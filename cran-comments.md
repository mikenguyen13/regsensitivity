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

Both notes are from the local run and we believe both are benign:

* "Found the following (possibly) invalid URLs" flags the pkgdown site
  <https://mikenguyen13.github.io/regsensitivity/> listed in DESCRIPTION.
  The site is published by the `pkgdown` GitHub Actions workflow on push
  to `main`, so the URL resolves once this version is tagged. Please let
  us know if you would prefer the URL removed until then.

* "checking HTML version of manual" reports that the local `tidy` binary
  is too old to run HTML validation. This is a property of our machine,
  not of the package, and does not reproduce on the CRAN check farm.

This is a new submission, so the "New submission" note is expected.

## References

Implements the methodology of Diegert, Masten & Poirier
(arXiv:2206.02303), Oster (2019, JBES) and Masten & Poirier
(arXiv:2208.00552). The bundled `bfg2020` data set is a subset of the
replication data from Bazzi, Fiszbein & Gebresilasse (2020),
*Econometrica*.
