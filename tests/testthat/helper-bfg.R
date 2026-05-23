# Shared helper: load BFG and pre-build the standard analysis call.
suppressPackageStartupMessages(library(ggplot2))

bfg <- function() {
    d <- regsensitivity::bfg2020
    d$statea <- factor(d$statea)
    d
}

bfg_controls <- function() {
    c("log_area_2010", "lat", "lon", "temp_mean", "rain_mean",
      "elev_mean", "d_coa", "d_riv", "d_lak", "ave_gyi", "statea")
}

bfg_formula <- function() {
    reformulate(c("tye_tfe890_500kNI_100_l6", bfg_controls()),
                response = "avgrep2000to2016")
}

bfg_compare <- function() setdiff(bfg_controls(), "statea")
