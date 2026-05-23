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
