## control.R --- tuning for the DMP global optimizer

#' Tuning for the finite-`rybar` optimizer
#'
#' With `rybar` finite and `cbar > 0`, the DMP (2026) identified set has no
#' closed form. Each bound is found by a global search over the unit cube
#' (the DIRECT-L algorithm), followed by a local polish (Subplex) started
#' from the point the global search returned. `regsen_control()` sets the
#' budget of both. Pass the result to the `control` argument of
#' [regsen_bounds()] or [regsen_breakdown()]; [regsen_boot()] and
#' [regsen_multi()] hand it on through `...`.
#'
#' The defaults agree to within about 3e-4 with a run twenty times as long
#' on the bundled data. To check a result of your own, run it again with a
#' larger budget, for example `regsen_control(maxiter = 5000, polish = 1500)`,
#' and compare: bounds that move by more than you care about mean the
#' default budget is too small for your problem. The closed-form regimes
#' (`rybar = Inf`, or `cbar = 0`) and the Oster analysis ignore these
#' settings.
#'
#' @param maxiter Maximum number of objective evaluations in the global
#'   search, per bound. Default 1000.
#' @param polish Maximum number of evaluations in the local polish, per
#'   bound. `0` skips the polish. Default 300.
#' @param precision Relative tolerance on the parameter point at which the
#'   global search stops; the polish uses one hundredth of it. Default 1e-8.
#'
#' @return A list of class `regsen_control`.
#' @examples
#' regsen_control()
#' regsen_control(maxiter = 5000, polish = 1500)
#' @export
regsen_control <- function(maxiter = 1000L, polish = 300L, precision = 1e-8) {
    count <- function(x, name, min) {
        if (!is.numeric(x) || length(x) != 1 || !is.finite(x) || x < min ||
            x != round(x)) {
            stop("`", name, "` must be a single whole number of at least ",
                 min, ".", call. = FALSE)
        }
        as.integer(x)
    }
    if (!is.numeric(precision) || length(precision) != 1 ||
        !is.finite(precision) || precision <= 0 || precision >= 1) {
        stop("`precision` must be a single number between 0 and 1.",
             call. = FALSE)
    }
    structure(
        list(maxiter = count(maxiter, "maxiter", 1),
             polish = count(polish, "polish", 0),
             precision = as.numeric(precision)),
        class = "regsen_control"
    )
}

#' @export
print.regsen_control <- function(x, ...) {
    cat("<regsen_control> maxiter = ", x$maxiter, ", polish = ", x$polish,
        ", precision = ", format(x$precision), "\n", sep = "")
    invisible(x)
}

# Accepts a regsen_control, a plain list of its fields, or NULL (defaults).
as_regsen_control <- function(control) {
    if (is.null(control)) return(regsen_control())
    if (inherits(control, "regsen_control")) return(control)
    if (is.list(control)) {
        bad <- setdiff(names(control), names(formals(regsen_control)))
        if (length(bad) || is.null(names(control))) {
            stop("`control` has unknown fields: ",
                 paste(bad, collapse = ", "),
                 ". Use regsen_control().", call. = FALSE)
        }
        return(do.call(regsen_control, control))
    }
    stop("`control` must come from regsen_control().", call. = FALSE)
}
