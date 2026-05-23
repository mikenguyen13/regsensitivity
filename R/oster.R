## oster.R --- Oster (2019) identified set and breakdown frontier,
## with the Masten-Poirier (2026) extensions for finite-OVB constraints.
##
## Two sensitivity parameters:
##   delta  : relative selection on observables vs unobservables
##   r2long : R-squared of the infeasible long regression
## Optional:
##   maxovb : maximum absolute value of the omitted-variable bias

## ---------------------------------------------------------------------------
## Identified set, delta = d (equal): solve the cubic in beta_long.
## ---------------------------------------------------------------------------

# Cubic coefficients (eq (3.3), Oster 2019, page 193).
# Returns the (up to three) real solutions for beta_long.
oster_idset_scalar <- function(delta, r_max, s) {
    c0 <- (r_max - s$r_med) * s$var_y * delta *
        (s$beta_short - s$beta_med) * s$var_x
    c1 <- delta * (r_max - s$r_med) * s$var_y * (s$var_x - s$var_x_resid) -
        (s$r_med - s$r_short) * s$var_y * s$var_x_resid -
        s$var_x * s$var_x_resid * (s$beta_short - s$beta_med)^2
    c2 <- s$var_x_resid * (s$beta_short - s$beta_med) * s$var_x * (delta - 2)
    c3 <- (delta - 1) * (s$var_x_resid * s$var_x - s$var_x_resid^2)

    rts <- real_roots(c(c0, c1, c2, c3))
    sols <- s$beta_med - rts

    if (length(rts) == 0 || length(s$gamma_med) == 0) {
        return(sols)
    }

    # Remove the spurious root for which gamma_med + root * pi_med == 0.
    # See the Stata source notes about the tolerance: we allow 2 extra digits
    # of slack on top of machine epsilon for the worst-conditioned input.
    keep <- logical(length(rts))
    for (i in seq_along(rts)) {
        ref <- max(abs(rts[i] * s$pi_med), abs(s$gamma_med))
        tol <- .Machine$double.eps * max(ref, 1) * 1e2
        check <- sqrt(sum((s$gamma_med + rts[i] * s$pi_med)^2))
        keep[i] <- check >= tol
    }
    sols[keep]
}

# Inverse: given a target value of beta_long, return the unique delta that
# would place it in the identified set, holding r_max fixed.
oster_delta <- function(beta, r_max, s) {
    if (abs(r_max - s$r_med) < 1e-7) return(POS_INF)
    bm <- s$beta_med
    bs <- s$beta_short
    vxr <- s$var_x_resid
    vx  <- s$var_x
    vy  <- s$var_y

    num <- (bm - beta) * (s$r_med - s$r_short) * vy * vxr +
           (bm - beta) * vx * vxr * (bs - bm)^2 +
           2 * (bm - beta)^2 * (vxr * (bs - bm) * vx) +
           (bm - beta)^3 * (vxr * vx - vxr^2)

    denom <- (r_max - s$r_med) * vy * (bs - bm) * vx +
             (bm - beta) * (r_max - s$r_med) * vy * (vx - vxr) +
             (bm - beta)^2 * (vxr * (bs - bm) * vx) +
             (bm - beta)^3 * (vxr * vx - vxr^2)

    num / denom
}

## ---------------------------------------------------------------------------
## Identified set, |delta| <= d (bound)
## ---------------------------------------------------------------------------

# For each value of delta and r_max, return a closed interval [bmin, bmax]
# of feasible beta_long values, capped by maxovb when supplied.
oster_idset_bound_scalar <- function(delta, r_max, maxovb, s) {
    if (delta >= 1) {
        return(c(NEG_INF, POS_INF))
    }
    sols1 <- oster_idset_scalar(delta, r_max, s)
    sols2 <- oster_idset_scalar(-delta, r_max, s)
    all_sols <- c(sols1, sols2)
    if (length(all_sols) == 0) {
        return(c(NA_real_, NA_real_))
    }
    bmin <- min(all_sols, na.rm = TRUE)
    bmax <- max(all_sols, na.rm = TRUE)
    if (!is.na(maxovb) && maxovb >= 0) {
        if (abs(bmin - s$beta_med) > maxovb) bmin <- s$beta_med - maxovb
        if (abs(bmax - s$beta_med) > maxovb) bmax <- s$beta_med + maxovb
    }
    c(bmin, bmax)
}

# Full Oster identified set sweep -- delta = d (equal).
# Returns a data.frame with columns: delta, r2long, beta1, beta2, beta3.
oster_idset_eq <- function(deltas, r2long, maxovb, s) {
    n <- length(deltas) * length(r2long)
    out <- data.frame(
        delta = rep(deltas, times = length(r2long)),
        r2long = rep(r2long, each = length(deltas)),
        beta1 = NA_real_, beta2 = NA_real_, beta3 = NA_real_
    )
    for (j in seq_len(nrow(out))) {
        sols <- oster_idset_scalar(out$delta[j], out$r2long[j], s)
        if (!is.na(maxovb) && maxovb >= 0 && length(sols)) {
            ovb <- abs(s$beta_med - sols)
            sols <- sols[ovb < maxovb]
        }
        if (length(sols) > 0) sols <- sort(sols)
        if (length(sols) >= 1) out$beta1[j] <- sols[1]
        if (length(sols) >= 2) out$beta2[j] <- sols[2]
        if (length(sols) >= 3) out$beta3[j] <- sols[3]
    }
    out
}

# Full Oster identified set sweep -- |delta| <= d (bound).
# Returns a data.frame: delta, r2long, bmin, bmax.
oster_idset_bound <- function(deltas, r2long, maxovb, s) {
    out_all <- vector("list", length(r2long))
    for (i in seq_along(r2long)) {
        r <- r2long[i]
        bmins <- numeric(length(deltas))
        bmaxs <- numeric(length(deltas))
        for (j in seq_along(deltas)) {
            ab <- oster_idset_bound_scalar(deltas[j], r, maxovb, s)
            bmins[j] <- ab[1]; bmaxs[j] <- ab[2]
        }
        bmins <- cummin_inf(bmins)
        bmaxs <- cummax_neg_inf(bmaxs)
        out_all[[i]] <- data.frame(delta = deltas, r2long = r,
                                    bmin = bmins, bmax = bmaxs)
    }
    do.call(rbind, out_all)
}

## ---------------------------------------------------------------------------
## Breakdown frontier
## ---------------------------------------------------------------------------

# Breakdown delta for an equality hypothesis Beta = beta(value).
# Returns +Inf when no finite delta makes the hypothesis fail.
oster_breakdown_eq <- function(r2max, beta, maxovb, s) {
    n <- max(length(beta), length(r2max), length(maxovb))
    if (length(beta)   == 1) beta   <- rep(beta,   n)
    if (length(r2max)  == 1) r2max  <- rep(r2max,  n)
    if (length(maxovb) == 1) maxovb <- rep(maxovb, n)

    # The index column is whichever vector actually varies.
    if (length(unique(maxovb)) > 1) {
        index <- maxovb
    } else if (length(unique(r2max)) > 1) {
        index <- r2max
    } else {
        index <- beta
    }

    delta <- rep(NA_real_, n)
    for (i in seq_len(n)) {
        if (!is.na(maxovb[i]) && maxovb[i] >= 0 &&
            abs(s$beta_med - beta[i]) > maxovb[i]) {
            delta[i] <- POS_INF
        } else {
            delta[i] <- oster_delta(beta[i], r2max[i], s)
        }
    }
    data.frame(index = index, breakdown = delta)
}

# Breakdown delta for an inequality hypothesis Beta > or < beta(value).
# Find the smallest |delta| such that some beta on the wrong side of the
# hypothesis is in the identified set.
oster_breakdown_bound_scalar <- function(beta, r_max, ovb_bound, lower_bound, s) {
    if (abs(r_max - s$r_med) < 1e-7) return(POS_INF)

    bm <- s$beta_med; bs <- s$beta_short
    vxr <- s$var_x_resid; vx <- s$var_x; vy <- s$var_y

    # Delta(beta_bias) is a ratio of two cubics in `beta_bias = bm - beta_long`.
    dcoef <- c(
        (r_max - s$r_med) * vy * (bs - bm) * vx,
        (r_max - s$r_med) * vy * (vx - vxr),
        vxr * (bs - bm) * vx,
        vxr * vx - vxr^2
    )
    ncoef <- c(
        0,
        (s$r_med - s$r_short) * vy * vxr + vx * vxr * (bs - bm)^2,
        2 * vxr * (bs - bm) * vx,
        vxr * vx - vxr^2
    )

    dcoef <- polymult(dcoef, dcoef)
    ncoef <- polymult(ncoef, ncoef)

    derivn <- polymult(polyderiv(ncoef, 1), dcoef)
    derivd <- polymult(polyderiv(dcoef, 1), -ncoef)
    deriv <- polyadd(derivn, derivd)

    critpoints <- real_roots(deriv)
    if (lower_bound) {
        critpoints <- critpoints[critpoints > bm - beta]
    } else {
        critpoints <- critpoints[critpoints < bm - beta]
    }
    checkpoints <- c(critpoints, bm - beta)

    if (!is.na(ovb_bound) && ovb_bound >= 0) {
        checkpoints <- checkpoints[abs(checkpoints) < ovb_bound]
        if (lower_bound && bm - ovb_bound < beta) {
            checkpoints <- c(checkpoints, ovb_bound)
        } else if (lower_bound && bm - ovb_bound >= beta) {
            return(POS_INF)
        } else if (!lower_bound && bm + ovb_bound > beta) {
            checkpoints <- c(checkpoints, -ovb_bound)
        } else if (!lower_bound && bm + ovb_bound <= beta) {
            return(POS_INF)
        }
    }

    if (length(checkpoints) == 0) return(POS_INF)

    deltas_abs <- vapply(checkpoints, function(cp) {
        abs(oster_delta(bm - cp, r_max, s))
    }, numeric(1))

    delta_abs <- min(deltas_abs, na.rm = TRUE)
    if (is.na(ovb_bound) || ovb_bound < 0) {
        delta_abs <- min(delta_abs, 1)
    }
    delta_abs
}

oster_breakdown_bound <- function(r2max, beta, maxovb, hyposign, s) {
    n <- max(length(beta), length(r2max), length(maxovb))
    if (length(beta)   == 1) beta   <- rep(beta,   n)
    if (length(r2max)  == 1) r2max  <- rep(r2max,  n)
    if (length(maxovb) == 1) maxovb <- rep(maxovb, n)

    if (length(unique(maxovb)) > 1) {
        index <- maxovb
    } else if (length(unique(r2max)) > 1) {
        index <- r2max
    } else {
        index <- beta
    }

    lower_bound <- hyposign == ">"
    delta <- vapply(seq_len(n), function(i) {
        oster_breakdown_bound_scalar(beta[i], r2max[i], maxovb[i],
                                      lower_bound, s)
    }, numeric(1))
    data.frame(index = index, breakdown = delta)
}

# The vertical asymptotes of beta -> delta(beta), used only by the equality
# identified-set plot to know where to break the curve into segments.
oster_delta_asymptotes <- function(r_max, s) {
    bm <- s$beta_med; bs <- s$beta_short
    vxr <- s$var_x_resid; vx <- s$var_x; vy <- s$var_y
    coef <- c(
        (r_max - s$r_med) * vy * (bs - bm) * vx,
        (r_max - s$r_med) * vy * (vx - vxr),
        vxr * (bs - bm) * vx,
        vxr * vx - vxr^2
    )
    roots <- real_roots(coef)
    sort(bm - roots)
}
