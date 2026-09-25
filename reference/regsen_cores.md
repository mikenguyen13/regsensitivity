# Cores used by the package

Sets or reads the number of cores that
[`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md),
[`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md),
[`regsen_multi()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_multi.md)
and
[`regsen_boot()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_boot.md)
use by default. Each of those also takes an `ncores` argument for a
single call; this sets the session-wide default those arguments fall
back to, held in `options(regsensitivity.ncores)`.

## Usage

``` r
regsen_cores(n = NULL)
```

## Arguments

- n:

  One of:

  - `NULL` (default): read the current setting without changing it.

  - a positive integer: use that many cores.

  - `"auto"`: use `parallel::detectCores() - 2`, and at least 1. Two are
    left free so the session, and whatever else the machine is doing,
    stay responsive.

  Whatever is set, at most 2 are used while `R CMD check --as-cran` is
  running, which forbids more.

## Value

The number of cores in effect after the call, invisibly when `n` is
given.

## Details

Parallel runs return exactly what serial runs return. The identified set
and the breakdown frontiers draw no random numbers, and the bootstrap
seeds each replicate from a vector drawn once up front, so nothing
depends on how the work was divided.

On macOS and Linux the work is forked with
[`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html), so
the data and model need no copying. Windows has no fork; it gets a PSOCK
cluster, which is slower to start and pays to ship the data once, so
there the gain is only worth having for long jobs (a bootstrap, or a
finite-`rybar` sweep with many grid points).

What is parallel: the grid points of a
[`regsen_bounds()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_bounds.md)
sweep (only the finite-`rybar` regime costs anything; the closed forms
are cheap either way), the values of a
[`regsen_breakdown()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_breakdown.md)
frontier, the treatments of
[`regsen_multi()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_multi.md),
and the replicates and jackknife of
[`regsen_boot()`](https://mikenguyen13.github.io/regsensitivity/reference/regsen_boot.md).
Work inside a replicate or a treatment is run serially, so cores are
never oversubscribed by nesting.

## Examples

``` r
old <- getOption("regsensitivity.ncores")
regsen_cores()          # the current setting, 1 unless changed
#> [1] 1
regsen_cores(2)         # run the sweeps on two cores
regsen_cores(1)         # back to serial
options(regsensitivity.ncores = old)
if (FALSE) { # \dontrun{
# Uses every core but two, so it is not run inside checks.
regsen_cores("auto")
} # }
```
