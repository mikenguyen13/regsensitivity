# Submission notes

## Update

This update fixes the ERROR that 0.3.0, published on 3 November, shows
on r-release-macos-x86_64 and r-oldrel-macos-x86_64.

The failing test checks a consistency property of the rybar breakdown
frontier: at a frontier point, the lower bound of the identified set
should sit at the hypothesis, 0. Both quantities come from numerical
solves. The frontier is a root found to 1e-4 in rybar, the bound changes
by about 6 per unit of rybar there, and each global optimization is
accurate to about 3e-4, so the two can differ by roughly 1e-3. The test
allowed exactly 1e-3. On the Intel macOS machines the gap came to
0.0010, just outside; elsewhere it is below 1e-5. The test now allows
5e-3. A second test that compared a result of the same global search
at 1e-6 now compares at 1e-3.

The update also adds input checks: a treatment or outcome with no
variation once the controls are partialled out, a formula without a
single numeric outcome, infinite values, a
`subset` that does not fit the data, and a cluster bootstrap with a
single cluster or missing cluster ids are now errors with a plain
message. None of this changes any result on valid data.

This update comes two weeks after 0.3.0. Its purpose is to clear a
check failure on CRAN's own machines.

## Reverse dependencies

There are none.

## Test environments

* local macOS 26.6.2 (Apple M4), R 4.5.2
* win-builder, R-devel and R-release
* GitHub Actions: macOS 15 Intel (x86_64), alongside the platforms below
* Intel MKL and ATLAS BLAS (R-hub containers on GitHub Actions)

The package is also checked by GitHub Actions on macOS-latest
(R-release), windows-latest (R-release), and ubuntu-latest under
R-devel, R-release and R-oldrel-1.

## R CMD check results

`R CMD check --as-cran` on the built tarball:

0 errors | 0 warnings | 1 note

* "checking HTML version of manual: Skipping checking HTML validation:
  'tidy' doesn't look like recent enough HTML Tidy." The `tidy` shipped
  with macOS is too old to run the validation. The PDF manual builds
  without a warning.

## Check time

The test suite marks its slowest cases, the bootstrap tests and the
Oster cases that need a global optimization over a nonconvex constraint
set, with `skip_on_cran()`. The full suite runs on every push under
GitHub Actions.
