#!/usr/bin/env Rscript
# Complementary review of ALL prespecified synthetic history; no model fitting.
source(file.path("src", "R", "00_config.R"))
source(file.path("src", "R", "00_functions_data.R"))
assert_project_root()
prefix <- "qc_13f_extended_synthetic40_v1"
windows_output <- file.path(paths$tables, paste0(prefix, "_review_windows_reproduced.csv"))
ac_output <- file.path(paths$tables, paste0(prefix, "_review_signed_ac.csv"))
if (any(file.exists(c(windows_output, ac_output)))) stop("Review outputs exist; preserve/version first.")
traces <- utils::read.csv(file.path(paths$tables,paste0(prefix,"_traces.csv")))
stopifnot(all(c("variable","statistic","chain","iteration","value") %in% names(traces)),
          identical(sort(unique(traces$iteration)),1:40),
          identical(sort(unique(traces$chain)),1:3),all(is.finite(traces$value)))
keys <- unique(traces[c("variable","statistic")])
rows <- ac_rows <- list()
for(j in seq_len(nrow(keys))) for(window in c(10L,20L,30L,40L)) {
  a <- traces[traces$variable==keys$variable[j] & traces$statistic==keys$statistic[j] &
                traces$iteration>40-window,]
  chains <- lapply(split(a,a$chain),function(d)d$value[order(d$iteration)])
  stopifnot(all(lengths(chains)==window))
  W <- mean(vapply(chains,stats::var,numeric(1)))
  B <- window*stats::var(vapply(chains,mean,numeric(1)))
  rows[[length(rows)+1L]] <- data.frame(variable=keys$variable[j],statistic=keys$statistic[j],
    window=window,psrf=if(W>0)sqrt(((window-1)/window*W+B/window)/W) else NA_real_,
    constant_chains=sum(vapply(chains,stats::var,numeric(1))==0))
  for(chain in seq_along(chains)) {
    values <- chains[[chain]]
    ac_rows[[length(ac_rows)+1L]] <- data.frame(variable=keys$variable[j],
      statistic=keys$statistic[j],window=window,chain=chain,
      lag1=if(stats::var(values)>0) as.numeric(stats::acf(values,lag.max=1,plot=FALSE)$acf[2]) else NA_real_)
  }
}
windows <- do.call(rbind,rows)
# This reproduces the separately recorded interactive review; no favorable
# window is substituted for the original last-ten-iteration flags.
recorded <- utils::read.csv(file.path(paths$tables,paste0(prefix,"_review_windows.csv")))
rownames(recorded) <- rownames(windows) <- NULL
stopifnot(isTRUE(all.equal(recorded,windows,tolerance=1e-12)))
write_csv_checked(windows,windows_output)
write_csv_checked(do.call(rbind,ac_rows),ac_output)
message("Complementary window and signed-autocorrelation review exported.")
