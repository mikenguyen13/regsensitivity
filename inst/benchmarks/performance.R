## performance.R --- timing benchmarks for the main entry points.
##
## We benchmark every regime of the analysis on the BFG2020 application
## (n = 2036, |W1| = 10 + state FE). The two slow regimes are DMP with
## rybar finite + cbar > 0 (DIRECT optimization) and any breakdown search
## that goes through it. All other regimes are closed-form.
##
## The BCa bootstrap timings include the delete-one jackknife that interval
## needs, which is one breakdown computation per resampling unit -- per row
## under the i.i.d. bootstrap, per cluster under the cluster bootstrap. The
## percentile-only run shows what the replicates alone cost.
##
## Timings are process CPU time (user + system), not elapsed time, so that a
## busy machine reports the cost of the computation rather than the cost of
## sharing the machine, and each figure is the smallest of `n` runs after a
## warm-up. Contention can only add to a measurement, so the minimum is the
## closest estimate of the uncontended cost; a median would report how busy
## the machine happened to be.

suppressPackageStartupMessages(library(regsensitivity))

d <- bfg2020; d$statea <- factor(d$statea)
w1 <- c("log_area_2010", "lat", "lon", "temp_mean", "rain_mean",
        "elev_mean", "d_coa", "d_riv", "d_lak", "ave_gyi")
form <- reformulate(c("tye_tfe890_500kNI_100_l6", w1, "statea"),
                    response = "avgrep2000to2016")

cpu_ms <- function(e, n = 5) {
    e <- substitute(e)
    env <- parent.frame()
    invisible(eval(e, env))                       # warm-up
    reps <- replicate(n, {
        s <- system.time(eval(e, env))
        as.numeric(s[["user.self"]] + s[["sys.self"]])
    })
    min(reps) * 1000
}

bench <- list(
    `DMP bounds, rybar=Inf, cbar=0.1, 10 rxbar` = function()
        cpu_ms(regsen_bounds(form, d, compare = w1, cbar = 0.1)),
    `DMP breakdown over cbar grid (11 points)` = function()
        cpu_ms(regsen_breakdown(form, d, compare = w1, cbar = seq(0, 1, 0.1))),
    `Oster bounds equality (21 delta)` = function()
        cpu_ms(regsen_bounds(form, d, compare = w1, analysis = "oster",
                             delta = seq(-1, 1, 0.1))),
    `Oster breakdown sign-change` = function()
        cpu_ms(regsen_breakdown(form, d, compare = w1, analysis = "oster",
                                r2long = 1)),
    `DMP bounds, rybar=2, cbar=1, 10 rxbar` = function()
        cpu_ms(regsen_bounds(form, d, compare = w1, rybar = 2,
                             rxbar = seq(0, 0.8, length.out = 10)), n = 3),
    `DMP rybar frontier, 5 rxbar points` = function()
        cpu_ms(regsen_breakdown(form, d, compare = w1, cbar = 1,
                                direction = "rybar",
                                rxbar = c(0.5, 1, 1.5, 2, 4)), n = 3),
    `Bootstrap, percentile, R=99` = function()
        cpu_ms(regsen_boot(form, d, compare = w1, cbar = 1, R = 99,
                           type = "perc", show_progress = FALSE, seed = 1),
               n = 3),
    `Cluster bootstrap, BCa, R=99` = function()
        cpu_ms(regsen_boot(form, d, compare = w1, cbar = 1,
                           cluster = "km_grid_cel_code", R = 99,
                           show_progress = FALSE, seed = 1), n = 3),
    `Bootstrap, BCa, R=99` = function()
        cpu_ms(regsen_boot(form, d, compare = w1, cbar = 1, R = 99,
                           show_progress = FALSE, seed = 1), n = 3)
)

cat("==== Minimum CPU time per call (ms) ====\n")
for (nm in names(bench)) {
    cat(sprintf("  %-45s %10.1f\n", nm, bench[[nm]]()))
}
