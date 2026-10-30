# Sensitivity summary (DMP bounds + Oster breakdown)

Runs the default sweep used by Stata's `regsensitivity` when no
subcommand is given: a DMP bounds analysis and an Oster breakdown
analysis at a few standard r2long values.

## Usage

``` r
regsen_summary(formula, data, compare = NULL, nocompare = NULL, subset = NULL)

# S3 method for class 'regsensitivity_summary'
print(x, ...)

# S3 method for class 'regsensitivity_summary'
summary(object, ...)

# S3 method for class 'summary.regsensitivity_summary'
print(x, ...)

# S3 method for class 'regsensitivity_summary'
plot(x, which = c("both", "dmp", "oster"), ...)
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

- x, object:

  A `regsensitivity_summary` object, or for the
  [`print()`](https://rdrr.io/r/base/print.html) method of its summary,
  a `summary.regsensitivity_summary` object.

- ...:

  Passed to the methods for the two component analyses.

- which:

  Which panel to draw: `"both"` (default) side by side, or `"dmp"` or
  `"oster"` alone.

## Value

A list with elements `dmp_bounds` and `oster_breakdown`, each a
`regsensitivity` object.

[`plot()`](https://rdrr.io/r/graphics/plot.default.html) returns a
`ggplot` for a single panel. For both it returns a list of the two, of
class `regsensitivity_plots`, whose print method draws them side by
side; each element is an ordinary `ggplot` that can be modified and
drawn on its own.

## Examples

``` r
data(bfg2020)
s <- regsen_summary(
  avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 +
    log_area_2010 + lat + lon,
  data = bfg2020
)
print(s)
#> 
#> === DMP (2026) bounds ===
#> 
#> Regression Sensitivity Analysis -- Bounds [DMP (2026)]
#> ------------------------------------------------------------------------
#> Model:             avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6
#> N (obs):           2036
#> Beta (medium):     1.3854
#> Hypothesis:        Beta > 0
#> Breakdown point:   0.3749
#> 
#> Results:
#>    rxbar rybar   cbar      bmin   bmax
#>        0  +Inf      1    1.3854 1.3854
#>  0.09518  +Inf      1    1.0605 1.7103
#>  0.19036  +Inf      1   0.72556 2.0453
#>  0.28554  +Inf      1    0.3688  2.402
#>  0.38072  +Inf      1 -0.025422 2.7963
#>   0.4759  +Inf      1  -0.48095 3.2518
#>  0.57108  +Inf      1   -1.0391 3.8099
#>  0.66626  +Inf      1   -1.7832  4.554
#>  0.76144  +Inf      1   -2.9248 5.6956
#>  0.85662  +Inf      1   -5.2891   8.06
#>   0.9518  +Inf      1      -Inf   +Inf
#> 
#> Use summary() for the specification and full results.
#> 
#> === Oster (2019) breakdown ===
#> 
#> Regression Sensitivity Analysis -- Breakdown Frontier [Oster (2019)]
#> ------------------------------------------------------------------------
#> Model:             avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6
#> N (obs):           2036
#> Beta (medium):     1.3854
#> Hypothesis:        Beta > 0
#> 
#> Results:
#>     index breakdown
#>  0.093344         1
#>   0.19334         1
#>   0.29334   0.65067
#>   0.39334   0.45792
#>   0.49334   0.35327
#>   0.59334   0.28756
#>   0.69334   0.24246
#>   0.79334   0.20958
#>   0.89334   0.18456
#>   0.99334   0.16488
#>         1   0.16371
#> 
#> Use summary() for the specification and full results.
```
