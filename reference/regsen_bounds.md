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
  rybar_expr = NULL,
  delta = NULL,
  r2long = 1,
  maxovb = NA,
  delta_type = c("eq", "bound"),
  r2long_type = c("eq", "relative"),
  maxovb_type = c("bound", "relative"),
  beta = "sign",
  product = TRUE,
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

- rxbar, rybar, cbar:

  (DMP) Numeric vectors of sensitivity-parameter values to sweep over.
  `rybar = Inf` (the default) gives the no-rybar case; setting it finite
  invokes the global-optimization code path.

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
  [`regsen_breakdown()`](regsen_breakdown.md).

- product:

  Logical. If `TRUE` (default), all combinations of the
  sensitivity-parameter grids are evaluated; if `FALSE`, the inputs are
  zipped element-wise. Maps to Stata's `noproduct` option (inverted).

- ngrid:

  Resolution of the finer grid stored in the result. Default 200.

- subset:

  Optional logical or integer vector indicating which rows of `data` to
  include in the estimation.

## Value

A `regsensitivity` object. The `results` field holds a data.frame with
one row per sensitivity-parameter point.

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
#>  0.22448  +Inf    0.1  0.65214 2.5207
#>  0.44897  +Inf    0.1 -0.35117  3.524
#>  0.67345  +Inf    0.1  -1.4627 4.6356
#>  0.89793  +Inf    0.1  -2.7437 5.9165
#>   1.1224  +Inf    0.1  -4.3004 7.4733
#>   1.3469  +Inf    0.1  -6.3455 9.5184
#>   1.5714  +Inf    0.1  -9.4032 12.576
#>   1.7959  +Inf    0.1  -15.393 18.566
#>   2.0204  +Inf    0.1  -60.525 63.698
#>   2.2448  +Inf    0.1     -Inf   +Inf
# }
```
