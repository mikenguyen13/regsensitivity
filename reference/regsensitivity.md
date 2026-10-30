# Regression sensitivity analysis

Top-level dispatcher that mirrors the Stata `regsensitivity` command.
For most users, calling
[`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md)
or
[`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
directly is clearer.

## Usage

``` r
regsensitivity(
  formula,
  data,
  subcommand = c("bounds", "breakdown", "summary"),
  ...
)
```

## Arguments

- formula:

  Two-sided formula: `y ~ x + w1 + w2 + ...`. The first right-hand-side
  variable is the primary independent variable; the rest are controls.

- data:

  A data.frame.

- subcommand:

  One of `"bounds"` (the default), `"breakdown"`, `"summary"`.

- ...:

  Additional arguments forwarded to the underlying function.

## Value

An object of class `regsensitivity`, or for `subcommand = "summary"` one
of class `regsensitivity_summary`.

## Details

Versions before 0.3.0 took `subcommand` first, following the Stata
syntax. A call in that order, `regsensitivity("bounds", y ~ x, data)`,
still runs, with a deprecation warning.

## See also

[`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md),
[`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md),
[`regsen_summary()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_summary.md)

## Examples

``` r
data(bfg2020)
regsensitivity(
  avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 +
    log_area_2010 + lat + lon,
  data = bfg2020,
  subcommand = "bounds",
  cbar = 0.1
)
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
```
