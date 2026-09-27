#!/usr/bin/env Rscript

# Alternative linear-age sensitivity analysis (Amendment 003).
# This is a secondary, post-primary-analysis specification. It changes only
# the age functional form; it does not supersede the primary age-spline model.
# Execute from the repository root, after scripts 04 through 06.

source(file.path("src", "R", "00_config.R"))
source(file.path("src", "R", "00_functions_data.R"))
source(file.path("src", "R", "00_functions_analysis.R"))

assert_project_root()
require_package("survey")
require_package("survival")
require_package("splines")

amendment_path <- file.path(
  "protocol", "amendments", "amendment_003_alternative_age_specification.md"
)
cohort_path <- file.path(paths$processed, "primary_complete_case_cohort.rds")
constants_path <- file.path(paths$processed, "analysis_constants.rds")
models_path <- file.path(paths$processed, "primary_cox_models.rds")
required <- c(amendment_path, cohort_path, constants_path, models_path)
if (any(!file.exists(required))) {
  stop(
    "Missing prerequisite(s): ",
    paste(required[!file.exists(required)], collapse = ", "),
    call. = FALSE
  )
}

cohort <- readRDS(cohort_path)
constants <- readRDS(constants_path)
saved_models <- readRDS(models_path)

required_columns <- c(
  "SEQN", "follow_up_months", "death", "log2_crp", "age", "sex",
  "race_hispanic_origin", "cycle", "education", "smoking", "bmi",
  "diabetes", "hypertension", "prevalent_cvd", "pooled_mec_weight",
  "SDMVSTRA", "SDMVPSU"
)
missing_columns <- setdiff(required_columns, names(cohort))
if (length(missing_columns)) {
  stop("Missing analytic variables: ", paste(missing_columns, collapse = ", "),
       call. = FALSE)
}
if (!identical(nrow(cohort), as.integer(constants$participant_n)) ||
    sum(cohort$death) != constants$death_n ||
    anyDuplicated(cohort$SEQN) ||
    anyNA(cohort[, required_columns]) ||
    any(!cohort$death %in% c(0, 1)) ||
    any(cohort$follow_up_months <= 0) ||
    any(!is.finite(cohort$log2_crp)) ||
    any(!is.finite(cohort$age))) {
  stop("Frozen cohort count, identifiers, or analysis-variable QC failed.",
       call. = FALSE)
}
if (nrow(cohort) != 26818L || sum(cohort$death) != 5886L) {
  stop("Primary reference does not match expected Stage 4 QC counts.",
       call. = FALSE)
}
if (is.null(saved_models$primary)) {
  stop("Saved primary model is missing.", call. = FALSE)
}

# Recreate the original age spline solely for an exact primary-model check.
cohort <- add_age_spline_basis(cohort, constants$age_knots)
design <- build_survey_design(cohort)

primary_formula <- survival::Surv(follow_up_months, death) ~
  log2_crp + age_rcs1 + age_rcs2 + age_rcs3 +
  sex + race_hispanic_origin + cycle + education + smoking + bmi +
  diabetes + hypertension + prevalent_cvd

alternative_formula <- survival::Surv(follow_up_months, death) ~
  log2_crp + age +
  sex + race_hispanic_origin + cycle + education + smoking + bmi +
  diabetes + hypertension + prevalent_cvd

primary_terms <- attr(stats::terms(primary_formula), "term.labels")
alternative_terms <- attr(stats::terms(alternative_formula), "term.labels")
if (!setequal(
  setdiff(primary_terms, c("age_rcs1", "age_rcs2", "age_rcs3")),
  setdiff(alternative_terms, "age")
) || !"age" %in% alternative_terms ||
    any(grepl("^age_rcs", alternative_terms))) {
  stop("Alternative formula differs from primary beyond the age specification.",
       call. = FALSE)
}

primary_refit <- survey::svycoxph(
  primary_formula, design = design, method = "efron", model = TRUE
)
validate_cox_model(primary_refit)
validate_cox_model(saved_models$primary)

primary_beta <- unname(stats::coef(primary_refit)["log2_crp"])
saved_beta <- unname(stats::coef(saved_models$primary)["log2_crp"])
if (!isTRUE(all.equal(primary_beta, saved_beta, tolerance = 1e-10))) {
  stop("Primary-model refit fails to reproduce the saved CRP coefficient.",
       call. = FALSE)
}

# The only modeling change is a single continuous linear age term.
alternative_model <- survey::svycoxph(
  alternative_formula, design = design, method = "efron", model = TRUE
)
validate_cox_model(alternative_model)
if (!"age" %in% names(stats::coef(alternative_model)) ||
    any(grepl("^age_rcs", names(stats::coef(alternative_model))))) {
  stop("Alternative model age-term QC failed.", call. = FALSE)
}

extract_crp <- function(model, label) {
  beta <- unname(stats::coef(model)["log2_crp"])
  v <- stats::vcov(model)
  se <- sqrt(unname(v["log2_crp", "log2_crp"]))
  if (!is.finite(beta) || !is.finite(se) || se <= 0 ||
      any(!is.finite(v))) {
    stop("Non-finite CRP estimate or variance in ", label, call. = FALSE)
  }
  z <- stats::qnorm(1 - analysis_alpha / 2)
  data.frame(
    model = label,
    participants = nrow(cohort),
    deaths = sum(cohort$death),
    design_degrees_of_freedom = survey::degf(design),
    log_hazard_ratio = beta,
    standard_error = se,
    hazard_ratio = exp(beta),
    confidence_low = exp(beta - z * se),
    confidence_high = exp(beta + z * se),
    p_value = 2 * stats::pnorm(abs(beta / se), lower.tail = FALSE),
    stringsAsFactors = FALSE
  )
}

results <- rbind(
  extract_crp(primary_refit, "Primary reference: spline age"),
  extract_crp(alternative_model, "Sensitivity: linear age")
)
if (nrow(results) != 2L ||
    any(!is.finite(results$hazard_ratio)) ||
    any(!is.finite(results$confidence_low)) ||
    any(!is.finite(results$confidence_high))) {
  stop("Sensitivity result QC failed.", call. = FALSE)
}
results$log_hr_difference_from_primary <-
  results$log_hazard_ratio - primary_beta
results$hazard_ratio_ratio_to_primary <-
  exp(results$log_hr_difference_from_primary)

qc <- data.frame(
  check = c(
    "amendment_present", "primary_reproduced", "participants",
    "deaths", "survey_design_df", "linear_age_only",
    "finite_coefficients_and_covariance"
  ),
  value = c(
    "TRUE", "TRUE", as.character(nrow(cohort)),
    as.character(sum(cohort$death)), as.character(survey::degf(design)),
    "TRUE", as.character(
      all(is.finite(stats::coef(alternative_model))) &&
      all(is.finite(stats::vcov(alternative_model)))
    )
  ),
  stringsAsFactors = FALSE
)

# Distinct outputs: do not overwrite the validated Script 10 results.
model_output <- file.path(
  paths$processed, "alternative_age_sensitivity_models.rds"
)
table_output <- file.path(
  paths$tables, "table_07_alternative_age_sensitivity.csv"
)
qc_output <- file.path(paths$tables, "qc_11_alternative_age_sensitivity.csv")
for (p in c(model_output, table_output, qc_output)) {
  if (file.exists(p)) {
    stop("Output already exists; review before replacing: ", p,
         call. = FALSE)
  }
}

dir.create(paths$processed, recursive = TRUE, showWarnings = FALSE)
saveRDS(
  list(primary_reference = primary_refit,
       alternative_age = alternative_model,
       comparison = results,
       qc = qc,
       analysis_constants = constants),
  model_output, version = 3
)
write_csv_checked(results, table_output)
write_csv_checked(qc, qc_output)

message("Alternative linear-age sensitivity completed.")
message("Participants: ", nrow(cohort), "; deaths: ", sum(cohort$death))
message("Design degrees of freedom: ", survey::degf(design))
message("Primary CRP HR: ", format(results$hazard_ratio[1], digits = 6))
message("Alternative-age CRP HR: ", format(results$hazard_ratio[2], digits = 6))
message("Wrote: ", table_output)
message("Wrote: ", qc_output)
