#!/usr/bin/env Rscript
# Synthetic execution benchmark. Setup and workers invoked by the companion Python runner.
Sys.setenv(TZ = 'Europe/Paris', OPENBLAS_NUM_THREADS = '1', OMP_NUM_THREADS = '1', MKL_NUM_THREADS = '1')
suppressPackageStartupMessages(library(mice))
source('src/R/00_functions_imputation_continuation.R')
args <- commandArgs(TRUE)
root <- 'data/processed/qc_13j_cpu60_benchmark_v1'
if (identical(args, 'setup')) {
  if (dir.exists(root)) stop('Benchmark already exists; use a new identifier.')
  dir.create(root)
  obj <- readRDS('data/processed/qc_13i_execution_benchmark_v1/input_1.rds')
  RNGkind("L'Ecuyer-CMRG"); set.seed(20261014)
  seeds <- list(.Random.seed)
  for(i in 2:10) seeds[[i]] <- parallel::nextRNGStream(seeds[[i-1]])
  for (i in 1:10) {
    obj$lastSeedValue <- seeds[[i]]
    saveRDS(obj, file.path(root,paste0('input_',i,'.rds')))
  }
  saveRDS(list(seed=20261014L, streams=seeds, session=sessionInfo(),
    source_hash=tools::md5sum(c('src/R/13j_benchmark_cpu60_synthetic.R',
      'src/R/00_functions_imputation_continuation.R')),
    parent_hash=tools::md5sum('data/processed/qc_13f_extended_synthetic40_v1_validation.rds')),file.path(root,'manifest.rds'))
} else if (length(args)==3L) {
  mode <- args[[1]]; chain <- as.integer(args[[2]]); label <- args[[3]]
  stopifnot(mode %in% c('original','compact'),chain %in% 1:10)
  destination <- file.path(root,paste0(label,'.rds'))
  if(file.exists(destination)) stop('Existing result.')
  obj <- readRDS(file.path(root,paste0('input_',chain,'.rds')))
  assign('.Random.seed',obj$lastSeedValue,.GlobalEnv)
  # Bound transient allocation without altering fits or RNG.
  for(method in c('pmm','polyreg','logreg')) {
    fun <- get(paste0('mice.impute.',method),asNamespace('mice'))
    wrapper <- local({original <- fun; function(...) {
      gc(verbose=FALSE); result <- original(...); gc(verbose=FALSE); result
    }})
    assign(paste0('mice.impute.',method,'_gc'),wrapper,.GlobalEnv)
    obj$method[obj$method==method] <- paste0(method,'_gc')
  }
  gc(verbose=FALSE)
  before <- proc.time()
  if(mode=='compact') ans <- continue_mice_compact(obj) else {
    ans <- withCallingHandlers(do.call(mice::mice.mids,list(obj=obj,maxit=1L,
      printFlag=FALSE,nnet.maxit=1000L,nnet.MaxNWts=5000L,donors=5L,
      matchtype=1L,ridge=1e-5,nnet.trace=FALSE)),
      warning=function(w) stop(conditionMessage(w)))
  }
  timing <- proc.time()-before
  stopifnot(is.null(ans$loggedEvents)||nrow(ans$loggedEvents)==0L)
  stopifnot(identical(ans$data,obj$data),identical(ans$where,obj$where),
    identical(ans$method,obj$method),identical(ans$predictorMatrix,obj$predictorMatrix))
  # Compressed atomic checkpoint and substantive round-trip verification.
  temporary <- tempfile(tmpdir=root)
  save_time <- system.time(saveRDS(ans,temporary))
  restored <- readRDS(temporary)
  fields <- setdiff(names(ans),c('call','formulas'))
  stopifnot(identical(ans[fields],restored[fields]),
    identical(lapply(ans$formulas,deparse),lapply(restored$formulas,deparse)))
  stopifnot(file.rename(temporary,destination))
  write.csv(data.frame(label=label,mode=mode,chain=chain,
    elapsed=timing[['elapsed']],cpu=timing[['user.self']]+timing[['sys.self']],
    mids_bytes=as.numeric(object.size(ans)),call_bytes=as.numeric(object.size(ans$call)),
    checkpoint_bytes=file.info(destination)$size,save_elapsed=save_time[['elapsed']]),
    file.path(root,paste0(label,'_timing.csv')),row.names=FALSE)
} else stop('Use setup or MODE CHAIN LABEL.')
