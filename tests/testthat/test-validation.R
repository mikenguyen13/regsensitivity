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

test_that("calibration helpers drop an aliased comparison column too", {
    d <- bfg(); d$lat2 <- 2 * d$lat
    f <- avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 +
        log_area_2010 + lat + lat2 + lon + statea
    f0 <- avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 +
        log_area_2010 + lat + lon + statea
    w1 <- c("log_area_2010", "lat", "lon")
    expect_equal(calibrate_rho(f, d, compare = c(w1, "lat2")),
                 calibrate_rho(f0, d, compare = w1))
    expect_equal(calibrate_partial_r2(f, d, compare = c(w1, "lat2")),
                 calibrate_partial_r2(f0, d, compare = w1))
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

## Degenerate data: each of these used to return a number or a cryptic error.

sim_small <- function(n = 200) {
    set.seed(11)
    w1a <- rnorm(n); w1b <- rnorm(n); w0 <- rnorm(n)
    x <- 0.5 * w1a + 0.3 * w1b + 0.2 * w0 + rnorm(n)
    y <- 1 + 0.4 * x + 0.5 * w1a - 0.2 * w1b + 0.3 * w0 + rnorm(n)
    data.frame(y, x, w1a, w1b, w0)
}
sim_f <- y ~ x + w1a + w1b + w0
sim_cmp <- c("w1a", "w1b")

test_that("a treatment with no variation left is an error, not a number", {
    d <- sim_small()
    # A constant treatment used to report beta = 1e15 and a breakdown of 0.76.
    dd <- d; dd$x <- 1
    expect_error(regsen_breakdown(sim_f, dd, compare = sim_cmp),
                 "treatment `x` has no variation")
    expect_error(regsen_bounds(sim_f, dd, compare = sim_cmp),
                 "treatment `x` has no variation")
    # Collinear with a control outside the comparison set ...
    dd <- d; dd$x <- dd$w0 + 1
    expect_error(regsen_breakdown(sim_f, dd, compare = sim_cmp),
                 "not identified")
    # ... and with one inside it, which used to fail on an NA in if().
    dd <- d; dd$x <- 2 * dd$w1a
    expect_error(regsen_breakdown(sim_f, dd, compare = sim_cmp),
                 "not identified")
    expect_error(regsen_bounds(sim_f, dd, compare = sim_cmp, analysis = "oster"),
                 "not identified")
    # A treatment that is nearly, but not exactly, collinear still runs.
    dd <- d; dd$x <- dd$w0 + 1e-3 * dd$x
    expect_s3_class(regsen_breakdown(sim_f, dd, compare = sim_cmp),
                    "regsensitivity")
})

test_that("an outcome with no variation left is an error", {
    d <- sim_small()
    dd <- d; dd$y <- 3
    expect_error(regsen_breakdown(sim_f, dd, compare = sim_cmp),
                 "outcome `y` has no variation")
    dd <- d; dd$y <- 2 * dd$w0 - 1
    expect_error(regsen_breakdown(sim_f, dd, compare = sim_cmp),
                 "outcome `y` has no variation")
    # Collinear with the comparison controls is a legitimate, if extreme,
    # model: the comparison set explains Y fully.
    dd <- d; dd$y <- dd$w1a + dd$x
    expect_s3_class(regsen_bounds(sim_f, dd, compare = sim_cmp),
                    "regsensitivity")
})

test_that("infinite values are named instead of failing inside qr()", {
    d <- sim_small()
    dd <- d; dd$y[1] <- Inf
    expect_error(regsen_bounds(sim_f, dd, compare = sim_cmp),
                 "Infinite values in `y`")
    dd <- d; dd$w0[3] <- -Inf; dd$x[2] <- Inf
    expect_error(regsen_bounds(sim_f, dd, compare = sim_cmp),
                 "`x`, `w0`")
})

test_that("a subset that does not fit the data is an error", {
    d <- sim_small()
    expect_error(regsen_bounds(sim_f, d, compare = sim_cmp,
                               subset = c(TRUE, FALSE)),
                 "length 2, but `data` has 200 rows")
    expect_error(regsen_bounds(sim_f, d, compare = sim_cmp, subset = 1:500),
                 "beyond the 200 rows")
    # Logical of the right length, positive and negative indices still work.
    a <- regsen_bounds(sim_f, d, compare = sim_cmp, subset = d$w0 > -1)
    b <- regsen_bounds(sim_f, d, compare = sim_cmp, subset = which(d$w0 > -1))
    neg <- regsen_bounds(sim_f, d, compare = sim_cmp, subset = -which(d$w0 <= -1))
    expect_equal(a$results, b$results)
    expect_equal(a$results, neg$results)
})

test_that("a cluster bootstrap needs at least two clusters and no missing ids", {
    d <- sim_small()
    dd <- d; dd$g <- 1L
    expect_error(regsen_boot(sim_f, dd, compare = sim_cmp, R = 5, seed = 1,
                             cluster = "g", show_progress = FALSE),
                 "single cluster")
    dd$g <- rep(1:20, each = 10); dd$g[4] <- NA
    expect_error(regsen_boot(sim_f, dd, compare = sim_cmp, R = 5, seed = 1,
                             cluster = "g", show_progress = FALSE),
                 "missing for 1 of the rows")
    expect_error(regsen_boot(sim_f, dd, compare = sim_cmp, R = 5, seed = 1,
                             cluster = c("g", "w0"), show_progress = FALSE),
                 "single column name")
})

test_that("the outcome must be one numeric column", {
    d <- sim_small()
    # A one-sided formula used to run with no outcome at all.
    expect_error(regsen_bounds(~ x + w1a + w1b + w0, d, compare = sim_cmp),
                 "single numeric outcome")
    expect_error(regsen_bounds(cbind(y, w0) ~ x + w1a + w1b, d,
                               compare = sim_cmp),
                 "single numeric outcome")
    dd <- d; dd$y <- factor(dd$y > 0)
    expect_error(regsen_bounds(sim_f, dd, compare = sim_cmp),
                 "single numeric outcome")
    # A transformed or logical outcome is still fine.
    expect_s3_class(regsen_bounds(log(exp(y)) ~ x + w1a + w1b + w0, d,
                                  compare = sim_cmp), "regsensitivity")
    dd <- d; dd$y <- dd$y > 0
    expect_s3_class(regsen_bounds(sim_f, dd, compare = sim_cmp),
                    "regsensitivity")
})
