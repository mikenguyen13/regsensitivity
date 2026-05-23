## Numeric regression tests. These pin down concrete output values so we
## catch silent regressions when nloptr / R / numeric tolerances shift on
## upgrade. The snapshots are stored in tests/testthat/_snaps/.
##
## To refresh after an intentional change:  testthat::snapshot_accept().

test_that("DMP bounds at BFG2020 cbar=0.1 are stable across upgrades", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(),
                          cbar = 0.1,
                          rxbar = seq(0, 2, 0.2))
    expect_snapshot_value(
        round(as.matrix(res$results), 5),
        style = "json2"
    )
})

test_that("DMP breakdown at BFG2020 over cbar grid is stable", {
    res <- regsen_breakdown(bfg_formula(), bfg(),
                             compare = bfg_compare(),
                             cbar = seq(0, 1, 0.1))
    expect_snapshot_value(
        round(as.matrix(res$results), 5),
        style = "json2"
    )
})

test_that("Oster equality bounds at BFG2020 are stable", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(),
                          analysis = "oster",
                          delta = seq(-1, 1, 0.2))
    expect_snapshot_value(
        round(as.matrix(res$results), 5),
        style = "json2"
    )
})

test_that("Oster sign-change breakdown across r2long grid is stable", {
    res <- regsen_breakdown(bfg_formula(), bfg(),
                             compare = bfg_compare(),
                             analysis = "oster",
                             r2long = seq(0.15, 1, 0.05))
    expect_snapshot_value(
        round(as.matrix(res$results), 5),
        style = "json2"
    )
})

test_that("DGP summary statistics are stable", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    snapshot <- list(
        beta_short = round(dgp$beta_short, 6),
        beta_med   = round(dgp$beta_med, 6),
        r_short    = round(dgp$r_short, 6),
        r_med      = round(dgp$r_med, 6),
        k0         = round(dgp$k0, 6),
        k1         = round(dgp$k1, 6),
        k2         = round(dgp$k2, 6),
        n          = dgp$n,
        n_compare  = dgp$n_compare
    )
    expect_snapshot_value(snapshot, style = "json2")
})
