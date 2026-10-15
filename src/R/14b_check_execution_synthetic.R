#!/usr/bin/env Rscript
# Recovery and corruption controls for the integrated artificial fixture.
Sys.setenv(TZ='Europe/Paris')
source('src/R/00_functions_imputation_execution.R')
source('src/R/00_functions_imputation_continuation.R')
root<-'data/processed/mi14_synthetic_execution_v3'
out<-file.path(root,'execution_checks.csv')
if(file.exists(out))stop('Checks already recorded.')
plan<-readRDS(file.path(root,'plan.rds'))
checks<-list()
record<-function(name,passed)checks[[length(checks)+1L]]<<-data.frame(check=name,passed=passed)
audit<-mi_install_methods()
for(chain in 1:4) {
 prior<-readRDS(file.path(root,sprintf('chain_%03d/iteration_001.rds',chain)))
 reference<-readRDS(file.path(root,sprintf('chain_%03d/iteration_002.rds',chain)))
 audit$fits<-list();assign('.Random.seed',prior$mids$lastSeedValue,.GlobalEnv)
 replay<-continue_mice_compact(prior$mids)
 fields<-setdiff(names(replay),c('call','formulas','date'))
 record(paste0('checkpoint_replay_chain_',chain),identical(replay[fields],reference$mids[fields]))
 record(paste0('audit_replay_chain_',chain),identical(do.call(rbind,audit$fits),
   reference$fits[c('convergence','coefficients','min_probability','max_probability')]))
 record(paste0('trace_replay_chain_',chain),identical(mi_trace(replay,plan,chain),reference$trace))
}
state<-reference$mids
for(kind in c('data','where','predictor','method')) {
 bad<-state
 if(kind=='data')bad$data$log2_crp[1]<-bad$data$log2_crp[1]+1
 if(kind=='where')bad$where[1,1]<-!bad$where[1,1]
 if(kind=='predictor')bad$predictorMatrix[1,2]<-0
 if(kind=='method')bad$method[1]<-'norm'
 record(paste0('reject_changed_',kind),inherits(try(mi_check_state(bad,plan),silent=TRUE),'try-error'))
}
# Direct instrumentation test against installed multinomial code, including RNG.
set.seed(14);y<-factor(sample(letters[1:3],120,TRUE));ry<-seq_along(y)<=100
X<-matrix(rnorm(240),120,2)
set.seed(140);a<-mice::mice.impute.polyreg(y,ry,X,nnet.maxit=1000,nnet.MaxNWts=5000);rng<-.Random.seed
set.seed(140);b<-mice.impute.polyreg_checked(y,ry,X,nnet.maxit=1000,nnet.MaxNWts=5000)
record('checked_multinomial_draws_identical',identical(a,b));record('checked_multinomial_rng_identical',identical(rng,.Random.seed))
checked_fun<-environment(mice.impute.polyreg_checked)$f
check<-environment(checked_fun)$mi_check_fit
record('reject_nonconverged_multinomial',inherits(try(check(list(convergence=1L),matrix(.5,1,2)),silent=TRUE),'try-error'))
record('reject_warning',inherits(try(mi_strict(warning('synthetic negative control')),silent=TRUE),'try-error'))
result<-do.call(rbind,checks);print(result);stopifnot(all(result$passed))
write.csv(result,out,row.names=FALSE)
