# Sensitivity summary (DMP bounds + Oster breakdown)

Runs the default sweep used by Stata's `regsensitivity` when no
subcommand is given: a DMP bounds analysis and an Oster breakdown
analysis at a few standard r2long values.

## Usage

``` r
regsen_summary(formula, data, compare = NULL, nocompare = NULL, subset = NULL)
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

A list with elements `dmp_bounds` and `oster_breakdown`, each a
`regsensitivity` object.
