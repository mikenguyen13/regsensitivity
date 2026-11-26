## Fixed effects absorbed with `fe` must give exactly what the same
## grouping variables give as factor controls outside the comparison set
## (Frisch-Waugh-Lovell), without building the dummy columns.

bfg_fe_formula <- function() {
    reformulate(c("tye_tfe890_500kNI_100_l6", bfg_compare()),
                response = "avgrep2000to2016")
}

test_that("fe = ~ statea reproduces statea as a factor control (bfg2020)", {
    d <- bfg()
    dense <- regsen_bounds(bfg_formula(), d, compare = bfg_compare(),
                           cbar = c(0, 0.5, 1), rxbar = c(0, 0.5, 1))
    absorbed <- regsen_bounds(bfg_fe_formula(), d, compare = bfg_compare(),
                              fe = ~ statea,
                              cbar = c(0, 0.5, 1), rxbar = c(0, 0.5, 1))
    expect_equal(coef(absorbed), coef(dense), tolerance = 1e-10)
    expect_equal(absorbed$results, dense$results, tolerance = 1e-8)
    expect_identical(absorbed$fe, "statea")
    expect_identical(absorbed$n, dense$n)

    bk_dense <- regsen_breakdown(bfg_formula(), d, compare = bfg_compare(),
                                 cbar = c(0, 1))
    bk_fe <- regsen_breakdown(bfg_fe_formula(), d, compare = bfg_compare(),
                              fe = "statea", cbar = c(0, 1))
    expect_equal(bk_fe$results, bk_dense$results, tolerance = 1e-8)

    os_dense <- regsen_breakdown(bfg_formula(), d, compare = bfg_compare(),
                                 analysis = "oster", r2long = 1)
    os_fe <- regsen_breakdown(bfg_fe_formula(), d, compare = bfg_compare(),
                              analysis = "oster", r2long = 1, fe = ~ statea)
    expect_equal(os_fe$results, os_dense$results, tolerance = 1e-8)

    expect_equal(
        calibrate_rho(bfg_fe_formula(), d, compare = bfg_compare(),
                      fe = ~ statea),
        calibrate_rho(bfg_formula(), d, compare = bfg_compare()),
        tolerance = 1e-8
    )
    expect_equal(
        calibrate_partial_r2(bfg_fe_formula(), d, compare = bfg_compare(),
                             fe = ~ statea),
        calibrate_partial_r2(bfg_formula(), d, compare = bfg_compare()),
        tolerance = 1e-8
    )
})

two_way_panel <- function(seed = 3, n_firm = 40, n_year = 8) {
    set.seed(seed)
    d <- expand.grid(firm = seq_len(n_firm), year = seq_len(n_year))
    # An unbalanced panel, so the two dimensions are not orthogonal and the
    # alternating projections need more than one sweep.
    d <- d[stats::runif(nrow(d)) > 0.25, ]
    a <- stats::rnorm(n_firm)[d$firm]
    t <- stats::rnorm(n_year)[d$year]
    n <- nrow(d)
    d$w1 <- stats::rnorm(n) + a
    d$w2 <- stats::rnorm(n) + t
    d$w3 <- stats::rnorm(n)
    d$x  <- 0.5 * d$w1 + 0.3 * d$w2 + a - t + stats::rnorm(n)
    d$y  <- 0.4 * d$x + 0.5 * d$w1 + 0.2 * d$w2 + 0.3 * d$w3 +
        2 * a + t + stats::rnorm(n)
    d
}

test_that("two-way fixed effects match firm and year dummies", {
    d <- two_way_panel()
    d$firm_f <- factor(d$firm)
    d$year_f <- factor(d$year)
    w <- c("w1", "w2")
    dense <- regsen_breakdown(y ~ x + w1 + w2 + w3 + firm_f + year_f, d,
                              compare = w, cbar = c(0, 0.5, 1))
    absorbed <- regsen_breakdown(y ~ x + w1 + w2 + w3, d, compare = w,
                                 fe = ~ firm + year, cbar = c(0, 0.5, 1))
    expect_equal(absorbed$dgp$beta_med, dense$dgp$beta_med, tolerance = 1e-9)
    expect_equal(absorbed$dgp$r_med, dense$dgp$r_med, tolerance = 1e-9)
    expect_equal(absorbed$results, dense$results, tolerance = 1e-7)
    expect_output(print(absorbed), "Fixed effects: +firm, year")
    expect_output(print(summary(absorbed)), "Fixed effects: +firm, year")
})

test_that("singletons are dropped, counted, and leave the estimates alone", {
    d <- two_way_panel()
    # Two firms observed once each.
    extra <- d[1:2, ]
    extra$firm <- c(1001, 1002)
    d2 <- rbind(d, extra)
    d2$firm_f <- factor(d2$firm)
    d2$year_f <- factor(d2$year)

    absorbed <- regsen_bounds(y ~ x + w1 + w2 + w3, d2, compare = c("w1", "w2"),
                              fe = ~ firm + year, rxbar = c(0, 1), cbar = 1)
    dense <- regsen_bounds(y ~ x + w1 + w2 + w3 + firm_f + year_f, d2,
                           compare = c("w1", "w2"), rxbar = c(0, 1), cbar = 1)
    expect_identical(absorbed$n_singletons, 2L)
    expect_identical(absorbed$n, dense$n - 2L)
    expect_equal(coef(absorbed), coef(dense), tolerance = 1e-9)
    expect_equal(absorbed$results, dense$results, tolerance = 1e-7)
    expect_output(print(absorbed), "2 singletons dropped")
})

test_that("rows with a missing group are dropped like any missing value", {
    d <- two_way_panel()
    d$firm[c(3, 7)] <- NA
    keep <- !is.na(d$firm)
    a <- regsen_bounds(y ~ x + w1 + w2, d, fe = ~ firm, rxbar = 1)
    b <- regsen_bounds(y ~ x + w1 + w2, d[keep, ], fe = ~ firm, rxbar = 1)
    expect_identical(a$n, b$n)
    expect_equal(coef(a), coef(b))
})

test_that("bad `fe` specifications are refused with a pointer", {
    d <- two_way_panel()
    expect_error(regsen_bounds(y ~ x + w1, d, fe = ~ firm:year), "interaction")
    expect_error(regsen_bounds(y ~ x + w1, d, fe = ~ nosuch), "not in `data`")
    expect_error(regsen_bounds(y ~ x + w1, d, fe = y ~ firm), "one-sided")
    expect_error(regsen_bounds(y ~ x + w1, d, fe = 3), "one-sided formula")
    # A treatment that does not vary within groups is absorbed entirely.
    d$xf <- stats::rnorm(40)[d$firm]
    expect_error(regsen_bounds(y ~ xf + w1, d, fe = ~ firm), "no variation")
})

test_that("the bootstrap re-demeans every replicate", {
    d <- two_way_panel()
    b1 <- regsen_boot(y ~ x + w1 + w2 + w3, d, compare = c("w1", "w2"),
                      fe = ~ firm + year, cbar = 1, R = 30, seed = 11,
                      cluster = "firm", type = "perc")
    b2 <- regsen_boot(y ~ x + w1 + w2 + w3, d, compare = c("w1", "w2"),
                      fe = ~ firm + year, cbar = 1, R = 30, seed = 11,
                      cluster = "firm", type = "perc")
    expect_identical(b1$replicates, b2$replicates)
    expect_true(all(is.finite(b1$replicates)))
    expect_equal(b1$point,
                 breakdown_point(regsen_breakdown(
                     y ~ x + w1 + w2 + w3, d, compare = c("w1", "w2"),
                     fe = ~ firm + year, cbar = 1)))
})

test_that("regsen_multi() and regsen_summary() pass `fe` through", {
    d <- two_way_panel()
    m <- regsen_multi(y ~ x + w1 + w2 + w3, d, treatments = c("x", "w3"),
                      compare = c("w1", "w2"), fe = ~ firm + year, cbar = 1)
    one <- regsen_breakdown(y ~ x + w1 + w2 + w3, d, compare = c("w1", "w2"),
                            fe = ~ firm + year, cbar = 1)
    expect_equal(m$breakdown[m$treatment == "x"], breakdown_point(one))

    s <- regsen_summary(y ~ x + w1 + w2 + w3, d, compare = c("w1", "w2"),
                        fe = ~ firm + year)
    expect_identical(s$dmp_bounds$fe, c("firm", "year"))
    expect_identical(s$oster_breakdown$fe, c("firm", "year"))
})
