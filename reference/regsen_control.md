# Tuning for the finite-`rybar` optimizer

With `rybar` finite and `cbar > 0`, the DMP (2026) identified set has no
closed form. Each bound is found by a global search over the unit cube
(the DIRECT-L algorithm), followed by a local polish (Subplex) started
from the point the global search returned. `regsen_control()` sets the
budget of both. Pass the result to the `control` argument of
[`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md)
or
[`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md);
[`regsen_boot()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_boot.md)
and
[`regsen_multi()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_multi.md)
hand it on through `...`.

## Usage

``` r
regsen_control(maxiter = 1000L, polish = 300L, precision = 1e-08)
```

## Arguments

- maxiter:

  Maximum number of objective evaluations in the global search, per
  bound. Default 1000.

- polish:

  Maximum number of evaluations in the local polish, per bound. `0`
  skips the polish. Default 300.

- precision:

  Relative tolerance on the parameter point at which the global search
  stops; the polish uses one hundredth of it. Default 1e-8.

## Value

A list of class `regsen_control`.

## Details

The defaults agree to within about 3e-4 with a run twenty times as long
on the bundled data. To check a result of your own, run it again with a
larger budget, for example
`regsen_control(maxiter = 5000, polish = 1500)`, and compare: bounds
that move by more than you care about mean the default budget is too
small for your problem. The closed-form regimes (`rybar = Inf`, or
`cbar = 0`) and the Oster analysis ignore these settings.

## Examples

``` r
regsen_control()
#> <regsen_control> maxiter = 1000, polish = 300, precision = 1e-08
regsen_control(maxiter = 5000, polish = 1500)
#> <regsen_control> maxiter = 5000, polish = 1500, precision = 1e-08
```
