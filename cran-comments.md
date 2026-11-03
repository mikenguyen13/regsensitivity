# Submission notes

## Resubmission

This replaces the 0.3.0 submission of 2 November, whose auto-check
reported an additional issue for 0.2.0 under MKL. Three tests in
`test-parallel.R` compared results computed on one core and on two, or
under the fork and the socket backend, with `expect_identical()`. MKL
moves the last digit or two between those runs (about 1e-15), so the
tests failed although the results agree to every digit the package
reports. The submission that was pending had the same tests. They now
compare with `expect_equal(tolerance = 1e-10)`. No package code changed.

## Update

This is an update of regsensitivity 0.2.0, published on 20 October. It
adds methods and accessors and changes no results:

* accessor functions `breakdown_point()`, `breakdown_frontier()`,
  `identified_set()` and `sensitivity_params()`, with `coef()` and
  `nobs()` methods;
* `summary()` methods that differ from `print()` for every result class,
  and `print()`, `summary()`, `plot()` and `confint()` for the bootstrap,
  multi-treatment and side-by-side summary results that lacked them;
* `regsensitivity()` now takes the formula first. The previous argument
  order still runs, with a deprecation warning;
* the quadratic forms in Var(W1) are computed by a triangular solve on
  the Cholesky factor rather than an explicit inverse.

The numeric snapshot tests are unchanged and pass.

I am sorry to send an update so soon after the first release. These
changes answer a design review of the package's interface, and an
article about the package under review needs the published version to
contain the functions it uses.

## Reverse dependencies

There are none.

## Test environments

* local macOS 26.6.2 (Apple M4), R 4.5.2

The package is also checked by GitHub Actions on macOS-latest
(R-release), windows-latest (R-release), and ubuntu-latest under R-devel,
R-release and R-oldrel-1.

## R CMD check results

`R CMD check --as-cran` on the built tarball:

0 errors | 0 warnings | 1 note

* "checking HTML version of manual: Skipping checking HTML validation:
  'tidy' doesn't look like recent enough HTML Tidy." The `tidy` shipped
  with macOS is too old to run the validation. The PDF manual builds
  without a warning.

The CRAN incoming feasibility check, run with remote checks on, passes.

## Check time

The test suite marks its slowest cases, the bootstrap tests and the
Oster cases that need a global optimization over a nonconvex constraint
set, with `skip_on_cran()`. The full suite runs on every push under
GitHub Actions.
