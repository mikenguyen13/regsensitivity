## plot.R --- ggplot2 plotting for regsensitivity objects.

#' @import ggplot2
NULL

#' Plot a regression sensitivity analysis
#'
#' Produces a ggplot object visualizing either an identified-set sweep (from
#' [regsen_bounds()]) or a breakdown frontier (from [regsen_breakdown()]).
#'
#' @param x A `regsensitivity` object.
#' @param ywidth Half-width of the y-axis in standard deviations of X.
#'   Ignored when `ylim` is set.
#' @param ylim Optional two-element numeric vector giving the y-axis limits.
#' @param show_breakdown Logical; draw a horizontal line at the hypothesis
#'   value. Defaults to `TRUE`.
#' @param show_legend Logical; show the legend (only relevant when plotting
#'   bounds with multiple values of a second sensitivity parameter).
#' @param title,subtitle,xtitle,ytitle Plot annotations. `NULL` uses defaults.
#' @param ... Ignored.
#'
#' @return A `ggplot` object.
#' @importFrom rlang .data
#' @export
plot.regsensitivity <- function(x, ywidth = NULL, ylim = NULL,
                                 show_breakdown = TRUE, show_legend = TRUE,
                                 title = NULL, subtitle = NULL,
                                 xtitle = NULL, ytitle = NULL, ...) {
    if (x$subcommand == "bounds") {
        plot_bounds(x, ywidth = ywidth, ylim = ylim,
                    show_breakdown = show_breakdown,
                    show_legend = show_legend,
                    title = title, subtitle = subtitle,
                    xtitle = xtitle, ytitle = ytitle)
    } else if (x$subcommand == "breakdown") {
        plot_breakdown(x,
                        title = title, subtitle = subtitle,
                        xtitle = xtitle, ytitle = ytitle)
    } else {
        stop("don't know how to plot subcommand '", x$subcommand, "'",
             call. = FALSE)
    }
}

# Pick a reasonable y-range for an identified-set plot.
default_ylim <- function(x, ywidth = NULL) {
    bmin <- x$results$bmin
    bmax <- x$results$bmax
    fin <- bmin[is.finite(bmin)]
    bmed <- x$dgp$beta_med
    sdx <- sqrt(x$dgp$var_x)
    if (is.null(ywidth)) {
        # Stata: 95th percentile of |bmin - beta_med|/sd(X), plus 0.1.
        if (length(fin) == 0) {
            ywidth <- 1
        } else {
            ywidth <- stats::quantile(abs(fin - bmed) / sdx, 0.95,
                                       na.rm = TRUE) + 0.1
        }
    }
    c(bmed - sdx * ywidth, bmed + sdx * ywidth)
}

plot_bounds <- function(x, ywidth = NULL, ylim = NULL,
                         show_breakdown = TRUE, show_legend = TRUE,
                         title = NULL, subtitle = NULL,
                         xtitle = NULL, ytitle = NULL) {
    res <- x$results

    if (is.null(ylim)) ylim <- default_ylim(x, ywidth)

    # DMP analysis -- find which sparam varies and which is the grouping.
    if (x$analysis == "DMP (2026)") {
        nonscalar <- x$sparams$nonscalar
        primary <- nonscalar[1]
        secondary <- if (length(nonscalar) > 1) nonscalar[2] else NULL
        df <- res
        df$bmin_p <- pmax(pmin(df$bmin, ylim[2]), ylim[1])
        df$bmax_p <- pmax(pmin(df$bmax, ylim[2]), ylim[1])
        df$x_var <- df[[primary]]

        if (!is.null(secondary)) {
            df$group <- factor(df[[secondary]])
            p <- ggplot(df, aes(x = .data$x_var, group = .data$group,
                                  colour = .data$group, linetype = .data$group)) +
                geom_line(aes(y = .data$bmin_p)) +
                geom_line(aes(y = .data$bmax_p))
            if (show_legend) {
                p <- p + labs(colour = secondary, linetype = secondary)
            } else {
                p <- p + guides(colour = "none", linetype = "none")
            }
        } else {
            p <- ggplot(df, aes(x = .data$x_var)) +
                geom_line(aes(y = .data$bmin_p)) +
                geom_line(aes(y = .data$bmax_p))
        }
    } else {
        # Oster.
        df <- res
        sp <- if ("delta" %in% names(df)) "delta" else colnames(df)[1]
        df$x_var <- df[[sp]]
        if (x$sparams$delta_type == "eq") {
            # Up to three solutions: beta1, beta2, beta3.
            long <- rbind(
                data.frame(x = df$x_var, y = df$beta1, branch = 1),
                data.frame(x = df$x_var, y = df$beta2, branch = 2),
                data.frame(x = df$x_var, y = df$beta3, branch = 3)
            )
            long <- long[is.finite(long$y), , drop = FALSE]
            long$y_p <- pmax(pmin(long$y, ylim[2]), ylim[1])
            p <- ggplot(long, aes(x = .data$x, y = .data$y_p,
                                    group = factor(.data$branch))) +
                geom_line()
            primary <- "Delta"
        } else {
            df$bmin_p <- pmax(pmin(df$bmin, ylim[2]), ylim[1])
            df$bmax_p <- pmax(pmin(df$bmax, ylim[2]), ylim[1])
            if (length(unique(df$r2long)) > 1) {
                df$group <- factor(df$r2long)
                p <- ggplot(df, aes(x = .data$x_var, group = .data$group,
                                      colour = .data$group, linetype = .data$group)) +
                    geom_line(aes(y = .data$bmin_p)) +
                    geom_line(aes(y = .data$bmax_p))
                if (show_legend) {
                    p <- p + labs(colour = "R-squared(long)",
                                   linetype = "R-squared(long)")
                } else {
                    p <- p + guides(colour = "none", linetype = "none")
                }
            } else {
                p <- ggplot(df, aes(x = .data$x_var)) +
                    geom_line(aes(y = .data$bmin_p)) +
                    geom_line(aes(y = .data$bmax_p))
            }
            primary <- "Delta"
        }
    }

    if (show_breakdown && !is.null(x$hypoval) &&
        length(x$hypoval) == 1 && !is.na(x$hypoval)) {
        p <- p + geom_hline(yintercept = x$hypoval,
                             colour = "black", linewidth = 0.3)
    }

    p <- p +
        coord_cartesian(ylim = ylim) +
        labs(
            title = title %||% NULL,
            subtitle = subtitle %||% paste(
                "Regression Sensitivity Analysis (",
                x$analysis, "), Bounds",
                sep = ""),
            x = xtitle %||% primary,
            y = ytitle %||% "Beta"
        ) +
        theme_bw() +
        theme(panel.grid = element_blank())
    p
}

plot_breakdown <- function(x, title = NULL, subtitle = NULL,
                            xtitle = NULL, ytitle = NULL) {
    df <- x$results
    df$y <- abs(df$breakdown)
    df$y[is.infinite(df$y)] <- NA
    df$x <- df$index

    xlab <- xtitle %||% if (x$analysis == "DMP (2026)") "cbar" else "R-squared(long)"
    ylab <- ytitle %||% if (x$analysis == "DMP (2026)") "rxbar (breakdown)" else "Delta (breakdown)"

    p <- ggplot(df, aes(x = .data$x, y = .data$y)) +
        geom_line() +
        labs(
            title = title %||% NULL,
            subtitle = subtitle %||% paste(
                "Regression Sensitivity Analysis (",
                x$analysis, "), Breakdown",
                sep = ""),
            x = xlab, y = ylab
        ) +
        theme_bw() +
        theme(panel.grid = element_blank())
    p
}

# Small helper since R has no null-coalescing operator.
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a
