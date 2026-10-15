#!/usr/bin/env Rscript
# Prespecified SYNTHETIC extension from 20 to 40 iterations; no participant data.
# Run from the repository root. This is not the 50-imputation sensitivity.
source(file.path("src", "R", "00_config.R"))
source(file.path("src", "R", "00_functions_data.R"))
source(file.path("src", "R", "00_functions_analysis.R"))
assert_project_root()
Sys.setenv(TZ = "Europe/Paris")
for (p in c("mice", "survey", "survival", "splines", "nnet")) require_package(p)
if (as.character(utils::packageVersion("mice")) != "3.19.0") {
  stop("This instrumentation must be reviewed for a different MICE version.")
}
prefix <- "qc_13f_extended_synthetic40_v1"
out <- file.path(paths$tables, paste0(prefix, ".csv"))
checkpoint <- file.path(paths$processed, paste0(prefix, "_checkpoint.rds"))
artifacts <- file.path(paths$processed, paste0(prefix, "_validation.rds"))
trace_file <- file.path(paths$tables, paste0(prefix, "_traces.csv"))
fit_file <- file.path(paths$tables, paste0(prefix, "_multinomial.csv"))
resume <- identical(commandArgs(trailingOnly = TRUE), "--resume")
if (length(commandArgs(trailingOnly = TRUE)) && !resume) stop("Only --resume is supported.")
if (any(file.exists(c(out, artifacts, trace_file, fit_file))) ||
    (!resume && file.exists(checkpoint))) {
  stop("Validation artifacts already exist; review/version before rerunning.")
}
diagnostic_outputs <- c(
  file.path(paths$tables, paste0(prefix, c("_convergence.csv", "_bmi_distributions.csv",
    "_category_distributions.csv"))),
  file.path("output", "figures", paste0(prefix, c("_bmi_traces.png", "_category_traces.png",
    "_bmi_distributions.png"))))
if (any(file.exists(diagnostic_outputs))) stop("Diagnostic outputs exist; review/version first.")
old_qc <- utils::read.csv(file.path(paths$tables, "qc_13b_synthetic_design_v2.csv"),
                         colClasses = "character")
stopifnot(old_qc$value[old_qc$check == "batched_continuation_identical"] == "1")
seed <- 20261013L
n <- 27755L
m <- 3L
iterations <- 40L
started <- proc.time()[["elapsed"]]

nelson_aalen <- function(time, death) {
  stopifnot(length(time) == length(death), length(time) > 0,
            all(is.finite(time)), all(time > 0), all(death %in% 0:1))
  times <- sort(unique(time))
  counts <- tabulate(match(time, times), length(times))
  events <- tabulate(match(time[death == 1L], times), length(times))
  risk <- rev(cumsum(rev(counts)))
  hazard <- cumsum(events / risk)
  stopifnot(sum(events) == sum(death), all(risk > 0),
            all(is.finite(hazard)), all(diff(hazard) >= 0))
  hazard[match(time, times)]
}
# Two deaths and one censor tied at 0.5, censor before first event, last event.
test_h <- nelson_aalen(c(.25, .5, .5, .5, 2), c(0, 1, 1, 0, 1))
stopifnot(isTRUE(all.equal(test_h, c(0, .5, .5, .5, 1.5))))
stopifnot(identical(nelson_aalen(c(1, 2), c(0, 0)), c(0, 0)))

set.seed(seed)
strata_per_cycle <- c(13L, 15L, 15L, 15L, 16L, 15L)
stratum_cycle <- rep(seq_len(6L), strata_per_cycle)
# 89 strata, 180 PSUs: two strata have a third artificial PSU.
psus_per_stratum <- c(3L, 3L, rep(2L, 87L))
cluster_stratum <- rep(seq_len(89L), psus_per_stratum)
cluster_psu <- unlist(lapply(psus_per_stratum, seq_len))
cluster <- rep(seq_len(180L), length.out = n)
s <- cluster_stratum[cluster]
cy <- stratum_cycle[s]
cluster_effect <- rnorm(180L, sd = .2)
x <- data.frame(
  SEQN = seq_len(n),
  cycle = factor(analysis_cycles$cycle[cy], levels = analysis_cycles$cycle),
  SDMVSTRA = s, SDMVPSU = cluster_psu[cluster],
  age = sample(20:79, n, TRUE),
  sex = factor(sample(c("Male", "Female"), n, TRUE), levels = c("Male", "Female")),
  race_hispanic_origin = factor(sample(c("Mexican American", "Other Hispanic",
    "Non-Hispanic White", "Non-Hispanic Black", "Other or multiracial"), n,
    TRUE, c(.14, .1, .51, .17, .08)), levels = c("Mexican American",
    "Other Hispanic", "Non-Hispanic White", "Non-Hispanic Black", "Other or multiracial")),
  education = factor(sample(c("Less than 9th grade", "9th-11th grade",
    "High school graduate or GED", "Some college or AA degree",
    "College graduate or above"), n, TRUE, c(.143, .165, .238, .265, .189)),
    levels = c("Less than 9th grade", "9th-11th grade", "High school graduate or GED",
               "Some college or AA degree", "College graduate or above")),
  smoking = factor(sample(c("never", "former", "current"), n, TRUE,
                           c(.515, .261, .224)), levels = c("never", "former", "current")),
  bmi = pmax(14, rnorm(n, 27 + .2 * cy + cluster_effect[cluster], 4.5)),
  diabetes = factor(sample(c("No", "Borderline", "Yes"), n, TRUE,
                            c(.873, .0164, .1106)), levels = c("No", "Borderline", "Yes")),
  hypertension = factor(sample(c("No", "Yes"), n, TRUE, c(.659, .341)),
                        levels = c("No", "Yes")),
  prevalent_cvd = factor(sample(c("No", "Yes"), n, TRUE, c(.882, .118)),
                         levels = c("No", "Yes")),
  log2_crp = rnorm(n, .55 + cluster_effect[cluster], 1.25),
  pooled_mec_weight = exp(rnorm(n, 7 + .03 * cy, .4))
)
eta <- .11 * x$log2_crp + .045 * (x$age - 48) +
  .25 * (x$smoking == "current") + .4 * (x$prevalent_cvd == "Yes")
event <- rexp(n, .0029 * exp(eta))
censor <- runif(n, 42, 200)
x$follow_up_months <- pmax(.5, round(pmin(event, censor) * 2) / 2)
x$death <- as.integer(event <= censor)
x$nelson_aalen <- nelson_aalen(x$follow_up_months, x$death)
x$log_weight <- log(x$pooled_mec_weight)
# Artificial knots: do not read real-data constants in this synthetic script.
knots <- c(p5 = 24, p35 = 40, p65 = 60, p95 = 76)
x <- add_age_spline_basis(x, knots)
targets <- c("bmi", "education", "smoking", "diabetes", "hypertension", "prevalent_cvd")
truth <- x
# Exact audited marginal missing counts, assigned to artificial records.
missing_n <- c(bmi = 575L, education = 48L, smoking = 31L, diabetes = 19L,
               hypertension = 164L, prevalent_cvd = 147L)
for (v in targets) {
  prob <- exp(.55 * x$death + .8 * (cy == 2L))
  x[[v]][sample.int(n, missing_n[[v]], prob = prob)] <- NA
}
masks <- lapply(x[targets], is.na)

# Full-rank design coding, with deterministic references.
design_columns <- list()
mapping <- list()
for (c in seq_len(6L)) {
  ss <- which(stratum_cycle == c)
  for (h in ss[-1L]) {
    name <- sprintf("stratum_%03d", h)
    design_columns[[name]] <- as.integer(s == h)
    mapping[[name]] <- data.frame(column = name, kind = "stratum", cycle = c,
                                  stratum = h, psu = NA_integer_)
  }
}
for (h in seq_len(89L)) {
  for (p in seq_len(psus_per_stratum[h])[-1L]) {
    name <- sprintf("psu_%03d_%02d", h, p)
    design_columns[[name]] <- as.integer(s == h & x$SDMVPSU == p)
    mapping[[name]] <- data.frame(column = name, kind = "psu", cycle = stratum_cycle[h],
                                  stratum = h, psu = p)
  }
}
design_data <- data.frame(cycle = x$cycle, as.data.frame(design_columns))
D <- stats::model.matrix(~ ., design_data)
stopifnot(ncol(D) == 180L, qr(D)$rank == 180L,
          length(design_columns) == 174L)
# Each coded column is constant within nested PSU and 180 independent columns
# span the 180-dimensional nested-PSU intercept space.
stopifnot(all(vapply(split(seq_len(n), cluster), function(rows) {
  all(vapply(seq_len(ncol(D)), function(j) length(unique(D[rows, j])) == 1L,
             logical(1)))
}, logical(1))))
rm(D)
fixed <- c("age_rcs1", "age_rcs2", "age_rcs3", "sex", "race_hispanic_origin",
           "cycle", "log2_crp", "death", "nelson_aalen", "log_weight")
data <- cbind(x[c(targets, fixed)], as.data.frame(design_columns))
transforms <- lapply(c("bmi", "age_rcs1", "age_rcs2", "age_rcs3", "log2_crp",
                       "nelson_aalen", "log_weight"), function(v) {
  z <- data[[v]]
  mu <- mean(z, na.rm = TRUE)
  sd <- stats::sd(z, na.rm = TRUE)
  stopifnot(is.finite(sd), sd > 0)
  data[[v]] <<- (z - mu) / sd
  c(mean = mu, sd = sd)
})
names(transforms) <- c("bmi", "age_rcs1", "age_rcs2", "age_rcs3", "log2_crp",
                      "nelson_aalen", "log_weight")
pred <- matrix(0L, ncol(data), ncol(data), dimnames = list(names(data), names(data)))
pred[targets, ] <- 1L
diag(pred) <- 0L
# MICE normalizes predictor matrices to double; retain exact value comparison.
storage.mode(pred) <- "double"
where <- is.na(data)
stopifnot(!any(where[, setdiff(names(data), targets)]))
methods <- stats::setNames(rep("", ncol(data)), names(data))
methods[targets] <- c("pmm", "polyreg_audit", "polyreg_audit", "polyreg_audit", "logreg", "logreg")

# Fail on warning; no warning suppression or automatic methodological fallback.
strict <- function(expr) withCallingHandlers(expr, warning = function(w) {
  stop("Unreviewed warning: ", conditionMessage(w), call. = FALSE)
})
audit <- new.env(parent = emptyenv())
audit$fits <- list()
check_multinomial <- function(fit, post) {
  if (fit$convergence != 0L || any(!is.finite(stats::coef(fit))) ||
      any(!is.finite(post)) || any(post < 0 | post > 1) ||
      any(abs(rowSums(post) - 1) > 1e-8)) {
    stop("Multinomial optimization/probability diagnostic failed.")
  }
  audit$fits[[length(audit$fits) + 1L]] <- data.frame(
    convergence = fit$convergence, min_probability = min(post),
    max_probability = max(post), coefficients = length(stats::coef(fit)))
}
# Instrument the installed function without altering its model or random draws.
mice.impute.polyreg_audit <- mice::mice.impute.polyreg
b <- as.list(body(mice.impute.polyreg_audit))
fit_pos <- which(vapply(b, function(e) {
  is.call(e) && identical(e[[1L]], as.name("<-")) && identical(e[[2L]], as.name("fit"))
}, logical(1)))
stopifnot(length(fit_pos) == 1L)
b <- append(b, list(quote(message("Synthetic multinomial fit starting"))),
            after = fit_pos - 1L)
pos <- which(vapply(b, function(e) {
  is.call(e) && identical(e[[1L]], as.name("<-")) && identical(e[[2L]], as.name("draws"))
}, logical(1)))
stopifnot(length(pos) == 1L)
b <- append(b, list(quote(get("check_multinomial", envir = globalenv())(fit, post))),
            after = pos - 1L)
body(mice.impute.polyreg_audit) <- as.call(b)
# Negative-control diagnostic and exact agreement with the original routine.
bad <- try(check_multinomial(list(convergence = 1L), matrix(.5, 1, 2)), silent = TRUE)
stopifnot(inherits(bad, "try-error"),
          inherits(try(strict(warning("intentional diagnostic test")), silent = TRUE), "try-error"))
set.seed(seed)
y <- factor(sample(c("a", "b", "c"), 120, TRUE))
ry <- seq_along(y) <= 100L
xx <- matrix(rnorm(240), 120, 2)
set.seed(seed)
a <- mice::mice.impute.polyreg(y, ry, xx, nnet.maxit = 1000, nnet.MaxNWts = 5000)
rng <- .Random.seed
set.seed(seed)
b <- mice.impute.polyreg_audit(y, ry, xx, nnet.maxit = 1000, nnet.MaxNWts = 5000)
stopifnot(identical(a, b), identical(rng, .Random.seed))
audit$fits <- list()

# Initialization is synthetic only; inspect every target's completed predictors.
init <- strict(mice::mice(data, m = m, maxit = 0L, predictorMatrix = pred,
                         method = methods, where = where, visitSequence = targets,
                         seed = seed, printFlag = FALSE,
                         remove.constant = FALSE, remove.collinear = FALSE))
rank_qc <- list()
initialized <- mice::complete(init, 1L)
for (v in targets) {
  X <- stats::model.matrix(~ ., initialized[setdiff(names(data), v)])
  X <- X[!masks[[v]], , drop = FALSE]
  rank_qc[[v]] <- data.frame(variable = v, columns = ncol(X), rank = qr(X)$rank,
                              condition = kappa(X, exact = FALSE))
  if (qr(X)$rank != ncol(X)) stop("Observed-row predictor rank deficiency: ", v)
}
rm(initialized, X)

args <- list(nnet.maxit = 1000L, nnet.MaxNWts = 5000L,
             donors = 5L, matchtype = 1L, ridge = 1e-5, nnet.trace = TRUE)
advance <- function(obj, count) {
  ans <- strict(do.call(mice::mice.mids, c(list(obj = obj, maxit = count,
                                              printFlag = FALSE), args)))
  if (!is.null(ans$loggedEvents) && nrow(ans$loggedEvents)) {
    print(ans$loggedEvents)
    stop("MICE logged events; prospective review required.")
  }
  stopifnot(identical(ans$predictorMatrix, pred), identical(ans$method, methods))
  ans
}
# One-iteration stepping captures every category's proportions without RNG use.
summarize_draws <- function(obj) {
  rows <- list()
  for (v in targets) for (chain in seq_len(m)) {
    z <- obj$imp[[v]][, chain]
    if (v == "bmi") {
      z <- z * transforms$bmi[["sd"]] + transforms$bmi[["mean"]]
      values <- c(mean = mean(z), variance = var(z),
                  stats::setNames(as.numeric(stats::quantile(z, c(.05, .5, .95))),
                                  c("p05", "p50", "p95")))
    } else {
      values <- as.numeric(table(factor(z, levels = levels(data[[v]])))) / length(z)
      names(values) <- levels(data[[v]])
    }
    rows[[length(rows) + 1L]] <- data.frame(iteration = obj$iteration,
      chain = chain, variable = v, statistic = names(values), value = values)
  }
  do.call(rbind, rows)
}
atomic_save <- function(object, path) {
  if (file.exists(path)) stop("Refusing checkpoint overwrite.")
  temporary <- tempfile(pattern = ".mi-checkpoint-", tmpdir = dirname(path))
  on.exit(unlink(temporary))
  saveRDS(object, temporary)
  restored <- readRDS(temporary)
  # Formulas can carry equivalent but newly deserialized environments.
  # Validate substantive state exactly, rather than environment identity.
  state_fields <- c("data", "imp", "m", "where", "blocks", "nmis", "method",
    "predictorMatrix", "visitSequence", "calltype", "post", "blots", "ignore",
    "seed", "iteration", "lastSeedValue", "chainMean", "chainVar", "loggedEvents")
  stopifnot(identical(restored[setdiff(names(restored), "mids")],
                      object[setdiff(names(object), "mids")]),
            identical(restored$mids[state_fields], object$mids[state_fields]),
            identical(lapply(restored$mids$formulas, deparse),
                      lapply(object$mids$formulas, deparse)))
  if (!file.rename(temporary, path)) stop("Checkpoint finalization failed.")
}
manifest <- list(seed = seed, m = m, participants = n,
                 code_md5 = tools::md5sum("src/R/13f_extend_imputation_synthetic_40.R"),
                 specification_md5 = tools::md5sum("docs/methods/multiple_imputation_technical_spec_draft.md"),
                 session = utils::sessionInfo(), rng_kind = RNGkind(),
                 diagnostics_hash = tools::md5sum("src/R/00_functions_imputation_diagnostics.R"),
                 parent_hash = tools::md5sum(file.path(paths$processed,
                   "qc_13d_extended_synthetic_v1_validation.rds")))
# Save initialization and every synthetic iteration for interruption recovery.
# Real-run checkpoint cadence remains a separate execution decision.
checkpoint_files <- list.files(paths$processed,
  pattern = paste0("^", prefix, "_iter[0-9]{3}\\.rds$"), full.names = TRUE)
if (!resume && length(checkpoint_files)) stop("Existing iteration checkpoints require --resume.")
obj <- init
traces <- list()
if (resume) {
  if (!length(checkpoint_files)) stop("No verified iteration checkpoint available.")
  latest <- readRDS(tail(sort(checkpoint_files), 1L))
  stopifnot(identical(latest$manifest, manifest),
            identical(latest$rng, latest$mids$lastSeedValue),
            identical(latest$mids$predictorMatrix, pred),
            identical(latest$mids$method, methods))
  obj <- latest$mids
  traces <- latest$traces
  audit$fits <- latest$fits
  message("Resuming synthetic validation after iteration ", obj$iteration)
} else {
  parent <- readRDS(file.path(paths$processed, "qc_13d_extended_synthetic_v1_validation.rds"))
  stopifnot(parent$mids$iteration == 20L,
            identical(parent$mids$data, data),
            identical(parent$mids$where, init$where),
            identical(parent$mids$predictorMatrix, pred),
            identical(parent$mids$method, methods),
            identical(parent$transforms, transforms),
            identical(parent$manifest$session, manifest$session),
            identical(unname(parent$manifest$code_md5),
                      unname(tools::md5sum("src/R/13d_validate_imputation_extended_synthetic.R"))),
            identical(unname(parent$manifest$diagnostics_hash),
                      unname(manifest$diagnostics_hash)),
            identical(unname(parent$manifest$specification_md5),
                      unname(manifest$specification_md5)))
  obj <- parent$mids
  traces <- lapply(seq_len(20L), function(i) parent$traces[parent$traces$iteration == i, ])
  audit$fits <- lapply(seq_len(nrow(parent$fits)), function(i) parent$fits[i, ])
  # Restore the parent's continuation state; never seed a fresh chain here.
  assign(".Random.seed", obj$lastSeedValue, envir = globalenv())
  message("Continuing the original three synthetic chains after iteration 20.")
  atomic_save(list(mids = obj, traces = traces, fits = audit$fits,
                  manifest = manifest, rng = .Random.seed),
              file.path(paths$processed, paste0(prefix, "_iter020.rds")))
}
if (obj$iteration < iterations) for (iteration in seq.int(obj$iteration + 1L, iterations)) {
  message("Synthetic iteration ", iteration, "/", iterations)
  obj <- advance(obj, 1L)
  traces[[iteration]] <- summarize_draws(obj)
  state <- list(mids = obj, traces = traces, fits = audit$fits,
                manifest = manifest, rng = .Random.seed)
  atomic_save(state, file.path(paths$processed,
    sprintf("%s_iter%03d.rds", prefix, iteration)))
  if (iteration == iterations - 1L && !file.exists(checkpoint)) atomic_save(state, checkpoint)
}
if (!file.exists(checkpoint)) stop("Missing penultimate-iteration equivalence checkpoint.")
reference <- obj
reference_fits <- audit$fits
reference_traces <- traces
# Replay after disk round trip. No seed reset; mice.mids restores saved state.
restored <- readRDS(checkpoint)
stopifnot(identical(restored$manifest, manifest),
          identical(restored$rng, restored$mids$lastSeedValue))
audit$fits <- restored$fits
traces <- restored$traces
obj <- restored$mids
for (iteration in seq.int(restored$mids$iteration + 1L, iterations)) {
  obj <- advance(obj, 1L)
  traces[[iteration]] <- summarize_draws(obj)
}
stopifnot(identical(obj$imp, reference$imp),
          identical(obj$lastSeedValue, reference$lastSeedValue),
          identical(obj$chainMean, reference$chainMean),
          identical(obj$chainVar, reference$chainVar),
          identical(traces, reference_traces), identical(audit$fits, reference_fits))
# Full-size batch-equivalence was validated separately in Script 13b.

source(file.path("src", "R", "00_functions_imputation_diagnostics.R"))
diag_result <- export_synthetic_imputation_diagnostics(
  obj, do.call(rbind, traces), x, transforms, targets, prefix, paths)
# Record review flags before fitting synthetic Cox; flags do not select methods.
message("Diagnostic summaries exported; review flags: ", sum(diag_result$flags$review_flag))

Q <- U <- numeric(m)
formula <- survival::Surv(follow_up_months, death) ~ log2_crp +
  age_rcs1 + age_rcs2 + age_rcs3 + sex + race_hispanic_origin + cycle +
  education + smoking + bmi + diabetes + hypertension + prevalent_cvd
for (chain in seq_len(m)) {
  completed <- mice::complete(obj, chain)
  stopifnot(!anyNA(completed[targets]))
  for (v in setdiff(names(data), targets)) stopifnot(identical(completed[[v]], data[[v]]))
  analysis <- x
  for (v in targets) {
    stopifnot(identical(completed[[v]][!masks[[v]]], data[[v]][!masks[[v]]]))
    if (is.factor(x[[v]])) stopifnot(identical(levels(completed[[v]]), levels(x[[v]])))
    draws <- completed[[v]][masks[[v]]]
    if (v == "bmi") {
      draws <- draws * transforms$bmi[["sd"]] + transforms$bmi[["mean"]]
      stopifnot(all(is.finite(draws)), all(draws > 0),
                min(draws) >= min(x$bmi, na.rm = TRUE) - 1e-10,
                max(draws) <= max(x$bmi, na.rm = TRUE) + 1e-10)
    }
    analysis[[v]][masks[[v]]] <- draws
    stopifnot(identical(analysis[[v]][!masks[[v]]], truth[[v]][!masks[[v]]]))
  }
  stopifnot(identical(analysis$SEQN, x$SEQN))
  design <- build_survey_design(analysis)
  stopifnot(survey::degf(design) == 91L)
  fit <- strict(survey::svycoxph(formula, design = design, method = "efron", model = FALSE))
  validate_cox_model(fit)
  Q[chain] <- stats::coef(fit)[["log2_crp"]]
  U[chain] <- stats::vcov(fit)["log2_crp", "log2_crp"]
}
T <- mean(U) + (1 + 1 / m) * var(Q)
pooled <- mice::pool.scalar(Q, U, n = 92, k = 1)
lambda <- (1 + 1 / m) * var(Q) / T
df_old <- if (lambda == 0) Inf else (m - 1) / lambda^2
df_obs <- 92 / 94 * 91 * (1 - lambda)
df <- 1 / (1 / df_old + 1 / df_obs)
stopifnot(isTRUE(all.equal(pooled$t, T)), isTRUE(all.equal(pooled$df, df)),
          all(is.finite(Q)), all(is.finite(U)), all(U > 0))
# B=0 must still give finite df with a finite complete-data convention.
zero <- mice::pool.scalar(rep(.1, m), rep(.01, m), n = 92, k = 1)
stopifnot(isTRUE(all.equal(zero$t, .01)), is.finite(zero$df))
trace_table <- do.call(rbind, traces)
fit_table <- do.call(rbind, reference_fits)
qc <- data.frame(check = c("synthetic_participants", "imputations", "iterations",
  "strata", "nested_psus", "design_df", "design_columns", "nelson_aalen_edge_cases",
  "instrumented_polyreg_matches_original", "negative_controls_detected",
  "checkpoint_restart_identical", "historical_batch_equivalence_passed",
  "observed_and_fixed_preserved", "all_targets_complete", "finite_survey_cox",
  "finite_df_rubin_matches_manual", "multinomial_fits", "elapsed_seconds",
  "checkpoint_bytes", "real_data_loaded", "convergence_review_complete"),
  value = as.character(c(n, m, iterations, 89, 180, 91, 174,
                          rep(TRUE, 9), nrow(fit_table),
                          proc.time()[["elapsed"]] - started,
                          file.info(checkpoint)$size, FALSE, FALSE)))
atomic_save(list(mids = obj, manifest = manifest, rank_qc = do.call(rbind, rank_qc),
  mapping = do.call(rbind, mapping), transforms = transforms, traces = trace_table,
  fits = fit_table, Q = Q, U = U, pooled = pooled), artifacts)
write_csv_checked(trace_table, trace_file)
write_csv_checked(fit_table, fit_file)
write_csv_checked(qc, out)
message("Extended synthetic execution completed; convergence requires review of exported flags and plots.")
message("QC: ", out)
