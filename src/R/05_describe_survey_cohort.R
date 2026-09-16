#!/usr/bin/env Rscript

# Audit the complex survey design, describe the complete-case cohort and freeze
# survey-weighted spline knots before association modelling.

source(file.path("src", "R", "00_config.R"))
source(file.path("src", "R", "00_functions_data.R"))
source(file.path("src", "R", "00_functions_analysis.R"))

assert_project_root()
require_package("survey")

cohort_path <- file.path(
  paths$processed,
  "primary_complete_case_cohort.rds"
)
if (!file.exists(cohort_path)) {
  stop("Run src/R/04_build_analysis_cohort.R first.", call. = FALSE)
}
cohort <- readRDS(cohort_path)

if (nrow(cohort) != unname(preoutcome_expected_counts["primary_complete"])) {
  stop("Primary complete-case cohort count is not reconciled.", call. = FALSE)
}
if (anyDuplicated(cohort$SEQN)) {
  stop("Duplicate SEQN in primary complete-case cohort.", call. = FALSE)
}
if (any(is.na(cohort$death) | !cohort$death %in% c(0, 1))) {
  stop("Invalid mortality status.", call. = FALSE)
}
if (any(is.na(cohort$follow_up_months) | cohort$follow_up_months <= 0)) {
  stop("Invalid analysis follow-up time.", call. = FALSE)
}

design <- build_survey_design(cohort)

stratum_psu <- aggregate(
  cohort$SDMVPSU,
  by = list(stratum = cohort$SDMVSTRA),
  FUN = function(x) length(unique(x))
)
names(stratum_psu)[2] <- "psu_n"

design_audit <- data.frame(
  measure = c(
    "participants", "deaths", "sampling_strata", "nested_psus",
    "singleton_strata", "design_degrees_of_freedom",
    "pooled_weight_min", "pooled_weight_median", "pooled_weight_max"
  ),
  value = c(
    nrow(cohort),
    sum(cohort$death),
    length(unique(cohort$SDMVSTRA)),
    nrow(unique(cohort[c("SDMVSTRA", "SDMVPSU")])),
    sum(stratum_psu$psu_n < 2),
    survey::degf(design),
    min(cohort$pooled_mec_weight),
    median(cohort$pooled_mec_weight),
    max(cohort$pooled_mec_weight)
  ),
  stringsAsFactors = FALSE
)

continuous_variables <- c(
  age = "Age, years",
  bmi = "Body mass index, kg/m2",
  crp_mg_l = "C-reactive protein, mg/L",
  log2_crp = "Log2 C-reactive protein",
  follow_up_years = "Follow-up, years"
)
categorical_variables <- c(
  sex = "Sex",
  race_hispanic_origin = "Race and Hispanic origin",
  education = "Educational attainment",
  smoking = "Smoking status",
  diabetes = "Diabetes",
  hypertension = "Hypertension",
  prevalent_cvd = "Prevalent cardiovascular disease",
  cycle = "NHANES cycle"
)

continuous_table <- do.call(
  rbind,
  lapply(names(continuous_variables), function(variable) {
    continuous_summary(design, variable, continuous_variables[[variable]])
  })
)
categorical_table <- do.call(
  rbind,
  lapply(names(categorical_variables), function(variable) {
    categorical_summary(design, variable, categorical_variables[[variable]])
  })
)
baseline_table <- rbind(continuous_table, categorical_table)

knot_probabilities <- c(0.05, 0.35, 0.65, 0.95)
age_knots <- survey_quantiles(design, "age", knot_probabilities)
crp_knots <- survey_quantiles(design, "log2_crp", knot_probabilities)

knot_table <- rbind(
  data.frame(
    variable = "age",
    probability = knot_probabilities,
    value = as.numeric(age_knots),
    stringsAsFactors = FALSE
  ),
  data.frame(
    variable = "log2_crp",
    probability = knot_probabilities,
    value = as.numeric(crp_knots),
    stringsAsFactors = FALSE
  )
)

analysis_constants <- list(
  generated_from = "primary_complete_case_cohort.rds",
  participant_n = nrow(cohort),
  death_n = sum(cohort$death),
  age_knots = age_knots,
  log2_crp_knots = crp_knots
)

saveRDS(
  analysis_constants,
  file.path(paths$processed, "analysis_constants.rds"),
  version = 3
)
write_csv_checked(
  design_audit,
  file.path(paths$tables, "qc_05_survey_design.csv")
)
write_csv_checked(
  baseline_table,
  file.path(paths$tables, "table_01_weighted_baseline_characteristics.csv")
)
write_csv_checked(
  knot_table,
  file.path(paths$tables, "qc_05_spline_knots.csv")
)

message("Survey design degrees of freedom: ", survey::degf(design))
message("Frozen age knots: ", paste(round(age_knots, 4), collapse = ", "))
message("Frozen log2(CRP) knots: ", paste(round(crp_knots, 4), collapse = ", "))
message("No association model has been fitted.")
