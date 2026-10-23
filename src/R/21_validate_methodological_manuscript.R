#!/usr/bin/env Rscript
# Read-only numerical checks for the Spanish methodological companion; no fitted models.
Sys.setenv(TZ='Europe/Paris')
source('src/R/00_functions_imputation_execution.R')
root<-'reports/metodologia_comentada_v1'
out<-file.path(root,'verificaciones.csv')
if(file.exists(out))stop('Validation exists; version before rerunning.')
text<-paste(readLines(file.path(root,'manuscrito_metodologico_es.md'),warn=FALSE),collapse='\n')
checks<-list();record<-function(name,passed)checks[[length(checks)+1L]]<<-data.frame(check=name,passed=passed)
cc<-read.csv('output/tables/table_02_primary_crp_hazard_ratios.csv');cc<-cc[cc$model=='Primary',]
p<-read.csv('output/tables/mi15_20261014_fourworker_v1_v2_pooled.csv')
q<-read.csv('output/tables/mi15_20261014_fourworker_v1_v2_per_imputation.csv')
record('primary_HR_and_interval',isTRUE(all.equal(unname(exp(cc$log_hazard_ratio+c(0,-qnorm(.975),qnorm(.975))*cc$standard_error)),unname(c(cc$hazard_ratio,cc$confidence_low,cc$confidence_high)))))
record('Rubin_Qbar',isTRUE(all.equal(mean(q$beta),p$beta)))
record('Rubin_within',isTRUE(all.equal(mean(q$variance),p$within_variance)))
record('Rubin_between',isTRUE(all.equal(var(q$beta),p$between_variance)))
record('Rubin_total',isTRUE(all.equal(mean(q$variance)+1.02*var(q$beta),p$total_variance)))
record('finite_MI_interval',isTRUE(all.equal(unname(exp(p$beta+c(-1,1)*qt(.975,p$df)*p$se)),unname(c(p$CI_lower,p$CI_upper)))))
record('Nelson_Aalen_tie_example',identical(mi_nelson_aalen(c(.25,.5,.5,.5,2),c(0,1,1,0,1)),c(0,.5,.5,.5,1.5)))
knots<-read.csv('output/tables/qc_05_spline_knots.csv')
record('age_knots',identical(knots$value[knots$variable=='age'],c(22,38,52,78)))
record('CRP_knots_back_transform',isTRUE(all.equal(2^knots$value[knots$variable=='log2_crp'],c(.2,1.1,3,14.7))))
missing<-read.csv('output/tables/qc_12_missingness_by_variable.csv')
targets<-c('bmi','education','smoking','diabetes','hypertension','prevalent_cvd')
record('984_missing_cells',sum(missing$missing_n[missing$variable%in%targets])==984L)
record('actual_MICE_version',as.character(packageVersion('mice'))=='3.19.0')
# Capture actual algorithms referred to in the text for version-specific inspection.
algorithms<-c('mice.impute.polyreg','mice.impute.logreg','mice.impute.pmm')
code<-unlist(lapply(algorithms,function(name)c(paste0('# ',name),deparse(get(name,asNamespace('mice'))),'')))
writeLines(code,file.path(root,'mice_3.19.0_algoritmos_inspeccionados.R'))
# Check the initial positivity filter against the applicable four-year weight, on original records.
weights<-list()
for(suffix in c('','_B')) {
 demo<-haven::read_xpt(paste0('data/raw/nhanes/DEMO',suffix,'.xpt'))
 crp<-haven::read_xpt(paste0('data/raw/nhanes/',if(suffix=='')'LAB11'else'L11_B','.xpt'))
 z<-merge(demo,crp[c('SEQN','LBXCRP')],by='SEQN')
 eligible<-!is.na(z$RIDAGEYR)&z$RIDAGEYR>=20&!is.na(z$LBXCRP)&z$LBXCRP>0
 a<-eligible&!is.na(z$WTMEC2YR)&z$WTMEC2YR>0
 b<-eligible&!is.na(z$WTMEC4YR)&z$WTMEC4YR>0
 weights[[length(weights)+1L]]<-data.frame(cycle=if(suffix=='')'1999-2000'else'2001-2002',positive_2yr=sum(a),positive_4yr=sum(b),membership_discrepancies=sum(a!=b))
}
weights<-do.call(rbind,weights)
record('positivity_filter_membership_equivalent',all(weights$membership_discrepancies==0L)&&identical(weights$positive_4yr,c(4145L,4729L)))
write.csv(weights,file.path(root,'auditoria_filtro_pesos.csv'),row.names=FALSE)
# Check saved completed analysis and accepted imputation artifacts without updating their manifests.
a<-readRDS('data/processed/mi14_20261014_fourworker_v1/accepted_endpoint_020.rds')
record('accepted_checkpoints_unchanged',identical(mi_hashes(names(a$checkpoint_hashes)),a$checkpoint_hashes))
s<-readRDS('data/processed/mi15_20261014_fourworker_v1_v2/phase_complete.rds')
record('Stage5_outputs_unchanged',identical(mi_hashes(names(s$hashes)),s$hashes))
s<-readRDS('data/processed/reporting_stage6_v1_manifest.rds')
record('original_manuscript_and_Stage6_unchanged',identical(mi_hashes(names(s$hashes)),s$hashes))
record('four_event_sensitivity_explicitly_pending',grepl('salida específica',text,fixed=TRUE)&&grepl('no la ejecuta',text,fixed=TRUE))
result<-do.call(rbind,checks);print(result);stopifnot(all(result$passed))
write.csv(result,out,row.names=FALSE)
inputs<-c('src/R/21_validate_methodological_manuscript.R',
 'output/tables/table_02_primary_crp_hazard_ratios.csv',
 'output/tables/mi15_20261014_fourworker_v1_v2_pooled.csv',
 'output/tables/mi15_20261014_fourworker_v1_v2_per_imputation.csv',
 'output/tables/qc_05_spline_knots.csv','output/tables/qc_12_missingness_by_variable.csv',
 'data/raw/nhanes/DEMO.xpt','data/raw/nhanes/DEMO_B.xpt','data/raw/nhanes/LAB11.xpt','data/raw/nhanes/L11_B.xpt')
write.csv(data.frame(path=inputs,md5=unname(mi_hashes(inputs))),file.path(root,'fuentes_verificadas.csv'),row.names=FALSE)
