---
title: 'regsensitivity: Regression sensitivity analysis for omitted variable bias in R'
tags:
  - R
  - econometrics
  - sensitivity analysis
  - omitted variable bias
  - causal inference
authors:
  - name: Mike Nguyen
    orcid: 0000-0000-0000-0000
    corresponding: true
    affiliation: 1
affiliations:
  - name: Independent researcher
    index: 1
date: 23 May 2026
bibliography: paper.bib
---

# Summary

`regsensitivity` is an R package for assessing how omitted variable bias
would affect the coefficient of interest in a linear regression. It
implements, in pure R, the identified-set and breakdown-point analyses
of @Diegert2026, @Oster2019 and @Masten2026 under a unified,
formula-based interface, with `ggplot2`-based plotting, a
percentile/cluster bootstrap on the breakdown point, and `testthat`
assertions that pin the empirical output to the published values in the
underlying methodology papers.

# Statement of need

Sensitivity analysis for omitted variable bias is a routine part of
empirical work in economics and adjacent fields. The most widely used
method [@Oster2019] and its endogenous-controls generalization
[@Diegert2026] have, until now, lacked a complete and CRAN-ready R
implementation. Existing R offerings either implement only the Oster
(2019) analysis or do not expose the breakdown-frontier machinery in a
programmable way.

`regsensitivity` fills that gap. It provides:

1. The full DMP (2026) identified set for the long-regression coefficient
   under the three sensitivity parameters $\bar r_X$, $\bar r_Y$,
   $\bar c$, including the closed-form regimes
   ($\bar r_Y = \infty$ or $\bar c = 0$) and the nonconvex regime
   ($\bar r_Y < \infty$, $\bar c > 0$) which is solved with the DIRECT
   global optimizer via `nloptr` [@Johnson2024].
2. The DMP breakdown frontier across $\bar c$, $\bar r_Y$ and hypothesis
   values, with bisection over the nonconvex regime.
3. The Oster (2019) identified set in both equality ($\delta = d$) and
   bound ($|\delta| \le \bar d$) modes, plus the Masten--Poirier (2026)
   `maxovb` extension.
4. A formula-and-data interface (`regsen_bounds()`,
   `regsen_breakdown()`, `regsen_summary()`) that fits naturally into R
   workflows.
5. `ggplot2` rendering of bounds and breakdown frontiers, and explicit
   helpers for the rho-calibration of @Diegert2026 Section 3.4.

The package ships with the Bazzi--Fiszbein--Gebresilasse [@BFG2020]
replication subset as the `bfg2020` data frame, and includes three
vignettes: a tour, a paper-replication vignette that reproduces Tables
1, 3 and 4 of DMP (2026) to within one unit in the last published digit,
and a stylized illustration of the Masten--Poirier extensions.

# Reproducibility

Every reported value in DMP (2026) Table 1 column (5) is pinned by a
`testthat` assertion against the package output:

| DMP (2026) Table 1, col (5)             | Paper | `regsensitivity` |
|-----------------------------------------|------:|-----------------:|
| $\hat\beta_{\text{med}}$                | 2.055 | 2.0548           |
| $\hat{\bar r}_X^{bp} \times 100$        |  80.4 | 80.36            |
| $\hat{\bar r}^{bp} \times 100$          |  95.9 | 95.84            |
| Oster $\hat\delta^{bp}_{\text{resid}}$  | -23.3 | -23.29           |

All ten partial-$R^2$ values of DMP (2026) Table 3 and all ten $\rho_k$
calibration values of Table 4 column (5) are likewise pinned in
`tests/testthat/test-paper-table1.R`. Every one agrees with the
published value to within 0.06; three of the twenty differ in the last
digit the paper prints ($\hat c_k^2$ of 0.8938 against 0.893 for average
temperature and 0.5588 against 0.560 for average rainfall, and
$\hat\rho_k$ of 20.25 against 20.2 for elevation), which is consistent
with rounding in the published tables rather than a difference in
estimand.

# Software design

`regsensitivity` is structured around an immutable summary-of-the-DGP
object (`class regsen_dgp`) computed once per analysis: the variance
matrix of $(Y, X, W_1)$ after partialling out $W_0$, and quantities
derived from it ($\beta_{\text{med}}$, $R^2_{\text{med}}$, the
basis-change matrix used by the global optimizer, etc.). Every analysis
function is a pure function from this DGP object plus
sensitivity-parameter values to a result table; the plotting layer reads
only that table. The result of a call carries class `regsensitivity`
with `print()`, `summary()` and `plot()` methods.

The DIRECT global optimization required when
$\bar r_Y < \infty, \bar c > 0$ is delegated to `nloptr`'s
`NLOPT_GN_DIRECT_L` algorithm, which is mature, portable and well-tested
across CRAN. Polynomial roots are taken via base R `polyroot()`. All
numerics are kept double precision.

# References
