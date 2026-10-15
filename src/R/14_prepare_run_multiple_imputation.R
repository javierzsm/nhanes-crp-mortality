#!/usr/bin/env Rscript
# Study MI preparation and single-iteration workers. Preparation does not draw imputations.
# Run from repository root; use the Python supervisor for four-worker execution.
Sys.setenv(TZ='Europe/Paris',OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',MKL_NUM_THREADS='1')
source('src/R/00_config.R');source('src/R/00_functions_data.R')
source('src/R/00_functions_analysis.R')
source('src/R/00_functions_imputation_continuation.R')
source('src/R/00_functions_imputation_execution.R')
source('src/R/00_functions_imputation_review.R')
assert_project_root()
for(p in c('mice','nnet','survey','survival'))require_package(p)
args<-commandArgs(TRUE)
if(length(args)<2L || !args[1]%in%c('--prepare','--worker','--status','--export'))stop('Use --prepare RUN_ID, --status RUN_ID, or --worker RUN_ID CHAIN ITERATION.')
mode<-args[1];id<-args[2]
if(!grepl('^[A-Za-z0-9][A-Za-z0-9_-]{0,70}$',id))stop('Invalid run ID.')
root<-file.path(paths$processed,paste0('mi14_',id))
plan_path<-file.path(root,'plan.rds')
input_files<-file.path(paths$processed,c('mortality_linked_eligible_cohort.rds','primary_complete_case_cohort.rds','analysis_constants.rds'))
source_files<-c('src/R/00_config.R','src/R/00_functions_data.R','src/R/00_functions_analysis.R',
 'src/R/00_functions_imputation_continuation.R','src/R/00_functions_imputation_execution.R',
 'src/R/00_functions_imputation_review.R',
 'src/R/14_prepare_run_multiple_imputation.R','src/R/14_run_multiple_imputation.py',
 'docs/methods/multiple_imputation_technical_spec_draft.md')
if(mode=='--prepare') {
  stopifnot(length(args)==2L,multiple_imputation_m==50L)
  if(dir.exists(root))stop('Run directory exists; use its verified plan or a fresh ID.')
  x<-readRDS(input_files[1]);cc<-readRDS(input_files[2]);constants<-readRDS(input_files[3])
  stopifnot(nrow(x)==27755L,sum(x$death)==6354L,nrow(cc)==26818L,sum(cc$death)==5886L,
    !anyDuplicated(x$SEQN),!anyDuplicated(cc$SEQN),
    identical(as.logical(x$primary_complete),complete.cases(x[primary_covariates])),
    setequal(x$SEQN[x$primary_complete],cc$SEQN),sum(!x$primary_complete)==937L,
    length(unique(x$SDMVSTRA))==89L,
    nlevels(interaction(x$SDMVSTRA,x$SDMVPSU,drop=TRUE))==180L,
    sum(x$zero_follow_up_death)==4L,all(x$follow_up_months[x$zero_follow_up_death]==.5))
  expected<-c(bmi=575L,education=48L,smoking=31L,diabetes=19L,hypertension=164L,prevalent_cvd=147L)
  stopifnot(identical(vapply(x[names(expected)],function(z)sum(is.na(z)),integer(1)),expected))
  for(v in c('sex','race_hispanic_origin','cycle',mi_targets[-1]))
    stopifnot(is.factor(x[[v]]),!is.ordered(x[[v]]))
  plan<-mi_prepare_table(x,constants$age_knots)
  stopifnot(nrow(plan$mapping)==174L,
    sum(plan$mapping$kind=='stratum')==83L,sum(plan$mapping$kind=='psu')==91L)
  RNGkind("L'Ecuyer-CMRG");set.seed(20261013)
  streams<-list(.Random.seed)
  for(i in 2:multiple_imputation_m)streams[[i]]<-parallel::nextRNGStream(streams[[i-1]])
  plan$manifest<-list(run_id=id,m=multiple_imputation_m,workers=4L,kind='study',seed=20261013L,
    streams=streams,initial_iterations=20L,allowed_endpoints=c(20L,40L,60L),
    versions=mi_versions(),hashes=mi_hashes(c(input_files,source_files)),
    created=as.character(Sys.time()),session=sessionInfo(),
    input_ids=x$SEQN,age_knots=constants$age_knots,
    scientific_scope='Secondary prognostic sensitivity; unchanged primary model.',
    checkpoint_cadence=1L,prepared_only=TRUE)
  dir.create(root);dir.create(file.path(root,'sources'))
  for(file in source_files) {
    destination<-file.path(root,'sources',basename(file))
    stopifnot(file.copy(file,destination,overwrite=FALSE))
  }
  mi_atomic_save(plan,plan_path)
  writeLines(c(paste0('m=',multiple_imputation_m),'workers=4','kind=study'),file.path(root,'execution.txt'))
  write.csv(plan$rank,file.path(root,'preflight_rank.csv'),row.names=FALSE)
  write.csv(plan$mapping,file.path(root,'design_mapping.csv'),row.names=FALSE)
  write.csv(data.frame(chain=1:50,worker_slot=(0:49)%%4+1L),file.path(root,'chain_mapping.csv'),row.names=FALSE)
  message('Prepared ',root,'; no MICE initialization, imputation or Cox fit executed.')
} else {
  if(!file.exists(plan_path))stop('Prepare run first.')
  plan<-readRDS(plan_path)
  stopifnot(identical(plan$manifest$run_id,id),identical(mi_versions(),plan$manifest$versions),
    identical(mi_hashes(names(plan$manifest$hashes)),plan$manifest$hashes))
  settings<-readLines(file.path(root,'execution.txt'))
  stopifnot(identical(settings,c(paste0('m=',plan$manifest$m),paste0('workers=',plan$manifest$workers),paste0('kind=',plan$manifest$kind))))
  if(mode=='--status') {
    stopifnot(length(args)==2L)
    rows<-lapply(seq_len(plan$manifest$m),function(chain) {
      files<-list.files(file.path(root,sprintf('chain_%03d',chain)),pattern='^iteration_[0-9]{3}\\.rds$')
      latest<-NA_integer_
      if(length(files)) {
        indices<-sort(as.integer(substr(files,11,13)))
        stopifnot(identical(indices,0:max(indices)))
        state<-readRDS(file.path(root,sprintf('chain_%03d',chain),tail(sort(files),1L)))
        stopifnot(state$chain==chain,identical(state$plan_hash,unname(mi_hashes(plan_path))),
          state$mids$iteration==max(indices))
        mi_check_state(state$mids,plan);latest<-max(indices)
      }
      data.frame(chain=chain,iteration=latest)
    });print(do.call(rbind,rows),row.names=FALSE)
  } else if(mode=='--export') {
    stopifnot(length(args)==3L)
    mi_export_review(root,plan,as.integer(args[3]))
  } else {
    stopifnot(length(args)==4L)
    chain<-as.integer(args[3]);iteration<-as.integer(args[4])
    stopifnot(chain %in% seq_len(plan$manifest$m),iteration %in% 1:60)
    if(iteration>20L && !file.exists(file.path(root,sprintf('extension_to_%03d.txt',if(iteration<=40L)40L else 60L))))stop('Missing prospective extension review.')
    folder<-file.path(root,sprintf('chain_%03d',chain));dir.create(folder,showWarnings=FALSE)
    # Exclusive per-chain lock; killed workers leave a visible lock requiring review.
    lock<-file.path(folder,'worker.lock')
    if(!dir.create(lock,showWarnings=FALSE))stop('Chain lock exists: ',lock)
    tryCatch({
      audit<-mi_install_methods()
      checkpoint<-function(i)file.path(folder,sprintf('iteration_%03d.rds',i))
      plan_hash<-unname(mi_hashes(plan_path))
      if(file.exists(checkpoint(iteration)))stop('Requested iteration already exists.')
      if(!file.exists(checkpoint(0L))) {
        if(iteration!=1L)stop('Missing initial checkpoint.')
        RNGkind("L'Ecuyer-CMRG");assign('.Random.seed',plan$manifest$streams[[chain]],.GlobalEnv)
        obj<-mi_strict(mice::mice(plan$data,m=1L,maxit=0L,predictorMatrix=plan$pred,
          method=plan$methods,where=plan$where,visitSequence=plan$targets,seed=NA,
          printFlag=FALSE,remove.constant=FALSE,remove.collinear=FALSE))
        obj$call<-quote(mice::mice(data,m=1L,maxit=0L))
        mi_check_state(obj,plan)
        # Validate the actual initialized regression matrices, separately from preparation fill.
        filled<-mice::complete(obj,1L)
        for(v in plan$targets) {
          X<-model.matrix(~.,filled[setdiff(names(filled),v)])
          X<-X[!plan$where[,v],,drop=FALSE];stopifnot(qr(X)$rank==ncol(X))
        }
        rm(filled,X);gc(verbose=FALSE)
        state<-list(mids=obj,chain=chain,plan_hash=plan_hash,trace=NULL,fits=NULL)
        mi_atomic_save(state,checkpoint(0L))
      }
      state<-readRDS(checkpoint(iteration-1L))
      stopifnot(state$chain==chain,identical(state$plan_hash,plan_hash),state$mids$iteration==iteration-1L)
      mi_check_state(state$mids,plan)
      assign('.Random.seed',state$mids$lastSeedValue,.GlobalEnv)
      obj<-mi_strict(continue_mice_compact(state$mids))
      mi_check_state(obj,plan)
      stopifnot(length(audit$fits)==3L)
      trace<-mi_trace(obj,plan,chain)
      fits<-do.call(rbind,audit$fits);fits$variable<-c('education','smoking','diabetes')
      fits$chain<-chain;fits$iteration<-iteration
      mi_atomic_save(list(mids=obj,chain=chain,plan_hash=plan_hash,trace=trace,fits=fits),checkpoint(iteration))
      message('Chain ',chain,' iteration ',iteration,' checkpoint verified.')
    },finally=unlink(lock,recursive=TRUE))
  }
}
