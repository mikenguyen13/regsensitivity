test_that("regsensitivity() dispatcher routes to subcommand functions", {
    a <- regsensitivity("bounds", bfg_formula(), bfg(),
                         compare = bfg_compare(), cbar = 0.1)
    b <- regsen_bounds(bfg_formula(), bfg(),
                       compare = bfg_compare(), cbar = 0.1)
    expect_equal(a$results, b$results)
})

test_that("parse_beta handles defaults, numeric, sign forms", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    h1 <- regsensitivity:::parse_beta("sign", dgp)
    expect_equal(h1$sign, ">")     # beta_med > 0
    expect_equal(h1$value, 0)

    h2 <- regsensitivity:::parse_beta(bnd_ub(4), dgp)
    expect_equal(h2$sign, "<")
    expect_equal(as.numeric(h2$value), 4)

    h3 <- regsensitivity:::parse_beta(bnd_eq(0), dgp)
    expect_equal(h3$sign, "=")
})

test_that("regsen_breakdown over cbar grid is monotone decreasing", {
    r <- regsen_breakdown(bfg_formula(), bfg(),
                           compare = bfg_compare(),
                           cbar = seq(0, 1, 0.1))
    bd <- r$results$breakdown
    # accept tiny non-monotonicities from bisection tolerance
    expect_true(all(diff(bd) <= 1e-3))
})

test_that("compare and nocompare partitions match", {
    a <- regsen_bounds(bfg_formula(), bfg(),
                       compare = bfg_compare(), cbar = 0.5)
    b <- regsen_bounds(bfg_formula(), bfg(),
                       nocompare = "statea", cbar = 0.5)
    expect_equal(a$compare, b$compare)
    expect_equal(a$results$bmin, b$results$bmin, tolerance = 1e-10)
})

test_that("regsen_summary returns DMP bounds + Oster breakdown", {
    s <- regsen_summary(bfg_formula(), bfg(), compare = bfg_compare())
    expect_s3_class(s, "regsensitivity_summary")
    expect_s3_class(s$dmp_bounds, "regsensitivity")
    expect_s3_class(s$oster_breakdown, "regsensitivity")
})

test_that("subset filters rows before estimation", {
    full <- regsen_bounds(bfg_formula(), bfg(),
                           compare = bfg_compare(), cbar = 0.5)
    half <- regsen_bounds(bfg_formula(), bfg(),
                           compare = bfg_compare(), cbar = 0.5,
                           subset = seq_len(nrow(bfg())) %% 2 == 0)
    expect_lt(half$n, full$n)
})
