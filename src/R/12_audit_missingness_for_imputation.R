#!/usr/bin/env Rscript

# Stage 5, step 1: audit missingness before specifying multiple imputation.
# Descriptive QC only: this script does not impute data or fit an outcome model.
# Run from the repository root after 04_build_analysis_cohort.R.

source(file.path("src", "R", "00_config.R"))
source(file.path("src", "R", "00_functions_data.R"))
assert_project_root()

eligible_path <- file.path(paths$processed, "mortality_linked_eligible_cohort.rds")
cc_path <- file.path(paths$processed, "primary_complete_case_cohort.rds")
if (!file.exists(eligible_path) || !file.exists(cc_path)) {
  stop("Run 04_build_analysis_cohort.R before the missingness audit.", call. = FALSE)
}

eligible <- readRDS(eligible_path)
complete_case <- readRDS(cc_path)

# The principal MI sensitivity targets the primary adjustment set. Income is
# audited separately: it belongs to an additional, distinct sensitivity model.
primary_variables <- primary_covariates
candidate_variables <- c(primary_variables, "income_poverty_ratio")
required <- unique(c(
  "SEQN", "death", "follow_up_months", "log2_crp", "crp_mg_l",
  "pooled_mec_weight", "SDMVSTRA", "SDMVPSU", "primary_complete",
  candidate_variables
))
missing_columns <- setdiff(required, names(eligible))
if (length(missing_columns) > 0L) {
  stop("Eligible cohort lacks: ", paste(missing_columns, collapse = ", "),
       call. = FALSE)
}
if (anyDuplicated(eligible$SEQN) || anyDuplicated(complete_case$SEQN)) {
  stop("Duplicated participant identifier.", call. = FALSE)
}
if (nrow(eligible) != unname(preoutcome_expected_counts["primary_eligible"]) ||
    nrow(complete_case) != unname(preoutcome_expected_counts["primary_complete"])) {
  stop("Eligible/complete-case counts disagree with frozen QC.", call. = FALSE)
}
if (anyNA(eligible$primary_complete) ||
    !identical(as.logical(eligible$primary_complete),
               stats::complete.cases(eligible[primary_variables]))) {
  stop("Primary completeness flag does not match the primary covariates.",
       call. = FALSE)
}
if (!setequal(eligible$SEQN[eligible$primary_complete], complete_case$SEQN)) {
  stop("Primary complete-case participant identifiers disagree.",
       call. = FALSE)
}

fixed_variables <- c("log2_crp", "crp_mg_l", "death", "follow_up_months",
                     "pooled_mec_weight", "SDMVSTRA", "SDMVPSU")
fixed_numeric <- c("log2_crp", "crp_mg_l", "death", "follow_up_months",
                   "pooled_mec_weight")

if (anyNA(eligible[fixed_variables]) ||
    any(vapply(fixed_numeric, function(v) {
      any(!is.finite(eligible[[v]]))
    }, logical(1)))) {
  stop("A field that must not be imputed has missing/non-finite values.",
       call. = FALSE)
}
if (any(eligible$pooled_mec_weight <= 0) ||
    any(eligible$follow_up_months <= 0) ||
    any(!eligible$death %in% c(0, 1))) {
  stop("Invalid survey weights, follow-up, or mortality status.", call. = FALSE)
}

n <- nrow(eligible)
primary_missing <- !eligible$primary_complete
n_primary_incomplete <- sum(primary_missing)
primary_missing_flags <- is.na(eligible[primary_variables])
income_complete <- stats::complete.cases(eligible[c(primary_variables, "income_poverty_ratio")])

# Each covariate's observed and missing counts, independently of the others.
variable_qc <- data.frame(
  variable = candidate_variables,
  role = ifelse(candidate_variables %in% primary_variables,
                "primary adjustment",
                "additional income sensitivity"),
  type = vapply(candidate_variables, function(v) {
    x <- eligible[[v]]
    if (is.factor(x)) {
      "factor"
    } else if (is.numeric(x)) {
      "numeric"
    } else {
      class(x)[1]
    }
  }, character(1)),
  missing_n = vapply(candidate_variables, function(v) {
    sum(is.na(eligible[[v]]))
  }, integer(1)),
  observed_n = NA_integer_,
  observed_levels = vapply(candidate_variables, function(v) {
    x <- eligible[[v]]
    if (is.factor(x)) {
      paste(names(table(x, useNA = "no")), collapse = " | ")
    } else {
      NA_character_
    }
  }, character(1)),
  stringsAsFactors = FALSE
)

variable_qc$missing_pct <- 100 * variable_qc$missing_n / n
variable_qc$observed_n <- n - variable_qc$missing_n

# Exact co-missingness combinations across the primary adjustment set.
missing_flags <- is.na(eligible[primary_variables])

pattern <- rep("complete", n)
non_complete_idx <- which(rowSums(missing_flags) > 0L)

pattern[non_complete_idx] <- vapply(non_complete_idx, function(i) {
  paste(primary_variables[missing_flags[i, ]], collapse = ";")
}, character(1))

pattern_table <- sort(table(pattern), decreasing = TRUE)
pattern_qc <- data.frame(
  missingness_pattern = names(pattern_table),
  participants = as.integer(pattern_table),
  percent_of_eligible = 100 * as.integer(pattern_table) / n,
  stringsAsFactors = FALSE
)

# Variation in incomplete-case share by survey cycle and mortality status.
cycle <- as.character(eligible$cycle)
cycle_levels <- as.character(analysis_cycles$cycle)

cycle_qc <- data.frame(
  cycle = cycle_levels,
  participants = vapply(cycle_levels, function(level) {
    as.integer(sum(cycle == level))
  }, integer(1)),
  primary_incomplete_n = vapply(cycle_levels, function(level) {
    as.integer(sum(primary_missing[cycle == level]))
  }, integer(1)),
  deaths = vapply(cycle_levels, function(level) {
    as.integer(sum(eligible$death[cycle == level]))
  }, integer(1)),
  stringsAsFactors = FALSE
)

cycle_qc$primary_incomplete_pct <- 100 * cycle_qc$primary_incomplete_n / cycle_qc$participants

mortality_qc <- data.frame(
  death = c(0, 1),
  participants = vapply(c(0, 1), function(value) {
    as.integer(sum(eligible$death == value))
  }, integer(1)),
  primary_incomplete_n = vapply(c(0, 1), function(value) {
    as.integer(sum(primary_missing[eligible$death == value]))
  }, integer(1)),
  stringsAsFactors = FALSE
)

mortality_qc$primary_incomplete_pct <- 100 * mortality_qc$primary_incomplete_n / mortality_qc$participants

summary_qc <- data.frame(
  measure = c("primary_eligible", "primary_complete", "primary_incomplete",
              "primary_incomplete_pct", "primary_and_income_complete",
              "mortality_events_eligible"),
  value = c(n, nrow(complete_case), n_primary_incomplete,
            100 * n_primary_incomplete / n,
            sum(stats::complete.cases(eligible[c(
              primary_variables, "income_poverty_ratio"
            )])), sum(eligible$death)),
  stringsAsFactors = FALSE
)
if (summary_qc$value[summary_qc$measure == "primary_and_income_complete"] !=
    unname(preoutcome_expected_counts["primary_and_income_complete"])) {
  stop("Income completeness count disagrees with frozen QC.", call. = FALSE)
}
if (sum(pattern_qc$participants) != n ||
    sum(cycle_qc$participants) != n ||
    sum(mortality_qc$participants) != n) {
  stop("Missingness audit totals do not reconcile.", call. = FALSE)
}

outputs <- list(
  qc_12_missingness_summary.csv = summary_qc,
  qc_12_missingness_by_variable.csv = variable_qc,
  qc_12_missingness_patterns.csv = pattern_qc,
  qc_12_missingness_by_cycle.csv = cycle_qc,
  qc_12_missingness_by_mortality.csv = mortality_qc
)
output_paths <- file.path(paths$tables, names(outputs))
if (any(file.exists(output_paths))) {
  stop("Stage 5 QC output already exists. Review it before rerunning; no files overwritten.",
       call. = FALSE)
}
for (i in seq_along(outputs)) {
  write_csv_checked(outputs[[i]], output_paths[i])
}
message("Missingness audit completed: ", n, " eligible; ",
        n_primary_incomplete, " incomplete on primary covariates.")
message("No data imputed; no regression model fitted.")
