# Build the bundled `bfg2020` data object from the source .dta file.
#
# Source: Bazzi, Fiszbein and Gebresilasse (2020),
#         "Frontier Culture: The Roots and Persistence of 'Rugged
#         Individualism' in the United States", Econometrica
#         (doi:10.3982/ECTA16484). The .dta in this directory is a
#         14-variable, 2036-row subset of their public replication data.
#
# Run interactively via `Rscript data-raw/bfg2020.R` to regenerate
# `data/bfg2020.rda`.

stopifnot(requireNamespace("haven", quietly = TRUE))

bfg2020 <- haven::read_dta("data-raw/bfg2020.dta")
bfg2020 <- as.data.frame(bfg2020)

usethis::use_data(bfg2020, overwrite = TRUE)
