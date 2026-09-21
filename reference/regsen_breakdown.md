# Breakdown frontier for a regression coefficient hypothesis

Find the smallest sensitivity-parameter value at which a given
hypothesis about the long-regression coefficient first fails. For DMP,
this is rxbar as a function of (cbar, rybar, beta) or – with
`direction = "rybar"` – rybar as a function of (rxbar, cbar, beta). For
Oster, this is \|delta\| as a function of R-squared(long), beta and
(optionally) maxovb.

## Usage

``` r
regsen_breakdown(
  formula,
  data,
  analysis = c("dmp", "oster"),
  compare = NULL,
  nocompare = NULL,
  cbar = 1,
  clow = 0,
  rybar = Inf,
  rybar_expr = NULL,
  direction = c("rxbar", "rybar"),
  rxbar = NULL,
  r2long = 1,
  maxovb = NA,
  r2long_type = c("eq", "relative"),
  maxovb_type = c("bound", "relative"),
  beta = "sign",
  subset = NULL,
  ncores = NULL
)
```

## Arguments

- formula:

  Two-sided formula: `y ~ x + w1 + w2 + ...`. The first right-hand-side
  variable is the primary independent variable; the rest are controls.

- data:

  A data.frame.

- analysis:

  Which sensitivity analysis to run: `"dmp"` (default) or `"oster"`.

- compare:

  Optional character vector of variables to use as the comparison set.
  Defaults to all controls if neither `compare` nor `nocompare` is
  given.

- nocompare:

  Optional character vector of controls to *exclude* from the comparison
  set.

- cbar, clow, rybar, rybar_expr:

  (DMP) Same as in
  [`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md).

- direction:

  (DMP) Which sensitivity parameter the breakdown point is reported in:
  `"rxbar"` (default) sweeps `cbar` or `beta` and solves for rxbar;
  `"rybar"` sweeps `rxbar` and solves for rybar, the frontier
  `rybar_bf(rxbar)` of DMP (2026) Theorem 4. The two trace the same
  frontier, but only the rybar direction can describe its horizontal
  arm, where the conclusion survives every rxbar and the rxbar breakdown
  point is `+Inf`.

- rxbar:

  (DMP, `direction = "rybar"`) Numeric vector of rxbar values at which
  to evaluate the frontier. Defaults to an 11-point grid over
  `[0, 2 * rmax(cbar)]`.

- r2long, maxovb:

  (Oster) Same as in
  [`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md).

- r2long_type:

  One of `"eq"` (the default) or `"relative"`. When `"relative"`, values
  are multiplied by R-squared(medium).

- maxovb_type:

  One of `"bound"` (default) or `"relative"`. When `"relative"`, values
  are multiplied by \|Beta(medium)\|.

- beta:

  Hypothesis spec. One of:

  - `"sign"` – the hypothesis that sign(beta_long) = sign(beta_med).

  - a numeric scalar or vector. Use the helpers
    [`bnd_lb()`](https://mikenguyen13.github.io/regsensitivity/reference/hypothesis_helpers.md),
    [`bnd_ub()`](https://mikenguyen13.github.io/regsensitivity/reference/hypothesis_helpers.md),
    [`bnd_eq()`](https://mikenguyen13.github.io/regsensitivity/reference/hypothesis_helpers.md)
    to set the direction, e.g. `beta = bnd_lb(0)` for the hypothesis
    `beta > 0`.

- subset:

  Optional logical or integer vector indicating which rows of `data` to
  include in the estimation.

- ncores:

  Number of cores to spread the frontier's values over. `NULL` (default)
  uses the session setting of
  [`regsen_cores()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_cores.md);
  `"auto"` uses all but two of the machine's cores. Only frontiers that
  need the optimizer (finite `rybar`, `rybar_expr`, or
  `direction = "rybar"`) are costly enough to benefit. Results are
  identical for any number of cores.

## Value

A `regsensitivity` object. `results$index` holds the swept parameter and
`results$breakdown` the breakdown point at each value.

## Details

For `analysis = "oster"` the hypothesis selects between two quantities
that Masten and Poirier (2026) distinguish. An equality hypothesis
(`beta = bnd_eq(0)`) returns the *explain away* breakdown point: the
signed delta at which beta_long equals the hypothesized value, the
number `psacalc` reports. An inequality or sign hypothesis (the default)
returns the *sign change* breakdown point: the smallest \|delta\| at
which some value on the wrong side of the hypothesis enters the
identified set. The two can differ by an order of magnitude and the
second is the one that bears on whether the conclusion could be wrong.

Their Theorem 2 shows the sign change breakdown point can never exceed
one, so without `maxovb` the reported value is capped at 1: a printed
`1` means the sign survives every \|delta\| below the conventional
cutoff, not that a solution was found there. Supplying `maxovb` adds the
assumption that lifts the cap.

## Examples

``` r
# \donttest{
data(bfg2020)
bk <- regsen_breakdown(
  avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 +
    log_area_2010 + lat + lon + temp_mean + rain_mean + elev_mean +
    d_coa + d_riv + d_lak + ave_gyi,
  data = bfg2020,
  cbar = seq(0, 1, 0.1)
)
print(bk)
#> 
#> Regression Sensitivity Analysis ----- Breakdown Frontier
#> ------------------------------------------------------------------------
#> Analysis:          DMP (2026)
#> Treatment:         tye_tfe890_500kNI_100_l6
#> Outcome:           avgrep2000to2016
#> N (obs):           2036
#> Hypothesis:        Beta > 0
#> 
#> --- Summary statistics ----------------------------------
#>   Beta (short)                  1.7078
#>   Beta (medium)                 1.5864
#>   R2 (short)                    0.0269
#>   R2 (medium)                   0.1345
#>   Var(Y)                      136.3204
#>   Var(X)                        1.2574
#>   Var(X_Residual)               1.0903
#> 
#> --- Results ---------------------------------------------
#>   index breakdown
#>       0   0.38508
#>     0.1    0.3726
#>     0.2   0.36438
#>     0.3   0.36007
#>     0.4   0.35936
#>     0.5   0.35936
#>     0.6   0.35936
#>     0.7   0.35936
#>     0.8   0.35936
#>     0.9   0.35936
#>       1   0.35936
# }
```
