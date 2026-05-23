

# regsensitivity

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![R-CMD-check](https://github.com/mikenguyen13/regsensitivity/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/mikenguyen13/regsensitivity/actions/workflows/R-CMD-check.yaml)
[![Codecov](https://codecov.io/gh/mikenguyen13/regsensitivity/graph/badge.svg)](https://app.codecov.io/gh/mikenguyen13/regsensitivity)
[![CRAN status](https://www.r-pkg.org/badges/version/regsensitivity)](https://CRAN.R-project.org/package=regsensitivity)
[![CRAN downloads](https://cranlogs.r-pkg.org/badges/grand-total/regsensitivity)](https://CRAN.R-project.org/package=regsensitivity)
<!-- badges: end -->

Regression sensitivity analysis for omitted-variable bias in R.

Implements the identified-set and breakdown-point analyses described in:

-   **Diegert, Masten and Poirier (2026)** — bounds on the
    long-regression coefficient under relaxations of the
    no-omitted-variables assumption, indexed by `rxbar` / `rybar` /
    `cbar`.
-   **Oster (2019)** — identified set in `(delta, R²(long))` and the
    associated breakdown point.
-   **Masten and Poirier (2026)** — extension with a maximum
    omitted-variable-bias constraint.

> Both arXiv working papers above are still revised periodically;
> citations in this package track the year of the latest arXiv revision.

The package provides a formula + `data.frame` API, `ggplot2`-based
plotting, and a percentile/cluster bootstrap on the breakdown point.

## Installation

``` r
# Released version (once accepted on CRAN):
install.packages("regsensitivity")

# Development version from GitHub:
# install.packages("remotes")
remotes::install_github("mikenguyen13/regsensitivity")

# Pre-built binary from r-universe:
install.packages("regsensitivity",
                 repos = c("https://mikenguyen13.r-universe.dev",
                           "https://cloud.r-project.org"))
```

## Quickstart

``` r
library(regsensitivity)
data(bfg2020)
bfg2020$statea <- factor(bfg2020$statea)

compare <- c("log_area_2010", "lat", "lon", "temp_mean", "rain_mean",
             "elev_mean", "d_coa", "d_riv", "d_lak", "ave_gyi")
form <- avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 +
    log_area_2010 + lat + lon + temp_mean + rain_mean + elev_mean +
    d_coa + d_riv + d_lak + ave_gyi + statea

# Default DMP analysis, cbar = 0.1
bnds <- regsen_bounds(form, bfg2020, compare = compare, cbar = 0.1)
print(bnds)
plot(bnds)

# Breakdown across cbar grid
bd <- regsen_breakdown(form, bfg2020, compare = compare,
                        cbar = seq(0, 1, 0.05))
plot(bd)

# Cluster bootstrap CI on the breakdown point
boot <- regsen_boot(form, bfg2020, compare = compare,
                     cbar = 1, cluster = "km_grid_cel_code",
                     R = 199)
print(boot)
```

See `vignette("regsensitivity")` for a full tour, and
`vignette("dmp2022-replication")` for the paper-exact replication.

## Crosswalk: Stata → R

| Stata syntax                                                 | R equivalent                                                                               |
|--------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| `regsensitivity bounds y x w, compare(w1) cbar(.1)`          | `regsen_bounds(y ~ x + w, data, compare = w1, cbar = 0.1)`                                 |
| `regsensitivity bounds ... cbar(0(.2)1)`                     | `regsen_bounds(..., cbar = seq(0, 1, 0.2))`                                                |
| `regsensitivity bounds ... rybar(=rxbar)`                    | `regsen_bounds(..., rybar_expr = function(rx) rx)`                                         |
| `regsensitivity bounds ... oster`                            | `regsen_bounds(..., analysis = "oster")`                                                   |
| `regsensitivity bounds ... oster delta(-3 3 eq)`             | `regsen_bounds(..., analysis = "oster", delta = seq(-3, 3, 0.05))`                         |
| `regsensitivity bounds ... oster delta(0(.001).999 bound)`   | `regsen_bounds(..., analysis = "oster", delta = seq(0, .999, .001), delta_type = "bound")` |
| `regsensitivity breakdown ... cbar(0(.1)1)`                  | `regsen_breakdown(..., cbar = seq(0, 1, 0.1))`                                             |
| `regsensitivity breakdown ... beta(-1(.2)1 lb)`              | `regsen_breakdown(..., beta = bnd_lb(seq(-1, 1, 0.2)))`                                    |
| `regsensitivity breakdown ... beta(4 ub)`                    | `regsen_breakdown(..., beta = bnd_ub(4))`                                                  |
| `regsensitivity breakdown ... oster rmax(0(.1)1) beta(0 eq)` | `regsen_breakdown(..., analysis = "oster", r2long = seq(0, 1, 0.1), beta = bnd_eq(0))`     |
| `regsensitivity plot`                                        | `plot(result)`                                                                             |
| `regsensitivity` (no subcommand)                             | `regsen_summary(...)`                                                                      |

## Citation

Inside R, every format is one call away:

``` r
citation("regsensitivity")                       # rendered text
print(citation("regsensitivity"), bibtex = TRUE) # with BibTeX
toBibtex(citation("regsensitivity"))             # BibTeX only
```

Copy-pasteable forms below.

### BibTeX

``` bibtex
@Manual{regsensitivity,
    title  = {regsensitivity: Regression Sensitivity Analysis for Omitted Variable Bias},
    author = {Mike Nguyen},
    year   = {2026},
    note   = {R package version 0.1.1},
    url    = {https://github.com/mikenguyen13/regsensitivity}
}
```

### RIS (Zotero, EndNote, Mendeley)

``` ris
TY  - COMP
TI  - regsensitivity: Regression Sensitivity Analysis for Omitted Variable Bias
AU  - Nguyen, Mike
PY  - 2026
PB  - GitHub
UR  - https://github.com/mikenguyen13/regsensitivity
ER  -
```

### APA 7

> Nguyen, M. (2026). *regsensitivity: Regression sensitivity analysis
> for omitted variable bias* (Version 0.1.1) \[R package\].
> <https://github.com/mikenguyen13/regsensitivity>

### MLA 9

> Nguyen, Mike. *regsensitivity: Regression Sensitivity Analysis for
> Omitted Variable Bias*. Version 0.1.1, 2026.
> <https://github.com/mikenguyen13/regsensitivity>.

### Chicago (author-date)

> Nguyen, Mike. 2026. “regsensitivity: Regression Sensitivity Analysis
> for Omitted Variable Bias.” R package version 0.1.1.
> <https://github.com/mikenguyen13/regsensitivity>.

### Machine-readable

-   [`CITATION.cff`](CITATION.cff) — used by GitHub’s “Cite this
    repository” widget
-   [`codemeta.json`](codemeta.json) — CodeMeta JSON-LD, consumed by
    Zenodo, r-universe, OpenAIRE
-   [`inst/CITATION`](inst/CITATION) — R-side `utils::citation()` source

Methodology citations (the underlying papers, which are **separate
works**) live below in [References](#references).

## References

-   Diegert, Masten, Poirier (2026). [Assessing Omitted Variable Bias
    when the Controls are Endogenous](https://arxiv.org/abs/2206.02303).
    arXiv:2206.02303.
-   Oster (2019). [Unobservable Selection and Coefficient
    Stability](https://www.tandfonline.com/doi/abs/10.1080/07350015.2016.1227711).
    *JBES* 37(2), 187–204.
-   Masten, Poirier (2026). [The Effect of Omitted Variables on the Sign
    of Regression Coefficients](https://arxiv.org/abs/2208.00552).
    arXiv:2208.00552.

## Code of conduct

Please note that the regsensitivity project is released with a
[Contributor Code of
Conduct](https://github.com/mikenguyen13/regsensitivity/blob/main/CODE_OF_CONDUCT.md).
By contributing to this project, you agree to abide by its terms.

## License

MIT. See `LICENSE.md`. The bundled `bfg2020` data set is a subset of
the replication data from Bazzi, Fiszbein and Gebresilasse (2020),
*Frontier Culture*, *Econometrica*.
