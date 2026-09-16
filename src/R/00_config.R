analysis_cycles <- data.frame(
  cycle = c(
    "1999-2000", "2001-2002", "2003-2004",
    "2005-2006", "2007-2008", "2009-2010"
  ),
  start_year = c(1999, 2001, 2003, 2005, 2007, 2009),
  suffix = c("", "_B", "_C", "_D", "_E", "_F"),
  lab_file = c("LAB11", "L11_B", "L11_C", "CRP_D", "CRP_E", "CRP_F"),
  stringsAsFactors = FALSE
)

mortality_expected_sizes <- c(
  "1999-2000" = 487666,
  "2001-2002" = 540362,
  "2003-2004" = 495722,
  "2005-2006" = 506774,
  "2007-2008" = 498376,
  "2009-2010" = 517751
)

paths <- list(
  raw = file.path("data", "raw", "nhanes"),
  processed = file.path("data", "processed"),
  tables = file.path("output", "tables")
)

primary_covariates <- c(
  "age", "sex", "race_hispanic_origin", "education", "smoking",
  "bmi", "diabetes", "hypertension", "prevalent_cvd", "cycle"
)

preoutcome_expected_counts <- c(
  adult_crp_positive_mec_weight = 28924L,
  mortality_linkage_eligible = 28890L,
  confirmed_pregnant = 1135L,
  primary_eligible = 27755L,
  primary_complete = 26818L,
  primary_and_income_complete = 24683L
)

mortality_followup_end <- as.Date("2019-12-31")
analysis_alpha <- 0.05
multiple_imputation_m <- 50L
