#!/usr/bin/env Rscript
# Amendment 001: exclude same-month deaths from the primary complete-case model.
# Separate versioned outputs; never overwrite the accepted analyses.
source('src/R/00_config.R')
source('src/R/00_functions_data.R')
source('src/R/00_functions_analysis.R')
source('src/R/00_functions_imputation_execution.R')
assert_project_root()
require_package('survey'); require_package('survival'); require_package('splines')
out <- 'reports/same_month_death_sensitivity_v1'
model_out <- 'data/processed/same_month_death_sensitivity_v1.rds'
if (dir.exists(out) || file.exists(model_out)) stop('Outputs exist; use a new version.')
inputs <- c('src/R/22_sensitivity_same_month_deaths.R',
 'protocol/amendments/001_zero_followup_time.qmd',
 'data/processed/mortality_linked_eligible_cohort.rds',
 'data/processed/primary_complete_case_cohort.rds',
 'data/processed/analysis_constants.rds', 'data/processed/primary_cox_models.rds')
before <- mi_hashes(inputs)
checks <- list()
check <- function(name, pass) {
 checks[[length(checks)+1L]] <<- data.frame(check=name, passed=isTRUE(pass))
 if (!isTRUE(pass)) stop('Failed: ', name)
}
# Verify accepted artifacts before and after this analysis, without changing manifests.
preserved <- function() {
 a <- readRDS('data/processed/mi14_20261014_fourworker_v1/accepted_endpoint_020.rds')
 h <- a$checkpoint_hashes
 for (p in c('data/processed/mi15_20261014_fourworker_v1_v2/phase_complete.rds',
             'data/processed/reporting_stage6_v1_manifest.rds',
             'data/processed/methodological_manuscript_v1_manifest.rds')) {
   h <- c(h, readRDS(p)$hashes)
 }
 identical(mi_hashes(names(h)), h)
}
check('previous_artifacts_intact_before', preserved())
eligible <- readRDS(inputs[3]); d <- readRDS(inputs[4])
constants <- readRDS(inputs[5]); saved <- readRDS(inputs[6])$primary
flag <- eligible$zero_follow_up_death
check('four_eligible_same_month_deaths', !anyNA(flag) && sum(flag)==4L &&
 all(eligible$death[flag]==1) && all(eligible$follow_up_months_released[flag]==0) &&
 all(eligible$follow_up_months[flag]==0.5))
check('primary_cohort_counts', nrow(d)==26818L && sum(d$death)==5886L && !anyDuplicated(d$SEQN))
remove <- d$SEQN %in% eligible$SEQN[flag]
check('two_same_month_deaths_in_complete_cases', sum(remove)==2L &&
 identical(remove, as.logical(d$zero_follow_up_death)))
check('other_two_ineligible_for_complete_cases',
 all(!eligible$primary_complete[flag & !eligible$SEQN %in% d$SEQN]))
d <- add_age_spline_basis(d, constants$age_knots)
design <- build_survey_design(d)
formula <- survival::Surv(follow_up_months, death) ~
 log2_crp + age_rcs1 + age_rcs2 + age_rcs3 + sex + race_hispanic_origin +
 cycle + education + smoking + bmi + diabetes + hypertension + prevalent_cvd
check('primary_formula_unchanged', identical(attr(terms(formula),'term.labels'),
 attr(terms(saved),'term.labels')))
reference <- mi_strict(survey::svycoxph(formula, design=design, method='efron', model=TRUE))
check('all_primary_coefficients_reproduced',
 isTRUE(all.equal(coef(reference),coef(saved),tolerance=1e-10)))
check('primary_covariance_reproduced',
 isTRUE(all.equal(vcov(reference),vcov(saved),tolerance=1e-10)))
design$variables$.keep <- !remove
restricted <- subset(design, .keep)
restricted$variables$.keep <- NULL
check('only_requested_rows_removed', identical(restricted$variables, d[!remove,]))
fit <- mi_strict(survey::svycoxph(formula, design=restricted, method='efron', model=TRUE))
validate_cox_model(fit)
check('positive_exposure_variance', vcov(fit)['log2_crp','log2_crp']>0)
check('remaining_sample_counts', nrow(restricted$variables)==26816L &&
 sum(restricted$variables$death)==5884L)
extract <- function(m, des, label) {
 x <- tidy_svycoxph(m, label)
 x <- x[x$term=='log2_crp',]
 x$participants <- nrow(des$variables)
 x$deaths <- sum(des$variables$death)
 x$design_df <- survey::degf(des)
 x
}
result <- rbind(extract(reference,design,'Primary reference'),
 extract(fit,restricted,'Exclude same-month deaths'))
result$log_hr_difference <- result$log_hazard_ratio-result$log_hazard_ratio[1]
result$hr_ratio_to_primary <- result$hazard_ratio/result$hazard_ratio[1]
check('confidence_interval_independent_check', isTRUE(all.equal(
 exp(coef(fit)['log2_crp'] + c(-1,1)*qnorm(.975)*sqrt(vcov(fit)['log2_crp','log2_crp'])),
 unname(c(result$confidence_low[2],result$confidence_high[2])),check.attributes=FALSE)))
check('inputs_unchanged', identical(mi_hashes(inputs),before))
check('previous_artifacts_intact_after', preserved())
audit <- do.call(rbind,lapply(split(eligible,eligible$cycle), function(x)
 data.frame(cycle=as.character(x$cycle[1]),
 eligible_same_month_deaths=sum(x$zero_follow_up_death),
 complete_case_same_month_deaths=sum(x$zero_follow_up_death & x$primary_complete))))
dir.create(out,recursive=TRUE)
write.csv(result,file.path(out,'comparison.csv'),row.names=FALSE)
write.csv(audit,file.path(out,'exclusion_audit.csv'),row.names=FALSE)
write.csv(do.call(rbind,checks),file.path(out,'validation.csv'),row.names=FALSE)
write.csv(data.frame(path=inputs,md5=unname(before)),file.path(out,'inputs.csv'),row.names=FALSE)
mi_atomic_save(list(created=Sys.time(),formula=formula,age_knots=constants$age_knots,
 coefficients=coef(fit),covariance=vcov(fit),comparison=result,
 input_hashes=before,hashes=mi_hashes(list.files(out,full.names=TRUE))),model_out)
print(result)
message('Amendment 001 sensitivity completed; original analyses preserved.')
