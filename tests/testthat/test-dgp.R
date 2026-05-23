test_that("DGP matches OLS on the medium regression (FWL)", {
    set.seed(1)
    n <- 500
    w1 <- matrix(rnorm(n * 3), n, 3); colnames(w1) <- paste0("w1_", 1:3)
    w0 <- matrix(rnorm(n * 2), n, 2); colnames(w0) <- paste0("w0_", 1:2)
    x <- rowSums(w1) * 0.3 + rnorm(n)
    y <- 2 * x + rowSums(w1) * 0.5 + rowSums(w0) * 0.2 + rnorm(n)
    dat <- data.frame(y = y, x = x, w1, w0)

    form <- y ~ x + w1_1 + w1_2 + w1_3 + w0_1 + w0_2
    inp <- regsensitivity:::build_dgp_inputs(form, dat,
                                              compare = c("w1_1", "w1_2", "w1_3"))
    dgp <- regsensitivity:::get_dgp(inp)

    # beta_med equals the OLS coefficient on x in the full medium regression.
    fit_med <- lm(y ~ x + w1_1 + w1_2 + w1_3 + w0_1 + w0_2, data = dat)
    expect_equal(dgp$beta_med, unname(coef(fit_med)["x"]),
                  tolerance = 1e-10)

    # k0 = Var(MX|W) where MX is X residualized on W0 + W1.
    res <- resid(lm(x ~ w1_1 + w1_2 + w1_3 + w0_1 + w0_2, data = dat))
    expect_equal(dgp$k0, var(res), tolerance = 1e-8)

    # r_med is the *partial* R-squared (after projecting out W0), so we
    # compute it by hand to compare. Equals R^2 of lm(y_resid ~ x_resid + w1_resid).
    yr  <- resid(lm(y ~ w0_1 + w0_2, data = dat))
    xr  <- resid(lm(x ~ w0_1 + w0_2, data = dat))
    w1r <- resid(lm(cbind(w1_1, w1_2, w1_3) ~ w0_1 + w0_2, data = dat))
    fit_partial <- lm(yr ~ xr + w1r)
    expect_equal(dgp$r_med, summary(fit_partial)$r.squared, tolerance = 1e-3)
})

test_that("empty compare set still produces a valid DGP", {
    set.seed(2)
    n <- 300
    x <- rnorm(n)
    y <- 1.5 * x + rnorm(n)
    dat <- data.frame(y = y, x = x)
    inp <- regsensitivity:::build_dgp_inputs(y ~ x, dat)
    dgp <- regsensitivity:::get_dgp(inp)
    expect_equal(dgp$n_compare, 0L)
    expect_equal(dgp$beta_short, dgp$beta_med, tolerance = 1e-12)
})

test_that("BFG2020 DGP values are stable", {
    inp <- regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare())
    dgp <- regsensitivity:::get_dgp(inp)
    expect_equal(dgp$n, 2036L)
    expect_equal(dgp$beta_med, 2.054759, tolerance = 1e-3)
    expect_gt(dgp$r_med, 0.10)
    expect_lt(dgp$r_med, 0.11)
})
