# Plot a regression sensitivity analysis

Produces a ggplot object visualizing either an identified-set sweep
(from [`regsen_bounds()`](regsen_bounds.md)) or a breakdown frontier
(from [`regsen_breakdown()`](regsen_breakdown.md)).

## Usage

``` r
# S3 method for class 'regsensitivity'
plot(
  x,
  ywidth = NULL,
  ylim = NULL,
  show_breakdown = TRUE,
  show_legend = TRUE,
  title = NULL,
  subtitle = NULL,
  xtitle = NULL,
  ytitle = NULL,
  ...
)
```

## Arguments

- x:

  A `regsensitivity` object.

- ywidth:

  Half-width of the y-axis in standard deviations of X. Ignored when
  `ylim` is set.

- ylim:

  Optional two-element numeric vector giving the y-axis limits.

- show_breakdown:

  Logical; draw a horizontal line at the hypothesis value. Defaults to
  `TRUE`.

- show_legend:

  Logical; show the legend (only relevant when plotting bounds with
  multiple values of a second sensitivity parameter).

- title, subtitle, xtitle, ytitle:

  Plot annotations. `NULL` uses defaults.

- ...:

  Ignored.

## Value

A `ggplot` object.
