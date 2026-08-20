# Package-level docs and re-exports.

#' regsensitivity: regression sensitivity analysis
#'
#' Implements the identified-set and breakdown-point sensitivity analyses
#' of Diegert, Masten and Poirier (2026), Oster (2019), and Masten and
#' Poirier (2026) for the coefficient of interest in a linear regression
#' with omitted variables.
#'
#' @section Core functions:
#' * [regsen_bounds()] -- identified set across sensitivity parameters
#' * [regsen_breakdown()] -- smallest sensitivity value at which a hypothesis fails
#' * [regsen_summary()] -- default summary sweep (DMP + Oster)
#' * [plot.regsensitivity()] -- ggplot2 visualization
#'
#' @section Reference data:
#' * [bfg2020] -- subset of the Bazzi, Fiszbein & Gebresilasse (2020)
#'   replication data, used to demonstrate the package.
#'
#' @keywords internal
#' @importFrom stats as.formula coef lm model.frame model.matrix model.response resid terms var
#' @importFrom rlang .data
#' @importFrom grid unit
"_PACKAGE"

# Register tidy()/glance() on the `generics` package's verbs, but only when
# it is installed. Doing it here rather than with @export keeps `generics`
# in Suggests: a user who never touches broom or modelsummary should not be
# made to install it, and CRAN counts hard dependencies against you.
.onLoad <- function(libname, pkgname) {
    if (requireNamespace("generics", quietly = TRUE)) {
        registerS3method("tidy",   "regsensitivity", tidy.regsensitivity,
                         envir = asNamespace("generics"))
        registerS3method("glance", "regsensitivity", glance.regsensitivity,
                         envir = asNamespace("generics"))
    }
    invisible()
}
