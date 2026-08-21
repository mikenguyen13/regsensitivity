## dmp.R --- Diegert, Masten and Poirier (2026) identified set
## and breakdown frontier.
##
## Sensitivity parameters:
##   rxbar : magnitude of selection on unobservables, X side
##   rybar : magnitude of selection on unobservables, Y side (+Inf = no constraint)
##   cbar  : largest correlation between comparison controls and unobservable
##   clow  : smallest such correlation (0 = A6 imposes nothing from below)
##
## Four regimes for the identified set, dispatched in `dmp_identified_set()`:
##   rxbar and rybar both past rmax -> (-Inf, +Inf), no computation
##   rybar = +Inf                   -> closed form via beta_deviation_ryinf()
##   rybar < +Inf, cbar = 0         -> closed form via quadratic inequality
##   rybar < +Inf, cbar > 0         -> DIRECT global optimization (nonconvex)

# Smallest rxbar at which zXbar(rxbar, clow, cbar) reaches `ztarget`.
#
# DMP (2026) appendix equation (S18) gives the largest z the sensitivity
# parameters permit as
#
#   zXbar(r, clow, cbar) = r * ||cov(W1, X)|| * sqrt(1 - a^2) / (1 - r * a),
#   a = max(min(r, cbar), clow)
#
# (`zmax()` below evaluates it). Everything the rybar = +Inf regime needs is
# a value of r at which zXbar hits some target: the identified set is
# unbounded once zXbar reaches sqrt(Var(X | W1)) (Theorem 3), and the
# hypothesis beta_long >= beta breaks down once zXbar reaches the z at which
# the deviation from beta_med first covers |beta_med - beta|.
#
# zXbar increases in r, so each target is reached once. Which of the three
# branches of `a` binds at the solution is decided by the interior branch:
# solving zXbar(r) = ztarget with a = r gives r = ztarget / sqrt(||cov||^2 +
# ztarget^2), and that value is the answer whenever it lands inside
# [clow, cbar]. Otherwise `a` sits at whichever endpoint of A6 is nearer and
# the equation is linear in r.
rxbar_at_zbar <- function(ztarget, cbar, s, clow = 0) {
    if (!is.finite(ztarget) || ztarget < 0 || !is.finite(cbar) ||
        !is.finite(s$covwx_norm_sq)) {
        return(NA_real_)
    }
    ssq <- max(s$covwx_norm_sq, 0)
    if (ssq <= 0) {
        # cov(W1, X) = 0: the calibration covariates say nothing about
        # selection, so no finite rxbar bounds it.
        return(POS_INF)
    }
    sx <- sqrt(ssq)
    r_interior <- ztarget / sqrt(ssq + ztarget^2)
    if (r_interior >= clow && r_interior <= cbar) {
        return(r_interior)
    }
    a <- if (r_interior < clow) clow else cbar
    denom <- sx * sqrt(max(1 - a^2, 0)) + ztarget * a
    if (!is.finite(denom) || denom <= 0) {
        return(POS_INF)
    }
    ztarget / denom
}

# Threshold rmax: the smallest rxbar at which the identified set becomes
# (-Inf, +Inf) once rybar is unrestricted, i.e. where zXbar^2 reaches
# Var(X | W1) (DMP Theorem 3).
#
# Through 0.1.2 this solved the cbar branch of the equation unconditionally,
# which overstated the threshold whenever cbar was below sqrt(1 - R2(X ~ W1))
# -- with cbar = 0.5 on the bundled data, calibrating against the ten
# geographic and climate covariates, it reported 1.48 where the identified
# set is in fact already unbounded at 1.19, so `regsen_bounds()` printed a
# large finite number in place of an infinite one across that range.
max_beta_bound <- function(c, s, clow = 0) {
    if (!is.finite(c) || !is.finite(s$k0) || !is.finite(s$var_x) ||
        s$var_x <= 0 || s$k0 < 0) {
        return(NA_real_)
    }
    rxbar_at_zbar(sqrt(s$k0), c, s, clow = clow)
}

max_beta_bound_vec <- function(cs, s, clow = 0) {
    vapply(cs, max_beta_bound, numeric(1), s = s, clow = clow)
}

# Cartesian product (or zipped) sensitivity-parameter triples.
format_dmp_sparams <- function(rxbar, rybar, cbar, product) {
    if (product) {
        g <- expand.grid(rxbar = rxbar, rybar = rybar, cbar = cbar,
                          KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
    } else {
        n <- max(length(rxbar), length(rybar), length(cbar))
        if (length(rxbar) == 1) rxbar <- rep(rxbar, n)
        if (length(rybar) == 1) rybar <- rep(rybar, n)
        if (length(cbar)  == 1) cbar  <- rep(cbar,  n)
        g <- data.frame(rxbar = rxbar, rybar = rybar, cbar = cbar)
    }
    list(rxbar = g$rxbar, rybar = g$rybar, cbar = g$cbar)
}

## ---------------------------------------------------------------------------
## Regime A: rybar = +Inf
## ---------------------------------------------------------------------------

# zXbar(rxbar, clow, cbar), DMP (2026) appendix equation (S18): the largest
# |z| the sensitivity parameters allow. The maximising ||c|| is rxbar itself
# where A6 permits it, and the nearer endpoint of [clow, cbar] otherwise.
#
# The expression holds below rmax, which is where the caller uses it: past
# rmax the supremum is infinite and `dmp_identified_set()` has already
# returned (-Inf, +Inf) without asking.
zmax <- function(c, rx, s, clow = 0) {
    cmax <- max(min(c, rx), clow)
    z <- sqrt(s$covwx_norm_sq) * rx * sqrt(max(1 - cmax^2, 0))
    z / (1 - rx * cmax)
}

# Maximum deviation |beta - beta_med| under rybar = +Inf, given zbar = z.
beta_deviation_ryinf <- function(z, s) {
    z_sq <- min(z^2, s$k0 - 1e-6)
    deviation_sq <- (z_sq * (s$k2 / s$k0 - (s$k1 / s$k0)^2)) / (s$k0 - z_sq)
    safe_sqrt(deviation_sq)
}

beta_bounds_ryinf <- function(sp, s) {
    z <- zmax(sp$cbar, sp$rxbar, s, clow = if (is.null(sp$clow)) 0 else sp$clow)
    dev <- beta_deviation_ryinf(z, s)
    c(s$beta_med - dev, s$beta_med + dev)
}

## ---------------------------------------------------------------------------
## Regime B: rybar finite, cbar = 0
## ---------------------------------------------------------------------------

# Cartesian "c" point (in covariance coordinates) corresponding to a polar
# (norm, angle) pair, mapped through the basis-change matrix on the dgp.
covw_polar_to_cartesian <- function(angle, norm, s) {
    coords_orth <- c(cos(angle), sin(angle)) * norm
    s$c_change_basis %*% coords_orth
}

# Expand a parameter vector p in [0,1]^3 into (z, cnorm, cterm, cx, cy).
# See DMP (2026) for the parametrization of the constraint set.
#
# p[2] sweeps ||c|| across the interval [clow, cbar] allowed by A6, p[3]
# sweeps its direction in the plane spanned by cov(W1, X) and cov(W1, Y), and
# p[1] sweeps z across the set A3 leaves feasible -- which is a union of two
# intervals once rxbar * ||c|| > 1, hence `pick_in_intervals()` rather than
# interpolation between a single pair of endpoints. z is NA when A3 rules out
# this (||c||, angle) pair entirely; every downstream quantity is then NA and
# the caller skips the point.
expand_dmp_params <- function(p, s, sp) {
    clow <- if (is.null(sp$clow)) 0 else sp$clow
    cnorm <- clow + p[2] * (sp$cbar - clow)
    cangle <- p[3] * pi * 2
    cxy <- covw_polar_to_cartesian(cangle, cnorm, s)
    cx <- cxy[1]; cy <- cxy[2]
    cterm_val <- 1 - cnorm^2
    cterm <- if (cterm_val < 0) NA_real_ else sqrt(cterm_val)

    ip_sigx_c <- cx * s$wxwx + cy * s$wxwy
    coef <- c(
        -cterm^2 * sp$rxbar^2 * s$wxwx,
         2 * cterm * sp$rxbar^2 * ip_sigx_c,
         1 - sp$rxbar^2 * cnorm^2
    )
    z_bound <- sqrt(max(s$k0, 0))
    z <- pick_in_intervals(quad_ineq_intervals(coef, c(-z_bound, z_bound)), p[1])
    list(z = z, cnorm = cnorm, cterm = cterm, cx = cx, cy = cy)
}

# Endogeneity-related quantities computed from the parameter expansion.
sig_endog_norm_sq <- function(p, s) {
    s$wxwx * (p$z^2 * p$cterm^2 - 2 * p$z * s$k0 * p$cterm * p$cx +
              s$k0^2 * p$cx^2) +
        2 * s$wxwy * s$k0 * p$cy * (s$k0 * p$cx - p$cterm * p$z) +
        s$wywy * p$cy^2 * s$k0^2
}

sig_ip <- function(p, s) {
    s$wxwx * s$beta_med * (s$k0 * p$cx - p$z * p$cterm) +
        s$wxwy * (p$z * p$cterm - s$k0 * p$cx + s$k1 * p$cy) -
        s$wywy * s$k0 * p$cy
}

rybar_quad_coef <- function(p, s, sp) {
    sen <- sig_endog_norm_sq(p, s)
    sip <- sig_ip(p, s)
    c(
        -sp$rybar^2 * p$z^2 * p$cterm^2 * s$gamma_med_norm_sq,
        -2 * sip * sp$rybar^2 * p$cterm * p$z,
         s$k0^2 - sp$rybar^2 * sen
    )
}

varx_bounds <- function(p, s) {
    # No feasible z at this (||c||, angle): the point contributes nothing.
    if (is.na(p$z)) {
        return(c(NA_real_, NA_real_))
    }
    if (p$z^2 >= s$k0) {
        return(c(NEG_INF, POS_INF))
    }
    dev_sq <- p$z^2 * (s$k2 / s$k0 - s$beta_med^2)
    dev_sq <- dev_sq / (s$k0 - p$z^2)
    if (is.na(dev_sq) || dev_sq < 0) {
        return(c(NA_real_, NA_real_))
    }
    dev <- sqrt(dev_sq)
    c(-dev, dev)
}

# Closed-form for cbar = 0 case.
beta_bounds_ryfinite_cbar_eq0 <- function(sp, s) {
    p_vec <- c(1, 0, 0)
    pexp <- expand_dmp_params(p_vec, s, sp)
    dev_bounds <- varx_bounds(pexp, s)
    coef <- rybar_quad_coef(pexp, s, sp)
    dev_bounds_1 <- quad_ineq_bounds(coef, dev_bounds)

    p_vec <- c(0, 0, 0)
    pexp <- expand_dmp_params(p_vec, s, sp)
    dev_bounds <- varx_bounds(pexp, s)
    coef <- rybar_quad_coef(pexp, s, sp)
    dev_bounds_2 <- quad_ineq_bounds(coef, dev_bounds)

    if (!any(is.na(dev_bounds)) &&
        !(identical(dev_bounds, c(NEG_INF, POS_INF)))) {
        lo <- min(c(dev_bounds_1, dev_bounds_2), na.rm = TRUE)
        hi <- max(c(dev_bounds_1, dev_bounds_2), na.rm = TRUE)
        c(lo + s$beta_med, hi + s$beta_med)
    } else {
        c(NEG_INF, POS_INF)
    }
}

## ---------------------------------------------------------------------------
## Quadratic inequality utility
## ---------------------------------------------------------------------------

# Solve  {x in [bounds[1], bounds[2]]  s.t.  Q(x) <= 0}
# where Q(x) = coef[1] + coef[2] * x + coef[3] * x^2, exactly.
#
# Returns the feasible set as a list of disjoint closed intervals in
# increasing order; an empty list means no feasible x.
#
# The solution set is a single interval only when Q is convex. It has TWO
# pieces whenever the leading coefficient is negative, since Q <= 0 then
# holds outside the roots rather than between them. Both callers below meet
# that case:
#
#   - the z constraint of A3 has leading coefficient 1 - rxbar^2 ||c||^2,
#     which turns negative exactly when rxbar * ||c|| > 1. Collapsing the two
#     pieces into their hull there admits the infeasible gap between the
#     roots, and the sampler in `expand_dmp_params()` then draws selection
#     equations that violate A3. That is what made the region
#     rxbar > rmax(cbar) > rybar unsafe to compute before this was fixed.
#   - the deviation constraint of A5 has leading coefficient
#     k0^2 - rybar^2 * ||...||^2. Here only the smallest and largest feasible
#     deviation are used, so the hull is what the caller wants -- see
#     `quad_ineq_bounds()`, which is the entry point for that case.
#
# Robustness notes:
#   - `coef` can carry NA/NaN when the upstream parameter expansion hits a
#     degenerate point, and `bounds` can be NA when `varx_bounds()` fails.
#     Either way the inequality cannot be evaluated: return no interval, and
#     let the caller treat the parameter point as infeasible.
#   - the leading coefficient is compared against a tolerance scaled by the
#     size of the coefficients, so a quadratic that is numerically linear is
#     solved as a linear one instead of dividing by a near-zero.
quad_ineq_intervals <- function(coef, bounds) {
    if (length(coef) < 3 || any(!is.finite(coef[1:3])) ||
        length(bounds) < 2 || any(is.na(bounds)) ||
        isTRUE(bounds[1] > bounds[2])) {
        return(list())
    }
    lo <- bounds[1]; hi <- bounds[2]
    a <- coef[3]; b <- coef[2]; cc <- coef[1]

    # Intersect [l, u] with [lo, hi], dropping the piece if it comes up empty.
    piece <- function(l, u) {
        l <- max(l, lo); u <- min(u, hi)
        if (l > u) NULL else list(c(l, u))
    }

    scale <- max(abs(coef[1:3]))
    if (scale == 0) return(list(c(lo, hi)))     # Q is identically zero
    tol <- 1e-14 * scale

    if (abs(a) <= tol) {                        # linear
        if (abs(b) <= tol) {
            return(if (cc <= 0) list(c(lo, hi)) else list())
        }
        xint <- -cc / b
        return(if (b > 0) piece(NEG_INF, xint) else piece(xint, POS_INF))
    }

    discrim <- b^2 - 4 * a * cc
    if (!is.finite(discrim)) return(list())

    if (a > 0) {                                # convex: feasible between roots
        if (discrim < 0) return(list())         # Q > 0 everywhere
        rts <- quadratic_real_roots(coef, discrim)
        if (any(is.na(rts))) return(list())
        return(piece(rts[1], rts[2]))
    }

    # concave: feasible outside the roots, so up to two pieces
    if (discrim < 0) return(list(c(lo, hi)))    # Q < 0 everywhere
    rts <- quadratic_real_roots(coef, discrim)
    if (any(is.na(rts))) return(list())
    c(piece(NEG_INF, rts[1]), piece(rts[2], POS_INF))
}

# Smallest and largest feasible x, i.e. the convex hull of
# `quad_ineq_intervals()`. NA endpoints mean the constraint is infeasible.
# This is the right summary wherever only the extremes of the feasible set
# matter (the deviation bounds); it is the wrong one wherever the set is
# sampled (see `pick_in_intervals()`).
quad_ineq_bounds <- function(coef, bounds) {
    ivs <- quad_ineq_intervals(coef, bounds)
    if (length(ivs) == 0) {
        return(c(NA_real_, NA_real_))
    }
    c(ivs[[1]][1], ivs[[length(ivs)]][2])
}

# Map u in [0, 1] onto a union of disjoint intervals, in proportion to their
# lengths, so that a sampler sweeping u covers the whole feasible set and
# nothing else. Degenerate (zero-length) pieces are still reachable: when the
# union has no length at all, u selects among the pieces by position.
# Returns NA when there is nothing to pick from.
pick_in_intervals <- function(ivs, u) {
    n <- length(ivs)
    if (n == 0) return(NA_real_)
    if (n == 1) return(ivs[[1]][1] + u * (ivs[[1]][2] - ivs[[1]][1]))
    lens <- vapply(ivs, function(v) v[2] - v[1], numeric(1))
    total <- sum(lens)
    if (!is.finite(total) || total <= 0) {
        k <- min(n, 1L + floor(u * n))
        return(ivs[[k]][1])
    }
    target <- u * total
    cum <- 0
    for (v in ivs) {
        l <- v[2] - v[1]
        if (target <= cum + l) return(v[1] + (target - cum))
        cum <- cum + l
    }
    ivs[[n]][2]
}

# Both real roots of coef[1] + coef[2] x + coef[3] x^2, ordered.
#
# Solved directly rather than through `real_roots()`, which goes via
# polyroot(): this sits inside the optimizer's objective and is evaluated a
# few thousand times per bound, where the general complex root finder costs
# more than the whole rest of the evaluation. The textbook formula is
# rearranged the usual way to avoid cancellation when b^2 dominates 4ac --
# one root from the addition that cannot cancel, the other from the product
# of the roots.
quadratic_real_roots <- function(coef, discrim) {
    if (!is.finite(discrim)) {
        return(c(NA_real_, NA_real_))
    }
    if (discrim < 0) {
        return(c(NEG_INF, POS_INF))
    }
    a <- coef[3]; b <- coef[2]; cc <- coef[1]
    if (a == 0) {
        if (b == 0) return(c(NA_real_, NA_real_))
        return(rep(-cc / b, 2))
    }
    q <- -0.5 * (b + if (b >= 0) sqrt(discrim) else -sqrt(discrim))
    r1 <- q / a
    r2 <- if (q != 0) cc / q else r1
    if (r1 <= r2) c(r1, r2) else c(r2, r1)
}

## ---------------------------------------------------------------------------
## Regime C: rybar finite, cbar > 0 - DIRECT global optimization
## ---------------------------------------------------------------------------

# `full_dev_bounds(p, s, sp)` returns the (low, high) deviation bounds at
# parameter point p. We minimise / maximise over [0,1]^3 with the DIRECT
# algorithm (nloptr::nl.opts NLOPT_GN_DIRECT_L).
full_dev_bounds <- function(p, s, sp) {
    pexp <- expand_dmp_params(p, s, sp)
    dev_bounds <- varx_bounds(pexp, s)
    coef <- rybar_quad_coef(pexp, s, sp)
    quad_ineq_bounds(coef, dev_bounds)
}

# Global search over [0,1]^3 followed by a local polish from the point the
# global search returned.
#
# DIRECT-L alone converges slowly on this objective: it brackets the optimum
# quickly but spends its remaining budget subdividing. Handing its answer to
# a derivative-free local search (Subplex, which tolerates the kinks left by
# the min/max over interval endpoints) buys about a decimal digit for a third
# of the cost of simply raising the DIRECT budget. With the settings below,
# results agree to within 3e-4 of a run twenty times as long.
dmp_minimize <- function(obj, maxiter, precision, polish) {
    lower <- rep(0, 3); upper <- rep(1, 3)
    res <- nloptr::nloptr(
        x0 = rep(0.5, 3), eval_f = obj,
        lb = lower, ub = upper,
        opts = list(algorithm = "NLOPT_GN_DIRECT_L",
                    maxeval = maxiter,
                    xtol_rel = precision)
    )
    if (polish <= 0 || !is.finite(res$objective)) {
        return(res$objective)
    }
    # DIRECT can return a coordinate a rounding error outside the box, which
    # nloptr rejects as a starting point.
    start <- clip(res$solution, 0, 1)
    loc <- nloptr::nloptr(
        x0 = start, eval_f = obj,
        lb = lower, ub = upper,
        opts = list(algorithm = "NLOPT_LN_SBPLX",
                    maxeval = polish,
                    xtol_rel = precision * 1e-2)
    )
    if (is.finite(loc$objective) && loc$objective < res$objective) {
        loc$objective
    } else {
        res$objective
    }
}

# `which` says which end of the identified set the caller needs. A breakdown
# search tests one end only, and skipping the other halves its work; the NA
# returned in the unused slot is never read.
beta_bounds_ryfinite_cbar_neq0 <- function(sp, s, maxiter = 1000L,
                                            precision = 1e-8,
                                            polish = 300L,
                                            which = c("both", "lower", "upper")) {
    which <- match.arg(which)
    # Mirror Stata's `direct_dev_bounds`:
    #   minimize=1: fval = -max(dev_bounds(p));    A := min fval = -overall_max_high
    #   minimize=0: fval =  min(dev_bounds(p));    B := min fval =  overall_min_low
    # Then identified set = [beta_med - overall_max_high, beta_med - overall_min_low]
    #                     = [beta_med + A,                 beta_med - B          ]
    obj_min <- function(p) {
        b <- suppressWarnings(full_dev_bounds(p, s, sp))
        if (any(is.na(b)) || any(is.nan(b))) return(POS_INF)
        -max(b)
    }
    obj_max <- function(p) {
        b <- suppressWarnings(full_dev_bounds(p, s, sp))
        if (any(is.na(b)) || any(is.nan(b))) return(POS_INF)
        min(b)
    }
    lo <- NA_real_; hi <- NA_real_
    if (which != "upper") {
        A <- dmp_minimize(obj_min, maxiter, precision, polish)
        lo <- if (is.finite(A)) A + s$beta_med else NEG_INF
    }
    if (which != "lower") {
        B <- dmp_minimize(obj_max, maxiter, precision, polish)
        hi <- if (is.finite(B)) -B + s$beta_med else POS_INF
    }
    if (which == "lower") return(c(lo, NA_real_))
    if (which == "upper") return(c(NA_real_, hi))
    c(min(lo, hi), max(lo, hi))
}

## ---------------------------------------------------------------------------
## Top-level: identified set
## ---------------------------------------------------------------------------

# Compute the identified set for every combination (or zipped triple, if
# product = FALSE) of (rxbar, rybar, cbar). Returns a data.frame with one
# row per combination and columns: rxbar, rybar, cbar, bmin, bmax.
dmp_identified_set <- function(rxbar, rybar, cbar, s, product = TRUE,
                                clow = 0) {
    sp <- format_dmp_sparams(rxbar, rybar, cbar, product)
    n <- length(sp$rxbar)
    out <- data.frame(
        rxbar = sp$rxbar, rybar = sp$rybar, cbar = sp$cbar,
        bmin = rep(NA_real_, n), bmax = rep(NA_real_, n)
    )
    for (i in seq_len(n)) {
        spi <- list(rxbar = sp$rxbar[i], rybar = sp$rybar[i],
                    cbar = sp$cbar[i], clow = min(clow, sp$cbar[i]))
        finite_threshold <- max_beta_bound(spi$cbar, s, clow = spi$clow)
        # finite_threshold may be NA at degenerate parameters; treat as Inf
        # for the threshold test (so we fall through to a regime computation
        # rather than returning (-Inf, +Inf) spuriously).
        ft <- if (is.na(finite_threshold)) Inf else finite_threshold
        infinite <- isTRUE(spi$rxbar > ft - 1e-7) &&
                    isTRUE(spi$rybar > ft - 1e-7)
        if (infinite) {
            bnd <- c(NEG_INF, POS_INF)
        } else if (is.finite(spi$rybar) && isTRUE(spi$cbar == 0)) {
            bnd <- beta_bounds_ryfinite_cbar_eq0(spi, s)
        } else if (is.finite(spi$rybar)) {
            bnd <- beta_bounds_ryfinite_cbar_neq0(spi, s)
        } else {
            bnd <- beta_bounds_ryinf(spi, s)
        }
        out$bmin[i] <- bnd[1]
        out$bmax[i] <- bnd[2]
    }
    out
}

## ---------------------------------------------------------------------------
## Breakdown point
## ---------------------------------------------------------------------------

# The z at which the identified set of the rybar = +Inf regime first reaches
# `beta`: the deviation from beta_med grows in |z| (Theorem 3), so inverting
# dev(z) = |beta_med - beta| gives the z the breakdown point is defined by.
breakdown_zbar <- function(beta, s) {
    if (!is.finite(beta) || !is.finite(s$beta_med) || !is.finite(s$k0) ||
        s$k0 <= 0) {
        return(NA_real_)
    }
    dev_sq <- (s$beta_med - beta)^2
    resid_var <- s$k2 / s$k0 - s$beta_med^2      # Var(Y | X, W1) / Var(X | W1)
    denom <- dev_sq + resid_var
    if (!is.finite(denom) || denom <= 0) {
        return(NA_real_)
    }
    safe_sqrt(dev_sq * s$k0 / denom)
}

# Breakdown point when cbar does not bind -- that is, the interior branch of
# `rxbar_at_zbar()`, which is also the breakdown point under cbar = 1.
breakdown_point_max <- function(beta, s) {
    dev_sq <- (beta - s$beta_med)^2
    bp_sq <- dev_sq * s$k0
    denom <- bp_sq + s$covwx_norm_sq *
        (s$k2 / s$k0 - 2 * beta * s$beta_med + beta^2)
    safe_sqrt(bp_sq / denom)
}

# Breakdown point for fixed [clow, cbar] -- closed form when rybar = +Inf.
#
# The `bfmax` argument earlier versions took was the cbar = 1 breakdown point,
# used to decide whether cbar binds; `rxbar_at_zbar()` now makes that decision
# from the same comparison and additionally handles a binding clow.
breakdown_point_dmp <- function(beta, c, lower_bound, s, clow = 0) {
    if (!is.finite(beta) || !is.finite(c) || !is.finite(s$beta_med)) {
        return(NA_real_)
    }
    # Hypothesis is already false at rx = 0 ? Return 0.
    if (lower_bound && beta >= s$beta_med) return(0)
    if (!lower_bound && beta <= s$beta_med) return(0)

    zb <- breakdown_zbar(beta, s)
    if (is.na(zb)) return(NA_real_)
    rxbar_at_zbar(zb, c, s, clow = clow)
}

# The end of the identified set that the hypothesis is tested against: its
# lower end for `beta_long >= beta`, its upper end for `beta_long <= beta`.
#
# With rybar finite the identified set is not symmetric around beta_med, so
# which end is tested matters. (Through 0.1.2 the lower end was used for both
# directions, which reported the wrong breakdown point for an upper-bound
# hypothesis.)
dmp_tested_bound <- function(rx, ry, c, clow, s, lower_bound,
                              maxiter = 1000L, polish = 300L) {
    sp <- list(rxbar = rx, rybar = ry, cbar = c, clow = clow)
    # A rybar_expr may hand back +Inf at some rxbar; that is the closed-form
    # regime, not a degenerate case of the optimizer's.
    bnd <- if (!is.finite(ry)) {
        row <- dmp_identified_set(rx, POS_INF, c, s, clow = clow)
        c(row$bmin[1], row$bmax[1])
    } else if (isTRUE(c == 0)) {
        beta_bounds_ryfinite_cbar_eq0(sp, s)
    } else {
        beta_bounds_ryfinite_cbar_neq0(
            sp, s, maxiter = maxiter, polish = polish,
            which = if (lower_bound) "lower" else "upper"
        )
    }
    if (lower_bound) bnd[1] else bnd[2]
}

# Breakdown point in rxbar when rybar is finite -- either a fixed value or a
# function of rxbar (`ry_expr`, e.g. the common-impact case rybar = rxbar).
#
# The identified set has no closed form here, so the breakdown point is the
# root of "distance from the tested bound to the hypothesised value", which
# decreases in rxbar. Two properties of the bracket matter:
#
#   - the upper end grows until the hypothesis actually fails. rmax(cbar),
#     which earlier versions used as a hard ceiling, bounds the breakdown
#     point only when rybar is unrestricted; with rybar finite the bound
#     stays finite past rmax and so can the breakdown point.
#   - if the hypothesis survives every rxbar up to `rx_cap`, the answer is
#     +Inf rather than the ceiling. That is the horizontal arm of the
#     breakdown frontier: once the impact of the unobservable on the outcome
#     is capped tightly enough, no amount of selection on the treatment side
#     overturns the conclusion.
breakdown_point_rx_idx <- function(beta, c, ry, lower_bound, s,
                                    ry_expr = NULL, clow = 0,
                                    start_hi = NA_real_, tol = 1e-4,
                                    rx_cap = 1e4,
                                    maxiter = 1000L, polish = 300L) {
    if (!is.finite(beta) || !is.finite(c) || !is.finite(s$beta_med)) {
        return(NA_real_)
    }
    if (lower_bound && beta >= s$beta_med) return(0)
    if (!lower_bound && beta <= s$beta_med) return(0)

    # Positive while the hypothesis holds, negative once it fails. Infinite
    # bounds are clamped so that a root finder can interpolate through them;
    # a bound the optimizer could not evaluate counts as "still holds", which
    # is the direction that does not silently shrink the reported robustness.
    big <- 1e6
    slack <- function(rx) {
        ryv <- if (is.null(ry_expr)) ry else ry_expr(rx)
        b <- dmp_tested_bound(rx, ryv, c, clow, s, lower_bound,
                               maxiter = maxiter, polish = polish)
        if (is.na(b)) return(big)
        v <- if (lower_bound) b - beta else beta - b
        clip(v, -big, big)
    }

    lo <- 0
    hi <- if (is.finite(start_hi) && start_hi > 0) start_hi else 1
    while (slack(hi) > 0) {
        lo <- hi
        hi <- hi * 2
        if (hi > rx_cap) return(POS_INF)
    }
    if (slack(lo) <= 0) return(lo)
    stats::uniroot(slack, lower = lo, upper = hi, tol = tol)$root
}

# Breakdown point in rybar at a fixed rxbar: the largest impact the omitted
# variable may have on the outcome before the hypothesis fails. This is the
# frontier DMP (2026) Theorem 4 characterizes, and the one their Figure 1
# plots -- the rxbar direction alone cannot draw the frontier's horizontal
# arm, where the hypothesis survives every rxbar and the rxbar breakdown
# point is +Inf.
#
# Case 2 of that theorem is the closed-form shortcut used first here: if the
# hypothesis already survives with rybar unrestricted, no finite rybar can
# overturn it.
breakdown_point_ry_idx <- function(beta, c, rx, lower_bound, s, clow = 0,
                                    tol = 1e-4, ry_cap = 1e4,
                                    maxiter = 1000L, polish = 300L) {
    if (!is.finite(beta) || !is.finite(c) || !is.finite(s$beta_med)) {
        return(NA_real_)
    }
    if (lower_bound && beta >= s$beta_med) return(0)
    if (!lower_bound && beta <= s$beta_med) return(0)

    unrestricted <- dmp_identified_set(rx, POS_INF, c, s, clow = clow)
    if (lower_bound && isTRUE(unrestricted$bmin[1] >= beta)) return(POS_INF)
    if (!lower_bound && isTRUE(unrestricted$bmax[1] <= beta)) return(POS_INF)

    big <- 1e6
    slack <- function(ry) {
        b <- dmp_tested_bound(rx, ry, c, clow, s, lower_bound,
                               maxiter = maxiter, polish = polish)
        if (is.na(b)) return(big)
        clip(if (lower_bound) b - beta else beta - b, -big, big)
    }

    lo <- 0
    hi <- 1
    while (slack(hi) > 0) {
        lo <- hi
        hi <- hi * 2
        if (hi > ry_cap) return(POS_INF)
    }
    if (slack(lo) <= 0) return(lo)
    stats::uniroot(slack, lower = lo, upper = hi, tol = tol)$root
}

# Breakdown frontier across one varying parameter (beta or cbar). Returns a
# data.frame with columns `index` (the varying value) and `breakdown` (rxbar).
dmp_breakdown_frontier <- function(beta, cs, ry = POS_INF, hyposign = ">",
                                    s, ry_expr = NULL, clow = 0) {
    if (length(beta) > 1) {
        cs <- rep(cs[1], length(beta))
        index <- beta
    } else {
        beta <- rep(beta[1], length(cs))
        index <- cs
    }
    # An equality hypothesis breaks down at whichever end of the identified
    # set can reach the hypothesised value; that is the lower end when the
    # value sits below beta_med and the upper end when it sits above.
    lower_bound <- if (identical(hyposign, "<")) {
        rep(FALSE, length(beta))
    } else if (identical(hyposign, "=")) {
        beta < s$beta_med
    } else {
        rep(TRUE, length(beta))
    }
    rx <- rep(NA_real_, length(beta))
    if (is.null(ry_expr) && is.infinite(ry)) {
        for (i in seq_along(beta)) {
            rx[i] <- breakdown_point_dmp(beta[i], cs[i], lower_bound[i], s,
                                          clow = clow)
        }
    } else {
        for (i in seq_along(beta)) {
            rx[i] <- breakdown_point_rx_idx(
                beta[i], cs[i], ry, lower_bound[i], s,
                ry_expr = ry_expr, clow = clow,
                start_hi = max_beta_bound(cs[i], s, clow = clow)
            )
        }
    }
    data.frame(index = index, breakdown = rx)
}

# Breakdown frontier in the rybar direction: rybar_bf(rxbar) at a fixed cbar.
# Returns a data.frame with columns `index` (the rxbar value) and `breakdown`
# (the rybar at which the hypothesis fails, possibly +Inf).
dmp_breakdown_frontier_ry <- function(beta, cbar, rxbar, hyposign = ">", s,
                                       clow = 0) {
    lower_bound <- if (identical(hyposign, "<")) {
        FALSE
    } else if (identical(hyposign, "=")) {
        beta < s$beta_med
    } else {
        TRUE
    }
    ry <- vapply(rxbar, function(rx) {
        breakdown_point_ry_idx(beta, cbar, rx, lower_bound, s, clow = clow)
    }, numeric(1))
    data.frame(index = rxbar, breakdown = ry)
}
