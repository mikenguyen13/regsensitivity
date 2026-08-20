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
#' @param xline Optional numeric vector of x-axis positions at which to draw
#'   reference lines, the equivalent of Stata's `xline()`. Useful for marking
#'   a value of `rmax`, a breakdown point, or any other threshold being
#'   discussed in the text.
#' @param xline_colour,xline_linetype,xline_linewidth Appearance of the
#'   `xline` reference lines.
#' @param title,subtitle,xtitle,ytitle Plot annotations. `NULL` uses defaults;
#'   `NA` drops the annotation entirely, which is usually what you want for a
#'   figure whose caption already carries the description.
#' @param base_size Base font size passed to [theme_regsen()]. Use `9` for a
#'   two-column journal figure rendered about 3.3 inches wide.
#' @param ... Ignored.
#'
#' @return A `ggplot` object. Because it is an ordinary ggplot, every default
#'   here can be overridden by adding scales, themes or annotations to it.
#'
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' \donttest{
#' data(bfg2020)
#' res <- regsen_bounds(
#'     avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
#'     data = bfg2020, compare = c("log_area_2010", "lat", "lon"),
#'     cbar = c(0.1, 0.5, 1)
#' )
#' plot(res, xline = 1, base_size = 9)
#' }
#' @importFrom rlang .data
#' @export
plot.regsensitivity <- function(x, ywidth = NULL, ylim = NULL,
                                 show_breakdown = TRUE, show_legend = TRUE,
                                 xline = NULL,
                                 xline_colour = "grey40",
                                 xline_linetype = "dashed",
                                 xline_linewidth = 0.35,
                                 title = NULL, subtitle = NULL,
                                 xtitle = NULL, ytitle = NULL,
                                 base_size = 11, ...) {
    if (x$subcommand == "bounds") {
        p <- plot_bounds(x, ywidth = ywidth, ylim = ylim,
                    show_breakdown = show_breakdown,
                    show_legend = show_legend,
                    title = title, subtitle = subtitle,
                    xtitle = xtitle, ytitle = ytitle,
                    base_size = base_size)
    } else if (x$subcommand == "breakdown") {
        p <- plot_breakdown(x,
                        title = title, subtitle = subtitle,
                        xtitle = xtitle, ytitle = ytitle,
                        base_size = base_size)
    } else {
        stop("don't know how to plot subcommand '", x$subcommand, "'",
             call. = FALSE)
    }

    if (!is.null(xline)) {
        xline <- as.numeric(xline)
        xline <- xline[is.finite(xline)]
        if (length(xline)) {
            p <- p + geom_vline(xintercept = xline,
                                 colour    = xline_colour,
                                 linetype  = xline_linetype,
                                 linewidth = xline_linewidth)
        }
    }
    p
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
                         xtitle = NULL, ytitle = NULL,
                         base_size = 11) {
    res <- x$results

    if (is.null(ylim)) ylim <- default_ylim(x, ywidth)

    # DMP analysis -- find which sparam varies and which is the grouping.
    if (x$analysis == "DMP (2026)") {
        nonscalar <- x$sparams$nonscalar
        primary <- nonscalar[1]
        secondary <- if (length(nonscalar) > 1) nonscalar[2] else NULL
        df <- res
        df$x_var <- df[[primary]]
        grp <- if (!is.null(secondary)) df[[secondary]] else NULL
        df$bmin_p <- offscreen_by(df$bmin, grp, ylim, "lower")
        df$bmax_p <- offscreen_by(df$bmax, grp, ylim, "upper")

        if (!is.null(secondary)) {
            df$group <- factor(df[[secondary]])
            p <- ggplot(df, aes(x = .data$x_var, group = .data$group,
                                  colour = .data$group, linetype = .data$group)) +
                geom_line(aes(y = .data$bmin_p), linewidth = 0.6, na.rm = TRUE) +
                geom_line(aes(y = .data$bmax_p), linewidth = 0.6, na.rm = TRUE)
            if (show_legend) {
                sec_lab <- sparam_label(secondary)
                p <- p + labs(colour = sec_lab, linetype = sec_lab)
            } else {
                p <- p + guides(colour = "none", linetype = "none")
            }
        } else {
            p <- ggplot(df, aes(x = .data$x_var)) +
                geom_line(aes(y = .data$bmin_p), linewidth = 0.6, na.rm = TRUE) +
                geom_line(aes(y = .data$bmax_p), linewidth = 0.6, na.rm = TRUE)
        }
    } else {
        # Oster.
        df <- res
        sp <- if ("delta" %in% names(df)) "delta" else colnames(df)[1]
        df$x_var <- df[[sp]]
        if (x$sparams$delta_type == "eq") {
            # Up to three solutions per delta: beta1, beta2, beta3. They are
            # ordered numerically, so a nominal branch can swap arms where a
            # root diverges; drawn as one line, that swap paints a false
            # vertical connector through the panel. Two exact facts locate
            # every swap: a true branch never crosses a vertical asymptote
            # of beta -> delta(beta), and the cubic's leading coefficient is
            # proportional to (delta - 1), so one root escapes to infinity
            # exactly at delta = 1, shifting the numeric ordering there.
            # Break a branch wherever a step straddles either. Each r2long
            # value is its own curve with its own asymptotes.
            r2s <- if ("r2long" %in% names(df)) df$r2long
                   else rep(x$sparams$r2long[1], nrow(df))
            long_list <- list()
            for (r2 in unique(r2s)) {
                sub <- df[r2s == r2, , drop = FALSE]
                sub <- sub[order(sub$x_var), , drop = FALSE]
                asym <- tryCatch(oster_delta_asymptotes(r2, x$dgp),
                                  error = function(e) numeric(0))
                for (k in 1:3) {
                    y <- sub[[paste0("beta", k)]]
                    keep <- is.finite(y)
                    yk <- y[keep]
                    if (length(yk) == 0) next
                    xk <- sub$x_var[keep]
                    cross <- rep(FALSE, max(0, length(yk) - 1))
                    for (a in asym) {
                        cross <- cross |
                            ((yk[-length(yk)] - a) * (yk[-1] - a) < 0)
                    }
                    if (length(yk) > 1) {
                        cross <- cross |
                            (xk[-length(xk)] <= 1 & xk[-1] > 1) |
                            (xk[-length(xk)] < 1 & xk[-1] >= 1)
                    }
                    long_list[[length(long_list) + 1]] <- data.frame(
                        x = xk, y = yk, r2long = r2,
                        branch = k, segment = cumsum(c(0, cross)))
                }
            }
            long <- do.call(rbind, long_list)
            long$y_p <- long$y
            grp <- interaction(long$r2long, long$branch, long$segment)
            if (length(unique(long$r2long)) > 1) {
                long$group_r2 <- factor(long$r2long)
                p <- ggplot(long, aes(x = .data$x, y = .data$y_p,
                                        group = grp,
                                        colour = .data$group_r2)) +
                    geom_line(linewidth = 0.6, na.rm = TRUE)
                if (show_legend) {
                    p <- p + labs(colour = sparam_label("r2long"))
                } else {
                    p <- p + guides(colour = "none")
                }
            } else {
                p <- ggplot(long, aes(x = .data$x, y = .data$y_p,
                                        group = grp)) +
                    geom_line(linewidth = 0.6, na.rm = TRUE)
            }
            primary <- "delta"
        } else {
            ogrp <- if (length(unique(df$r2long)) > 1) df$r2long else NULL
            df$bmin_p <- offscreen_by(df$bmin, ogrp, ylim, "lower")
            df$bmax_p <- offscreen_by(df$bmax, ogrp, ylim, "upper")
            if (length(unique(df$r2long)) > 1) {
                df$group <- factor(df$r2long)
                p <- ggplot(df, aes(x = .data$x_var, group = .data$group,
                                      colour = .data$group, linetype = .data$group)) +
                    geom_line(aes(y = .data$bmin_p), linewidth = 0.6, na.rm = TRUE) +
                    geom_line(aes(y = .data$bmax_p), linewidth = 0.6, na.rm = TRUE)
                if (show_legend) {
                    r2_lab <- sparam_label("r2long")
                    p <- p + labs(colour = r2_lab, linetype = r2_lab)
                } else {
                    p <- p + guides(colour = "none", linetype = "none")
                }
            } else {
                p <- ggplot(df, aes(x = .data$x_var)) +
                    geom_line(aes(y = .data$bmin_p), linewidth = 0.6, na.rm = TRUE) +
                    geom_line(aes(y = .data$bmax_p), linewidth = 0.6, na.rm = TRUE)
            }
            primary <- "delta"
        }
    }

    if (show_breakdown && !is.null(x$hypoval) &&
        length(x$hypoval) == 1 && !is.na(x$hypoval)) {
        p <- p + geom_hline(yintercept = x$hypoval,
                             colour = "grey40", linewidth = 0.35,
                             linetype = "dotted")
    }

    p <- p +
        coord_cartesian(ylim = ylim) +
        labs(
            title    = drop_na_label(title),
            subtitle = drop_na_label(subtitle),
            x        = axis_label(xtitle, sparam_label(primary)),
            y        = axis_label(ytitle, quote(beta[long]))
        ) +
        scale_colour_regsen() +
        theme_regsen(base_size = base_size)
    p
}

plot_breakdown <- function(x, title = NULL, subtitle = NULL,
                            xtitle = NULL, ytitle = NULL,
                            base_size = 11) {
    df <- x$results
    df$y <- abs(df$breakdown)
    df$y[is.infinite(df$y)] <- NA
    df$x <- df$index

    dmp <- x$analysis == "DMP (2026)"
    xdef <- if (dmp) sparam_label("cbar")  else sparam_label("r2long")
    ydef <- if (dmp) breakdown_label("rxbar") else breakdown_label("delta")

    p <- ggplot(df, aes(x = .data$x, y = .data$y)) +
        geom_line(linewidth = 0.6, na.rm = TRUE) +
        labs(
            title    = drop_na_label(title),
            subtitle = drop_na_label(subtitle),
            x        = axis_label(xtitle, xdef),
            y        = axis_label(ytitle, ydef)
        ) +
        theme_regsen(base_size = base_size)
    p
}


# An unbounded identified set must not be drawn as a flat line along the
# axis: that reads as "the bound levels off here", which is the opposite of
# what it means. Send non-finite bounds well past the panel so the line
# leaves the plot steeply, and let coord_cartesian() do the clipping --
# clamping finite values to the limits would flatten them the same way.
offscreen <- function(v, ylim, side) {
    pad <- diff(ylim)
    if (!is.finite(pad) || pad <= 0) pad <- 1
    target <- if (side == "lower") ylim[1] - pad else ylim[2] + pad

    out <- v
    bad <- !is.finite(v)
    if (!any(bad)) return(out)

    # Consumers pass na.rm = TRUE to the geoms: the NAs below are a
    # deliberate break in the line, not missing data, and the default
    # "Removed N rows" warning would otherwise fail a vignette build under
    # r-lib's error_on = "warning".
    #
    # Only the *first* point of each unbounded run is placed off-panel; the
    # rest become NA. Giving every point the same off-panel value drew a
    # straight segment between them, which coord_cartesian then clipped into
    # a horizontal line along the panel edge -- reintroducing the very
    # plateau this routing exists to avoid. One point is enough to make the
    # line leave the plot; the break afterwards says there is nothing to draw.
    starts <- bad & !c(FALSE, utils::head(bad, -1))
    out[bad] <- NA_real_
    out[starts] <- target
    out
}


# offscreen() detects the start of each unbounded run, so it must not see
# two series concatenated: a run that begins exactly at a group boundary
# would otherwise be mistaken for the continuation of the previous group's
# run and lose its exit point. Applying it per group keeps each series
# independent.
offscreen_by <- function(v, group, ylim, side) {
    if (is.null(group)) return(offscreen(v, ylim, side))
    out <- v
    for (g in unique(group)) {
        i <- which(group == g)
        out[i] <- offscreen(v[i], ylim, side)
    }
    out
}

# Small helper since R has no null-coalescing operator.
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a

# Annotations default to absent. A user-supplied string wins; NA is an
# explicit "no annotation", which matters for journal figures whose caption
# already says what the panel shows.
drop_na_label <- function(user) {
    if (is.null(user)) return(NULL)
    if (length(user) == 1 && is.na(user)) return(NULL)
    user
}

# Axis titles fall back to a plotmath expression. A user string always wins,
# and NA yields a blank title rather than the default.
axis_label <- function(user, default) {
    if (is.null(user)) return(default)
    if (length(user) == 1 && is.na(user)) return(NULL)
    user
}

#' Autoplot method
#'
#' `ggplot2::autoplot()` support, so a `regsensitivity` object can be drawn
#' by code that dispatches on `autoplot()` rather than `plot()`. It forwards
#' every argument to [plot.regsensitivity()].
#'
#' @param object A `regsensitivity` object.
#' @param ... Passed to [plot.regsensitivity()].
#' @return A `ggplot` object.
#' @examples
#' \donttest{
#' data(bfg2020)
#' res <- regsen_bounds(
#'     avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
#'     data = bfg2020, compare = c("log_area_2010", "lat", "lon"), cbar = 0.1
#' )
#' ggplot2::autoplot(res)
#' }
#' @importFrom ggplot2 autoplot
#' @exportS3Method ggplot2::autoplot
autoplot.regsensitivity <- function(object, ...) {
    plot.regsensitivity(object, ...)
}
