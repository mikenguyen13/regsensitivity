# Calibration parameters rho_k for rxbar

For each calibration covariate `W1[k]`, computes \$\$\rho_k =
\frac{\sqrt{\mathrm{Var}(\pi\_{1,med,k} W\_{1k})}}{
\sqrt{\mathrm{Var}(\pi\_{1,med,-k}' W\_{1,-k})}},\$\$ where pi(1,med) is
the OLS coefficient on W1 from the regression of the treatment X on (W0,
W1). Variances are computed on the W0-residualized variables, matching
the construction in DMP (2026) equation (3.5).

## Usage

``` r
calibrate_rho(formula, data, compare = NULL, nocompare = NULL, subset = NULL)
```

## Arguments

- formula:

  Two-sided formula: `y ~ x + w1 + w2 + ...`. The first right-hand-side
  variable is the primary independent variable; the rest are controls.

- data:

  A data.frame.

- compare:

  Optional character vector of variables to use as the comparison set.
  Defaults to all controls if neither `compare` nor `nocompare` is
  given.

- nocompare:

  Optional character vector of controls to *exclude* from the comparison
  set.

- subset:

  Optional logical or integer vector indicating which rows of `data` to
  include in the estimation.

## Value

A data.frame with columns `variable` and `rho` (a percentage).

## Details

These are point-identified reference values to compare the rxbar
breakdown point against. See DMP (2026) section 3.4 and Table 4.

## Examples

``` r
# \donttest{
data(bfg2020)
bfg2020$statea <- factor(bfg2020$statea)
w1 <- c("log_area_2010", "lat", "lon", "temp_mean", "rain_mean",
        "elev_mean", "d_coa", "d_riv", "d_lak", "ave_gyi")
form <- reformulate(c("tye_tfe890_500kNI_100_l6", w1, "statea"),
                    response = "avgrep2000to2016")
calibrate_rho(form, bfg2020, compare = w1)
#>         variable       rho
#> 10       ave_gyi 118.33963
#> 7          d_coa  78.58110
#> 3            lon  49.93006
#> 4      temp_mean  37.26278
#> 5      rain_mean  29.28644
#> 2            lat  26.92989
#> 8          d_riv  24.95888
#> 1  log_area_2010  22.45564
#> 6      elev_mean  20.25159
#> 9          d_lak  12.06453
# }
```
