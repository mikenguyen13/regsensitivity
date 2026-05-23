test_that("DMP identified set at rxbar=0 collapses to point at beta_med", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    idset <- regsensitivity:::dmp_identified_set(
        rxbar = 0, rybar = Inf, cbar = 0.5, s = dgp)
    expect_equal(idset$bmin, idset$bmax, tolerance = 1e-10)
    expect_equal(idset$bmin, dgp$beta_med, tolerance = 1e-10)
})

test_that("DMP identified set at rxbar=rmax is (-Inf, Inf)", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    rmax <- regsensitivity:::max_beta_bound(0.1, dgp)
    idset <- regsensitivity:::dmp_identified_set(
        rxbar = rmax, rybar = Inf, cbar = 0.1, s = dgp)
    expect_true(is.infinite(idset$bmin))
    expect_true(is.infinite(idset$bmax))
})

test_that("DMP identified set is monotonically widening in rxbar", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    rmax <- regsensitivity:::max_beta_bound(0.5, dgp)
    rxs <- seq(0, rmax * 0.9, length.out = 10)
    idset <- regsensitivity:::dmp_identified_set(
        rxbar = rxs, rybar = Inf, cbar = 0.5, s = dgp)
    widths <- idset$bmax - idset$bmin
    # widths must be non-decreasing (modulo small floating noise)
    expect_true(all(diff(widths) >= -1e-8))
})

test_that("DMP identified set centred around beta_med (ryinf)", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    idset <- regsensitivity:::dmp_identified_set(
        rxbar = 0.2, rybar = Inf, cbar = 0.1, s = dgp)
    expect_equal((idset$bmin + idset$bmax) / 2, dgp$beta_med,
                  tolerance = 1e-8)
})

test_that("DMP rybar-finite, cbar=0 closed form runs and is finite", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    idset <- regsensitivity:::dmp_identified_set(
        rxbar = 0.3, rybar = 2, cbar = 0, s = dgp)
    expect_true(is.finite(idset$bmin))
    expect_true(is.finite(idset$bmax))
    expect_lt(idset$bmin, idset$bmax)
})

test_that("DMP rybar-finite, cbar>0 DIRECT produces sensible bounds", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    idset <- regsensitivity:::dmp_identified_set(
        rxbar = 0.3, rybar = 2, cbar = 1, s = dgp)
    expect_true(is.finite(idset$bmin))
    expect_true(is.finite(idset$bmax))
    expect_lt(idset$bmin, dgp$beta_med)
    expect_gt(idset$bmax, dgp$beta_med)
})

test_that("DMP breakdown frontier monotonically decreases in cbar (ryinf)", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    bf <- regsensitivity:::dmp_breakdown_frontier(
        beta = 0, cs = seq(0, 1, 0.1), ry = Inf, hyposign = ">", s = dgp)
    # Monotonically decreasing (with possible plateau when cbar > bfmax).
    diffs <- diff(bf$breakdown)
    expect_true(all(diffs <= 1e-6))
})

test_that("regsen_bounds returns the expected structure", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = 0.1)
    expect_s3_class(res, "regsensitivity")
    expect_equal(res$subcommand, "bounds")
    expect_equal(res$analysis, "DMP (2026)")
    expect_true(all(c("rxbar", "rybar", "cbar", "bmin", "bmax") %in%
                     colnames(res$results)))
    expect_true(!is.na(res$breakdown))
    expect_gt(res$breakdown, 0)
})

test_that("regsen_bounds with multi-cbar returns product grid", {
    cbars <- seq(0, 1, 0.25)
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(),
                          rxbar = seq(0, 2, 0.5),
                          cbar = cbars)
    expect_equal(nrow(res$results), 5 * length(cbars))
})

test_that("noproduct (product = FALSE) zips the parameter inputs", {
    rx <- c(0.1, 0.3, 0.5)
    cb <- c(0.2, 0.4, 0.6)
    res <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                          rxbar = rx, cbar = cb, product = FALSE)
    expect_equal(nrow(res$results), 3L)
    expect_equal(res$results$rxbar, rx)
    expect_equal(res$results$cbar, cb)
})
