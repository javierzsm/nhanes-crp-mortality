#!/usr/bin/env Rscript
# Pre-imputation support audit using covariate/design fields only.
# No imputation, outcome model, category merging or predictor selection.
source(file.path("src", "R", "00_config.R"))
source(file.path("src", "R", "00_functions_data.R"))
assert_project_root()
output <- file.path(paths$tables, "qc_13b_real_covariate_design_support_v1.csv")
if (file.exists(output)) stop("Support audit exists; review/version before rerunning.")
data <- readRDS(file.path(paths$processed, "mortality_linked_eligible_cohort.rds"))
variables <- c("bmi", "education", "smoking", "diabetes", "hypertension", "prevalent_cvd")
required <- c("SEQN", "cycle", "SDMVSTRA", "SDMVPSU", variables)
if (length(setdiff(required, names(data)))) stop("Missing support-audit columns.")
stopifnot(nrow(data) == preoutcome_expected_counts[["primary_eligible"]],
          !anyDuplicated(data$SEQN), !anyNA(data[c("SEQN", "cycle", "SDMVSTRA", "SDMVPSU")]))
key <- interaction(data$SDMVSTRA, data$SDMVPSU, drop = TRUE)
stopifnot(nlevels(key) == 180L, length(unique(data$SDMVSTRA)) == 89L)
rows <- list()
for (v in variables) for (g in levels(key)) {
  z <- data[[v]][key == g]
  levels <- if (is.factor(z)) levels(z) else "observed_continuous"
  for (level in levels) {
    rows[[length(rows) + 1L]] <- data.frame(
      nested_psu = g, variable = v, category = level, participants = length(z),
      missing = sum(is.na(z)),
      observed_category = if (is.factor(z)) sum(z == level, na.rm = TRUE) else sum(!is.na(z)))
  }
}
result <- do.call(rbind, rows)
write_csv_checked(result, output)
for (v in variables) {
  counts <- result[result$variable == v, "observed_category"]
  message(v, ": absent category/PSU cells = ", sum(counts == 0L),
          "; minimum observed category count = ", min(counts))
}
message("Support audit completed; absent categories do not trigger automatic recoding.")
