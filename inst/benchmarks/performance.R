## performance.R --- timing benchmarks for the main entry points.
##
## We benchmark every regime of the analysis on the BFG2020 application
## (n = 2036, |W1| = 10 + state FE). The two slow regimes are DMP with
## rybar finite + cbar > 0 (DIRECT optimization) and the DMP breakdown
## bisection. All other regimes are closed-form.

suppressPackageStartupMessages({
    library(regsensitivity)
    library(microbenchmark)
})

d <- bfg2020; d$statea <- factor(d$statea)
w1 <- c("log_area_2010", "lat", "lon", "temp_mean", "rain_mean",
        "elev_mean", "d_coa", "d_riv", "d_lak", "ave_gyi")
form <- reformulate(c("tye_tfe890_500kNI_100_l6", w1, "statea"),
                    response = "avgrep2000to2016")

cat("==== Single-call timings (ms, median over 5 runs) ====\n")
mb <- microbenchmark(
    `DMP bounds, rybar=Inf, cbar=0.1, 10 rxbar`     =
        regsen_bounds(form, d, compare = w1, cbar = 0.1),
    `DMP bounds, rybar=2, cbar=1, 10 rxbar`        =
        regsen_bounds(form, d, compare = w1, rybar = 2,
                       rxbar = seq(0, 0.8, length.out = 10)),
    `DMP breakdown over cbar grid (11 points)`     =
        regsen_breakdown(form, d, compare = w1, cbar = seq(0, 1, 0.1)),
    `Oster bounds equality (21 delta)`             =
        regsen_bounds(form, d, compare = w1,
                       analysis = "oster",
                       delta = seq(-1, 1, 0.1)),
    `Oster breakdown sign-change`                  =
        regsen_breakdown(form, d, compare = w1,
                          analysis = "oster",
                          r2long = 1),
    times = 5
)
print(mb, unit = "ms")

cat("\n==== Bootstrap timing ====\n")
t0 <- Sys.time()
suppressMessages(regsen_boot(form, d, compare = w1, cbar = 1,
                              R = 99, show_progress = FALSE,
                              seed = 1))
t1 <- Sys.time()
cat(sprintf("  R=99 standard bootstrap     : %.2fs (~ %.0fms/replicate)\n",
            as.numeric(t1 - t0, units = "secs"),
            1000 * as.numeric(t1 - t0, units = "secs") / 99))
