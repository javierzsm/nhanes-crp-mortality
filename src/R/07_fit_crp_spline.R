#!/usr/bin/env Rscript

# Fit the prespecified four-knot restricted cubic spline for log2(CRP).

source(file.path("src", "R", "00_config.R"))
source(file.path("src", "R", "00_functions_data.R"))
source(file.path("src", "R", "00_functions_analysis.R"))

assert_project_root()
require_package("survey")
require_package("survival")
require_package("splines")

cohort_path <- file.path(paths$processed, "primary_complete_case_cohort.rds")
constants_path <- file.path(paths$processed, "analysis_constants.rds")
models_path <- file.path(paths$processed, "primary_cox_models.rds")
required_files <- c(cohort_path, constants_path, models_path)
if (any(!file.exists(required_files))) {
  stop("Run analysis scripts 04 through 06 first.", call. = FALSE)
}

cohort <- readRDS(cohort_path)
analysis_constants <- readRDS(constants_path)
primary_models <- readRDS(models_path)

if (nrow(cohort) != analysis_constants$participant_n ||
    sum(cohort$death) != analysis_constants$death_n) {
  stop("Cohort does not match frozen analysis constants.", call. = FALSE)
}

cohort <- add_age_spline_basis(cohort, analysis_constants$age_knots)
cohort <- add_crp_spline_basis(cohort, analysis_constants$log2_crp_knots)
design <- build_survey_design(cohort)

spline_formula <- survival::Surv(follow_up_months, death) ~
  crp_rcs_linear + crp_rcs_nonlinear1 + crp_rcs_nonlinear2 +
  age_rcs1 + age_rcs2 + age_rcs3 + sex + race_hispanic_origin + cycle +
  education + smoking + bmi + diabetes + hypertension + prevalent_cvd

spline_model <- survey::svycoxph(
  spline_formula,
  design = design,
  method = "efron",
  model = TRUE
)

validate_cox_model(spline_model, exposure = "crp_rcs_linear")

exposure_terms <- c(
  "crp_rcs_linear", "crp_rcs_nonlinear1", "crp_rcs_nonlinear2"
)
nonlinear_terms <- c("crp_rcs_nonlinear1", "crp_rcs_nonlinear2")
wald_tests <- rbind(
  design_wald_test(
    spline_model,
    exposure_terms,
    "Global CRP association"
  ),
  design_wald_test(
    spline_model,
    nonlinear_terms,
    "CRP nonlinearity"
  )
)

planned_contrasts <- do.call(
  rbind,
  lapply(c(2, 4, 8), function(value) {
    spline_contrast(
      spline_model,
      comparison_mg_l = value,
      reference_mg_l = 1,
      knots = analysis_constants$log2_crp_knots
    )
  })
)

display_bounds <- survey_quantiles(design, "crp_mg_l", c(0.01, 0.99))
curve_crp <- exp(seq(
  log(display_bounds[[1]]),
  log(display_bounds[[2]]),
  length.out = 200
))
curve_table <- do.call(
  rbind,
  lapply(curve_crp, function(value) {
    spline_contrast(
      spline_model,
      comparison_mg_l = value,
      reference_mg_l = 1,
      knots = analysis_constants$log2_crp_knots
    )
  })
)

linear_primary <- primary_models$primary
linear_estimate <- tidy_svycoxph(linear_primary, "Primary linear")
linear_estimate <- linear_estimate[linear_estimate$term == "log2_crp", ]

model_audit <- data.frame(
  measure = c(
    "participants", "deaths", "design_degrees_of_freedom",
    "model_coefficients", "finite_coefficients", "finite_variance",
    "curve_weighted_percentile_low", "curve_weighted_percentile_high"
  ),
  value = c(
    nrow(cohort),
    sum(cohort$death),
    survey::degf(design),
    length(stats::coef(spline_model)),
    all(is.finite(stats::coef(spline_model))),
    all(is.finite(stats::vcov(spline_model))),
    display_bounds[[1]],
    display_bounds[[2]]
  ),
  stringsAsFactors = FALSE
)

saveRDS(
  list(
    spline = spline_model,
    analysis_constants = analysis_constants,
    display_bounds_mg_l = display_bounds
  ),
  file.path(paths$processed, "crp_spline_model.rds"),
  version = 3
)
write_csv_checked(
  wald_tests,
  file.path(paths$tables, "table_03_crp_spline_tests.csv")
)
write_csv_checked(
  planned_contrasts,
  file.path(paths$tables, "table_03_crp_spline_contrasts.csv")
)
write_csv_checked(
  curve_table,
  file.path(paths$tables, "figure_data_01_crp_spline.csv")
)
write_csv_checked(
  linear_estimate,
  file.path(paths$tables, "qc_07_linear_model_reference.csv")
)
write_csv_checked(
  model_audit,
  file.path(paths$tables, "qc_07_crp_spline.csv")
)

message("Spline model fitted to participants: ", nrow(cohort))
message("Global CRP p-value: ", format(wald_tests$p_value[1], digits = 5))
message("CRP nonlinearity p-value: ", format(wald_tests$p_value[2], digits = 5))
message(
  "Curve display range, weighted percentiles 1 to 99: ",
  round(display_bounds[[1]], 4), " to ", round(display_bounds[[2]], 4),
  " mg/L"
)
