# mice.impute.polyreg
function (y, ry, x, wy = NULL, nnet.maxit = 100, nnet.trace = FALSE, 
    nnet.MaxNWts = 1500, ...) 
{
    if (is.null(wy)) {
        wy <- !ry
    }
    x <- as.matrix(x)
    aug <- augment(y, ry, x, wy)
    x <- aug$x
    y <- aug$y
    ry <- aug$ry
    wy <- aug$wy
    w <- aug$w
    fy <- as.factor(y)
    nc <- length(levels(fy))
    un <- rep(runif(sum(wy)), each = nc)
    xy <- cbind.data.frame(y = y, x = x)
    if (ncol(x) == 0L) {
        xy <- data.frame(xy, int = 1)
    }
    cat.has.all.obs <- table(y[ry]) == sum(ry)
    if (any(cat.has.all.obs)) {
        return(rep(levels(fy)[cat.has.all.obs], sum(wy)))
    }
    fit <- nnet::multinom(formula(xy), data = xy[ry, , drop = FALSE], 
        weights = w[ry], maxit = nnet.maxit, trace = nnet.trace, 
        MaxNWts = nnet.MaxNWts, ...)
    post <- predict(fit, xy[wy, , drop = FALSE], type = "probs")
    if (sum(wy) == 1) {
        post <- matrix(post, nrow = 1, ncol = length(post))
    }
    if (is.vector(post)) {
        post <- matrix(c(1 - post, post), ncol = 2)
    }
    draws <- un > apply(post, 1, cumsum)
    idx <- 1 + apply(draws, 2, sum)
    levels(fy)[idx]
}

# mice.impute.logreg
function (y, ry, x, wy = NULL, ...) 
{
    if (is.null(wy)) 
        wy <- !ry
    aug <- augment(y, ry, x, wy)
    x <- aug$x
    y <- aug$y
    ry <- aug$ry
    wy <- aug$wy
    w <- aug$w
    x <- cbind(1, as.matrix(x))
    expr <- expression(glm.fit(x = x[ry, , drop = FALSE], y = y[ry], 
        family = quasibinomial(link = logit), weights = w[ry]))
    fit <- eval(expr)
    fit.sum <- summary.glm(fit)
    beta <- coef(fit)
    rv <- t(chol(sym(fit.sum$cov.unscaled)))
    beta.star <- beta + rv %*% rnorm(ncol(rv))
    p <- 1/(1 + exp(-(x[wy, , drop = FALSE] %*% beta.star)))
    vec <- (runif(nrow(p)) <= p)
    vec[vec] <- 1
    if (is.factor(y)) {
        vec <- factor(vec, c(0, 1), levels(y))
    }
    vec
}

# mice.impute.pmm
function (y, ry, x, wy = NULL, donors = 5L, matchtype = 1L, exclude = NULL, 
    quantify = TRUE, trim = 1L, ridge = 1e-05, use.matcher = FALSE, 
    ...) 
{
    if (is.null(wy)) {
        wy <- !ry
    }
    if (is.factor(y)) {
        active <- !ry | y %in% (levels(y)[table(y) >= trim])
        y <- y[active]
        ry <- ry[active]
        x <- x[active, , drop = FALSE]
        wy <- wy[active]
    }
    if (!is.null(exclude)) {
        active <- !ry | !y %in% exclude
        y <- y[active]
        ry <- ry[active]
        x <- x[active, , drop = FALSE]
        wy <- wy[active]
    }
    x <- cbind(1, as.matrix(x))
    ynum <- y
    if (is.factor(y)) {
        if (quantify) {
            ynum <- quantify(y, ry, x)
        }
        else {
            ynum <- as.integer(y)
        }
    }
    parm <- .norm.draw(ynum, ry, x, ridge = ridge, ...)
    if (matchtype == 0L) {
        yhatobs <- x[ry, , drop = FALSE] %*% parm$coef
        yhatmis <- x[wy, , drop = FALSE] %*% parm$coef
    }
    if (matchtype == 1L) {
        yhatobs <- x[ry, , drop = FALSE] %*% parm$coef
        yhatmis <- x[wy, , drop = FALSE] %*% parm$beta
    }
    if (matchtype == 2L) {
        yhatobs <- x[ry, , drop = FALSE] %*% parm$beta
        yhatmis <- x[wy, , drop = FALSE] %*% parm$beta
    }
    if (use.matcher) {
        idx <- matcher(yhatobs, yhatmis, k = donors)
    }
    else {
        idx <- matchindex(yhatobs, yhatmis, donors)
    }
    return(y[ry][idx])
}

