# Submission notes

## Resubmission

This is a resubmission. The previous submission was returned with:

```
Found the following (possibly) invalid file URIs:
  URI: CODE_OF_CONDUCT.md
    From: README.md
  URI: CITATION.cff
    From: README.md
  URI: codemeta.json
    From: README.md
```

Those three files are excluded from the build by `.Rbuildignore`, so the
relative links to them in `README.md` pointed at paths that do not exist
in the tarball. All three now link to the files on GitHub with absolute
`https://` URLs.

While going back over the package against the CRAN Cookbook, four
further things were corrected in the same revision:

* `\value` was missing from `hypothesis_helpers.Rd`, which documents the
  exported `bnd_lb()`, `bnd_ub()` and `bnd_eq()`. It now says what those
  return and what the `"sign"` attribute is for.

* `regsensitivity()`, `regsen_summary()`, `calibrate_partial_r2()` and
  `scale_colour_regsen()` are exported but had no examples, and neither
  did the `bfg2020` data set. Each now has a small executable one.

* `regsen_cores()` had its examples in `\dontrun{}` although they run
  instantly. They are unwrapped, and the session option they set is
  restored afterwards. The one case that is genuinely not for a check
  machine, `regsen_cores("auto")`, stays in `\dontrun{}`.
  `regsen_explore()` starts a Shiny app, so its example moved from
  `\dontrun{}` to `if (interactive())`.

No code changed; the revision is documentation only.

## Test environments

* local macOS 26.6.2 (Apple M4), R 4.5.2

The package is also checked by GitHub Actions on macOS-latest
(R-release), windows-latest (R-release), and ubuntu-latest under R-devel,
R-release and R-oldrel-1.

## R CMD check results

`R CMD check --as-cran` on the built tarball:

0 errors | 0 warnings | 2 notes

* "New submission" — this is the first submission of the package to CRAN.

* "checking HTML version of manual: Skipping checking HTML validation:
  'tidy' doesn't look like recent enough HTML Tidy." The `tidy` binary
  shipped with this machine's macOS is too old to perform the
  validation, so that step could not run here. It is a property of the
  machine, not of the package. The PDF version of the manual builds
  without a warning.

All URLs in DESCRIPTION and the README resolve (HTTP 200), including the
pkgdown site at <https://mikenguyen13.github.io/regsensitivity/>.

## Check time

The full check takes about 6.5 minutes of wall-clock time and 4 minutes
of CPU on the machine above, of which re-building the vignettes accounts
for roughly 3.5 minutes and the test suite for 1.

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
