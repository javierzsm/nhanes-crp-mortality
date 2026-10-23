#!/usr/bin/env Rscript
# SAP-prespecified sex and age-group interactions; methods fixed in stage6 note.
Sys.setenv(TZ='Europe/Paris')
source('src/R/00_config.R');source('src/R/00_functions_data.R')
source('src/R/00_functions_analysis.R');source('src/R/00_functions_imputation_execution.R')
assert_project_root()
root<-file.path(paths$processed,'secondary_effect_modification_v1')
outputs<-file.path(paths$tables,c('table_08_effect_modifier_contrasts.csv',
 'table_08_effect_modifier_tests.csv','table_08_interaction_ratios.csv','qc_16_effect_modification.csv'))
if(dir.exists(root)||any(file.exists(outputs)))stop('Versioned outputs already exist.')
files<-c('data/processed/primary_complete_case_cohort.rds','data/processed/primary_cox_models.rds',
 'data/processed/analysis_constants.rds','protocol/sap_v0.3.qmd',
 'docs/methods/analysis_execution_stage6_sap_reconciliation.md',
 list.files(paths$tables,pattern='^(table_0[1-7]|mi15_.*_v2_)',full.names=TRUE))
hashes<-mi_hashes(files)
x<-readRDS(files[1]);saved<-readRDS(files[2]);constants<-readRDS(files[3])
stopifnot(nrow(x)==26818L,sum(x$death)==5886L,!anyDuplicated(x$SEQN),
 identical(constants$age_knots,saved$analysis_constants$age_knots))
x<-add_age_spline_basis(x,constants$age_knots)
x$age_group<-factor(ifelse(x$age<65,'20-64','65+'),levels=c('20-64','65+'))
stopifnot(all(x$age>=20),all(x$age[x$age_group=='20-64']<65),all(x$age[x$age_group=='65+']>=65))
design<-build_survey_design(x);stopifnot(survey::degf(design)==91L)
primary_formula<-formula(saved$primary)
forms<-list(sex=update(primary_formula,~.+log2_crp:sex),
 age_group=update(primary_formula,~.+age_group+log2_crp:age_group))
rows<-tests<-ratios<-qc<-models<-list()
for(modifier in names(forms)) {
 fit<-mi_strict(survey::svycoxph(forms[[modifier]],design=design,method='efron',model=FALSE))
 validate_cox_model(fit)
 stopifnot(fit$n==26818L,fit$nevent==5886L,all(diag(vcov(fit))>0))
 b<-coef(fit);V<-vcov(fit)
 interaction<-names(b)[grepl('log2_crp:',names(b),fixed=TRUE)&grepl(modifier,names(b),fixed=TRUE)]
 stopifnot(length(interaction)==1L)
 test<-design_wald_test(fit,paste0('log2_crp:',modifier),paste('CRP by',modifier))
 stopifnot(test$numerator_df==1L,is.finite(test$p_value))
 tests[[modifier]]<-cbind(modifier=modifier,test)
 levels<-levels(x[[modifier]])
 for(j in 1:2) {
  L<-setNames(rep(0,length(b)),names(b));L['log2_crp']<-1
  if(j==2)L[interaction]<-1
  beta<-sum(L*b);variance<-as.numeric(t(L)%*%V%*%L);se<-sqrt(variance)
  # Independent algebra for covariance of beta + interaction.
  expected<-if(j==1)V['log2_crp','log2_crp']else V['log2_crp','log2_crp']+V[interaction,interaction]+2*V['log2_crp',interaction]
  stopifnot(isTRUE(all.equal(variance,unname(expected))))
  member<-x[[modifier]]==levels[j]
  rows[[length(rows)+1]]<-data.frame(modifier=modifier,group=levels[j],participants=sum(member),
   deaths=sum(x$death[member]),log_hazard_ratio=beta,standard_error=se,hazard_ratio=exp(beta),
   confidence_low=exp(beta-qnorm(.975)*se),confidence_high=exp(beta+qnorm(.975)*se))
 }
 ib<-unname(b[interaction]);ise<-sqrt(V[interaction,interaction])
 ratios[[modifier]]<-data.frame(modifier=modifier,comparison=paste(levels[2],'versus',levels[1]),
  interaction_beta=ib,standard_error=ise,ratio_of_HRs=exp(ib),
  confidence_low=exp(ib-qnorm(.975)*ise),confidence_high=exp(ib+qnorm(.975)*ise))
 qc[[modifier]]<-data.frame(modifier=modifier,participants=fit$n,deaths=fit$nevent,
  coefficients=length(b),design_df=survey::degf(design),residual_df=fit$degf.resid,
  finite_coefficients_and_covariance=TRUE,contrast_covariance_checked=TRUE)
 models[[modifier]]<-list(formula=deparse(forms[[modifier]]),coefficients=b,covariance=V)
 message('Secondary interaction verified: ',modifier)
}
stopifnot(identical(mi_hashes(names(hashes)),hashes))
write_csv_checked(do.call(rbind,rows),outputs[1]);write_csv_checked(do.call(rbind,tests),outputs[2])
write_csv_checked(do.call(rbind,ratios),outputs[3]);write_csv_checked(do.call(rbind,qc),outputs[4])
dir.create(root)
mi_atomic_save(list(inputs=hashes,code=mi_hashes('src/R/16_secondary_effect_modification.R'),
 session=sessionInfo(),models=models),file.path(root,'results.rds'))
print(do.call(rbind,rows));print(do.call(rbind,tests))
