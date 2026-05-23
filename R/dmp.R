## dmp.R --- Diegert, Masten and Poirier (2026) identified set
## and breakdown frontier.
##
## Three sensitivity parameters:
##   rxbar : magnitude of selection on unobservables, X side
##   rybar : magnitude of selection on unobservables, Y side (+Inf = no constraint)
##   cbar  : maximum correlation between comparison controls and unobservable
##
## Three regimes for the identified set, dispatched in `dmp_identified_set()`:
##   rybar = +Inf                 -> closed-form via beta_deviation_ryinf()
##   rybar < +Inf, cbar = 0       -> closed form via quadratic inequality
##   rybar < +Inf, cbar > 0       -> DIRECT global optimization (nonconvex)

# Threshold r such that for rxbar >= r and rybar >= r the identified set
# becomes (-Inf, +Inf). Mirrors `max_beta_bound` in the Stata source.
#
# `c` is finite by user-input invariant (callers pass cbar from a numeric
# vector). `s$k0 / s$var_x` is guaranteed in [0, 1] by construction, but
# floating-point rounding can occasionally produce a value > 1 (and so a
# negative argument to the inner sqrt); we guard against that.
max_beta_bound <- function(c, s) {
    if (!is.finite(c) || !is.finite(s$k0) || !is.finite(s$var_x) ||
        s$var_x <= 0) {
        return(NA_real_)
    }
    ratio <- s$k0 / s$var_x
    if (ratio < 0) ratio <- 0
    rmax <- sqrt(ratio)
    if (isTRUE(c < rmax)) {
        r2medx <- 1 - rmax^2
        inner <- r2medx * (1 - c^2) / rmax
        if (!is.finite(inner) || inner < 0) {
            return(NA_real_)
        }
        denom <- c^2 - r2medx
        if (!is.finite(denom) || denom == 0) {
            return(NA_real_)
        }
        rmax <- (c - sqrt(inner)) / denom
    }
    rmax
}

max_beta_bound_vec <- function(cs, s) {
    vapply(cs, max_beta_bound, numeric(1), s = s)
}

# Returns TRUE if (rx, ry, c) combinations fall in the "not implemented" region
# of DMP (rxbar > rmax(c) > rybar).
dmp_sparam_unsafe <- function(rxbar, rybar, cbar, product, s) {
    sp <- format_dmp_sparams(rxbar, rybar, cbar, product)
    for (i in seq_along(sp$rxbar)) {
        rm <- max_beta_bound(sp$cbar[i], s)
        if (sp$rxbar[i] > rm && sp$rybar[i] < rm) {
            return(TRUE)
        }
    }
    FALSE
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

# zbar(c, rx) function from DMP (2026).
zmax <- function(c, rx, s) {
    cmax <- min(c, rx)
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
    z <- zmax(sp$cbar, sp$rxbar, s)
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
expand_dmp_params <- function(p, s, sp) {
    cnorm <- p[2] * sp$cbar
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
    z_bounds <- quad_ineq_bounds(coef, c(-z_bound, z_bound))
    z <- z_bounds[1] + p[1] * (z_bounds[2] - z_bounds[1])
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
    if (is.na(p$z) || p$z^2 >= s$k0) {
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
# where Q(x) = coef[1] + coef[2] * x + coef[3] * x^2.
# Returns the closed interval [lo, hi] of the feasible set, or NA endpoints
# if infeasible. Mirrors `quad_ineq_bounds` in the Stata source.
#
# Robustness notes:
#   - `coef` can be passed with NA/NaN values when the upstream parameter
#     expansion (`expand_dmp_params`) hits a degenerate point. In that case
#     we cannot evaluate the inequality; return NA endpoints.
#   - `bounds` can be NA when `varx_bounds` returns NA endpoints (e.g.
#     dev_sq < 0). Same handling.
#   - Every internal comparison is wrapped in isTRUE() / isFALSE() so that
#     a single NA never blows up an `if`. The Mac-vs-Windows discrepancy
#     observed in v0.1.0 came from nloptr exploring slightly different
#     parameter points on each platform, hitting these edge cases more
#     often on Windows.
quad_ineq_bounds <- function(coef, bounds) {
    if (length(coef) < 3 || any(!is.finite(coef[1:3])) ||
        length(bounds) < 2 || any(is.na(bounds))) {
        return(c(NA_real_, NA_real_))
    }
    a <- coef[3]; b <- coef[2]; c <- coef[1]
    discrim <- b^2 - 4 * a * c
    if (!is.finite(discrim)) {
        return(c(NA_real_, NA_real_))
    }
    roots <- quadratic_real_roots(coef, discrim)

    if (isTRUE(a > 0) && isTRUE(discrim >= 0)) {
        return(clip(roots, bounds[1], bounds[2]))
    } else if (isTRUE(a > 0) && isTRUE(discrim < 0)) {
        return(c(NA_real_, NA_real_))
    } else if (isTRUE(a == 0)) {
        if (isTRUE(b == 0)) {
            if (isTRUE(c <= 0)) return(bounds) else return(c(NA_real_, NA_real_))
        }
        xintercept <- -c / b
        if (isTRUE(b > 0)) {
            return(c(bounds[1], clip(xintercept, bounds[1], bounds[2])))
        } else {
            return(c(clip(xintercept, bounds[1], bounds[2]), bounds[2]))
        }
    } else if (isTRUE(discrim >= 0)) {
        # a < 0
        r1 <- roots[1]; r2 <- roots[2]
        b1 <- bounds[1]; b2 <- bounds[2]
        if (any(is.na(c(r1, r2, b1, b2)))) {
            return(c(NA_real_, NA_real_))
        }
        if (is.infinite(b1) && is.infinite(b2)) {
            return(bounds)
        }
        if (isTRUE(b1 <= r1) && isTRUE(b2 <= r1)) return(bounds)
        if (isTRUE(b1 <= r1) && isTRUE(b2 <  r2)) return(c(b1, r1))
        if (isTRUE(b1 <= r1) && isTRUE(b2 >= r2)) return(bounds)
        if (isTRUE(b1 <  r2) && isTRUE(b2 <  r2)) return(c(NA_real_, NA_real_))
        if (isTRUE(b1 <  r2) && isTRUE(b2 >= r2)) return(c(r2, b2))
        return(bounds)
    } else {
        # a < 0, discrim < 0  -- everywhere infeasible (Q always > 0)? Actually
        # the Stata code returns bounds here; preserved.
        return(bounds)
    }
}

quadratic_real_roots <- function(coef, discrim) {
    if (!is.finite(discrim)) {
        return(c(NA_real_, NA_real_))
    }
    if (discrim >= 0) {
        rts <- real_roots(coef)
        if (length(rts) == 0) return(c(NA_real_, NA_real_))
        if (length(rts) == 1) return(c(rts, rts))
        return(sort(rts))
    }
    c(NEG_INF, POS_INF)
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

beta_bounds_ryfinite_cbar_neq0 <- function(sp, s, maxiter = 200L,
                                            precision = 1e-8) {
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
    lower <- rep(0, 3); upper <- rep(1, 3)
    res_min <- nloptr::nloptr(
        x0 = rep(0.5, 3), eval_f = obj_min,
        lb = lower, ub = upper,
        opts = list(algorithm = "NLOPT_GN_DIRECT_L",
                    maxeval = maxiter,
                    xtol_rel = precision)
    )
    res_max <- nloptr::nloptr(
        x0 = rep(0.5, 3), eval_f = obj_max,
        lb = lower, ub = upper,
        opts = list(algorithm = "NLOPT_GN_DIRECT_L",
                    maxeval = maxiter,
                    xtol_rel = precision)
    )
    A <- res_min$objective
    B <- res_max$objective
    lo <- A + s$beta_med
    hi <- -B + s$beta_med
    if (!is.finite(lo) || !is.finite(hi)) {
        return(c(NEG_INF, POS_INF))
    }
    c(min(lo, hi), max(lo, hi))
}

## ---------------------------------------------------------------------------
## Top-level: identified set
## ---------------------------------------------------------------------------

# Compute the identified set for every combination (or zipped triple, if
# product = FALSE) of (rxbar, rybar, cbar). Returns a data.frame with one
# row per combination and columns: rxbar, rybar, cbar, bmin, bmax.
dmp_identified_set <- function(rxbar, rybar, cbar, s, product = TRUE) {
    sp <- format_dmp_sparams(rxbar, rybar, cbar, product)
    n <- length(sp$rxbar)
    out <- data.frame(
        rxbar = sp$rxbar, rybar = sp$rybar, cbar = sp$cbar,
        bmin = rep(NA_real_, n), bmax = rep(NA_real_, n)
    )
    for (i in seq_len(n)) {
        spi <- list(rxbar = sp$rxbar[i], rybar = sp$rybar[i], cbar = sp$cbar[i])
        finite_threshold <- max_beta_bound(spi$cbar, s)
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

# Breakdown point with cbar = 1 -- closed form.
breakdown_point_max <- function(beta, s) {
    dev_sq <- (beta - s$beta_med)^2
    bp_sq <- dev_sq * s$k0
    denom <- bp_sq + s$covwx_norm_sq *
        (s$k2 / s$k0 - 2 * beta * s$beta_med + beta^2)
    safe_sqrt(bp_sq / denom)
}

# Breakdown point for fixed cbar -- closed form when rybar = +Inf.
breakdown_point_dmp <- function(beta, c, bfmax, lower_bound, s) {
    if (!is.finite(beta) || !is.finite(c) || !is.finite(s$beta_med)) {
        return(NA_real_)
    }
    # Hypothesis is already false at rx = 0 ? Return 0.
    if (lower_bound && beta >= s$beta_med) return(0)
    if (!lower_bound && beta <= s$beta_med) return(0)
    if (!is.na(bfmax) && isTRUE(c >= bfmax)) return(bfmax)

    K1 <- s$k0 * (s$beta_med - beta)^2
    K2 <- s$k2 / s$k0 - 2 * s$beta_med * beta + beta^2
    A <- K1 * c^2 - (1 - c^2) * s$covwx_norm_sq * K2
    B <- K1 * c
    Ccoef <- K1
    disc <- B^2 - A * Ccoef
    if (!is.finite(disc) || disc < 0 || !is.finite(A) || A == 0) {
        return(NA_real_)
    }
    sqrt_disc <- sqrt(disc)
    root1 <- (B + sqrt_disc) / A
    root2 <- (B - sqrt_disc) / A
    if (isTRUE(root1 <= root2) && isTRUE(root1 >= 0)) {
        return(root1)
    }
    root2
}

# Breakdown point when rybar is a fixed finite scalar (bisection on rxbar).
breakdown_point_rx_idx_ry_fix <- function(beta, c, ry, bfmax, lower_bound, s,
                                            maxiter = 50, tol = 1e-4) {
    if (!is.finite(beta) || !is.finite(c) || !is.finite(bfmax) ||
        !is.finite(s$beta_med)) {
        return(NA_real_)
    }
    if (lower_bound && beta >= s$beta_med) return(0)
    if (!lower_bound && beta <= s$beta_med) return(0)

    rx_left <- 0
    rx_right <- bfmax
    rx_mid <- (rx_left + rx_right) / 2
    sp <- list(rxbar = rx_mid, rybar = ry, cbar = c)
    for (i in seq_len(maxiter)) {
        rx_mid <- (rx_left + rx_right) / 2
        sp$rxbar <- rx_mid
        if (isTRUE(c > 0)) {
            beta_mid <- beta_bounds_ryfinite_cbar_neq0(sp, s)[1]
        } else {
            beta_mid <- beta_bounds_ryfinite_cbar_eq0(sp, s)[1]
        }
        if (!is.na(beta_mid) && abs(beta_mid - beta) < tol) break
        if (is.na(beta_mid) || isTRUE(beta_mid > beta)) {
            rx_left <- rx_mid
        } else {
            rx_right <- rx_mid
        }
    }
    rx_mid
}

# Breakdown point when rybar is given as an expression of rxbar (currently:
# rybar = rxbar). `ry_expr` is the function rxbar -> rybar.
breakdown_point_rx_idx_ry_expr <- function(beta, c, ry_expr, bfmax,
                                            lower_bound, s,
                                            maxiter = 50, tol = 1e-4) {
    if (!is.finite(beta) || !is.finite(c) || !is.finite(bfmax) ||
        !is.finite(s$beta_med)) {
        return(NA_real_)
    }
    if (lower_bound && beta >= s$beta_med) return(0)
    if (!lower_bound && beta <= s$beta_med) return(0)

    rx_left <- 0
    rx_right <- bfmax
    rx_mid <- (rx_left + rx_right) / 2
    for (i in seq_len(maxiter)) {
        rx_mid <- (rx_left + rx_right) / 2
        ry_val <- ry_expr(rx_mid)
        sp <- list(rxbar = rx_mid, rybar = ry_val, cbar = c)
        if (isTRUE(c > 0)) {
            beta_mid <- beta_bounds_ryfinite_cbar_neq0(sp, s)[1]
        } else {
            beta_mid <- beta_bounds_ryfinite_cbar_eq0(sp, s)[1]
        }
        if (!is.na(beta_mid) && abs(beta_mid - beta) < tol) break
        if (is.na(beta_mid) || isTRUE(beta_mid > beta)) {
            rx_left <- rx_mid
        } else {
            rx_right <- rx_mid
        }
    }
    rx_mid
}

# Breakdown frontier across one varying parameter (beta or cbar). Returns a
# data.frame with columns `index` (the varying value) and `breakdown` (rxbar).
dmp_breakdown_frontier <- function(beta, cs, ry = POS_INF, hyposign = ">",
                                    s, ry_expr = NULL) {
    if (length(beta) > 1) {
        cs <- rep(cs[1], length(beta))
        index <- beta
    } else {
        beta <- rep(beta[1], length(cs))
        index <- cs
    }
    lower_bound <- hyposign == ">"
    rx <- rep(NA_real_, length(beta))
    if (is.null(ry_expr) && is.infinite(ry)) {
        for (i in seq_along(beta)) {
            bfmax <- breakdown_point_max(beta[i], s)
            rx[i] <- breakdown_point_dmp(beta[i], cs[i], bfmax, lower_bound, s)
        }
    } else if (is.null(ry_expr)) {
        for (i in seq_along(beta)) {
            bfmax <- max_beta_bound(cs[i], s)
            rx[i] <- breakdown_point_rx_idx_ry_fix(beta[i], cs[i], ry,
                                                    bfmax, lower_bound, s)
        }
    } else {
        for (i in seq_along(beta)) {
            bfmax <- max_beta_bound(cs[i], s)
            rx[i] <- breakdown_point_rx_idx_ry_expr(beta[i], cs[i], ry_expr,
                                                    bfmax, lower_bound, s)
        }
    }
    data.frame(index = index, breakdown = rx)
}
