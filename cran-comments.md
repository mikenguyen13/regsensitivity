# Submission notes

## Test environments

* local macOS 15 (Apple M4), R 4.5.2
* GitHub Actions:
  * macOS-latest (R-release)
  * windows-latest (R-release)
  * ubuntu-latest (R-devel, R-release, R-oldrel-1)
* win-builder (R-devel, R-release)

## R CMD check results

0 errors | 0 warnings | 2 notes

* "New submission" — expected; this is the first submission of the
  package to CRAN.

* "checking HTML version of manual" reports that the local `tidy` binary
  is too old to run HTML validation. This is a property of our machine,
  not of the package, and does not reproduce on the CRAN check farm.

All URLs in DESCRIPTION and the README resolve (HTTP 200), including the
pkgdown site at <https://mikenguyen13.github.io/regsensitivity/>.

The package is also checked on every push by GitHub Actions across
macOS-latest (R-release), windows-latest (R-release), and ubuntu-latest
on R-devel, R-release and R-oldrel-1; all five pass with 0 errors and
0 warnings.

## References

Implements the methodology of Diegert, Masten & Poirier
(arXiv:2206.02303), Oster (2019, JBES) and Masten & Poirier
(arXiv:2208.00552). The bundled `bfg2020` data set is a subset of the
replication data from Bazzi, Fiszbein & Gebresilasse (2020),
*Econometrica*.
