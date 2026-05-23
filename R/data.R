#' Bazzi, Fiszbein and Gebresilasse (2020) "Frontier Culture" replication data
#'
#' A subset of the data from Bazzi, Fiszbein and Gebresilasse (2020) used in
#' the Diegert-Masten-Poirier (2026) sensitivity analysis vignette. Each row
#' is a county; each column is a covariate used in the DMP empirical
#' application.
#'
#' @format A data.frame with 2036 rows and 14 columns:
#' \describe{
#'   \item{lat, lon}{Latitude and longitude.}
#'   \item{statea}{State indicator (numeric).}
#'   \item{avgrep2000to2016}{Outcome: average Republican vote share, 2000-2016.}
#'   \item{temp_mean, rain_mean, elev_mean}{Climate / topography.}
#'   \item{d_coa, d_riv, d_lak}{Distance to coast / river / lake.}
#'   \item{ave_gyi}{Average GYI.}
#'   \item{tye_tfe890_500kNI_100_l6}{Treatment: years of frontier exposure.}
#'   \item{log_area_2010}{Log area, 2010.}
#'   \item{km_grid_cel_code}{Grid cell code used for clustering.}
#' }
#' @source Bazzi, Fiszbein and Gebresilasse (2020),
#'   "Frontier Culture: The Roots and Persistence of 'Rugged Individualism'
#'   in the United States", \emph{Econometrica}
#'   <doi:10.3982/ECTA16484>. A 14-variable, 2036-row subset of their
#'   public replication data, used here to demonstrate the package.
"bfg2020"
