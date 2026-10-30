# Print and summarize a sensitivity analysis

[`print()`](https://rdrr.io/r/base/print.html) shows the headline: the
analysis, the medium-regression coefficient, the breakdown point and a
thinned results table.
[`summary()`](https://rdrr.io/r/base/summary.html) returns an object
whose print method adds the call, the control and comparison sets, every
sensitivity parameter, the summary statistics and the full results
table. For an identified-set sweep that table carries a `holds` column,
`TRUE` where the identified set lies entirely on the hypothesis' side.

## Usage

``` r
# S3 method for class 'regsensitivity'
print(x, max_rows = 12, ...)

# S3 method for class 'regsensitivity'
summary(object, ...)

# S3 method for class 'summary.regsensitivity'
print(x, max_rows = Inf, ...)
```

## Arguments

- x, object:

  A `regsensitivity` object, or for the
  [`print()`](https://rdrr.io/r/base/print.html) method of the summary,
  a `summary.regsensitivity` object.

- max_rows:

  Rows of the results table to show before thinning it to evenly spaced
  rows. [`print()`](https://rdrr.io/r/base/print.html) defaults to 12, a
  summary to all of them.

- ...:

  Ignored.

## Value

[`print()`](https://rdrr.io/r/base/print.html) returns `x` invisibly.
[`summary()`](https://rdrr.io/r/base/summary.html) returns an object of
class `summary.regsensitivity`, a list holding `call`, `analysis`,
`subcommand`, `outcome`, `treatment`, `n`, `controls`, `compare`,
`hypothesis`, `sparams` (a data frame describing each sensitivity
parameter), `statistics`, `breakdown` and `results`.

## See also

[`breakdown_point()`](https://mikenguyen13.github.io/regsensitivity/reference/regsensitivity-accessors.md),
[`identified_set()`](https://mikenguyen13.github.io/regsensitivity/reference/regsensitivity-accessors.md)
and
[`as.data.frame.regsensitivity()`](https://mikenguyen13.github.io/regsensitivity/reference/as.data.frame.regsensitivity.md)
to extract the numbers.

## Examples

``` r
data(bfg2020)
res <- regsen_bounds(
  avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
  data = bfg2020, compare = c("log_area_2010", "lat", "lon"), cbar = 0.1
)
res
#> 
#> Regression Sensitivity Analysis -- Bounds [DMP (2026)]
#> ------------------------------------------------------------------------
#> Model:             avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6
#> N (obs):           2036
#> Beta (medium):     1.3854
#> Hypothesis:        Beta > 0
#> Breakdown point:   0.3906
#> 
#> Results:
#>    rxbar rybar   cbar    bmin   bmax
#>        0  +Inf    0.1  1.3854 1.3854
#>  0.23774  +Inf    0.1 0.55995 2.2109
#>  0.47547  +Inf    0.1 -0.3236 3.0944
#>  0.71321  +Inf    0.1 -1.2923 4.0631
#>  0.95094  +Inf    0.1 -2.3864 5.1572
#>   1.1887  +Inf    0.1 -3.6709 6.4417
#>   1.4264  +Inf    0.1 -5.2616 8.0325
#>   1.6642  +Inf    0.1 -7.3957 10.167
#>   1.9019  +Inf    0.1 -10.676 13.447
#>   2.1396  +Inf    0.1  -17.46 20.231
#>   2.3774  +Inf    0.1    -Inf   +Inf
#> 
#> Use summary() for the specification and full results.
summary(res)
#> 
#> Regression Sensitivity Analysis -- Bounds [DMP (2026)]
#> ------------------------------------------------------------------------
#> Call:
#>   regsen_bounds(formula = avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + 
#>       log_area_2010 + lat + lon, data = bfg2020, compare = c("log_area_2010", 
#>       "lat", "lon"), cbar = 0.1)
#> 
#> --- Specification ---------------------------------------
#>   Outcome:             avgrep2000to2016
#>   Treatment:           tye_tfe890_500kNI_100_l6
#>   N (obs):             2036
#>   Controls:            log_area_2010, lat, lon
#>   Comparison set:      log_area_2010, lat, lon
#>   Hypothesis:          Beta > 0
#> 
#> --- Sensitivity parameters ------------------------------
#>   rxbar                11 values in [0.0000, 2.3774]
#>   rybar                +Inf
#>   cbar                 0.1000
#>   clow                 0.0000
#> 
#> --- Summary statistics ----------------------------------
#>   Beta (short)               1.7078
#>   Beta (medium)              1.3854
#>   R2 (short)                 0.0269
#>   R2 (medium)                0.0718
#>   Var(Y)                   136.3204
#>   Var(X)                     1.2574
#>   Var(X_Residual)            1.1391
#> 
#> --- Results ---------------------------------------------
#>   Breakdown point:     0.3906
#>   Hypothesis holds at: 2 of 11 grid points
#> 
#> Results:
#>    rxbar rybar   cbar    bmin   bmax holds
#>        0  +Inf    0.1  1.3854 1.3854  TRUE
#>  0.23774  +Inf    0.1 0.55995 2.2109  TRUE
#>  0.47547  +Inf    0.1 -0.3236 3.0944 FALSE
#>  0.71321  +Inf    0.1 -1.2923 4.0631 FALSE
#>  0.95094  +Inf    0.1 -2.3864 5.1572 FALSE
#>   1.1887  +Inf    0.1 -3.6709 6.4417 FALSE
#>   1.4264  +Inf    0.1 -5.2616 8.0325 FALSE
#>   1.6642  +Inf    0.1 -7.3957 10.167 FALSE
#>   1.9019  +Inf    0.1 -10.676 13.447 FALSE
#>   2.1396  +Inf    0.1  -17.46 20.231 FALSE
#>   2.3774  +Inf    0.1    -Inf   +Inf FALSE
```
