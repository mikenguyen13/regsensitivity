# Extract sensitivity results as a tidy data frame

Returns the results table of a `regsensitivity` object as a plain
`data.frame`, with the sensitivity parameters and the bounds (or the
breakdown frontier) in columns.

## Usage

``` r
# S3 method for class 'regsensitivity'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  ...,
  digits = NULL,
  finite_only = FALSE
)
```

## Arguments

- x:

  A `regsensitivity` object, from
  [`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md)
  or
  [`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md).

- row.names, optional:

  Ignored, present for S3 compatibility with
  [`base::as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

- ...:

  Ignored.

- digits:

  Optional number of significant digits to round numeric columns to.
  `NULL` (default) leaves the values at full precision, which is what
  you want when the result feeds further computation.

- finite_only:

  Logical. If `TRUE`, drop rows where every bound is non-finite.
  Defaults to `FALSE` so that the unbounded region of the sweep stays
  visible.

## Value

A `data.frame`.

## Details

This is the recommended entry point for producing tables. Because the
return value is an ordinary data frame it can be handed to whichever
table package you already use –
[`knitr::kable()`](https://rdrr.io/pkg/knitr/man/kable.html),
kableExtra, gt, modelsummary, huxtable, tinytable or xtable – rather
than committing the package to one of them.
[`regsen_table()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_table.md)
wraps the common case.

## Examples

``` r
# \donttest{
data(bfg2020)
res <- regsen_bounds(
    avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
    data = bfg2020, compare = c("log_area_2010", "lat", "lon"), cbar = 0.1
)
head(as.data.frame(res))
#>       rxbar rybar cbar       bmin     bmax
#> 1 0.0000000   Inf  0.1  1.3854162 1.385416
#> 2 0.2377361   Inf  0.1  0.5599466 2.210886
#> 3 0.4754721   Inf  0.1 -0.3235995 3.094432
#> 4 0.7132082   Inf  0.1 -1.2922838 4.063116
#> 5 0.9509442   Inf  0.1 -2.3863884 5.157221
#> 6 1.1886803   Inf  0.1 -3.6708919 6.441724
# }
```
