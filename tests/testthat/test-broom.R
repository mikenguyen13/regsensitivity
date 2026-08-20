test_that("regsen_tidy uses broom's column vocabulary", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = c(0.1, 0.5))
    t <- regsen_tidy(res)
    expect_s3_class(t, "data.frame")
    # These names are the contract with modelsummary and friends.
    expect_true(all(c("term", "estimate", "conf.low", "conf.high") %in% names(t)))
    expect_equal(names(t)[1:4], c("term", "estimate", "conf.low", "conf.high"))
    expect_equal(unique(t$term), res$indvar)
    expect_equal(nrow(t), nrow(as.data.frame(res)))
})

test_that("estimate is the medium-regression coefficient, held constant", {
    # `estimate` reports beta from the medium regression at every grid
    # point. It must not be derived from the bounds: under DMP with
    # rybar = Inf the identified set happens to be symmetric about that
    # coefficient, so a midpoint would agree here by coincidence and then
    # silently disagree for Oster or for finite rybar.
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = 0.5)
    t <- regsen_tidy(res)

    expect_equal(unique(t$estimate), res$dgp$beta_med)
    expect_length(unique(t$estimate), 1L)

    # Constant even where the set is unbounded and a midpoint is undefined.
    unbounded <- which(!is.finite(t$conf.low) | !is.finite(t$conf.high))
    if (length(unbounded)) {
        expect_true(all(is.finite(t$estimate[unbounded])))
        expect_equal(t$estimate[unbounded[1]], res$dgp$beta_med)
    }
})

test_that("regsen_glance returns exactly one row of analysis metadata", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = 1)
    g <- regsen_glance(res)
    expect_equal(nrow(g), 1L)
    expect_true(all(c("analysis", "outcome", "treatment", "nobs",
                      "breakdown", "hypothesis") %in% names(g)))
    expect_equal(g$nobs, res$n)
    expect_equal(g$treatment, res$indvar)
})

test_that("tidiers reject non-regsensitivity input", {
    expect_error(regsen_tidy(mtcars))
    expect_error(regsen_glance(mtcars))
})

test_that("breakdown objects tidy and glance too", {
    bd <- regsen_breakdown(bfg_formula(), bfg(),
                            compare = bfg_compare(), cbar = seq(0, 1, 0.5))
    expect_s3_class(regsen_tidy(bd), "data.frame")
    expect_equal(nrow(regsen_glance(bd)), 1L)
})

test_that("generics::tidy dispatches when generics is available", {
    skip_if_not_installed("generics")
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = 0.5)
    expect_equal(nrow(generics::tidy(res)), nrow(regsen_tidy(res)))
    expect_equal(nrow(generics::glance(res)), 1L)
})

test_that("autoplot matches plot", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = 0.1)
    expect_s3_class(ggplot2::autoplot(res), "ggplot")
    expect_s3_class(ggplot2::autoplot(res, xline = 1), "ggplot")
})
