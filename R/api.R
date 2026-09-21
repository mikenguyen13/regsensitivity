## api.R --- public-facing functions for regsensitivity.
##
## The R interface differs from Stata's in two ways:
##
##   * One R function per subcommand (`regsen_bounds`, `regsen_breakdown`,
##     `regsen_summary`) plus a convenience wrapper `regsensitivity()` that
##     dispatches by `subcommand =`. This mirrors the Stata help layout
##     while feeling natural in R.
##
##   * Inputs are passed as a formula plus data.frame, plus explicit named
##     arguments for each sensitivity parameter. Stata's parser allowed
##     things like `rxbar(0(.1)1, bound)` -- we expose those choices via
##     `rxbar = seq(0, 1, 0.1)` and `rxbar_type = "bound"`, both far simpler
##     to manipulate from R code.

#' Regression sensitivity analysis
#'
#' Top-level dispatcher that mirrors the Stata `regsensitivity` command.
#' For most users, calling [regsen_bounds()] or [regsen_breakdown()] directly
#' is clearer.
#'
#' @param subcommand One of `"bounds"`, `"breakdown"`, `"summary"`.
#' @param formula Two-sided formula: `y ~ x + w1 + w2 + ...`. The first
#'   right-hand-side variable is the primary independent variable; the rest
#'   are controls.
#' @param data A data.frame.
#' @param ... Additional arguments forwarded to the underlying function.
#'
#' @return An object of class `regsensitivity`.
#' @seealso [regsen_bounds()], [regsen_breakdown()], [regsen_summary()]
#' @export
regsensitivity <- function(subcommand = c("bounds", "breakdown", "summary"),
                            formula, data, ...) {
    subcommand <- match.arg(subcommand)
    switch(subcommand,
           bounds    = regsen_bounds(formula, data, ...),
           breakdown = regsen_breakdown(formula, data, ...),
           summary   = regsen_summary(formula, data, ...))
}

# Translate the user-facing `analysis` argument into the internal flag.
match_analysis <- function(analysis) {
    analysis <- match.arg(analysis, c("dmp", "oster"))
    analysis
}

# Translate a hypothesis spec into (hyposign, hypoval).
#
# Accepted values:
#   "sign"           -> sign(beta) = sign(beta_med); converts at runtime
#   c(0, "lb")       -> beta > 0    (hyposign = ">")
#   c(0, "ub")       -> beta < 0    (hyposign = "<")
#   c(0, "eq")       -> beta != 0   (hyposign = "=")
#   list(value=#, sign=">"|"<"|"=") for the more explicit form.
# Validate the lower end of DMP Assumption A6, R(W2 ~ W1 . W0) in [clow, cbar].
check_clow <- function(clow, cbar) {
    if (is.null(clow) || length(clow) == 0) return(0)
    if (length(clow) != 1 || !is.numeric(clow) || !is.finite(clow)) {
        stop("`clow` must be a single finite number.", call. = FALSE)
    }
    if (clow < 0 || clow > 1) {
        stop("`clow` must lie in [0, 1]; got ", format(clow), ".",
             call. = FALSE)
    }
    if (clow > min(cbar)) {
        stop("`clow` must not exceed `cbar`; got clow = ", format(clow),
             " and cbar = ", format(min(cbar)), ".", call. = FALSE)
    }
    clow
}

# Validate the DMP sensitivity parameters before anything is computed from
# them. cbar bounds a correlation and lives in [0, 1]; rxbar and rybar are
# ratios of standard deviations and are non-negative, with rybar = +Inf
# meaning no restriction. Out-of-range values used to pass straight through
# to the closed forms and the optimizer, which then returned NA or nonsense
# without saying why.
check_dmp_sparams <- function(rxbar = NULL, rybar = NULL, cbar = NULL) {
    chk <- function(v, name, hi, allow_inf) {
        if (is.null(v)) return(invisible())
        if (!is.numeric(v) || length(v) == 0 || anyNA(v)) {
            stop("`", name, "` must be numeric with no missing values.",
                 call. = FALSE)
        }
        if (!allow_inf && any(!is.finite(v))) {
            stop("`", name, "` must be finite.", call. = FALSE)
        }
        bad <- v < 0 | v > hi
        if (any(bad)) {
            stop("`", name, "` must lie in [0, ", hi, "]; got ",
                 paste(format(v[bad]), collapse = ", "), ".", call. = FALSE)
        }
    }
    chk(rxbar, "rxbar", Inf, allow_inf = FALSE)
    chk(rybar, "rybar", Inf, allow_inf = TRUE)
    chk(cbar,  "cbar",  1,   allow_inf = FALSE)
    invisible()
}

# The Oster counterpart: delta is any real number, r2long lies in [0, 1]
# (before any `relative` rescaling), and maxovb is NA (no constraint) or a
# non-negative number.
check_oster_sparams <- function(delta = NULL, r2long = NULL, maxovb = NULL) {
    if (!is.null(delta) && (!is.numeric(delta) || anyNA(delta))) {
        stop("`delta` must be numeric with no missing values.", call. = FALSE)
    }
    if (!is.null(r2long) && (!is.numeric(r2long) || length(r2long) == 0 ||
                             anyNA(r2long) || any(r2long < 0))) {
        stop("`r2long` must be numeric, non-negative and without missing ",
             "values.", call. = FALSE)
    }
    if (!is.null(maxovb) && !all(is.na(maxovb)) &&
        (!is.numeric(maxovb) || any(maxovb < 0, na.rm = TRUE))) {
        stop("`maxovb` must be NA or a non-negative number.", call. = FALSE)
    }
    invisible()
}

parse_beta <- function(beta, dgp) {
    # Defaults -- "sign" hypothesis at 0.
    if (is.null(beta) || identical(beta, "sign") ||
        (is.character(beta) && length(beta) == 1 && beta == "sign")) {
        value <- 0
        sign <- if (dgp$beta_med >= 0) ">" else "<"
        return(list(value = value, sign = sign, multiple = FALSE))
    }
    # list(...) form
    if (is.list(beta)) {
        value <- beta$value
        sign  <- beta$sign
        if (!is.numeric(value) || length(value) == 0 || anyNA(value)) {
            stop("`beta$value` must be a numeric vector without missing ",
                 "values.", call. = FALSE)
        }
        if (!is.character(sign) || length(sign) != 1 ||
            !sign %in% c(">", "<", "=")) {
            stop("`beta$sign` must be one of \">\", \"<\" or \"=\".",
                 call. = FALSE)
        }
        return(list(value = value, sign = sign, multiple = length(value) > 1))
    }
    # numeric scalar / vector + optional type via attr
    if (is.numeric(beta)) {
        value <- beta
        sign  <- attr(beta, "sign")
        if (is.null(sign)) {
            sign <- if (length(value) == 1 && value == 0 && dgp$beta_med >= 0) ">"
                    else if (length(value) == 1 && value == 0) "<"
                    else ">"
        }
        return(list(value = value, sign = sign, multiple = length(value) > 1))
    }
    stop("invalid `beta` specification", call. = FALSE)
}

# Build the package's standard result object.
new_regsen <- function(subcommand, analysis, dgp, inputs, sparams, results,
                        call, extras = list()) {
    structure(
        c(
            list(
                subcommand = subcommand,
                analysis = analysis,
                call = call,
                n = inputs$n,
                depvar = inputs$y_name,
                indvar = inputs$x_name,
                compare = inputs$compare_names,
                controls = inputs$control_names,
                sparams = sparams,
                summary_stats = sumstats_table(dgp),
                dgp = dgp,
                results = results
            ),
            extras
        ),
        class = "regsensitivity"
    )
}

#' Bounds on a regression coefficient under omitted-variable bias
#'
#' Computes the identified set for the coefficient on the primary independent
#' variable in the infeasible long regression, across a grid of sensitivity
#' parameters. Implements the analyses of Diegert, Masten & Poirier (2026)
#' (the default) and of Oster (2019) extended by Masten & Poirier (2026).
#'
#' @inheritParams regsensitivity
#' @param analysis Which sensitivity analysis to run: `"dmp"` (default) or
#'   `"oster"`.
#' @param compare Optional character vector of variables to use as the
#'   comparison set. Defaults to all controls if neither `compare` nor
#'   `nocompare` is given.
#' @param nocompare Optional character vector of controls to *exclude* from
#'   the comparison set.
#' @param rxbar,rybar,cbar (DMP) Numeric vectors of sensitivity-parameter
#'   values to sweep over. `rybar = Inf` (the default) gives the no-rybar
#'   case; setting it finite invokes the global-optimization code path.
#' @param clow (DMP) Lower bound on control endogeneity, the `clow` of DMP
#'   Assumption A6 `R(W2 ~ W1 . W0) %in% [clow, cbar]`. Default 0, which
#'   asserts nothing beyond `cbar`. A positive value asserts that the
#'   controls are *at least* that endogenous. Must satisfy
#'   `0 <= clow <= min(cbar)`.
#' @param rybar_expr (DMP) A function `function(rxbar) rybar` to set rybar
#'   as a function of rxbar (the only supported form in the Stata source
#'   is `rybar = rxbar`, i.e. `function(rxbar) rxbar`).
#' @param delta,r2long,maxovb (Oster) Numeric vectors of sensitivity values.
#' @param delta_type One of `"eq"` (equality, the default) or `"bound"`.
#' @param r2long_type One of `"eq"` (the default) or `"relative"`. When
#'   `"relative"`, values are multiplied by R-squared(medium).
#' @param maxovb_type One of `"bound"` (default) or `"relative"`. When
#'   `"relative"`, values are multiplied by |Beta(medium)|.
#' @param beta Hypothesis spec for the breakdown point. See [regsen_breakdown()].
#' @param product Logical. If `TRUE` (default), all combinations of the
#'   sensitivity-parameter grids are evaluated; if `FALSE`, the inputs are
#'   zipped element-wise. Maps to Stata's `noproduct` option (inverted).
#' @param subset Optional logical or integer vector indicating which rows
#'   of `data` to include in the estimation.
#'
#' @return A `regsensitivity` object. The `results` field holds a data.frame
#'   with one row per sensitivity-parameter point.
#'
#'   For a breakdown analysis, `results$breakdown` is **signed**: its sign
#'   carries the direction of selection, and for Oster it is the `delta`
#'   that solves Proposition 3 for the hypothesised value. Feeding that
#'   value back into [regsen_bounds()] recovers the hypothesised beta, but
#'   feeding `abs()` of it lands on a different branch of the cubic. The
#'   scalar `$breakdown` field and the print method report the magnitude,
#'   since that is what is quoted as "the breakdown point". Note that the
#'   scalar exists on [regsen_bounds()] output only; a [regsen_breakdown()]
#'   result carries the value in `results$breakdown` alone.
#'
#' @examples
#' \donttest{
#' data(bfg2020)
#' bnds <- regsen_bounds(
#'   avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 +
#'     log_area_2010 + lat + lon + temp_mean + rain_mean + elev_mean +
#'     d_coa + d_riv + d_lak + ave_gyi,
#'   data = bfg2020,
#'   cbar = 0.1
#' )
#' print(bnds)
#' }
#' @export
regsen_bounds <- function(formula, data,
                          analysis = c("dmp", "oster"),
                          compare = NULL, nocompare = NULL,
                          rxbar = NULL, rybar = Inf, cbar = 1, clow = 0,
                          rybar_expr = NULL,
                          delta = NULL, r2long = 1, maxovb = NA,
                          delta_type = c("eq", "bound"),
                          r2long_type = c("eq", "relative"),
                          maxovb_type = c("bound", "relative"),
                          beta = "sign",
                          product = TRUE,
                          subset = NULL) {
    cl <- match.call()
    analysis <- match_analysis(analysis)
    delta_type  <- match.arg(delta_type)
    r2long_type <- match.arg(r2long_type)
    maxovb_type <- match.arg(maxovb_type)

    inputs <- build_dgp_inputs(formula, data, compare = compare,
                                nocompare = nocompare, subset = subset)
    dgp <- get_dgp(inputs)
    hypo <- parse_beta(beta, dgp)

    if (analysis == "dmp") {
        if (length(rybar) == 0) rybar <- Inf
        check_dmp_sparams(rxbar, rybar, cbar)
        clow <- check_clow(clow, cbar)
        # rxbar defaults to a grid spanning [0, rmax(cbar)] when not specified.
        if (is.null(rxbar)) {
            rmax <- max(max_beta_bound_vec(as.numeric(cbar), dgp, clow = clow))
            if (!is.finite(rmax)) rmax <- 1
            rxbar <- seq(0, rmax, length.out = 11)
        }
        if (!is.null(rybar_expr)) {
            ry_vals <- vapply(rxbar, rybar_expr, numeric(1))
            stopifnot(length(ry_vals) == length(rxbar))
            product <- FALSE
        }

        idset <- dmp_identified_set(
            rxbar = rxbar,
            rybar = if (!is.null(rybar_expr)) ry_vals else rybar,
            cbar  = cbar,
            s = dgp, product = product, clow = clow
        )

        # Decide which sparams are scalar vs varying, for downstream display.
        scalar_sparam <- c()
        if (length(unique(rxbar)) == 1) scalar_sparam <- c(scalar_sparam, "rxbar")
        if (length(unique(rybar)) == 1 && is.null(rybar_expr)) scalar_sparam <- c(scalar_sparam, "rybar")
        if (length(unique(cbar))  == 1) scalar_sparam <- c(scalar_sparam, "cbar")
        nonscalar_sparam <- setdiff(c("rxbar", "rybar", "cbar"), scalar_sparam)

        # Breakdown -- computed when cbar is scalar AND (rybar is scalar OR
        # rybar_expr is provided). Mirrors the Stata `breakdown_dmp` cases.
        breakdown <- NA_real_
        cbar_is_scalar <- length(unique(cbar)) == 1
        rybar_is_scalar <- length(unique(rybar)) == 1
        if (cbar_is_scalar && (rybar_is_scalar || !is.null(rybar_expr))) {
            bf <- dmp_breakdown_frontier(
                beta = hypo$value, cs = unique(cbar),
                ry = if (!is.null(rybar_expr)) Inf else unique(rybar),
                hyposign = hypo$sign, s = dgp,
                ry_expr = rybar_expr, clow = clow
            )
            breakdown <- bf$breakdown[1]
        }

        sparams <- list(rxbar = rxbar, rybar = rybar, cbar = cbar,
                        clow = clow, rybar_expr = rybar_expr,
                        scalar = scalar_sparam, nonscalar = nonscalar_sparam,
                        product = product)

        extras <- list(
            hyposign = hypo$sign,
            hypoval = if (hypo$multiple) NA_real_ else hypo$value,
            breakdown = breakdown,
            beta_label = if (hypo$multiple) "Beta(Hypothesis)" else hypo$value
        )

        return(new_regsen(
            subcommand = "bounds", analysis = "DMP (2026)",
            dgp = dgp, inputs = inputs,
            sparams = sparams,
            results = idset, call = cl, extras = extras
        ))
    }

    ## ----- Oster branch ----------------------------------------------------
    check_oster_sparams(delta, r2long, maxovb)
    if (is.null(delta)) {
        delta <- if (delta_type == "eq") seq(-1, 1, by = 0.1) else seq(0, 1, by = 0.01)
    }
    if (r2long_type == "relative") {
        r2long <- r2long * dgp$r_med
    }
    # Clip r2long to (r_med, 1].
    r2long <- pmin(pmax(r2long, dgp$r_med), 1)
    if (is.na(maxovb[1])) {
        maxovb_use <- NA_real_
    } else {
        maxovb_use <- if (maxovb_type == "relative") maxovb * abs(dgp$beta_med) else maxovb
    }

    if (delta_type == "eq") {
        results <- oster_idset_eq(delta, r2long, maxovb_use[1], dgp)
    } else {
        results <- oster_idset_bound(delta, r2long, maxovb_use[1], dgp)
    }

    # Breakdown point if r2long is scalar.
    breakdown <- NA_real_
    if (length(unique(r2long)) == 1) {
        if (delta_type == "eq" || hypo$sign == "=") {
            bf <- oster_breakdown_eq(unique(r2long), hypo$value,
                                      maxovb_use[1], dgp)
        } else {
            bf <- oster_breakdown_bound(unique(r2long), hypo$value,
                                         maxovb_use[1], hypo$sign, dgp)
        }
        breakdown <- bf$breakdown[1]
    }

    sparams <- list(delta = delta, r2long = r2long, maxovb = maxovb_use,
                    delta_type = delta_type, r2long_type = r2long_type,
                    maxovb_type = maxovb_type)

    extras <- list(
        hyposign = hypo$sign,
        hypoval = if (hypo$multiple) NA_real_ else hypo$value,
        breakdown = breakdown,
        beta_label = if (hypo$multiple) "Beta(Hypothesis)" else hypo$value
    )
    new_regsen(
        subcommand = "bounds", analysis = "Oster (2019)",
        dgp = dgp, inputs = inputs,
        sparams = sparams,
        results = results, call = cl, extras = extras
    )
}

#' Breakdown frontier for a regression coefficient hypothesis
#'
#' Find the smallest sensitivity-parameter value at which a given hypothesis
#' about the long-regression coefficient first fails. For DMP, this is rxbar
#' as a function of (cbar, rybar, beta) or -- with `direction = "rybar"` --
#' rybar as a function of (rxbar, cbar, beta). For Oster, this is |delta| as
#' a function of R-squared(long), beta and (optionally) maxovb.
#'
#' @inheritParams regsen_bounds
#' @param beta Hypothesis spec. One of:
#'   * `"sign"` -- the hypothesis that sign(beta_long) = sign(beta_med).
#'   * a numeric scalar or vector. Use the helpers [bnd_lb()], [bnd_ub()],
#'     [bnd_eq()] to set the direction, e.g. `beta = bnd_lb(0)` for the
#'     hypothesis `beta > 0`.
#' @param cbar,clow,rybar,rybar_expr (DMP) Same as in [regsen_bounds()].
#' @param direction (DMP) Which sensitivity parameter the breakdown point is
#'   reported in: `"rxbar"` (default) sweeps `cbar` or `beta` and solves for
#'   rxbar; `"rybar"` sweeps `rxbar` and solves for rybar, the frontier
#'   `rybar_bf(rxbar)` of DMP (2026) Theorem 4. The two trace the same
#'   frontier, but only the rybar direction can describe its horizontal arm,
#'   where the conclusion survives every rxbar and the rxbar breakdown point
#'   is `+Inf`.
#' @param rxbar (DMP, `direction = "rybar"`) Numeric vector of rxbar values
#'   at which to evaluate the frontier. Defaults to an 11-point grid over
#'   `[0, 2 * rmax(cbar)]`.
#' @param r2long,maxovb (Oster) Same as in [regsen_bounds()].
#'
#' @return A `regsensitivity` object. `results$index` holds the swept
#'   parameter and `results$breakdown` the breakdown point at each value.
#' @examples
#' \donttest{
#' data(bfg2020)
#' bk <- regsen_breakdown(
#'   avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 +
#'     log_area_2010 + lat + lon + temp_mean + rain_mean + elev_mean +
#'     d_coa + d_riv + d_lak + ave_gyi,
#'   data = bfg2020,
#'   cbar = seq(0, 1, 0.1)
#' )
#' print(bk)
#' }
#' @export
regsen_breakdown <- function(formula, data,
                             analysis = c("dmp", "oster"),
                             compare = NULL, nocompare = NULL,
                             cbar = 1, clow = 0, rybar = Inf,
                             rybar_expr = NULL,
                             direction = c("rxbar", "rybar"),
                             rxbar = NULL,
                             r2long = 1, maxovb = NA,
                             r2long_type = c("eq", "relative"),
                             maxovb_type = c("bound", "relative"),
                             beta = "sign",
                             subset = NULL) {
    cl <- match.call()
    analysis <- match_analysis(analysis)
    direction <- match.arg(direction)
    r2long_type <- match.arg(r2long_type)
    maxovb_type <- match.arg(maxovb_type)

    inputs <- build_dgp_inputs(formula, data, compare = compare,
                                nocompare = nocompare, subset = subset)
    dgp <- get_dgp(inputs)
    bd <- breakdown_from_dgp(
        dgp, analysis = analysis, beta = beta,
        cbar = cbar, clow = clow, rybar = rybar, rybar_expr = rybar_expr,
        direction = direction, rxbar = rxbar,
        r2long = r2long, maxovb = maxovb,
        r2long_type = r2long_type, maxovb_type = maxovb_type
    )
    new_regsen(
        subcommand = "breakdown",
        analysis = if (analysis == "dmp") "DMP (2026)" else "Oster (2019)",
        dgp = dgp, inputs = inputs,
        sparams = bd$sparams,
        results = bd$results, call = cl, extras = bd$extras
    )
}

# The breakdown computation of `regsen_breakdown()`, resolved against a dgp
# instead of a data set.
#
# Both the public function and the bootstrap go through this. A bootstrap or
# jackknife replicate can therefore reuse the model matrices built once for
# the original data instead of paying for model.frame() every time -- on the
# bundled data that is the difference between 71 and 10 milliseconds per
# replicate. Everything that depends on the sample (the direction of a
# "sign" hypothesis, a relative r2long, a relative maxovb) is resolved from
# the dgp passed in, so a replicate is computed exactly as the point
# estimate is.
breakdown_from_dgp <- function(dgp, analysis = "dmp", beta = "sign",
                               cbar = 1, clow = 0, rybar = Inf,
                               rybar_expr = NULL,
                               direction = "rxbar", rxbar = NULL,
                               r2long = 1, maxovb = NA,
                               r2long_type = "eq", maxovb_type = "bound") {
    hypo <- parse_beta(beta, dgp)

    if (analysis == "dmp") {
        check_dmp_sparams(rxbar, rybar, cbar)
        clow <- check_clow(clow, cbar)
        if (direction == "rybar") {
            if (length(unique(cbar)) > 1) {
                stop("`cbar` must be a single value when ",
                     "direction = \"rybar\".", call. = FALSE)
            }
            if (is.null(rxbar)) {
                rmax <- max_beta_bound(cbar[1], dgp, clow = clow)
                hi <- if (is.finite(rmax)) 2 * rmax else 2
                rxbar <- seq(0, hi, length.out = 11)
            }
            bf <- dmp_breakdown_frontier_ry(
                beta = hypo$value[1], cbar = cbar[1], rxbar = rxbar,
                hyposign = hypo$sign, s = dgp, clow = clow
            )
        } else {
            bf <- dmp_breakdown_frontier(
                beta = hypo$value, cs = cbar,
                ry = if (is.null(rybar_expr)) rybar[1] else Inf,
                hyposign = hypo$sign, s = dgp,
                ry_expr = rybar_expr, clow = clow
            )
        }
        return(list(
            results = bf,
            sparams = list(cbar = cbar, clow = clow, rybar = rybar,
                           rxbar = rxbar, rybar_expr = rybar_expr,
                           direction = direction),
            extras = list(
                hyposign = hypo$sign,
                hypoval = if (hypo$multiple) NA_real_ else hypo$value,
                direction = direction,
                varying = if (direction == "rybar") "rxbar"
                          else if (length(hypo$value) > 1) "beta" else "cbar"
            )
        ))
    }

    ## ----- Oster branch ----------------------------------------------------
    check_oster_sparams(r2long = r2long, maxovb = maxovb)
    if (r2long_type == "relative") {
        r2long <- r2long * dgp$r_med
    }
    r2long <- pmin(pmax(r2long, dgp$r_med), 1)
    if (is.na(maxovb[1])) {
        maxovb_use <- NA_real_
    } else {
        maxovb_use <- if (maxovb_type == "relative") {
            maxovb * abs(dgp$beta_med)
        } else {
            maxovb
        }
    }
    if (hypo$sign == "=") {
        bf <- oster_breakdown_eq(r2long, hypo$value, maxovb_use, dgp)
    } else {
        bf <- oster_breakdown_bound(r2long, hypo$value, maxovb_use,
                                     hypo$sign, dgp)
    }
    list(
        results = bf,
        sparams = list(r2long = r2long, maxovb = maxovb_use,
                       r2long_type = r2long_type, maxovb_type = maxovb_type),
        extras = list(
            hyposign = hypo$sign,
            hypoval = if (hypo$multiple) NA_real_ else hypo$value,
            varying = if (length(unique(maxovb_use)) > 1) "maxovb"
                      else if (length(unique(r2long)) > 1) "r2long" else "beta"
        )
    )
}

#' Sensitivity summary (DMP bounds + Oster breakdown)
#'
#' Runs the default sweep used by Stata's `regsensitivity` when no subcommand
#' is given: a DMP bounds analysis and an Oster breakdown analysis at a few
#' standard r2long values.
#'
#' @inheritParams regsen_bounds
#' @return A list with elements `dmp_bounds` and `oster_breakdown`, each a
#'   `regsensitivity` object.
#' @export
regsen_summary <- function(formula, data,
                            compare = NULL, nocompare = NULL,
                            subset = NULL) {
    inputs <- build_dgp_inputs(formula, data, compare = compare,
                                nocompare = nocompare, subset = subset)
    dgp <- get_dgp(inputs)

    bnds <- regsen_bounds(formula, data, analysis = "dmp",
                          compare = compare, nocompare = nocompare,
                          subset = subset)
    r2rot <- min(dgp$r_med * 1.3, 1)
    # The grid ends at 1 whether or not the step lands there; unique() keeps
    # 1 from appearing twice when it does.
    breakdown <- regsen_breakdown(
        formula, data, analysis = "oster",
        compare = compare, nocompare = nocompare, subset = subset,
        r2long = unique(c(seq(r2rot, 1, by = 0.1), 1))
    )
    structure(list(dmp_bounds = bnds, oster_breakdown = breakdown),
              class = c("regsensitivity_summary", "list"))
}

#' Hypothesis-direction helpers
#'
#' Convenience wrappers for specifying the direction of a hypothesis used by
#' [regsen_breakdown()] and [regsen_bounds()].
#' @param x Numeric scalar or vector of hypothesis values.
#' @name hypothesis_helpers
#' @export
#' @examples
#' bnd_lb(0)
#' bnd_ub(4)
#' bnd_eq(0)
bnd_lb <- function(x) {
    out <- as.numeric(x)
    attr(out, "sign") <- ">"
    out
}
#' @rdname hypothesis_helpers
#' @export
bnd_ub <- function(x) {
    out <- as.numeric(x)
    attr(out, "sign") <- "<"
    out
}
#' @rdname hypothesis_helpers
#' @export
bnd_eq <- function(x) {
    out <- as.numeric(x)
    attr(out, "sign") <- "="
    out
}
