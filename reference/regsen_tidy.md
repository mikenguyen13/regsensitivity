# Tidy a sensitivity analysis

A broom-style tidier. `tidy()` returns one row per point of the
sensitivity sweep; `glance()` returns a one-row summary of the analysis
as a whole.

## Usage

``` r
regsen_tidy(x, conf.int = TRUE, ...)

regsen_glance(x, ...)
```

## Arguments

- x:

  A `regsensitivity` object.

- conf.int:

  Ignored; present for signature compatibility with other tidiers.
  Sensitivity bounds are not confidence intervals – see
  [`regsen_boot()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_boot.md)
  for sampling uncertainty in the breakdown point.

- ...:

  Ignored.

## Value

`regsen_tidy()` returns a `data.frame` with the sensitivity parameters
plus `conf.low`/`conf.high` holding the identified set, using broom's
column names so downstream packages recognise them. `regsen_glance()`
returns a one-row `data.frame`.

## Details

Implementing these makes `regsensitivity` objects usable by anything
that speaks the broom vocabulary – most usefully modelsummary, which is
how many economists assemble their tables.

The methods are registered on generics' `tidy()` and `glance()` only
when that package is installed, so it stays an optional dependency.
Without it, call `regsen_tidy()` and `regsen_glance()` directly.

## Examples

``` r
# \donttest{
data(bfg2020)
res <- regsen_bounds(
    avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
    data = bfg2020, compare = c("log_area_2010", "lat", "lon"),
    cbar = c(0.1, 0.5)
)
head(regsen_tidy(res))
#>                       term estimate   conf.low conf.high     rxbar rybar cbar
#> 1 tye_tfe890_500kNI_100_l6 1.385416  1.3854162  1.385416 0.0000000   Inf  0.1
#> 2 tye_tfe890_500kNI_100_l6 1.385416  0.5047744  2.266058 0.2531195   Inf  0.1
#> 3 tye_tfe890_500kNI_100_l6 1.385416 -0.4434758  3.214308 0.5062390   Inf  0.1
#> 4 tye_tfe890_500kNI_100_l6 1.385416 -1.4932901  4.264122 0.7593584   Inf  0.1
#> 5 tye_tfe890_500kNI_100_l6 1.385416 -2.6971380  5.467970 1.0124779   Inf  0.1
#> 6 tye_tfe890_500kNI_100_l6 1.385416 -4.1441420  6.914974 1.2655974   Inf  0.1
regsen_glance(res)
#>     analysis subcommand          outcome                treatment nobs
#> 1 DMP (2026)     bounds avgrep2000to2016 tye_tfe890_500kNI_100_l6 2036
#>   beta_medium breakdown hypothesis n_gridpoints
#> 1    1.385416        NA   Beta > 0           22
# }
```
