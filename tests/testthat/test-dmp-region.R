# Tests for the region rxbar > rmax(cbar) > rybar, which the package refused
# to compute through 0.1.2, and for the pieces that made it computable: the
# exact feasible-set solver, the corrected rmax threshold, the rybar
# direction of the breakdown frontier, and the two-sided form of A6.

dgp_bfg <- function() {
    regsensitivity:::get_dgp(regsensitivity:::build_dgp_inputs(
        bfg_formula(), bfg(), compare = bfg_compare()))
}

## ---------------------------------------------------------------------------
## The quadratic solver
## ---------------------------------------------------------------------------

test_that("quad_ineq_intervals solves the convex case", {
    # x^2 - 1 <= 0  on [-3, 3]  ->  [-1, 1]
    ivs <- regsensitivity:::quad_ineq_intervals(c(-1, 0, 1), c(-3, 3))
    expect_length(ivs, 1L)
    expect_equal(ivs[[1]], c(-1, 1))
    # ... clipped by the bounds
    ivs <- regsensitivity:::quad_ineq_intervals(c(-1, 0, 1), c(0, 0.5))
    expect_equal(ivs[[1]], c(0, 0.5))
    # ... and empty when the roots fall outside the bounds
    expect_length(regsensitivity:::quad_ineq_intervals(c(-1, 0, 1), c(2, 3)), 0L)
    # no real roots: infeasible everywhere
    expect_length(regsensitivity:::quad_ineq_intervals(c(1, 0, 1), c(-3, 3)), 0L)
})

test_that("quad_ineq_intervals returns both pieces in the concave case", {
    # 1 - x^2 <= 0  on [-3, 3]  ->  [-3, -1] U [1, 3]
    ivs <- regsensitivity:::quad_ineq_intervals(c(1, 0, -1), c(-3, 3))
    expect_length(ivs, 2L)
    expect_equal(ivs[[1]], c(-3, -1))
    expect_equal(ivs[[2]], c(1, 3))
    # a single piece when the bounds only reach one of them
    ivs <- regsensitivity:::quad_ineq_intervals(c(1, 0, -1), c(-3, 0))
    expect_length(ivs, 1L)
    expect_equal(ivs[[1]], c(-3, -1))
    # empty when the bounds sit inside the infeasible gap
    expect_length(
        regsensitivity:::quad_ineq_intervals(c(1, 0, -1), c(-0.5, 0.5)), 0L)
    # concave with no real roots: feasible everywhere
    ivs <- regsensitivity:::quad_ineq_intervals(c(-1, 0, -1), c(-2, 2))
    expect_equal(ivs[[1]], c(-2, 2))
})

test_that("quad_ineq_intervals solves the linear and degenerate cases", {
    # 2x - 1 <= 0 on [-1, 1] -> [-1, 0.5]
    expect_equal(
        regsensitivity:::quad_ineq_intervals(c(-1, 2, 0), c(-1, 1))[[1]],
        c(-1, 0.5))
    # -2x - 1 <= 0 -> [-0.5, 1]
    expect_equal(
        regsensitivity:::quad_ineq_intervals(c(-1, -2, 0), c(-1, 1))[[1]],
        c(-0.5, 1))
    # constant
    expect_length(regsensitivity:::quad_ineq_intervals(c(1, 0, 0), c(0, 1)), 0L)
    expect_equal(
        regsensitivity:::quad_ineq_intervals(c(-1, 0, 0), c(0, 1))[[1]], c(0, 1))
    # unusable input
    expect_length(
        regsensitivity:::quad_ineq_intervals(c(NA, 0, 1), c(0, 1)), 0L)
})

test_that("pick_in_intervals covers a union in proportion to length", {
    ivs <- list(c(0, 1), c(3, 5))
    pick <- regsensitivity:::pick_in_intervals
    expect_equal(pick(ivs, 0), 0)
    expect_equal(pick(ivs, 1), 5)
    # the first piece holds a third of the total length
    expect_equal(pick(ivs, 1 / 3), 1)
    expect_equal(pick(ivs, 2 / 3), 4)
    # never lands in the gap
    us <- seq(0, 1, length.out = 101)
    zs <- vapply(us, function(u) pick(ivs, u), numeric(1))
    expect_false(any(zs > 1 & zs < 3))
    expect_true(is.na(pick(list(), 0.5)))
})

## ---------------------------------------------------------------------------
## Soundness: the sampler must not violate A3
## ---------------------------------------------------------------------------

test_that("the sampled z always satisfies the rxbar constraint", {
    s <- dgp_bfg()
    # rxbar well past rmax(1), where the feasible z set splits in two.
    sp <- list(rxbar = 3, rybar = 0.5, cbar = 1, clow = 0)
    grid <- expand.grid(p1 = seq(0, 1, length.out = 11),
                        p2 = seq(0, 1, length.out = 11),
                        p3 = seq(0, 1, length.out = 11))
    slack <- apply(grid, 1, function(p) {
        pe <- regsensitivity:::expand_dmp_params(as.numeric(p), s, sp)
        if (is.na(pe$z)) return(NA_real_)
        # p(z, c; rxbar) = rxbar^2 ||cov(W1,X) sqrt(1-|c|^2) - c z||^2 - z^2
        ip <- pe$cx * s$wxwx + pe$cy * s$wxwy
        nrm2 <- pe$cterm^2 * s$wxwx - 2 * pe$cterm * pe$z * ip +
            pe$z^2 * pe$cnorm^2
        sp$rxbar^2 * nrm2 - pe$z^2
    })
    slack <- slack[!is.na(slack)]
    expect_gt(length(slack), 0)
    expect_true(all(slack >= -1e-8))
})

## ---------------------------------------------------------------------------
## The identified set where the package used to refuse
## ---------------------------------------------------------------------------

test_that("bounds are finite and computable for rxbar > rmax(cbar) > rybar", {
    s <- dgp_bfg()
    rmax <- regsensitivity:::max_beta_bound(1, s)
    idset <- regsensitivity:::dmp_identified_set(
        rxbar = c(2, 4), rybar = 0.5, cbar = 1, s = s)
    expect_true(all(idset$rxbar > rmax))
    expect_true(all(is.finite(idset$bmin)))
    expect_true(all(is.finite(idset$bmax)))
    expect_true(all(idset$bmin < s$beta_med))
    expect_true(all(idset$bmax > s$beta_med))
    # and through the public entry point, which used to raise an error here
    b <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                       cbar = 1, rxbar = 2, rybar = 0.5)
    expect_true(is.finite(b$results$bmin))
    expect_equal(b$results$bmin, idset$bmin[1], tolerance = 1e-6)
})

test_that("bounds match a direct search over the constraint set", {
    s <- dgp_bfg()
    # An independent implementation of DMP (2026) Theorem 5, written from the
    # constraints rather than from R/dmp.R: sweep (z, ||c||, angle) on a grid,
    # keep the points A3 allows, and take the extremes of the deviations A5
    # allows there. A grid can only undercover, so it is a lower bound on the
    # true bounds; the package must not come out inside it.
    brute <- function(rx, ry, cb) {
        bm <- s$beta_med; k0 <- s$k0
        g_g <- s$wywy - 2 * bm * s$wxwy + bm^2 * s$wxwx
        g_sx <- s$wxwy - bm * s$wxwx
        nx <- sqrt(s$wxwx); ny <- sqrt(max(s$wywy - s$wxwy^2 / s$wxwx, 0))
        z <- sqrt(k0) * tanh(seq(-5, 5, length.out = 400))
        dmax <- sqrt(pmax(z^2 * (s$k2 / k0 - bm^2) / (k0 - z^2), 0))
        lo <- Inf; hi <- -Inf
        for (cn in seq(0, cb, length.out = 30)) {
            ct <- sqrt(max(1 - cn^2, 0))
            for (ang in seq(0, 2 * pi, length.out = 90)) {
                csx <- cn * cos(ang) * nx
                csy <- cn * cos(ang) * s$wxwy / nx + cn * sin(ang) * ny
                keep <- rx^2 * (ct^2 * s$wxwx - 2 * ct * z * csx +
                                z^2 * cn^2) - z^2 >= 0
                if (!any(keep)) next
                zz <- z[keep]; dd <- dmax[keep]
                sen <- zz^2 * ct^2 * s$wxwx - 2 * zz * ct * k0 * csx +
                    k0^2 * cn^2
                sip <- zz * ct * g_sx - k0 * (csy - bm * csx)
                # Deviations A5 allows at each (z, c), from the quadratic
                # d^2 <= rybar^2 ||z sqrt(1-|c|^2) gamma + d (...)||^2 / k0^2.
                aa <- k0^2 - ry^2 * sen
                bb <- -2 * sip * ry^2 * ct * zz
                cc <- -ry^2 * zz^2 * ct^2 * g_g
                disc <- bb^2 - 4 * aa * cc
                ok <- disc >= 0
                r1 <- rep(NA_real_, length(zz)); r2 <- r1
                r1[ok] <- (-bb[ok] - sqrt(disc[ok])) / (2 * aa[ok])
                r2[ok] <- (-bb[ok] + sqrt(disc[ok])) / (2 * aa[ok])
                rl <- pmin(r1, r2); rh <- pmax(r1, r2)
                # convex (aa > 0): feasible between the roots
                cx <- aa > 0 & ok
                l <- pmax(rl[cx], -dd[cx]); h <- pmin(rh[cx], dd[cx])
                good <- l <= h
                if (any(good)) { lo <- min(lo, l[good]); hi <- max(hi, h[good]) }
                # concave (aa < 0): feasible outside the roots, so an endpoint
                # of [-dmax, dmax] is feasible unless it lies in the gap
                cv <- which(aa < 0)
                if (length(cv)) {
                    lowend <- ifelse(!ok[cv] | -dd[cv] <= rl[cv], -dd[cv],
                                     ifelse(dd[cv] >= rh[cv],
                                            pmax(rh[cv], -dd[cv]), NA))
                    highend <- ifelse(!ok[cv] | dd[cv] >= rh[cv], dd[cv],
                                      ifelse(-dd[cv] <= rl[cv],
                                             pmin(rl[cv], dd[cv]), NA))
                    if (any(is.finite(lowend))) {
                        lo <- min(lo, min(lowend, na.rm = TRUE))
                    }
                    if (any(is.finite(highend))) {
                        hi <- max(hi, max(highend, na.rm = TRUE))
                    }
                }
            }
        }
        c(bm - hi, bm - lo)
    }
    for (cfg in list(c(2, 0.5), c(4, 0.4))) {
        ref <- brute(cfg[1], cfg[2], 1)
        got <- regsensitivity:::dmp_identified_set(
            rxbar = cfg[1], rybar = cfg[2], cbar = 1, s = s)
        expect_equal(got$bmin, ref[1], tolerance = 0.01)
        expect_equal(got$bmax, ref[2], tolerance = 0.01)
    }
})

test_that("bounds widen monotonically in rxbar across rmax", {
    s <- dgp_bfg()
    rmax <- regsensitivity:::max_beta_bound(1, s)
    rxs <- c(rmax * c(0.5, 0.9, 0.99), rmax * c(1.01, 1.1, 2, 4))
    idset <- regsensitivity:::dmp_identified_set(
        rxbar = rxs, rybar = 0.5, cbar = 1, s = s)
    w <- idset$bmax - idset$bmin
    expect_true(all(is.finite(w)))
    expect_true(all(diff(w) >= -0.02))

    # No jump at the threshold the package used to refuse to cross. The width
    # grows steeply there, so the step has to be small for the test to be
    # about continuity rather than about slope.
    edge <- regsensitivity:::dmp_identified_set(
        rxbar = rmax * c(0.9999, 1.0001), rybar = 0.5, cbar = 1, s = s)
    we <- edge$bmax - edge$bmin
    expect_lt(abs(we[2] - we[1]), 0.01 * we[1])
})

## ---------------------------------------------------------------------------
## rmax
## ---------------------------------------------------------------------------

test_that("rmax is where zXbar reaches sqrt(Var(X | W1))", {
    s <- dgp_bfg()
    for (cb in c(0.1, 0.3, 0.5, 0.8, 1)) {
        target <- stats::uniroot(
            function(rx) regsensitivity:::zmax(cb, rx, s)^2 - s$k0,
            c(1e-8, min(1 / cb - 1e-9, 100)), tol = 1e-12)$root
        expect_equal(regsensitivity:::max_beta_bound(cb, s), target,
                     tolerance = 1e-6)
    }
})

test_that("the identified set is unbounded from rmax onwards", {
    s <- dgp_bfg()
    for (cb in c(0.5, 1)) {
        rmax <- regsensitivity:::max_beta_bound(cb, s)
        below <- regsensitivity:::dmp_identified_set(
            rxbar = rmax * 0.99, rybar = Inf, cbar = cb, s = s)
        at <- regsensitivity:::dmp_identified_set(
            rxbar = rmax * c(1, 1.05, 1.5), rybar = Inf, cbar = cb, s = s)
        expect_true(all(is.finite(unlist(below[c("bmin", "bmax")]))))
        expect_true(all(is.infinite(at$bmin)))
        expect_true(all(is.infinite(at$bmax)))
    }
})

## ---------------------------------------------------------------------------
## Breakdown frontier: both directions
## ---------------------------------------------------------------------------

test_that("the rxbar breakdown point is +Inf below the frontier's asymptote", {
    s <- dgp_bfg()
    # rybar small enough that no amount of selection on treatment overturns
    # the sign, which earlier versions clipped to rmax(cbar) instead.
    v <- regsensitivity:::dmp_breakdown_frontier(0, 1, ry = 0.2, s = s)
    expect_true(is.infinite(v$breakdown))
})

test_that("the rxbar breakdown point can exceed rmax(cbar)", {
    s <- dgp_bfg()
    rmax <- regsensitivity:::max_beta_bound(1, s)
    v <- regsensitivity:::dmp_breakdown_frontier(0, 1, ry = 0.62, s = s)
    expect_true(is.finite(v$breakdown))
    expect_gt(v$breakdown, rmax)
    # the bound really does cross zero there
    lo <- regsensitivity:::dmp_identified_set(
        rxbar = v$breakdown * c(0.98, 1.02), rybar = 0.62, cbar = 1, s = s)
    expect_gt(lo$bmin[1], 0)
    expect_lt(lo$bmin[2], 0)
})

test_that("the rybar frontier traces the same curve as the rxbar breakdown", {
    d <- bfg(); f <- bfg_formula(); w1 <- bfg_compare()
    bk <- regsen_breakdown(f, d, compare = w1, cbar = 1, direction = "rybar",
                           rxbar = c(0.5, 1.2, 3))
    expect_equal(bk$results$index, c(0.5, 1.2, 3))
    # Below the rxbar breakdown point the conclusion survives every rybar.
    expect_true(is.infinite(bk$results$breakdown[1]))
    ry <- bk$results$breakdown[2:3]
    expect_true(all(is.finite(ry)))
    expect_true(ry[1] > ry[2])          # frontier decreasing in rxbar
    # Duality: at (rxbar, frontier) the tested bound sits at the hypothesis.
    for (i in 2:3) {
        b <- regsen_bounds(f, d, compare = w1, cbar = 1,
                           rxbar = bk$results$index[i],
                           rybar = bk$results$breakdown[i])
        expect_equal(b$results$bmin, 0, tolerance = 1e-3)
    }
})

test_that("an upper-bound hypothesis breaks down at the upper bound", {
    d <- bfg(); f <- bfg_formula(); w1 <- bfg_compare()
    s <- dgp_bfg()
    # Beta(medium) is positive here, so "beta_long < 4" is the hypothesis the
    # upper end of the identified set threatens.
    bk <- regsen_breakdown(f, d, compare = w1, cbar = 1, rybar = 1,
                           beta = bnd_ub(4))
    bp <- bk$results$breakdown
    expect_true(is.finite(bp))
    b <- regsen_bounds(f, d, compare = w1, cbar = 1, rybar = 1,
                       rxbar = bp * c(0.98, 1.02))
    expect_lt(b$results$bmax[1], 4)
    expect_gt(b$results$bmax[2], 4)
})

## ---------------------------------------------------------------------------
## Two-sided A6
## ---------------------------------------------------------------------------

test_that("clow tightens the bounds and raises the breakdown point", {
    d <- bfg(); f <- bfg_formula(); w1 <- bfg_compare()
    bp <- vapply(c(0, 0.95, 0.99), function(cl) {
        regsen_breakdown(f, d, compare = w1, cbar = 1,
                         clow = cl)$results$breakdown
    }, numeric(1))
    expect_true(all(diff(bp) > 0))

    width <- vapply(c(0, 0.95, 0.99), function(cl) {
        r <- regsen_bounds(f, d, compare = w1, cbar = 1, clow = cl,
                           rxbar = 0.9)$results
        r$bmax - r$bmin
    }, numeric(1))
    expect_true(all(diff(width) < 0))

    # the finite-rybar path responds to clow too
    wide <- regsen_bounds(f, d, compare = w1, cbar = 1, clow = 0,
                          rxbar = 0.9, rybar = 1)$results
    tight <- regsen_bounds(f, d, compare = w1, cbar = 1, clow = 0.99,
                           rxbar = 0.9, rybar = 1)$results
    expect_lt(tight$bmax - tight$bmin, wide$bmax - wide$bmin)
})

test_that("clow is validated against cbar", {
    d <- bfg(); f <- bfg_formula(); w1 <- bfg_compare()
    expect_error(regsen_bounds(f, d, compare = w1, cbar = 0.5, clow = 0.8),
                 "must not exceed")
    expect_error(regsen_bounds(f, d, compare = w1, clow = -1), "\\[0, 1\\]")
    expect_error(regsen_bounds(f, d, compare = w1, clow = c(0.1, 0.2)),
                 "single finite number")
})
