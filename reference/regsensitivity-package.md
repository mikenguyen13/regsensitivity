# regsensitivity: regression sensitivity analysis

Implements the identified-set and breakdown-point sensitivity analyses
of Diegert, Masten and Poirier (2026), Oster (2019), and Masten and
Poirier (2026) for the coefficient of interest in a linear regression
with omitted variables.

## Core functions

- [`regsen_bounds()`](regsen_bounds.md) – identified set across
  sensitivity parameters

- [`regsen_breakdown()`](regsen_breakdown.md) – smallest sensitivity
  value at which a hypothesis fails

- [`regsen_summary()`](regsen_summary.md) – default summary sweep (DMP +
  Oster)

- [`plot.regsensitivity()`](plot.regsensitivity.md) – ggplot2
  visualization

## Reference data

- [bfg2020](bfg2020.md) – subset of the Bazzi, Fiszbein &
  Gebresilasse (2020) replication data, used to demonstrate the package.

## See also

Useful links:

- <https://github.com/mikenguyen13/regsensitivity>

- <https://mikenguyen13.github.io/regsensitivity/>

- Report bugs at <https://github.com/mikenguyen13/regsensitivity/issues>

## Author

**Maintainer**: Mike Nguyen <nguyennghia1301@gmail.com> \[copyright
holder\]
