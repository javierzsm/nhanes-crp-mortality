# Exact comparisons and observed worker CPU utilization; no study fitting.
root <- 'data/processed/qc_13j_cpu60_benchmark_v1'
outputs <- file.path(root,c('four_equivalence.csv','four_comparison.csv'))
if(any(file.exists(outputs))) stop('Review outputs already exist.')
fields <- c('imp','chainMean','chainVar','lastSeedValue','iteration','data','method','where','predictorMatrix','loggedEvents')
checks <- lapply(1:4,function(i) {
 a<-readRDS(file.path(root,paste0('gc_single_',i,'.rds')))
 b<-readRDS(file.path(root,paste0('gc_four_',i,'.rds')))
 data.frame(check=paste0('gc_sequential_parallel_exact_',i),passed=identical(a[fields],b[fields]))
})
qc<-do.call(rbind,checks);print(qc);stopifnot(all(qc$passed));write.csv(qc,outputs[[1]],row.names=FALSE)
p<-read.csv(file.path(root,'phases.csv'));q<-read.csv(file.path(root,'four_phases.csv'))
seq_time<-p$wall_seconds[p$phase=='gc_single']+sum(q$wall_seconds[q$workers==1])
par<-q[q$phase=='gc_four',]
timings<-do.call(rbind,lapply(1:4,function(i)read.csv(file.path(root,paste0('gc_four_',i,'_timing.csv')))))
result<-data.frame(chains=4,sequential_seconds=seq_time,parallel_seconds=par$wall_seconds,
 speedup=seq_time/par$wall_seconds,reduction_pct=100*(1-par$wall_seconds/seq_time),
 peak_rss_gib=par$aggregate_peak_rss_kib/1024^2,
 minimum_available_gib=par$minimum_available_kib/1024^2,
 continuation_cpu_seconds=sum(timings$cpu),
 approximate_logical_cpu_pct=100*sum(timings$cpu)/par$wall_seconds/16)
print(result);write.csv(result,outputs[[2]],row.names=FALSE)
