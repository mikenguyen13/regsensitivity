# Sensitivity analysis for several treatments at once

Runs
[`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
(or
[`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md))
once per candidate treatment and collects the breakdown points into one
table. This is the applied question "which of my regressors would
survive an unobservable, and which would not?", answered in a single
call.

## Usage

``` r
regsen_multi(
  formula,
  data,
  treatments,
  compare = NULL,
  fun = regsen_breakdown,
  ...
)

# S3 method for class 'regsensitivity_multi'
plot(x, base_size = 11, ...)
```

## Arguments

- formula:

  A model formula. Its right-hand side must contain every name in
  `treatments`. Which term appears first does not matter here, since
  each treatment is promoted in turn.

- data:

  A data frame.

- treatments:

  Character vector of variables to treat as the treatment in turn.

- compare:

  Passed to the underlying analysis. A variable currently acting as the
  treatment is removed from `compare` for that row, since a variable
  cannot calibrate against itself.

- fun:

  The analysis to run:
  [`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
  (default) or
  [`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md).

- ...:

  Passed to `fun`, e.g. `cbar`, `analysis`, `beta`.

- x:

  A `regsensitivity_multi` object.

- base_size:

  Base font size, passed to
  [`theme_regsen()`](https://mikenguyen13.github.io/regsensitivity/reference/theme_regsen.md).

## Value

A `data.frame` of class `regsensitivity_multi`, one row per treatment,
with columns `treatment`, `estimate` (the medium-regression
coefficient), `breakdown`, and `n`. Rows where the analysis failed carry
`NA` and an `error` column explaining why, rather than aborting the
whole sweep.

## Details

Each treatment is analysed in the *same* model: the variable of interest
moves to the front of the formula and every other right-hand-side term
stays a control, including the other candidate treatments. That is
deliberate – dropping the others would change the specification and the
breakdown points would no longer be comparable across rows.

## Examples

``` r
# \donttest{
data(bfg2020)
w1 <- c("log_area_2010", "lat", "lon")
regsen_multi(
    avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
    data = bfg2020,
    treatments = c("tye_tfe890_500kNI_100_l6", "lat"),
    compare = w1, cbar = 1
)
#> 
#> Sensitivity across treatments
#> ------------------------------------------------------------
#>                 treatment estimate breakdown     n
#>  tye_tfe890_500kNI_100_l6    1.385    0.3749  2036
#>                       lat  -0.3266    0.9425  2036
# }
```
