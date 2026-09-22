# Changelog

## regsensitivity 0.2.0

### The Oster equality identified-set plot draws the actual branches

- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) on an
  `analysis = "oster"`, `delta_type = "eq"` sweep now groups the roots
  by branch rather than by sort order. Up to three roots come back per
  `delta`, sorted within each `delta`, so the root continuing a given
  branch moves between the `beta1`/`beta2`/`beta3` columns wherever a
  fold adds two roots or one escapes to infinity. Drawing a column as a
  line cut continuous branches into pieces and joined unrelated ones; a
  heuristic that broke the line at an asymptote and at `delta = 1`
  suppressed the false connectors but left visible gaps in curves that
  are not broken.

  Branch identity does not need a heuristic. `delta(beta)` is a ratio of
  cubics; between two consecutive poles of it the map is continuous and
  single valued, so the roots in one pole interval are one branch, and
  walking that interval in increasing `beta` traverses it end to end. A
  branch that folds back is not a function of `delta`, so the branches
  are drawn with
  [`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html).

- A zero of the denominator of `delta(beta)` that is also a zero of its
  numerator is a hole, not an asymptote, and no longer splits a branch.
  With a single control covariate it is the only real root of the
  denominator, which made that case a single continuous curve reported
  as two.

- The spurious root – the one solving the cubic at every `delta`, since
  it is that common root – no longer survives at scattered `delta` and
  draws a stray spur along the asymptote. Its residual is set by how
  accurately [`polyroot()`](https://rdrr.io/r/base/polyroot.html)
  locates it, which is well above the few digits of machine epsilon the
  filter allowed.

- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) warns when a
  `delta` grid is too coarse to draw anything, and errors when Oster’s
  cubic has no real solution anywhere on it. Passing `delta = c(-3, 3)`
  – the endpoints, as Stata’s `delta()` takes them, rather than the grid
  – silently produced an empty panel.

### The identified set is now computed everywhere

- The region `rxbar > rmax(cbar) > rybar` no longer raises an error.
  [`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md)
  and
  [`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
  compute it like any other, and the numbers agree with an independent
  search over the constraint set of DMP (2026) Theorem 5 to within 0.01,
  continuously across `rmax`.

  What stood in the way was the solver for the constraint Assumption A3
  places on `z`. That constraint is a quadratic inequality whose leading
  coefficient turns negative exactly when `rxbar * ||c|| > 1`; its
  solution set is then the complement of an interval, not an interval,
  and the solver returned the hull of the two pieces. Sampling that hull
  hands the optimizer selection equations that violate A3, so the region
  was refused rather than reported. The feasible set is now represented
  as the list of intervals it is, and sampled in proportion to their
  lengths.

- The breakdown point in `rxbar` is no longer capped at `rmax(cbar)`.
  That ceiling binds only when `rybar` is unrestricted; with `rybar`
  finite the breakdown point can lie well past it. Where no `rxbar`
  overturns the conclusion – the horizontal arm of the breakdown
  frontier – the reported value is now `+Inf` instead of the ceiling.

- [`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
  gains `direction = "rybar"`, giving the frontier `rybar_bf(rxbar)` of
  DMP (2026) Theorem 4 over a grid of `rxbar`. This is the form the
  paper’s Figure 1 plots, and the only one that can describe the
  frontier’s horizontal arm.

### Assumption A6 in its general form

- [`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md)
  and
  [`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
  gain `clow`, the lower end of DMP Assumption A6, `R(W2 ~ W1 . W0)` in
  `[clow, cbar]`. Asserting that the controls are *at least* somewhat
  endogenous tightens the identified set and raises the breakdown point.
  `clow = 0`, the default, is the previous behaviour.

### Parallel computation

- [`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md),
  [`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
  and
  [`regsen_multi()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_multi.md)
  gain an `ncores` argument, joining
  [`regsen_boot()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_boot.md),
  and all four default to the session setting of the new
  [`regsen_cores()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_cores.md).
  The grid points of an identified set, the values of a breakdown
  frontier and the treatments of a multi-treatment sweep are independent
  and are spread across the cores; on the bundled data a finite-`rybar`
  frontier runs about three times faster on six cores. Results are
  identical for any number of cores: nothing but the bootstrap draws
  random numbers, and it seeds each replicate itself.
- The default stays serial, as CRAN policy requires of a package that
  has not been asked. `regsen_cores("auto")` sets the session to all but
  two of the machine’s cores; `regsen_cores(n)` sets a number. Work
  inside a bootstrap replicate or a treatment always runs serially, so
  cores are not oversubscribed by nesting.
- The socket backend that Windows uses can be selected on any machine
  with `options(regsensitivity.backend = "psock")`, and the test suite
  runs it everywhere, so a change that works under fork but not on
  Windows is caught before it ships. Arguments a worker closure touches
  are forced before the closure is built: a socket worker is a fresh
  session and would otherwise receive an unevaluated promise into a
  frame it does not have.
- A replicate or grid point that errors is now confined to its own slot.
  `mclapply()` preschedules jobs onto cores and marks every job on a
  core as failed when one errors, so a single bad bootstrap resample
  used to take a whole core’s worth of replicates down with it.

### Inference

- [`regsen_boot()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_boot.md)
  now reports a bias-corrected and accelerated (BCa) interval alongside
  the percentile interval, and returns it by default; `type = "perc"`
  restores the old choice. The acceleration comes from a delete-one
  jackknife over the units the bootstrap resamples – rows, or clusters
  under a cluster bootstrap. In the simulation design of the package’s
  paper at `n = 500`, coverage improves from 92.0% to 94.0% against a
  nominal 95% at the same interval width; the two agree by `n = 1000`.
  `z0` and `acceleration` are returned so the correction can be
  inspected, and an endpoint that falls on an extreme replicate is
  reported as such.
- Bootstrap replicates are about three times faster on the bundled data,
  5 milliseconds against 14. A replicate is now a row subset of model
  matrices built once, rather than a fresh
  [`model.frame()`](https://rdrr.io/r/stats/model.frame.html) call per
  draw, which is what makes the BCa jackknife – one computation per row
  – affordable.

### Bug fixes

- `rmax`, the `rxbar` at which the identified set becomes unbounded, was
  wrong for `cbar < 1`. It solved the `cbar` branch of DMP appendix
  equation (S18) unconditionally, when the maximising `||c||` is `rxbar`
  itself wherever A6 allows it. With `cbar = 0.5` on the bundled data,
  calibrating against the ten geographic and climate covariates, it
  reported 1.48 where the set is in fact unbounded from 1.19, so
  [`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md)
  printed a large finite number in place of an infinite one across that
  range, and the default `rxbar` grid ran past the point where the
  analysis says anything.
- A breakdown point for an upper-bound hypothesis (`beta = bnd_ub(v)`)
  was computed from the lower end of the identified set. With `rybar`
  finite the set is not symmetric around `beta_med`, so the reported
  value was wrong; the tested end is now chosen by the direction of the
  hypothesis.
- An equality hypothesis (`beta = bnd_eq(v)`) now breaks down at
  whichever end of the identified set can reach the hypothesised value,
  rather than always at the upper one.
- A name in `compare` or `nocompare` that is not a control on the
  right-hand side of the formula – a typo, or the treatment itself – is
  now an error. It used to be dropped silently, so a misspelt covariate
  quietly changed which variables calibrated the analysis.
- The sensitivity parameters are validated: `cbar` must lie in `[0, 1]`,
  `rxbar` and `rybar` must be non-negative, `r2long` non-negative and
  `maxovb` non-negative or `NA`, and none may be missing. Out-of-range
  values used to reach the closed forms and the optimizer and come back
  as `NA` without explanation.
- Under `analysis = "oster"` with `delta_type = "bound"`, a `maxovb` cap
  is now applied at `delta >= 1` too. The raw set is the whole real line
  there, and the cap was skipped, so the reported bounds were `-Inf` and
  `+Inf` where the constraint says `beta_med - maxovb` and
  `beta_med + maxovb`.
- Comparison covariates that are collinear with one another are dropped,
  as the documentation already said and as Stata does; only those
  collinear with `W0` were. `Var(W1)` is singular otherwise, and the
  analysis went through a regularised inverse of it. The test for
  collinearity with `W0` is now relative to the covariate’s own
  variance, so a covariate measured in small units is no longer mistaken
  for a constant.
- [`regsen_boot()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_boot.md)
  keeps replicates on which the breakdown point is `+Inf` – the
  hypothesis survived every value of the sensitivity parameter – in both
  intervals, where they count as `+Inf`. They were dropped along with
  failed replicates, so an interval whose upper tail is unbounded was
  reported with a finite upper endpoint. The count is returned as
  `$infinite` and printed.
- [`print()`](https://rdrr.io/r/base/print.html) of a
  [`regsen_boot()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_boot.md)
  result reports the interval for the magnitude of a signed (Oster)
  breakdown point correctly. Taking
  [`abs()`](https://rdrr.io/r/base/MathFun.html) of each endpoint
  reversed a negative interval and, for one straddling zero, hid that
  the magnitude may be as small as zero.
- `regsen_table(label = ...)` warns when `caption` is not given, since
  [`knitr::kable()`](https://rdrr.io/pkg/knitr/man/kable.html) emits a
  float only with a caption and the label had nowhere to attach; it was
  dropped silently. The `r2long` column head uses `\mathrm` rather than
  `\text`, so it no longer needs `amsmath`.
- [`scale_colour_regsen()`](https://mikenguyen13.github.io/regsensitivity/reference/scale_colour_regsen.md)
  and
  [`scale_fill_regsen()`](https://mikenguyen13.github.io/regsensitivity/reference/scale_colour_regsen.md)
  recycle the palette (with a warning) when a sweep has more than eight
  groups, instead of erroring inside
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html).
- The default y-range of an identified-set plot is read off both bounds.
  It was read off the lower bound alone, which cropped the upper one
  whenever the set is not symmetric about `beta_med` (finite `rybar`, or
  Oster).
- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) of a result
  whose sensitivity parameters are all single values says so, rather
  than failing with a subscript error.
- A logical `subset` containing `NA` treats `NA` as `FALSE`, as
  [`subset()`](https://rdrr.io/r/base/subset.html) does. The `NA` used
  to select a row of missing values and leave an `NA` in the row
  bookkeeping that
  [`regsen_boot()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_boot.md)
  uses to line up a cluster column.
- The `ngrid` argument of
  [`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md)
  and
  [`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
  is removed: it was documented but never used.
- The explorer app no longer errors when the `rybar` box is left at its
  default. A numeric input cannot carry `Inf`, so blank now means
  unrestricted, and a cleared box greys the panel instead of raising.
- Masten and Poirier (2026) is cited as published, in the *American
  Economic Review* 116(7), rather than as an arXiv preprint.

### Documentation

- New vignette, *Reading the output: interpretation, edge cases and
  decisions*
  ([`vignette("interpreting-results")`](https://mikenguyen13.github.io/regsensitivity/articles/interpreting-results.md)).
  It says what each number means, gives a decision path from breakdown
  point and `rho_k` to a verdict, and walks through the cases that
  confuse readers – a robust and a fragile conclusion on worlds where
  the omitted variable exists, a breakdown point of zero, a set that is
  unbounded early because the calibration set is weak, what goes in
  `compare`, when `cbar` matters, an infinite breakdown point under
  finite `rybar`, the two Oster breakdown points, and how to read the
  bootstrap print – each with the sentence to write in the paper. It
  ends with a list of common mistakes and a reporting checklist.

- The two Oster breakdown points now carry the names Masten and Poirier

  2026. give them, in
        [`?regsen_breakdown`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md),
        the interpretation vignette and the paper: the *explain away*
        point (`beta = bnd_eq(0)`; the `psacalc` number) and the *sign
        change* point (the default). The documentation also states that
        the sign change value is capped at one by their Theorem 2, not
        by convention, and that only `maxovb` lifts the cap. On the
        frontier data the two are -23.3 and 0.974, and a reader who took
        one for the other reached the opposite verdict.

### Verification

- The identified set is now checked against worlds in which the omitted
  variable exists. Each test world simulates `W2`, reads the true
  `beta_long`, `r_X`, `r_Y` and `c` off it by the projections DMP (2026)
  define them through, and requires the package’s set at exactly those
  parameters to contain `beta_long` – with `rybar` unrestricted, with
  `rybar` finite (the optimizer), and with two-sided A6. A search over
  constructed omitted variables on fixed observed data stays inside the
  `rybar = Inf` set and reaches within 15% of its ends, so the set is
  neither invalid nor loose.
- Property tests pin what must hold on any data: sets nest as each
  parameter is relaxed and collapse to `beta_med` at `rxbar = 0`; the
  breakdown point is where the tested bound crosses the hypothesis;
  `rmax` is where the set becomes unbounded; rescaling `Y` or `X` scales
  the bounds as the model says, and rescaling, shifting or reordering
  the covariates leaves bounds and breakdown points unchanged, for both
  DMP and Oster.

### Accuracy and speed

- The global optimizer behind the finite-`rybar` identified set now
  polishes its result with a local search. Bounds agree with a run
  twenty times as long to within 3e-4, where the previous setting could
  be off by 0.02.
- A breakdown search evaluates only the end of the identified set its
  hypothesis tests, and finds the crossing by root-finding rather than
  fixed-iteration bisection. Together these make a breakdown point at
  finite `rybar` several times faster despite the more accurate
  optimizer.

## regsensitivity 0.1.2

### Plots

- The Oster equality identified-set plot no longer draws a false
  vertical connector where the numerically ordered solution branches
  swap arms across an asymptote. Branches are now split exactly where a
  step would cross a vertical asymptote of `delta(beta)`, computed from
  the model rather than guessed from the drawing. With several `r2long`
  values the curves are now drawn (and coloured) per `r2long` instead of
  being interleaved into one line.

- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) gains
  `xline`, drawing vertical reference lines. This closes a gap against
  the Stata package, whose vignette uses `xline()` to mark values such
  as `rmax` or a breakdown point; those figures could not be reproduced
  in R before.

- New
  [`theme_regsen()`](https://mikenguyen13.github.io/regsensitivity/reference/theme_regsen.md)
  and
  [`scale_colour_regsen()`](https://mikenguyen13.github.io/regsensitivity/reference/scale_colour_regsen.md)
  (with
  [`scale_color_regsen()`](https://mikenguyen13.github.io/regsensitivity/reference/scale_colour_regsen.md)
  and
  [`scale_fill_regsen()`](https://mikenguyen13.github.io/regsensitivity/reference/scale_colour_regsen.md)
  aliases), exported so a plot can be rebuilt with the same look.
  Defaults are aimed at print: a faint y-grid, a thin panel border,
  legend on top, and the colourblind-safe Okabe-Ito palette, which also
  survives greyscale printing.

- Axis and legend titles now use plotmath, so they read as the symbols
  in the papers rather than as parameter names.

- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) gains
  `base_size`; use `9` for a two-column journal figure.

- Passing `NA` to `title`, `subtitle`, `xtitle` or `ytitle` drops the
  annotation. The auto-generated subtitle is no longer applied by
  default, since a journal figure carries its description in the
  caption.

### Calibration

- New
  [`calibrate_rho()`](https://mikenguyen13.github.io/regsensitivity/reference/calibrate_rho.md)
  and
  [`calibrate_partial_r2()`](https://mikenguyen13.github.io/regsensitivity/reference/calibrate_partial_r2.md),
  computing the point-identified reference values of DMP (2026) Section
  3.4 (Table 4) and Table 3, so the sensitivity parameters can be read
  against the observed covariates they are calibrated to.

### Verification

- The Oster (2019) implementation is now checked against the paper
  rather than against its own past output. A test round-trips
  Proposition 3 into Proposition 2: the delta reported as the breakdown
  for a target beta, fed back through the identified set, must return
  that beta. It does, to machine precision, for several targets.
- `results$breakdown` is documented as **signed**. The sign carries the
  direction of selection; passing
  [`abs()`](https://rdrr.io/r/base/MathFun.html) of it back into
  [`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md)
  lands on a different branch of the Oster cubic. The scalar
  `$breakdown` reports the magnitude and exists on
  [`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md)
  output only – a
  [`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
  result carries the value in `results$breakdown` alone.

### Replication fidelity

- The DMP (2026) Figure 1 reproduction now matches the published figure.
  The left panel gains the dashed bounds under the common-maximal-impact
  restriction `rybar = rxbar` and the Table 4 calibration tick marks;
  both zero crossings are reported and agree with the published 0.804
  and 0.959. The right panel previously plotted the breakdown point
  against `cbar`, a different object from the paper’s, which is the
  breakdown frontier in (rxbar, rybar) space; it is now that frontier,
  one curve per `cbar`.
- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) no longer
  paints a line along the panel edge when a stretch of the sweep is
  unbounded. Only the first point of each unbounded run is routed
  off-panel and the rest are blank, so the curve leaves the plot once
  instead of running along its boundary. Runs are detected per series,
  so one beginning at a group boundary still gets its own exit.

### Bug fixes

- `regsen_bounds(analysis = "oster", delta_type = "bound")` reported a
  bounded identified set where the set is in fact unbounded. The solver
  correctly returns `-Inf`/`Inf` for `|delta| <= dbar` with `dbar >= 1`,
  but the routine accumulating bounds across the grid discarded infinite
  values alongside `NA` and carried the last finite bound forward. On
  the bundled data, `delta = c(0.5, 1, 2)` reported `[1.31, 2.98]` at
  every point instead of `(-Inf, Inf)` from `dbar = 1` on.

  `NA` still carries over, since it means the solver failed and carries
  no information; an infinity is a bound and now propagates. This is the
  one direction a sensitivity analysis must not err in, since it made
  results look more robust than they are. Previously validated numbers
  are unchanged – the snapshot tests pass untouched.

### Interactive

- New
  [`regsen_explore()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_explore.md),
  a shiny application for moving the sensitivity parameters by hand and
  watching the identified set respond. is a Suggests, so the rest of the
  package works without it. Inputs are validated and the model is fitted
  once before the app opens, so a bad call reports at the console rather
  than as a banner in a browser tab.

### Several treatments

- New
  [`regsen_multi()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_multi.md),
  running the analysis once per candidate treatment and collecting the
  breakdown points into one table, with a
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) method
  ordering treatments by fragility. Every treatment is analysed in the
  same specification – the others stay as controls – so the rows are
  comparable. A treatment whose analysis fails yields an `NA` row with
  the reason rather than aborting the sweep.

### Inference

- [`regsen_boot()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_boot.md)
  gains `ncores`, running replications in parallel: forking on macOS and
  Linux, a PSOCK cluster on Windows. A progress bar is not shown in
  parallel, since it cannot report meaningfully from several workers.
- Results for a given `seed` are now identical regardless of `ncores`.
  Each replicate seeds itself from a vector drawn once up front, rather
  than relying on parallel RNG substreams, which would have made the
  numbers depend on how the work happened to be divided.

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
