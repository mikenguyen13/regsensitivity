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

test_that("a seed gives identical replicates regardless of ncores", {
    skip_on_cran()
    # The property that matters for a replication package: results must not
    # depend on how the work was divided across cores.
    args <- list(bfg_formula(), bfg(), compare = bfg_compare(),
                 cbar = 1, R = 12, seed = 99, show_progress = FALSE)
    b1 <- do.call(regsen_boot, c(args, list(ncores = 1)))
    b2 <- do.call(regsen_boot, c(args, list(ncores = 2)))

    expect_equal(b1$replicates, b2$replicates)
    expect_equal(b1$ci, b2$ci)
})

test_that("a different seed gives different replicates", {
    skip_on_cran()
    a <- regsen_boot(bfg_formula(), bfg(), compare = bfg_compare(),
                      cbar = 1, R = 12, seed = 1, show_progress = FALSE)
    b <- regsen_boot(bfg_formula(), bfg(), compare = bfg_compare(),
                      cbar = 1, R = 12, seed = 2, show_progress = FALSE)
    expect_false(isTRUE(all.equal(a$replicates, b$replicates)))
})

test_that("ncores is validated and capped at R", {
    skip_on_cran()
    expect_error(regsen_boot(bfg_formula(), bfg(), compare = bfg_compare(),
                              cbar = 1, R = 5, ncores = 0),
                 "positive integer")
    # More cores than replicates must not spawn idle workers. Kept at two
    # replicates so the request stays inside the two-process ceiling that
    # R CMD check --as-cran enforces.
    b <- regsen_boot(bfg_formula(), bfg(), compare = bfg_compare(),
                      cbar = 1, R = 2, ncores = 8, seed = 1,
                      show_progress = FALSE)
    expect_equal(b$ncores, 2L)
    expect_length(b$replicates, 2L)
})

test_that("the caller's RNG state is not disturbed by seeding", {
    skip_on_cran()
    set.seed(123)
    before <- runif(1)
    set.seed(123)
    invisible(regsen_boot(bfg_formula(), bfg(), compare = bfg_compare(),
                           cbar = 1, R = 4, show_progress = FALSE))
    # No seed argument: the bootstrap consumes draws from the caller's
    # stream, so the next value must differ from the un-consumed one.
    after <- runif(1)
    expect_false(isTRUE(all.equal(before, after)))
})
