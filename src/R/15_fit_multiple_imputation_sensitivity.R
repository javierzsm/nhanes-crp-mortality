#!/usr/bin/env Rscript
# Accepted MI sensitivity: unchanged primary survey Cox and scalar Rubin pooling.
Sys.setenv(TZ='Europe/Paris',OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1')
source('src/R/00_config.R');source('src/R/00_functions_data.R')
source('src/R/00_functions_analysis.R');source('src/R/00_functions_imputation_execution.R')
assert_project_root()
id<-'20261014_fourworker_v1';prefix<-paste0('mi15_',id,'_v2')
root<-file.path('data/processed',paste0('mi14_',id))
result_dir<-file.path('data/processed',prefix)
outputs<-file.path(paths$tables,paste0(prefix,c('_per_imputation.csv','_pooled.csv','_comparison.csv','_qc.csv')))
if(any(file.exists(outputs)))stop('Completed outputs exist; do not overwrite.')
acceptance<-readRDS(file.path(root,'accepted_endpoint_020.rds'))
plan<-readRDS(file.path(root,'plan.rds'))
stopifnot(acceptance$accepted_iteration==20L,acceptance$m==50L,
 identical(mi_hashes(names(acceptance$review_hashes)),acceptance$review_hashes),
 identical(mi_hashes(names(acceptance$checkpoint_hashes)),acceptance$checkpoint_hashes),
 identical(mi_hashes(names(acceptance$plan_hash)),acceptance$plan_hash),
 identical(mi_hashes(names(plan$manifest$hashes)),plan$manifest$hashes),
 identical(mi_versions(),plan$manifest$versions))
x<-readRDS(file.path(paths$processed,'mortality_linked_eligible_cohort.rds'))
stopifnot(identical(x$SEQN,plan$manifest$input_ids),nrow(x)==27755L,sum(x$death)==6354L)
formula<-survival::Surv(follow_up_months,death) ~ log2_crp +
 age_rcs1+age_rcs2+age_rcs3+sex+race_hispanic_origin+cycle+education+smoking+bmi+
 diabetes+hypertension+prevalent_cvd
# Verify formula against source AST of primary script rather than duplicating unchecked choices.
expressions<-parse('src/R/06_fit_primary_cox_models.R')
assignment<-Filter(function(e)is.call(e)&&identical(e[[1]],as.name('<-'))&&identical(e[[2]],as.name('primary_formula')),as.list(expressions))
stopifnot(length(assignment)==1L,identical(deparse(formula),deparse(eval(assignment[[1]][[3]]))))
protected<-unique(c(names(plan$manifest$hashes),names(acceptance$checkpoint_hashes),
 list.files(paths$tables,pattern='^(table_|qc_0[6-9]|qc_1[01])',full.names=TRUE)))
protected_hashes<-mi_hashes(protected)
manifest<-list(run_id=id,accepted_iteration=20L,m=50L,formula=deparse(formula),
 versions=mi_versions(),input_hashes=protected_hashes,
 code_hash=mi_hashes('src/R/15_fit_multiple_imputation_sensitivity.R'),
 acceptance_hash=mi_hashes(file.path(root,'accepted_endpoint_020.rds')),
 session=sessionInfo(),df_convention='Finite Barnard-Rubin, dfcom=survey::degf(eligible design)')
if(!dir.exists(result_dir)) {
 dir.create(result_dir);mi_atomic_save(manifest,file.path(result_dir,'manifest.rds'))
 stopifnot(file.copy('src/R/15_fit_multiple_imputation_sensitivity.R',file.path(result_dir,'executed_source.R'),overwrite=FALSE))
} else stopifnot(identical(readRDS(file.path(result_dir,'manifest.rds'))[c('input_hashes','code_hash','acceptance_hash','versions')],manifest[c('input_hashes','code_hash','acceptance_hash','versions')]))
reuse<-identical(commandArgs(TRUE),'--reuse-v1-fits')
if(length(commandArgs(TRUE))&&!reuse)stop('Only --reuse-v1-fits is supported.')
if(reuse) {
 previous_dir<-file.path('data/processed',paste0('mi15_',id,'_v1'))
 previous<-readRDS(file.path(previous_dir,'manifest.rds'))
 stopifnot(identical(previous$input_hashes,protected_hashes),
   identical(previous$versions,manifest$versions),identical(previous$formula,manifest$formula),
   identical(unname(mi_hashes(file.path(previous_dir,'executed_source.R'))),unname(previous$code_hash)))
 reuse_record<-list(parent_manifest=mi_hashes(file.path(previous_dir,'manifest.rds')),
   parent_fits=mi_hashes(file.path(previous_dir,sprintf('model_%03d.rds',1:50))),
   reason='Correct historical comparison CI field names; Q/U and all fitted models unchanged.')
 mi_atomic_save(reuse_record,file.path(result_dir,'reused_fits_provenance.rds'))
}
rows<-list()
for(chain in 1:50) {
 path<-file.path(result_dir,sprintf('model_%03d.rds',chain))
 if(file.exists(path)) {
  rows[[chain]]<-readRDS(path);next
 }
 if(reuse) {
  row<-readRDS(file.path(previous_dir,sprintf('model_%03d.rds',chain)))
  stopifnot(row$chain==chain,row$n==27755L,row$deaths==6354L,row$dfcom==91L,
    row$finite_model,is.finite(row$beta),is.finite(row$variance),row$variance>0)
  mi_atomic_save(row,path);rows[[chain]]<-row;next
 }
 state<-readRDS(file.path(root,sprintf('chain_%03d/iteration_020.rds',chain)))
 mi_check_state(state$mids,plan)
 completed<-mice::complete(state$mids,1L);analysis<-x
 for(v in mi_targets) {
  missing<-plan$where[,v]
  stopifnot(identical(completed[[v]][!missing],plan$data[[v]][!missing]))
  draws<-completed[[v]][missing]
  if(v=='bmi')draws<-draws*plan$transforms$bmi[['sd']]+plan$transforms$bmi[['mean']]
  analysis[[v]][missing]<-draws
  stopifnot(identical(analysis[[v]][!missing],x[[v]][!missing]))
 }
 stopifnot(!anyNA(analysis[primary_covariates]),identical(analysis$SEQN,x$SEQN))
 for(v in setdiff(names(x),mi_targets))stopifnot(identical(analysis[[v]],x[[v]]))
 analysis<-add_age_spline_basis(analysis,plan$manifest$age_knots)
 design<-build_survey_design(analysis);dfcom<-survey::degf(design)
 stopifnot(dfcom==91L)
 fit<-mi_strict(survey::svycoxph(formula,design=design,method='efron',model=FALSE))
 validate_cox_model(fit)
 stopifnot(fit$n==27755L,fit$nevent==6354L,
   all(is.finite(coef(fit))),all(is.finite(vcov(fit))),all(diag(vcov(fit))>0))
 row<-data.frame(chain=chain,n=fit$n,deaths=fit$nevent,dfcom=dfcom,
  beta=unname(coef(fit)['log2_crp']),variance=unname(vcov(fit)['log2_crp','log2_crp']),
  coefficients=length(coef(fit)),finite_model=TRUE)
 mi_atomic_save(row,path);rows[[chain]]<-row
 message('MI survey-Cox ',chain,'/50 verified and saved.')
 rm(fit,design,completed,analysis,state);gc(verbose=FALSE)
}
results<-do.call(rbind,rows);Q<-results$beta;U<-results$variance;m<-50L
stopifnot(nrow(results)==50L,identical(results$chain,1:50),all(results$dfcom==91L))
qbar<-mean(Q);ubar<-mean(U);B<-var(Q);T<-ubar+(1+1/m)*B
lambda<-(1+1/m)*B/T;r<-(1+1/m)*B/ubar
df_old<-if(lambda==0)Inf else (m-1)/lambda^2
df_obs<-(92/94)*91*(1-lambda);df<-1/(1/df_old+1/df_obs)
fmi<-(r+2/(df+3))/(r+1)
independent<-mice::pool.scalar(Q,U,n=92,k=1)
stopifnot(isTRUE(all.equal(T,independent$t)),isTRUE(all.equal(qbar,independent$qbar)),
 isTRUE(all.equal(df,independent$df)),isTRUE(all.equal(fmi,independent$fmi)))
# Independent edge control for zero between-imputation variance.
zero<-mice::pool.scalar(rep(.1,50),rep(.01,50),n=92,k=1)
stopifnot(isTRUE(all.equal(zero$t,.01)),is.finite(zero$df))
se<-sqrt(T);critical<-qt(.975,df)
pooled<-data.frame(m=m,n=27755L,deaths=6354L,iterations=20L,beta=qbar,se=se,
 within_variance=ubar,between_variance=B,total_variance=T,dfcom=91L,df=df,
 lambda=lambda,relative_variance_increase=r,fmi=fmi,
 HR=exp(qbar),CI_lower=exp(qbar-critical*se),CI_upper=exp(qbar+critical*se),
 p=2*pt(-abs(qbar/se),df),inference='Barnard-Rubin t interval; survey dfcom=91')
cc<-read.csv(file.path(paths$tables,'table_02_primary_crp_hazard_ratios.csv'))
cc<-cc[cc$model=='Primary',]
stopifnot(nrow(cc)==1L)
write_csv_checked(results,outputs[1]);write_csv_checked(pooled,outputs[2])
# Keep the historical table's convention and exact fields as originally exported.
comparison<-data.frame(analysis=c('Primary complete-case','Secondary multiple imputation'),
 n=c(26818L,27755L),deaths=c(5886L,6354L),HR=c(cc$hazard_ratio,pooled$HR),
 CI_lower=c(cc$confidence_low,pooled$CI_lower),CI_upper=c(cc$confidence_high,pooled$CI_upper),
 inference=c('Original asymptotic Wald','Finite Barnard-Rubin t, dfcom=91'))
write_csv_checked(comparison,outputs[3])
stopifnot(identical(mi_hashes(names(protected_hashes)),protected_hashes))
write_csv_checked(data.frame(check=c('all_50_models_finite','unchanged_cohort_and_observed_values',
 'primary_formula_identical','scalar_pooling_independent_match','finite_df_zero_B_control',
 'protected_outputs_unchanged','no_imputation_refitting'),passed=TRUE),outputs[4])
mi_atomic_save(list(manifest=manifest,pooled=pooled,per_imputation=results,comparison=comparison),file.path(result_dir,'completed_results.rds'))
print(pooled);print(comparison)
