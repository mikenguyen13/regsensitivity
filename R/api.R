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
#' @param ngrid Resolution of the finer grid stored in the result. Default 200.
#' @param subset Optional logical or integer vector indicating which rows
#'   of `data` to include in the estimation.
#'
#' @return A `regsensitivity` object. The `results` field holds a data.frame
#'   with one row per sensitivity-parameter point.
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
                          rxbar = NULL, rybar = Inf, cbar = 1,
                          rybar_expr = NULL,
                          delta = NULL, r2long = 1, maxovb = NA,
                          delta_type = c("eq", "bound"),
                          r2long_type = c("eq", "relative"),
                          maxovb_type = c("bound", "relative"),
                          beta = "sign",
                          product = TRUE,
                          ngrid = 200L,
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
        # rxbar defaults to a grid spanning [0, rmax(cbar)] when not specified.
        if (is.null(rxbar)) {
            rmax <- max(max_beta_bound_vec(as.numeric(cbar), dgp))
            rxbar <- seq(0, rmax, length.out = 11)
        }
        if (length(rybar) == 0) rybar <- Inf
        # Evaluate the user-specified rybar expression first so we can run
        # the safety check on the actual rybar values rather than a placeholder.
        if (!is.null(rybar_expr)) {
            ry_vals <- vapply(rxbar, rybar_expr, numeric(1))
            stopifnot(length(ry_vals) == length(rxbar))
            product <- FALSE
            safety_ry <- ry_vals
        } else {
            safety_ry <- rybar
        }
        if (dmp_sparam_unsafe(rxbar, safety_ry, cbar, product, dgp)) {
            stop("Bounds calculation not implemented in the region where ",
                 "rxbar > rmax(c) > rybar (see DMP 2026)", call. = FALSE)
        }

        idset <- dmp_identified_set(
            rxbar = rxbar,
            rybar = if (!is.null(rybar_expr)) ry_vals else rybar,
            cbar  = cbar,
            s = dgp, product = product
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
                ry_expr = rybar_expr
            )
            breakdown <- bf$breakdown[1]
        }

        sparams <- list(rxbar = rxbar, rybar = rybar, cbar = cbar,
                        rybar_expr = rybar_expr,
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
#' as a function of (cbar, rybar, beta). For Oster, this is |delta| as a
#' function of R-squared(long), beta and (optionally) maxovb.
#'
#' @inheritParams regsen_bounds
#' @param beta Hypothesis spec. One of:
#'   * `"sign"` -- the hypothesis that sign(beta_long) = sign(beta_med).
#'   * a numeric scalar or vector. Use the helpers [bnd_lb()], [bnd_ub()],
#'     [bnd_eq()] to set the direction, e.g. `beta = bnd_lb(0)` for the
#'     hypothesis `beta > 0`.
#' @param cbar,rybar,rybar_expr (DMP) Same as in [regsen_bounds()].
#' @param r2long,maxovb (Oster) Same as in [regsen_bounds()].
#'
#' @return A `regsensitivity` object.
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
                             cbar = 1, rybar = Inf, rybar_expr = NULL,
                             r2long = 1, maxovb = NA,
                             r2long_type = c("eq", "relative"),
                             maxovb_type = c("bound", "relative"),
                             beta = "sign",
                             ngrid = 200L,
                             subset = NULL) {
    cl <- match.call()
    analysis <- match_analysis(analysis)
    r2long_type <- match.arg(r2long_type)
    maxovb_type <- match.arg(maxovb_type)

    inputs <- build_dgp_inputs(formula, data, compare = compare,
                                nocompare = nocompare, subset = subset)
    dgp <- get_dgp(inputs)
    hypo <- parse_beta(beta, dgp)

    if (analysis == "dmp") {
        bf <- dmp_breakdown_frontier(
            beta = hypo$value, cs = cbar,
            ry = if (is.null(rybar_expr)) rybar[1] else Inf,
            hyposign = hypo$sign, s = dgp,
            ry_expr = rybar_expr
        )
        sparams <- list(cbar = cbar, rybar = rybar, rybar_expr = rybar_expr)
        extras <- list(
            hyposign = hypo$sign,
            hypoval = if (hypo$multiple) NA_real_ else hypo$value,
            varying = if (length(hypo$value) > 1) "beta" else "cbar"
        )
        return(new_regsen(
            subcommand = "breakdown", analysis = "DMP (2026)",
            dgp = dgp, inputs = inputs,
            sparams = sparams,
            results = bf, call = cl, extras = extras
        ))
    }

    ## ----- Oster branch ----------------------------------------------------
    if (r2long_type == "relative") {
        r2long <- r2long * dgp$r_med
    }
    r2long <- pmin(pmax(r2long, dgp$r_med), 1)
    if (is.na(maxovb[1])) {
        maxovb_use <- NA_real_
    } else {
        maxovb_use <- if (maxovb_type == "relative") maxovb * abs(dgp$beta_med) else maxovb
    }
    if (hypo$sign == "=") {
        bf <- oster_breakdown_eq(r2long, hypo$value, maxovb_use, dgp)
    } else {
        bf <- oster_breakdown_bound(r2long, hypo$value, maxovb_use,
                                     hypo$sign, dgp)
    }
    sparams <- list(r2long = r2long, maxovb = maxovb_use,
                    r2long_type = r2long_type, maxovb_type = maxovb_type)
    extras <- list(
        hyposign = hypo$sign,
        hypoval = if (hypo$multiple) NA_real_ else hypo$value,
        varying = if (length(unique(maxovb_use)) > 1) "maxovb"
                   else if (length(unique(r2long)) > 1) "r2long" else "beta"
    )
    new_regsen(
        subcommand = "breakdown", analysis = "Oster (2019)",
        dgp = dgp, inputs = inputs,
        sparams = sparams,
        results = bf, call = cl, extras = extras
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
    breakdown <- regsen_breakdown(
        formula, data, analysis = "oster",
        compare = compare, nocompare = nocompare, subset = subset,
        r2long = c(seq(r2rot, 1, by = 0.1), 1)
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
