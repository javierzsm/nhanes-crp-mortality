#!/usr/bin/env Rscript
# Assemble a manuscript draft from validated aggregate outputs; no model fitting.
Sys.setenv(TZ='Europe/Paris')
source('src/R/00_functions_imputation_execution.R')
root<-'reports/stage6_v1'
if(dir.exists(root))stop('Reporting package exists; use a new version.')
read_table<-function(name)read.csv(file.path('output/tables',name),check.names=FALSE)
primary<-read_table('table_02_primary_crp_hazard_ratios.csv')
spline<-read_table('table_03_crp_spline_contrasts.csv');spline_tests<-read_table('table_03_crp_spline_tests.csv')
periods<-read_table('table_05_crp_hr_by_followup_period.csv');time_test<-read_table('table_05_crp_time_interaction_test.csv')
sens<-read_table('table_06_sensitivity_analyses.csv');age_sens<-read_table('table_07_alternative_age_sensitivity.csv')
mod<-read_table('table_08_effect_modifier_contrasts.csv');mod_tests<-read_table('table_08_effect_modifier_tests.csv')
influence<-read_table('table_09_primary_influence_summary.csv')
mi<-read_table('mi15_20261014_fourworker_v1_v2_pooled.csv')
baseline<-read_table('table_01_weighted_baseline_characteristics.csv')
flow<-read_table('qc_04_cohort_flow.csv');missing<-read_table('qc_12_missingness_by_variable.csv')
inputs<-file.path('output/tables',c('table_01_weighted_baseline_characteristics.csv',
 'table_02_primary_crp_hazard_ratios.csv','table_03_crp_spline_contrasts.csv','table_03_crp_spline_tests.csv',
 'table_05_crp_hr_by_followup_period.csv','table_05_crp_time_interaction_test.csv',
 'table_06_sensitivity_analyses.csv','table_07_alternative_age_sensitivity.csv',
 'table_08_effect_modifier_contrasts.csv','table_08_effect_modifier_tests.csv',
 'table_08_interaction_ratios.csv','table_09_primary_influence_summary.csv',
 'mi15_20261014_fourworker_v1_v2_pooled.csv','qc_04_cohort_flow.csv','qc_12_missingness_by_variable.csv'))
cohort_file<-'data/processed/primary_complete_case_cohort.rds'
hashes<-mi_hashes(c(inputs,cohort_file,'data/processed/analysis_constants.rds'))
accepted<-readRDS('data/processed/mi15_20261014_fourworker_v1_v2/phase_complete.rds')
stopifnot(identical(mi_hashes(names(accepted$hashes)),accepted$hashes))
cohort<-readRDS(cohort_file)
stopifnot(nrow(cohort)==26818L,sum(cohort$death)==5886L)
followup<-data.frame(n=nrow(cohort),deaths=sum(cohort$death),
 unweighted_person_years=sum(cohort$follow_up_months)/12,
 unweighted_mean_years=mean(cohort$follow_up_months)/12,
 unweighted_median_years=median(cohort$follow_up_months)/12,
 min_years=min(cohort$follow_up_months)/12,max_years=max(cohort$follow_up_months)/12)
hr<-function(a,b,c)sprintf('%.3f (%.3f–%.3f)',a,b,c)
pfmt<-function(p)if(p<.001)'<0.001'else sprintf('%.3f',p)
md<-function(data) {
 data[]<-lapply(data,function(x) {x<-as.character(x);x[is.na(x)]<-'—';gsub('|','/',x,fixed=TRUE)})
 c(paste0('| ',paste(names(data),collapse=' | '),' |'),
 paste0('| ',paste(rep('---',ncol(data)),collapse=' | '),' |'),
 apply(data,1,function(z)paste0('| ',paste(z,collapse=' | '),' |')))
}
summary<-data.frame(Analysis=c(primary$model,'Multiple imputation'),
 Participants=c(26818L,26818L,27755L),Deaths=c(5886L,5886L,6354L),
 `HR (95% CI)`=c(hr(primary$hazard_ratio,primary$confidence_low,primary$confidence_high),
 hr(mi$HR,mi$CI_lower,mi$CI_upper)),check.names=FALSE)
period_table<-data.frame(Period=periods$followup_period,
 `HR per doubling (95% CI)`=hr(periods$hazard_ratio,periods$confidence_low,periods$confidence_high),check.names=FALSE)
mod_table<-data.frame(Modifier=mod$modifier,Group=mod$group,N=mod$participants,Deaths=mod$deaths,
 `HR per doubling (95% CI)`=hr(mod$hazard_ratio,mod$confidence_low,mod$confidence_high),check.names=FALSE)
sensitivity_table<-data.frame(Analysis=c(sens$analysis,age_sens$model[2],'Multiple imputation'),
 N=c(sens$participants,age_sens$participants[2],mi$n),Deaths=c(sens$deaths,age_sens$deaths[2],mi$deaths),
 `HR (95% CI)`=c(hr(sens$hazard_ratio,sens$confidence_low,sens$confidence_high),
 hr(age_sens$hazard_ratio[2],age_sens$confidence_low[2],age_sens$confidence_high[2]),hr(mi$HR,mi$CI_lower,mi$CI_upper)),check.names=FALSE)
stopifnot(nrow(summary)==3L,nrow(period_table)==4L,nrow(mod_table)==4L,nrow(sensitivity_table)==11L)
primary_row<-primary[primary$model=='Primary',]
lines<-c('# Baseline C-reactive protein and all-cause mortality in US adults: a survey-weighted NHANES cohort study',
 '', '**Working methods/results draft v0.1 — 23 October 2026.** Not submission-ready. Introduction, external literature discussion, author information, ethics determination, funding and disclosure statements require completion. Numbers are assembled from validated saved outputs; no new model selection is performed.',
 '', '## Abstract: analytical summary', '',
 sprintf('We analyzed NHANES 1999–2010 linked to public-use mortality records through 2019. The complete-case analysis included 26,818 adults and 5,886 deaths. The adjusted survey-weighted hazard ratio per doubling of baseline CRP was %s; the secondary 50-imputation estimate was %s.',
 hr(primary_row$hazard_ratio,primary_row$confidence_low,primary_row$confidence_high),hr(mi$HR,mi$CI_lower,mi$CI_upper)),
 sprintf('The CRP spline supported nonlinearity (p %s). The association varied across follow-up periods (interaction p = %s); secondary effect modification was observed by age group (p = %s), while the sex interaction was not clearly supported (p = %s). These findings describe adjusted prognostic associations and do not establish causality.',
 pfmt(spline_tests$p_value[spline_tests$test=='CRP nonlinearity']),pfmt(time_test$p_value),
 pfmt(mod_tests$p_value[mod_tests$modifier=='age_group']),pfmt(mod_tests$p_value[mod_tests$modifier=='sex'])),
 '', '## Methods', '', '### Design, participants and measurements', '',
 'This secondary cohort analysis pooled six NHANES cycles from 1999–2000 through 2009–2010, representing the civilian noninstitutionalized US adult population. Adults aged at least 20 years with positive baseline CRP, positive applicable MEC weight and public mortality-linkage eligibility were considered. Confirmed pregnancy was excluded. Indeterminate pregnancy status at ages 20–44 was retained primarily and examined in a sensitivity analysis. The study size comprises available eligible records rather than an outcome-driven sample-size calculation.',
 '', 'CRP was converted from mg/dL to mg/L and analyzed on the base-2 logarithmic scale. Released below-detection fill values were retained primarily. All-cause mortality status and MEC-examination follow-up months came from the public-use mortality linkage through 31 December 2019. Four same-month deaths were assigned 0.5 months under Amendment 001; original released follow-up was retained separately. Detailed covariate definitions and recoding algorithms are documented in the audit reports and data-construction scripts; these must be incorporated into a measurement supplement before submission.',
 '', '### Survey and primary modeling', '',
 'Primary inference used pooled MEC weights (WTMEC4YR/3 for 1999–2002; WTMEC2YR/6 for 2003–2010), strata and nested PSUs. There were 89 strata and 180 PSUs (91 design degrees of freedom). Survey-weighted Cox models used elapsed months from examination, Efron ties and design-based covariance. CRP was linear in log2 units in the primary model. Age used three natural-cubic spline terms with four percentile locations frozen before outcome modeling. The demographic model adjusted for age, sex, race/Hispanic origin and cycle. Primary adjustment additionally included education, smoking, BMI, diabetes, hypertension and prevalent CVD; covariates were not screened or selected for significance.',
 '', '### Functional form, follow-up variation and secondary interactions', '',
 'A restricted-cubic spline of log2(CRP), with frozen weighted percentile knots, assessed nonlinearity; planned contrasts compared 2, 4 and 8 mg/L with 1 mg/L. Design-based Wald F tests evaluated global association/nonlinearity. Amendment 002 replaced the planned log-time interaction with four follow-up periods (0–5, >5–10, >10–15, >15 years), estimated with counting-process Cox models and 180 sequential JKn replicates. A global three-df contrast tested equality of period-specific CRP coefficients. The constant primary HR is therefore an overall working-model summary, not a uniform effect at every CRP value or follow-up time.',
 '', 'Separate SAP-prespecified secondary models added CRP-by-sex and CRP-by-age-group (20–64 versus 65+) interactions. Both retained the primary covariates and continuous-age spline. The age-group model also included the group main effect to preserve hierarchy. Group HRs and their covariance-based normal intervals were linear contrasts of each interaction model; interaction tests used design-based Wald F tests with model-residual denominator df. The hypotheses and age boundary were prespecified; the detailed implementation was recorded on 23 October 2026 after other study results were known, before these estimates. Secondary tests received no general multiplicity correction and are interpreted cautiously.',
 '', '### Missing covariates and sensitivities', '',
 'Complete cases were primary. Fifty independent MICE chains provided a secondary missing-covariate sensitivity, with PMM for BMI, multinomial models for education/smoking/diabetes and binary logistic models for hypertension/CVD. Imputation predictors included analysis covariates, CRP, death, an unweighted marginal Nelson–Aalen auxiliary, log survey weight and a full-rank cycle/stratum/PSU representation. Exposure, outcome, follow-up and survey fields were not imputed. The three fixed age terms used frozen knots. Diagnostic review accepted 20 iterations before outcome-model fitting; short-window autocorrelation flags, rare categories and extreme observed BMI donors were retained and disclosed.',
 '', 'The unchanged primary survey-Cox model was fitted within each completed set; coefficients/design variances were combined with scalar Rubin rules and finite Barnard–Rubin t inference (complete-data survey df 91). This interval convention differs from the primary asymptotic Wald convention. Imputation assumes a working MAR mechanism conditional on included predictors and does not prove model adequacy. Prespecified sensitivities addressed early deaths, CRP >10 mg/L, below-detection handling, income adjustment, indeterminate pregnancy and an unweighted diagnostic; Amendment 003 introduced linear age after primary-result review.',
 '', '### Influence diagnostics and transparency', '',
 'Weighted DFBETA residuals from the saved primary Cox model described first-order coefficient contributions at participant and nested-PSU levels. Their absolute CRP component was scaled by the original design-based SE. Grouped residuals were checked against independently summed individual contributions. These are approximate diagnostics, not exact deletion refits or hypothesis tests; no participant/PSU was removed or pass/fail cutoff applied. The frozen SAP and numbered amendments remain unchanged; the present reporting reconciliation discloses previously unimplemented secondary items.',
 '', '## Results', '', '### Participants and baseline profile', '',
 'Of 28,924 adults with positive CRP and MEC weight, 28,890 were eligible for mortality linkage; excluding 1,135 confirmed pregnancies left 27,755 eligible participants. Primary covariates were complete for 26,818 (96.62%); 937 had at least one missing target. The complete-case cohort contained 5,886 deaths, versus 6,354 in the eligible cohort.',
 sprintf('Unweighted observed follow-up totaled %.1f person-years (median %.2f years). Survey-weighted mean age was %.2f years, median CRP %.2f mg/L and median follow-up %.2f years. Weighted and unweighted summaries are distinguished; observed deaths are not weighted population counts.',followup$unweighted_person_years,followup$unweighted_median_years,
 baseline$estimate[baseline$variable=='age'],baseline$weighted_median[baseline$variable=='crp_mg_l'],baseline$weighted_median[baseline$variable=='follow_up_years']),
 '', '### Primary and imputed estimates', '',md(summary),'',
 'Intervals for demographic/primary models use the original asymptotic normal convention; MI uses finite Barnard–Rubin t inference. The MI result is secondary and does not replace the complete-case estimand.',
 '', '### Nonlinearity and follow-up variation', '',
 sprintf('CRP nonlinearity was supported (F = %.3f, df %s and %s; p %s). Spline contrasts for 2, 4 and 8 mg/L versus 1 mg/L were respectively %s, %s and %s.',
 spline_tests$f_statistic[2],spline_tests$numerator_df[2],spline_tests$denominator_df[2],pfmt(spline_tests$p_value[2]),
 hr(spline$hazard_ratio[1],spline$confidence_low[1],spline$confidence_high[1]),
 hr(spline$hazard_ratio[2],spline$confidence_low[2],spline$confidence_high[2]),
 hr(spline$hazard_ratio[3],spline$confidence_low[3],spline$confidence_high[3])),
 '',md(period_table),'',
 sprintf('The global period-interaction test was F = %.3f (df %s, %s), p = %s. The pattern was not monotonically declining: the >15-year estimate increased relative to the preceding interval and had less precision. Period boundaries are analytical rather than biological thresholds.',time_test$f_statistic,time_test$numerator_df,time_test$denominator_df,pfmt(time_test$p_value)),
 '', '### Secondary effect modification', '',md(mod_table),'',md(mod_tests),
 '', 'The age interaction suggests heterogeneity of the linear summary on the multiplicative hazard scale; it does not establish a biological threshold at 65, modification on the absolute-risk scale, or a pattern invariant over time. The sex interaction does not establish equivalence of associations. Neither result warrants choosing a new primary model.',
 '', '### Sensitivities and influence', '',md(sensitivity_table),'',
 'The unweighted row is diagnostic only. Early-death exclusions remove deaths at or before the specified threshold, not a landmark cohort. Income adjustment changes both sample and adjustment set. Linear age was defined after primary results and is disclosed as such. These sensitivities do not resolve nonlinearity, PH departures or potential unmeasured bias.',
 sprintf('Maximum absolute first-order CRP contributions were %.3f design SE at participant level and %.3f at PSU level. These approximate diagnostics describe concentration; no deletions or exact leave-one-out claims are made.',influence$max_abs_SE[influence$unit_type=='participant'],influence$max_abs_SE[influence$unit_type=='nested_PSU']),
 '', '## Interpretation and work still required', '',
 'The adjusted CRP–mortality association is positive in the primary and sensitivity analyses. Its nonlinear form and variation over follow-up limit interpretation of a single HR. These are secondary observational prognostic associations, not evidence that changing CRP causes mortality changes. Residual confounding, selection/linkage eligibility, one-time exposure measurement, conditional-model/MAR assumptions and multiple secondary testing remain relevant limitations.',
 '', 'Before submission: complete source-based background/discussion; verify author/affiliation, ethics, funding and conflicts; specify data-access/linkage restrictions and external validation of recoding/definitions; finish measurement supplement; review target-journal format and reporting checklists. Do not claim RECORD/STROBE compliance solely because a checklist exists.',
 '', '## Reproducibility', '', 'This draft was assembled by `src/R/18_build_reporting_package.R` from existing validated aggregate outputs and the new prespecified secondary outputs. Input/code hashes and copied aggregate tables accompany this package. It does not replace or overwrite source analysis outputs. No new primary or MI model was fitted by this reporting script.')
stopifnot(identical(mi_hashes(names(hashes)),hashes))
dir.create(root,recursive=TRUE)
writeLines(lines,file.path(root,'manuscript_methods_results.md'),useBytes=TRUE)
for(i in seq_along(inputs))stopifnot(file.copy(inputs[i],file.path(root,basename(inputs[i])),overwrite=FALSE))
write.csv(followup,file.path(root,'followup_summary.csv'),row.names=FALSE)
write.csv(summary,file.path(root,'integrated_primary_MI.csv'),row.names=FALSE)
write.csv(sensitivity_table,file.path(root,'integrated_sensitivities.csv'),row.names=FALSE)
write.csv(data.frame(path=names(hashes),md5=unname(hashes)),file.path(root,'input_manifest.csv'),row.names=FALSE)
writeLines(unname(mi_hashes('src/R/18_build_reporting_package.R')),file.path(root,'generator_md5.txt'))
message('Versioned reporting package created at ',root)
