assert_project_root <- function() {
  required <- c("README.md", file.path("src", "R", "00_config.R"))
  missing <- required[!file.exists(required)]
  if (length(missing) > 0) {
    stop(
      "Run the script from the repository root. Missing: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
}

require_package <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop("Package '", package, "' is required.", call. = FALSE)
  }
}

download_if_missing <- function(url, destination, expected_size = NULL) {
  valid_existing <- file.exists(destination) &&
    (is.null(expected_size) || file.info(destination)$size == expected_size)
  if (valid_existing) return(invisible(destination))

  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(destination, ".part")
  if (file.exists(temporary)) unlink(temporary)
  on.exit(if (file.exists(temporary)) unlink(temporary), add = TRUE)

  download.file(
    url, temporary, mode = "wb", quiet = FALSE, method = "libcurl"
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

read_nhanes_component <- function(start_year, file, raw_dir) {
  require_package("haven")
  destination <- file.path(raw_dir, paste0(file, ".xpt"))
  url <- sprintf(
    "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/%s/DataFiles/%s.xpt",
    start_year, file
  )
  download_if_missing(url, destination)
  haven::read_xpt(destination)
}

read_mortality_file <- function(cycle, raw_dir, expected_size) {
  filename <- sprintf(
    "NHANES_%s_MORT_2019_PUBLIC.dat",
    gsub("-", "_", cycle)
  )
  destination <- file.path(raw_dir, filename)
  url <- paste0(
    "https://ftp.cdc.gov/pub/Health_Statistics/NCHS/datalinkage/",
    "linked_mortality/", filename
  )
  download_if_missing(url, destination, expected_size)

  lines <- readLines(destination, warn = FALSE)
  # Some public LMF records omit trailing blanks and line endings differ by
  # platform. The fields through MORTSTAT must always be present; follow-up is
  # validated after linkage eligibility has been applied.
  if (length(lines) == 0 || any(nchar(lines) < 16)) {
    stop("Invalid mortality fixed-width file: ", filename, call. = FALSE)
  }

  numeric_field <- function(start, end) {
    suppressWarnings(as.numeric(trimws(substr(lines, start, end))))
  }

  data.frame(
    SEQN = numeric_field(1, 6),
    ELIGSTAT = numeric_field(15, 15),
    MORTSTAT = numeric_field(16, 16),
    PERMTH_EXM = numeric_field(46, 48),
    stringsAsFactors = FALSE
  )
}

select_required <- function(data, variables, component) {
  missing <- setdiff(variables, names(data))
  if (length(missing) > 0) {
    stop(
      "Missing variables in ", component, ": ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  data[variables]
}

left_join_unique <- function(x, y, component) {
  if (anyDuplicated(y$SEQN)) {
    stop("Duplicate SEQN in component: ", component, call. = FALSE)
  }
  before <- nrow(x)
  result <- merge(x, y, by = "SEQN", all.x = TRUE, sort = FALSE)
  if (nrow(result) != before) {
    stop("Join changed row count for component: ", component, call. = FALSE)
  }
  result
}

valid_or_na <- function(x, valid) {
  ifelse(x %in% valid, as.numeric(x), NA_real_)
}

derive_smoking <- function(smq020, smq040) {
  result <- rep(NA_character_, length(smq020))
  result[smq020 == 2] <- "never"
  result[smq020 == 1 & smq040 == 3] <- "former"
  result[smq020 == 1 & smq040 %in% c(1, 2)] <- "current"
  factor(result, levels = c("never", "former", "current"))
}

derive_prevalent_cvd <- function(data) {
  variables <- c("MCQ160B", "MCQ160C", "MCQ160D", "MCQ160E", "MCQ160F")
  result <- rep(NA_integer_, nrow(data))
  result[rowSums(data[variables] == 1, na.rm = TRUE) > 0] <- 1L
  explicit_no <- rowSums(data[variables] == 2, na.rm = TRUE) == length(variables)
  result[explicit_no] <- 0L
  result
}

derive_pooled_mec_weight <- function(data) {
  early <- data$cycle %in% c("1999-2000", "2001-2002")
  result <- rep(NA_real_, nrow(data))
  result[early] <- data$WTMEC4YR[early] / 3
  result[!early] <- data$WTMEC2YR[!early] / 6
  result
}

label_analysis_variables <- function(data) {
  data$sex <- factor(
    data$sex_code,
    levels = c(1, 2), labels = c("Male", "Female")
  )
  data$race_hispanic_origin <- factor(
    data$race_code,
    levels = 1:5,
    labels = c(
      "Mexican American", "Other Hispanic", "Non-Hispanic White",
      "Non-Hispanic Black", "Other or multiracial"
    )
  )
  data$education <- factor(
    data$education_code,
    levels = 1:5,
    labels = c(
      "Less than 9th grade", "9th-11th grade",
      "High school graduate or GED", "Some college or AA degree",
      "College graduate or above"
    )
  )
  data$diabetes <- factor(
    data$diabetes_code,
    levels = c(2, 3, 1), labels = c("No", "Borderline", "Yes")
  )
  data$hypertension <- factor(
    data$hypertension_code,
    levels = c(2, 1), labels = c("No", "Yes")
  )
  data$prevalent_cvd <- factor(
    data$prevalent_cvd_code,
    levels = c(0, 1), labels = c("No", "Yes")
  )
  data$cycle <- factor(data$cycle, levels = analysis_cycles$cycle)
  data
}

write_csv_checked <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(data, path, row.names = FALSE, na = "")
  if (!file.exists(path) || file.info(path)$size == 0) {
    stop("Failed to write output: ", path, call. = FALSE)
  }
  invisible(path)
}
