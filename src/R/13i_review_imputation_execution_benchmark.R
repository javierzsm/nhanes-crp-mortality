root <- 'data/processed/qc_13i_execution_benchmark_v1'
if(any(file.exists(file.path(root,c('equivalence.csv','timings.csv','comparison.csv'))))) stop('Review outputs already exist.')
fields <- c('imp','chainMean','chainVar','lastSeedValue','iteration','data','method','where','predictorMatrix','loggedEvents')
checks <- list()
for (i in 1:2) {
 a <- readRDS(file.path(root,paste0('original_',i,'.rds')))
 b <- readRDS(file.path(root,paste0('compact_',i,'.rds')))
 c <- readRDS(file.path(root,paste0('parallel_',i,'.rds')))
 checks[[length(checks)+1L]] <- data.frame(check=paste0('original_compact_exact_chain_',i),passed=identical(a[fields],b[fields]))
 checks[[length(checks)+1L]] <- data.frame(check=paste0('sequential_parallel_exact_chain_',i),passed=identical(b[fields],c[fields]))
}
a <- readRDS(file.path(root,'parallel_1.rds'));b <- readRDS(file.path(root,'replay_1.rds'))
checks[[length(checks)+1L]] <- data.frame(check='checkpoint_input_replay_exact',passed=identical(a[fields],b[fields]))
qc <- do.call(rbind,checks); print(qc);stopifnot(all(qc$passed))
write.csv(qc,file.path(root,'equivalence.csv'),row.names=FALSE)
timings <- do.call(rbind,lapply(list.files(root,pattern='_timing.csv$',full.names=TRUE),read.csv));print(timings)
write.csv(timings,file.path(root,'timings.csv'),row.names=FALSE)
p <- read.csv(file.path(root,'phases.csv')); print(p)
seq_original <- sum(p$wall_seconds[p$phase %in% c('sequential_original_1','sequential_original_2')])
seq_compact <- sum(p$wall_seconds[p$phase %in% c('sequential_compact_1','sequential_compact_2')])
par <- p$wall_seconds[p$phase=='parallel_compact']
comparison <- data.frame(original_seconds=seq_original,compact_seconds=seq_compact,parallel_seconds=par,speedup=seq_compact/par,wall_reduction_pct=100*(1-par/seq_compact))
print(comparison)
write.csv(comparison,file.path(root,"comparison.csv"),row.names=FALSE)
