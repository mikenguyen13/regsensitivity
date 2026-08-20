## broom.R --- tidy()/glance() so results flow into the wider tooling.

#' Tidy a sensitivity analysis
#'
#' A \pkg{broom}-style tidier. `tidy()` returns one row per point of the
#' sensitivity sweep; `glance()` returns a one-row summary of the analysis
#' as a whole.
#'
#' Implementing these makes `regsensitivity` objects usable by anything
#' that speaks the broom vocabulary -- most usefully \pkg{modelsummary},
#' which is how many economists assemble their tables.
#'
#' The methods are registered on \pkg{generics}' `tidy()` and `glance()`
#' only when that package is installed, so it stays an optional dependency.
#' Without it, call [regsen_tidy()] and [regsen_glance()] directly.
#'
#' @param x A `regsensitivity` object.
#' @param conf.int Ignored; present for signature compatibility with other
#'   tidiers. Sensitivity bounds are not confidence intervals -- see
#'   [regsen_boot()] for sampling uncertainty in the breakdown point.
#' @param ... Ignored.
#'
#' @return `regsen_tidy()` returns a `data.frame` with the sensitivity
#'   parameters plus `conf.low`/`conf.high` holding the identified set, using
#'   broom's column names so downstream packages recognise them.
#'   `regsen_glance()` returns a one-row `data.frame`.
#'
#' @examples
#' \donttest{
#' data(bfg2020)
#' res <- regsen_bounds(
#'     avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
#'     data = bfg2020, compare = c("log_area_2010", "lat", "lon"),
#'     cbar = c(0.1, 0.5)
#' )
#' head(regsen_tidy(res))
#' regsen_glance(res)
#' }
#' @export
regsen_tidy <- function(x, conf.int = TRUE, ...) {
    stopifnot(inherits(x, "regsensitivity"))
    df <- as.data.frame(x)
    if (nrow(df) == 0) return(df)

    # broom's vocabulary: term / estimate / conf.low / conf.high. The
    # identified set maps onto conf.low-conf.high, which is what lets
    # modelsummary and friends lay it out without special-casing.
    #
    # `estimate` is the medium-regression coefficient, never a function of
    # the bounds. Under DMP with rybar = Inf the set is symmetric about that
    # coefficient, so a midpoint would look right here and then diverge for
    # Oster or finite rybar -- and it is undefined wherever the set is
    # unbounded, which is exactly where the analysis is most interesting.
    out <- df
    if (all(c("bmin", "bmax") %in% names(out))) {
        names(out)[names(out) == "bmin"] <- "conf.low"
        names(out)[names(out) == "bmax"] <- "conf.high"
    }
    out$term <- x$indvar
    out$estimate <- if (!is.null(x$dgp$beta_med)) x$dgp$beta_med else NA_real_

    lead <- intersect(c("term", "estimate", "conf.low", "conf.high"),
                      names(out))
    out[c(lead, setdiff(names(out), lead))]
}

#' @rdname regsen_tidy
#' @export
regsen_glance <- function(x, ...) {
    stopifnot(inherits(x, "regsensitivity"))
    bp <- x$breakdown
    if (is.null(bp) || length(bp) != 1) bp <- NA_real_

    data.frame(
        analysis       = x$analysis,
        subcommand     = x$subcommand,
        outcome        = x$depvar,
        treatment      = x$indvar,
        nobs           = x$n,
        beta_medium    = if (!is.null(x$dgp$beta_med)) x$dgp$beta_med
                         else NA_real_,
        breakdown      = abs(bp),
        hypothesis     = tryCatch(format_hypothesis(x),
                                  error = function(e) NA_character_),
        n_gridpoints   = if (is.null(x$results)) 0L else nrow(x$results),
        stringsAsFactors = FALSE
    )
}

# Registered in .onLoad() so `generics` stays a Suggests rather than a hard
# dependency: a user who never touches broom/modelsummary should not have
# to install it.
tidy.regsensitivity   <- function(x, conf.int = TRUE, ...) regsen_tidy(x, conf.int, ...)
glance.regsensitivity <- function(x, ...) regsen_glance(x, ...)
