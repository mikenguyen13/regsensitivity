## display.R --- console print/summary methods for regsensitivity objects.

#' @export
print.regsensitivity <- function(x, ...) {
    cat("\nRegression Sensitivity Analysis ----- ",
        if (x$subcommand == "bounds") "Bounds" else "Breakdown Frontier",
        "\n", sep = "")
    cat(strrep("-", 72), "\n", sep = "")

    cat(sprintf("%-18s %s\n", "Analysis:",     x$analysis))
    cat(sprintf("%-18s %s\n", "Treatment:",    x$indvar))
    cat(sprintf("%-18s %s\n", "Outcome:",      x$depvar))
    cat(sprintf("%-18s %d\n", "N (obs):",      x$n))
    cat(sprintf("%-18s %s\n", "Hypothesis:",   format_hypothesis(x)))
    if (!is.null(x$breakdown) && length(x$breakdown) == 1 &&
        !is.na(x$breakdown)) {
        bp <- abs(x$breakdown)
        if (is.finite(bp)) {
            cat(sprintf("%-18s %.4f\n", "Breakdown point:", bp))
        } else {
            cat(sprintf("%-18s %s\n", "Breakdown point:", "+Inf"))
        }
    }
    cat("\n--- Summary statistics ----------------------------------\n")
    ss <- x$summary_stats
    for (i in seq_len(nrow(ss))) {
        cat(sprintf("  %-22s  %12.4f\n", ss$statistic[i], ss$value[i]))
    }
    cat("\n--- Results ---------------------------------------------\n")
    print_results_table(x)
    invisible(x)
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

# Print the results table, doing some light formatting (Inf as "+inf",
# rounding sensitivity-parameter values).
print_results_table <- function(x) {
    r <- x$results
    if (is.null(r) || nrow(r) == 0) {
        cat("  (no results)\n")
        return(invisible(NULL))
    }
    # Down-sample to ~10 rows for the console.
    n <- nrow(r)
    if (n > 12) {
        idx <- unique(c(1, round(seq(1, n, length.out = 11))))
        r <- r[idx, , drop = FALSE]
    }
    # Format Inf / NA as +/- inf.
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

#' @export
summary.regsensitivity <- function(object, ...) {
    structure(
        list(
            object = object,
            sumstats = object$summary_stats,
            results = object$results,
            breakdown = object$breakdown,
            hyposign = object$hyposign,
            hypoval = object$hypoval
        ),
        class = "summary.regsensitivity"
    )
}

#' @export
print.summary.regsensitivity <- function(x, ...) {
    print(x$object)
    invisible(x)
}

#' @export
print.regsensitivity_summary <- function(x, ...) {
    cat("\n=== DMP (2026) bounds ===\n")
    print(x$dmp_bounds)
    cat("\n=== Oster (2019) breakdown ===\n")
    print(x$oster_breakdown)
    invisible(x)
}
