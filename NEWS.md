# regsensitivity 0.2.0

## The identified set is now computed everywhere

* The region `rxbar > rmax(cbar) > rybar` no longer raises an error.
  `regsen_bounds()` and `regsen_breakdown()` compute it like any other,
  and the numbers agree with an independent search over the constraint
  set of DMP (2026) Theorem 5 to within 0.01, continuously across
  `rmax`.

  What stood in the way was the solver for the constraint Assumption A3
  places on `z`. That constraint is a quadratic inequality whose leading
  coefficient turns negative exactly when `rxbar * ||c|| > 1`; its
  solution set is then the complement of an interval, not an interval,
  and the solver returned the hull of the two pieces. Sampling that hull
  hands the optimizer selection equations that violate A3, so the region
  was refused rather than reported. The feasible set is now represented
  as the list of intervals it is, and sampled in proportion to their
  lengths.

* The breakdown point in `rxbar` is no longer capped at `rmax(cbar)`.
  That ceiling binds only when `rybar` is unrestricted; with `rybar`
  finite the breakdown point can lie well past it. Where no `rxbar`
  overturns the conclusion -- the horizontal arm of the breakdown
  frontier -- the reported value is now `+Inf` instead of the ceiling.

* `regsen_breakdown()` gains `direction = "rybar"`, giving the frontier
  `rybar_bf(rxbar)` of DMP (2026) Theorem 4 over a grid of `rxbar`. This
  is the form the paper's Figure 1 plots, and the only one that can
  describe the frontier's horizontal arm.

## Assumption A6 in its general form

* `regsen_bounds()` and `regsen_breakdown()` gain `clow`, the lower end
  of DMP Assumption A6, `R(W2 ~ W1 . W0)` in `[clow, cbar]`. Asserting
  that the controls are *at least* somewhat endogenous tightens the
  identified set and raises the breakdown point. `clow = 0`, the default,
  is the previous behaviour.

## Inference

* `regsen_boot()` now reports a bias-corrected and accelerated (BCa)
  interval alongside the percentile interval, and returns it by default;
  `type = "perc"` restores the old choice. The acceleration comes from a
  delete-one jackknife over the units the bootstrap resamples -- rows, or
  clusters under a cluster bootstrap. In the simulation design of the
  package's paper at `n = 500`, coverage improves from 92.0% to 94.0%
  against a nominal 95% at the same interval width; the two agree by
  `n = 1000`. `z0` and `acceleration` are returned so the correction can
  be inspected, and an endpoint that falls on an extreme replicate is
  reported as such.
* Bootstrap replicates are around seven times faster on the bundled data.
  A replicate is now a row subset of model matrices built once, rather
  than a fresh `model.frame()` call per draw.

## Bug fixes

* `rmax`, the `rxbar` at which the identified set becomes unbounded, was
  wrong for `cbar < 1`. It solved the `cbar` branch of DMP appendix
  equation (S18) unconditionally, when the maximising `||c||` is `rxbar`
  itself wherever A6 allows it. With `cbar = 0.5` on the bundled data it
  reported 1.48 where the set is in fact unbounded from 1.19, so
  `regsen_bounds()` printed a large finite number in place of an infinite
  one across that range, and the default `rxbar` grid ran past the point
  where the analysis says anything.
* A breakdown point for an upper-bound hypothesis (`beta = bnd_ub(v)`)
  was computed from the lower end of the identified set. With `rybar`
  finite the set is not symmetric around `beta_med`, so the reported
  value was wrong; the tested end is now chosen by the direction of the
  hypothesis.
* An equality hypothesis (`beta = bnd_eq(v)`) now breaks down at whichever
  end of the identified set can reach the hypothesised value, rather than
  always at the upper one.

## Accuracy and speed

* The global optimizer behind the finite-`rybar` identified set now
  polishes its result with a local search. Bounds agree with a run twenty
  times as long to within 3e-4, where the previous setting could be off
  by 0.02.
* A breakdown search evaluates only the end of the identified set its
  hypothesis tests, and finds the crossing by root-finding rather than
  fixed-iteration bisection. Together these make a breakdown point at
  finite `rybar` several times faster despite the more accurate optimizer.

# regsensitivity 0.1.2

## Plots

* The Oster equality identified-set plot no longer draws a false vertical
  connector where the numerically ordered solution branches swap arms
  across an asymptote. Branches are now split exactly where a step would
  cross a vertical asymptote of `delta(beta)`, computed from the model
  rather than guessed from the drawing. With several `r2long` values the
  curves are now drawn (and coloured) per `r2long` instead of being
  interleaved into one line.

* `plot()` gains `xline`, drawing vertical reference lines. This closes a
  gap against the Stata package, whose vignette uses `xline()` to mark
  values such as `rmax` or a breakdown point; those figures could not be
  reproduced in R before.
* New `theme_regsen()` and `scale_colour_regsen()` (with `scale_color_regsen()`
  and `scale_fill_regsen()` aliases), exported so a plot can
  be rebuilt with the same look. Defaults are aimed at print: a faint
  y-grid, a thin panel border, legend on top, and the colourblind-safe
  Okabe-Ito palette, which also survives greyscale printing.
* Axis and legend titles now use plotmath, so they read as the symbols in
  the papers rather than as parameter names.
* `plot()` gains `base_size`; use `9` for a two-column journal figure.
* Passing `NA` to `title`, `subtitle`, `xtitle` or `ytitle` drops the
  annotation. The auto-generated subtitle is no longer applied by default,
  since a journal figure carries its description in the caption.

## Calibration

* New `calibrate_rho()` and `calibrate_partial_r2()`, computing the
  point-identified reference values of DMP (2026) Section 3.4 (Table 4)
  and Table 3, so the sensitivity parameters can be read against the
  observed covariates they are calibrated to.

## Verification

* The Oster (2019) implementation is now checked against the paper rather
  than against its own past output. A test round-trips Proposition 3 into
  Proposition 2: the delta reported as the breakdown for a target beta,
  fed back through the identified set, must return that beta. It does, to
  machine precision, for several targets.
* `results$breakdown` is documented as **signed**. The sign carries the
  direction of selection; passing `abs()` of it back into
  `regsen_bounds()` lands on a different branch of the Oster cubic. The
  scalar `$breakdown` reports the magnitude and exists on `regsen_bounds()`
  output only -- a `regsen_breakdown()` result carries the value in
  `results$breakdown` alone.

## Replication fidelity

* The DMP (2026) Figure 1 reproduction now matches the published figure.
  The left panel gains the dashed bounds under the common-maximal-impact
  restriction `rybar = rxbar` and the Table 4 calibration tick marks; both
  zero crossings are reported and agree with the published 0.804 and 0.959.
  The right panel previously plotted the breakdown point against `cbar`,
  a different object from the paper's, which is the breakdown frontier in
  (rxbar, rybar) space; it is now that frontier, one curve per `cbar`.
* `plot()` no longer paints a line along the panel edge when a stretch of
  the sweep is unbounded. Only the first point of each unbounded run is
  routed off-panel and the rest are blank, so the curve leaves the plot
  once instead of running along its boundary. Runs are detected per series,
  so one beginning at a group boundary still gets its own exit.

## Bug fixes

* `regsen_bounds(analysis = "oster", delta_type = "bound")` reported a
  bounded identified set where the set is in fact unbounded. The solver
  correctly returns `-Inf`/`Inf` for `|delta| <= dbar` with `dbar >= 1`,
  but the routine accumulating bounds across the grid discarded infinite
  values alongside `NA` and carried the last finite bound forward. On the
  bundled data, `delta = c(0.5, 1, 2)` reported `[1.31, 2.98]` at every
  point instead of `(-Inf, Inf)` from `dbar = 1` on.

  `NA` still carries over, since it means the solver failed and carries no
  information; an infinity is a bound and now propagates. This is the one
  direction a sensitivity analysis must not err in, since it made results
  look more robust than they are. Previously validated numbers are
  unchanged -- the snapshot tests pass untouched.

## Interactive

* New `regsen_explore()`, a shiny application for moving the sensitivity
  parameters by hand and watching the identified set respond. \pkg{shiny}
  is a Suggests, so the rest of the package works without it. Inputs are
  validated and the model is fitted once before the app opens, so a bad
  call reports at the console rather than as a banner in a browser tab.

## Several treatments

* New `regsen_multi()`, running the analysis once per candidate treatment
  and collecting the breakdown points into one table, with a `plot()`
  method ordering treatments by fragility. Every treatment is analysed in
  the same specification -- the others stay as controls -- so the rows are
  comparable. A treatment whose analysis fails yields an `NA` row with the
  reason rather than aborting the sweep.

## Inference

* `regsen_boot()` gains `ncores`, running replications in parallel: forking
  on macOS and Linux, a PSOCK cluster on Windows. A progress bar is not
  shown in parallel, since it cannot report meaningfully from several
  workers.
* Results for a given `seed` are now identical regardless of `ncores`.
  Each replicate seeds itself from a vector drawn once up front, rather
  than relying on parallel RNG substreams, which would have made the
  numbers depend on how the work happened to be divided.

## Documentation

* New vignette "Publication-ready plots and tables", covering figure
  sizing for journals, greyscale and colour-vision safety, and the LaTeX
  / HTML / Markdown table output.
* New vignette "Coming from the Stata package", mapping every command and
  option in the Stata package's own vignette onto its R equivalent. It
  doubles as a coverage check: a gap would show as a missing row rather
  than going unnoticed.

## Interoperability

* New `regsen_tidy()` and `regsen_glance()`, broom-style tidiers. They are
  registered on `generics::tidy()`/`glance()` when \pkg{generics} is
  installed, so results flow into \pkg{modelsummary} and anything else
  speaking that vocabulary; `generics` stays a Suggests.
* New `autoplot()` method, forwarding to `plot()`.

## Replication

* The DMP (2026) vignette now checks its numbers against the published
  values in a table, and `stopifnot()`s the comparison, so a regression
  stops the build instead of quietly shipping a wrong replication.
* Calibration labels in the Figure 1 overlay are staggered across three x
  positions; at a single x they collided into an unreadable stack.

## Tables

* New `as.data.frame()` method returning the results as a plain data frame,
  so they can be passed to any table package (kableExtra, gt, modelsummary,
  huxtable, tinytable, xtable).
* New `regsen_table()` rendering results as LaTeX, HTML or Markdown, so the
  same call works in an Rmd/Qmd knitting to PDF, HTML or Markdown. LaTeX
  output uses `booktabs` and puts notes in a `threeparttable`, with
  `notes = TRUE` generating a note recording the analysis, hypothesis and
  sample size. Infinite bounds render as the correct symbol per format
  rather than being blanked out.

# regsensitivity 0.1.1

* Fix a Windows-only crash when the DIRECT optimizer
  (DMP analysis with `rybar < Inf` and `cbar > 0`) explored parameter
  points where `varx_bounds()` returned NA endpoints. The downstream
  `quad_ineq_bounds()` did unguarded `if (b1 <= r1 && b2 <= r1)`
  comparisons which evaluated to `NA` and triggered "missing value where
  TRUE/FALSE needed". Symptoms: BFG2020 vignette failed to build on
  Windows (Status: 1 ERROR on win-builder), but built clean on macOS due
  to floating-point determinism differences in nloptr's DIRECT-L.
* Audit all bare `if (...)` numeric comparisons in `dmp.R` and guard
  against NA propagation. Every comparison now uses `isTRUE()` /
  `isFALSE()` so a single NA cannot poison the dispatch logic.
* Add 13 NA-robustness regression tests pinning the failure mode
  (`tests/testthat/test-na-robustness.R`).

# regsensitivity 0.1.0

* Initial CRAN-ready release.
* Implements:
  * DMP (2026) identified set and breakdown frontier
    (`rybar = Inf` analytic, `rybar < Inf, cbar = 0` analytic,
    `rybar < Inf, cbar > 0` via DIRECT global optimization (`nloptr`)).
  * Oster (2019) identified set (`eq` and `bound` modes) and
    breakdown points.
  * Masten & Poirier (2026) `maxovb` extension.
* User API: `regsen_bounds()`, `regsen_breakdown()`, `regsen_summary()`,
  `regsensitivity()` dispatcher, hypothesis helpers
  (`bnd_lb()`, `bnd_ub()`, `bnd_eq()`).
* Visualization: `plot.regsensitivity()` (ggplot2).
* Vignettes:
  * `regsensitivity`: end-to-end tour with the BFG2020 application.
  * `dmp2022-replication`: reproduces every table and figure of
    Diegert, Masten & Poirier (2026) that uses the bundled data.
  * `mp2022-stylized`: reproduces the stylized Oster examples from
    Masten & Poirier (2026).
* Bundled data: `bfg2020` (Bazzi, Fiszbein, Gebresilasse 2020, subset).
