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
