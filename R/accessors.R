## accessors.R --- extract results without reaching into the object.
##
## The objects are lists, and their fields used to be the only way to the
## numbers, which tied every script to the internal layout. These accessors
## are the stable interface; the layout behind them may change.

#' Extract results from a sensitivity analysis
#'
#' Accessors for the quantities most often reported, so that scripts do not
#' depend on how the result objects are laid out internally.
#'
#' * `breakdown_point()` returns the breakdown point. For [regsen_bounds()]
#'   output it is a scalar (`NA` when the sweep does not define one); for
#'   [regsen_breakdown()] output it is one value per point of the frontier,
#'   in the order of `breakdown_frontier()`; for [regsen_boot()] output, the
#'   point estimate; for [regsen_multi()] output, one value per treatment,
#'   named by treatment.
#' * `breakdown_frontier()` returns the frontier as a data frame whose first
#'   column is named after the parameter swept (`cbar`, `beta`, `rxbar`,
#'   `r2long` or `maxovb`) and whose second is `breakdown`.
#' * `identified_set()` returns the bounds of a [regsen_bounds()] sweep: one
#'   row per point, with the sensitivity parameters and `bmin`, `bmax`.
#' * `sensitivity_params()` returns the sensitivity parameters the analysis
#'   was run at, as a named list.
#' * `coef()` returns the short- and medium-regression coefficients on the
#'   treatment, the two estimates the sensitivity analysis starts from, and
#'   `nobs()` the number of observations used.
#'
#' @param x,object A result object.
#' @param signed Logical. The breakdown point is reported as a magnitude,
#'   which is the number quoted as "the breakdown point". With
#'   `signed = TRUE` an Oster breakdown keeps the sign that records the
#'   direction of selection; see [regsen_breakdown()].
#' @param ... Ignored.
#'
#' @return See Details.
#' @seealso [as.data.frame.regsensitivity()] for the full results table.
#' @examples
#' data(bfg2020)
#' f <- avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon
#' w1 <- c("log_area_2010", "lat", "lon")
#'
#' bnds <- regsen_bounds(f, bfg2020, compare = w1, cbar = 0.1)
#' breakdown_point(bnds)
#' head(identified_set(bnds))
#' coef(bnds)
#'
#' bk <- regsen_breakdown(f, bfg2020, compare = w1, cbar = c(0, 0.5, 1))
#' breakdown_frontier(bk)
#' breakdown_point(bk)
#' @name regsensitivity-accessors
NULL

#' @rdname regsensitivity-accessors
#' @export
breakdown_point <- function(x, ...) UseMethod("breakdown_point")

#' @rdname regsensitivity-accessors
#' @export
breakdown_point.regsensitivity <- function(x, signed = FALSE, ...) {
    bp <- if (x$subcommand == "breakdown") {
        x$results$breakdown
    } else if (!is.null(x$breakdown) && length(x$breakdown) == 1) {
        x$breakdown
    } else {
        NA_real_
    }
    if (isTRUE(signed)) bp else abs(bp)
}

#' @rdname regsensitivity-accessors
#' @export
breakdown_point.regsensitivity_boot <- function(x, signed = FALSE, ...) {
    if (isTRUE(signed)) x$point else abs(x$point)
}

#' @rdname regsensitivity-accessors
#' @export
breakdown_point.regsensitivity_multi <- function(x, ...) {
    stats::setNames(x$breakdown, x$treatment)
}

#' @rdname regsensitivity-accessors
#' @export
breakdown_frontier <- function(x, ...) UseMethod("breakdown_frontier")

#' @rdname regsensitivity-accessors
#' @export
breakdown_frontier.regsensitivity <- function(x, signed = FALSE, ...) {
    if (x$subcommand != "breakdown") {
        stop("`x` is not a breakdown frontier; use regsen_breakdown().",
             call. = FALSE)
    }
    out <- as.data.frame(x)
    if (!is.null(x$varying)) names(out)[names(out) == "index"] <- x$varying
    if (!isTRUE(signed)) out$breakdown <- abs(out$breakdown)
    out
}

#' @rdname regsensitivity-accessors
#' @export
identified_set <- function(x, ...) UseMethod("identified_set")

#' @rdname regsensitivity-accessors
#' @export
identified_set.regsensitivity <- function(x, ...) {
    if (x$subcommand != "bounds") {
        stop("`x` holds a breakdown frontier, not identified sets; use ",
             "regsen_bounds().", call. = FALSE)
    }
    as.data.frame(x)
}

#' @rdname regsensitivity-accessors
#' @export
sensitivity_params <- function(x, ...) UseMethod("sensitivity_params")

#' @rdname regsensitivity-accessors
#' @export
sensitivity_params.regsensitivity <- function(x, ...) {
    sp <- x$sparams
    # Bookkeeping for the display code, not parameters of the analysis.
    sp[setdiff(names(sp), c("scalar", "nonscalar"))]
}

#' @rdname regsensitivity-accessors
#' @export
coef.regsensitivity <- function(object, ...) {
    c(short = object$dgp$beta_short, medium = object$dgp$beta_med)
}

#' @rdname regsensitivity-accessors
#' @export
nobs.regsensitivity <- function(object, ...) {
    object$n
}
