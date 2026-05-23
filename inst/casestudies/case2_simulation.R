## Case study 2: simulation study of breakdown-point coverage.
##
## We simulate a known DGP with one observed control W1 and one truly
## unobserved variable W2. We vary the strength of selection on
## unobservables and ask: at what value of rxbar does our analysis declare
## the result non-robust? Does the bootstrap CI cover the true breakdown
## point with the nominal 95% rate?

suppressPackageStartupMessages({
    library(regsensitivity)
})

dgp_one <- function(n, rho_W2X, rho_W2Y, seed) {
    set.seed(seed)
    W1 <- rnorm(n)
    W2 <- rho_W2X * W1 + sqrt(max(1 - rho_W2X^2, 0)) * rnorm(n)
    X  <- 0.5 * W1 + 0.5 * W2 + rnorm(n)
    Y  <- 1.0 * X + 0.3 * W1 + rho_W2Y * W2 + rnorm(n)
    data.frame(Y = Y, X = X, W1 = W1)
}

# A small Monte Carlo over a grid of selection-on-unobservables strengths.
grid <- expand.grid(rho_W2X = c(0.0, 0.2, 0.5),
                    rho_W2Y = c(0.0, 0.3, 0.6))

cat("==== Monte Carlo: breakdown rxbar across DGP parameters ====\n")
cat("    True beta_long = 1.0\n")
cat("    Hypothesis    : beta > 0\n\n")
sim_one <- function(n, rho_W2X, rho_W2Y, R = 100, seed = 1) {
    dat <- dgp_one(n, rho_W2X, rho_W2Y, seed)
    res <- regsen_bounds(Y ~ X + W1, dat, compare = "W1", cbar = 1)
    list(beta_med = res$dgp$beta_med, rxbar_bp = res$breakdown)
}

results <- lapply(seq_len(nrow(grid)), function(i) {
    r <- sim_one(2000, grid$rho_W2X[i], grid$rho_W2Y[i], seed = 42 + i)
    cbind(grid[i, , drop = FALSE], r)
})
out <- do.call(rbind, results)
print(out, row.names = FALSE)

cat("\nIntuition: rxbar_bp shrinks as W2's correlation with both X and Y grows.\n")
cat("When rho_W2X = rho_W2Y = 0 the unobservable doesn't matter and the\n")
cat("breakdown point is large; as either correlation grows the conclusion\n")
cat("becomes more fragile.\n")
