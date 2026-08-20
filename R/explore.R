## explore.R --- launcher for the interactive explorer.

# The app needs the model and data. They are put here rather than in
# options() or the global environment so that two explorers opened from one
# session cannot overwrite each other's inputs, and so nothing is left
# behind in the user's workspace.
.regsen_explore_env <- new.env(parent = emptyenv())

#' Explore a sensitivity analysis interactively
#'
#' Opens a \pkg{shiny} application for moving the sensitivity parameters by
#' hand and watching the identified set respond. It is a way of building
#' intuition, and of finding the region worth reporting, before committing
#' to a figure.
#'
#' \pkg{shiny} is only needed to run this, so it lives in `Suggests`: the
#' rest of the package works without it.
#'
#' @param formula A model formula, as for [regsen_bounds()].
#' @param data A data frame.
#' @param compare Character vector of comparison covariates.
#' @param ... Passed to [shiny::runApp()], e.g. `launch.browser` or `port`.
#'
#' @return Invisibly `NULL`; called for the running application.
#'
#' @examples
#' \dontrun{
#' data(bfg2020)
#' bfg2020$statea <- factor(bfg2020$statea)
#' w1 <- c("log_area_2010", "lat", "lon")
#' regsen_explore(
#'     avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
#'     data = bfg2020, compare = w1
#' )
#' }
#' @export
regsen_explore <- function(formula, data, compare = NULL, ...) {
    if (!requireNamespace("shiny", quietly = TRUE)) {
        stop("regsen_explore() needs the 'shiny' package.\n",
             "Install it with install.packages(\"shiny\"), or use ",
             "regsen_bounds() and plot() directly.", call. = FALSE)
    }
    if (!inherits(formula, "formula")) {
        stop("`formula` must be a formula.", call. = FALSE)
    }
    if (!is.data.frame(data)) {
        stop("`data` must be a data frame.", call. = FALSE)
    }

    # Fail here rather than inside a reactive: a bad model should report at
    # the call site, not as a red banner in a browser tab.
    probe <- try(regsen_bounds(formula, data, compare = compare, cbar = 1),
                 silent = TRUE)
    if (inherits(probe, "try-error")) {
        stop("the model could not be fitted:\n  ",
             conditionMessage(attr(probe, "condition")), call. = FALSE)
    }

    assign("formula", formula, envir = .regsen_explore_env)
    assign("data",    data,    envir = .regsen_explore_env)
    assign("compare", compare, envir = .regsen_explore_env)

    app_dir <- system.file("shiny", "explorer", package = "regsensitivity")
    if (!nzchar(app_dir)) {
        stop("the explorer app was not found in the installed package.",
             call. = FALSE)
    }
    shiny::runApp(app_dir, ...)
    invisible(NULL)
}
