# Bounds on a regression coefficient under omitted-variable bias

Computes the identified set for the coefficient on the primary
independent variable in the infeasible long regression, across a grid of
sensitivity parameters. Implements the analyses of Diegert, Masten &
Poirier (2026) (the default) and of Oster (2019) extended by Masten &
Poirier (2026).

## Usage

``` r
regsen_bounds(
  formula,
  data,
  analysis = c("dmp", "oster"),
  compare = NULL,
  nocompare = NULL,
  rxbar = NULL,
  rybar = Inf,
  cbar = 1,
  clow = 0,
  rybar_expr = NULL,
  delta = NULL,
  r2long = 1,
  maxovb = NA,
  delta_type = c("eq", "bound"),
  r2long_type = c("eq", "relative"),
  maxovb_type = c("bound", "relative"),
  beta = "sign",
  product = TRUE,
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

- rxbar, rybar, cbar:

  (DMP) Numeric vectors of sensitivity-parameter values to sweep over.
  `rybar = Inf` (the default) gives the no-rybar case; setting it finite
  invokes the global-optimization code path.

- clow:

  (DMP) Lower bound on control endogeneity, the `clow` of DMP Assumption
  A6 `R(W2 ~ W1 . W0) %in% [clow, cbar]`. Default 0, which asserts
  nothing beyond `cbar`. A positive value asserts that the controls are
  *at least* that endogenous. Must satisfy `0 <= clow <= min(cbar)`.

- rybar_expr:

  (DMP) A function `function(rxbar) rybar` to set rybar as a function of
  rxbar (the only supported form in the Stata source is `rybar = rxbar`,
  i.e. `function(rxbar) rxbar`).

- delta, r2long, maxovb:

  (Oster) Numeric vectors of sensitivity values.

- delta_type:

  One of `"eq"` (equality, the default) or `"bound"`.

- r2long_type:

  One of `"eq"` (the default) or `"relative"`. When `"relative"`, values
  are multiplied by R-squared(medium).

- maxovb_type:

  One of `"bound"` (default) or `"relative"`. When `"relative"`, values
  are multiplied by \|Beta(medium)\|.

- beta:

  Hypothesis spec for the breakdown point. See
  [`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md).

- product:

  Logical. If `TRUE` (default), all combinations of the
  sensitivity-parameter grids are evaluated; if `FALSE`, the inputs are
  zipped element-wise. Maps to Stata's `noproduct` option (inverted).

- subset:

  Optional logical or integer vector indicating which rows of `data` to
  include in the estimation.

## Value

A `regsensitivity` object. The `results` field holds a data.frame with
one row per sensitivity-parameter point.

For a breakdown analysis, `results$breakdown` is **signed**: its sign
carries the direction of selection, and for Oster it is the `delta` that
solves Proposition 3 for the hypothesised value. Feeding that value back
into `regsen_bounds()` recovers the hypothesised beta, but feeding
[`abs()`](https://rdrr.io/r/base/MathFun.html) of it lands on a
different branch of the cubic. The scalar `$breakdown` field and the
print method report the magnitude, since that is what is quoted as "the
breakdown point". Note that the scalar exists on `regsen_bounds()`
output only; a
[`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
result carries the value in `results$breakdown` alone.

## Examples

``` r
# \donttest{
data(bfg2020)
bnds <- regsen_bounds(
  avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 +
    log_area_2010 + lat + lon + temp_mean + rain_mean + elev_mean +
    d_coa + d_riv + d_lak + ave_gyi,
  data = bfg2020,
  cbar = 0.1
)
print(bnds)
#> 
#> Regression Sensitivity Analysis ----- Bounds
#> ------------------------------------------------------------------------
#> Analysis:          DMP (2026)
#> Treatment:         tye_tfe890_500kNI_100_l6
#> Outcome:           avgrep2000to2016
#> N (obs):           2036
#> Hypothesis:        Beta > 0
#> Breakdown point:   0.3726
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
#>    rxbar rybar   cbar     bmin   bmax
#>        0  +Inf    0.1   1.5864 1.5864
#>  0.20427  +Inf    0.1   0.7386 2.4343
#>  0.40855  +Inf    0.1 -0.16388 3.3368
#>  0.61282  +Inf    0.1  -1.1489 4.3218
#>   0.8171  +Inf    0.1  -2.2576 5.4304
#>   1.0214  +Inf    0.1  -3.5556 6.7285
#>   1.2256  +Inf    0.1  -5.1601  8.333
#>   1.4299  +Inf    0.1  -7.3101 10.483
#>   1.6342  +Inf    0.1  -10.614 13.786
#>   1.8385  +Inf    0.1  -17.445 20.618
#>   2.0427  +Inf    0.1     -Inf   +Inf
# }
```
