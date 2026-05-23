# Standalone replication of Diegert, Masten, Poirier (2026) tables and
# figures that use the bundled data. Run with:
#   Rscript inst/replication/dmp2022.R
#
# Output: dmp2022_table3.csv, dmp2022_table4.csv, dmp2022_fig1_left.png,
# dmp2022_fig1_right.png in the current working directory.

suppressPackageStartupMessages({
    library(regsensitivity)
    library(ggplot2)
})

data(bfg2020)
bfg2020$statea <- factor(bfg2020$statea)

w1 <- c("log_area_2010", "lat", "lon", "temp_mean", "rain_mean",
        "elev_mean", "d_coa", "d_riv", "d_lak", "ave_gyi")
labels <- c(
    log_area_2010 = "Land area",
    lat           = "Centroid Latitude",
    lon           = "Centroid Longitude",
    temp_mean     = "Average temperature",
    rain_mean     = "Average rainfall",
    elev_mean     = "Elevation",
    d_coa         = "Distance from centroid to the coast",
    d_riv         = "Distance from centroid to rivers",
    d_lak         = "Distance from centroid to lakes",
    ave_gyi       = "Average potential agricultural yield"
)

form <- avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 +
    log_area_2010 + lat + lon + temp_mean + rain_mean + elev_mean +
    d_coa + d_riv + d_lak + ave_gyi + statea

cat("=== Panel C, col (5): breakdown points ===\n")
bp1 <- regsen_bounds(form, bfg2020, compare = w1, cbar = 1)
bp2 <- regsen_bounds(form, bfg2020, compare = w1, cbar = 1,
                      rybar_expr = function(rx) rx)
cat(sprintf("  rxbar^bp (cbar=1):                 %.4f  (paper: 0.804)\n",
            bp1$breakdown))
cat(sprintf("  r^bp (cbar=1, rybar = rxbar):      %.4f  (paper: 0.96)\n",
            bp2$breakdown))

cat("\n=== Table 3: partial R^2 of W1k on W1,-k given W0 ===\n")
tbl3 <- calibrate_partial_r2(form, bfg2020, compare = w1)
tbl3$variable <- labels[tbl3$variable]
print(tbl3, row.names = FALSE)
write.csv(tbl3, "dmp2022_table3.csv", row.names = FALSE)

cat("\n=== Table 4 col (5): rho_k for Republican Vote Share ===\n")
tbl4 <- calibrate_rho(form, bfg2020, compare = w1)
tbl4$variable <- labels[tbl4$variable]
print(tbl4, row.names = FALSE)
write.csv(tbl4, "dmp2022_table4.csv", row.names = FALSE)

cat("\n=== Figure 1 (left): bounds vs rxbar at cbar=1 ===\n")
fig1L <- regsen_bounds(form, bfg2020, compare = w1, cbar = 1,
                        rxbar = seq(0, 0.99, length.out = 100))
ggsave("dmp2022_fig1_left.png",
        plot(fig1L, ylim = c(-2, 8)),
        width = 5, height = 4, dpi = 150)
cat("  saved dmp2022_fig1_left.png\n")

cat("\n=== Figure 1 (right): rxbar breakdown frontier vs cbar ===\n")
fig1R <- regsen_breakdown(form, bfg2020, compare = w1,
                           cbar = seq(0, 1, 0.02))
df_rho <- calibrate_rho(form, bfg2020, compare = w1)
df_rho$variable <- labels[df_rho$variable]
df_rho$rho_dec <- df_rho$rho / 100
p <- plot(fig1R) +
    geom_hline(yintercept = df_rho$rho_dec, linetype = "dotted",
                colour = "grey50") +
    geom_text(data = df_rho,
               aes(x = 0.02, y = rho_dec, label = variable),
               hjust = 0, vjust = -0.3, size = 2.4, colour = "grey30") +
    coord_cartesian(ylim = c(0, 1.4))
ggsave("dmp2022_fig1_right.png", p, width = 6, height = 4, dpi = 150)
cat("  saved dmp2022_fig1_right.png\n")

cat("\nReplication complete.\n")
