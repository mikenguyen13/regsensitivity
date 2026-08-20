# Hypothesis-direction helpers

Convenience wrappers for specifying the direction of a hypothesis used
by [`regsen_breakdown()`](regsen_breakdown.md) and
[`regsen_bounds()`](regsen_bounds.md).

## Usage

``` r
bnd_lb(x)

bnd_ub(x)

bnd_eq(x)
```

## Arguments

- x:

  Numeric scalar or vector of hypothesis values.

## Examples

``` r
bnd_lb(0)
#> [1] 0
#> attr(,"sign")
#> [1] ">"
bnd_ub(4)
#> [1] 4
#> attr(,"sign")
#> [1] "<"
bnd_eq(0)
#> [1] 0
#> attr(,"sign")
#> [1] "="
```
