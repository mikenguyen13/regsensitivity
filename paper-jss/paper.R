## regsensitivity: Sensitivity Analysis for Omitted Variable Bias in Linear
##                 Regression in R
## Author: Mike Nguyen
##
## Replication script for the manuscript. Every number, table and figure
## reported in the paper is produced below, in the order in which it appears.
## Section numbers refer to the sections of the manuscript.
##
## Operating system: macOS 15 (Darwin 25.5.0); Processor: Apple M4;
##                   System type: 64-bit arm64
## R version 4.5.2 (2025-10-31)
##
## Package versions used for the results in the paper:
##   regsensitivity 0.1.1, ggplot2 4.0.0, AER 1.2-15, nloptr 2.2.1,
##   sensemakr 0.1.6, xtable 1.8-4, knitr 1.50, microbenchmark 1.5.0
##
## Total runtime is roughly 8 minutes, dominated by the coverage study of
## Section 11; every other step completes in seconds. Steps whose runtime
## exceeds a few seconds are marked SLOW below.

# list.of.packages <- c("regsensitivity", "ggplot2", "AER", "nloptr",
#                       "sensemakr", "xtable", "knitr", "microbenchmark")
# new.packages <- list.of.packages[!(list.of.packages %in%
#                                    installed.packages()[, "Package"])]
# if (length(new.packages)) install.packages(new.packages, dependencies = TRUE)

library("regsensitivity")
library("ggplot2")

## Display layout mandated by the JSS style guide. digits = 4 produces the
## printed precision of every value quoted in the manuscript.
options(prompt = "R> ", continue = "+  ", width = 70,
        useFancyQuotes = FALSE, digits = 4)

## save figures to PDF: TRUE/FALSE
doPDF <- FALSE
if (doPDF) dir.create("figures", showWarnings = FALSE)


#### Section 7: The package API -- BFG2020 walkthrough ####

## The Bazzi-Fiszbein-Gebresilasse (2020) Frontier Culture data, as used in
## Diegert, Masten and Poirier (2026) Table 1, column (5).
data("bfg2020", package = "regsensitivity")
bfg2020$statea <- factor(bfg2020$statea)
w1 <- c("log_area_2010", "lat", "lon", "temp_mean", "rain_mean",
        "elev_mean", "d_coa", "d_riv", "d_lak", "ave_gyi")
form <- reformulate(c("tye_tfe890_500kNI_100_l6", w1, "statea"),
                    response = "avgrep2000to2016")

##### Section 7.1 / Figure 1: bounds across rxbar #####
## Header reports N = 2036 and beta_med = 2.0548 (DMP Table 1 col (5): 2.055).
## Breakdown point at cbar = 0.1 is 1.1947.
bnds <- regsen_bounds(form, bfg2020, compare = w1, cbar = 0.1)
print(bnds)

if (doPDF) pdf("figures/api-bounds-plot-1.pdf", width = 5.5, height = 4)
print(plot(bnds))
if (doPDF) dev.off()

## Values quoted in Sections 3.3 and 7.1: the breakdown point falls from
## 1.35 at cbar = 0 to 0.80 at cbar = 1, so the < 1 ceiling of Corollary 1
## binds only under arbitrarily endogenous controls.
regsen_breakdown(form, bfg2020, compare = w1, cbar = 0)$results$breakdown[1]
regsen_breakdown(form, bfg2020, compare = w1, cbar = 1)$results$breakdown[1]

##### Section 7.2 / Figure 2: breakdown across cbar #####
bd <- regsen_breakdown(form, bfg2020, compare = w1,
                       cbar = seq(0, 1, 0.05))
head(bd$results, 4)

if (doPDF) pdf("figures/api-breakdown-plot-1.pdf", width = 5.5, height = 4)
print(plot(bd))
if (doPDF) dev.off()

##### Section 7.3: hypotheses other than a sign change #####
regsen_breakdown(form, bfg2020, compare = w1, cbar = 1,
                 beta = bnd_lb(c(0, 0.5, 1, 1.5)))$results

##### Section 7.4: Oster (2019) analysis #####
## Corrected Oster delta. DMP report -23.3 where BFG published -8.55.
o <- regsen_breakdown(form, bfg2020, compare = w1,
                      analysis = "oster",
                      r2long = 1.3, r2long_type = "relative",
                      beta = bnd_eq(0))
o$results$breakdown

##### Section 7.5: bounding the bias magnitude (Masten-Poirier maxovb) #####
regsen_bounds(form, bfg2020, compare = w1, analysis = "oster",
              delta = c(0.5, 1, 2), r2long = 1.3,
              r2long_type = "relative",
              maxovb = 0.5, maxovb_type = "relative")$results

##### Section 7.6: the default summary #####
smry <- regsen_summary(form, bfg2020, compare = w1)
names(smry)
head(smry$oster_breakdown$results, 4)

##### Section 7.7: calibration #####
## rho_k of DMP Section 3.4; matches DMP Table 4 col (5) to within 0.06.
rho <- calibrate_rho(form, bfg2020, compare = w1)
rho

## c_k^2 of DMP Section 3.5; matches DMP Table 3.
calibrate_partial_r2(form, bfg2020, compare = w1)

##### Section 7.8: bootstrap inference #####
## Point estimate 0.8036 is the value DMP Table 1 col (5) reports as 80.4%.
set.seed(2026)
boot <- regsen_boot(form, bfg2020,
                    compare = w1, cbar = 1,
                    cluster = "km_grid_cel_code",
                    R = 199, show_progress = FALSE)
print(boot)

##### Section 7.9 / Figure 3: tracing a breakdown frontier ##### SLOW (~30s)
ry_grid <- c(0.5, 0.75, 1, 1.25, 1.5, 2, 3, Inf)
frontier <- do.call(rbind, lapply(c(0, 0.5, 1), function(cb) {
    rx <- vapply(ry_grid, function(ry) {
        out <- try(regsen_breakdown(form, bfg2020, compare = w1,
                                    cbar = cb, rybar = ry),
                   silent = TRUE)
        if (inherits(out, "try-error")) NA_real_
        else out$results$breakdown[1]
    }, numeric(1))
    data.frame(cbar = cb, rybar = ry_grid, rxbar_bp = rx)
}))
subset(frontier, cbar == 1)

fr <- frontier[is.finite(frontier$rybar) & !is.na(frontier$rxbar_bp), ]
p_fr <- ggplot(fr, aes(x = rxbar_bp, y = rybar,
                       colour = factor(cbar), shape = factor(cbar))) +
    geom_line() + geom_point() +
    labs(x = expression(bar(r)[X]), y = expression(bar(r)[Y]),
         colour = expression(bar(c)), shape = expression(bar(c))) +
    theme_bw()
if (doPDF) pdf("figures/api-frontier-plot-1.pdf", width = 5.5, height = 4)
print(p_fr)
if (doPDF) dev.off()


#### Section 8: Replicating Diegert, Masten and Poirier (2026) Table 1 ####

inp <- regsensitivity:::build_dgp_inputs(form, bfg2020, compare = w1)
dgp <- regsensitivity:::get_dgp(inp)
r2rot <- min(dgp$r_med * 1.3, 1)

dgp$beta_med                                   # published 2.055
dgp$n                                          # published 2,036
mean(bfg2020$avgrep2000to2016, na.rm = TRUE)   # published 60.04
regsen_breakdown(form, bfg2020, compare = w1, analysis = "oster",
                 r2long = r2rot,
                 beta = bnd_eq(0))$results$breakdown[1]   # published -23.3
regsen_bounds(form, bfg2020, compare = w1, cbar = 1)$breakdown  # 80.4%
regsen_breakdown(form, bfg2020, compare = w1, cbar = 1,
                 rybar_expr = function(rx) rx)$results$breakdown[1]  # 95.9%


#### Section 9: Case study -- California schools ####

suppressPackageStartupMessages(library("AER"))
data("CASchools", package = "AER")
CASchools$score <- with(CASchools, (read + math) / 2)
CASchools$STR   <- CASchools$students / CASchools$teachers

f <- score ~ STR + english + lunch + county
res <- regsen_bounds(f, CASchools, compare = c("english", "lunch"),
                     cbar = 1)
res$dgp$beta_med   # -0.9011, quoted in the text as -0.90
res$breakdown      #  0.9446, quoted in the text as 0.94

regsen_breakdown(f, CASchools, compare = c("english", "lunch"),
                 cbar = 0)$results$breakdown[1]
calibrate_rho(f, CASchools, compare = c("english", "lunch"))
regsen_boot(f, CASchools, compare = c("english", "lunch"), cbar = 1,
            R = 199, seed = 7, show_progress = FALSE)


#### Section 10: Simulation -- bootstrap CI coverage ####  SLOW (~7 min)

sim_dgp <- function(n, rho = 0.5, seed = NULL) {
    if (!is.null(seed)) set.seed(seed)
    W1 <- matrix(rnorm(2 * n), n, 2)
    W2 <- rho * W1[, 1] + sqrt(max(1 - rho^2, 0)) * rnorm(n)
    X  <- 0.5 * W1[, 1] + 0.3 * W1[, 2] + 0.5 * W2 + rnorm(n)
    Y  <- 1.0 * X + 0.3 * W1[, 1] + 0.2 * W1[, 2] + 0.4 * W2 + rnorm(n)
    data.frame(Y = Y, X = X, W1a = W1[, 1], W1b = W1[, 2])
}
sim_f <- Y ~ X + W1a + W1b
sim_cmp <- c("W1a", "W1b")

## Pseudo-true breakdown point: 0.716954
truth <- regsen_bounds(sim_f, sim_dgp(4e5, seed = 1),
                       compare = sim_cmp, cbar = 1)$breakdown
M <- 250L; Rb <- 199L
sim_tab <- do.call(rbind, lapply(c(500L, 1000L, 4000L), function(n) {
    cov <- 0L; wid <- numeric(M); est <- numeric(M)
    for (m in seq_len(M)) {
        d <- sim_dgp(n, seed = 10000L + 1000L * n + m)
        b <- regsen_boot(sim_f, d, compare = sim_cmp, cbar = 1,
                         R = Rb, show_progress = FALSE)
        est[m] <- b$point
        cov <- cov + as.integer(truth >= b$ci[1] && truth <= b$ci[2])
        wid[m] <- b$ci[2] - b$ci[1]
    }
    data.frame(n = n, coverage = 100 * cov / M, bias = mean(est) - truth,
               sd = sd(est), width = mean(wid))
}))
sim_tab   # coverage 90.4 / 92.0 / 95.2 at n = 500 / 1000 / 4000


#### Section 11: Comparison with sensemakr ####

suppressPackageStartupMessages(library("sensemakr"))
fit <- lm(form, data = bfg2020)
sm <- sensemakr(model = fit, treatment = "tye_tfe890_500kNI_100_l6",
                benchmark_covariates = w1, kd = 1, ky = 1,
                q = 1, alpha = 0.05, reduce = TRUE)
sm$sensitivity_stats[c("r2yd.x", "rv_q", "rv_qa")]


#### Section 12: Performance (timing table) ####
## Full script: system.file("benchmarks", "performance.R",
##                          package = "regsensitivity")


#### Appendix B: regression tests ####
## testthat::test_local()  from the package source, or
## testthat::test_package("regsensitivity")  on the installed package.
