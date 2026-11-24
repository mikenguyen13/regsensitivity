test_that("regsen_control() validates its arguments", {
    ctl <- regsen_control()
    expect_s3_class(ctl, "regsen_control")
    expect_identical(ctl$maxiter, 1000L)
    expect_identical(ctl$polish, 300L)
    expect_equal(ctl$precision, 1e-8)
    expect_identical(regsen_control(polish = 0)$polish, 0L)
    expect_output(print(ctl), "maxiter = 1000")

    expect_error(regsen_control(maxiter = 0), "maxiter")
    expect_error(regsen_control(maxiter = 10.5), "maxiter")
    expect_error(regsen_control(maxiter = c(1, 2)), "maxiter")
    expect_error(regsen_control(polish = -1), "polish")
    expect_error(regsen_control(precision = 0), "precision")
    expect_error(regsen_control(precision = 2), "precision")
})

test_that("control accepts a plain list and rejects unknown fields", {
    expect_identical(regsensitivity:::as_regsen_control(list(maxiter = 50)),
                     regsen_control(maxiter = 50))
    expect_identical(regsensitivity:::as_regsen_control(NULL),
                     regsen_control())
    expect_error(regsensitivity:::as_regsen_control(list(iters = 5)),
                 "unknown fields")
    expect_error(regsensitivity:::as_regsen_control("fast"),
                 "regsen_control")
})

control_dgp <- function() {
    set.seed(5)
    n <- 300
    w1 <- rnorm(n); w2 <- rnorm(n); u <- rnorm(n)
    x <- 0.5 * w1 + 0.3 * w2 + 0.4 * u + rnorm(n)
    y <- 0.7 * x + 0.6 * w1 + 0.2 * w2 + 0.8 * u + rnorm(n)
    data.frame(y, x, w1, w2)
}

test_that("the optimizer budget reaches the finite-rybar solver", {
    d <- control_dgp()
    run <- function(ctl) {
        regsen_bounds(y ~ x + w1 + w2, d, rxbar = c(0.3, 0.6), rybar = 0.5,
                      cbar = 0.5, control = ctl)$results
    }
    full <- run(regsen_control())
    tiny <- run(regsen_control(maxiter = 8, polish = 0))
    # A smaller search can only miss the extremes, so its set is nested in
    # the default one; and with 8 evaluations it does miss them.
    expect_true(all(tiny$bmin >= full$bmin - 1e-8))
    expect_true(all(tiny$bmax <= full$bmax + 1e-8))
    expect_false(isTRUE(all.equal(tiny, full)))

    # The closed-form regime never calls the optimizer, so the budget is
    # irrelevant there.
    closed <- function(ctl) {
        regsen_bounds(y ~ x + w1 + w2, d, rxbar = c(0.3, 0.6),
                      cbar = 0.5, control = ctl)$results
    }
    expect_identical(closed(regsen_control(maxiter = 8, polish = 0)),
                     closed(regsen_control()))
})

test_that("the breakdown frontier honours the budget too", {
    d <- control_dgp()
    run <- function(ctl) {
        regsen_breakdown(y ~ x + w1 + w2, d, cbar = 0.5, rybar = 2,
                         control = ctl)$results$breakdown
    }
    default <- run(regsen_control())
    expect_true(is.finite(default))
    expect_equal(run(list(maxiter = 1000, polish = 300)), default)
    expect_false(isTRUE(all.equal(run(regsen_control(maxiter = 8,
                                                     polish = 0)),
                                  default)))
})

test_that("formula() returns the formula the analysis ran on", {
    d <- control_dgp()
    f <- y ~ x + w1 + w2
    b <- regsen_bounds(f, d, cbar = 0.5)
    expect_identical(formula(b), f)
    expect_identical(formula(regsen_breakdown(f, d, analysis = "oster")), f)
    # A formula held in a variable is returned as the formula, not the name.
    expect_s3_class(formula(b), "formula")
    expect_identical(all.vars(formula(b))[1:2], c("y", "x"))
})
