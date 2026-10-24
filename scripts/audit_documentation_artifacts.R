#!/usr/bin/env Rscript
# Read-only comparison with recorded historical hashes; never rewrite a manifest.
source('src/R/00_functions_imputation_execution.R')
out <- 'reports/documentation_quality_v1'
spec <- list(
 list('data/processed/mi14_20261014_fourworker_v1/accepted_endpoint_020.rds','checkpoint_hashes'),
 list('data/processed/mi14_20261014_fourworker_v1/plan.rds','manifest.hashes'),
 list('data/processed/mi15_20261014_fourworker_v1_v2/phase_complete.rds','hashes'),
 list('data/processed/reporting_stage6_v1_manifest.rds','hashes'),
 list('data/processed/methodological_manuscript_v1_manifest.rds','hashes'),
 list('data/processed/same_month_death_sensitivity_v1.rds','input_hashes'),
 list('data/processed/same_month_death_sensitivity_v1.rds','hashes'))
rows <- lapply(spec,function(s) {
 obj <- readRDS(s[[1]])
 x <- if(s[[2]]=='manifest.hashes') obj$manifest$hashes else obj[[s[[2]]]]
 actual <- mi_hashes(names(x))
 data.frame(manifest=s[[1]],field=s[[2]],path=names(x),recorded_md5=unname(x),
 current_md5=unname(actual),unchanged=unname(x)==unname(actual),stringsAsFactors=FALSE)
})
rows <- do.call(rbind,rows)
# Documentation fingerprints deliberately remain historical after this revision.
doc <- grepl('\\.(md|qmd|html)$',rows$path,ignore.case=TRUE)
write.csv(rows[!doc,],file.path(out,'historical_artifact_checks.csv'),row.names=FALSE)
write.csv(rows[doc,],file.path(out,'historical_document_references.csv'),row.names=FALSE)
stopifnot(all(rows$unchanged[!doc]))
archive <- 'data/processed/mi14_20261014_fourworker_v1/sources/multiple_imputation_technical_spec_draft.md'
expected <- readRDS(spec[[2]][[1]])$manifest$hashes['docs/methods/multiple_imputation_technical_spec_draft.md']
a <- data.frame(path=archive,recorded_md5=unname(expected),current_md5=unname(mi_hashes(archive)))
a$passed <- a$recorded_md5==a$current_md5
stopifnot(all(a$passed))
write.csv(a,file.path(out,'archived_specification_check.csv'),row.names=FALSE)
cat(sum(!doc),' non-document artifact references unchanged; ',
 sum(!rows$unchanged[doc]),' historical documentation differences disclosed.\n',sep='')
# Check numerical notation against saved coefficient/variance inputs, without fits.
text <- paste(readLines('reports/metodologia_comentada_v1/manuscrito_metodologico_es.md'),collapse='\n')
q <- read.csv('output/tables/mi15_20261014_fourworker_v1_v2_per_imputation.csv')
p <- read.csv('output/tables/mi15_20261014_fourworker_v1_v2_pooled.csv')
cc <- read.csv('output/tables/table_02_primary_crp_hazard_ratios.csv')
cc <- cc[cc$model=='Primary',]
w <- mean(q$variance); b <- var(q$beta); total <- w+(1+1/nrow(q))*b
pool <- mice::pool.scalar(q$beta,q$variance,n=92,k=1)
close <- function(x,y) isTRUE(all.equal(unname(x),unname(y),tolerance=1e-10))
numeric_checks <- data.frame(check=c('fifty_saved_imputation_estimates','Rubin_mean','Rubin_within',
 'Rubin_between','Rubin_total','independent_pool_total','independent_pool_df','primary_HR_interval',
 'English_primary_coefficient','English_MI_coefficient','English_Rubin_total','English_same_month_result',
 'thirty_four_main_sections'),passed=c(nrow(q)==50L,close(mean(q$beta),p$beta),
 close(w,p$within_variance),close(b,p$between_variance),close(total,p$total_variance),
 close(pool$t,p$total_variance),close(pool$df,p$df),
 close(exp(cc$log_hazard_ratio+c(0,-qnorm(.975),qnorm(.975))*cc$standard_error),
 c(cc$hazard_ratio,cc$confidence_low,cc$confidence_high)),
 grepl('0.1220883',text,fixed=TRUE),grepl('0.126956936985662',text,fixed=TRUE),
 grepl('8.23145878169100',text,fixed=TRUE),
 all(vapply(c('1.129632','1.108576–1.151088','−0.01965%'),grepl,logical(1),x=text,fixed=TRUE)),
 sum(grepl('^## ',strsplit(text,'\n',fixed=TRUE)[[1]]))==34L))
stopifnot(all(numeric_checks$passed))
write.csv(numeric_checks,file.path(out,'numerical_crosschecks.csv'),row.names=FALSE)
cat(nrow(numeric_checks),'numerical/text cross-checks passed.\n')
