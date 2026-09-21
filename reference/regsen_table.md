# Render a sensitivity analysis as a publication-ready table

Formats the results of
[`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md)
or
[`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
for a manuscript. The `format` argument selects the output flavour, so
the same call works in an Rmd/Qmd document knitting to PDF, to HTML, or
to a Markdown target such as GitHub or Typst.

## Usage

``` r
regsen_table(
  x,
  format = NULL,
  digits = 3,
  caption = NULL,
  label = NULL,
  notes = NULL,
  booktabs = TRUE,
  threeparttable = TRUE,
  align = NULL,
  col_names = NULL,
  escape = TRUE,
  max_rows = NULL,
  ...
)
```

## Arguments

- x:

  A `regsensitivity` object.

- format:

  One of `"latex"`, `"html"`, `"markdown"`, `"pipe"` or `"simple"`.
  Defaults to `"latex"` when knitting to PDF and `"markdown"` otherwise.

- digits:

  Significant digits for the numeric columns.

- caption:

  Table caption. `NULL` for none.

- label:

  LaTeX label, used as `\\label{tab:<label>}`. Ignored for non-LaTeX
  formats.

- notes:

  Character vector of table notes, one element per line. Set to `NULL`
  for none, or `TRUE` to use an automatically generated note recording
  the analysis, hypothesis and sample size – which is the information a
  referee will look for.

- booktabs:

  Logical; use `booktabs` rules in LaTeX output.

- threeparttable:

  Logical; wrap LaTeX output and its notes in a `threeparttable`
  environment. Requires `\\usepackage{threeparttable}` in the document
  preamble.

- align:

  Column alignment string, e.g. `"lrrr"`. `NULL` left-aligns character
  columns and right-aligns numeric ones.

- col_names:

  Optional character vector of column headings. `NULL` uses tidied
  versions of the internal names.

- escape:

  Logical; escape special characters. Set `FALSE` if you are supplying
  LaTeX markup in `col_names` or `caption`.

- max_rows:

  Optional integer. If the sweep is longer than this, the table is
  thinned to `max_rows` evenly spaced rows and a note records that this
  happened. `NULL` keeps every row.

- ...:

  Passed to
  [`knitr::kable()`](https://rdrr.io/pkg/knitr/man/kable.html).

## Value

A `knitr_kable` object, which prints as the requested markup and renders
directly in an Rmd/Qmd chunk.

## Details

For LaTeX the default follows the convention most economics journals
expect: `booktabs` rules, and table notes wrapped in a `threeparttable`
environment so the note block is set to the width of the table rather
than the width of the page. Both are switchable.

Anything this function does not expose can be done by taking
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) of the
object and passing it to the table package of your choice; nothing here
is a dead end.

## Examples

``` r
# \donttest{
data(bfg2020)
res <- regsen_bounds(
    avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
    data = bfg2020, compare = c("log_area_2010", "lat", "lon"),
    cbar = c(0.1, 0.5, 1)
)
regsen_table(res, format = "markdown", digits = 3)
#> 
#> 
#> | rxbar| rybar|  cbar|  Lower| Upper|
#> |-----:|-----:|-----:|------:|-----:|
#> |     0|  +Inf| 0.100|   1.39|  1.39|
#> | 0.238|  +Inf| 0.100|  0.560|  2.21|
#> | 0.475|  +Inf| 0.100| -0.324|  3.09|
#> | 0.713|  +Inf| 0.100|  -1.29|  4.06|
#> | 0.951|  +Inf| 0.100|  -2.39|  5.16|
#> |  1.19|  +Inf| 0.100|  -3.67|  6.44|
#> |  1.43|  +Inf| 0.100|  -5.26|  8.03|
#> |  1.66|  +Inf| 0.100|  -7.40|  10.2|
#> |  1.90|  +Inf| 0.100|  -10.7|  13.4|
#> |  2.14|  +Inf| 0.100|  -17.5|  20.2|
#> |  2.38|  +Inf| 0.100|   -Inf|  +Inf|
#> |     0|  +Inf| 0.500|   1.39|  1.39|
#> | 0.238|  +Inf| 0.500|  0.552|  2.22|
#> | 0.475|  +Inf| 0.500| -0.479|  3.25|
#> | 0.713|  +Inf| 0.500|  -2.04|  4.81|
#> | 0.951|  +Inf| 0.500|  -4.80|  7.57|
#> |  1.19|  +Inf| 0.500|  -13.6|  16.4|
#> |  1.43|  +Inf| 0.500|   -Inf|  +Inf|
#> |  1.66|  +Inf| 0.500|   -Inf|  +Inf|
#> |  1.90|  +Inf| 0.500|   -Inf|  +Inf|
#> |  2.14|  +Inf| 0.500|   -Inf|  +Inf|
#> |  2.38|  +Inf| 0.500|   -Inf|  +Inf|
#> |     0|  +Inf|  1.00|   1.39|  1.39|
#> | 0.238|  +Inf|  1.00|  0.552|  2.22|
#> | 0.475|  +Inf|  1.00| -0.479|  3.25|
#> | 0.713|  +Inf|  1.00|  -2.27|  5.04|
#> | 0.951|  +Inf|  1.00|  -74.8|  77.5|
#> |  1.19|  +Inf|  1.00|   -Inf|  +Inf|
#> |  1.43|  +Inf|  1.00|   -Inf|  +Inf|
#> |  1.66|  +Inf|  1.00|   -Inf|  +Inf|
#> |  1.90|  +Inf|  1.00|   -Inf|  +Inf|
#> |  2.14|  +Inf|  1.00|   -Inf|  +Inf|
#> |  2.38|  +Inf|  1.00|   -Inf|  +Inf|
regsen_table(res, format = "latex", notes = TRUE,
             caption = "Identified sets", label = "idset")
#> \begin{table}
#> 
#> \caption{Identified sets}
#> \label{tab:idset}
#> \centering
#> \begin{threeparttable}
#> \begin{tabular}[t]{rrrrr}
#> \toprule
#> $\bar{r}_x$ & $\bar{r}_y$ & $\bar{c}$ & $\beta_{\min}$ & $\beta_{\max}$\\
#> \midrule
#> 0 & $+\infty$ & 0.100 & 1.39 & 1.39\\
#> 0.238 & $+\infty$ & 0.100 & 0.560 & 2.21\\
#> 0.475 & $+\infty$ & 0.100 & -0.324 & 3.09\\
#> 0.713 & $+\infty$ & 0.100 & -1.29 & 4.06\\
#> 0.951 & $+\infty$ & 0.100 & -2.39 & 5.16\\
#> \addlinespace
#> 1.19 & $+\infty$ & 0.100 & -3.67 & 6.44\\
#> 1.43 & $+\infty$ & 0.100 & -5.26 & 8.03\\
#> 1.66 & $+\infty$ & 0.100 & -7.40 & 10.2\\
#> 1.90 & $+\infty$ & 0.100 & -10.7 & 13.4\\
#> 2.14 & $+\infty$ & 0.100 & -17.5 & 20.2\\
#> \addlinespace
#> 2.38 & $+\infty$ & 0.100 & $-\infty$ & $+\infty$\\
#> 0 & $+\infty$ & 0.500 & 1.39 & 1.39\\
#> 0.238 & $+\infty$ & 0.500 & 0.552 & 2.22\\
#> 0.475 & $+\infty$ & 0.500 & -0.479 & 3.25\\
#> 0.713 & $+\infty$ & 0.500 & -2.04 & 4.81\\
#> \addlinespace
#> 0.951 & $+\infty$ & 0.500 & -4.80 & 7.57\\
#> 1.19 & $+\infty$ & 0.500 & -13.6 & 16.4\\
#> 1.43 & $+\infty$ & 0.500 & $-\infty$ & $+\infty$\\
#> 1.66 & $+\infty$ & 0.500 & $-\infty$ & $+\infty$\\
#> 1.90 & $+\infty$ & 0.500 & $-\infty$ & $+\infty$\\
#> \addlinespace
#> 2.14 & $+\infty$ & 0.500 & $-\infty$ & $+\infty$\\
#> 2.38 & $+\infty$ & 0.500 & $-\infty$ & $+\infty$\\
#> 0 & $+\infty$ & 1.00 & 1.39 & 1.39\\
#> 0.238 & $+\infty$ & 1.00 & 0.552 & 2.22\\
#> 0.475 & $+\infty$ & 1.00 & -0.479 & 3.25\\
#> \addlinespace
#> 0.713 & $+\infty$ & 1.00 & -2.27 & 5.04\\
#> 0.951 & $+\infty$ & 1.00 & -74.8 & 77.5\\
#> 1.19 & $+\infty$ & 1.00 & $-\infty$ & $+\infty$\\
#> 1.43 & $+\infty$ & 1.00 & $-\infty$ & $+\infty$\\
#> 1.66 & $+\infty$ & 1.00 & $-\infty$ & $+\infty$\\
#> \addlinespace
#> 1.90 & $+\infty$ & 1.00 & $-\infty$ & $+\infty$\\
#> 2.14 & $+\infty$ & 1.00 & $-\infty$ & $+\infty$\\
#> 2.38 & $+\infty$ & 1.00 & $-\infty$ & $+\infty$\\
#> \bottomrule
#> \end{tabular}
#> \begin{tablenotes}[flushleft]
#> \small
#> \item Sensitivity analysis: DMP (2026). Outcome: avgrep2000to2016. Treatment: tye\_tfe890\_500kNI\_100\_l6. N = 2,036.
#> \item Hypothesis: Beta > 0.
#> \end{tablenotes}
#> \end{threeparttable}
#> \end{table}
# }
```
