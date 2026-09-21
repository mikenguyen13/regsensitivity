# Bootstrap confidence interval for the breakdown point

Computes a non-parametric (or cluster) bootstrap confidence interval for
the breakdown point returned by
[`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
or the scalar `$breakdown` field of
[`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md).
Both a bias-corrected and accelerated (BCa) interval and a percentile
interval are returned; `type` chooses which one `$ci` reports.

## Usage

``` r
regsen_boot(
  formula,
  data,
  ...,
  type = c("bca", "perc"),
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

- type:

  Interval type reported in `$ci`: `"bca"` (default) or `"perc"`. Under
  `"bca"` both intervals are computed and stored; under `"perc"` the
  jackknife BCa needs is skipped and `$ci_bca` is `NA`. See Details.

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
  when running in parallel. Capped at `R`, and at 2 while
  `R CMD check --as-cran` is running, which forbids more; results do not
  depend on the cap.

- show_progress:

  Logical; print progress bar.

## Value

An object of class `regsensitivity_boot` containing: `point`,
`replicates`, `ci` (the interval named by `type`), `ci_bca`, `ci_perc`,
`z0`, `acceleration`, `type`, `level`, `R`, `cluster`, `na` (the number
of replicates that could not be computed) and `infinite` (the number on
which the hypothesis survived every value of the sensitivity parameter;
these count as `+Inf` in the intervals rather than being dropped).

## Details

For DMP analyses the breakdown point is computed exactly as in
[`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md);
when `rxbar`, `rybar` and `cbar` are all scalar the returned breakdown
is the rxbar breakdown for the (scalar) hypothesis on beta. For Oster
analyses the breakdown is the \|delta\| value at which the hypothesis
first fails.

The BCa interval takes the percentile interval and shifts the quantiles
it reads by two constants: `z0`, a median-bias correction equal to the
normal quantile of the share of replicates below the point estimate, and
`acceleration`, computed from the delete-one jackknife over sampling
units – rows, or clusters when `cluster` is given. The jackknife costs
one breakdown computation per unit, which under an i.i.d. bootstrap
means one per row and usually dominates the run; both it and the
replicates honour `ncores`, and `type = "perc"` skips it. When the
jackknife is degenerate (every unit gives the same estimate, so the
acceleration is undefined) the BCa interval falls back to the percentile
interval and `acceleration` is `NA`.

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
#>   Interval           : BCa
#>   Bias corr. (z0)    : 1.1233
#>   Acceleration       : -0.0008
#>   Confidence level   : 95%
#>   Point estimate     : 0.8036
#>   95% CI            : [0.7465, 0.9025]
#>   (An endpoint is an extreme replicate; raise R)
#>   95% CI (percentile): [0.4997, 0.8612]
# }
```
