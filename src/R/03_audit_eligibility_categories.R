#!/usr/bin/env Rscript

# Audit final pre-outcome eligibility rules and categorical codes.
# Mortality status and follow-up time are deliberately not read.

if (!requireNamespace("haven", quietly = TRUE)) {
  stop("Package 'haven' is required.", call. = FALSE)
}

cycles <- data.frame(
  cycle = c(
    "1999-2000", "2001-2002", "2003-2004",
    "2005-2006", "2007-2008", "2009-2010"
  ),
  start_year = c(1999, 2001, 2003, 2005, 2007, 2009),
  suffix = c("", "_B", "_C", "_D", "_E", "_F"),
  lab_file = c("LAB11", "L11_B", "L11_C", "CRP_D", "CRP_E", "CRP_F"),
  stringsAsFactors = FALSE
)

raw_dir <- file.path("data", "raw", "nhanes")
output_dir <- file.path("output", "tables")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = max(300, getOption("timeout")))

download_if_missing <- function(url, destination, expected_size = NULL) {
  valid_existing <- file.exists(destination) &&
    (is.null(expected_size) || file.info(destination)$size == expected_size)
  if (valid_existing) return(invisible(destination))

  temporary <- paste0(destination, ".part")
  if (file.exists(temporary)) unlink(temporary)
  on.exit(if (file.exists(temporary)) unlink(temporary), add = TRUE)

  download.file(
    url, temporary, mode = "wb", quiet = FALSE, method = "libcurl"
  )
  if (!is.null(expected_size) && file.info(temporary)$size != expected_size) {
    stop("Downloaded file has unexpected size: ", basename(destination),
         call. = FALSE)
  }
  if (file.exists(destination)) unlink(destination)
  if (!file.rename(temporary, destination)) {
    stop("Could not finalize download: ", basename(destination), call. = FALSE)
  }
  invisible(destination)
}

read_component <- function(start_year, file) {
  path <- file.path(raw_dir, paste0(file, ".xpt"))
  url <- sprintf(
    "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/%s/DataFiles/%s.xpt",
    start_year, file
  )
  download_if_missing(url, path)
  haven::read_xpt(path)
}

read_eligibility <- function(cycle) {
  name <- sprintf("NHANES_%s_MORT_2019_PUBLIC.dat", gsub("-", "_", cycle))
  path <- file.path(raw_dir, name)
  url <- paste0(
    "https://ftp.cdc.gov/pub/Health_Statistics/NCHS/datalinkage/",
    "linked_mortality/", name
  )
  expected_sizes <- c(
    "1999-2000" = 487666, "2001-2002" = 540362,
    "2003-2004" = 495722, "2005-2006" = 506774,
    "2007-2008" = 498376, "2009-2010" = 517751
  )
  download_if_missing(url, path, unname(expected_sizes[cycle]))
  lines <- readLines(path, warn = FALSE)
  data.frame(
    SEQN = as.numeric(substr(lines, 1, 6)),
    ELIGSTAT = as.integer(substr(lines, 15, 15))
  )
}

keep_existing <- function(data, variables, required = variables) {
  missing_required <- setdiff(required, names(data))
  if (length(missing_required) > 0) {
    stop("Missing expected variables: ",
         paste(missing_required, collapse = ", "), call. = FALSE)
  }
  data[intersect(variables, names(data))]
}

audit_cycle <- function(i) {
  row <- cycles[i, ]
  component_names <- c("DEMO", "SMQ", "BMX", "DIQ", "BPQ", "MCQ")
  files <- paste0(component_names, row$suffix)
  files[component_names == "DEMO" & row$cycle == "1999-2000"] <- "DEMO"

  demo <- keep_existing(
    read_component(row$start_year, files[1]),
    c(
      "SEQN", "RIDAGEYR", "RIAGENDR", "RIDRETH1", "DMDEDUC2",
      "INDFMPIR", "RIDEXPRG", "WTMEC2YR", "WTMEC4YR",
      "SDMVSTRA", "SDMVPSU"
    ),
    required = c(
      "SEQN", "RIDAGEYR", "RIAGENDR", "RIDRETH1", "DMDEDUC2",
      "INDFMPIR", "RIDEXPRG", "WTMEC2YR", "SDMVSTRA", "SDMVPSU"
    )
  )
  if (!"WTMEC4YR" %in% names(demo)) demo$WTMEC4YR <- NA_real_
  demo <- demo[c(
    "SEQN", "RIDAGEYR", "RIAGENDR", "RIDRETH1", "DMDEDUC2",
    "INDFMPIR", "RIDEXPRG", "WTMEC2YR", "WTMEC4YR",
    "SDMVSTRA", "SDMVPSU"
  )]
  smq <- keep_existing(
    read_component(row$start_year, files[2]),
    c("SEQN", "SMQ020", "SMQ040")
  )
  bmx <- keep_existing(read_component(row$start_year, files[3]),
                       c("SEQN", "BMXBMI"))
  diq <- keep_existing(read_component(row$start_year, files[4]),
                       c("SEQN", "DIQ010"))
  bpq <- keep_existing(read_component(row$start_year, files[5]),
                       c("SEQN", "BPQ020"))
  mcq <- keep_existing(
    read_component(row$start_year, files[6]),
    c("SEQN", "MCQ160B", "MCQ160C", "MCQ160D", "MCQ160E", "MCQ160F")
  )
  lab <- keep_existing(read_component(row$start_year, row$lab_file),
                       c("SEQN", "LBXCRP"))

  components <- list(smq, bmx, diq, bpq, mcq, lab, read_eligibility(row$cycle))
  joined <- Reduce(
    function(x, y) merge(x, y, by = "SEQN", all.x = TRUE),
    components, init = demo
  )
  joined$cycle <- row$cycle
  joined
}

all_examined <- do.call(rbind, lapply(seq_len(nrow(cycles)), audit_cycle))

duplicate_seqn <- duplicated(all_examined$SEQN) |
  duplicated(all_examined$SEQN, fromLast = TRUE)
duplicate_table <- all_examined[duplicate_seqn, c("SEQN", "cycle")]

base <- all_examined[
  all_examined$RIDAGEYR >= 20 &
    !is.na(all_examined$LBXCRP) &
    all_examined$LBXCRP > 0 &
    !is.na(all_examined$WTMEC2YR) &
    all_examined$WTMEC2YR > 0,
]
linked <- base[!is.na(base$ELIGSTAT) & base$ELIGSTAT == 1, ]

categorical_variables <- c(
  "RIAGENDR", "RIDRETH1", "DMDEDUC2", "RIDEXPRG",
  "SMQ020", "SMQ040", "DIQ010", "BPQ020",
  "MCQ160B", "MCQ160C", "MCQ160D", "MCQ160E", "MCQ160F"
)

category_counts <- do.call(
  rbind,
  lapply(categorical_variables, function(variable) {
    values <- linked[[variable]]
    shown <- ifelse(is.na(values), "<NA>", as.character(values))
    counts <- as.data.frame(table(linked$cycle, shown), stringsAsFactors = FALSE)
    names(counts) <- c("cycle", "code", "n")
    counts$variable <- variable
    counts[counts$n > 0, c("cycle", "variable", "code", "n")]
  })
)

valid_or_na <- function(x, valid) ifelse(x %in% valid, x, NA)

linked$sex <- valid_or_na(linked$RIAGENDR, 1:2)
linked$race_hispanic_origin <- valid_or_na(linked$RIDRETH1, 1:5)
linked$education <- valid_or_na(linked$DMDEDUC2, 1:5)
linked$diabetes <- valid_or_na(linked$DIQ010, 1:3)
linked$hypertension <- valid_or_na(linked$BPQ020, 1:2)
linked$bmi <- ifelse(linked$BMXBMI > 0, linked$BMXBMI, NA)
linked$income_poverty_ratio <- ifelse(
  linked$INDFMPIR >= 0 & linked$INDFMPIR <= 5,
  linked$INDFMPIR, NA
)

linked$smoking <- NA_character_
linked$smoking[linked$SMQ020 == 2] <- "never"
linked$smoking[linked$SMQ020 == 1 & linked$SMQ040 == 3] <- "former"
linked$smoking[linked$SMQ020 == 1 & linked$SMQ040 %in% c(1, 2)] <- "current"

cvd_variables <- c("MCQ160B", "MCQ160C", "MCQ160D", "MCQ160E", "MCQ160F")
linked$prevalent_cvd <- NA_integer_
linked$prevalent_cvd[
  rowSums(linked[cvd_variables] == 1, na.rm = TRUE) > 0
] <- 1L
linked$prevalent_cvd[
  rowSums(linked[cvd_variables] == 2, na.rm = TRUE) == length(cvd_variables)
] <- 0L

linked$confirmed_pregnant <-
  linked$sex == 2 & linked$RIDAGEYR >= 20 & linked$RIDAGEYR <= 44 &
  !is.na(linked$RIDEXPRG) & linked$RIDEXPRG == 1
linked$pregnancy_unknown <-
  linked$sex == 2 & linked$RIDAGEYR >= 20 & linked$RIDAGEYR <= 44 &
  !is.na(linked$RIDEXPRG) & linked$RIDEXPRG == 3

primary_variables <- c(
  "RIDAGEYR", "sex", "race_hispanic_origin", "education", "smoking",
  "bmi", "diabetes", "hypertension", "prevalent_cvd", "cycle"
)
linked$primary_complete <- complete.cases(linked[primary_variables])
linked$income_complete <- !is.na(linked$income_poverty_ratio)

missingness <- do.call(
  rbind,
  lapply(
    c(primary_variables, "income_poverty_ratio"),
    function(variable) {
      data.frame(
        variable = variable,
        n = nrow(linked),
        missing_n = sum(is.na(linked[[variable]])),
        missing_percent = 100 * mean(is.na(linked[[variable]])),
        stringsAsFactors = FALSE
      )
    }
  )
)

flow <- data.frame(
  step = c(
    "adult_crp_positive_mec_weight",
    "mortality_linkage_eligible",
    "confirmed_pregnant_excluded_from_primary",
    "primary_eligible_after_confirmed_pregnancy_exclusion",
    "pregnancy_status_unknown_retained_in_primary",
    "primary_complete_after_pregnancy_exclusion_and_recoding",
    "primary_and_income_complete_after_pregnancy_exclusion_and_recoding",
    "sensitivity_eligible_after_unknown_pregnancy_exclusion",
    "sensitivity_complete_after_unknown_pregnancy_exclusion"
  ),
  n = c(
    nrow(base),
    nrow(linked),
    sum(linked$confirmed_pregnant),
    sum(!linked$confirmed_pregnant),
    sum(linked$pregnancy_unknown),
    sum(linked$primary_complete & !linked$confirmed_pregnant),
    sum(
      linked$primary_complete & linked$income_complete &
        !linked$confirmed_pregnant
    ),
    sum(!linked$confirmed_pregnant & !linked$pregnancy_unknown),
    sum(
      linked$primary_complete & !linked$confirmed_pregnant &
        !linked$pregnancy_unknown
    )
  ),
  stringsAsFactors = FALSE
)

stopifnot(nrow(base) == 28924)
stopifnot(nrow(linked) == 28890)
stopifnot(nrow(duplicate_table) == 0)

write.csv(category_counts,
          file.path(output_dir, "qc_03_category_codes.csv"),
          row.names = FALSE, na = "")
write.csv(missingness,
          file.path(output_dir, "qc_03_missingness_reclassified.csv"),
          row.names = FALSE, na = "")
write.csv(flow,
          file.path(output_dir, "qc_03_eligibility_flow.csv"),
          row.names = FALSE, na = "")
write.csv(duplicate_table,
          file.path(output_dir, "qc_03_duplicate_seqn.csv"),
          row.names = FALSE, na = "")

message("Wrote QC 03 category, missingness, eligibility and duplicate tables.")
message("Confirmed pregnant participants: ", sum(linked$confirmed_pregnant))
message(
  "Primary complete cases after pregnancy exclusion and recoding: ",
  sum(linked$primary_complete & !linked$confirmed_pregnant), " / ",
  sum(!linked$confirmed_pregnant)
)
message(
  "Sensitivity complete cases after also excluding unknown pregnancy: ",
  sum(
    linked$primary_complete & !linked$confirmed_pregnant &
      !linked$pregnancy_unknown
  ), " / ",
  sum(!linked$confirmed_pregnant & !linked$pregnancy_unknown)
)
