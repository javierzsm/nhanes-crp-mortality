#!/usr/bin/env Rscript
# Publication-draft figures from saved aggregate results; no model refits.
Sys.setenv(TZ='Europe/Paris')
source('src/R/00_functions_imputation_execution.R')
root<-'reports/stage6_v1/figures'
if(dir.exists(root))stop('Figure package exists; use a new version.')
files<-c('reports/stage6_v1/integrated_sensitivities.csv',
 'output/tables/figure_data_01_crp_spline.csv','output/tables/table_08_effect_modifier_contrasts.csv')
hashes<-mi_hashes(files)
s<-read.csv(files[1],check.names=FALSE)
# Use numerical source values, not rounded manuscript strings, for the forest.
a<-read.csv('output/tables/table_06_sensitivity_analyses.csv')
b<-read.csv('output/tables/table_07_alternative_age_sensitivity.csv')[2,]
c<-read.csv('output/tables/mi15_20261014_fourworker_v1_v2_pooled.csv')
forest<-data.frame(label=c(a$analysis,b$model,'Multiple imputation (50 sets)'),
 HR=c(a$hazard_ratio,b$hazard_ratio,c$HR),lower=c(a$confidence_low,b$confidence_low,c$CI_lower),
 upper=c(a$confidence_high,b$confidence_high,c$CI_upper))
curve<-read.csv(files[2]);mod<-read.csv(files[3]);dir.create(root)
render<-function(name,width,height,draw)for(extension in c('png','svg')) {
 path<-file.path(root,paste0(name,'.',extension))
 if(extension=='png')png(path,width=width,height=height,res=150)else svg(path,width=width/150,height=height/150)
 tryCatch(draw(),finally=dev.off())
}
render('primary_sensitivities',2100,1200,function() {
 par(mar=c(5,23,3,2));y<-rev(seq_len(nrow(forest)))
 plot(forest$HR,y,log='x',xlim=range(c(1,forest$lower,forest$upper)),ylim=c(.5,nrow(forest)+.5),
  yaxt='n',ylab='',xlab='Hazard ratio per doubling of CRP (95% CI)',pch=19,
  main='Primary model and sensitivity analyses')
 axis(2,at=y,labels=forest$label,las=1,cex.axis=.85)
 segments(forest$lower,y,forest$upper,y);abline(v=1,lty=2,col='grey50')
})
render('crp_spline',1500,1100,function() {
 par(mar=c(5,5,3,1))
 plot(curve$comparison_crp_mg_l,curve$hazard_ratio,log='x',type='n',
  ylim=range(curve$confidence_low,curve$confidence_high),xlab='Baseline CRP (mg/L; logarithmic axis)',
  ylab='Hazard ratio versus CRP = 1 mg/L',main='Adjusted CRP association: spline working model')
 polygon(c(curve$comparison_crp_mg_l,rev(curve$comparison_crp_mg_l)),
  c(curve$confidence_low,rev(curve$confidence_high)),col=adjustcolor('steelblue',.2),border=NA)
 lines(curve$comparison_crp_mg_l,curve$hazard_ratio,lwd=2,col='steelblue4')
 abline(h=1,lty=2,col='grey50');points(1,1,pch=19)
})
render('secondary_effect_modifiers',1700,900,function() {
 par(mar=c(5,12,3,2));y<-rev(seq_len(nrow(mod)))
 labels<-paste(ifelse(mod$modifier=='sex','Sex','Age'),mod$group,sep=': ')
 plot(mod$hazard_ratio,y,log='x',xlim=range(c(1,mod$confidence_low,mod$confidence_high)),
  ylim=c(.5,4.5),yaxt='n',ylab='',xlab='Hazard ratio per doubling of CRP (95% CI)',
  main='Secondary interaction-model contrasts',pch=19)
 axis(2,at=y,labels=labels,las=1)
 segments(mod$confidence_low,y,mod$confidence_high,y);abline(v=1,lty=2,col='grey50')
})
stopifnot(identical(mi_hashes(names(hashes)),hashes))
write.csv(data.frame(path=names(hashes),md5=unname(hashes)),file.path(root,'input_manifest.csv'),row.names=FALSE)
writeLines(unname(mi_hashes('src/R/19_build_reporting_figures.R')),file.path(root,'generator_md5.txt'))
writeLines(c('# Draft figures','',
 'PNG and SVG exports; numerical inputs are saved estimates, not refitted models.',
 'The forest includes an unweighted diagnostic and a finite-df MI interval; these have distinct roles/conventions.',
 'The spline is a constant-coefficient working-model summary, not a cure for time variation.',
 'Subgroup intervals come from separate interaction models; formal age/sex tests are in table_08, not inferred from overlap.',
 'All figures are drafts pending journal style and author review.'),file.path(root,'README.md'))
message('Six draft figures created without altering original outputs.')
