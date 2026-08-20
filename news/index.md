# Changelog

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
- User API: [`regsen_bounds()`](../reference/regsen_bounds.md),
  [`regsen_breakdown()`](../reference/regsen_breakdown.md),
  [`regsen_summary()`](../reference/regsen_summary.md),
  [`regsensitivity()`](../reference/regsensitivity.md) dispatcher,
  hypothesis helpers ([`bnd_lb()`](../reference/hypothesis_helpers.md),
  [`bnd_ub()`](../reference/hypothesis_helpers.md),
  [`bnd_eq()`](../reference/hypothesis_helpers.md)).
- Visualization:
  [`plot.regsensitivity()`](../reference/plot.regsensitivity.md)
  (ggplot2).
- Vignettes:
  - `regsensitivity`: end-to-end tour with the BFG2020 application.
  - `dmp2022-replication`: reproduces every table and figure of Diegert,
    Masten & Poirier (2026) that uses the bundled data.
  - `mp2022-stylized`: reproduces the stylized Oster examples from
    Masten & Poirier (2026).
- Bundled data: `bfg2020` (Bazzi, Fiszbein, Gebresilasse 2020, subset).
