# Submission notes

## Test environments

* local macOS 26.5.1 (Apple M4), R 4.5.2

Before submitting, this package is also checked on win-builder (R-devel
and R-release) and by GitHub Actions on macOS-latest (R-release),
windows-latest (R-release), and ubuntu-latest under R-devel, R-release
and R-oldrel-1.

## R CMD check results

`R CMD check --as-cran --no-manual` on the built tarball:

0 errors | 0 warnings | 2 notes

* "New submission" — this is the first submission of the package to CRAN.

* "checking top-level files: Files 'README.md' or 'NEWS.md' cannot be
  checked without 'pandoc' being installed." There is no `pandoc` on this
  machine's PATH, so that validation could not run here. It is a property
  of the machine, not of the package, and does not reproduce where pandoc
  is present.

`--no-manual` was passed because the local `tidy` binary is too old to
perform HTML validation, so the "checking HTML version of manual" step
did not run here either.

All URLs in DESCRIPTION and the README resolve (HTTP 200), including the
pkgdown site at <https://mikenguyen13.github.io/regsensitivity/>.

## Check time

The full check takes about 7.5 minutes of wall-clock time and 4 minutes
of CPU on the machine above, of which re-building the vignettes accounts
for roughly 3.5 minutes and the test suite for 2.

The test suite marks its slowest cases -- the bootstrap tests, and the
Oster cases that require a global optimization over a nonconvex
constraint set -- with `skip_on_cran()`, so the figure above is what a
CRAN machine runs, not what a developer running the suite in full would
see. The full suite, `skip_on_cran()` cases included, runs on every push
under GitHub Actions.

## References

Implements the methodology of Diegert, Masten & Poirier
(arXiv:2206.02303), Oster (2019, JBES) and Masten & Poirier
(arXiv:2208.00552). The bundled `bfg2020` data set is a subset of the
replication data from Bazzi, Fiszbein & Gebresilasse (2020),
*Econometrica*.
