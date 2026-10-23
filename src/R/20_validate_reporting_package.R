#!/usr/bin/env Rscript
# Meaningful cross-checks of secondary contrasts, source preservation and report numbers.
Sys.setenv(TZ='Europe/Paris')
source('src/R/00_functions_imputation_execution.R')
root<-'reports/stage6_v1';out<-file.path(root,'validation.csv')
if(file.exists(out))stop('Validation already recorded.')
checks<-list();record<-function(name,passed) {
 stopifnot(length(passed)==1L,!is.na(passed))
 checks[[length(checks)+1L]]<<-data.frame(check=name,passed=passed)
}
m<-readRDS('data/processed/secondary_effect_modification_v1/results.rds')
record('secondary_inputs_preserved',identical(mi_hashes(names(m$inputs)),m$inputs))
record('secondary_executed_code_matches',identical(mi_hashes(names(m$code)),m$code))
t<-read.csv('output/tables/table_08_effect_modifier_tests.csv')
c<-read.csv('output/tables/table_08_effect_modifier_contrasts.csv')
for(modifier in names(m$models)) {
 model<-m$models[[modifier]];b<-model$coefficients;V<-model$covariance
 idx<-grep(paste0('log2_crp:',modifier),names(b),fixed=TRUE)
 f<-b[idx]^2/V[idx,idx];observed<-t[t$modifier==modifier,]
 record(paste0(modifier,'_wald_F_independent'),isTRUE(all.equal(unname(f),observed$f_statistic)))
 record(paste0(modifier,'_wald_p_independent'),isTRUE(all.equal(pf(f,1,observed$denominator_df,lower.tail=FALSE),observed$p_value,check.attributes=FALSE)))
 groups<-c[c$modifier==modifier,]
 record(paste0(modifier,'_contrast_ratio_identity'),isTRUE(all.equal(log(groups$hazard_ratio[2]/groups$hazard_ratio[1]),unname(b[idx]))))
 record(paste0(modifier,'_counts_partition'),sum(groups$participants)==26818L&&sum(groups$deaths)==5886L)
}
i<-readRDS('data/processed/primary_influence_v1/results.rds')
record('influence_inputs_preserved',identical(mi_hashes(names(i$inputs)),i$inputs))
record('influence_code_matches',identical(mi_hashes(names(i$code)),i$code))
for(path in c('data/processed/mi14_20261014_fourworker_v1/accepted_endpoint_020.rds',
 'data/processed/mi15_20261014_fourworker_v1_v2/phase_complete.rds')) {
 z<-readRDS(path)
 if(!is.null(z$hashes))record('stage5_completed_outputs_preserved',identical(mi_hashes(names(z$hashes)),z$hashes))
 else record('accepted_imputation_checkpoints_preserved',identical(mi_hashes(names(z$checkpoint_hashes)),z$checkpoint_hashes))
}
manifest<-read.csv(file.path(root,'input_manifest.csv'))
record('report_source_hashes_match',identical(unname(mi_hashes(manifest$path)),manifest$md5))
summary<-read.csv(file.path(root,'integrated_primary_MI.csv'),check.names=FALSE)
record('report_primary_estimate',summary[['HR (95% CI)']][summary$Analysis=='Primary']=='1.130 (1.109–1.151)')
record('report_mi_estimate',summary[['HR (95% CI)']][summary$Analysis=='Multiple imputation']=='1.135 (1.115–1.156)')
record('three_pngs_three_svgs',length(list.files(file.path(root,'figures'),pattern='\\.png$'))==3L&&length(list.files(file.path(root,'figures'),pattern='\\.svg$'))==3L)
result<-do.call(rbind,checks);print(result);stopifnot(all(result$passed));write.csv(result,out,row.names=FALSE)
# Include all numerical figure sources as well as the report's copied aggregate sources.
figure_inputs<-c('output/tables/table_06_sensitivity_analyses.csv',
 'output/tables/table_07_alternative_age_sensitivity.csv',
 'output/tables/mi15_20261014_fourworker_v1_v2_pooled.csv',
 'output/tables/figure_data_01_crp_spline.csv','output/tables/table_08_effect_modifier_contrasts.csv')
all_inputs<-unique(c(manifest$path,figure_inputs))
write.csv(data.frame(path=all_inputs,md5=unname(mi_hashes(all_inputs))),file.path(root,'validated_input_manifest.csv'),row.names=FALSE)
