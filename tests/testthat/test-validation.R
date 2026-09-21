## Input validation and the edge cases it guards.

test_that("a compare name that is not a control is an error, not a silent drop", {
    expect_error(
        regsen_bounds(bfg_formula(), bfg(), compare = c("lat", "lonn"),
                      cbar = 1),
        "lonn")
    expect_error(
        regsen_bounds(bfg_formula(), bfg(), nocompare = "nope", cbar = 1),
        "nope")
    # Naming the treatment gets the pointed message.
    expect_error(
        regsen_bounds(bfg_formula(), bfg(),
                      compare = "tye_tfe890_500kNI_100_l6", cbar = 1),
        "cannot calibrate itself")
})

test_that("DMP sensitivity parameters are range-checked", {
    f <- bfg_formula(); d <- bfg(); w1 <- bfg_compare()
    expect_error(regsen_bounds(f, d, compare = w1, cbar = 2), "cbar")
    expect_error(regsen_bounds(f, d, compare = w1, cbar = NA), "cbar")
    expect_error(regsen_bounds(f, d, compare = w1, cbar = -0.1), "cbar")
    expect_error(regsen_bounds(f, d, compare = w1, rxbar = -1, cbar = 1),
                 "rxbar")
    expect_error(regsen_breakdown(f, d, compare = w1, rybar = -1), "rybar")
    expect_error(regsen_breakdown(f, d, compare = w1, cbar = "a"), "cbar")
    # rybar = Inf is the unrestricted case and stays legal.
    expect_s3_class(regsen_breakdown(f, d, compare = w1, rybar = Inf),
                    "regsensitivity")
})

test_that("Oster sensitivity parameters are checked", {
    f <- bfg_formula(); d <- bfg(); w1 <- bfg_compare()
    expect_error(regsen_bounds(f, d, compare = w1, analysis = "oster",
                               r2long = "a"), "r2long")
    expect_error(regsen_bounds(f, d, compare = w1, analysis = "oster",
                               delta = c(0.1, NA)), "delta")
    expect_error(regsen_breakdown(f, d, compare = w1, analysis = "oster",
                                  maxovb = -1), "maxovb")
})

test_that("a list-form beta is validated", {
    expect_error(
        regsen_breakdown(bfg_formula(), bfg(), compare = bfg_compare(),
                         beta = list(value = 0, sign = ">=")),
        "beta\\$sign")
    expect_error(
        regsen_breakdown(bfg_formula(), bfg(), compare = bfg_compare(),
                         beta = list(value = "0", sign = ">")),
        "beta\\$value")
})

test_that("maxovb caps the Oster bound set where the raw set is unbounded", {
    res <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                         analysis = "oster", delta = c(0.5, 1, 2),
                         delta_type = "bound", maxovb = 0.05)
    r <- res$results
    bm <- res$dgp$beta_med
    expect_equal(r$bmin[r$delta >= 1], rep(bm - 0.05, 2))
    expect_equal(r$bmax[r$delta >= 1], rep(bm + 0.05, 2))
    # Without the cap the same points are unbounded.
    raw <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                         analysis = "oster", delta = c(0.5, 1, 2),
                         delta_type = "bound")$results
    expect_equal(raw$bmin[raw$delta >= 1], c(-Inf, -Inf))
})

test_that("breakdown sweep arguments of unequal length are refused", {
    dgp <- regsensitivity:::get_dgp(regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare()))
    expect_error(
        regsensitivity:::oster_breakdown_eq(r2max = c(0.5, 1), beta = c(0, 1, 2),
                                            maxovb = NA_real_, s = dgp),
        "common length")
})

test_that("aliased comparison columns are dropped", {
    d <- bfg()
    d$lat2 <- 2 * d$lat            # collinear with lat
    d$tiny <- d$lon * 1e-8         # lon in tiny units: kept, not mistaken for 0
    f <- avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 +
        log_area_2010 + lat + lat2 + tiny + statea
    a <- regsen_bounds(f, d, compare = c("log_area_2010", "lat", "lat2", "tiny"),
                       cbar = 1)
    b <- regsen_bounds(avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 +
                           log_area_2010 + lat + lon + statea,
                       d, compare = c("log_area_2010", "lat", "lon"), cbar = 1)
    expect_equal(a$dgp$n_compare, 3L)
    expect_equal(a$dgp$beta_med, b$dgp$beta_med)
    expect_equal(a$results$bmin, b$results$bmin)
    expect_equal(a$results$bmax, b$results$bmax)
})

test_that("a logical subset with NA treats NA as FALSE", {
    n <- nrow(bfg())
    sub <- c(rep(TRUE, 1000), NA, rep(FALSE, n - 1001))
    res <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                         cbar = 1, subset = sub)
    expect_equal(res$n, 1000L)
})

test_that("plotting a single identified set is a clear error", {
    res <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                         cbar = 1, rxbar = 0.5)
    expect_error(plot(res), "nothing to plot")
})

test_that("more groups than palette colours recycles with a warning", {
    res <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                         cbar = seq(0.1, 0.9, 0.1))
    p <- plot(res)
    expect_warning(ggplot2::ggplot_build(p), "recycled")
})

test_that("a LaTeX label without a caption warns instead of vanishing", {
    skip_if_not_installed("knitr")
    res <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                         cbar = 0.1)
    expect_warning(regsen_table(res, format = "latex", label = "x"),
                   "caption")
})

test_that("a signed interval is reported as a magnitude interval", {
    ai <- regsensitivity:::abs_interval
    expect_equal(ai(c(-0.9, -0.4)), c(0.4, 0.9))
    expect_equal(ai(c(-0.3, 0.6)), c(0, 0.6))
    expect_equal(ai(c(0.2, 0.5)), c(0.2, 0.5))
    expect_equal(ai(c(NA, 0.5)), c(NA, 0.5))
})

test_that("infinite bootstrap replicates stay in the interval", {
    reps <- c(rep(1, 15), rep(Inf, 5))
    ci <- regsensitivity:::bca_interval(1, reps, jack = rep(1, 20),
                                        level = 0.5)$ci
    expect_equal(ci[2], Inf)
})

test_that("regsen_summary uses each r2long value once", {
    s <- regsen_summary(bfg_formula(), bfg(), compare = bfg_compare())
    idx <- s$oster_breakdown$results$index
    expect_false(any(duplicated(idx)))
})
