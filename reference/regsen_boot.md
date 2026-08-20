# Bootstrap confidence interval for the breakdown point

Computes a non-parametric (or cluster) bootstrap percentile confidence
interval for the breakdown point returned by
[`regsen_breakdown()`](regsen_breakdown.md) or the scalar `$breakdown`
field of [`regsen_bounds()`](regsen_bounds.md).

## Usage

``` r
regsen_boot(
  formula,
  data,
  ...,
  R = 999L,
  cluster = NULL,
  level = 0.95,
  seed = NULL,
  show_progress = interactive()
)
```

## Arguments

- formula:

  Two-sided formula: `y ~ x + w1 + w2 + ...`. The first right-hand-side
  variable is the primary independent variable; the rest are controls.

- data:

  A data.frame.

- ...:

  Additional arguments forwarded to
  [`regsen_breakdown()`](regsen_breakdown.md) (the analysis to
  bootstrap).

- R:

  Integer. Number of bootstrap replications. Defaults to 999.

- cluster:

  Optional character scalar naming a column of `data` to resample at the
  cluster level (e.g. `"km_grid_cel_code"` for the BFG 2020
  application). When NULL the standard non-parametric bootstrap is used.

- level:

  Two-sided confidence level for the percentile CI. Default 0.95.

- seed:

  Optional integer seed for reproducibility.

- show_progress:

  Logical; print progress bar.

## Value

An object of class `regsensitivity_boot` containing: `point`,
`replicates`, `ci`, `level`, `R`, `cluster`, `na`.

## Details

For DMP analyses the breakdown point is computed exactly as in
[`regsen_breakdown()`](regsen_breakdown.md); when `rxbar`, `rybar` and
`cbar` are all scalar the returned breakdown is the rxbar breakdown for
the (scalar) hypothesis on beta. For Oster analyses the breakdown is the
\|delta\| value at which the hypothesis first fails.

## Examples

``` r
# \donttest{
data(bfg2020)
bfg2020$statea <- factor(bfg2020$statea)
w1 <- c("log_area_2010", "lat", "lon", "temp_mean", "rain_mean",
        "elev_mean", "d_coa", "d_riv", "d_lak", "ave_gyi")
form <- reformulate(c("tye_tfe890_500kNI_100_l6", w1, "statea"),
                    response = "avgrep2000to2016")
set.seed(1)
bb <- regsen_boot(form, bfg2020, compare = w1, cbar = 1,
                   R = 199, cluster = "km_grid_cel_code")
print(bb)
#> Bootstrap confidence interval for the breakdown point
#> ------------------------------------------------------------
#>   R                  : 199
#>   Cluster bootstrap  : km_grid_cel_code
#>   Confidence level   : 95%
#>   Point estimate     : 0.8036
#>   95% CI            : [0.5309, 0.8669]
# }
```
