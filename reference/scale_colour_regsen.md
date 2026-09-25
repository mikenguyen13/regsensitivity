# Colourblind-safe scales for sensitivity plots

Discrete colour and fill scales using the Okabe-Ito palette, which stays
legible under the common forms of colour vision deficiency and survives
greyscale printing. These are applied by default in
[`plot.regsensitivity()`](https://mikenguyen13.github.io/regsensitivity/reference/plot.regsensitivity.md);
they are exported so a plot can be rebuilt with the same colours.

## Usage

``` r
scale_colour_regsen(...)

scale_color_regsen(...)

scale_fill_regsen(...)
```

## Arguments

- ...:

  Passed to
  [`ggplot2::discrete_scale()`](https://ggplot2.tidyverse.org/reference/discrete_scale.html).

## Value

A ggplot2 scale.

## Examples

``` r
d <- data.frame(
  x = rep(1:3, 2),
  y = c(1, 2, 3, 2, 3, 4),
  series = rep(c("a", "b"), each = 3)
)
ggplot2::ggplot(d, ggplot2::aes(x, y, colour = series)) +
  ggplot2::geom_line() +
  scale_colour_regsen()
```
