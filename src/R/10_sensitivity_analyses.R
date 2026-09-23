#!/usr/bin/env Rscript

# Prespecified sensitivity analyses for the primary survey-weighted Cox model.
#
# This script evaluates robustness of the prespecified primary linear summary:
# the adjusted hazard ratio for all-cause mortality per doubling of baseline CRP.
#
# Implemented here:
#   1. Exclude deaths within 12 months.
#   2. Exclude deaths within 24 months.
#   3. Exclude CRP > 10 mg/L.
#   4. Replace below-detection CRP fill values with the nominal detection limit.
#   5. Exclude below-detection CRP observations.
#   6. Add family income-to-poverty ratio.
#   9. Compare weighted and unweighted estimates as a diagnostic.
#  10. Exclude participants aged 20-44 years with indeterminate pregnancy status.
#
# Not implemented in this script:
#   7. Multiple imputation: requires a dedicated imputation workflow.
#   8. Alternative age specification: the frozen SAP does not define the
#      alternative functional form, so it must not be invented post hoc.
#
# These analyses are secondary. They do not replace the Stage 3 conclusion
# concerning time variation in the CRP association.

source(file.path("src", "R", "00_config.R"))
source(file.path("src", "R", "00_functions_data.R"))
source(file.path("src", "R", "00_functions_analysis.R"))

assert_project_root()
require_package("survey")
require_package("survival")
require_package("splines")

cohort_path <- file.path(paths$processed, "primary_complete_case_cohort.rds")
constants_path <- file.path(paths$processed, "analysis_constants.rds")
primary_models_path <- file.path(paths$processed, "primary_cox_models.rds")

required_files <- c(cohort_path, constants_path, primary_models_path)

if (any(!file.exists(required_files))) {
  stop("Run analysis scripts 04 through 06 before script 10.", call. = FALSE)
}

cohort <- readRDS(cohort_path)
analysis_constants <- readRDS(constants_path)
primary_models <- readRDS(primary_models_path)

if (nrow(cohort) != analysis_constants$participant_n ||
    sum(cohort$death) != analysis_constants$death_n) {
  stop(
    "Primary complete-case cohort does not match frozen analysis constants.",
    call. = FALSE
  )
}

required_variables <- c(
  "SEQN", "follow_up_months", "death", "log2_crp", "crp_mg_l",
  "below_detection_fill", "crp_above_10_mg_l", "income_poverty_ratio",
  "pregnancy_unknown", "age", "sex", "race_hispanic_origin", "cycle",
  "education", "smoking", "bmi", "diabetes", "hypertension",
  "prevalent_cvd", "SDMVSTRA", "SDMVPSU", "pooled_mec_weight"
)

missing_variables <- setdiff(required_variables, names(cohort))
if (length(missing_variables) > 0L) {
  stop(
    "Missing variables required for sensitivity analyses: ",
    paste(missing_variables, collapse = ", "),
    call. = FALSE
  )
}

if (anyDuplicated(cohort$SEQN)) {
  stop("Duplicate SEQN in primary complete-case cohort.", call. = FALSE)
}

if (any(is.na(cohort$death) | !cohort$death %in% c(0, 1))) {
  stop(
    "Invalid mortality status in primary complete-case cohort.",
    call. = FALSE
  )
}

if (any(is.na(cohort$follow_up_months) | cohort$follow_up_months <= 0)) {
  stop(
    "Invalid follow-up time in primary complete-case cohort.",
    call. = FALSE
  )
}

cohort <- add_age_spline_basis(cohort, analysis_constants$age_knots)

primary_formula <- survival::Surv(follow_up_months, death) ~
  log2_crp + age_rcs1 + age_rcs2 + age_rcs3 +
  sex + race_hispanic_origin + cycle + education + smoking + bmi +
  diabetes + hypertension + prevalent_cvd

income_formula <- update(primary_formula, . ~ . + income_poverty_ratio)

base_design <- build_survey_design(cohort)

subset_survey_design <- function(design, keep) {
  if (length(keep) != nrow(design$variables)) {
    stop("Survey subset indicator has incorrect length.", call. = FALSE)
  }
  if (any(is.na(keep))) {
    stop("Survey subset indicator contains missing values.", call. = FALSE)
  }

  design$variables$.sensitivity_keep <- as.logical(keep)
  result <- subset(design, .sensitivity_keep)
  result$variables$.sensitivity_keep <- NULL

  if (nrow(result$variables) == 0L) {
    stop("Sensitivity subset contains no participants.", call. = FALSE)
  }

  result
}

tidy_exposure <- function(model, analysis_name, analysis_type,
                          participants, deaths, design_df = NA_real_) {
  coefficients <- stats::coef(model)
  variance <- stats::vcov(model)

  if (!"log2_crp" %in% names(coefficients)) {
    stop(
      "CRP coefficient is absent from model: ",
      analysis_name,
      call. = FALSE
    )
  }

  if (any(!is.finite(coefficients)) || any(!is.finite(variance))) {
    stop(
      "Non-finite model estimates detected: ",
      analysis_name,
      call. = FALSE
    )
  }

  estimate <- unname(coefficients["log2_crp"])
  standard_error <- sqrt(unname(variance["log2_crp", "log2_crp"]))
  confidence_multiplier <- stats::qnorm(1 - analysis_alpha / 2)
  z_value <- estimate / standard_error

  data.frame(
    analysis = analysis_name,
    analysis_type = analysis_type,
    participants = as.integer(participants),
    deaths = as.integer(deaths),
    design_degrees_of_freedom = as.numeric(design_df),
    log_hazard_ratio = estimate,
    standard_error = standard_error,
    hazard_ratio = exp(estimate),
    confidence_low = exp(
      estimate - confidence_multiplier * standard_error
    ),
    confidence_high = exp(
      estimate + confidence_multiplier * standard_error
    ),
    p_value = 2 * stats::pnorm(
      abs(z_value),
      lower.tail = FALSE
    ),
    stringsAsFactors = FALSE
  )
}

fit_survey_sensitivity <- function(design, analysis_name,
                                   formula = primary_formula) {
  participants <- nrow(design$variables)
  deaths <- sum(design$variables$death)

  if (participants < 1L || deaths < 1L) {
    stop(
      "Sensitivity analysis has insufficient observations/events: ",
      analysis_name,
      call. = FALSE
    )
  }

  model <- survey::svycoxph(
    formula,
    design = design,
    method = "efron",
    model = TRUE
  )

  validate_cox_model(model)

  list(
    model = model,
    result = tidy_exposure(
      model = model,
      analysis_name = analysis_name,
      analysis_type = "survey-weighted sensitivity",
      participants = participants,
      deaths = deaths,
      design_df = survey::degf(design)
    )
  )
}

fit_unweighted_diagnostic <- function(data) {
  model <- survival::coxph(
    primary_formula,
    data = data,
    method = "efron",
    model = TRUE,
    x = FALSE,
    y = FALSE
  )

  validate_cox_model(model)

  list(
    model = model,
    result = tidy_exposure(
      model = model,
      analysis_name = "Unweighted diagnostic",
      analysis_type = "unweighted diagnostic",
      participants = nrow(data),
      deaths = sum(data$death),
      design_df = NA_real_
    )
  )
}

# Primary-model refit for reproducibility.
primary_refit <- fit_survey_sensitivity(
  base_design,
  "Primary reference"
)

saved_primary <- primary_models$primary
validate_cox_model(saved_primary)

saved_primary_crp <- unname(stats::coef(saved_primary)["log2_crp"])
refit_primary_crp <- unname(
  stats::coef(primary_refit$model)["log2_crp"]
)

if (!isTRUE(all.equal(
  saved_primary_crp,
  refit_primary_crp,
  tolerance = 1e-10
))) {
  stop(
    "Primary-model refit does not reproduce the saved CRP coefficient.",
    call. = FALSE
  )
}

primary_refit$result$analysis_type <- "primary reference"

# Early-death exclusions.
# The SAP wording is implemented literally: remove participants whose observed
# death occurred at or before the specified month; retain all others.
exclude_deaths_12_keep <- !(
  cohort$death == 1 &
    cohort$follow_up_months <= 12
)

exclude_deaths_24_keep <- !(
  cohort$death == 1 &
    cohort$follow_up_months <= 24
)

exclude_deaths_12 <- fit_survey_sensitivity(
  subset_survey_design(base_design, exclude_deaths_12_keep),
  "Exclude deaths within 12 months"
)

exclude_deaths_24 <- fit_survey_sensitivity(
  subset_survey_design(base_design, exclude_deaths_24_keep),
  "Exclude deaths within 24 months"
)

# Exclude CRP > 10 mg/L.
exclude_high_crp <- fit_survey_sensitivity(
  subset_survey_design(
    base_design,
    !cohort$crp_above_10_mg_l
  ),
  "Exclude CRP > 10 mg/L"
)

# Alternative handling of below-detection CRP.
# 0.02 mg/dL = 0.2 mg/L.
bdl_replacement_design <- base_design

bdl_replacement_design$variables$log2_crp[
  bdl_replacement_design$variables$below_detection_fill
] <- log2(0.2)

replace_bdl <- fit_survey_sensitivity(
  bdl_replacement_design,
  "Replace below-detection CRP with 0.02 mg/dL"
)

exclude_bdl <- fit_survey_sensitivity(
  subset_survey_design(
    base_design,
    !cohort$below_detection_fill
  ),
  "Exclude below-detection CRP"
)

# Add family income-to-poverty ratio.
income_keep <- !is.na(cohort$income_poverty_ratio)

income_sensitivity <- fit_survey_sensitivity(
  subset_survey_design(base_design, income_keep),
  "Add family income-to-poverty ratio",
  formula = income_formula
)

expected_income_n <- unname(
  preoutcome_expected_counts["primary_and_income_complete"]
)

if (income_sensitivity$result$participants != expected_income_n) {
  stop(
    "Income sensitivity cohort does not match the frozen pre-outcome count.",
    call. = FALSE
  )
}

# Weighted versus unweighted diagnostic.
unweighted_diagnostic <- fit_unweighted_diagnostic(cohort)

# Exclude indeterminate pregnancy status among ages 20-44.
exclude_unknown_pregnancy <- fit_survey_sensitivity(
  subset_survey_design(
    base_design,
    !cohort$pregnancy_unknown
  ),
  "Exclude indeterminate pregnancy status, ages 20-44"
)

# Combine results.
results <- do.call(
  rbind,
  list(
    primary_refit$result,
    exclude_deaths_12$result,
    exclude_deaths_24$result,
    exclude_high_crp$result,
    replace_bdl$result,
    exclude_bdl$result,
    income_sensitivity$result,
    unweighted_diagnostic$result,
    exclude_unknown_pregnancy$result
  )
)

primary_log_hr <- results$log_hazard_ratio[
  results$analysis == "Primary reference"
]

if (length(primary_log_hr) != 1L || !is.finite(primary_log_hr)) {
  stop("Could not identify the primary reference estimate.", call. = FALSE)
}

results$log_hr_difference_from_primary <-
  results$log_hazard_ratio - primary_log_hr

results$hazard_ratio_ratio_to_primary <-
  exp(results$log_hr_difference_from_primary)

# QC summary.
sensitivity_qc <- data.frame(
  analysis = results$analysis,
  participants = results$participants,
  deaths = results$deaths,
  participant_difference_from_primary =
    results$participants - analysis_constants$participant_n,
  death_difference_from_primary =
    results$deaths - analysis_constants$death_n,
  finite_log_hazard_ratio = is.finite(results$log_hazard_ratio),
  finite_standard_error = is.finite(results$standard_error),
  finite_confidence_interval =
    is.finite(results$confidence_low) &
    is.finite(results$confidence_high),
  stringsAsFactors = FALSE
)

if (!all(
  sensitivity_qc$finite_log_hazard_ratio &
    sensitivity_qc$finite_standard_error &
    sensitivity_qc$finite_confidence_interval
)) {
  stop("Non-finite sensitivity-analysis results detected.", call. = FALSE)
}

deferred_sensitivities <- data.frame(
  sap_item = c(
    "Multiple imputation for missing covariates",
    "Alternative age specification"
  ),
  status = c(
    "Deferred to dedicated analysis script",
    "Not implemented pending prospective specification"
  ),
  reason = c(
    paste(
      "Requires the prespecified 50-dataset imputation workflow,",
      "including imputation-model construction and Rubin pooling."
    ),
    paste(
      "The frozen SAP prespecifies an alternative age specification",
      "but does not define its functional form."
    )
  ),
  stringsAsFactors = FALSE
)

models <- list(
  primary_reference = primary_refit$model,
  exclude_deaths_12_months = exclude_deaths_12$model,
  exclude_deaths_24_months = exclude_deaths_24$model,
  exclude_crp_above_10_mg_l = exclude_high_crp$model,
  replace_below_detection_crp = replace_bdl$model,
  exclude_below_detection_crp = exclude_bdl$model,
  add_income_poverty_ratio = income_sensitivity$model,
  unweighted_diagnostic = unweighted_diagnostic$model,
  exclude_indeterminate_pregnancy = exclude_unknown_pregnancy$model
)

# Save outputs.
saveRDS(
  list(
    models = models,
    results = results,
    qc = sensitivity_qc,
    deferred_sensitivities = deferred_sensitivities,
    analysis_constants = analysis_constants
  ),
  file.path(paths$processed, "sensitivity_analysis_models.rds"),
  version = 3
)

write_csv_checked(
  results,
  file.path(paths$tables, "table_06_sensitivity_analyses.csv")
)

write_csv_checked(
  sensitivity_qc,
  file.path(paths$tables, "qc_10_sensitivity_analyses.csv")
)

write_csv_checked(
  deferred_sensitivities,
  file.path(paths$tables, "qc_10_deferred_sensitivities.csv")
)

message("Sensitivity analyses completed.")
message("Primary reference participants: ", analysis_constants$participant_n)
message("Primary reference deaths: ", analysis_constants$death_n)
message("Completed sensitivity estimates: ", nrow(results) - 1L)
message(
  "Deferred SAP sensitivities: ",
  paste(deferred_sensitivities$sap_item, collapse = "; ")
)
