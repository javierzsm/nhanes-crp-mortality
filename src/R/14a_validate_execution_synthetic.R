#!/usr/bin/env Rscript
# Small artificial end-to-end fixture for the exact Script 14 worker/supervisor.
Sys.setenv(TZ='Europe/Paris')
source('src/R/00_functions_data.R');source('src/R/00_config.R');source('src/R/00_functions_analysis.R')
source('src/R/00_functions_imputation_continuation.R')
source('src/R/00_functions_imputation_execution.R')
id<-'synthetic_execution_v3';root<-file.path('data/processed',paste0('mi14_',id))
if(dir.exists(root))stop('Synthetic fixture already exists; review/version before rerunning.')
set.seed(1401);n<-600L
cycle<-rep(analysis_cycles$cycle,each=100L)
x<-data.frame(SEQN=seq_len(n),cycle=factor(cycle,levels=analysis_cycles$cycle),
 SDMVSTRA=rep(1:6,each=100L),SDMVPSU=rep(rep(1:2,each=50L),6),
 age=sample(20:79,n,TRUE),sex=factor(sample(c('Male','Female'),n,TRUE)),
 race_hispanic_origin=factor(sample(letters[1:5],n,TRUE)),
 bmi=rnorm(n,28,4),education=factor(sample(letters[1:5],n,TRUE)),
 smoking=factor(sample(c('never','former','current'),n,TRUE)),
 diabetes=factor(sample(c('No','Borderline','Yes'),n,TRUE)),
 hypertension=factor(sample(c('No','Yes'),n,TRUE)),
 prevalent_cvd=factor(sample(c('No','Yes'),n,TRUE)),
 log2_crp=rnorm(n),death=rbinom(n,1,.25),follow_up_months=sample(1:200,n,TRUE),
 pooled_mec_weight=exp(rnorm(n,7,.4)))
for(v in mi_targets)x[[v]][sample.int(n,20)]<-NA
plan<-mi_prepare_table(x,c(p5=24,p35=40,p65=60,p95=76))
RNGkind("L'Ecuyer-CMRG");set.seed(20261013);streams<-list(.Random.seed)
for(i in 2:4)streams[[i]]<-parallel::nextRNGStream(streams[[i-1]])
files<-c('src/R/14_prepare_run_multiple_imputation.R','src/R/14_run_multiple_imputation.py',
 'src/R/00_functions_imputation_execution.R','src/R/00_functions_imputation_review.R',
 'src/R/00_functions_imputation_continuation.R')
plan$manifest<-list(run_id=id,m=4L,workers=4L,kind='synthetic',streams=streams,
 versions=mi_versions(),hashes=mi_hashes(files),input_ids=x$SEQN)
dir.create(root);mi_atomic_save(plan,file.path(root,'plan.rds'))
writeLines(c('m=4','workers=4','kind=synthetic'),file.path(root,'execution.txt'))
message('Artificial test fixture prepared; invoke supervisor --synthetic-test --endpoint 2.')
