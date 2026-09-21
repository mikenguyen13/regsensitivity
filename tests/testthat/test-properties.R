## Property tests: things that must hold on any data set, checked on random
## ones. Each simulated world carries an actual omitted variable W2, so the
## true beta_long and the true sensitivity parameters can be read off it and
## the package's bounds at exactly those parameters must contain beta_long.
## The invariance tests below are the checks a referee would run by hand:
## rescaling a variable must move the bounds the way the model says, and
## relabelling the covariates must not move them at all.

# A world with observed (W0, W1), an omitted W2 and known coefficients.
sim_world <- function(seed, n = 2000, k1 = 3, k0 = 2) {
    set.seed(seed)
    W0 <- matrix(rnorm(n * k0), n, k0)
    L  <- matrix(rnorm(k1 * k1), k1, k1)
    W1 <- matrix(rnorm(n * k1), n, k1) %*% L +
        W0 %*% matrix(runif(k0 * k1, -1, 1), k0, k1)
    W2 <- W1 %*% (rnorm(k1) * runif(1, 0, 1.5)) + W0 %*% rnorm(k0) +
        rnorm(n) * runif(1, 0.3, 2)
    pi1 <- rnorm(k1); pi2 <- rnorm(1) * runif(1, 0, 2)
    X  <- W0 %*% rnorm(k0) + W1 %*% pi1 + pi2 * W2 + rnorm(n) * runif(1, 0.5, 2)
    g1 <- rnorm(k1); g2 <- rnorm(1) * runif(1, 0, 2)
    Y  <- rnorm(1) * X + W0 %*% rnorm(k0) + W1 %*% g1 + g2 * W2 +
        rnorm(n) * runif(1, 0.5, 2)
    d <- data.frame(y = as.numeric(Y), x = as.numeric(X), W1, W0)
    names(d)[3:(2 + k1)] <- paste0("w1_", seq_len(k1))
    names(d)[(3 + k1):(2 + k1 + k0)] <- paste0("w0_", seq_len(k0))
    d$w2 <- as.numeric(W2)
    d
}

# The population quantities DMP (2026) define, computed in-sample by the
# same linear projections, with W0 partialled out of everything: r_X and
# r_Y from equations (2.1)-(2.2), c = R(W2 ~ W1 . W0) from A6, and the
# long-regression coefficient itself.
true_params <- function(d) {
    w1 <- grep("^w1_", names(d), value = TRUE)
    w0 <- grep("^w0_", names(d), value = TRUE)
    P <- function(v) stats::resid(stats::lm(v ~ ., data = d[w0]))
    W1r <- sapply(d[w1], P); W2r <- P(d$w2); Xr <- P(d$x); Yr <- P(d$y)
    fx <- stats::lm(Xr ~ W1r + W2r - 1)
    pi1 <- stats::coef(fx)[seq_len(ncol(W1r))]
    pi2 <- stats::coef(fx)[ncol(W1r) + 1]
    fy <- stats::lm(Yr ~ Xr + W1r + W2r - 1)
    g1 <- stats::coef(fy)[1 + seq_len(ncol(W1r))]
    g2 <- stats::coef(fy)[2 + ncol(W1r)]
    list(beta_long = unname(stats::coef(fy)[1]),
         rX = unname(stats::sd(pi2 * W2r) / stats::sd(W1r %*% pi1)),
         rY = unname(stats::sd(g2 * W2r) / stats::sd(W1r %*% g1)),
         c = sqrt(summary(stats::lm(W2r ~ W1r - 1))$r.squared),
         w1 = w1, w0 = w0,
         formula = stats::reformulate(c("x", w1, w0), response = "y"))
}

within <- function(v, lo, hi, tol = 1e-6) lo - tol <= v && v <= hi + tol

test_that("the rybar = Inf identified set contains the true beta_long", {
    for (s in 1:12) {
        d <- sim_world(s); tp <- true_params(d)
        eps <- 1e-6
        b <- regsen_bounds(tp$formula, d, compare = tp$w1,
                           rxbar = tp$rX * (1 + eps),
                           cbar = min(1, tp$c * (1 + eps)))$results
        expect_true(within(tp$beta_long, b$bmin, b$bmax),
                    label = sprintf("world %d: %.4f in [%.4f, %.4f]",
                                    s, tp$beta_long, b$bmin, b$bmax))
        # Two-sided A6 with clow = c is still a valid restriction.
        b2 <- regsen_bounds(tp$formula, d, compare = tp$w1,
                            rxbar = tp$rX * (1 + eps),
                            cbar = min(1, tp$c * (1 + eps)),
                            clow = max(0, tp$c * (1 - eps)))$results
        expect_true(within(tp$beta_long, b2$bmin, b2$bmax))
        # ... and tighter than one-sided.
        expect_true(b2$bmin >= b$bmin - 1e-8 && b2$bmax <= b$bmax + 1e-8)
    }
})

test_that("the finite-rybar identified set contains beta_long and nests", {
    skip_on_cran()
    for (s in 1:12) {
        d <- sim_world(s); tp <- true_params(d)
        eps <- 1e-6
        bA <- regsen_bounds(tp$formula, d, compare = tp$w1,
                            rxbar = tp$rX * (1 + eps),
                            cbar = min(1, tp$c * (1 + eps)))$results
        bC <- regsen_bounds(tp$formula, d, compare = tp$w1,
                            rxbar = tp$rX * (1 + eps),
                            rybar = tp$rY * (1 + eps),
                            cbar = min(1, tp$c * (1 + eps)))$results
        tol <- 1e-3 * max(1, abs(tp$beta_long))   # optimizer precision
        expect_true(within(tp$beta_long, bC$bmin, bC$bmax, tol),
                    label = sprintf("world %d: %.4f in [%.4f, %.4f]",
                                    s, tp$beta_long, bC$bmin, bC$bmax))
        expect_true(bC$bmin >= bA$bmin - tol && bC$bmax <= bA$bmax + tol)
    }
})

test_that("the rybar = Inf set is sharp: a search over omitted variables reaches it", {
    skip_on_cran()
    # Fixed observed data; many constructed W2 satisfying A3 and A6. The sup
    # of beta_long over them must stay inside the package's set and get
    # close to its ends. (A random search underestimates the sup, so the
    # closeness tolerance is loose; containment is exact.)
    set.seed(7)
    n <- 1500
    W1 <- matrix(rnorm(n * 3), n, 3) %*% matrix(rnorm(9), 3)
    X <- W1 %*% rnorm(3) + rnorm(n)
    Y <- 0.5 * X + W1 %*% rnorm(3) + rnorm(n)
    d <- data.frame(y = as.numeric(Y), x = as.numeric(X),
                    w1_1 = W1[, 1], w1_2 = W1[, 2], w1_3 = W1[, 3])
    f <- y ~ x + w1_1 + w1_2 + w1_3
    r <- function(v) stats::resid(stats::lm(v ~ W1))
    Xp <- r(X); Yp <- stats::resid(stats::lm(r(Y) ~ Xp))
    cbar <- 0.7
    dgp <- regsensitivity:::get_dgp(regsensitivity:::build_dgp_inputs(
        f, d, compare = c("w1_1", "w1_2", "w1_3")))
    # Inside rmax, where the set is bounded and there is something to reach.
    rxbar <- 0.6 * regsensitivity:::max_beta_bound(cbar, dgp)
    lo <- Inf; hi <- -Inf
    for (i in 1:1500) {
        u <- r(rnorm(1) * Xp + rnorm(1) * Yp + rnorm(1) * runif(1) * rnorm(n))
        w1part <- as.numeric(W1 %*% rnorm(3))
        lam <- runif(1)
        W2 <- lam * w1part / stats::sd(w1part) + (1 - lam) * u / stats::sd(u)
        fx <- stats::lm(X ~ W1 + W2)
        pi1 <- stats::coef(fx)[2:4]; pi2 <- stats::coef(fx)[5]
        rX <- stats::sd(pi2 * W2) / stats::sd(W1 %*% pi1)
        cc <- sqrt(summary(stats::lm(W2 ~ W1))$r.squared)
        if (rX <= rxbar && cc <= cbar) {
            bl <- stats::coef(stats::lm(Y ~ X + W1 + W2))[2]
            lo <- min(lo, bl); hi <- max(hi, bl)
        }
    }
    b <- regsen_bounds(f, d, compare = c("w1_1", "w1_2", "w1_3"),
                       rxbar = rxbar, cbar = cbar)$results
    bmed <- b$bmin + (b$bmax - b$bmin) / 2
    expect_true(lo >= b$bmin - 1e-8 && hi <= b$bmax + 1e-8)
    expect_gt((hi - bmed) / (b$bmax - bmed), 0.85)
    expect_gt((bmed - lo) / (bmed - b$bmin), 0.85)
})

test_that("bounds nest as each sensitivity parameter is relaxed", {
    d <- sim_world(3); tp <- true_params(d)
    # -Inf/+Inf endpoints are the widest possible, so a diff() through them
    # must not be read as a violation (it is NaN).
    nested <- function(r) {
        lo <- pmax(r$bmin, -1e300); hi <- pmin(r$bmax, 1e300)
        all(diff(lo) <= 1e-9) && all(diff(hi) >= -1e-9)
    }
    dgp <- regsensitivity:::get_dgp(regsensitivity:::build_dgp_inputs(
        tp$formula, d, compare = tp$w1))
    rmax <- regsensitivity:::max_beta_bound(1, dgp)
    # A grid that runs from a point, through the bounded region, past rmax.
    rx <- regsen_bounds(tp$formula, d, compare = tp$w1,
                        rxbar = rmax * seq(0, 1.5, 0.25), cbar = 0.5)$results
    expect_true(nested(rx))
    expect_equal(rx$bmin[1], rx$bmax[1])              # rxbar = 0: a point
    expect_true(any(is.finite(rx$bmin[-1])) && any(is.infinite(rx$bmin)))
    cb <- regsen_bounds(tp$formula, d, compare = tp$w1,
                        rxbar = 0.7 * rmax, cbar = seq(0, 1, 0.25))$results
    expect_true(nested(cb))
    expect_true(all(is.finite(cb$bmin)))
    cl <- do.call(rbind, lapply(c(0, 0.2, 0.4), function(clow) {
        regsen_bounds(tp$formula, d, compare = tp$w1, rxbar = 0.7 * rmax,
                      cbar = 0.5, clow = clow)$results
    }))
    expect_true(all(diff(cl$bmin) >= -1e-9) && all(diff(cl$bmax) <= 1e-9))
    ob <- regsen_bounds(tp$formula, d, compare = tp$w1, analysis = "oster",
                        delta = seq(0, 0.9, 0.1), delta_type = "bound")$results
    expect_true(nested(ob))
})

test_that("bounds always contain beta_med, and equal it at rxbar = 0", {
    for (s in 4:8) {
        d <- sim_world(s); tp <- true_params(d)
        res <- regsen_bounds(tp$formula, d, compare = tp$w1,
                             rxbar = c(0, 0.2, 0.5), cbar = c(0.3, 1))
        r <- res$results
        bm <- res$dgp$beta_med
        expect_true(all(r$bmin <= bm + 1e-9 & r$bmax >= bm - 1e-9))
        expect_equal(r$bmin[r$rxbar == 0], rep(bm, 2))
        expect_equal(r$bmax[r$rxbar == 0], rep(bm, 2))
    }
})

test_that("the rxbar breakdown point is where the bound crosses the hypothesis", {
    for (s in 9:12) {
        d <- sim_world(s); tp <- true_params(d)
        for (cbar in c(0.4, 1)) {
            bp <- regsen_breakdown(tp$formula, d, compare = tp$w1,
                                   cbar = cbar)$results$breakdown
            if (!is.finite(bp) || bp == 0) next
            bm <- regsen_bounds(tp$formula, d, compare = tp$w1, rxbar = bp,
                                cbar = cbar)$dgp$beta_med
            r <- regsen_bounds(tp$formula, d, compare = tp$w1,
                               rxbar = bp * c(0.999, 1, 1.001),
                               cbar = cbar)$results
            tested <- if (bm >= 0) r$bmin else -r$bmax
            expect_gt(tested[1], 0)
            expect_equal(tested[2], 0, tolerance = 1e-5)
            expect_lt(tested[3], 0)
        }
    }
})

test_that("rmax is where the set becomes unbounded", {
    d <- sim_world(13); tp <- true_params(d)
    dgp <- regsensitivity:::get_dgp(regsensitivity:::build_dgp_inputs(
        tp$formula, d, compare = tp$w1))
    for (cbar in c(0.2, 0.6, 1)) {
        rmax <- regsensitivity:::max_beta_bound(cbar, dgp)
        r <- regsen_bounds(tp$formula, d, compare = tp$w1,
                           rxbar = rmax * c(0.99, 1.01), cbar = cbar)$results
        expect_true(is.finite(r$bmin[1]) && is.finite(r$bmax[1]))
        expect_equal(c(r$bmin[2], r$bmax[2]), c(-Inf, Inf))
    }
})

test_that("bounds respond to rescaling as the model says", {
    d <- sim_world(14); tp <- true_params(d)
    args <- list(compare = tp$w1, rxbar = c(0.2, 0.4), rybar = c(Inf, 0.8),
                 cbar = 0.6)
    base <- do.call(regsen_bounds, c(list(tp$formula, d), args))$results
    tol <- 2e-3   # the finite-rybar rows go through the optimizer
    # Y * k scales the coefficient by k.
    dy <- d; dy$y <- 3 * dy$y
    ry <- do.call(regsen_bounds, c(list(tp$formula, dy), args))$results
    expect_equal(ry$bmin, 3 * base$bmin, tolerance = tol)
    expect_equal(ry$bmax, 3 * base$bmax, tolerance = tol)
    # X * k scales it by 1 / k.
    dx <- d; dx$x <- 4 * dx$x
    rx <- do.call(regsen_bounds, c(list(tp$formula, dx), args))$results
    expect_equal(rx$bmin, base$bmin / 4, tolerance = tol)
    expect_equal(rx$bmax, base$bmax / 4, tolerance = tol)
    # Shifting and rescaling a comparison covariate changes nothing, since
    # the sensitivity parameters are defined through variances of indices.
    dw <- d; dw$w1_2 <- 100 + 0.01 * dw$w1_2
    rw <- do.call(regsen_bounds, c(list(tp$formula, dw), args))$results
    expect_equal(rw$bmin, base$bmin, tolerance = tol)
    expect_equal(rw$bmax, base$bmax, tolerance = tol)
    # Neither does the order of the comparison covariates.
    f_perm <- stats::reformulate(c("x", rev(tp$w1), tp$w0), response = "y")
    rp <- regsen_bounds(f_perm, d, compare = rev(tp$w1), rxbar = c(0.2, 0.4),
                        rybar = c(Inf, 0.8), cbar = 0.6)$results
    expect_equal(rp$bmin, base$bmin, tolerance = tol)
    expect_equal(rp$bmax, base$bmax, tolerance = tol)
    # A control (W0) column: shift, rescale, or add a constant to X.
    dz <- d; dz$w0_1 <- -5 * dz$w0_1 + 2; dz$x <- dz$x + 10
    rz <- do.call(regsen_bounds, c(list(tp$formula, dz), args))$results
    expect_equal(rz$bmin, base$bmin, tolerance = tol)
    expect_equal(rz$bmax, base$bmax, tolerance = tol)
})

test_that("Oster's identified set behaves at its anchors", {
    d <- sim_world(15); tp <- true_params(d)
    # delta = 0: no selection, the set is beta_med.
    r0 <- regsen_bounds(tp$formula, d, compare = tp$w1, analysis = "oster",
                        delta = 0, r2long = 1)
    expect_equal(r0$results$beta1, r0$dgp$beta_med)
    # r2long = R2(medium): nothing left to explain, breakdown is +Inf.
    bk <- regsen_breakdown(tp$formula, d, compare = tp$w1, analysis = "oster",
                           r2long = r0$dgp$r_med)
    expect_equal(bk$results$breakdown, Inf)
    # Rescaling Y rescales the equality solutions; rescaling X inverts.
    grid <- list(analysis = "oster", delta = c(-0.5, 0.5), r2long = 0.9)
    base <- do.call(regsen_bounds, c(list(tp$formula, d, compare = tp$w1), grid))$results
    dy <- d; dy$y <- 2 * dy$y
    ry <- do.call(regsen_bounds, c(list(tp$formula, dy, compare = tp$w1), grid))$results
    expect_equal(ry$beta1, 2 * base$beta1)
    dx <- d; dx$x <- 2 * dx$x
    rx <- do.call(regsen_bounds, c(list(tp$formula, dx, compare = tp$w1), grid))$results
    expect_equal(rx$beta1, base$beta1 / 2)
})

test_that("the breakdown point is invariant to rescaling and relabelling", {
    d <- sim_world(16); tp <- true_params(d)
    bp <- function(dd, f = tp$formula, cmp = tp$w1) {
        c(dmp = regsen_breakdown(f, dd, compare = cmp, cbar = 0.7)$results$breakdown,
          oster = regsen_breakdown(f, dd, compare = cmp, analysis = "oster",
                                   r2long = 1)$results$breakdown)
    }
    base <- bp(d)
    dd <- d; dd$y <- 7 * dd$y; dd$x <- 0.3 * dd$x + 5; dd$w1_1 <- 50 - 2 * dd$w1_1
    expect_equal(bp(dd), base, tolerance = 1e-8)
    f_perm <- stats::reformulate(c("x", rev(tp$w1), rev(tp$w0)), response = "y")
    expect_equal(bp(d, f_perm, rev(tp$w1)), base, tolerance = 1e-8)
})
