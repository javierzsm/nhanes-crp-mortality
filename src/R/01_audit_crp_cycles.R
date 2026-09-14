#!/usr/bin/env Rscript

# Audit exposure availability and mortality-linkage eligibility.
# Mortality status and follow-up time are deliberately not read.

if (!requireNamespace("haven", quietly = TRUE)) {
  stop("Package 'haven' is required.", call. = FALSE)
}

cycles <- data.frame(
  cycle = c("1999-2000", "2001-2002", "2003-2004", "2005-2006", "2007-2008", "2009-2010"),
  start_year = c(1999, 2001, 2003, 2005, 2007, 2009),
  lab_file = c("LAB11", "L11_B", "L11_C", "CRP_D", "CRP_E", "CRP_F"),
  demo_file = c("DEMO", "DEMO_B", "DEMO_C", "DEMO_D", "DEMO_E", "DEMO_F"),
  stringsAsFactors = FALSE
)

raw_dir <- file.path("data", "raw", "nhanes")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = max(300, getOption("timeout")))

download_if_missing <- function(url, destination, expected_size = NULL) {
  valid_existing <- file.exists(destination) &&
    (is.null(expected_size) || file.info(destination)$size == expected_size)
  if (valid_existing) {
    return(invisible(destination))
  }

  temporary <- paste0(destination, ".part")
  if (file.exists(temporary)) unlink(temporary)
  on.exit(if (file.exists(temporary)) unlink(temporary), add = TRUE)

  download.file(
    url,
    temporary,
    mode = "wb",
    quiet = FALSE,
    method = "libcurl"
  )
  if (!is.null(expected_size) && file.info(temporary)$size != expected_size) {
    stop(
      "Downloaded file has unexpected size: ", basename(destination),
      call. = FALSE
    )
  }
  if (file.exists(destination)) unlink(destination)
  if (!file.rename(temporary, destination)) {
    stop("Could not finalize download: ", basename(destination), call. = FALSE)
  }
  invisible(destination)
}

read_eligibility <- function(path) {
  lines <- readLines(path, warn = FALSE)
  data.frame(
    SEQN = as.numeric(substr(lines, 1, 6)),
    ELIGSTAT = as.integer(substr(lines, 15, 15))
  )
}

sha256_file <- function(path) {
  output <- system2("sha256sum", path, stdout = TRUE)
  strsplit(output, "[[:space:]]+")[[1]][1]
}

audit_one_cycle <- function(i) {
  row <- cycles[i, ]
  base <- sprintf(
    "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/%s/DataFiles",
    row$start_year
  )
  lab_path <- file.path(raw_dir, paste0(row$lab_file, ".xpt"))
  demo_path <- file.path(raw_dir, paste0(row$demo_file, ".xpt"))
  mortality_name <- sprintf(
    "NHANES_%s_MORT_2019_PUBLIC.dat",
    gsub("-", "_", row$cycle)
  )
  mortality_path <- file.path(raw_dir, mortality_name)
  mortality_sizes <- c(
    "1999-2000" = 487666,
    "2001-2002" = 540362,
    "2003-2004" = 495722,
    "2005-2006" = 506774,
    "2007-2008" = 498376,
    "2009-2010" = 517751
  )

  download_if_missing(paste0(base, "/", row$lab_file, ".xpt"), lab_path)
  download_if_missing(paste0(base, "/", row$demo_file, ".xpt"), demo_path)
  download_if_missing(
    paste0(
      "https://ftp.cdc.gov/pub/Health_Statistics/NCHS/datalinkage/",
      "linked_mortality/", mortality_name
    ),
    mortality_path,
    expected_size = unname(mortality_sizes[row$cycle])
  )

  lab <- haven::read_xpt(lab_path)[c("SEQN", "LBXCRP")]
  demo_all <- haven::read_xpt(demo_path)
  demo_variables <- intersect(
    c("SEQN", "RIDAGEYR", "WTMEC2YR", "WTMEC4YR"),
    names(demo_all)
  )
  demo <- demo_all[demo_variables]
  mortality <- read_eligibility(mortality_path)

  joined <- merge(demo, lab, by = "SEQN", all.x = TRUE)
  joined <- merge(joined, mortality, by = "SEQN", all.x = TRUE)
  eligible_exposure <- with(
    joined,
    RIDAGEYR >= 20 & !is.na(LBXCRP) & WTMEC2YR > 0
  )
  analytic_base <- joined[eligible_exposure, ]

  data.frame(
    cycle = row$cycle,
    lab_file = row$lab_file,
    adult_crp_positive_mec_weight = nrow(analytic_base),
    below_detection_fill_n = sum(analytic_base$LBXCRP == 0.01),
    mortality_linkage_ineligible_n = sum(analytic_base$ELIGSTAT == 3),
    crp_min_mg_dl = min(analytic_base$LBXCRP),
    crp_max_mg_dl = max(analytic_base$LBXCRP),
    lab_sha256 = sha256_file(lab_path),
    demo_sha256 = sha256_file(demo_path),
    mortality_sha256 = sha256_file(mortality_path),
    stringsAsFactors = FALSE
  )
}

audit <- do.call(rbind, lapply(seq_len(nrow(cycles)), audit_one_cycle))

output_path <- file.path("output", "tables", "qc_01_crp_cycle_audit.csv")
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
write.csv(audit, output_path, row.names = FALSE, na = "")

stopifnot(sum(audit$adult_crp_positive_mec_weight) == 28924)
stopifnot(sum(audit$below_detection_fill_n) == 684)
stopifnot(sum(audit$mortality_linkage_ineligible_n) == 34)

message("Wrote ", output_path)
