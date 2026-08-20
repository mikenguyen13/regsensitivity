## multi.R --- run the same sensitivity analysis across several treatments.

#' Sensitivity analysis for several treatments at once
#'
#' Runs [regsen_breakdown()] (or [regsen_bounds()]) once per candidate
#' treatment and collects the breakdown points into one table. This is the
#' applied question "which of my regressors would survive an unobservable,
#' and which would not?", answered in a single call.
#'
#' Each treatment is analysed in the *same* model: the variable of interest
#' moves to the front of the formula and every other right-hand-side term
#' stays a control, including the other candidate treatments. That is
#' deliberate -- dropping the others would change the specification and the
#' breakdown points would no longer be comparable across rows.
#'
#' @param formula A model formula. Its right-hand side must contain every
#'   name in `treatments`. Which term appears first does not matter here,
#'   since each treatment is promoted in turn.
#' @param data A data frame.
#' @param treatments Character vector of variables to treat as the
#'   treatment in turn.
#' @param compare Passed to the underlying analysis. A variable currently
#'   acting as the treatment is removed from `compare` for that row, since
#'   a variable cannot calibrate against itself.
#' @param fun The analysis to run: [regsen_breakdown()] (default) or
#'   [regsen_bounds()].
#' @param ... Passed to `fun`, e.g. `cbar`, `analysis`, `beta`.
#'
#' @return A `data.frame` of class `regsensitivity_multi`, one row per
#'   treatment, with columns `treatment`, `estimate` (the medium-regression
#'   coefficient), `breakdown`, and `n`. Rows where the analysis failed
#'   carry `NA` and an `error` column explaining why, rather than aborting
#'   the whole sweep.
#'
#' @examples
#' \donttest{
#' data(bfg2020)
#' w1 <- c("log_area_2010", "lat", "lon")
#' regsen_multi(
#'     avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
#'     data = bfg2020,
#'     treatments = c("tye_tfe890_500kNI_100_l6", "lat"),
#'     compare = w1, cbar = 1
#' )
#' }
#' @export
regsen_multi <- function(formula, data, treatments,
                         compare = NULL, fun = regsen_breakdown, ...) {
    stopifnot(is.data.frame(data))
    if (!is.character(treatments) || length(treatments) == 0) {
        stop("`treatments` must be a non-empty character vector.",
             call. = FALSE)
    }
    fun <- match.fun(fun)

    rhs <- attr(stats::terms(formula), "term.labels")
    lhs <- all.vars(formula)[1]
    missing_terms <- setdiff(treatments, rhs)
    if (length(missing_terms)) {
        stop("not on the right-hand side of `formula`: ",
             paste(missing_terms, collapse = ", "), call. = FALSE)
    }

    rows <- lapply(treatments, function(tr) {
        # Promote this treatment; everything else stays a control so the
        # specification is identical across rows.
        f_tr <- stats::reformulate(c(tr, setdiff(rhs, tr)), response = lhs)
        cmp <- if (is.null(compare)) NULL else setdiff(compare, tr)

        res <- tryCatch(
            fun(f_tr, data, compare = cmp, ...),
            error = function(e) e
        )
        if (inherits(res, "error")) {
            return(data.frame(treatment = tr, estimate = NA_real_,
                              breakdown = NA_real_, n = NA_integer_,
                              error = conditionMessage(res),
                              stringsAsFactors = FALSE))
        }

        bp <- res$breakdown
        if (is.null(bp) || length(bp) != 1) {
            bp <- if (!is.null(res$results$breakdown)) {
                res$results$breakdown[1]
            } else {
                NA_real_
            }
        }
        data.frame(
            treatment = tr,
            estimate  = if (!is.null(res$dgp$beta_med)) res$dgp$beta_med
                        else NA_real_,
            breakdown = abs(bp),
            n         = res$n,
            error     = NA_character_,
            stringsAsFactors = FALSE
        )
    })

    out <- do.call(rbind, rows)
    rownames(out) <- NULL
    # Drop the error column when nothing failed, so the common case is a
    # clean four-column table.
    if (all(is.na(out$error))) out$error <- NULL
    structure(out, class = c("regsensitivity_multi", "data.frame"))
}

#' @export
print.regsensitivity_multi <- function(x, ...) {
    cat("\nSensitivity across treatments\n")
    cat(strrep("-", 60), "\n", sep = "")
    df <- as.data.frame(x)
    num <- vapply(df, is.numeric, logical(1))
    df[num] <- lapply(df[num], function(v) formatC(v, format = "fg", digits = 4))
    print(df, row.names = FALSE)
    if (!is.null(x$error) && any(!is.na(x$error))) {
        cat("\n(", sum(!is.na(x$error)), " treatment(s) failed; see the ",
            "`error` column.)\n", sep = "")
    }
    invisible(x)
}

#' @rdname regsen_multi
#' @param x A `regsensitivity_multi` object.
#' @param base_size Base font size, passed to [theme_regsen()].
#' @export
plot.regsensitivity_multi <- function(x, base_size = 11, ...) {
    df <- as.data.frame(x)
    df <- df[is.finite(df$breakdown), , drop = FALSE]
    if (nrow(df) == 0) {
        stop("no finite breakdown points to plot.", call. = FALSE)
    }
    # Most fragile at the top: the ordering a reader wants first.
    df$treatment <- factor(df$treatment,
                           levels = df$treatment[order(df$breakdown)])

    ggplot2::ggplot(df, ggplot2::aes(x = .data$breakdown, y = .data$treatment)) +
        ggplot2::geom_segment(
            ggplot2::aes(x = 0, xend = .data$breakdown,
                         y = .data$treatment, yend = .data$treatment),
            colour = "grey70", linewidth = 0.4) +
        ggplot2::geom_point(size = 2.2, colour = okabe_ito[1]) +
        ggplot2::labs(x = "Breakdown point", y = NULL) +
        theme_regsen(base_size = base_size, grid = "x")
}
