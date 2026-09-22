test_that("plot.regsensitivity produces a ggplot for bounds", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(),
                          cbar = c(0.1, 0.5, 1.0))
    p <- plot(res)
    expect_s3_class(p, "ggplot")
})

test_that("plot.regsensitivity produces a ggplot for breakdown", {
    res <- regsen_breakdown(bfg_formula(), bfg(),
                             compare = bfg_compare(),
                             cbar = seq(0, 1, 0.2))
    p <- plot(res)
    expect_s3_class(p, "ggplot")
})

test_that("plot for Oster equality has three-branch geoms", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(),
                          analysis = "oster",
                          delta = seq(-1, 1, 0.1))
    p <- plot(res, ylim = c(-5, 5))
    expect_s3_class(p, "ggplot")
})

test_that("Oster equality branches are continuous curves, not sort order", {
    # Up to three roots per delta come back sorted within each delta, so the
    # root continuing a given branch moves between the beta1/beta2/beta3
    # columns wherever a fold adds two roots or one escapes. Drawing a column
    # as a line cut continuous branches and joined unrelated ones; the plot
    # groups by which interval between the poles of delta(beta) a root falls
    # in instead, and walks each interval in increasing beta.
    #
    # One control covariate puts the only real root of the denominator on the
    # spurious root, where the numerator vanishes too -- a hole, not a pole --
    # so the whole picture is a single branch.
    set.seed(2208)
    n <- 2000
    w1 <- rnorm(n); w2 <- rnorm(n)
    x <- 0.3 * w1 + 0.5 * w2 + rnorm(n)
    y <- 0.8 * x + 0.4 * w1 + 0.6 * w2 + rnorm(n)
    d <- data.frame(y = y, x = x, w1 = w1)

    res <- regsen_bounds(y ~ x + w1, d, analysis = "oster",
                          delta = seq(-2, 2, 0.02), r2long = 1)
    p <- plot(res, ylim = c(-2, 4))

    # A branch that folds is not a function of delta, so it has to be drawn
    # in data order: geom_line() would re-sort it by delta and saw the fold
    # into vertical spikes.
    expect_identical(unname(vapply(p$layers, function(l) class(l$geom)[1], "")),
                     c("GeomPath", "GeomHline"))

    dat <- ggplot2::layer_data(p, 1)
    expect_equal(length(unique(dat$group)), 1L)

    # beta increases monotonically along the path, and inside the panel no
    # step spans an appreciable part of it. The largest legitimate step is
    # the near-vertical turn at the fold (about 1.0 of a 6-unit panel), where
    # the delta grid is coarse relative to how fast beta moves; the
    # sort-order grouping instead put a connector of nearly 28 -- more than
    # four panel heights -- through the figure.
    yy <- dat$y
    expect_true(all(diff(yy) > 0))
    inside <- yy >= -2 & yy <= 4
    expect_gt(sum(inside), 100)
    expect_lt(max(abs(diff(yy[inside]))), 1.5)

    # The spurious root sits exactly on the denominator's root and solves the
    # cubic at every delta; it must not appear in the identified set.
    hole <- res$dgp$beta_med + res$dgp$gamma_med / res$dgp$pi_med
    betas <- unlist(res$results[, c("beta1", "beta2", "beta3")])
    expect_false(any(abs(betas - hole) < 1e-8, na.rm = TRUE))
})

test_that("print method runs without error", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = 0.1)
    expect_output(print(res), "Regression Sensitivity Analysis")
    expect_output(print(res), "Breakdown point")
})

test_that("xline adds vertical reference lines (Stata's xline())", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = 0.1)
    geoms <- function(p) vapply(p$layers, function(l) class(l$geom)[1], "")

    expect_false("GeomVline" %in% geoms(plot(res)))
    expect_true("GeomVline" %in% geoms(plot(res, xline = 1)))

    # Several lines at once, and non-finite values are dropped rather than
    # erroring, so xline = c(1, Inf) still plots the finite one.
    p <- plot(res, xline = c(0.5, 1, Inf))
    expect_true("GeomVline" %in% geoms(p))
})

test_that("breakdown plots accept xline as well", {
    res <- regsen_breakdown(bfg_formula(), bfg(),
                             compare = bfg_compare(), cbar = seq(0, 1, 0.5))
    p <- plot(res, xline = 0.5)
    expect_true("GeomVline" %in%
                    vapply(p$layers, function(l) class(l$geom)[1], ""))
})

test_that("NA annotations drop the label rather than printing 'NA'", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = 0.1)
    p <- plot(res, subtitle = NA, xtitle = NA)
    expect_null(p$labels$subtitle)
    expect_null(p$labels$x)
})

test_that("theme_regsen and the colour scale are usable on their own", {
    expect_s3_class(theme_regsen(), "theme")
    expect_s3_class(theme_regsen(base_size = 9, grid = "none"), "theme")
    expect_s3_class(scale_colour_regsen(), "ScaleDiscrete")
})

test_that("unbounded identified sets leave the panel instead of flattening", {
    # Clamping bounds to the y-limits drew a flat line along the axis, which
    # reads as "the bound levels off here" -- the opposite of unbounded.
    ylim <- c(-10, 10)
    v <- c(1, Inf, -Inf, NA)
    lo <- regsensitivity:::offscreen(v, ylim, "lower")
    hi <- regsensitivity:::offscreen(v, ylim, "upper")

    expect_equal(lo[1], 1)
    # Only the first point of an unbounded run goes off-panel; the rest are
    # NA. Sending every point to the same off-panel value drew a straight
    # segment between them, which the coord then clipped into a line along
    # the panel edge -- the plateau this routing exists to prevent.
    expect_true(lo[2] < ylim[1])
    expect_true(hi[2] > ylim[2])
    expect_true(all(is.na(lo[3:4])))
    expect_true(all(is.na(hi[3:4])))

    # A degenerate range must not produce NaN padding.
    expect_true(is.finite(regsensitivity:::offscreen(Inf, c(0, 0), "upper")))

    # A run restarting after finite values gets its own exit point.
    expect_equal(regsensitivity:::offscreen(c(1, Inf, 2, Inf, Inf), c(-10, 10),
                                            "upper")[c(2, 4, 5)],
                 c(30, 30, NA))

    # Grouped series are handled independently, so a run beginning exactly
    # at a group boundary still gets an exit point.
    expect_equal(regsensitivity:::offscreen_by(c(1, Inf, Inf, 2),
                                               c("a", "a", "b", "b"),
                                               c(-10, 10), "upper"),
                 c(1, 30, 30, 2))
})

test_that("theme_regsen defaults to no grid, as econ journals expect", {
    th <- theme_regsen()
    expect_s3_class(th$panel.grid.major, "element_blank")
    expect_s3_class(th$panel.border, "element_blank")
    # Opting back in still works.
    expect_false(inherits(theme_regsen(grid = "y")$panel.grid.major.y,
                          "element_blank"))
})
