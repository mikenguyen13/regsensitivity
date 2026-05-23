test_that("regsen_boot returns valid percentile CI containing point estimate", {
    skip_on_cran()  # bootstrap is slow
    set.seed(1)
    res <- regsen_boot(bfg_formula(), bfg(),
                      compare = bfg_compare(),
                      cbar = 1,
                      R = 49,
                      show_progress = FALSE)
    expect_s3_class(res, "regsensitivity_boot")
    # Point estimate must lie between the bootstrap quantiles (almost
    # always for percentile CIs with R >= 25).
    expect_true(abs(res$point) >= abs(res$ci[1]) - 1e-6)
    expect_true(abs(res$point) <= abs(res$ci[2]) + 1e-6)
    expect_length(res$replicates, 49)
})

test_that("regsen_boot with cluster argument uses cluster resampling", {
    skip_on_cran()
    set.seed(2)
    res <- regsen_boot(bfg_formula(), bfg(),
                      compare = bfg_compare(),
                      cbar = 1,
                      cluster = "km_grid_cel_code",
                      R = 19,
                      show_progress = FALSE)
    expect_equal(res$cluster, "km_grid_cel_code")
    # Cluster bootstrap should give a slightly wider CI than the i.i.d.
    # bootstrap when there's clustering -- at minimum it should have run
    # without error.
    expect_true(is.finite(res$ci[1]))
    expect_true(is.finite(res$ci[2]))
})

test_that("regsen_boot accepts Oster analysis", {
    skip_on_cran()
    set.seed(3)
    res <- regsen_boot(bfg_formula(), bfg(),
                      compare = bfg_compare(),
                      analysis = "oster",
                      R = 19,
                      show_progress = FALSE)
    expect_s3_class(res, "regsensitivity_boot")
    expect_true(is.finite(res$point))
})

test_that("print method runs without error", {
    skip_on_cran()
    set.seed(4)
    res <- regsen_boot(bfg_formula(), bfg(),
                      compare = bfg_compare(),
                      cbar = 1,
                      R = 19,
                      show_progress = FALSE)
    expect_output(print(res), "Bootstrap confidence interval")
})
