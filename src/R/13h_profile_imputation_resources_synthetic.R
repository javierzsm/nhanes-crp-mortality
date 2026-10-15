# Synthetic-only, single-chain resource benchmark; not study inference.
# Run from repository root after the completed 13f validation.
Sys.setenv(TZ='Europe/Paris')
prefix <- 'output/tables/qc_13h_resource_profile_v1'
outputs <- paste0(prefix,c('_timings.csv','_rprof.out'))
if(any(file.exists(outputs))) stop('Profile outputs exist; review/version before rerunning.')
library(mice)
source('src/R/00_functions_imputation_continuation.R')
z <- readRDS('data/processed/qc_13f_extended_synthetic40_v1_validation.rds')
obj <- z$mids
obj$call <- quote(mice::mice(data))
obj$m <- 1L
obj$imp <- lapply(obj$imp, function(v) v[,1L,drop=FALSE])
obj$chainMean <- obj$chainMean[,,1L,drop=FALSE]
obj$chainVar <- obj$chainVar[,,1L,drop=FALSE]
obj$method[obj$method=='polyreg_audit'] <- 'polyreg'
rm(z); gc()
timings <- list()
for (method in c('pmm','polyreg','logreg')) {
  fun <- get(paste0('mice.impute.',method),asNamespace('mice'))
  wrapper <- local({ original <- fun; label <- method
    function(...) { started <- proc.time(); ans <- original(...); elapsed <- proc.time()-started
      timings[[length(timings)+1L]] <<- data.frame(method=label,user=elapsed[['user.self']],system=elapsed[['sys.self']],elapsed=elapsed[['elapsed']]); ans }
  })
  name <- paste0(method,'_timed')
  assign(paste0('mice.impute.',name),wrapper,.GlobalEnv)
  obj$method[obj$method==method] <- name
}
set.seed(20261014)
Rprof(outputs[[2L]], interval=.02)
started <- proc.time()
ans <- continue_mice_compact(obj)
Rprof(NULL)
print(proc.time()-started)
result <- do.call(rbind,timings)
result$variable <- c('bmi','education','smoking','diabetes','hypertension','prevalent_cvd')
write.csv(result,outputs[[1L]],row.names=FALSE)
print(result)
print(head(summaryRprof(outputs[[2L]])$by.self,12))
