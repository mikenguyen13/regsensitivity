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
#> | 0.253|  +Inf| 0.100|  0.505|  2.27|
#> | 0.506|  +Inf| 0.100| -0.443|  3.21|
#> | 0.759|  +Inf| 0.100|  -1.49|  4.26|
#> |  1.01|  +Inf| 0.100|  -2.70|  5.47|
#> |  1.27|  +Inf| 0.100|  -4.14|  6.91|
#> |  1.52|  +Inf| 0.100|  -6.01|  8.78|
#> |  1.77|  +Inf| 0.100|  -8.67|  11.4|
#> |  2.02|  +Inf| 0.100|  -13.4|  16.2|
#> |  2.28|  +Inf| 0.100|  -29.3|  32.1|
#> |  2.53|  +Inf| 0.100|   -Inf|  +Inf|
#> |     0|  +Inf| 0.500|   1.39|  1.39|
#> | 0.253|  +Inf| 0.500|  0.494|  2.28|
#> | 0.506|  +Inf| 0.500| -0.645|  3.42|
#> | 0.759|  +Inf| 0.500|  -2.45|  5.22|
#> |  1.01|  +Inf| 0.500|  -5.97|  8.74|
#> |  1.27|  +Inf| 0.500|  -35.7|  38.4|
#> |  1.52|  +Inf| 0.500|   -Inf|  +Inf|
#> |  1.77|  +Inf| 0.500|   -Inf|  +Inf|
#> |  2.02|  +Inf| 0.500|   -Inf|  +Inf|
#> |  2.28|  +Inf| 0.500|   -Inf|  +Inf|
#> |  2.53|  +Inf| 0.500|   -Inf|  +Inf|
#> |     0|  +Inf|  1.00|   1.39|  1.39|
#> | 0.253|  +Inf|  1.00|  0.494|  2.28|
#> | 0.506|  +Inf|  1.00| -0.645|  3.42|
#> | 0.759|  +Inf|  1.00|  -2.89|  5.66|
#> |  1.01|  +Inf|  1.00|   -Inf|  +Inf|
#> |  1.27|  +Inf|  1.00|   -Inf|  +Inf|
#> |  1.52|  +Inf|  1.00|   -Inf|  +Inf|
#> |  1.77|  +Inf|  1.00|   -Inf|  +Inf|
#> |  2.02|  +Inf|  1.00|   -Inf|  +Inf|
#> |  2.28|  +Inf|  1.00|   -Inf|  +Inf|
#> |  2.53|  +Inf|  1.00|   -Inf|  +Inf|
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
#> \$\textbackslash{}bar\{r\}\_x\$ & \$\textbackslash{}bar\{r\}\_y\$ & \$\textbackslash{}bar\{c\}\$ & \$\textbackslash{}beta\_\{\textbackslash{}min\}\$ & \$\textbackslash{}beta\_\{\textbackslash{}max\}\$\\
#> \midrule
#> 0 & \$+\textbackslash{}infty\$ & 0.100 & 1.39 & 1.39\\
#> 0.253 & \$+\textbackslash{}infty\$ & 0.100 & 0.505 & 2.27\\
#> 0.506 & \$+\textbackslash{}infty\$ & 0.100 & -0.443 & 3.21\\
#> 0.759 & \$+\textbackslash{}infty\$ & 0.100 & -1.49 & 4.26\\
#> 1.01 & \$+\textbackslash{}infty\$ & 0.100 & -2.70 & 5.47\\
#> \addlinespace
#> 1.27 & \$+\textbackslash{}infty\$ & 0.100 & -4.14 & 6.91\\
#> 1.52 & \$+\textbackslash{}infty\$ & 0.100 & -6.01 & 8.78\\
#> 1.77 & \$+\textbackslash{}infty\$ & 0.100 & -8.67 & 11.4\\
#> 2.02 & \$+\textbackslash{}infty\$ & 0.100 & -13.4 & 16.2\\
#> 2.28 & \$+\textbackslash{}infty\$ & 0.100 & -29.3 & 32.1\\
#> \addlinespace
#> 2.53 & \$+\textbackslash{}infty\$ & 0.100 & \$-\textbackslash{}infty\$ & \$+\textbackslash{}infty\$\\
#> 0 & \$+\textbackslash{}infty\$ & 0.500 & 1.39 & 1.39\\
#> 0.253 & \$+\textbackslash{}infty\$ & 0.500 & 0.494 & 2.28\\
#> 0.506 & \$+\textbackslash{}infty\$ & 0.500 & -0.645 & 3.42\\
#> 0.759 & \$+\textbackslash{}infty\$ & 0.500 & -2.45 & 5.22\\
#> \addlinespace
#> 1.01 & \$+\textbackslash{}infty\$ & 0.500 & -5.97 & 8.74\\
#> 1.27 & \$+\textbackslash{}infty\$ & 0.500 & -35.7 & 38.4\\
#> 1.52 & \$+\textbackslash{}infty\$ & 0.500 & \$-\textbackslash{}infty\$ & \$+\textbackslash{}infty\$\\
#> 1.77 & \$+\textbackslash{}infty\$ & 0.500 & \$-\textbackslash{}infty\$ & \$+\textbackslash{}infty\$\\
#> 2.02 & \$+\textbackslash{}infty\$ & 0.500 & \$-\textbackslash{}infty\$ & \$+\textbackslash{}infty\$\\
#> \addlinespace
#> 2.28 & \$+\textbackslash{}infty\$ & 0.500 & \$-\textbackslash{}infty\$ & \$+\textbackslash{}infty\$\\
#> 2.53 & \$+\textbackslash{}infty\$ & 0.500 & \$-\textbackslash{}infty\$ & \$+\textbackslash{}infty\$\\
#> 0 & \$+\textbackslash{}infty\$ & 1.00 & 1.39 & 1.39\\
#> 0.253 & \$+\textbackslash{}infty\$ & 1.00 & 0.494 & 2.28\\
#> 0.506 & \$+\textbackslash{}infty\$ & 1.00 & -0.645 & 3.42\\
#> \addlinespace
#> 0.759 & \$+\textbackslash{}infty\$ & 1.00 & -2.89 & 5.66\\
#> 1.01 & \$+\textbackslash{}infty\$ & 1.00 & \$-\textbackslash{}infty\$ & \$+\textbackslash{}infty\$\\
#> 1.27 & \$+\textbackslash{}infty\$ & 1.00 & \$-\textbackslash{}infty\$ & \$+\textbackslash{}infty\$\\
#> 1.52 & \$+\textbackslash{}infty\$ & 1.00 & \$-\textbackslash{}infty\$ & \$+\textbackslash{}infty\$\\
#> 1.77 & \$+\textbackslash{}infty\$ & 1.00 & \$-\textbackslash{}infty\$ & \$+\textbackslash{}infty\$\\
#> \addlinespace
#> 2.02 & \$+\textbackslash{}infty\$ & 1.00 & \$-\textbackslash{}infty\$ & \$+\textbackslash{}infty\$\\
#> 2.28 & \$+\textbackslash{}infty\$ & 1.00 & \$-\textbackslash{}infty\$ & \$+\textbackslash{}infty\$\\
#> 2.53 & \$+\textbackslash{}infty\$ & 1.00 & \$-\textbackslash{}infty\$ & \$+\textbackslash{}infty\$\\
#> \bottomrule
#> \end{tabular}
#> \begin{tablenotes}[flushleft]
#> \small
#> \item Sensitivity analysis: DMP (2026). Outcome: avgrep2000to2016. Treatment: tye_tfe890_500kNI_100_l6. N = 2,036.
#> \item Hypothesis: Beta > 0.
#> \end{tablenotes}
#> \end{threeparttable}
#> \end{table}
# }
```
