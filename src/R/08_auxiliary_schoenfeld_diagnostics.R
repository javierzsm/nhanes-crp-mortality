#!/usr/bin/env Rscript

# Supportive proportional-hazards diagnostics. These do not replace the planned
# design-based CRP-by-log-time test.

source(file.path("src", "R", "00_config.R"))
source(file.path("src", "R", "00_functions_data.R"))
source(file.path("src", "R", "00_functions_analysis.R"))

assert_project_root()
require_package("survival")
require_package("splines")

cohort_path <- file.path(paths$processed, "primary_complete_case_cohort.rds")
constants_path <- file.path(paths$processed, "analysis_constants.rds")
if (!file.exists(cohort_path) || !file.exists(constants_path)) {
  stop("Run analysis scripts 04 and 05 first.", call. = FALSE)
}

cohort <- readRDS(cohort_path)
analysis_constants <- readRDS(constants_path)
cohort <- add_age_spline_basis(cohort, analysis_constants$age_knots)
cohort$analysis_weight <- cohort$pooled_mec_weight /
  mean(cohort$pooled_mec_weight)
cohort$survey_cluster <- interaction(
  cohort$SDMVSTRA,
  cohort$SDMVPSU,
  drop = TRUE
)

auxiliary_formula <- survival::Surv(follow_up_months, death) ~
  log2_crp + age_rcs1 + age_rcs2 + age_rcs3 +
  sex + race_hispanic_origin + cycle + education + smoking + bmi +
  diabetes + hypertension + prevalent_cvd + cluster(survey_cluster)

auxiliary_model <- survival::coxph(
  auxiliary_formula,
  data = cohort,
  weights = analysis_weight,
  method = "efron",
  x = TRUE,
  model = TRUE
)
if (any(!is.finite(stats::coef(auxiliary_model)))) {
  stop("Non-finite auxiliary Cox coefficients.", call. = FALSE)
}

ph_test <- survival::cox.zph(auxiliary_model, transform = "log")
ph_table <- data.frame(
  term = rownames(ph_test$table),
  chi_square = ph_test$table[, "chisq"],
  degrees_of_freedom = ph_test$table[, "df"],
  p_value = ph_test$table[, "p"],
  stringsAsFactors = FALSE
)

crp_column <- match("log2_crp", colnames(ph_test$y))
if (is.na(crp_column)) {
  stop("CRP residual column is absent from cox.zph output.", call. = FALSE)
}
residual_table <- data.frame(
  transformed_time = ph_test$x,
  log2_crp_scaled_schoenfeld = ph_test$y[, crp_column],
  stringsAsFactors = FALSE
)

saveRDS(
  list(model = auxiliary_model, cox_zph = ph_test),
  file.path(paths$processed, "auxiliary_schoenfeld_diagnostics.rds"),
  version = 3
)
write_csv_checked(
  ph_table,
  file.path(paths$tables, "table_04_auxiliary_schoenfeld_tests.csv")
)
write_csv_checked(
  residual_table,
  file.path(paths$tables, "figure_data_02_crp_schoenfeld.csv")
)

message("Auxiliary Schoenfeld diagnostics completed.")
message("These diagnostics are supportive and are not design-based inference.")
