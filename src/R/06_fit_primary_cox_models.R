#!/usr/bin/env Rscript

# Fit the prespecified demographic and primary survey-weighted Cox models.

source(file.path("src", "R", "00_config.R"))
source(file.path("src", "R", "00_functions_data.R"))
source(file.path("src", "R", "00_functions_analysis.R"))

assert_project_root()
require_package("survey")
require_package("survival")
require_package("splines")

cohort_path <- file.path(
  paths$processed,
  "primary_complete_case_cohort.rds"
)
constants_path <- file.path(paths$processed, "analysis_constants.rds")
if (!file.exists(cohort_path) || !file.exists(constants_path)) {
  stop(
    "Run scripts 04_build_analysis_cohort.R and 05_describe_survey_cohort.R first.",
    call. = FALSE
  )
}

cohort <- readRDS(cohort_path)
analysis_constants <- readRDS(constants_path)

if (nrow(cohort) != analysis_constants$participant_n ||
    sum(cohort$death) != analysis_constants$death_n) {
  stop("Cohort does not match frozen analysis constants.", call. = FALSE)
}

cohort <- add_age_spline_basis(cohort, analysis_constants$age_knots)
design <- build_survey_design(cohort)

demographic_formula <- survival::Surv(follow_up_months, death) ~
  log2_crp + age_rcs1 + age_rcs2 + age_rcs3 +
  sex + race_hispanic_origin + cycle

primary_formula <- survival::Surv(follow_up_months, death) ~
  log2_crp + age_rcs1 + age_rcs2 + age_rcs3 +
  sex + race_hispanic_origin + cycle + education + smoking + bmi +
  diabetes + hypertension + prevalent_cvd

demographic_model <- survey::svycoxph(
  demographic_formula,
  design = design,
  method = "efron",
  model = TRUE
)
primary_model <- survey::svycoxph(
  primary_formula,
  design = design,
  method = "efron",
  model = TRUE
)

validate_cox_model(demographic_model)
validate_cox_model(primary_model)

model_table <- rbind(
  tidy_svycoxph(demographic_model, "Demographic"),
  tidy_svycoxph(primary_model, "Primary")
)
exposure_table <- model_table[model_table$term == "log2_crp", ]
if (nrow(exposure_table) != 2L) {
  stop("Expected one CRP estimate from each nested model.", call. = FALSE)
}

model_audit <- data.frame(
  model = c("Demographic", "Primary"),
  participants = c(nrow(cohort), nrow(cohort)),
  deaths = c(sum(cohort$death), sum(cohort$death)),
  coefficients = c(
    length(stats::coef(demographic_model)),
    length(stats::coef(primary_model))
  ),
  design_degrees_of_freedom = c(
    survey::degf(design), survey::degf(design)
  ),
  finite_coefficients = c(
    all(is.finite(stats::coef(demographic_model))),
    all(is.finite(stats::coef(primary_model)))
  ),
  finite_variance = c(
    all(is.finite(stats::vcov(demographic_model))),
    all(is.finite(stats::vcov(primary_model)))
  ),
  stringsAsFactors = FALSE
)

saveRDS(
  list(
    demographic = demographic_model,
    primary = primary_model,
    analysis_constants = analysis_constants
  ),
  file.path(paths$processed, "primary_cox_models.rds"),
  version = 3
)
write_csv_checked(
  exposure_table,
  file.path(paths$tables, "table_02_primary_crp_hazard_ratios.csv")
)
write_csv_checked(
  model_table,
  file.path(paths$tables, "table_02_all_model_coefficients.csv")
)
write_csv_checked(
  model_audit,
  file.path(paths$tables, "qc_06_primary_cox_models.csv")
)

primary_crp <- exposure_table[exposure_table$model == "Primary", ]
message("Primary model fitted to participants: ", nrow(cohort))
message("Observed deaths: ", sum(cohort$death))
message(
  "Primary HR per CRP doubling: ",
  format(round(primary_crp$hazard_ratio, 4), nsmall = 4),
  " (95% CI ",
  format(round(primary_crp$confidence_low, 4), nsmall = 4),
  " to ",
  format(round(primary_crp$confidence_high, 4), nsmall = 4),
  ")"
)
