#!/usr/bin/env Rscript
# Descriptive first-order influence; no deletions, refitting or pass/fail threshold.
Sys.setenv(TZ='Europe/Paris')
source('src/R/00_config.R');source('src/R/00_functions_data.R')
source('src/R/00_functions_analysis.R');source('src/R/00_functions_imputation_execution.R')
assert_project_root()
for(p in c("survey","survival"))require_package(p)
outputs<-file.path(paths$tables,c('table_09_primary_influence_summary.csv',
 'table_09_primary_influence_psu.csv','qc_17_primary_influence.csv'))
root<-file.path(paths$processed,'primary_influence_v1')
if(any(file.exists(outputs))||dir.exists(root))stop('Influence outputs already exist.')
files<-c('data/processed/primary_cox_models.rds','data/processed/primary_complete_case_cohort.rds',
 'docs/methods/analysis_execution_stage6_sap_reconciliation.md')
hashes<-mi_hashes(files);fit<-readRDS(files[1])$primary;x<-readRDS(files[2])
stopifnot(fit$n==26818L,fit$nevent==5886L,nrow(x)==fit$n,
 identical(names(fit$residuals),rownames(x)),!is.null(fit$naive.var))
key<-interaction(x$SDMVSTRA,x$SDMVPSU,drop=TRUE)
dfb<-mi_strict(residuals(fit,type='dfbeta',weighted=TRUE))
stopifnot(is.matrix(dfb),nrow(dfb)==nrow(x),ncol(dfb)==length(coef(fit)),all(is.finite(dfb)),
 identical(rownames(dfb),rownames(x)))
collapsed<-mi_strict(residuals(fit,type='dfbeta',weighted=TRUE,collapse=key))
independent<-rowsum(dfb,key,reorder=TRUE)
stopifnot(isTRUE(all.equal(collapsed,independent,check.attributes=FALSE)),nrow(collapsed)==180L)
# survival's multiplication by unnamed naive.var can drop column labels; coefficient order is retained.
colnames(dfb)<-colnames(collapsed)<-names(coef(fit))
se<-sqrt(vcov(fit)['log2_crp','log2_crp'])
individual<-dfb[,'log2_crp'];psu<-collapsed[,'log2_crp']
summary<-do.call(rbind,lapply(list(participant=individual,nested_PSU=psu),function(z) {
 a<-abs(z/se)
 data.frame(units=length(z),median_abs_SE=median(a),p95_abs_SE=unname(quantile(a,.95)),
  p99_abs_SE=unname(quantile(a,.99)),max_abs_SE=max(a),
  max_abs_logHR_contribution=max(abs(z)),sum_signed_contributions=sum(z))
}))
summary$unit_type<-rownames(summary);rownames(summary)<-NULL
psus<-data.frame(nested_psu=rownames(collapsed),participants=as.integer(table(key)),
 weighted_dfbeta_crp=as.numeric(psu),standardized_by_design_SE=as.numeric(psu/se))
psus<-psus[order(abs(psus$standardized_by_design_SE),decreasing=TRUE),]
stopifnot(sum(psus$participants)==26818L,all(is.finite(psus$standardized_by_design_SE)))
stopifnot(identical(mi_hashes(names(hashes)),hashes))
write_csv_checked(summary,outputs[1]);write_csv_checked(psus,outputs[2])
write_csv_checked(data.frame(check=c('cohort_model_row_alignment','finite_weighted_residuals',
 'all_180_psus_retained','independent_group_sums_match','original_inputs_unchanged'),passed=TRUE),outputs[3])
dir.create(root);mi_atomic_save(list(inputs=hashes,code=mi_hashes('src/R/17_primary_influence_diagnostics.R'),
 session=sessionInfo(),design_SE=se,summary=summary,psu=psus,
 interpretation='First-order case-weight contributions, not exact deletion estimates or survey hypothesis tests'),file.path(root,'results.rds'))
print(summary)
