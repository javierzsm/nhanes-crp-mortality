#!/usr/bin/env Rscript

# Build the mortality-linked analytic cohort after specification freeze.

source(file.path("src", "R", "00_config.R"))
source(file.path("src", "R", "00_functions_data.R"))

assert_project_root()
require_package("haven")
options(timeout = max(300, getOption("timeout")))

dir.create(paths$raw, recursive = TRUE, showWarnings = FALSE)
dir.create(paths$processed, recursive = TRUE, showWarnings = FALSE)
dir.create(paths$tables, recursive = TRUE, showWarnings = FALSE)

read_cycle <- function(i) {
  row <- analysis_cycles[i, ]
  component_names <- c("DEMO", "SMQ", "BMX", "DIQ", "BPQ", "MCQ")
  files <- paste0(component_names, row$suffix)
  files[component_names == "DEMO" & row$cycle == "1999-2000"] <- "DEMO"

  demo_all <- read_nhanes_component(row$start_year, files[1], paths$raw)
  if (!"WTMEC4YR" %in% names(demo_all)) demo_all$WTMEC4YR <- NA_real_
  demo <- select_required(
    demo_all,
    c(
      "SEQN", "RIDAGEYR", "RIAGENDR", "RIDRETH1", "DMDEDUC2",
      "INDFMPIR", "RIDEXPRG", "WTMEC2YR", "WTMEC4YR",
      "SDMVSTRA", "SDMVPSU"
    ),
    files[1]
  )
  components <- list(
    SMQ = select_required(
      read_nhanes_component(row$start_year, files[2], paths$raw),
      c("SEQN", "SMQ020", "SMQ040"), files[2]
    ),
    BMX = select_required(
      read_nhanes_component(row$start_year, files[3], paths$raw),
      c("SEQN", "BMXBMI"), files[3]
    ),
    DIQ = select_required(
      read_nhanes_component(row$start_year, files[4], paths$raw),
      c("SEQN", "DIQ010"), files[4]
    ),
    BPQ = select_required(
      read_nhanes_component(row$start_year, files[5], paths$raw),
      c("SEQN", "BPQ020"), files[5]
    ),
    MCQ = select_required(
      read_nhanes_component(row$start_year, files[6], paths$raw),
      c("SEQN", "MCQ160B", "MCQ160C", "MCQ160D", "MCQ160E", "MCQ160F"),
      files[6]
    ),
    CRP = select_required(
      read_nhanes_component(row$start_year, row$lab_file, paths$raw),
      c("SEQN", "LBXCRP"), row$lab_file
    ),
    mortality = read_mortality_file(
      row$cycle, paths$raw, unname(mortality_expected_sizes[row$cycle])
    )
  )

  result <- demo
  for (component in names(components)) {
    result <- left_join_unique(result, components[[component]], component)
  }
  result$cycle <- row$cycle
  result
}

pooled <- do.call(rbind, lapply(seq_len(nrow(analysis_cycles)), read_cycle))

if (anyDuplicated(pooled$SEQN)) {
  stop("Duplicate SEQN after pooling cycles.", call. = FALSE)
}

adult_crp_weight <- pooled[
  pooled$RIDAGEYR >= 20 &
    !is.na(pooled$LBXCRP) & pooled$LBXCRP > 0 &
    !is.na(pooled$WTMEC2YR) & pooled$WTMEC2YR > 0,
]
linkage_eligible <- adult_crp_weight[
  !is.na(adult_crp_weight$ELIGSTAT) & adult_crp_weight$ELIGSTAT == 1,
]

linkage_eligible$confirmed_pregnant <- with(
  linkage_eligible,
  RIAGENDR == 2 & RIDAGEYR >= 20 & RIDAGEYR <= 44 &
    !is.na(RIDEXPRG) & RIDEXPRG == 1
)
linkage_eligible$pregnancy_unknown <- with(
  linkage_eligible,
  RIAGENDR == 2 & RIDAGEYR >= 20 & RIDAGEYR <= 44 &
    !is.na(RIDEXPRG) & RIDEXPRG == 3
)
primary_eligible <- linkage_eligible[!linkage_eligible$confirmed_pregnant, ]

primary_eligible$age <- primary_eligible$RIDAGEYR
primary_eligible$sex_code <- valid_or_na(primary_eligible$RIAGENDR, 1:2)
primary_eligible$race_code <- valid_or_na(primary_eligible$RIDRETH1, 1:5)
primary_eligible$education_code <- valid_or_na(primary_eligible$DMDEDUC2, 1:5)
primary_eligible$smoking <- derive_smoking(
  primary_eligible$SMQ020, primary_eligible$SMQ040
)
primary_eligible$bmi <- ifelse(
  primary_eligible$BMXBMI > 0, primary_eligible$BMXBMI, NA_real_
)
primary_eligible$diabetes_code <- valid_or_na(primary_eligible$DIQ010, 1:3)
primary_eligible$hypertension_code <- valid_or_na(primary_eligible$BPQ020, 1:2)
primary_eligible$prevalent_cvd_code <- derive_prevalent_cvd(primary_eligible)
primary_eligible$income_poverty_ratio <- ifelse(
  primary_eligible$INDFMPIR >= 0 & primary_eligible$INDFMPIR <= 5,
  primary_eligible$INDFMPIR, NA_real_
)
primary_eligible$crp_mg_l <- primary_eligible$LBXCRP * 10
primary_eligible$log2_crp <- log2(primary_eligible$crp_mg_l)
primary_eligible$below_detection_fill <- primary_eligible$LBXCRP == 0.01
primary_eligible$crp_above_10_mg_l <- primary_eligible$crp_mg_l > 10
primary_eligible$pooled_mec_weight <- derive_pooled_mec_weight(primary_eligible)
primary_eligible$death <- primary_eligible$MORTSTAT
primary_eligible$follow_up_months_released <- primary_eligible$PERMTH_EXM
primary_eligible$zero_follow_up_death <- with(
  primary_eligible,
  !is.na(follow_up_months_released) & follow_up_months_released == 0 &
    !is.na(death) & death == 1
)
primary_eligible$follow_up_months <- ifelse(
  primary_eligible$zero_follow_up_death,
  0.5,
  primary_eligible$follow_up_months_released
)
primary_eligible$follow_up_years <- primary_eligible$follow_up_months / 12
primary_eligible <- label_analysis_variables(primary_eligible)

if (any(!primary_eligible$death %in% c(0, 1) | is.na(primary_eligible$death))) {
  stop("Invalid or missing mortality status in primary eligible cohort.",
       call. = FALSE)
}
released_missing <- is.na(primary_eligible$follow_up_months_released)
released_zero <- !released_missing &
  primary_eligible$follow_up_months_released == 0
released_negative <- !released_missing &
  primary_eligible$follow_up_months_released < 0
if (any(released_missing | released_negative)) {
  stop(
    "Invalid released follow-up in primary eligible cohort: missing=",
    sum(released_missing), ", negative=", sum(released_negative),
    call. = FALSE
  )
}
if (sum(released_zero) != 4L ||
    any(primary_eligible$death[released_zero] != 1) ||
    sum(primary_eligible$zero_follow_up_death) != 4L) {
  stop(
    "Zero-follow-up reconciliation failed: total=", sum(released_zero),
    ", deaths=", sum(primary_eligible$death[released_zero] == 1),
    ", censored=", sum(primary_eligible$death[released_zero] == 0),
    call. = FALSE
  )
}
if (any(is.na(primary_eligible$follow_up_months) |
        primary_eligible$follow_up_months <= 0)) {
  stop("Invalid analysis follow-up after zero-time handling.", call. = FALSE)
}
if (any(is.na(primary_eligible$pooled_mec_weight) |
        primary_eligible$pooled_mec_weight <= 0)) {
  stop("Invalid pooled MEC weight.", call. = FALSE)
}

primary_eligible$primary_complete <- complete.cases(
  primary_eligible[primary_covariates]
)
primary_eligible$income_complete <- !is.na(
  primary_eligible$income_poverty_ratio
)
complete_case <- primary_eligible[primary_eligible$primary_complete, ]

observed_counts <- c(
  adult_crp_positive_mec_weight = nrow(adult_crp_weight),
  mortality_linkage_eligible = nrow(linkage_eligible),
  confirmed_pregnant = sum(linkage_eligible$confirmed_pregnant),
  primary_eligible = nrow(primary_eligible),
  primary_complete = nrow(complete_case),
  primary_and_income_complete = sum(
    primary_eligible$primary_complete & primary_eligible$income_complete
  )
)
if (!identical(as.integer(observed_counts),
               as.integer(preoutcome_expected_counts))) {
  comparison <- paste(
    names(observed_counts), observed_counts, preoutcome_expected_counts,
    sep = ":", collapse = "; "
  )
  stop("Pre-outcome reconciliation failed: ", comparison, call. = FALSE)
}

flow <- data.frame(
  step = names(observed_counts),
  n = as.integer(observed_counts),
  stringsAsFactors = FALSE
)
flow <- rbind(
  flow,
  data.frame(
    step = "same_month_deaths_assigned_0_5_months",
    n = sum(primary_eligible$zero_follow_up_death),
    stringsAsFactors = FALSE
  )
)
mortality_summary <- do.call(
  rbind,
  lapply(split(primary_eligible, primary_eligible$cycle), function(data) {
    data.frame(
      cycle = as.character(data$cycle[1]),
      n = nrow(data),
      deaths = sum(data$death),
      censored = sum(data$death == 0),
      same_month_deaths_assigned_0_5_months = sum(data$zero_follow_up_death),
      released_follow_up_months_min = min(data$follow_up_months_released),
      follow_up_months_min = min(data$follow_up_months),
      follow_up_months_median = median(data$follow_up_months),
      follow_up_months_max = max(data$follow_up_months),
      stringsAsFactors = FALSE
    )
  })
)

saveRDS(
  primary_eligible,
  file.path(paths$processed, "mortality_linked_eligible_cohort.rds"),
  version = 3
)
saveRDS(
  complete_case,
  file.path(paths$processed, "primary_complete_case_cohort.rds"),
  version = 3
)
write_csv_checked(flow, file.path(paths$tables, "qc_04_cohort_flow.csv"))
write_csv_checked(
  mortality_summary,
  file.path(paths$tables, "qc_04_mortality_followup_by_cycle.csv")
)

message("Wrote mortality-linked eligible cohort: ", nrow(primary_eligible))
message("Wrote primary complete-case cohort: ", nrow(complete_case))
message("Observed deaths in eligible cohort: ", sum(primary_eligible$death))
message("No association model has been fitted.")
