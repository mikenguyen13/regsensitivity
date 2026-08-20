# Explore a sensitivity analysis interactively

Opens a shiny application for moving the sensitivity parameters by hand
and watching the identified set respond. It is a way of building
intuition, and of finding the region worth reporting, before committing
to a figure.

## Usage

``` r
regsen_explore(formula, data, compare = NULL, ...)
```

## Arguments

- formula:

  A model formula, as for
  [`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md).

- data:

  A data frame.

- compare:

  Character vector of comparison covariates.

- ...:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html), e.g.
  `launch.browser` or `port`.

## Value

Invisibly `NULL`; called for the running application.

## Details

shiny is only needed to run this, so it lives in `Suggests`: the rest of
the package works without it.

## Examples

``` r
if (FALSE) { # \dontrun{
data(bfg2020)
bfg2020$statea <- factor(bfg2020$statea)
w1 <- c("log_area_2010", "lat", "lon")
regsen_explore(
    avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
    data = bfg2020, compare = w1
)
} # }
```
