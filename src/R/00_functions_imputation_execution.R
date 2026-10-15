# Shared preparation, audited fitting and immutable checkpoints for Script 14.
mi_targets <- c('bmi','education','smoking','diabetes','hypertension','prevalent_cvd')
mi_strict <- function(expr) withCallingHandlers(expr,warning=function(w)
  stop('Unreviewed imputation warning: ',conditionMessage(w),call.=FALSE))
mi_versions <- function() c(R=as.character(getRversion()),
  vapply(c('mice','nnet','survey','survival'),function(p)as.character(packageVersion(p)),character(1)))
mi_hashes <- function(files) {
  if(any(!file.exists(files))) stop('Manifest source/input missing.')
  tools::md5sum(files)
}
mi_atomic_save <- function(object,path) {
  if(file.exists(path))stop('Refusing existing checkpoint: ',path)
  temporary<-tempfile(pattern='.mi-',tmpdir=dirname(path));on.exit(unlink(temporary))
  saveRDS(object,temporary)
  restored<-readRDS(temporary)
  if(!is.null(object$mids)) {
    fields<-setdiff(names(object$mids),c('call','formulas'))
    stopifnot(identical(object$mids[fields],restored$mids[fields]),
      identical(lapply(object$mids$formulas,deparse),lapply(restored$mids$formulas,deparse)),
      identical(object[setdiff(names(object),'mids')],restored[setdiff(names(restored),'mids')]))
  } else stopifnot(identical(object,restored))
  stopifnot(file.rename(temporary,path))
}
mi_nelson_aalen <- function(time,death) {
  stopifnot(length(time)==length(death),all(is.finite(time)),all(time>0),all(death %in% 0:1))
  times<-sort(unique(time));counts<-tabulate(match(time,times),length(times))
  events<-tabulate(match(time[death==1L],times),length(times))
  risk<-rev(cumsum(rev(counts)));hazard<-cumsum(events/risk)
  stopifnot(sum(events)==sum(death),all(risk>0),all(is.finite(hazard)),all(diff(hazard)>=0))
  hazard[match(time,times)]
}
mi_prepare_table <- function(x,knots) {
  stopifnot(!anyDuplicated(x$SEQN),!anyNA(x[c('age','sex','race_hispanic_origin',
    'cycle','SDMVSTRA','SDMVPSU','log2_crp','death','follow_up_months','pooled_mec_weight')]),
    all(x$pooled_mec_weight>0))
  x<-add_age_spline_basis(x,knots)
  x$nelson_aalen<-mi_nelson_aalen(x$follow_up_months,x$death)
  x$log_weight<-log(x$pooled_mec_weight)
  columns<-mapping<-list()
  for(cycle in levels(x$cycle)) {
    strata<-sort(unique(x$SDMVSTRA[x$cycle==cycle]))
    for(h in strata[-1L]) {
      name<-paste0('stratum_',h)
      columns[[name]]<-as.integer(x$SDMVSTRA==h)
      mapping[[name]]<-data.frame(column=name,kind='stratum',cycle=cycle,stratum=h,psu=NA_integer_)
    }
  }
  for(h in sort(unique(x$SDMVSTRA))) {
    stopifnot(length(unique(x$cycle[x$SDMVSTRA==h]))==1L)
    psus<-sort(unique(x$SDMVPSU[x$SDMVSTRA==h]))
    for(p in psus[-1L]) {
      name<-paste0('psu_',h,'_',p)
      columns[[name]]<-as.integer(x$SDMVSTRA==h & x$SDMVPSU==p)
      mapping[[name]]<-data.frame(column=name,kind='psu',cycle=as.character(x$cycle[which(x$SDMVSTRA==h)[1]]),stratum=h,psu=p)
    }
  }
  fixed<-c('age_rcs1','age_rcs2','age_rcs3','sex','race_hispanic_origin','cycle',
    'log2_crp','death','nelson_aalen','log_weight')
  data<-cbind(x[c(mi_targets,fixed)],as.data.frame(columns))
  scaled<-c('bmi','age_rcs1','age_rcs2','age_rcs3','log2_crp','nelson_aalen','log_weight')
  transforms<-lapply(scaled,function(v) {
    mu<-mean(data[[v]],na.rm=TRUE);sd<-stats::sd(data[[v]],na.rm=TRUE)
    stopifnot(is.finite(mu),is.finite(sd),sd>0)
    data[[v]]<<-(data[[v]]-mu)/sd;c(mean=mu,sd=sd)
  });names(transforms)<-scaled
  pred<-matrix(0,ncol(data),ncol(data),dimnames=list(names(data),names(data)))
  pred[mi_targets,]<-1;diag(pred)<-0
  methods<-setNames(rep('',ncol(data)),names(data))
  methods[mi_targets]<-c('pmm_checked','polyreg_checked','polyreg_checked','polyreg_checked','logreg_checked','logreg_checked')
  where<-is.na(data);rownames(where)<-rownames(data);stopifnot(!any(where[,setdiff(names(data),mi_targets)]))
  # Deterministic filled copy solely for preflight rank checks, never analysis or MICE initialization.
  filled<-data
  for(v in mi_targets) {
    missing<-is.na(filled[[v]])
    if(is.factor(filled[[v]]))filled[[v]][missing]<-names(which.max(table(filled[[v]])))
    else filled[[v]][missing]<-median(filled[[v]],na.rm=TRUE)
  }
  rank<-lapply(mi_targets,function(v) {
    X<-model.matrix(~.,filled[setdiff(names(filled),v)])
    X<-X[!where[,v],,drop=FALSE];r<-qr(X)$rank
    if(r!=ncol(X))stop('Preflight predictor rank failure: ',v)
    data.frame(variable=v,columns=ncol(X),rank=r,condition=kappa(X,exact=FALSE))
  })
  list(data=data,where=where,pred=pred,methods=methods,transforms=transforms,
    mapping=do.call(rbind,mapping),rank=do.call(rbind,rank),targets=mi_targets)
}
mi_install_methods <- function() {
  if(as.character(packageVersion('mice'))!='3.19.0')stop('Review instrumentation for this MICE version.')
  audit<-new.env(parent=emptyenv());audit$fits<-list()
  check<-function(fit,post) {
    if(fit$convergence!=0L || any(!is.finite(coef(fit))) || any(!is.finite(post)) ||
      any(post<0 | post>1) || any(abs(rowSums(post)-1)>1e-8))stop('Multinomial fit/probability failure.')
    audit$fits[[length(audit$fits)+1L]]<-data.frame(convergence=fit$convergence,
      coefficients=length(coef(fit)),min_probability=min(post),max_probability=max(post))
  }
  fun<-mice::mice.impute.polyreg;b<-as.list(body(fun))
  pos<-which(vapply(b,function(e)is.call(e)&&identical(e[[1L]],as.name('<-'))&&
    identical(e[[2L]],as.name('draws')),logical(1)))
  stopifnot(length(pos)==1L)
  env<-new.env(parent=environment(fun));env$mi_check_fit<-check
  b<-append(b,list(quote(mi_check_fit(fit,post))),after=pos-1L)
  body(fun)<-as.call(b);environment(fun)<-env
  for(method in c('pmm','polyreg','logreg')) {
    original<-if(method=='polyreg')fun else get(paste0('mice.impute.',method),asNamespace('mice'))
    wrapper<-local({f<-original;function(...) {
      gc(verbose=FALSE);ans<-f(...);gc(verbose=FALSE);ans
    }})
    assign(paste0('mice.impute.',method,'_checked'),wrapper,envir=.GlobalEnv)
  }
  audit
}
mi_check_state <- function(obj,plan) {
  stopifnot(inherits(obj,'mids'),obj$m==1L,identical(obj$data,plan$data),
    identical(obj$where,plan$where),identical(obj$method,plan$methods),
    identical(obj$predictorMatrix,plan$pred),identical(obj$visitSequence,plan$targets),
    is.null(obj$loggedEvents)||nrow(obj$loggedEvents)==0L)
  for(v in plan$targets) {
    z<-obj$imp[[v]][,1];stopifnot(length(z)==sum(plan$where[,v]),!anyNA(z))
    if(is.factor(plan$data[[v]]))stopifnot(all(as.character(z)%in%levels(plan$data[[v]])))
    else {
      stopifnot(all(is.finite(z)),all(z>=min(plan$data[[v]],na.rm=TRUE)),
        all(z<=max(plan$data[[v]],na.rm=TRUE)),
        all(z*plan$transforms$bmi[['sd']]+plan$transforms$bmi[['mean']]>0))
    }
  }
  invisible(TRUE)
}
mi_trace <- function(obj,plan,chain) {
  do.call(rbind,lapply(plan$targets,function(v) {
    z<-obj$imp[[v]][,1]
    if(v=='bmi') {
      z<-z*plan$transforms$bmi[['sd']]+plan$transforms$bmi[['mean']]
      values<-c(mean=mean(z),variance=var(z),setNames(as.numeric(quantile(z,c(.05,.5,.95))),c('p05','p50','p95')))
    } else {
      values<-as.numeric(table(factor(z,levels=levels(plan$data[[v]]))))/length(z)
      names(values)<-levels(plan$data[[v]])
    }
    data.frame(iteration=obj$iteration,chain=chain,variable=v,statistic=names(values),value=values)
  }))
}
