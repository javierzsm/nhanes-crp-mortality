# Read independent chain checkpoints sequentially; no Cox fits or pooled effects.
mi_export_review <- function(root,plan,iteration) {
  prefix<-paste0('mi14_',plan$manifest$run_id,'_iter',sprintf('%03d',iteration))
  destinations<-file.path('output/tables',paste0(prefix,c('_traces.csv','_multinomial.csv','_convergence.csv','_draws.csv')))
  if(any(file.exists(destinations)))stop('Review outputs already exist.')
  traces<-fits<-draws<-list()
  plan_hash<-unname(mi_hashes(file.path(root,'plan.rds')))
  for(chain in seq_len(plan$manifest$m))for(i in seq_len(iteration)) {
    state<-readRDS(file.path(root,sprintf('chain_%03d',chain),sprintf('iteration_%03d.rds',i)))
    stopifnot(state$chain==chain,state$mids$iteration==i,identical(state$plan_hash,plan_hash))
    mi_check_state(state$mids,plan)
    traces[[length(traces)+1L]]<-state$trace;fits[[length(fits)+1L]]<-state$fits
    if(i==iteration)for(v in plan$targets) {
      z<-state$mids$imp[[v]][,1L]
      if(v=='bmi')z<-z*plan$transforms$bmi[['sd']]+plan$transforms$bmi[['mean']]
      draws[[length(draws)+1L]]<-data.frame(chain=chain,variable=v,
        row=which(plan$where[,v]),value=as.character(z))
    }
    rm(state)
  }
  traces<-do.call(rbind,traces);fits<-do.call(rbind,fits)
  write_csv_checked(traces,destinations[1]);write_csv_checked(fits,destinations[2])
  if(iteration>=10L) {
    keys<-unique(traces[c('variable','statistic')])
    flags<-lapply(seq_len(nrow(keys)),function(j) {
      z<-traces[traces$variable==keys$variable[j]&traces$statistic==keys$statistic[j]&
        traces$iteration>iteration-10L,]
      chains<-lapply(split(z,z$chain),function(a)a$value[order(a$iteration)])
      stopifnot(length(chains)==plan$manifest$m,all(lengths(chains)==10L))
      variances<-vapply(chains,var,numeric(1));W<-mean(variances)
      B<-10*var(vapply(chains,mean,numeric(1)))
      psrf<-if(W>0)sqrt((.9*W+B/10)/W)else NA_real_
      ac<-vapply(chains,function(a)if(var(a)>0)as.numeric(acf(a,lag.max=1,plot=FALSE)$acf[2])else NA_real_,numeric(1))
      max_ac<-if(all(is.na(ac)))NA_real_ else max(abs(ac),na.rm=TRUE)
      delta<-mean(vapply(chains,function(a)mean(a[6:10])-mean(a[1:5]),numeric(1)))
      drift<-if(W>0)abs(delta)/sqrt(W)else NA_real_
      data.frame(variable=keys$variable[j],statistic=keys$statistic[j],
        psrf_classic=psrf,max_abs_lag1=max_ac,window_delta=delta,window_delta_sd=drift,
        constant_chains=sum(variances==0),review_flag=anyNA(c(psrf,max_ac,drift))||
          psrf>1.05||max_ac>.5||drift>.2)
    })
    write_csv_checked(do.call(rbind,flags),destinations[3])
  }
  write_csv_checked(do.call(rbind,draws),destinations[4])
  message('Diagnostics exported; manual trace/distribution review required before extension or analysis.')
}
