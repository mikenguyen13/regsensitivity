## Regression tests for the v0.1.0 Windows-only NA bug.
##
## Setup: on Windows, nloptr's DIRECT-L explores parameter points where
## `varx_bounds()` returns (NA, NA) (because the radicand goes slightly
## negative due to floating-point rounding). That NA propagated into
## `quad_ineq_bounds()` and blew up the `if (b1 <= r1 && b2 <= r1)` check,
## crashing the vignette build.
##
## We can't reliably reproduce the exact floating-point trajectory on every
## platform, so these tests directly exercise the NA-fragile paths in
## isolation: every internal helper should accept NA inputs without
## erroring, and the user-facing call should be robust to nloptr returning
## degenerate parameter points.

test_that("quad_ineq_bounds tolerates NA in coef", {
    out <- regsensitivity:::quad_ineq_bounds(c(NA_real_, 1, 1),
                                              c(0, 1))
    expect_true(all(is.na(out)))
})

test_that("quad_ineq_bounds tolerates NA in bounds", {
    out <- regsensitivity:::quad_ineq_bounds(c(-1, 0, 1),
                                              c(NA_real_, NA_real_))
    expect_true(all(is.na(out)))
})

test_that("quad_ineq_bounds tolerates NaN coef from upstream NaN sqrt", {
    out <- regsensitivity:::quad_ineq_bounds(c(NaN, 0, 1), c(0, 1))
    expect_true(all(is.na(out)))
})

test_that("max_beta_bound returns NA cleanly on degenerate inputs", {
    bad_dgp <- list(k0 = NA_real_, var_x = 1)
    expect_true(is.na(regsensitivity:::max_beta_bound(0.5, bad_dgp)))
    bad_dgp2 <- list(k0 = 1, var_x = 0)
    expect_true(is.na(regsensitivity:::max_beta_bound(0.5, bad_dgp2)))
    expect_true(is.na(regsensitivity:::max_beta_bound(NaN,
                                                       list(k0=1, var_x=1))))
})

test_that("quadratic_real_roots handles all degenerate inputs", {
    # No real roots
    out1 <- regsensitivity:::quadratic_real_roots(c(1, 0, 1), -4)
    expect_length(out1, 2)
    # NA discriminant
    out2 <- regsensitivity:::quadratic_real_roots(c(1, 0, 1), NA_real_)
    expect_true(all(is.na(out2)))
})

test_that("breakdown_point_dmp returns NA on degenerate inputs", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    # NA bfmax should not crash
    res <- regsensitivity:::breakdown_point_dmp(beta = 0, c = 0.5,
                                                 bfmax = NA_real_,
                                                 lower_bound = TRUE, s = dgp)
    # Returns either 0 (hypothesis already false at rx=0) or a finite
    # number computed without using bfmax; just should not error.
    expect_true(is.finite(res) || is.na(res))
})

test_that("regsen_bounds with rybar=2, cbar=1 still computes without erroring", {
    # This is the regime that hit the bug on Windows: ry < Inf, cbar > 0,
    # via the DIRECT optimizer.
    expect_no_error(
        regsen_bounds(bfg_formula(), bfg(),
                      compare = bfg_compare(),
                      rybar = 2,
                      rxbar = seq(0, 0.8, length.out = 5))
    )
})

test_that("informative error on too-few observations", {
    expect_error(
        regsen_bounds(bfg_formula(), bfg()[1:5, ], compare = bfg_compare()),
        "at least 10"
    )
})

test_that("informative error on non-data.frame input", {
    expect_error(
        regsen_bounds(bfg_formula(), as.matrix(bfg())),
        "must be a data.frame"
    )
})

test_that("informative error on non-formula input", {
    expect_error(
        regsen_bounds("not a formula", bfg()),
        "must be a formula"
    )
})

test_that("informative error on all-NA outcome", {
    d <- bfg()
    d$avgrep2000to2016 <- NA_real_
    expect_error(
        regsen_bounds(bfg_formula(), d, compare = bfg_compare()),
        "complete observations"
    )
})

test_that("dmp_identified_set with NA-prone rxbar grid still returns sensible bounds", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    # Edge of the safe region.
    out <- regsensitivity:::dmp_identified_set(
        rxbar = c(0, 0.5, 0.95),
        rybar = 2,
        cbar = 1,
        s = dgp
    )
    expect_equal(nrow(out), 3L)
    # bounds at rxbar=0 must collapse to beta_med
    expect_equal(out$bmin[1], dgp$beta_med, tolerance = 1e-8)
    expect_equal(out$bmax[1], dgp$beta_med, tolerance = 1e-8)
})
