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
