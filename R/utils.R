## utils.R --- internal helpers

# Special floats. Stata's Mata uses .a and .b for -Inf / +Inf with rich
# semantics; here we use plain -Inf / Inf. Use these constants for clarity.
NEG_INF <- -Inf
POS_INF <- Inf

# Safe sqrt: returns NA for negative inputs (instead of NaN with a warning).
safe_sqrt <- function(x) ifelse(x >= 0, sqrt(pmax(x, 0)), NA_real_)

# Clip a value to a closed interval [lo, hi].
clip <- function(val, lo, hi) {
    pmin(pmax(val, lo), hi)
}

# Real roots of a polynomial.
#
# coef is the vector of coefficients in INCREASING order of power:
#     coef[1] + coef[2] * x + coef[3] * x^2 + ... + coef[k] * x^(k-1)
# (this matches the Mata `polyroots` convention used in the Stata source).
#
# Trailing zero coefficients are dropped first so that, for example, a quadratic
# expressed with a leading-zero cubic term still solves correctly. A tolerance
# on the imaginary part decides which complex roots count as real.
real_roots <- function(coef, tol = 1e-9) {
    while (length(coef) > 1 && abs(coef[length(coef)]) < 1e-15) {
        coef <- coef[-length(coef)]
    }
    if (length(coef) < 2) {
        return(numeric(0))
    }
    rts <- polyroot(coef)
    Re(rts)[abs(Im(rts)) < tol]
}

# Polynomial multiplication, increasing-order coefficients.
polymult <- function(a, b) {
    na <- length(a)
    nb <- length(b)
    out <- numeric(na + nb - 1)
    for (i in seq_len(na)) {
        for (j in seq_len(nb)) {
            out[i + j - 1] <- out[i + j - 1] + a[i] * b[j]
        }
    }
    out
}

# Polynomial addition, increasing-order coefficients.
polyadd <- function(a, b) {
    n <- max(length(a), length(b))
    length(a) <- n
    length(b) <- n
    a[is.na(a)] <- 0
    b[is.na(b)] <- 0
    a + b
}

# Derivative of a polynomial expressed in increasing-order coefficients.
# (The optional `m` argument matches the Mata signature; we always do the
# first derivative since that is the only one the codebase needs.)
polyderiv <- function(coef, m = 1) {
    if (length(coef) < 2) {
        return(0)
    }
    out <- coef[-1] * seq_len(length(coef) - 1)
    out
}

# Cumulative minimum, treating NA as +Inf so a single NA does not poison
# everything after it. Used for Oster bound idsets.
cummin_inf <- function(x) {
    out <- rep(POS_INF, length(x))
    cur <- POS_INF
    for (i in seq_along(x)) {
        v <- x[i]
        if (is.na(v) || is.infinite(v)) {
            out[i] <- cur
        } else {
            cur <- min(cur, v)
            out[i] <- cur
        }
    }
    out
}

cummax_neg_inf <- function(x) {
    out <- rep(NEG_INF, length(x))
    cur <- NEG_INF
    for (i in seq_along(x)) {
        v <- x[i]
        if (is.na(v) || is.infinite(v)) {
            out[i] <- cur
        } else {
            cur <- max(cur, v)
            out[i] <- cur
        }
    }
    out
}

# Indices for `length(p)` evenly spaced quantiles in a length-n vector.
quantile_indices <- function(n, p) {
    pmin(floor(p * n) + 1L, n)
}

# Expand a Stata-style "numlist" string into an explicit numeric vector.
#
# Supports:
#   - space- or comma-separated explicit values:  "0 .5 1", "0, .5, 1"
#   - range with step:                            "0(.1)1"   (numpy-like)
#   - simple range without step (defaults to 0.1): "0 1"  is treated as two values, not a range
#   - already-numeric input: returned unchanged
expand_numlist <- function(x) {
    if (is.numeric(x)) {
        return(as.numeric(x))
    }
    if (is.null(x) || length(x) == 0 || identical(x, "")) {
        return(numeric(0))
    }
    s <- gsub(",", " ", trimws(as.character(x)))
    # `a(step)b` -> seq(a, b, by=step)
    m <- regmatches(s, regexec("([-+0-9.eE]+)\\(([-+0-9.eE]+)\\)([-+0-9.eE]+)", s))[[1]]
    if (length(m) == 4 && nzchar(m[1])) {
        a <- as.numeric(m[2])
        step <- as.numeric(m[3])
        b <- as.numeric(m[4])
        v <- seq(a, b, by = step)
        # Stata's numlist also expands any additional bare numbers around the range.
        # Strip the range portion and parse any trailing/leading extras.
        rest <- trimws(sub(regmatches(s, regexec("([-+0-9.eE]+)\\(([-+0-9.eE]+)\\)([-+0-9.eE]+)", s))[[1]][1], "", s, fixed = TRUE))
        if (nzchar(rest)) {
            extras <- suppressWarnings(as.numeric(strsplit(rest, "\\s+")[[1]]))
            extras <- extras[!is.na(extras)]
            v <- c(v, extras)
        }
        return(v)
    }
    v <- suppressWarnings(as.numeric(strsplit(s, "\\s+")[[1]]))
    v[!is.na(v)]
}

# Returns TRUE if a number is non-finite (matches Stata's .a / .b semantics in
# the original code, which used special missing codes for -Inf / +Inf).
is_inf <- function(x) {
    is.infinite(x) || (is.numeric(x) && !is.finite(x))
}
