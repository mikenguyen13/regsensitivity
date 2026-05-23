## calibrate.R --- helpers for calibrating rxbar via the rho_k method of
## Diegert, Masten and Poirier (2026, section 3.4).

#' Calibration parameters rho_k for rxbar
#'
#' For each calibration covariate `W1[k]`, computes
#' \deqn{\rho_k = \frac{\sqrt{\mathrm{Var}(\pi_{1,med,k} W_{1k})}}{
#'                       \sqrt{\mathrm{Var}(\pi_{1,med,-k}' W_{1,-k})}},}
#' where pi(1,med) is the OLS coefficient on W1 from the regression of
#' the treatment X on (W0, W1). Variances are computed on the
#' W0-residualized variables, matching the construction in DMP (2026)
#' equation (3.5).
#'
#' These are point-identified reference values to compare the rxbar
#' breakdown point against. See DMP (2026) section 3.4 and Table 4.
#'
#' @inheritParams regsen_bounds
#' @return A data.frame with columns `variable` and `rho` (a percentage).
#' @export
#' @examples
#' \donttest{
#' data(bfg2020)
#' bfg2020$statea <- factor(bfg2020$statea)
#' w1 <- c("log_area_2010", "lat", "lon", "temp_mean", "rain_mean",
#'         "elev_mean", "d_coa", "d_riv", "d_lak", "ave_gyi")
#' form <- reformulate(c("tye_tfe890_500kNI_100_l6", w1, "statea"),
#'                     response = "avgrep2000to2016")
#' calibrate_rho(form, bfg2020, compare = w1)
#' }
calibrate_rho <- function(formula, data, compare = NULL, nocompare = NULL,
                          subset = NULL) {
    inp <- build_dgp_inputs(formula, data, compare = compare,
                             nocompare = nocompare, subset = subset)
    # Need (X, W1) residualized on W0.
    if (ncol(inp$w1) < 2) {
        stop("rho calibration requires at least two comparison controls",
             call. = FALSE)
    }
    x_res  <- project_residuals(matrix(inp$x, ncol = 1), inp$w0)[, 1]
    w1_res <- project_residuals(inp$w1, inp$w0)

    # pi_med = OLS coefficient of x_res on w1_res
    fit <- stats::lm(x_res ~ w1_res - 1)
    pi_med <- stats::coef(fit)
    # The intercept-free fit may rename columns; align by position.
    names(pi_med) <- colnames(w1_res)

    out <- data.frame(
        variable = colnames(w1_res),
        rho = NA_real_,
        stringsAsFactors = FALSE
    )
    for (k in colnames(w1_res)) {
        others <- setdiff(colnames(w1_res), k)
        contrib_k   <- pi_med[k] * w1_res[, k]
        contrib_oth <- as.vector(w1_res[, others, drop = FALSE] %*% pi_med[others])
        out$rho[out$variable == k] <- sqrt(stats::var(contrib_k)) /
                                       sqrt(stats::var(contrib_oth)) * 100
    }
    out[order(-out$rho), , drop = FALSE]
}

#' Pairwise partial R-squared of calibration covariates
#'
#' For each `W1[k]`, computes
#' \deqn{R^2_{W_{1k} \sim W_{1,-k} \cdot W_0}}
#' i.e. the R-squared of regressing the `W0`-residualized `W1[k]` on the
#' `W0`-residualized `W1[-k]`. Matches Table 3 in DMP (2026): a quick read
#' on how collinear the comparison controls are.
#'
#' @inheritParams regsen_bounds
#' @return A data.frame with columns `variable` and `R2`.
#' @export
calibrate_partial_r2 <- function(formula, data, compare = NULL,
                                  nocompare = NULL, subset = NULL) {
    inp <- build_dgp_inputs(formula, data, compare = compare,
                             nocompare = nocompare, subset = subset)
    w1_res <- project_residuals(inp$w1, inp$w0)
    if (ncol(w1_res) < 2) {
        stop("partial R^2 needs at least two comparison controls",
             call. = FALSE)
    }
    out <- data.frame(
        variable = colnames(w1_res),
        R2 = NA_real_,
        stringsAsFactors = FALSE
    )
    for (k in colnames(w1_res)) {
        others <- setdiff(colnames(w1_res), k)
        rk <- w1_res[, k]
        df <- as.data.frame(w1_res[, others, drop = FALSE])
        df$.target <- rk
        fit <- stats::lm(.target ~ ., data = df)
        out$R2[out$variable == k] <- summary(fit)$r.squared
    }
    out[order(-out$R2), , drop = FALSE]
}
