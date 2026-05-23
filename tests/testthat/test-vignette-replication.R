## Regression-test the package against the values one expects from the
## Stata vignette demo (Diegert, Masten, Poirier 2026 -- BFG2020 application).
## The Stata vignette references a number of specific numerical values, like
## the Oster-equality asymptote at -1.704; we test against those.

test_that("Oster delta(beta) asymptote is finite and located at a polynomial root", {
    # `oster_delta_asymptotes` finds the values of beta_long at which the
    # delta(beta) function diverges (the denominator of the cubic-in-bias
    # vanishes). We test that the returned roots make the denominator near
    # zero, rather than hard-coding a specific x-axis value from the Stata
    # vignette (the `xline()` values there are user-set visual references).
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    roots <- regsensitivity:::oster_delta_asymptotes(1, dgp)
    expect_true(length(roots) >= 1)
    for (rt in roots) {
        # Plug `bm - rt` (the original-polynomial root) back in.
        u <- dgp$beta_med - rt
        bm <- dgp$beta_med; bs <- dgp$beta_short
        vxr <- dgp$var_x_resid; vx <- dgp$var_x; vy <- dgp$var_y
        val <- (1 - dgp$r_med) * vy * (bs - bm) * vx +
               u * (1 - dgp$r_med) * vy * (vx - vxr) +
               u^2 * vxr * (bs - bm) * vx +
               u^3 * (vxr * vx - vxr^2)
        expect_lt(abs(val), 1e-6)
    }
})

test_that("Oster sign-change breakdown is finite and > 0", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    bd <- regsensitivity:::oster_breakdown_bound(
        r2max = 1, beta = 0, maxovb = NA_real_,
        hyposign = ">", s = dgp)
    expect_true(is.finite(bd$breakdown))
    expect_gt(bd$breakdown, 0)
})

test_that("DMP breakdown at cbar=0.1, rybar=Inf is ~1.19 (vignette step 4)", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = 0.1)
    expect_equal(res$breakdown, 1.19, tolerance = 0.02)
})

test_that("rxbar at which idset becomes (-inf, inf) for cbar=0.1 is ~4.08", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    rmax <- regsensitivity:::max_beta_bound(0.1, dgp)
    expect_equal(rmax, 4.08, tolerance = 0.02)
})

test_that("rxbar at which idset becomes (-inf, inf) for cbar=1 is ~0.99", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    rmax <- regsensitivity:::max_beta_bound(1, dgp)
    expect_equal(rmax, 0.989, tolerance = 0.02)
})

test_that("rybar = rxbar option produces a valid breakdown frontier", {
    res <- regsen_breakdown(bfg_formula(), bfg(),
                             compare = bfg_compare(),
                             cbar = c(0, 0.5, 1.0),
                             rybar_expr = function(rx) rx)
    expect_equal(nrow(res$results), 3L)
    expect_true(all(res$results$breakdown >= 0))
})

test_that("Oster delta sign change (sign hypothesis) breakdown is positive", {
    res <- regsen_breakdown(bfg_formula(), bfg(),
                             compare = bfg_compare(),
                             analysis = "oster",
                             r2long = seq(0.1, 1, 0.1),
                             r2long_type = "eq")
    # All breakdown points should be non-negative
    expect_true(all(res$results$breakdown >= 0 |
                     is.infinite(res$results$breakdown)))
})

test_that("Oster maxovb constraint reduces the breakdown set", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    # Unconstrained
    a <- regsensitivity:::oster_breakdown_bound(
        r2max = 1, beta = 0, maxovb = NA_real_, hyposign = ">", s = dgp)
    # With a very tight OVB bound, breakdown is +Inf when beta is unreachable.
    b <- regsensitivity:::oster_breakdown_bound(
        r2max = 1, beta = 0,
        maxovb = abs(dgp$beta_med) * 0.5, hyposign = ">", s = dgp)
    expect_true(is.infinite(b$breakdown) || b$breakdown >= a$breakdown)
})
