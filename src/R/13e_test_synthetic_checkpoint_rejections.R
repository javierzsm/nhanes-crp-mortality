#!/usr/bin/env Rscript
# Exercise the actual synthetic validator's resume gate without any MICE fits.
source(file.path("src", "R", "00_config.R"))
source(file.path("src", "R", "00_functions_data.R"))
assert_project_root()
output <- file.path(paths$tables, "qc_13e_synthetic_checkpoint_rejections.csv")
if (file.exists(output)) stop("Checkpoint test QC exists; review/version first.")
source_path <- file.path("src", "R", "13d_validate_imputation_extended_synthetic.R")
checkpoint_path <- file.path(paths$processed, "qc_13d_extended_synthetic_v1_iter000.rds")
if (!file.exists(checkpoint_path)) stop("Synthetic initialization checkpoint is required.")
expressions <- parse(source_path)
branches <- Filter(function(e) is.call(e) && identical(e[[1L]], as.name("if")) &&
                     identical(e[[2L]], as.name("resume")), as.list(expressions))
stopifnot(length(branches) == 1L)
good <- readRDS(checkpoint_path)
stopifnot(identical(unname(good$manifest$code_md5), unname(tools::md5sum(source_path))))
run_gate <- function(checkpoint, corrupt = FALSE) {
  temporary <- tempfile(fileext = ".rds")
  on.exit(unlink(temporary))
  if (corrupt) writeLines("intentional invalid RDS", temporary) else saveRDS(checkpoint, temporary)
  context <- new.env(parent = globalenv())
  context$resume <- TRUE
  context$checkpoint_files <- temporary
  context$manifest <- good$manifest
  context$pred <- good$mids$predictorMatrix
  context$methods <- good$mids$method
  context$audit <- new.env(parent = emptyenv())
  result <- tryCatch({
    eval(branches[[1L]], envir = context)
    stopifnot(identical(context$obj$imp, good$mids$imp),
              identical(context$obj$lastSeedValue, good$mids$lastSeedValue))
    TRUE
  }, error = function(e) FALSE)
  result
}
checks <- c(valid_checkpoint_accepted = run_gate(good))
bad <- good; bad$manifest$seed <- bad$manifest$seed + 1L
checks <- c(checks, changed_manifest_rejected = !run_gate(bad))
bad <- good; bad$rng[2L] <- bad$rng[2L] + 1L
checks <- c(checks, altered_rng_rejected = !run_gate(bad))
bad <- good; bad$mids$predictorMatrix[1L,2L] <- 0
checks <- c(checks, changed_predictor_matrix_rejected = !run_gate(bad))
bad <- good; bad$mids$method[["bmi"]] <- "norm"
checks <- c(checks, changed_method_rejected = !run_gate(bad),
            corrupt_rds_rejected = !run_gate(good, corrupt = TRUE))
stopifnot(all(checks))
write_csv_checked(data.frame(check = names(checks), passed = unname(checks)), output)
message("All synthetic checkpoint acceptance/rejection controls passed.")
