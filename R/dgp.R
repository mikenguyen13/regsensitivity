## dgp.R --- compute the summary statistics that every sensitivity analysis
## consumes.
##
## All identified-set and breakdown-point calculations in this package depend
## only on Var(Y, X, W1) after partialling out W0. We compute that variance
## matrix once and cache the derived quantities used downstream.

# Internal: build a model frame from a formula spec and split controls into
# `w1` (the comparison controls) and `w0` (the "other" controls which we
# partial out before computing the variance matrix).
#
# The argument names mirror the Stata `compare()`/`nocompare()` options:
#  - compare:   names of variables to USE as the comparison set
#  - nocompare: names of variables to EXCLUDE from the comparison set
#               (i.e. everything else becomes the comparison set)
#
# Factor variables are expanded via model.matrix and any aliased columns
# (perfectly collinear after partialling out the intercept) are dropped.
build_dgp_inputs <- function(formula, data, compare = NULL, nocompare = NULL,
                              subset = NULL) {
    if (!inherits(formula, "formula")) {
        stop("`formula` must be a formula object (e.g. y ~ x + w).",
             call. = FALSE)
    }
    if (!is.data.frame(data)) {
        stop("`data` must be a data.frame.", call. = FALSE)
    }
    if (!is.null(subset)) {
        data <- data[subset, , drop = FALSE]
    }
    if (nrow(data) < 10) {
        stop("Need at least 10 complete observations; got ", nrow(data), ".",
             call. = FALSE)
    }
    mf <- stats::model.frame(formula, data = data, na.action = stats::na.omit)
    if (nrow(mf) < 10) {
        stop("Fewer than 10 complete observations remain after na.omit; got ",
             nrow(mf), ". Consider imputing or removing rows with NAs.",
             call. = FALSE)
    }
    y <- stats::model.response(mf)
    tt <- stats::terms(mf)
    # x is the first non-response term; remaining terms are controls.
    rhs <- attr(tt, "term.labels")
    if (length(rhs) < 1) {
        stop("formula must include at least an independent variable",
             call. = FALSE)
    }
    xname <- rhs[1]
    control_names <- rhs[-1]

    # Determine compare / nocompare partition.
    if (!is.null(compare) && !is.null(nocompare)) {
        stop("specify at most one of `compare` and `nocompare`", call. = FALSE)
    }
    if (is.null(compare) && is.null(nocompare)) {
        w1_names <- control_names
        w0_names <- character(0)
    } else if (!is.null(compare)) {
        w1_names <- intersect(control_names, compare)
        w0_names <- setdiff(control_names, w1_names)
    } else {
        w0_names <- intersect(control_names, nocompare)
        w1_names <- setdiff(control_names, w0_names)
    }

    expand <- function(nms, data, drop_first = TRUE) {
        if (length(nms) == 0) {
            return(matrix(numeric(0), nrow = nrow(data), ncol = 0))
        }
        f <- stats::as.formula(paste("~", paste(nms, collapse = " + ")))
        mm <- stats::model.matrix(f, data = data)
        if (drop_first && "(Intercept)" %in% colnames(mm)) {
            mm <- mm[, setdiff(colnames(mm), "(Intercept)"), drop = FALSE]
        }
        mm
    }

    # Use the same row-wise complete-cases as mf, robust to any kind of
    # row labels (integer vs character vs subset-preserved).
    keep_rows <- match(rownames(mf), rownames(data))
    use_data <- data[keep_rows, , drop = FALSE]
    x <- expand(xname, use_data)
    if (ncol(x) != 1) {
        stop("independent variable must be numeric/scalar", call. = FALSE)
    }
    x <- x[, 1]
    w1 <- expand(w1_names, use_data)
    w0 <- expand(w0_names, use_data)

    list(
        y = y, x = x, w1 = w1, w0 = w0,
        y_name = all.vars(formula)[1],
        x_name = xname,
        compare_names = colnames(w1),
        control_names = c(colnames(w1), colnames(w0)),
        n = length(y)
    )
}

# Residualize a numeric matrix on `w0` (after adding an intercept).
#
# When `w0` is empty we still demean each column (the Stata workflow always
# includes a constant in W0).
project_residuals <- function(mat, w0) {
    if (is.null(dim(mat))) {
        mat <- matrix(mat, ncol = 1)
    }
    if (ncol(w0) == 0) {
        # Just demean (equivalent to projecting onto a constant).
        mu <- colMeans(mat)
        return(sweep(mat, 2, mu, FUN = "-"))
    }
    # Add intercept, solve in one go for all columns.
    W <- cbind(1, w0)
    qrW <- qr(W)
    fit <- qr.fitted(qrW, mat)
    mat - fit
}

# Drop any columns of `w` that have zero variance after projection (these are
# columns that became collinear with W0 once we partialled it out).
drop_zero_variance <- function(w) {
    if (ncol(w) == 0) return(w)
    v <- apply(w, 2, stats::var)
    keep <- v > 1e-12
    w[, keep, drop = FALSE]
}

# Compute Var(Y, X, W1) and all the derived quantities used by the analyses.
#
# Mirrors `get_dgp` in the Stata source. The returned object is an S3 list
# of class `regsen_dgp` and holds the same fields as the Mata struct dgp.
#
# Fields:
#   var_y, var_x        : variances of (residualized) Y, X
#   var_w               : variance matrix of (residualized) W1
#   wt                  : Cholesky inverse of var_w
#   k0, k1, k2          : DMP scalars (k0 = Var(MX|W1), etc.)
#   wxwx, wywy, wxwy    : inner products  cov_wx' wt cov_wx, etc.
#   covwx_norm_sq       : Var(X) - k0
#   beta_short          : OLS coefficient of Y on X alone
#   beta_med            : OLS coefficient of Y on X + W1
#   gamma_med, pi_med   : Y- and X- partial coefficients on W1 (unweighted)
#   gamma_med_norm_sq   : ||gamma_med||^2 under wt
#   r_short, r_med      : R^2 of the short and medium regressions
#   var_x_resid         : equals k0; kept under the Oster name
#   c_change_basis      : 2x2 matrix used inside the DIRECT optimization
#
# `inputs` is the list returned by `build_dgp_inputs()`.
get_dgp <- function(inputs) {
    y <- inputs$y; x <- inputs$x; w1 <- inputs$w1; w0 <- inputs$w0

    # Partial out W0 (and a constant) from (Y, X, W1).
    yxw <- cbind(y, x, w1)
    yxw_r <- project_residuals(yxw, w0)
    yr <- yxw_r[, 1]
    xr <- yxw_r[, 2]
    if (ncol(w1) > 0) {
        w1r <- yxw_r[, -(1:2), drop = FALSE]
    } else {
        w1r <- matrix(numeric(0), nrow = length(yr), ncol = 0)
    }
    w1r <- drop_zero_variance(w1r)

    # Variance matrix V = Var((Y, X, W1)) after residualizing.
    data_block <- cbind(yr, xr, w1r)
    V <- stats::var(data_block)

    var_y <- V[1, 1]
    var_x <- V[2, 2]
    if (ncol(w1r) == 0) {
        # No comparison controls. Many quantities simplify; we still allow
        # the analysis to run but a number of the sensitivity parameters
        # become meaningless. We populate the struct with sensible defaults.
        var_w <- matrix(0, 0, 0)
        wt <- matrix(0, 0, 0)
        covwx <- numeric(0)
        covwy <- numeric(0)
        wxwx <- 0; wywy <- 0; wxwy <- 0
    } else {
        var_w <- V[-(1:2), -(1:2), drop = FALSE]
        # cholinv = inverse of a PD matrix via Cholesky; chol2inv() does this.
        ch <- tryCatch(chol(var_w), error = function(e) NULL)
        if (is.null(ch)) {
            # fall back to ginv for near-singular cases
            wt <- solve(var_w + diag(1e-12, nrow(var_w)))
        } else {
            wt <- chol2inv(ch)
        }
        covwx <- V[-(1:2), 2]
        covwy <- V[-(1:2), 1]
        wxwx <- as.numeric(t(covwx) %*% wt %*% covwx)
        wywy <- as.numeric(t(covwy) %*% wt %*% covwy)
        wxwy <- as.numeric(t(covwx) %*% wt %*% covwy)
    }
    covxy <- V[1, 2]

    k0 <- var_x - wxwx
    k1 <- covxy - wxwy
    k2 <- var_y - wywy
    covwx_norm_sq <- var_x - k0

    beta_short <- covxy / var_x
    beta_med <- k1 / k0
    var_x_resid <- k0

    if (ncol(w1r) == 0) {
        gamma_med <- numeric(0)
        pi_med <- numeric(0)
        gamma_med_norm_sq <- 0
    } else {
        gamma_med <- covwy - beta_med * covwx
        pi_med <- covwx
        gamma_med_norm_sq <- as.numeric(t(gamma_med) %*% wt %*% gamma_med)
    }

    r_short <- beta_short^2 * var_x / var_y
    r_med <- (beta_med^2 * var_x +
              gamma_med_norm_sq +
              2 * beta_med * as.numeric(t(gamma_med) %*% (if (length(gamma_med)) wt %*% covwx else numeric(0)))) / var_y
    # The second-term cross product simplifies to 0 when there are no W1.

    # Change-of-basis matrix used in the DIRECT optimization (DMP, ry<inf, c>0).
    wy_orthogonal_norm <- sqrt(max(wywy * wxwx - wxwy^2, 0))
    wxnorm <- sqrt(max(wxwx, 0))
    c_change_basis <- matrix(c(
        if (wxnorm > 0) 1 / wxnorm else 0,
        0,
        if (wy_orthogonal_norm > 0 && wxnorm > 0) -wxwy / wy_orthogonal_norm / wxnorm else 0,
        if (wy_orthogonal_norm > 0) wxnorm / wy_orthogonal_norm else 0
    ), nrow = 2, byrow = FALSE)

    structure(
        list(
            var_y = var_y, var_x = var_x, var_w = var_w, wt = wt,
            k0 = k0, k1 = k1, k2 = k2,
            wxwx = wxwx, wywy = wywy, wxwy = wxwy,
            covwx_norm_sq = covwx_norm_sq,
            beta_short = beta_short, beta_med = beta_med,
            gamma_med = gamma_med, pi_med = pi_med,
            gamma_med_norm_sq = gamma_med_norm_sq,
            r_short = r_short, r_med = r_med,
            var_x_resid = var_x_resid,
            c_change_basis = c_change_basis,
            n_compare = ncol(w1r),
            n = length(yr)
        ),
        class = "regsen_dgp"
    )
}

# A small helper used by display code.
sumstats_table <- function(dgp) {
    data.frame(
        statistic = c("Beta (short)", "Beta (medium)",
                      "R2 (short)", "R2 (medium)",
                      "Var(Y)", "Var(X)", "Var(X_Residual)"),
        value = c(dgp$beta_short, dgp$beta_med,
                  dgp$r_short, dgp$r_med,
                  dgp$var_y, dgp$var_x, dgp$var_x_resid),
        stringsAsFactors = FALSE
    )
}
