test_that("Oster at delta=0 returns beta_med", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    sols <- regsensitivity:::oster_idset_scalar(0, 1, dgp)
    # beta_med always satisfies the cubic when delta=0 and r_max=1.
    expect_true(any(abs(sols - dgp$beta_med) < 1e-6))
})

test_that("Oster delta() inverts oster_idset_scalar", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    # take some beta in the medium-ish range, recover delta
    target_beta <- dgp$beta_med - 0.5
    d <- regsensitivity:::oster_delta(target_beta, 1, dgp)
    sols <- regsensitivity:::oster_idset_scalar(d, 1, dgp)
    expect_true(any(abs(sols - target_beta) < 1e-3))
})

test_that("Oster identified-set sweep is shape-correct", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(),
                          analysis = "oster",
                          delta = seq(-1, 1, 0.5))
    expect_equal(nrow(res$results), 5L)
    expect_true("beta1" %in% colnames(res$results))
    expect_equal(res$analysis, "Oster (2019)")
})

test_that("Oster bound (delta-bound) idset has [bmin, bmax]", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(),
                          analysis = "oster",
                          delta = seq(0, 0.9, 0.1),
                          delta_type = "bound")
    expect_true(all(c("bmin", "bmax") %in% colnames(res$results)))
    expect_true(all(res$results$bmin <= res$results$bmax))
})

test_that("Oster breakdown_eq inverts at the medium", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    bd <- regsensitivity:::oster_breakdown_eq(
        r2max = 1, beta = dgp$beta_med, maxovb = NA_real_, s = dgp)
    expect_equal(bd$breakdown, 0, tolerance = 1e-8)
})

test_that("Oster breakdown_bound matches known sign", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    # sign hypothesis Beta > 0 (since beta_med > 0)
    bd <- regsensitivity:::oster_breakdown_bound(
        r2max = 1, beta = 0, maxovb = NA_real_,
        hyposign = ">", s = dgp)
    expect_gt(bd$breakdown, 0)
})

test_that("an unbounded Oster bound set is reported as unbounded", {
    # |delta| <= dbar with dbar >= 1 admits any beta_long. Reporting the
    # finite set from a smaller dbar would make the estimate look far more
    # robust than it is -- the one direction a sensitivity analysis must
    # never err in.
    res <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                          analysis = "oster",
                          delta = c(0.5, 1, 2), delta_type = "bound")
    r <- res$results
    expect_true(all(is.finite(unlist(r[r$delta == 0.5, c("bmin", "bmax")]))))
    expect_equal(r$bmin[r$delta == 1], -Inf)
    expect_equal(r$bmax[r$delta == 1],  Inf)
    expect_equal(r$bmin[r$delta == 2], -Inf)
    expect_equal(r$bmax[r$delta == 2],  Inf)
})

test_that("the bound sweep stays nested as dbar grows", {
    # The identified set for |delta| <= dbar can only grow with dbar.
    res <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                          analysis = "oster",
                          delta = seq(0.1, 0.9, by = 0.2),
                          delta_type = "bound")
    r <- res$results
    expect_false(is.unsorted(rev(r$bmin)))   # bmin non-increasing in dbar
    expect_false(is.unsorted(r$bmax))        # bmax non-decreasing in dbar
})
