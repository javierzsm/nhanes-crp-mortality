#!/usr/bin/env Rscript
# Illustrated manuscript from saved estimates; no statistical model is fitted.
Sys.setenv(TZ='Europe/Paris')
source('src/R/00_functions_imputation_execution.R')
root <- 'reports/stage6_v3'
if(dir.exists(root)) stop('Version exists; use a new output version.')
files <- c('reports/stage6_v2/manuscript_methods_results.md',
 'output/tables/qc_04_cohort_flow.csv','data/processed/primary_complete_case_cohort.rds',
 'output/tables/figure_data_01_crp_spline.csv',
 'output/tables/table_05_crp_hr_by_followup_period.csv',
 'output/tables/table_05_crp_time_interaction_test.csv',
 'output/tables/qc_09_followup_period_events.csv',
 'output/tables/table_06_sensitivity_analyses.csv',
 'output/tables/table_07_alternative_age_sensitivity.csv',
 'output/tables/mi15_20261014_fourworker_v1_v2_pooled.csv',
 'reports/same_month_death_sensitivity_v1/comparison.csv',
 'output/tables/table_08_effect_modifier_contrasts.csv',
 'output/tables/table_08_effect_modifier_tests.csv',
 'output/tables/table_03_crp_spline_tests.csv',
 'src/R/23_build_illustrated_manuscript.R')
hashes <- mi_hashes(files)
flow <- read.csv(files[2]); d <- readRDS(files[3]); curve <- read.csv(files[4])
period <- read.csv(files[5]); interaction <- read.csv(files[6]); events <- read.csv(files[7])
sens <- read.csv(files[8]); age <- read.csv(files[9])[2,]; mi <- read.csv(files[10])
zero <- read.csv(files[11])[2,]; modifier <- read.csv(files[12])
modifier_tests <- read.csv(files[13]); spline_tests <- read.csv(files[14])
stopifnot(nrow(d)==26818L,sum(d$death)==5886L,
 identical(flow$n[match(c('adult_crp_positive_mec_weight','mortality_linkage_eligible',
 'confirmed_pregnant','primary_eligible','primary_complete'),flow$step)],
 c(28924L,28890L,1135L,27755L,26818L)),
 identical(period$followup_period,events$followup_period),sum(events$death)==5886L,
 nrow(period)==4L,nrow(curve)>100,all(curve$reference_crp_mg_l==1),
 all(is.finite(unlist(curve))), all(curve$confidence_low<=curve$hazard_ratio),
 all(curve$confidence_high>=curve$hazard_ratio))
# Weighted distribution uses the entire original complete-case denominator.
# Only aggregate bins are exported, not participant records.
br <- seq(log2(min(curve$comparison_crp_mg_l)),log2(max(curve$comparison_crp_mg_l)),length.out=31)
in_range <- d$crp_mg_l>=2^br[1] & d$crp_mg_l<=2^tail(br,1)
idx <- findInterval(log2(d$crp_mg_l),br,rightmost.closed=TRUE)
w <- d$pooled_mec_weight
bins <- data.frame(lower_crp_mg_l=2^head(br,-1),upper_crp_mg_l=2^tail(br,-1),
 weighted_percent=vapply(1:30,function(i)100*sum(w[in_range & idx==i])/sum(w),numeric(1)))
stopifnot(abs(sum(bins$weighted_percent)-100*sum(w[in_range])/sum(w))<1e-9)
forest <- rbind(data.frame(label=sens$analysis,HR=sens$hazard_ratio,
 lower=sens$confidence_low,upper=sens$confidence_high),
 data.frame(label='Linear age (Amendment 003)',HR=age$hazard_ratio,lower=age$confidence_low,upper=age$confidence_high),
 data.frame(label='Multiple imputation (50 datasets)',HR=mi$HR,lower=mi$CI_lower,upper=mi$CI_upper))
forest <- rbind(forest[1,],data.frame(label='Exclude same-month deaths (Amendment 001)',
 HR=zero$hazard_ratio,lower=zero$confidence_low,upper=zero$confidence_high),forest[-1,])
dir.create(file.path(root,'figures'),recursive=TRUE)
dir.create(file.path(root,'figure_data'))
write.csv(flow,file.path(root,'figure_data/figure_1_cohort_flow.csv'),row.names=FALSE)
write.csv(curve,file.path(root,'figure_data/figure_2_spline.csv'),row.names=FALSE)
write.csv(bins,file.path(root,'figure_data/figure_2_weighted_distribution.csv'),row.names=FALSE)
write.csv(cbind(period,deaths=events$death),file.path(root,'figure_data/figure_3_period_estimates.csv'),row.names=FALSE)
write.csv(interaction,file.path(root,'figure_data/figure_3_global_test.csv'),row.names=FALSE)
write.csv(forest,file.path(root,'figure_data/supplement_1_sensitivities.csv'),row.names=FALSE)
write.csv(modifier,file.path(root,'figure_data/supplement_2_effect_modifiers.csv'),row.names=FALSE)
write.csv(modifier_tests,file.path(root,'figure_data/supplement_2_tests.csv'),row.names=FALSE)
blue <- '#175D88'; grey <- '#59636D'; pale <- '#E9F2F8'
render <- function(name,width,height,draw) {
 for(ext in c('svg','png')) {
  p <- file.path(root,'figures',paste0(name,'.',ext))
  if(ext=='svg') svg(p,width=width,height=height,family='sans',pointsize=12)
  else png(p,width=width,height=height,units='in',res=240,type='cairo',pointsize=12)
  tryCatch(draw(),finally=dev.off())
 }
}
render('figure_1_cohort_flow',11,8,function() {
 grid::grid.newpage()
 box <- function(x,y,width,height,text,fill=pale) {
  grid::grid.roundrect(x,y,width,height,r=grid::unit(.08,'in'),gp=grid::gpar(fill=fill,col=blue,lwd=1.2))
  grid::grid.text(text,x,y,gp=grid::gpar(fontsize=12,lineheight=1.2,col='#172B3A'))
 }
 arrow <- function(x0,y0,x1,y1) grid::grid.lines(c(x0,x1),c(y0,y1),
  arrow=grid::arrow(length=grid::unit(.10,'in')),gp=grid::gpar(col=grey,lwd=1.3))
 box(.36,.90,.56,.13,'Adults with positive CRP and MEC weight\nNHANES 1999-2010\nn = 28,924')
 box(.36,.69,.56,.12,'Eligible for public mortality linkage\nn = 28,890')
 box(.36,.48,.56,.13,'Eligible study cohort\nn = 27,755; deaths = 6,354')
 arrow(.36,.835,.36,.75);arrow(.36,.63,.36,.545)
 box(.82,.79,.29,.105,'Not linkage-eligible\nn = 34',fill='#F4F5F6')
 box(.82,.585,.29,.105,'Confirmed pregnancy\nn = 1,135',fill='#F4F5F6')
 arrow(.36,.79,.675,.79);arrow(.36,.585,.675,.585)
 arrow(.36,.415,.25,.29);arrow(.36,.415,.75,.29)
 grid::grid.text('Exclude 937 with missing\nprimary covariates',.19,.355,gp=grid::gpar(fontsize=10,col=grey))
 grid::grid.text('Retain all eligible\nparticipants',.69,.355,gp=grid::gpar(fontsize=10,col=grey))
 box(.25,.205,.43,.17,'Primary complete-case analysis\nn = 26,818; deaths = 5,886\n96.62% of eligible participants')
 box(.75,.205,.43,.17,'Secondary multiple imputation\n50 completed datasets\nn = 27,755; deaths = 6,354')
 grid::grid.text('The imputed cohort includes both complete and incomplete cases; the branches overlap.',
 .5,.055,gp=grid::gpar(fontsize=10,col=grey))
})
render('figure_2_crp_spline_distribution',10,8,function() {
 layout(matrix(1:2,ncol=1),heights=c(3.6,1.4))
 par(mar=c(.8,5,2.8,1.3),mgp=c(3,.8,0),las=1)
 x <- curve$comparison_crp_mg_l
 plot(x,curve$hazard_ratio,log='x',type='n',xaxt='n',xlab='',
  ylim=range(curve$confidence_low,curve$confidence_high),ylab='Adjusted hazard ratio (reference: 1 mg/L)',bty='l')
 polygon(c(x,rev(x)),c(curve$confidence_low,rev(curve$confidence_high)),
 col=adjustcolor(blue,.17),border=NA)
 abline(h=1,col=grey,lty=2);abline(v=1,col='#AAB8C2',lty=3)
 lines(x,curve$hazard_ratio,col=blue,lwd=2.5);points(1,1,pch=21,bg='white',col=blue,cex=1.1)
 mtext('A  Adjusted concentration-response association',side=3,adj=0,line=.8,font=2)
 legend('topleft',legend=c('Spline estimate','95% confidence interval'),
 col=c(blue,adjustcolor(blue,.25)),lwd=c(2.5,8),bty='n',cex=.9)
 par(mar=c(4.5,5,2,1.3),mgp=c(3,.8,0),las=1)
 plot(1,type='n',log='x',xlim=range(x),ylim=c(0,max(bins$weighted_percent)*1.12),
 xaxt='n',xlab='Baseline CRP (mg/L; logarithmic scale)',ylab='Weighted %',bty='l')
 rect(bins$lower_crp_mg_l,0,bins$upper_crp_mg_l,bins$weighted_percent,
 col=adjustcolor(blue,.45),border='white')
 abline(v=1,col=grey,lty=3)
 ticks <- c(.1,.2,.5,1,2,5,10,20,30);ticks<-ticks[ticks>=min(x)&ticks<=max(x)]
 axis(1,at=ticks,labels=ticks)
 mtext('B  Observed CRP distribution in complete cases',side=3,adj=0,line=.4,font=2)
})
render('figure_3_followup_periods',11,5.5,function() {
 par(mar=c(5,8,3.5,2),mgp=c(3,.8,0),las=1,xpd=NA,cex=1.15)
 y<-4:1
 plot(period$hazard_ratio,y,log='x',xlim=c(.98,1.60),ylim=c(.5,5),
 axes=FALSE,xlab='',ylab='',bty='n',pch=15,col=blue,cex=1.3)
 axis(1,at=c(1,1.1,1.2,1.25),labels=c('1.00','1.10','1.20','1.25'))
 mtext('Adjusted hazard ratio per doubling of CRP',side=1,line=3,at=sqrt(.98*1.27),cex=.95)
 segments(period$confidence_low,y,period$confidence_high,y,col=blue,lwd=2)
 axis(2,at=y,labels=period$followup_period,tick=FALSE)
 segments(1,.65,1,4.4,lty=2,col=grey)
 text(1.31,4.65,'HR (95% CI)',adj=0,font=2,cex=.95)
 text(1.58,4.65,'Deaths',adj=1,font=2,cex=.95)
 text(1.31,y,sprintf('%.3f (%.3f-%.3f)',period$hazard_ratio,period$confidence_low,period$confidence_high),adj=0,cex=.9)
 text(1.58,y,format(events$death,big.mark=',',trim=TRUE),adj=1,cex=.9)
 mtext(sprintf('Global period interaction: F(3, 91) = %.3f; p = %.3f',interaction$f_statistic,interaction$p_value),
 side=3,line=1,adj=0,cex=.95)
})
render('supplement_1_sensitivities',13,8,function() {
 par(mar=c(5,24,2,2),mgp=c(3,.8,0),las=1)
 y<-rev(seq_len(nrow(forest)))
 plot(forest$HR,y,log='x',xlim=range(c(1,forest$lower,forest$upper)),ylim=c(.5,nrow(forest)+.5),
 yaxt='n',ylab='',xlab='Hazard ratio per doubling of CRP (95% CI)',bty='l',pch=19,col=blue)
 axis(2,at=y,labels=forest$label,tick=FALSE,cex.axis=.85)
 segments(forest$lower,y,forest$upper,y,col=blue,lwd=1.5);abline(v=1,lty=2,col=grey)
})
render('supplement_2_effect_modifiers',10,5,function() {
 par(mar=c(5,10,2,2),mgp=c(3,.8,0),las=1)
 y<-4:1
 label<-paste(ifelse(modifier$modifier=='sex','Sex','Age'),modifier$group,sep=': ')
 plot(modifier$hazard_ratio,y,log='x',xlim=range(c(1,modifier$confidence_low,modifier$confidence_high)),
 ylim=c(.5,4.5),yaxt='n',ylab='',xlab='Hazard ratio per doubling of CRP (95% CI)',pch=19,col=blue,bty='l')
 axis(2,at=y,labels=label,tick=FALSE)
 segments(modifier$confidence_low,y,modifier$confidence_high,y,col=blue,lwd=2)
 abline(v=1,lty=2,col=grey)
 mtext('Interaction tests: sex p = 0.284; age group p = 0.021',side=3,line=.4,adj=0,cex=.9)
})
# Integrate into a new version; earlier manuscript sources remain untouched.
text <- paste(readLines(files[1]),collapse='\n')
text <- sub('^# [^\n]+\n\n','',text)
text <- sub('draft v0.2 — 23 October 2026','draft v0.3 — 24 October 2026',text,fixed=TRUE)
flow_caption <- paste('Study cohort and analysis populations. Counts are unweighted observed participants.',
 'Multiple imputation includes both complete and incomplete cases; the two analysis branches overlap.',
 'Missing primary covariates exclude 937 participants from the primary model, not from the imputed analysis.')
curve_caption <- paste('Adjusted CRP association and observed exposure distribution.',
 '(A) Saved survey-weighted CRP spline with pointwise normal 95% confidence intervals, referenced to 1 mg/L;',
 'adjustment matches the primary model except for the flexible CRP terms.',
 'Nonlinearity test: F(2, 65) = 9.169, p < 0.001. The model assumes time-constant spline coefficients.',
 '(B) Pooled-MEC-weighted percentages in equal-width log2(CRP) bins, with all 26,818 complete cases as denominator.',
 sprintf('The displayed range is the saved curve range, 0.1-33.4 mg/L; %.2f%% of the total weight lies outside it.',100-sum(bins$weighted_percent)),
 'Restriction of the drawing range does not remove observations from the fitted model. HRs are not absolute risks.')
period_caption <- paste('Association per doubling of CRP by follow-up period.',
 'Squares and horizontal lines show adjusted HRs and pointwise normal 95% intervals using covariance from 180 JKn design replicates.',
 'Death counts are unweighted events in each period; a participant can contribute risk time to several periods but at most one death.',
 'The global three-contrast test uses F(3, 91). Period boundaries are analytical, not biological thresholds;',
 'the pattern is not monotonically declining.')
fig <- function(caption,file,id) paste0('\n\n![',caption,'](figures/',file,'.svg){#',id,' width=100%}\n\n')
marker <- '### Primary and imputed estimates'
text <- sub(marker,paste0('The cohort flow and overlapping primary/imputed analysis populations are shown in @fig-cohort.',
 fig(flow_caption,'figure_1_cohort_flow','fig-cohort'),marker),text,fixed=TRUE)
marker <- '| Period | HR per doubling (95% CI) |'
pos <- regexpr(marker,text,fixed=TRUE)[1]
stopifnot(pos>0)
text <- paste0(substr(text,1,pos-1),
 'The concentration-response curve and the observed exposure distribution are shown in @fig-crp.',
 fig(curve_caption,'figure_2_crp_spline_distribution','fig-crp'),substr(text,pos,nchar(text)))
# Replace the redundant period table with the integrated period forest.
start <- regexpr(marker,text,fixed=TRUE)[1]
end <- regexpr('The global period-interaction test',text,fixed=TRUE)[1]
text <- paste0(substr(text,1,start-1),'Period-specific estimates and death counts are shown in @fig-periods.',
 fig(period_caption,'figure_3_followup_periods','fig-periods'),substr(text,end,nchar(text)))
text <- sub('### Sensitivities and influence',
 '### Sensitivities and influence\n\nThe sensitivity forest, including Amendment 001, and secondary interaction plots appear in the [supplementary figure document](supplementary_figures.html).',text,fixed=TRUE)
# Format secondary tests for reading without changing their values.
test_start <- regexpr('| modifier | test | numerator_df |',text,fixed=TRUE)[1]
test_end <- regexpr('The age interaction suggests',text,fixed=TRUE)[1]
stopifnot(test_start>0,test_end>test_start)
text <- paste0(substr(text,1,test_start-1),
 '| Modifier | Wald F (numerator, denominator df) | p value |\n',
 '| --- | --- | --- |\n| Sex | 1.167 (1, 66) | 0.284 |\n',
 '| Age group | 5.575 (1, 65) | 0.021 |\n\n',substr(text,test_end,nchar(text)))
text <- gsub('| sex |','| Sex |',text,fixed=TRUE)
text <- gsub('| age_group |','| Age group |',text,fixed=TRUE)
text <- paste0(text,'\n\nVersion v0.3 integrates three main figures and two supplementary figures from saved estimates. ',
 'Only the weighted exposure-distribution bins were newly summarized from the original complete-case cohort; no model was refitted. ',
 'The figure sources, input hashes and checks accompany this version. Prior validation files refer to the versions they originally checked.\n')
yaml <- c('---',
 'title: "Baseline C-reactive protein and all-cause mortality in US adults: a survey-weighted NHANES cohort study"',
 'lang: en','date: 2026-10-24','format:','  html:','    toc: true','    toc-depth: 2',
 '    theme: default','    embed-resources: true','    html-math-method: mathml',
 '    fontsize: 18px','    linestretch: 1.6','    fig-cap-location: bottom',
 'execute:','  enabled: false','---','')
writeLines(c(yaml,text),file.path(root,'manuscript_methods_results.md'))
supp <- c('---','title: "Supplementary figures: NHANES CRP and mortality"',
 'lang: en','date: 2026-10-24','format:','  html:','    theme: default','    embed-resources: true',
 '    html-math-method: mathml','    fontsize: 18px','execute:','  enabled: false','---','',
 '## Supplementary Figure S1','',
 '![](figures/supplement_1_sensitivities.svg){fig-alt="Primary and sensitivity hazard ratios with 95 percent confidence intervals" width=100%}','',
 '**Supplementary Figure S1. Primary and sensitivity analyses.** All estimates use the CRP coefficient per doubling. ',
 'The same-month-death exclusion removes two complete-case deaths. The income analysis changes both sample and adjustment. ',
 'Linear age is a disclosed post-primary specification. The unweighted estimate is diagnostic only. ',
 'Normal intervals are used except for MI, which uses finite Barnard-Rubin t inference. ',
 'Similar estimates do not establish equivalence or absence of shared bias.','',
 '## Supplementary Figure S2','',
 '![](figures/supplement_2_effect_modifiers.svg){fig-alt="CRP hazard ratios by sex and age group from separate interaction models" width=100%}','',
 '**Supplementary Figure S2. Secondary interaction-model contrasts.** Models retain primary adjustment and the continuous-age spline. ',
 'The age-group model additionally includes the 65+ group main effect. Group intervals are normal covariance-based contrasts. ',
 'Design-based interaction tests: sex F(1,66)=1.167, p=0.284; age F(1,65)=5.575, p=0.021. ',
 'Interval overlap is not a formal interaction test; these analyses do not establish causal effect modification.','',
 '[Return to the illustrated manuscript](manuscript_methods_results.html).')
writeLines(supp,file.path(root,'supplementary_figures.md'))
writeLines(c('# Illustrated manuscript v0.3','',
 '[Main manuscript](manuscript_methods_results.md) with cohort flow, spline/distribution, and follow-up-period figures.',
 '[Supplementary figures](supplementary_figures.md) show updated sensitivities and secondary interactions.',
 'Open the locally rendered HTML files for a standalone reading version with embedded figures.',
 'All text and figure labels are English. SVG and 240-dpi PNG files are provided in `figures/`.',
 'Figure source CSVs contain aggregates only. Earlier manuscript versions and numerical results are preserved.',
 'This remains a Methods/Results working draft; the listed publication tasks are not complete.','',
 'Build once from the repository root: `Rscript src/R/23_build_illustrated_manuscript.R`.',
 'The script refuses to overwrite this version. Render the two Markdown manuscripts using Quarto.',
 'Input hashes and figure/manuscript checks accompany this package.'),file.path(root,'README.md'))
checks <- data.frame(check=c('saved_cohort_and_flow_counts','period_deaths_sum_to_primary',
 'weighted_histogram_denominator','curve_from_saved_estimates','Amendment001_in_supplement',
 'three_main_figure_references','all_input_hashes_unchanged','ten_figure_exports'),
 passed=c(TRUE,sum(events$death)==5886L,
 abs(sum(bins$weighted_percent)-100*sum(w[in_range])/sum(w))<1e-9,TRUE,
 any(grepl('same-month',forest$label)),
 all(vapply(c('@fig-cohort','@fig-crp','@fig-periods'),grepl,logical(1),x=text,fixed=TRUE)),
 identical(mi_hashes(names(hashes)),hashes),length(list.files(file.path(root,'figures')))==10L))
stopifnot(all(checks$passed))
write.csv(checks,file.path(root,'validation.csv'),row.names=FALSE)
write.csv(data.frame(path=files,md5=unname(hashes)),file.path(root,'input_manifest.csv'),row.names=FALSE)
mi_atomic_save(list(created=Sys.time(),inputs=hashes,
 hashes=mi_hashes(list.files(root,recursive=TRUE,full.names=TRUE))),
 'data/processed/reporting_stage6_v3_manifest.rds')
cat('Illustrated manuscript and ten figure exports generated; no models refitted.\n')
