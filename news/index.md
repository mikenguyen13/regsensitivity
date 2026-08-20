# Changelog

## regsensitivity (development version)

### Plots

- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) gains
  `xline`, drawing vertical reference lines. This closes a gap against
  the Stata package, whose vignette uses `xline()` to mark values such
  as `rmax` or a breakdown point; those figures could not be reproduced
  in R before.
- New
  [`theme_regsen()`](https://mikenguyen13.github.io/regsensitivity/reference/theme_regsen.md)
  and
  [`scale_colour_regsen()`](https://mikenguyen13.github.io/regsensitivity/reference/scale_colour_regsen.md),
  exported so a plot can be rebuilt with the same look. Defaults are
  aimed at print: a faint y-grid, a thin panel border, legend on top,
  and the colourblind-safe Okabe-Ito palette, which also survives
  greyscale printing.
- Axis and legend titles now use plotmath, so they read as the symbols
  in the papers rather than as parameter names.
- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) gains
  `base_size`; use `9` for a two-column journal figure.
- Passing `NA` to `title`, `subtitle`, `xtitle` or `ytitle` drops the
  annotation. The auto-generated subtitle is no longer applied by
  default, since a journal figure carries its description in the
  caption.

### Documentation

- New vignette “Publication-ready plots and tables”, covering figure
  sizing for journals, greyscale and colour-vision safety, and the LaTeX
  / HTML / Markdown table output.
- New vignette “Coming from the Stata package”, mapping every command
  and option in the Stata package’s own vignette onto its R equivalent.
  It doubles as a coverage check: a gap would show as a missing row
  rather than going unnoticed.

### Interoperability

- New
  [`regsen_tidy()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_tidy.md)
  and
  [`regsen_glance()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_tidy.md),
  broom-style tidiers. They are registered on
  [`generics::tidy()`](https://generics.r-lib.org/reference/tidy.html)/`glance()`
  when is installed, so results flow into and anything else speaking
  that vocabulary; `generics` stays a Suggests.
- New
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  method, forwarding to
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html).

### Replication

- The DMP (2026) vignette now checks its numbers against the published
  values in a table, and
  [`stopifnot()`](https://rdrr.io/r/base/stopifnot.html)s the
  comparison, so a regression stops the build instead of quietly
  shipping a wrong replication.
- Calibration labels in the Figure 1 overlay are staggered across three
  x positions; at a single x they collided into an unreadable stack.

### Tables

- New [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)
  method returning the results as a plain data frame, so they can be
  passed to any table package (kableExtra, gt, modelsummary, huxtable,
  tinytable, xtable).
- New
  [`regsen_table()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_table.md)
  rendering results as LaTeX, HTML or Markdown, so the same call works
  in an Rmd/Qmd knitting to PDF, HTML or Markdown. LaTeX output uses
  `booktabs` and puts notes in a `threeparttable`, with `notes = TRUE`
  generating a note recording the analysis, hypothesis and sample size.
  Infinite bounds render as the correct symbol per format rather than
  being blanked out.

## regsensitivity 0.1.1

- Fix a Windows-only crash when the DIRECT optimizer (DMP analysis with
  `rybar < Inf` and `cbar > 0`) explored parameter points where
  `varx_bounds()` returned NA endpoints. The downstream
  `quad_ineq_bounds()` did unguarded `if (b1 <= r1 && b2 <= r1)`
  comparisons which evaluated to `NA` and triggered “missing value where
  TRUE/FALSE needed”. Symptoms: BFG2020 vignette failed to build on
  Windows (Status: 1 ERROR on win-builder), but built clean on macOS due
  to floating-point determinism differences in nloptr’s DIRECT-L.
- Audit all bare `if (...)` numeric comparisons in `dmp.R` and guard
  against NA propagation. Every comparison now uses
  [`isTRUE()`](https://rdrr.io/r/base/Logic.html) /
  [`isFALSE()`](https://rdrr.io/r/base/Logic.html) so a single NA cannot
  poison the dispatch logic.
- Add 13 NA-robustness regression tests pinning the failure mode
  (`tests/testthat/test-na-robustness.R`).

## regsensitivity 0.1.0

- Initial CRAN-ready release.
- Implements:
  - DMP (2026) identified set and breakdown frontier (`rybar = Inf`
    analytic, `rybar < Inf, cbar = 0` analytic, `rybar < Inf, cbar > 0`
    via DIRECT global optimization (`nloptr`)).
  - Oster (2019) identified set (`eq` and `bound` modes) and breakdown
    points.
  - Masten & Poirier (2026) `maxovb` extension.
- User API:
  [`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md),
  [`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md),
  [`regsen_summary()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_summary.md),
  [`regsensitivity()`](https://mikenguyen13.github.io/regsensitivity/reference/regsensitivity.md)
  dispatcher, hypothesis helpers
  ([`bnd_lb()`](https://mikenguyen13.github.io/regsensitivity/reference/hypothesis_helpers.md),
  [`bnd_ub()`](https://mikenguyen13.github.io/regsensitivity/reference/hypothesis_helpers.md),
  [`bnd_eq()`](https://mikenguyen13.github.io/regsensitivity/reference/hypothesis_helpers.md)).
- Visualization:
  [`plot.regsensitivity()`](https://mikenguyen13.github.io/regsensitivity/reference/plot.regsensitivity.md)
  (ggplot2).
- Vignettes:
  - `regsensitivity`: end-to-end tour with the BFG2020 application.
  - `dmp2022-replication`: reproduces every table and figure of Diegert,
    Masten & Poirier (2026) that uses the bundled data.
  - `mp2022-stylized`: reproduces the stylized Oster examples from
    Masten & Poirier (2026).
- Bundled data: `bfg2020` (Bazzi, Fiszbein, Gebresilasse 2020, subset).
