# Breakdown frontier for a regression coefficient hypothesis

Find the smallest sensitivity-parameter value at which a given
hypothesis about the long-regression coefficient first fails. For DMP,
this is rxbar as a function of (cbar, rybar, beta). For Oster, this is
\|delta\| as a function of R-squared(long), beta and (optionally)
maxovb.

## Usage

``` r
regsen_breakdown(
  formula,
  data,
  analysis = c("dmp", "oster"),
  compare = NULL,
  nocompare = NULL,
  cbar = 1,
  rybar = Inf,
  rybar_expr = NULL,
  r2long = 1,
  maxovb = NA,
  r2long_type = c("eq", "relative"),
  maxovb_type = c("bound", "relative"),
  beta = "sign",
  ngrid = 200L,
  subset = NULL
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

- cbar, rybar, rybar_expr:

  (DMP) Same as in [`regsen_bounds()`](regsen_bounds.md).

- r2long, maxovb:

  (Oster) Same as in [`regsen_bounds()`](regsen_bounds.md).

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
    [`bnd_lb()`](hypothesis_helpers.md),
    [`bnd_ub()`](hypothesis_helpers.md),
    [`bnd_eq()`](hypothesis_helpers.md) to set the direction, e.g.
    `beta = bnd_lb(0)` for the hypothesis `beta > 0`.

- ngrid:

  Resolution of the finer grid stored in the result. Default 200.

- subset:

  Optional logical or integer vector indicating which rows of `data` to
  include in the estimation.

## Value

A `regsensitivity` object.

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
