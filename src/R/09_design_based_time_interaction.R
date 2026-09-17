#!/usr/bin/env Rscript

# Design-based assessment of time-varying CRP association using prespecified
# follow-up periods. This replaces the computationally infeasible CRP-by-log-time
# implementation based on coxph(tt()).
#
# IMPORTANT: Do not execute this script until Amendment 002 has been registered.
#
# Follow-up periods:
#   0-5 years
#   >5-10 years
#   >10-15 years
#   >15 years
#
# Inference uses sequential JKn replicate-weight Cox fits. Replicates are fitted
# one at a time and checkpointed so execution can be resumed after interruption.

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

participant_n <- analysis_constants$participant_n
death_n <- analysis_constants$death_n

if (!all(c("SDMVSTRA", "SDMVPSU") %in% names(cohort))) {
  stop(
    "SDMVSTRA and SDMVPSU are required for survey QC.",
    call. = FALSE
  )
}

survey_strata_n <- length(unique(cohort$SDMVSTRA))
survey_psu_n <- length(unique(interaction(
  cohort$SDMVSTRA,
  cohort$SDMVPSU,
  drop = TRUE
)))

cohort <- add_age_spline_basis(cohort, analysis_constants$age_knots)
cohort$.analysis_row_id <- seq_len(nrow(cohort))

# -----------------------------------------------------------------------------
# 1. Original NHANES complex-survey design and JKn replicate weights
# -----------------------------------------------------------------------------

design <- build_survey_design(cohort)
design_df <- survey::degf(design)

rep_design <- survey::as.svrepdesign(
  design,
  type = "JKn",
  mse = TRUE
)

sampling_weights <- as.numeric(stats::weights(rep_design, type = "sampling"))
replicate_weights <- stats::weights(rep_design, type = "analysis")
replicate_weights <- as.matrix(replicate_weights)

if (nrow(replicate_weights) != nrow(cohort)) {
  stop("Unexpected JKn replicate-weight matrix dimensions.", call. = FALSE)
}
if (length(sampling_weights) != nrow(cohort)) {
  stop("Unexpected sampling-weight vector length.", call. = FALSE)
}
if (any(!is.finite(sampling_weights)) || any(sampling_weights <= 0)) {
  stop("Invalid full-sample survey weights.", call. = FALSE)
}
if (any(!is.finite(replicate_weights)) || any(replicate_weights < 0)) {
  stop("Invalid JKn replicate weights.", call. = FALSE)
}

n_replicates <- ncol(replicate_weights)
if (n_replicates < 2L) {
  stop("Too few JKn replicates were generated.", call. = FALSE)
}

jkn_scale <- rep_design$scale
jkn_rscales <- rep_design$rscales
jkn_mse <- rep_design$mse

rm(design, rep_design)
invisible(gc(verbose = FALSE))

# -----------------------------------------------------------------------------
# 2. Split follow-up into prespecified periods
# -----------------------------------------------------------------------------

period_cuts_months <- c(60, 120, 180)
period_labels <- c(
  "0-5 years",
  ">5-10 years",
  ">10-15 years",
  ">15 years"
)

Surv <- survival::Surv

split_variables <- c(
  ".analysis_row_id",
  "follow_up_months",
  "death",
  "log2_crp",
  "age_rcs1",
  "age_rcs2",
  "age_rcs3",
  "sex",
  "race_hispanic_origin",
  "cycle",
  "education",
  "smoking",
  "bmi",
  "diabetes",
  "hypertension",
  "prevalent_cvd"
)

missing_split_variables <- setdiff(split_variables, names(cohort))
if (length(missing_split_variables) > 0L) {
  stop(
    "Missing variables required for the piecewise model: ",
    paste(missing_split_variables, collapse = ", "),
    call. = FALSE
  )
}

cohort_for_split <- cohort[, split_variables, drop = FALSE]

long_cohort <- survival::survSplit(
  Surv(follow_up_months, death) ~ .,
  data = cohort_for_split,
  cut = period_cuts_months,
  start = "tstart_months",
  end = "tstop_months",
  event = "death",
  episode = "followup_period_index"
)

rm(cohort_for_split)
invisible(gc(verbose = FALSE))

long_cohort$followup_period <- factor(
  long_cohort$followup_period_index,
  levels = seq_along(period_labels),
  labels = period_labels
)

if (any(long_cohort$tstop_months <= long_cohort$tstart_months)) {
  stop("Non-positive follow-up intervals detected after splitting.", call. = FALSE)
}
if (sum(long_cohort$death) != death_n) {
  stop("Death count changed after splitting follow-up.", call. = FALSE)
}

if (!identical(
  sort(unique(long_cohort$.analysis_row_id)),
  seq_len(participant_n)
)) {
  stop("Participant mapping changed after splitting follow-up.", call. = FALSE)
}

for (period_index in seq_along(period_labels)) {
  variable_name <- paste0("log2_crp_period_", period_index)
  long_cohort[[variable_name]] <- ifelse(
    long_cohort$followup_period_index == period_index,
    long_cohort$log2_crp,
    0
  )
}

crp_period_terms <- paste0("log2_crp_period_", seq_along(period_labels))

piecewise_formula <- survival::Surv(
  tstart_months,
  tstop_months,
  death
) ~
  log2_crp_period_1 + log2_crp_period_2 +
  log2_crp_period_3 + log2_crp_period_4 +
  age_rcs1 + age_rcs2 + age_rcs3 +
  sex + race_hispanic_origin + cycle + education + smoking + bmi +
  diabetes + hypertension + prevalent_cvd

# Fit helper. Replicate weights contain zeros for the deleted PSU, so rows with
# zero weight are omitted before coxph(). Factor levels are retained because the
# underlying columns are not droplevelled.
fit_weighted_cox <- function(participant_weights) {
  if (length(participant_weights) != participant_n) {
    stop("Weight vector has incorrect length.", call. = FALSE)
  }

  row_weights <- participant_weights[long_cohort$.analysis_row_id]
  keep <- is.finite(row_weights) & row_weights > 0

  if (!any(keep)) {
    stop("No positive weights in Cox fit.", call. = FALSE)
  }

  fit_columns <- c(
    "tstart_months",
    "tstop_months",
    "death",
    crp_period_terms,
    "age_rcs1",
    "age_rcs2",
    "age_rcs3",
    "sex",
    "race_hispanic_origin",
    "cycle",
    "education",
    "smoking",
    "bmi",
    "diabetes",
    "hypertension",
    "prevalent_cvd"
  )

  analysis_data <- long_cohort[
    keep,
    c(fit_columns),
    drop = FALSE
  ]

  analysis_data$.fit_weight <- row_weights[keep]
  analysis_data$.fit_weight <-
    analysis_data$.fit_weight / mean(analysis_data$.fit_weight)

  model <- survival::coxph(
    piecewise_formula,
    data = analysis_data,
    weights = .fit_weight,
    ties = "efron",
    model = FALSE,
    x = FALSE,
    y = FALSE
  )

  coefficients <- stats::coef(model)

  if (any(!is.finite(coefficients))) {
    stop("Non-finite Cox coefficients detected.", call. = FALSE)
  }

  coefficients
}

# -----------------------------------------------------------------------------
# 3. Full-sample estimate
# -----------------------------------------------------------------------------

full_coefficients <- fit_weighted_cox(sampling_weights)
coefficient_names <- names(full_coefficients)

missing_crp_terms <- setdiff(crp_period_terms, coefficient_names)
if (length(missing_crp_terms) > 0L) {
  stop(
    "Missing CRP-period coefficients: ",
    paste(missing_crp_terms, collapse = ", "),
    call. = FALSE
  )
}

# -----------------------------------------------------------------------------
# 4. Sequential JKn fits with resumable checkpoints
# -----------------------------------------------------------------------------

checkpoint_dir <- file.path(paths$processed, "checkpoints")
dir.create(checkpoint_dir, recursive = TRUE, showWarnings = FALSE)

checkpoint_path <- file.path(
  checkpoint_dir,
  "09_piecewise_crp_jkn_checkpoint.rds"
)

replicate_coefficients <- matrix(
  NA_real_,
  nrow = n_replicates,
  ncol = length(full_coefficients),
  dimnames = list(
    paste0("replicate_", seq_len(n_replicates)),
    coefficient_names
  )
)
completed <- rep(FALSE, n_replicates)

save_checkpoint <- function() {
  checkpoint <- list(
    replicate_coefficients = replicate_coefficients,
    completed = completed,
    n_replicates = n_replicates,
    coefficient_names = coefficient_names,
    period_cuts_months = period_cuts_months,
    period_labels = period_labels
  )

  temporary_path <- paste0(checkpoint_path, ".tmp")
  saveRDS(checkpoint, temporary_path, version = 3)
  if (!file.rename(temporary_path, checkpoint_path)) {
    unlink(temporary_path)
    stop("Could not atomically update checkpoint.", call. = FALSE)
  }
}

if (file.exists(checkpoint_path)) {
  checkpoint <- readRDS(checkpoint_path)

  valid_checkpoint <-
    identical(checkpoint$n_replicates, n_replicates) &&
    identical(checkpoint$coefficient_names, coefficient_names) &&
    identical(checkpoint$period_cuts_months, period_cuts_months) &&
    identical(checkpoint$period_labels, period_labels) &&
    identical(dim(checkpoint$replicate_coefficients),
              dim(replicate_coefficients)) &&
    length(checkpoint$completed) == n_replicates

  if (!valid_checkpoint) {
    stop(
      "Existing script 09 checkpoint is incompatible with the current analysis.",
      call. = FALSE
    )
  }

  replicate_coefficients <- checkpoint$replicate_coefficients
  completed <- checkpoint$completed
  message("Resuming JKn fits from existing checkpoint.")
}

pending <- which(!completed)

if (length(pending) > 0L) {
  for (replicate_index in pending) {
    message(
      "Fitting JKn replicate ", replicate_index,
      " of ", n_replicates, "..."
    )

    replicate_fit <- fit_weighted_cox(
      replicate_weights[, replicate_index]
    )

    if (!identical(names(replicate_fit), coefficient_names)) {
      stop(
        "Coefficient structure changed in JKn replicate ",
        replicate_index,
        ".",
        call. = FALSE
      )
    }

    replicate_coefficients[replicate_index, ] <- replicate_fit
    completed[replicate_index] <- TRUE
    save_checkpoint()

    rm(replicate_fit)
    invisible(gc(verbose = FALSE))
  }
}

if (!all(completed) || any(!is.finite(replicate_coefficients))) {
  stop("JKn replicate fitting did not complete successfully.", call. = FALSE)
}

# -----------------------------------------------------------------------------
# 5. JKn covariance matrix
# -----------------------------------------------------------------------------

replicate_variance <- survey::svrVar(
  replicate_coefficients,
  scale = jkn_scale,
  rscales = jkn_rscales,
  mse = jkn_mse,
  coef = full_coefficients
)
replicate_variance <- as.matrix(replicate_variance)

if (!identical(dim(replicate_variance),
               c(length(full_coefficients), length(full_coefficients)))) {
  stop("Unexpected JKn covariance-matrix dimensions.", call. = FALSE)
}
if (any(!is.finite(replicate_variance))) {
  stop("Non-finite JKn covariance estimates detected.", call. = FALSE)
}

dimnames(replicate_variance) <- list(coefficient_names, coefficient_names)

# -----------------------------------------------------------------------------
# 6. Period-specific CRP hazard ratios
# -----------------------------------------------------------------------------

crp_coefficients <- full_coefficients[crp_period_terms]
crp_variance <- replicate_variance[
  crp_period_terms,
  crp_period_terms,
  drop = FALSE
]
crp_standard_errors <- sqrt(diag(crp_variance))
confidence_multiplier <- stats::qnorm(1 - analysis_alpha / 2)

period_results <- data.frame(
  followup_period = period_labels,
  start_month = c(0, 60, 120, 180),
  end_month = c(60, 120, 180, Inf),
  log_hazard_ratio = as.numeric(crp_coefficients),
  standard_error = as.numeric(crp_standard_errors),
  hazard_ratio = exp(as.numeric(crp_coefficients)),
  confidence_low = exp(
    as.numeric(crp_coefficients) -
      confidence_multiplier * crp_standard_errors
  ),
  confidence_high = exp(
    as.numeric(crp_coefficients) +
      confidence_multiplier * crp_standard_errors
  ),
  p_value = 2 * stats::pnorm(
    abs(as.numeric(crp_coefficients) / crp_standard_errors),
    lower.tail = FALSE
  ),
  stringsAsFactors = FALSE
)

# -----------------------------------------------------------------------------
# 7. Global design-based test of CRP-by-period interaction
# -----------------------------------------------------------------------------
# H0: beta_0-5 = beta_5-10 = beta_10-15 = beta_15+

contrast_matrix <- rbind(
  c(1, -1, 0, 0),
  c(0, 1, -1, 0),
  c(0, 0, 1, -1)
)
colnames(contrast_matrix) <- crp_period_terms

contrast_estimate <- as.numeric(contrast_matrix %*% crp_coefficients)
contrast_variance <- contrast_matrix %*% crp_variance %*%
  t(contrast_matrix)

wald_chisq <- as.numeric(
  t(contrast_estimate) %*%
    solve(contrast_variance, contrast_estimate)
)
interaction_df <- nrow(contrast_matrix)
f_statistic <- wald_chisq / interaction_df
interaction_p <- stats::pf(
  f_statistic,
  df1 = interaction_df,
  df2 = design_df,
  lower.tail = FALSE
)

interaction_test <- data.frame(
  test = "CRP by follow-up period interaction",
  numerator_df = interaction_df,
  denominator_df = design_df,
  f_statistic = f_statistic,
  p_value = interaction_p,
  stringsAsFactors = FALSE
)

# -----------------------------------------------------------------------------
# 8. QC and outputs
# -----------------------------------------------------------------------------

period_event_counts <- aggregate(
  death ~ followup_period,
  data = long_cohort,
  FUN = sum
)
period_row_counts <- as.data.frame(table(long_cohort$followup_period))
names(period_row_counts) <- c("followup_period", "interval_rows")
period_qc <- merge(
  period_row_counts,
  period_event_counts,
  by = "followup_period",
  all = TRUE,
  sort = FALSE
)

analysis_qc <- data.frame(
  participants = participant_n,
  deaths = death_n,
  interval_rows = nrow(long_cohort),
  survey_strata = survey_strata_n,
  survey_psu_nested = survey_psu_n,
  survey_design_df = design_df,
  jkn_replicates = n_replicates,
  all_replicates_completed = all(completed),
  stringsAsFactors = FALSE
)

saveRDS(
  list(
    full_coefficients = full_coefficients,
    covariance = replicate_variance,
    period_results = period_results,
    interaction_test = interaction_test,
    period_qc = period_qc,
    analysis_qc = analysis_qc,
    period_cuts_months = period_cuts_months,
    period_labels = period_labels,
    analysis_constants = analysis_constants
  ),
  file.path(paths$processed, "piecewise_crp_time_interaction.rds"),
  version = 3
)

write_csv_checked(
  period_results,
  file.path(paths$tables, "table_05_crp_hr_by_followup_period.csv")
)
write_csv_checked(
  interaction_test,
  file.path(paths$tables, "table_05_crp_time_interaction_test.csv")
)
write_csv_checked(
  period_qc,
  file.path(paths$tables, "qc_09_followup_period_events.csv")
)
write_csv_checked(
  analysis_qc,
  file.path(paths$tables, "qc_09_piecewise_crp_jkn.csv")
)

message("Piecewise CRP time-interaction analysis completed.")
message("Participants: ", participant_n)
message("Deaths: ", death_n)
message("JKn replicates: ", n_replicates)
message("Design degrees of freedom: ", design_df)
message(
  "Global CRP-by-period interaction p-value: ",
  format(interaction_p, digits = 5)
)
