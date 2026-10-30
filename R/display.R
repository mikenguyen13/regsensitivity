## display.R --- console print/summary methods for regsensitivity objects.
##
## print() is the short answer: what was run, the breakdown point, and a
## thinned results table. summary() is the full record a referee asks for:
## the call, the specification, every sensitivity parameter, the summary
## statistics, and the whole results table with a column saying where the
## hypothesis holds.

#' Print and summarize a sensitivity analysis
#'
#' `print()` shows the headline: the analysis, the medium-regression
#' coefficient, the breakdown point and a thinned results table. `summary()`
#' returns an object whose print method adds the call, the control and
#' comparison sets, every sensitivity parameter, the summary statistics and
#' the full results table. For an identified-set sweep that table carries a
#' `holds` column, `TRUE` where the identified set lies entirely on the
#' hypothesis' side.
#'
#' @param x,object A `regsensitivity` object, or for the `print()` method
#'   of the summary, a `summary.regsensitivity` object.
#' @param max_rows Rows of the results table to show before thinning it to
#'   evenly spaced rows. `print()` defaults to 12, a summary to all of them.
#' @param ... Ignored.
#'
#' @return `print()` returns `x` invisibly. `summary()` returns an object of
#'   class `summary.regsensitivity`, a list holding `call`, `analysis`,
#'   `subcommand`, `outcome`, `treatment`, `n`, `controls`, `compare`,
#'   `hypothesis`, `sparams` (a data frame describing each sensitivity
#'   parameter), `statistics`, `breakdown` and `results`.
#'
#' @seealso [breakdown_point()], [identified_set()] and
#'   [as.data.frame.regsensitivity()] to extract the numbers.
#' @examples
#' data(bfg2020)
#' res <- regsen_bounds(
#'   avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
#'   data = bfg2020, compare = c("log_area_2010", "lat", "lon"), cbar = 0.1
#' )
#' res
#' summary(res)
#' @name regsensitivity-display
NULL

#' @rdname regsensitivity-display
#' @export
print.regsensitivity <- function(x, max_rows = 12, ...) {
    print_header(x)
    cat(sprintf("%-18s %s ~ %s\n", "Model:", x$depvar, x$indvar))
    cat(sprintf("%-18s %d\n", "N (obs):", x$n))
    cat(sprintf("%-18s %.4f\n", "Beta (medium):", x$dgp$beta_med))
    cat(sprintf("%-18s %s\n", "Hypothesis:", format_hypothesis(x)))
    print_breakdown_line(x)
    cat("\n")
    print_results_table(x$results, max_rows)
    cat("\nUse summary() for the specification and full results.\n")
    invisible(x)
}

print_header <- function(x) {
    cat("\nRegression Sensitivity Analysis -- ",
        if (x$subcommand == "bounds") "Bounds" else "Breakdown Frontier",
        " [", x$analysis, "]\n", sep = "")
    cat(strrep("-", 72), "\n", sep = "")
}

print_breakdown_line <- function(x) {
    bp <- x$breakdown
    if (!is.null(bp) && length(bp) == 1 && !is.na(bp)) {
        cat(sprintf("%-18s %s\n", "Breakdown point:", format_bp(abs(bp))))
    }
}

format_bp <- function(v) {
    ifelse(is.na(v), "NA",
           ifelse(v == Inf, "+Inf",
                  ifelse(v == -Inf, "-Inf", sprintf("%.4f", v))))
}

# Format a hypothesis row, e.g. "Beta > 0", "Beta != 0".
format_hypothesis <- function(x) {
    sign <- x$hyposign
    val  <- x$hypoval
    if (is.null(val) || (length(val) == 1 && is.na(val))) {
        return(sprintf("Beta %s Beta(Hypothesis)", sign))
    }
    op <- switch(sign, ">" = ">", "<" = "<", "=" = "!=", sign)
    sprintf("Beta %s %s", op, format(val))
}

# Print a results table, doing some light formatting (Inf as "+Inf",
# rounding sensitivity-parameter values) and thinning it to evenly spaced
# rows when it is longer than `max_rows`.
print_results_table <- function(r, max_rows = 12) {
    if (is.null(r) || nrow(r) == 0) {
        cat("  (no results)\n")
        return(invisible(NULL))
    }
    n <- nrow(r)
    if (is.finite(max_rows) && n > max_rows) {
        idx <- unique(round(seq(1, n, length.out = max_rows - 1)))
        r <- r[idx, , drop = FALSE]
        cat(sprintf("Results (%d of %d rows):\n", nrow(r), n))
    } else {
        cat("Results:\n")
    }
    for (j in seq_along(r)) {
        col <- r[[j]]
        if (is.numeric(col)) {
            r[[j]] <- ifelse(is.na(col), "",
                       ifelse(col == Inf, "+Inf",
                       ifelse(col == -Inf, "-Inf",
                              formatC(col, format = "fg", digits = 5))))
        }
    }
    print(r, row.names = FALSE)
}

# One row per sensitivity parameter: its name and either its value or the
# grid it was swept over.
describe_sparams <- function(sp) {
    keys <- c("rxbar", "rybar", "cbar", "clow", "delta", "r2long", "maxovb",
              "delta_type", "r2long_type", "maxovb_type", "direction")
    if (is.function(sp$rybar_expr)) sp$rybar <- "a function of rxbar"
    rows <- lapply(intersect(keys, names(sp)), function(k) {
        v <- sp[[k]]
        if (is.null(v)) return(NULL)
        desc <- if (is.character(v)) {
            v[1]
        } else if (length(unique(v)) == 1) {
            format_bp(v[1])
        } else {
            sprintf("%d values in [%s, %s]", length(v),
                    format_bp(min(v)), format_bp(max(v)))
        }
        data.frame(parameter = k, value = desc, stringsAsFactors = FALSE)
    })
    out <- do.call(rbind, rows)
    if (is.null(out)) {
        out <- data.frame(parameter = character(0), value = character(0))
    }
    out
}

# Whether the identified set in each row of a bounds table lies wholly on
# the hypothesis' side: TRUE where the conclusion holds at that point.
hypothesis_holds <- function(results, hyposign, hypoval) {
    if (!all(c("bmin", "bmax") %in% names(results)) ||
        length(hypoval) != 1 || is.na(hypoval)) {
        return(NULL)
    }
    switch(hyposign,
           ">" = results$bmin > hypoval,
           "<" = results$bmax < hypoval,
           "=" = results$bmin > hypoval | results$bmax < hypoval,
           NULL)
}

list_names <- function(v, max = 8) {
    if (length(v) == 0) return("(none)")
    shown <- paste(utils::head(v, max), collapse = ", ")
    if (length(v) > max) {
        shown <- paste0(shown, ", ... (", length(v) - max, " more)")
    }
    shown
}

#' @rdname regsensitivity-display
#' @export
summary.regsensitivity <- function(object, ...) {
    res <- object$results
    holds <- if (object$subcommand == "bounds" && !is.null(res)) {
        hypothesis_holds(res, object$hyposign, object$hypoval)
    }
    if (!is.null(holds)) res$holds <- holds
    if (object$subcommand == "breakdown" && !is.null(res) &&
        !is.null(object$varying) && "index" %in% names(res)) {
        names(res)[names(res) == "index"] <- object$varying
    }
    structure(
        list(
            call = object$call,
            analysis = object$analysis,
            subcommand = object$subcommand,
            outcome = object$depvar,
            treatment = object$indvar,
            n = object$n,
            controls = object$controls,
            compare = object$compare,
            hypothesis = format_hypothesis(object),
            sparams = describe_sparams(object$sparams),
            statistics = object$summary_stats,
            breakdown = object$breakdown,
            results = res
        ),
        class = "summary.regsensitivity"
    )
}

#' @rdname regsensitivity-display
#' @export
print.summary.regsensitivity <- function(x, max_rows = Inf, ...) {
    print_header(x)
    if (!is.null(x$call)) {
        cat("Call:\n  ", paste(deparse(x$call, width.cutoff = 68),
                               collapse = "\n  "), "\n\n", sep = "")
    }
    cat("--- Specification ---------------------------------------\n")
    cat(sprintf("  %-20s %s\n", "Outcome:", x$outcome))
    cat(sprintf("  %-20s %s\n", "Treatment:", x$treatment))
    cat(sprintf("  %-20s %d\n", "N (obs):", x$n))
    cat(sprintf("  %-20s %s\n", "Controls:", list_names(x$controls)))
    cat(sprintf("  %-20s %s\n", "Comparison set:", list_names(x$compare)))
    cat(sprintf("  %-20s %s\n", "Hypothesis:", x$hypothesis))

    cat("\n--- Sensitivity parameters ------------------------------\n")
    for (i in seq_len(nrow(x$sparams))) {
        cat(sprintf("  %-20s %s\n", x$sparams$parameter[i], x$sparams$value[i]))
    }

    cat("\n--- Summary statistics ----------------------------------\n")
    ss <- x$statistics
    for (i in seq_len(nrow(ss))) {
        cat(sprintf("  %-20s %12.4f\n", ss$statistic[i], ss$value[i]))
    }

    cat("\n--- Results ---------------------------------------------\n")
    bp <- x$breakdown
    if (!is.null(bp) && length(bp) == 1 && !is.na(bp)) {
        cat(sprintf("  %-20s %s\n", "Breakdown point:", format_bp(abs(bp))))
    }
    r <- x$results
    if (!is.null(r$holds)) {
        cat(sprintf("  %-20s %d of %d grid points\n", "Hypothesis holds at:",
                    sum(r$holds, na.rm = TRUE), nrow(r)))
    }
    if (!is.null(r$breakdown)) {
        fin <- r$breakdown[is.finite(r$breakdown)]
        if (length(fin)) {
            cat(sprintf("  %-20s [%.4f, %.4f]\n", "Breakdown range:",
                        min(abs(fin)), max(abs(fin))))
        }
        if (any(is.infinite(r$breakdown))) {
            cat(sprintf("  %-20s %d of %d values\n", "Never breaks down:",
                        sum(is.infinite(r$breakdown)), nrow(r)))
        }
    }
    cat("\n")
    print_results_table(r, max_rows)
    invisible(x)
}

#' @rdname regsen_summary
#' @param x,object A `regsensitivity_summary` object, or for the `print()`
#'   method of its summary, a `summary.regsensitivity_summary` object.
#' @param ... Passed to the methods for the two component analyses.
#' @export
print.regsensitivity_summary <- function(x, ...) {
    cat("\n=== DMP (2026) bounds ===\n")
    print(x$dmp_bounds, ...)
    cat("\n=== Oster (2019) breakdown ===\n")
    print(x$oster_breakdown, ...)
    invisible(x)
}

#' @rdname regsen_summary
#' @export
summary.regsensitivity_summary <- function(object, ...) {
    structure(
        list(dmp_bounds = summary(object$dmp_bounds),
             oster_breakdown = summary(object$oster_breakdown)),
        class = "summary.regsensitivity_summary"
    )
}

#' @rdname regsen_summary
#' @export
print.summary.regsensitivity_summary <- function(x, ...) {
    cat("\n=== DMP (2026) bounds ===\n")
    print(x$dmp_bounds, ...)
    cat("\n=== Oster (2019) breakdown ===\n")
    print(x$oster_breakdown, ...)
    invisible(x)
}
