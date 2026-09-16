# Reusable functions for the survey-weighted NHANES survival analysis.

build_survey_design <- function(data) {
  require_package("survey")

  required <- c(
    "SDMVPSU", "SDMVSTRA", "pooled_mec_weight",
    "follow_up_months", "death"
  )
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop(
      "Missing survey-design variables: ", paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  invalid <- is.na(data$SDMVPSU) | is.na(data$SDMVSTRA) |
    is.na(data$pooled_mec_weight) | data$pooled_mec_weight <= 0
  if (any(invalid)) {
    stop("Invalid survey-design values in analytic cohort.", call. = FALSE)
  }

  stratum_psu <- aggregate(
    data$SDMVPSU,
    by = list(stratum = data$SDMVSTRA),
    FUN = function(x) length(unique(x))
  )
  names(stratum_psu)[2] <- "psu_n"
  if (any(stratum_psu$psu_n < 2)) {
    bad <- paste(stratum_psu$stratum[stratum_psu$psu_n < 2], collapse = ", ")
    stop("Singleton sampling strata detected: ", bad, call. = FALSE)
  }

  survey::svydesign(
    ids = ~SDMVPSU,
    strata = ~SDMVSTRA,
    weights = ~pooled_mec_weight,
    nest = TRUE,
    data = data
  )
}

survey_quantiles <- function(design, variable, probabilities) {
  estimate <- survey::svyquantile(
    stats::as.formula(paste0("~", variable)),
    design = design,
    quantiles = probabilities,
    ci = FALSE,
    na.rm = TRUE
  )
  values <- as.numeric(stats::coef(estimate))
  if (length(values) != length(probabilities) || any(!is.finite(values))) {
    stop("Could not calculate survey-weighted quantiles for ", variable, ".",
         call. = FALSE)
  }
  stats::setNames(values, paste0("p", probabilities * 100))
}

continuous_summary <- function(design, variable, label) {
  estimate <- survey::svymean(
    stats::as.formula(paste0("~", variable)),
    design = design,
    na.rm = TRUE
  )
  median_value <- survey_quantiles(design, variable, 0.5)[[1]]
  values <- design$variables[[variable]]

  data.frame(
    variable = variable,
    label = label,
    level = "",
    unweighted_n = sum(!is.na(values)),
    estimate = as.numeric(stats::coef(estimate))[1],
    standard_error = as.numeric(survey::SE(estimate))[1],
    weighted_percent = NA_real_,
    weighted_median = median_value,
    stringsAsFactors = FALSE
  )
}

categorical_summary <- function(design, variable, label) {
  values <- design$variables[[variable]]
  if (!is.factor(values)) {
    values <- factor(values)
    design$variables[[variable]] <- values
  }

  estimate <- survey::svymean(
    stats::as.formula(paste0("~", variable)),
    design = design,
    na.rm = TRUE
  )
  coefficients <- as.numeric(stats::coef(estimate))
  standard_errors <- as.numeric(survey::SE(estimate))
  levels_present <- levels(values)

  if (length(coefficients) != length(levels_present)) {
    stop("Unexpected survey proportion output for ", variable, ".",
         call. = FALSE)
  }

  data.frame(
    variable = variable,
    label = label,
    level = levels_present,
    unweighted_n = as.integer(table(values)[levels_present]),
    estimate = coefficients,
    standard_error = standard_errors,
    weighted_percent = 100 * coefficients,
    weighted_median = NA_real_,
    stringsAsFactors = FALSE
  )
}

add_age_spline_basis <- function(data, knots) {
  require_package("splines")
  required <- c("p5", "p35", "p65", "p95")
  if (!all(required %in% names(knots))) {
    stop("Age spline knots are incomplete.", call. = FALSE)
  }

  basis <- splines::ns(
    data$age,
    knots = knots[c("p35", "p65")],
    Boundary.knots = knots[c("p5", "p95")]
  )
  if (ncol(basis) != 3L) {
    stop("Unexpected age spline dimension.", call. = FALSE)
  }
  data$age_rcs1 <- basis[, 1]
  data$age_rcs2 <- basis[, 2]
  data$age_rcs3 <- basis[, 3]
  data
}

tidy_svycoxph <- function(model, model_name) {
  coefficients <- stats::coef(model)
  variance <- stats::vcov(model)
  standard_errors <- sqrt(diag(variance))
  z_value <- coefficients / standard_errors
  confidence_multiplier <- stats::qnorm(1 - analysis_alpha / 2)

  data.frame(
    model = model_name,
    term = names(coefficients),
    log_hazard_ratio = as.numeric(coefficients),
    standard_error = as.numeric(standard_errors),
    hazard_ratio = exp(as.numeric(coefficients)),
    confidence_low = exp(as.numeric(coefficients) -
                           confidence_multiplier * standard_errors),
    confidence_high = exp(as.numeric(coefficients) +
                            confidence_multiplier * standard_errors),
    p_value = 2 * stats::pnorm(abs(z_value), lower.tail = FALSE),
    stringsAsFactors = FALSE
  )
}

validate_cox_model <- function(model, exposure = "log2_crp") {
  coefficients <- stats::coef(model)
  variance <- stats::vcov(model)
  if (!exposure %in% names(coefficients)) {
    stop("Exposure coefficient is absent from fitted model.", call. = FALSE)
  }
  if (any(!is.finite(coefficients)) || any(!is.finite(variance))) {
    stop("Non-finite Cox model estimates detected.", call. = FALSE)
  }
  invisible(TRUE)
}

restricted_cubic_spline_basis <- function(x, knots) {
  knots <- sort(as.numeric(knots))
  if (length(knots) < 3L || any(!is.finite(knots)) ||
      any(diff(knots) <= 0)) {
    stop("Restricted cubic spline knots must be finite and distinct.",
         call. = FALSE)
  }

  truncated_cube <- function(value) pmax(value, 0)^3
  last <- length(knots)
  scale_factor <- (knots[last] - knots[1])^2

  nonlinear <- do.call(
    cbind,
    lapply(seq_len(last - 2L), function(index) {
      truncated_cube(x - knots[index]) -
        truncated_cube(x - knots[last - 1L]) *
          (knots[last] - knots[index]) /
          (knots[last] - knots[last - 1L]) +
        truncated_cube(x - knots[last]) *
          (knots[last - 1L] - knots[index]) /
          (knots[last] - knots[last - 1L])
    })
  ) / scale_factor

  basis <- cbind(linear = x, nonlinear)
  colnames(basis) <- c(
    "linear",
    paste0("nonlinear", seq_len(ncol(basis) - 1L))
  )
  basis
}

add_crp_spline_basis <- function(data, knots) {
  basis <- restricted_cubic_spline_basis(data$log2_crp, knots)
  if (ncol(basis) != 3L) {
    stop("The four-knot CRP spline must have three basis columns.",
         call. = FALSE)
  }
  data$crp_rcs_linear <- basis[, 1]
  data$crp_rcs_nonlinear1 <- basis[, 2]
  data$crp_rcs_nonlinear2 <- basis[, 3]
  data
}

design_wald_test <- function(model, terms, test_name) {
  require_package("survey")
  test <- survey::regTermTest(
    model,
    stats::reformulate(terms),
    method = "Wald"
  )

  data.frame(
    test = test_name,
    numerator_df = as.numeric(test$df),
    denominator_df = as.numeric(test$ddf),
    f_statistic = as.numeric(test$Ftest),
    p_value = as.numeric(test$p),
    stringsAsFactors = FALSE
  )
}

spline_contrast <- function(model, comparison_mg_l, reference_mg_l, knots) {
  terms <- c("crp_rcs_linear", "crp_rcs_nonlinear1", "crp_rcs_nonlinear2")
  comparison_basis <- restricted_cubic_spline_basis(
    log2(comparison_mg_l), knots
  )
  reference_basis <- restricted_cubic_spline_basis(
    log2(reference_mg_l), knots
  )
  if (!identical(dim(comparison_basis), c(1L, 3L)) ||
      !identical(dim(reference_basis), c(1L, 3L))) {
    stop("Unexpected spline contrast basis dimensions.", call. = FALSE)
  }
  contrast <- as.numeric(comparison_basis - reference_basis)

  coefficients <- stats::coef(model)[terms]
  variance <- stats::vcov(model)[terms, terms, drop = FALSE]
  log_hazard_ratio <- sum(contrast * coefficients)
  standard_error <- sqrt(as.numeric(t(contrast) %*% variance %*% contrast))
  multiplier <- stats::qnorm(1 - analysis_alpha / 2)

  data.frame(
    comparison_crp_mg_l = comparison_mg_l,
    reference_crp_mg_l = reference_mg_l,
    log_hazard_ratio = log_hazard_ratio,
    standard_error = standard_error,
    hazard_ratio = exp(log_hazard_ratio),
    confidence_low = exp(log_hazard_ratio - multiplier * standard_error),
    confidence_high = exp(log_hazard_ratio + multiplier * standard_error),
    stringsAsFactors = FALSE
  )
}
