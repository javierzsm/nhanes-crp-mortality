#!/usr/bin/env Rscript
# Diagnostic review only: no outcome regression, pooling, refitting or tuning.
Sys.setenv(TZ='Europe/Paris')
source('src/R/00_functions_data.R')
source('src/R/00_functions_imputation_execution.R')
id<-'20261014_fourworker_v1';prefix<-paste0('mi14_',id,'_review020_v2')
root<-file.path('data/processed',paste0('mi14_',id))
outputs<-file.path('output/tables',paste0(prefix,c('_windows.csv','_chain_diagnostics.csv','_bmi.csv','_categories.csv','_qc.csv')))
figures<-file.path('output/figures',paste0(prefix,c('_bmi.png','_categories.png','_bmi_density.png')))
if(any(file.exists(c(outputs,figures))))stop('Review artifacts already exist.')
plan<-readRDS(file.path(root,'plan.rds'))
stopifnot(identical(mi_hashes(names(plan$manifest$hashes)),plan$manifest$hashes),identical(mi_versions(),plan$manifest$versions))
x<-readRDS('data/processed/mortality_linked_eligible_cohort.rds')
traces<-read.csv(file.path('output/tables',paste0('mi14_',id,'_iter020_traces.csv')))
keys<-unique(traces[c('variable','statistic')]);windows<-perchain<-list()
for(j in seq_len(nrow(keys)))for(window in c(10L,20L)) {
 z<-traces[traces$variable==keys$variable[j]&traces$statistic==keys$statistic[j]&traces$iteration>20-window,]
 chains<-lapply(split(z,z$chain),function(a)a$value[order(a$iteration)])
 stopifnot(length(chains)==50L,all(lengths(chains)==window))
 variances<-vapply(chains,var,numeric(1));W<-mean(variances);B<-window*var(vapply(chains,mean,numeric(1)))
 ac<-vapply(chains,function(a)if(var(a)>0)as.numeric(acf(a,lag.max=1,plot=FALSE)$acf[2])else NA_real_,numeric(1))
 delta<-vapply(chains,function(a)mean(tail(a,5))-mean(a[(length(a)-9):(length(a)-5)]),numeric(1))
 slopes<-vapply(chains,function(a)as.numeric(coef(lm(a~seq_along(a)))[2]),numeric(1))
 windows[[length(windows)+1]]<-data.frame(variable=keys$variable[j],statistic=keys$statistic[j],window=window,
  psrf=sqrt(((window-1)/window*W+B/window)/W),constant_chains=sum(variances==0),
  median_signed_ac=median(ac,na.rm=TRUE),p90_abs_ac=quantile(abs(ac),.9,na.rm=TRUE),
  positive_ac_over05=sum(ac>.5,na.rm=TRUE),negative_ac_below_minus05=sum(ac < -0.5,na.rm=TRUE),
  window_delta_sd=abs(mean(delta))/sqrt(W),mean_slope=mean(slopes))
 perchain[[length(perchain)+1]]<-data.frame(variable=keys$variable[j],statistic=keys$statistic[j],window=window,
  chain=as.integer(names(chains)),lag1=ac,delta_last5_previous5=delta,slope=slopes,
  constant=variances==0)
}
rows_bmi<-rows_category<-list();density_draws<-list();checks<-list()
groups<-list(overall=rep('all',nrow(x)),cycle=as.character(x$cycle),death=as.character(x$death))
for(chain in 1:50) {
 state<-readRDS(file.path(root,sprintf('chain_%03d/iteration_020.rds',chain)))
 stopifnot(state$chain==chain,state$mids$iteration==20L,identical(state$plan_hash,unname(mi_hashes(file.path(root,'plan.rds')))))
 mi_check_state(state$mids,plan)
 completed<-mice::complete(state$mids,1L)
 for(v in names(plan$data)) {
  observed<-!plan$where[,v]
  stopifnot(identical(completed[[v]][observed],plan$data[[v]][observed]))
 }
 for(v in mi_targets) {
  missing<-is.na(x[[v]]);imputed<-completed[[v]][missing]
  if(v=='bmi') {
   imputed<-imputed*plan$transforms$bmi[['sd']]+plan$transforms$bmi[['mean']]
   donors<-sort(unique(x$bmi[!missing]));idx<-findInterval(imputed,donors)
   distances<-pmin(abs(imputed-donors[pmax(1,idx)]),abs(imputed-donors[pmin(length(donors),idx+1)]))
   stopifnot(all(is.finite(imputed)),all(imputed>0),all(distances<1e-10))
   density_draws[[chain]]<-imputed
  }
  for(group in names(groups))for(level in unique(groups[[group]])) {
   member<-groups[[group]]==level
   subsets<-list(observed=x[[v]][member&!missing],imputed=imputed[member[missing]])
   for(kind in names(subsets)) {
    values<-subsets[[kind]]
    if(v=='bmi') {
     s<-if(length(values))c(mean=mean(values),sd=sd(values),setNames(as.numeric(quantile(values,c(.01,.05,.25,.5,.75,.95,.99))),c('p01','p05','p25','p50','p75','p95','p99')),minimum=min(values),maximum=max(values))else setNames(rep(NA_real_,11),c('mean','sd','p01','p05','p25','p50','p75','p95','p99','minimum','maximum'))
     rows_bmi[[length(rows_bmi)+1]]<-data.frame(chain=chain,group=group,group_level=level,kind=kind,n=length(values),statistic=names(s),value=as.numeric(s))
    } else {
     counts<-table(factor(values,levels=levels(x[[v]])))
     rows_category[[length(rows_category)+1]]<-data.frame(chain=chain,variable=v,group=group,group_level=level,kind=kind,category=names(counts),count=as.integer(counts),n=length(values),proportion=if(length(values))as.numeric(counts)/length(values)else NA_real_)
    }
   }
  }
 }
 checks[[chain]]<-data.frame(chain=chain,state_verified=TRUE,observed_and_fixed_preserved=TRUE,targets_complete=TRUE,bmi_donors_verified=TRUE)
 rm(completed,state)
}
write_csv_checked(do.call(rbind,windows),outputs[1]);write_csv_checked(do.call(rbind,perchain),outputs[2])
write_csv_checked(do.call(rbind,rows_bmi),outputs[3]);write_csv_checked(do.call(rbind,rows_category),outputs[4]);write_csv_checked(do.call(rbind,checks),outputs[5])
draw<-function(selected,path,layout,width,height) {
 png(path,width=width,height=height,res=150);on.exit(dev.off());par(mfrow=layout,mar=c(3,4,3,1))
 for(j in seq_len(nrow(selected))) {
  z<-traces[traces$variable==selected$variable[j]&traces$statistic==selected$statistic[j],]
  plot(range(z$iteration),range(z$value),type='n',xlab='Iteration',ylab=selected$statistic[j],main=paste(selected$variable[j],selected$statistic[j]))
  for(chain in 1:50){a<-z[z$chain==chain,];lines(a$iteration,a$value,col=adjustcolor('grey35',alpha.f=.3))}
  a<-aggregate(value~iteration,z,mean);lines(a$iteration,a$value,col='blue',lwd=2)
 }
}
draw(keys[keys$variable=='bmi',],figures[1],c(3,2),1600,1500)
draw(keys[keys$variable!='bmi',],figures[2],c(5,3),2400,2400)
png(figures[3],width=1400,height=1000,res=150)
d<-density(x$bmi[!is.na(x$bmi)]);ds<-lapply(density_draws,density)
plot(d,xlim=range(c(d$x,unlist(lapply(ds,function(a)a$x)))),ylim=c(0,max(c(d$y,unlist(lapply(ds,function(a)a$y))))),main='Observed and imputed BMI',xlab='BMI',lwd=2)
for(a in ds)lines(a,col=adjustcolor('steelblue',.3));lines(d,lwd=2)
legend('topright',c('Observed','Imputed: 50 chains'),col=c('black','steelblue'),lwd=2,bty='n');dev.off()
message('Review tables/figures written; no model fits or endpoint decision made by this script.')
