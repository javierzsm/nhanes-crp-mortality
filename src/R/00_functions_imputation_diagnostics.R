# Descriptive diagnostics for outcome-blinded synthetic MICE validation.
# Review flags are not automatic evidence of convergence or validity.
export_synthetic_imputation_diagnostics <- function(obj, traces, original,
                                                    transforms, targets, prefix, paths) {
  stopifnot(obj$iteration >= 10L, obj$m >= 2L)
  flags <- list()
  keys <- unique(traces[c("variable", "statistic")])
  for (j in seq_len(nrow(keys))) {
    z <- traces[traces$variable == keys$variable[j] &
                  traces$statistic == keys$statistic[j], ]
    z <- z[z$iteration > obj$iteration - 10L, ]
    chains <- lapply(split(z, z$chain), function(a) a$value[order(a$iteration)])
    stopifnot(all(lengths(chains) == 10L))
    W <- mean(vapply(chains, stats::var, numeric(1)))
    B <- 10 * stats::var(vapply(chains, mean, numeric(1)))
    rhat <- if (W > 0) sqrt((.9 * W + B / 10) / W) else NA_real_
    ac <- vapply(chains, function(a) {
      if (stats::var(a) == 0) return(NA_real_)
      as.numeric(stats::acf(a, lag.max = 1, plot = FALSE)$acf[2])
    }, numeric(1))
    max_ac <- if (all(is.na(ac))) NA_real_ else max(abs(ac), na.rm = TRUE)
    delta <- mean(vapply(chains, function(a) mean(a[6:10]) - mean(a[1:5]), numeric(1)))
    drift <- if (W > 0) abs(delta) / sqrt(W) else NA_real_
    flags[[j]] <- data.frame(variable = keys$variable[j], statistic = keys$statistic[j],
      psrf_classic = rhat, max_abs_lag1 = max_ac, window_delta = delta,
      window_delta_sd = drift, constant_trace = W == 0,
      review_flag = is.na(rhat) || is.na(max_ac) || is.na(drift) ||
        rhat > 1.05 || max_ac > .5 || drift > .2)
  }
  flags <- do.call(rbind, flags)
  # All summaries concern original missing cells, never overwritten observations.
  rows_bmi <- rows_category <- list()
  imputed_bmi <- list()
  groups <- list(overall = rep("all", nrow(original)),
                 cycle = as.character(original$cycle),
                 death = as.character(original$death))
  for (chain in seq_len(obj$m)) {
    completed <- mice::complete(obj, chain)
    for (v in targets) {
      missing <- is.na(original[[v]])
      imputed <- completed[[v]][missing]
      if (v == "bmi") {
        imputed <- imputed * transforms$bmi[["sd"]] + transforms$bmi[["mean"]]
        imputed_bmi[[chain]] <- imputed
      }
      for (group in names(groups)) for (level in unique(groups[[group]])) {
        member <- groups[[group]] == level
        subsets <- list(observed = original[[v]][member & !missing],
                        imputed = imputed[member[missing]])
        for (kind in names(subsets)) {
          values <- subsets[[kind]]
          if (v == "bmi") {
            summaries <- if (length(values)) {
              c(mean = mean(values), sd = stats::sd(values),
                stats::setNames(as.numeric(stats::quantile(values,
                  c(.01,.05,.25,.5,.75,.95,.99))), c("p01","p05","p25","p50","p75","p95","p99")),
                minimum = min(values), maximum = max(values))
            } else stats::setNames(rep(NA_real_,11L),
              c("mean","sd","p01","p05","p25","p50","p75","p95","p99","minimum","maximum"))
            rows_bmi[[length(rows_bmi)+1L]] <- data.frame(chain=chain, group=group,
              group_level=level, kind=kind, n=length(values), statistic=names(summaries),
              value=as.numeric(summaries))
          } else {
            counts <- table(factor(values, levels=levels(original[[v]])))
            rows_category[[length(rows_category)+1L]] <- data.frame(chain=chain,
              variable=v, group=group, group_level=level, kind=kind,
              category=names(counts), count=as.integer(counts), n=length(values),
              proportion=if(length(values)) as.numeric(counts)/length(values) else NA_real_)
          }
        }
      }
    }
  }
  write_csv_checked(flags, file.path(paths$tables,paste0(prefix,"_convergence.csv")))
  write_csv_checked(do.call(rbind,rows_bmi),
                    file.path(paths$tables,paste0(prefix,"_bmi_distributions.csv")))
  write_csv_checked(do.call(rbind,rows_category),
                    file.path(paths$tables,paste0(prefix,"_category_distributions.csv")))
  figure_dir <- file.path("output","figures")
  dir.create(figure_dir, recursive=TRUE, showWarnings=FALSE)
  draw_traces <- function(selected, path, layout, width, height) {
    if(file.exists(path)) stop("Refusing figure overwrite.")
    grDevices::png(path,width=width,height=height,res=150)
    on.exit(grDevices::dev.off())
    graphics::par(mfrow=layout,mar=c(3,4,3,1))
    for(j in seq_len(nrow(selected))) {
      z <- traces[traces$variable==selected$variable[j] &
                    traces$statistic==selected$statistic[j],]
      graphics::plot(range(z$iteration),range(z$value),type="n",xlab="Iteration",
        ylab=selected$statistic[j],main=paste(selected$variable[j],selected$statistic[j]))
      for(chain in seq_len(obj$m)) {
        a <- z[z$chain==chain,]; a <- a[order(a$iteration),]
        graphics::lines(a$iteration,a$value,col=chain,lty=chain)
      }
    }
  }
  draw_traces(keys[keys$variable=="bmi" & keys$statistic %in% c("mean","variance"),],
    file.path(figure_dir,paste0(prefix,"_bmi_traces.png")),c(2,1),1500,1100)
  draw_traces(keys[keys$variable!="bmi",],
    file.path(figure_dir,paste0(prefix,"_category_traces.png")),c(5,3),2400,2400)
  path <- file.path(figure_dir,paste0(prefix,"_bmi_distributions.png"))
  if(file.exists(path)) stop("Refusing figure overwrite.")
  grDevices::png(path,width=1500,height=1000,res=150)
  observed <- original$bmi[!is.na(original$bmi)]
  density_observed <- stats::density(observed)
  densities <- lapply(imputed_bmi,stats::density)
  graphics::plot(density_observed,xlab="BMI",main="Synthetic observed and imputed BMI",
    ylim=c(0,max(c(density_observed$y,unlist(lapply(densities,function(a)a$y))))))
  for(chain in seq_len(obj$m)) graphics::lines(densities[[chain]],col=chain+1,lty=chain)
  graphics::legend("topright",legend=c("Observed",paste("Imputed chain",seq_len(obj$m))),
    col=seq_len(obj$m+1L),lty=c(1,seq_len(obj$m)),bty="n")
  grDevices::dev.off()
  invisible(list(flags=flags))
}
