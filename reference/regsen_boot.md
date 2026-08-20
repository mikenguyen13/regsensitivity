# Bootstrap confidence interval for the breakdown point

Computes a non-parametric (or cluster) bootstrap percentile confidence
interval for the breakdown point returned by
[`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
or the scalar `$breakdown` field of
[`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md).

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
  ncores = 1L,
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
  [`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
  (the analysis to bootstrap).

- R:

  Integer. Number of bootstrap replications. Defaults to 999.

- cluster:

  Optional character scalar naming a column of `data` to resample at the
  cluster level (e.g. `"km_grid_cel_code"` for the BFG 2020
  application). When NULL the standard non-parametric bootstrap is used.

- level:

  Two-sided confidence level for the percentile CI. Default 0.95.

- seed:

  Optional integer seed for reproducibility. Results are identical for a
  given `seed` regardless of `ncores`: each replicate draws its own seed
  from a vector generated once up front, so nothing depends on how the
  work was divided.

- ncores:

  Number of cores for the replications. `1` (default) runs serially.
  Above 1 the package forks on macOS and Linux and falls back to a PSOCK
  cluster on Windows, which has no fork. A progress bar is not shown
  when running in parallel.

- show_progress:

  Logical; print progress bar.

## Value

An object of class `regsensitivity_boot` containing: `point`,
`replicates`, `ci`, `level`, `R`, `cluster`, `na`.

## Details

For DMP analyses the breakdown point is computed exactly as in
[`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md);
when `rxbar`, `rybar` and `cbar` are all scalar the returned breakdown
is the rxbar breakdown for the (scalar) hypothesis on beta. For Oster
analyses the breakdown is the \|delta\| value at which the hypothesis
first fails.

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
#>   95% CI            : [0.4997, 0.8612]
# }
```
