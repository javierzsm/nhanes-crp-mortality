#!/usr/bin/env Rscript

# Audit baseline covariate availability and missingness.
# Mortality status and follow-up time are deliberately not read.

if (!requireNamespace("haven", quietly = TRUE)) {
  stop("Package 'haven' is required.", call. = FALSE)
}

cycles <- data.frame(
  cycle = c("1999-2000", "2001-2002", "2003-2004", "2005-2006", "2007-2008", "2009-2010"),
  start_year = c(1999, 2001, 2003, 2005, 2007, 2009),
  suffix = c("", "_B", "_C", "_D", "_E", "_F"),
  lab_file = c("LAB11", "L11_B", "L11_C", "CRP_D", "CRP_E", "CRP_F"),
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

read_component <- function(start_year, file) {
  path <- file.path(raw_dir, paste0(file, ".xpt"))
  url <- sprintf(
    "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/%s/DataFiles/%s.xpt",
    start_year,
    file
  )
  download_if_missing(url, path)
  haven::read_xpt(path)
}

read_eligibility <- function(cycle) {
  name <- sprintf(
    "NHANES_%s_MORT_2019_PUBLIC.dat",
    gsub("-", "_", cycle)
  )
  path <- file.path(raw_dir, name)
  url <- paste0(
    "https://ftp.cdc.gov/pub/Health_Statistics/NCHS/datalinkage/",
    "linked_mortality/", name
  )
  expected_sizes <- c(
    "1999-2000" = 487666,
    "2001-2002" = 540362,
    "2003-2004" = 495722,
    "2005-2006" = 506774,
    "2007-2008" = 498376,
    "2009-2010" = 517751
  )
  download_if_missing(
    url,
    path,
    expected_size = unname(expected_sizes[cycle])
  )
  lines <- readLines(path, warn = FALSE)
  data.frame(
    SEQN = as.numeric(substr(lines, 1, 6)),
    ELIGSTAT = as.integer(substr(lines, 15, 15))
  )
}

select_existing <- function(data, variables) {
  missing_variables <- setdiff(variables, names(data))
  if (length(missing_variables) > 0) {
    stop(
      "Missing expected variables: ",
      paste(missing_variables, collapse = ", "),
      call. = FALSE
    )
  }
  data[variables]
}

audit_cycle <- function(i) {
  row <- cycles[i, ]
  component_names <- c("DEMO", "SMQ", "BMX", "DIQ", "BPQ", "MCQ")
  files <- paste0(component_names, row$suffix)
  files[component_names == "DEMO" & row$cycle == "1999-2000"] <- "DEMO"

  demo <- select_existing(
    read_component(row$start_year, files[1]),
    c(
      "SEQN", "RIDAGEYR", "RIAGENDR", "RIDRETH1", "DMDEDUC2",
      "INDFMPIR", "WTMEC2YR", "SDMVSTRA", "SDMVPSU"
    )
  )
  smq <- select_existing(
    read_component(row$start_year, files[2]),
    c("SEQN", "SMQ020", "SMQ040")
  )
  bmx <- select_existing(
    read_component(row$start_year, files[3]),
    c("SEQN", "BMXBMI")
  )
  diq <- select_existing(
    read_component(row$start_year, files[4]),
    c("SEQN", "DIQ010")
  )
  bpq <- select_existing(
    read_component(row$start_year, files[5]),
    c("SEQN", "BPQ020")
  )
  mcq <- select_existing(
    read_component(row$start_year, files[6]),
    c("SEQN", "MCQ160B", "MCQ160C", "MCQ160D", "MCQ160E", "MCQ160F")
  )
  lab <- select_existing(
    read_component(row$start_year, row$lab_file),
    c("SEQN", "LBXCRP")
  )

  components <- list(smq, bmx, diq, bpq, mcq, lab, read_eligibility(row$cycle))
  joined <- Reduce(
    function(x, y) merge(x, y, by = "SEQN", all.x = TRUE),
    components,
    init = demo
  )
  joined <- joined[
    joined$RIDAGEYR >= 20 &
      !is.na(joined$LBXCRP) &
      joined$WTMEC2YR > 0 &
      !is.na(joined$ELIGSTAT) &
      joined$ELIGSTAT == 1,
  ]
  joined$cycle <- row$cycle
  joined
}

data <- do.call(rbind, lapply(seq_len(nrow(cycles)), audit_cycle))

data$smoking <- NA_character_
data$smoking[data$SMQ020 == 2] <- "never"
data$smoking[data$SMQ020 == 1 & data$SMQ040 == 3] <- "former"
data$smoking[data$SMQ020 == 1 & data$SMQ040 %in% c(1, 2)] <- "current"

cvd_variables <- c("MCQ160B", "MCQ160C", "MCQ160D", "MCQ160E", "MCQ160F")
data$prevalent_cvd <- NA_integer_
data$prevalent_cvd[rowSums(data[cvd_variables] == 1, na.rm = TRUE) > 0] <- 1L
all_cvd_no <- rowSums(data[cvd_variables] == 2, na.rm = TRUE) == length(cvd_variables)
data$prevalent_cvd[all_cvd_no] <- 0L

variables <- c(
  age = "RIDAGEYR",
  sex = "RIAGENDR",
  race_hispanic_origin = "RIDRETH1",
  education = "DMDEDUC2",
  smoking = "smoking",
  bmi = "BMXBMI",
  diabetes = "DIQ010",
  hypertension = "BPQ020",
  prevalent_cvd = "prevalent_cvd",
  income_poverty_ratio = "INDFMPIR"
)

audit <- do.call(
  rbind,
  lapply(names(variables), function(label) {
    variable <- variables[[label]]
    data.frame(
      construct = label,
      variable = variable,
      n = nrow(data),
      missing_n = sum(is.na(data[[variable]])),
      missing_percent = 100 * mean(is.na(data[[variable]])),
      stringsAsFactors = FALSE
    )
  })
)

primary_variables <- unname(variables[names(variables) != "income_poverty_ratio"])
primary_complete <- complete.cases(data[primary_variables])
all_complete <- complete.cases(data[unname(variables)])

stopifnot(nrow(data) == 28890)
stopifnot(sum(primary_complete) == 28031)
stopifnot(sum(all_complete) == 25800)

output_path <- file.path("output", "tables", "qc_02_covariate_missingness.csv")
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
write.csv(audit, output_path, row.names = FALSE, na = "")

message("Wrote ", output_path)
message("Primary complete cases: ", sum(primary_complete), " / ", nrow(data))
message("Complete cases including income-to-poverty ratio: ", sum(all_complete), " / ", nrow(data))
