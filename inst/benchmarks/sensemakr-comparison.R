## sensemakr-comparison.R
##
## Side-by-side comparison of regsensitivity with sensemakr
## (Cinelli & Hazlett 2020). Both are sensitivity analyses for omitted
## variable bias, but they operationalize "strength of unobservable" via
## different sensitivity parameters:
##
##   regsensitivity (DMP 2026, Oster 2019)
##       - DMP : rxbar, rybar, cbar
##       - Oster : delta, R-squared(long), maxovb
##
##   sensemakr (Cinelli-Hazlett 2020)
##       - partial R^2 of unobservable with treatment AND outcome
##       - the "robustness value" RV: smallest pair of partial R^2 that
##         changes the conclusion
##
## The two are complementary, not competitors. This script runs both on the
## same BFG2020 application and tabulates the result.

suppressPackageStartupMessages({
    library(regsensitivity)
    library(sensemakr)
})

# Common setup.
d <- bfg2020; d$statea <- factor(d$statea)
w1 <- c("log_area_2010", "lat", "lon", "temp_mean", "rain_mean",
        "elev_mean", "d_coa", "d_riv", "d_lak", "ave_gyi")
form <- reformulate(c("tye_tfe890_500kNI_100_l6", w1, "statea"),
                    response = "avgrep2000to2016")

cat("==== regsensitivity (DMP 2026) ====\n")
res_dmp <- regsen_bounds(form, d, compare = w1, cbar = 1)
cat(sprintf("  beta_med                    : %.4f\n", res_dmp$dgp$beta_med))
cat(sprintf("  rxbar breakdown (cbar=1)    : %.4f\n", res_dmp$breakdown))

cat("\n==== regsensitivity (Oster 2019) ====\n")
inp <- regsensitivity:::build_dgp_inputs(form, d, compare = w1)
dgp <- regsensitivity:::get_dgp(inp)
r2rot <- min(dgp$r_med * 1.3, 1)
res_o <- regsen_breakdown(form, d, compare = w1,
                          analysis = "oster",
                          r2long = r2rot,
                          beta = bnd_eq(0))
cat(sprintf("  Oster delta_resid           : %.4f\n", res_o$results$breakdown[1]))

cat("\n==== sensemakr (Cinelli-Hazlett 2020) ====\n")
fit <- lm(form, data = d)
sm <- sensemakr(model = fit,
                treatment = "tye_tfe890_500kNI_100_l6",
                benchmark_covariates = w1,
                kd = 1:3,
                ky = 1:3,
                q = 1,
                alpha = 0.05,
                reduce = TRUE)
print(summary(sm))

cat("\n==== Conceptual mapping ====\n")
cat("  Oster delta            : how much selection on unobservables relative\n")
cat("                           to observables; can be > 1 or < 0\n")
cat("  DMP rxbar              : norm-ratio version of selection on unob.;\n")
cat("                           breakdown <= 1 always (Theorem 1)\n")
cat("  Cinelli-Hazlett RV     : partial R^2 of unobservable jointly with\n")
cat("                           treatment AND outcome; symmetric quantity\n")
cat("\nThese answer subtly different questions about robustness. Reporting\n")
cat("more than one tightens the empirical conclusion.\n")
