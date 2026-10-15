# Continue the accepted MICE configuration without embedding data in call history.
# The archived manifest/source provides provenance; call expressions are metadata.
continue_mice_compact <- function(obj, count = 1L) {
  stopifnot(inherits(obj, "mids"), length(count) == 1L,
            is.finite(count), count >= 1L, count == as.integer(count))
  if (!is.null(obj$loggedEvents) && nrow(obj$loggedEvents)) {
    stop("Review prior logged events before continuation.")
  }
  ans <- withCallingHandlers(
    mice::mice.mids(obj, maxit = as.integer(count), printFlag = FALSE,
      nnet.maxit = 1000L, nnet.MaxNWts = 5000L, donors = 5L,
      matchtype = 1L, ridge = 1e-5, nnet.trace = FALSE),
    warning = function(w) stop("Unreviewed continuation warning: ", conditionMessage(w)))
  if (!is.null(ans$loggedEvents) && nrow(ans$loggedEvents)) {
    stop("Logged events during continuation.")
  }
  stopifnot(identical(ans$predictorMatrix, obj$predictorMatrix),
            identical(ans$method, obj$method),
            identical(ans$where, obj$where),
            identical(ans$data, obj$data), ans$iteration == obj$iteration + count)
  ans
}
