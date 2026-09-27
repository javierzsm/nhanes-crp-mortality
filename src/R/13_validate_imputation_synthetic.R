#!/usr/bin/env Rscript

# Stage 5: smoke-test the proposed MICE workflow with SYNTHETIC data only.
# Never loads the real eligible cohort; does not choose methods using real
# CRP-mortality associations. Run from the repository root.
# This is an implementation validation, NOT evidence that MAR holds, that
# imputation models converge in real data, or that survey-aware MI is solved.

source(file.path("src", "R", "00_config.R"))
source(file.path("src", "R", "00_functions_data.R"))
source(file.path("src", "R", "00_functions_analysis.R"))
assert_project_root()
for (pkg in c("mice", "survey", "survival", "splines")) require_package(pkg)

set.seed(20260927)
m_test <- 3L
iterations_test <- 5L
n <- 2400L

# 1. Simulate six cycles with eight strata per cycle
# and two PSUs per stratum.
cycle_id <- rep(seq_len(6L), each = 400L)
stratum_local <- rep(rep(1:8, each = 50L), times = 6L)
psu_local <- rep(rep(1:2, each = 25L), times = 48L)
cycle_levels <- as.character(analysis_cycles$cycle)

synthetic <- data.frame(
  SEQN = seq_len(n),
  cycle = factor(cycle_levels[cycle_id], levels = cycle_levels),
  SDMVSTRA = (cycle_id - 1L) * 8L + stratum_local,
  SDMVPSU = psu_local,
  age = sample(20:79, n, replace = TRUE),
  sex = factor(sample(c("Male", "Female"), n, TRUE),
               levels = c("Male", "Female")),
  race_hispanic_origin = factor(
    sample(c("Mexican American", "Other Hispanic", "Non-Hispanic White",
             "Non-Hispanic Black", "Other or multiracial"), n, TRUE,
           prob = c(.14, .10, .51, .17, .08))
  ),
  education = factor(
    sample(c("Less than 9th grade", "9th-11th grade",
             "High school graduate or GED", "Some college or AA degree",
             "College graduate or above"), n, TRUE,
           prob = c(.14, .16, .23, .28, .19))
  ),
  smoking = factor(sample(c("never", "former", "current"), n, TRUE,
                          prob = c(.51, .27, .22)),
                   levels = c("never", "former", "current")),
  bmi = pmax(16, rnorm(n, mean = 27 + .05 * (cycle_id - 1), sd = 4.5)),
  diabetes = factor(sample(c("No", "Borderline", "Yes"), n, TRUE,
                           prob = c(.855, .025, .12)),
                    levels = c("No", "Borderline", "Yes")),
  hypertension = factor(sample(c("No", "Yes"), n, TRUE,
                               prob = c(.66, .34)), levels = c("No", "Yes")),
  prevalent_cvd = factor(sample(c("No", "Yes"), n, TRUE,
                                prob = c(.88, .12)), levels = c("No", "Yes")),
  log2_crp = rnorm(n, mean = .55, sd = 1.25),
  pooled_mec_weight = exp(rnorm(n, mean = 7, sd = .4))
)

# Correlate simulated survival with some covariates, to test outcome predictors.
eta <- .11 * synthetic$log2_crp +
  .045 * (synthetic$age - 48) +
  .25 * (synthetic$smoking == "current") +
  .40 * (synthetic$prevalent_cvd == "Yes")
event_months <- rexp(n, rate = (.0029 * exp(eta)))
censor_months <- runif(n, min = 42, max = 200)
synthetic$follow_up_months <- pmax(.5, pmin(event_months, censor_months))
synthetic$death <- as.integer(event_months <= censor_months)

# 2. Nelson-Aalen cumulative hazard, evaluated at each observed time.
# Compute it explicitly to keep this test independent of null-Cox behavior.
event_times <- sort(unique(synthetic$follow_up_months[synthetic$death == 1L]))
event_counts <- tabulate(
  match(synthetic$follow_up_months[synthetic$death == 1L], event_times),
  nbins = length(event_times)
)
at_risk <- vapply(event_times, function(t) {
  sum(synthetic$follow_up_months >= t)
}, integer(1))
na_hazard <- cumsum(event_counts / at_risk)
idx <- findInterval(synthetic$follow_up_months, event_times)
synthetic$nelson_aalen <- c(0, na_hazard)[idx + 1L]
synthetic$log_weight <- log(synthetic$pooled_mec_weight)
if (any(!is.finite(synthetic$nelson_aalen)) ||
    any(synthetic$nelson_aalen < 0)) {
  stop("Non-finite synthetic cumulative hazard.", call. = FALSE)
}

# 3. Induce synthetic missingness, including dependence on cycle and mortality.
# This is a stress test, not a claim about NHANES's missingness mechanism.
variables <- c("bmi", "education", "smoking", "diabetes",
               "hypertension", "prevalent_cvd")
complete_truth <- synthetic
missing_probs <- list(
  bmi = plogis(-3.5 + 1.2 * (cycle_id == 2L) + .55 * synthetic$death),
  education = rep(.012, n),
  smoking = rep(.012, n),
  diabetes = rep(.009, n),
  hypertension = rep(.018, n),
  prevalent_cvd = rep(.018, n)
)
for (variable in variables) {
  missing <- stats::runif(n) < missing_probs[[variable]]
  if (!any(missing)) stop("No missing synthetic values in ", variable)
  synthetic[[variable]][missing] <- NA
}
missing_masks <- lapply(variables, function(v) is.na(synthetic[[v]]))
names(missing_masks) <- variables

# Do not pass participant identifiers, PSU IDs, follow-up or raw weights to MICE.
# Their role is to remain fixed and to be used in the subsequent survey model.
# Strata/PSU handling as imputation predictors needs separate methodological
# justification before real-data MI; cycle and log(weight) are test predictors.
imi_vars <- c("age", "sex", "race_hispanic_origin", "education", "smoking",
              "bmi", "diabetes", "hypertension", "prevalent_cvd", "cycle",
              "log2_crp", "death", "nelson_aalen", "log_weight")
imi_data <- synthetic[imi_vars]
methods <- rep("", length(imi_vars))
names(methods) <- imi_vars
methods[c("bmi", "education", "smoking", "diabetes",
          "hypertension", "prevalent_cvd")] <-
  c("pmm", "polyreg", "polyreg", "polyreg", "logreg", "logreg")

pred <- matrix(0L, nrow = length(imi_vars), ncol = length(imi_vars),
               dimnames = list(imi_vars, imi_vars))
for (variable in variables) {
  pred[variable, setdiff(imi_vars, variable)] <- 1L
}
stopifnot(all(methods[setdiff(imi_vars, variables)] == ""),
          all(diag(pred) == 0L))

# 4. Fit only a SMALL synthetic trial: NOT the planned 50 real imputations.
imputations <- mice::mice(
  imi_data, m = m_test, maxit = iterations_test,
  method = methods, predictorMatrix = pred,
  seed = 20260927, printFlag = FALSE
)

if (!is.null(imputations$loggedEvents) && nrow(imputations$loggedEvents) > 0L) {
  print(imputations$loggedEvents)
  stop("MICE logged events during synthetic test; review before proceeding.",
       call. = FALSE)
}

# 5. Invariants: no missing target values and all observed/fixed values intact.
fixed <- setdiff(imi_vars, variables)
for (i in seq_len(m_test)) {
  completed <- mice::complete(imputations, action = i)
  if (anyNA(completed[variables])) {
    stop("Unimputed values in synthetic dataset ", i, call. = FALSE)
  }
  for (v in fixed) {
    if (!identical(completed[[v]], imi_data[[v]])) {
      stop("Fixed variable changed: ", v, call. = FALSE)
    }
  }
  for (v in variables) {
    observed <- !missing_masks[[v]]
    if (!identical(completed[[v]][observed],
                   complete_truth[[v]][observed])) {
      stop("Observed values changed: ", v, call. = FALSE)
    }
    if (is.factor(complete_truth[[v]]) &&
        !all(as.character(completed[[v]]) %in%
             levels(complete_truth[[v]]))) {
      stop("Out-of-range factor levels: ", v, call. = FALSE)
    }
    if (v == "bmi" && any(!is.finite(completed$bmi) | completed$bmi <= 0)) {
      stop("Invalid imputed synthetic BMI.", call. = FALSE)
    }
  }
}

# 6. Fit design-based Cox on each synthetic imputation and test scalar pooling.
# Frozen knots here are SYNTHETIC test constants, not the real analysis knots.
test_knots <- c(p5 = 24, p35 = 40, p65 = 60, p95 = 76)
formula <- survival::Surv(follow_up_months, death) ~
  log2_crp + age_rcs1 + age_rcs2 + age_rcs3 +
  sex + race_hispanic_origin + cycle + education + smoking + bmi +
  diabetes + hypertension + prevalent_cvd
Q <- U <- numeric(m_test)
for (i in seq_len(m_test)) {
  completed <- mice::complete(imputations, action = i)
  analysis <- synthetic
  analysis[variables] <- completed[variables]
  analysis <- add_age_spline_basis(analysis, test_knots)
  design <- build_survey_design(analysis)
  model <- survey::svycoxph(formula, design = design,
                             method = "efron", model = FALSE)
  validate_cox_model(model)
  Q[i] <- unname(stats::coef(model)["log2_crp"])
  U[i] <- unname(stats::vcov(model)["log2_crp", "log2_crp"])
  if (!is.finite(Q[i]) || !is.finite(U[i]) || U[i] <= 0) {
    stop("Invalid synthetic Cox estimate or variance.", call. = FALSE)
  }
}
manual_total_variance <- mean(U) + (1 + 1 / m_test) * stats::var(Q)
pooled <- mice::pool.scalar(Q, U, n = Inf, k = 1)
if (!isTRUE(all.equal(unname(pooled$qbar), mean(Q), tolerance = 1e-10)) ||
    !isTRUE(all.equal(unname(pooled$t), manual_total_variance,
                      tolerance = 1e-10))) {
  stop("Scalar Rubin pooling does not match direct calculation.", call. = FALSE)
}

# 7. Save ONLY synthetic QC, with a strict no-overwrite safeguard.
out <- file.path(paths$tables, "qc_13_synthetic_imputation.csv")
if (file.exists(out)) {
  stop("Synthetic QC file exists; review it before any rerun: ", out,
       call. = FALSE)
}
qc <- data.frame(
  check = c("synthetic_participants", "synthetic_deaths", "test_imputations",
            "test_iterations", "missing_target_variables",
            "mice_logged_events", "all_observed_and_fixed_unchanged",
            "all_imputed_targets_complete", "all_synthetic_cox_fits_finite",
            "scalar_rubin_pooling_matches_manual", "synthetic_pooled_log_hr",
            "synthetic_pooled_variance"),
  value = as.character(c(n, sum(synthetic$death), m_test, iterations_test,
                         length(variables), 0, TRUE, TRUE, TRUE, TRUE,
                         pooled$qbar, pooled$t)),
  stringsAsFactors = FALSE
)
write_csv_checked(qc, out)
message("Synthetic MICE smoke test completed. This is not real-data MI validation.")
message("QC: ", out)
