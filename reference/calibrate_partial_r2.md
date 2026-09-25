# Pairwise partial R-squared of calibration covariates

For each `W1[k]`, computes \$\$R^2\_{W\_{1k} \sim W\_{1,-k} \cdot
W_0}\$\$ i.e. the R-squared of regressing the `W0`-residualized `W1[k]`
on the `W0`-residualized `W1[-k]`. Matches Table 3 in DMP (2026): a
quick read on how collinear the comparison controls are.

## Usage

``` r
calibrate_partial_r2(
  formula,
  data,
  compare = NULL,
  nocompare = NULL,
  subset = NULL
)
```

## Arguments

- formula:

  Two-sided formula: `y ~ x + w1 + w2 + ...`. The first right-hand-side
  variable is the primary independent variable; the rest are controls.

- data:

  A data.frame.

- compare:

  Optional character vector of variables to use as the comparison set.
  Defaults to all controls if neither `compare` nor `nocompare` is
  given.

- nocompare:

  Optional character vector of controls to *exclude* from the comparison
  set.

- subset:

  Optional logical or integer vector indicating which rows of `data` to
  include in the estimation.

## Value

A data.frame with columns `variable` and `R2`.

## Examples

``` r
data(bfg2020)
calibrate_partial_r2(
  avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 +
    log_area_2010 + lat + lon,
  data = bfg2020
)
#>        variable          R2
#> 3           lon 0.184922201
#> 1 log_area_2010 0.182701680
#> 2           lat 0.006174835
```
