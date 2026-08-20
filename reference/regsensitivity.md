# Regression sensitivity analysis

Top-level dispatcher that mirrors the Stata `regsensitivity` command.
For most users, calling [`regsen_bounds()`](regsen_bounds.md) or
[`regsen_breakdown()`](regsen_breakdown.md) directly is clearer.

## Usage

``` r
regsensitivity(
  subcommand = c("bounds", "breakdown", "summary"),
  formula,
  data,
  ...
)
```

## Arguments

- subcommand:

  One of `"bounds"`, `"breakdown"`, `"summary"`.

- formula:

  Two-sided formula: `y ~ x + w1 + w2 + ...`. The first right-hand-side
  variable is the primary independent variable; the rest are controls.

- data:

  A data.frame.

- ...:

  Additional arguments forwarded to the underlying function.

## Value

An object of class `regsensitivity`.

## See also

[`regsen_bounds()`](regsen_bounds.md),
[`regsen_breakdown()`](regsen_breakdown.md),
[`regsen_summary()`](regsen_summary.md)
