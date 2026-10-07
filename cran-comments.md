# Submission notes

## Resubmission

This is a resubmission addressing the points raised by Konstanze Lauseker
on 7 October. Each is taken in turn.

**Single quotes around names.** The author names in the Description field
are no longer quoted. The quotes are gone and nothing else in the field
changed.

**`\dontrun{}`, and unwrapping examples that run in under 5 seconds.**
Every example in the package now runs. The `\dontrun{}` block, which
held three calls to `regsen_cores()`, is gone: the two that belong in a
check are unwrapped and restore the option they set, and the third is
described in prose instead, for the reason under cores below. Twelve
`\donttest{}` wrappers are also unwrapped, having been timed at between
0.01 and 0.42 seconds each. One `\donttest{}` remains, on
`regsen_boot()`, whose example takes 4.5 seconds here and would be at
risk of passing 5 on a slower machine. `regsen_explore()` starts a Shiny
app, so its example is wrapped in `if (interactive())`.

**More than 2 cores.** `regsen_cores("auto")` asks for every core but
two, so it no longer appears in any example or vignette chunk. What it
does is described in the text of both. Nothing in the examples, vignettes
or tests now requests more than two cores, and the package caps itself at
two whenever `_R_CHECK_LIMIT_CORES_` is set, whatever the user has asked
for.

**Writing to the user's filespace: `inst/replication/dmp2022.R`.** The
script wrote four files to the working directory. It now writes them to
`tempdir()` and prints the path, and takes an optional command-line
argument for a directory, so it writes to the user's own files only when
the user names where.

**Resetting `options()`: `inst/doc`.** Two vignettes set
`options(width = )` in their setup chunk and did not put it back. Each
now saves the old value and restores it in a final chunk.

**Setting a seed within a function.** `regsen_boot()` takes a `seed`
argument defaulting to `NULL`, and now saves the session's random state
on entry and restores it on exit, so a bootstrap run inside a larger
simulation no longer redirects that simulation's draws. Where a `seed`
is given the call is transparent; where it is not, the stream is left
advanced by the one draw that generates the replicate seeds and nothing
more. The remaining `set.seed()` inside the function seeds each
bootstrap replicate from that drawn vector, which is what makes results
identical whatever the core count, and it is covered by the same restore.
Two helper functions outside the package code, one in a vignette and one
in `inst/casestudies/`, also set a seed internally; both now take it from
the caller instead.

Four tests cover the new behaviour, and they run everywhere rather than
under `skip_on_cran()`.

While making these changes the package was re-read against the CRAN
Cookbook as a whole. Nothing else was found: no writes outside
`tempdir()`, no `setwd()`, no `par()` left unrestored, no `T`/`F`, no
assignment to the global environment beyond the `.Random.seed` restore
described above, and no `installed.packages()`.

## Test environments

* local macOS 26.6.2 (Apple M4), R 4.5.2
* win-builder, R-devel (2026-09-21 r90579 ucrt): 1 NOTE, "New submission"
* win-builder, R 4.6.1 (2026-06-24 ucrt): 1 NOTE, "New submission"

This exact tarball was checked on both win-builder flavours before
resubmitting. Neither reports the file-URI problem, nor anything else.

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
