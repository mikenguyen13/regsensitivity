## theme.R --- publication defaults for regsensitivity plots.

#' Publication-ready theme for sensitivity plots
#'
#' A \pkg{ggplot2} theme tuned for figures that will be dropped into a paper.
#' It follows the conventions of the economics journals: an L of axis lines
#' rather than a box, no grid, ticks outside the panel, no figure title (the
#' caption carries it), and a legend along the top so the plot region keeps
#' its aspect ratio when the figure is scaled down to one column.
#'
#' To match a LaTeX manuscript's body type, pass a serif family, e.g.
#' `theme_regsen(base_family = "Times New Roman")`. Fonts are left to the
#' caller because what is installed varies by machine, and a missing family
#' would make figures unreproducible.
#'
#' The default `base_size` of 11 assumes a figure rendered at roughly
#' 6 inches wide. For a two-column journal figure, render at 3.3 inches and
#' pass `base_size = 9`; the type will then sit at about 8pt on the page.
#'
#' @param base_size Base font size in points.
#' @param base_family Base font family. The empty string uses the device
#'   default, which keeps figures reproducible across machines.
#' @param grid One of `"none"` (default), `"y"`, `"x"` or `"both"`, choosing
#'   which faint grid lines to draw. The default is none, following the
#'   economics journals: a figure should carry ink only where it carries
#'   data. Use `"y"` when readers need to take values off the axis.
#' @param legend_position Passed to [ggplot2::theme()]. Defaults to `"top"`.
#'
#' @return A \pkg{ggplot2} theme object, which can be added to any plot.
#'
#' @examples
#' \donttest{
#' data(bfg2020)
#' res <- regsen_bounds(
#'     avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
#'     data = bfg2020, compare = c("log_area_2010", "lat", "lon"), cbar = 0.1
#' )
#' plot(res) + theme_regsen(base_size = 9)
#' }
#' @export
theme_regsen <- function(base_size = 11, base_family = "",
                         grid = c("none", "y", "x", "both"),
                         legend_position = "top") {
    grid <- match.arg(grid)
    gridline <- ggplot2::element_line(colour = "grey92", linewidth = 0.3)

    th <- ggplot2::theme_bw(base_size = base_size, base_family = base_family) +
        ggplot2::theme(
            # An L of axis lines rather than a full box, and no grid: the
            # house style of AER, QJE, Econometrica and the rest, where a
            # figure is expected to carry ink only where it carries data.
            panel.border     = ggplot2::element_blank(),
            axis.line        = ggplot2::element_line(colour = "black",
                                                     linewidth = 0.4),
            panel.grid.minor = ggplot2::element_blank(),
            panel.grid.major = ggplot2::element_blank(),
            axis.ticks       = ggplot2::element_line(colour = "black",
                                                     linewidth = 0.4),
            axis.ticks.length = grid::unit(3.5, "pt"),
            axis.text        = ggplot2::element_text(colour = "black"),
            axis.title       = ggplot2::element_text(size = ggplot2::rel(1.0)),
            plot.title       = ggplot2::element_text(size = ggplot2::rel(1.05),
                                                     face = "bold",
                                                     hjust = 0),
            plot.subtitle    = ggplot2::element_text(size = ggplot2::rel(0.9),
                                                     colour = "grey30",
                                                     hjust = 0),
            plot.caption     = ggplot2::element_text(size = ggplot2::rel(0.8),
                                                     colour = "grey30",
                                                     hjust = 0),
            plot.title.position   = "plot",
            plot.caption.position = "plot",
            legend.position  = legend_position,
            legend.title     = ggplot2::element_text(size = ggplot2::rel(0.9)),
            legend.key       = ggplot2::element_blank(),
            legend.background = ggplot2::element_blank(),
            strip.background = ggplot2::element_blank(),
            plot.margin      = ggplot2::margin(6, 10, 6, 6)
        )

    if (grid %in% c("y", "both")) {
        th <- th + ggplot2::theme(panel.grid.major.y = gridline)
    }
    if (grid %in% c("x", "both")) {
        th <- th + ggplot2::theme(panel.grid.major.x = gridline)
    }
    th
}

# Okabe-Ito, the standard colourblind-safe qualitative palette. Black is
# dropped so a single-series plot keeps its own black line and grouped
# series stay distinguishable from it.
okabe_ito <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7",
               "#E69F00", "#56B4E9", "#F0E442", "#999999")

#' Colourblind-safe scales for sensitivity plots
#'
#' Discrete colour and fill scales using the Okabe-Ito palette, which stays
#' legible under the common forms of colour vision deficiency and survives
#' greyscale printing. These are applied by default in
#' [plot.regsensitivity()]; they are exported so a plot can be rebuilt with
#' the same colours.
#'
#' @param ... Passed to [ggplot2::discrete_scale()].
#' @return A \pkg{ggplot2} scale.
#' @export
scale_colour_regsen <- function(...) {
    ggplot2::scale_colour_manual(values = okabe_ito, ...)
}

#' @rdname scale_colour_regsen
#' @export
scale_color_regsen <- scale_colour_regsen

#' @rdname scale_colour_regsen
#' @export
scale_fill_regsen <- function(...) {
    ggplot2::scale_fill_manual(values = okabe_ito, ...)
}

# Plotmath labels for the sensitivity parameters. Falls back to the raw
# name so an unrecognised parameter still gets a sensible axis title.
sparam_label <- function(name) {
    switch(as.character(name),
        "rxbar"  = quote(bar(r)[x]),
        "rybar"  = quote(bar(r)[y]),
        "cbar"   = quote(bar(c)),
        "delta"  = quote(delta),
        "r2long" = quote(R^2 * " (long)"),
        "maxovb" = quote("max OVB"),
        "beta"   = quote(beta),
        name
    )
}

# As above, but for a breakdown frontier's y-axis, which reports the
# breakdown *point* of the named parameter.
breakdown_label <- function(name) {
    lab <- sparam_label(name)
    if (is.character(lab)) return(paste(lab, "(breakdown)"))
    bquote(.(lab) ~ "(breakdown point)")
}
