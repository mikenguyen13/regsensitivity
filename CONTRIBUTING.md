# Contributing to regsensitivity

Thanks for considering a contribution.

## Bug reports

Please open an issue on GitHub with a reproducible example
(`reprex::reprex()` is the easiest way) and the output of
[`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html).

## Pull requests

1.  Fork the repo and create a feature branch from `main`.
2.  Run `devtools::test()` to confirm existing tests pass.
3.  Add tests for new behaviour.
4.  Run `devtools::check()` and ensure 0 errors / 0 warnings.
5.  Open a PR against `main`.

## Code style

Roughly tidyverse style: 4-space indent, `<-` for assignment, snake_case
for functions and variables, `lintr` clean.

## Methodology questions

If you want to discuss the underlying methodology rather than the
implementation, please contact the authors of the original papers
(Diegert, Masten, Poirier; Oster) directly.
