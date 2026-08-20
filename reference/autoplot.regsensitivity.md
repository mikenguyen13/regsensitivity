# Autoplot method

[`ggplot2::autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
support, so a `regsensitivity` object can be drawn by code that
dispatches on `autoplot()` rather than
[`plot()`](https://rdrr.io/r/graphics/plot.default.html). It forwards
every argument to
[`plot.regsensitivity()`](https://mikenguyen13.github.io/regsensitivity/reference/plot.regsensitivity.md).

## Usage

``` r
# S3 method for class 'regsensitivity'
autoplot(object, ...)
```

## Arguments

- object:

  A `regsensitivity` object.

- ...:

  Passed to
  [`plot.regsensitivity()`](https://mikenguyen13.github.io/regsensitivity/reference/plot.regsensitivity.md).

## Value

A `ggplot` object.

## Examples

``` r
# \donttest{
data(bfg2020)
res <- regsen_bounds(
    avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
    data = bfg2020, compare = c("log_area_2010", "lat", "lon"), cbar = 0.1
)
ggplot2::autoplot(res)

# }
```
