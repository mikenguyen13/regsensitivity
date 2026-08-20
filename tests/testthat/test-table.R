test_that("as.data.frame returns the results as a plain data frame", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = c(0.1, 0.5))
    df <- as.data.frame(res)
    expect_s3_class(df, "data.frame")
    expect_true(nrow(df) > 0)
    expect_true(all(c("bmin", "bmax") %in% names(df)))
    # Full precision by default, so the frame can feed further computation.
    expect_type(df$bmin, "double")
    expect_null(attr(df, "row.names.orig"))
})

test_that("as.data.frame(digits=) rounds and finite_only drops unbounded rows", {
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = c(0.1, 0.5, 1))
    rounded <- as.data.frame(res, digits = 3)
    expect_equal(rounded$bmin, signif(as.data.frame(res)$bmin, 3))

    full <- as.data.frame(res)
    finite <- as.data.frame(res, finite_only = TRUE)
    expect_lte(nrow(finite), nrow(full))
})

test_that("regsen_table emits markdown with right-aligned numeric columns", {
    skip_if_not_installed("knitr")
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = 0.1)
    tab <- regsen_table(res, format = "markdown", digits = 3)
    txt <- paste(as.character(tab), collapse = "\n")
    expect_s3_class(tab, "knitr_kable")
    # Numeric columns must not be left-aligned -- ":---" would mean they were
    # formatted to character before the alignment was computed.
    expect_false(grepl("|:---", txt, fixed = TRUE))
    expect_true(grepl("---:", txt, fixed = TRUE))
})

test_that("LaTeX output keeps its backslashes and wires up notes and label", {
    skip_if_not_installed("knitr")
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = c(0.1, 0.5))
    txt <- paste(as.character(regsen_table(
        res, format = "latex", notes = TRUE, escape = FALSE,
        caption = "Identified sets", label = "idset")), collapse = "\n")

    # Regex replacement silently eats backslashes; these guard that.
    expect_true(grepl("\\begin{threeparttable}", txt, fixed = TRUE))
    expect_true(grepl("\\begin{tablenotes}", txt, fixed = TRUE))
    expect_true(grepl("\\item ", txt, fixed = TRUE))
    expect_true(grepl("\\label{tab:idset}", txt, fixed = TRUE))
    expect_true(grepl("\\toprule", txt, fixed = TRUE))
    expect_false(grepl("\nitem ", txt, fixed = TRUE))
    expect_false(grepl("\nbegin{tablenotes}", txt, fixed = TRUE))
})

test_that("threeparttable can be switched off", {
    skip_if_not_installed("knitr")
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = 0.1)
    txt <- paste(as.character(regsen_table(res, format = "latex", notes = "A note.",
                                      threeparttable = FALSE, escape = FALSE)), collapse = "\n")
    expect_false(grepl("threeparttable", txt, fixed = TRUE))
    expect_true(grepl("A note.", txt, fixed = TRUE))
})

test_that("HTML infinity is a character, not a double-escaped entity", {
    skip_if_not_installed("knitr")
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = c(0.5, 1))
    txt <- paste(as.character(regsen_table(res, format = "html", digits = 3)), collapse = "\n")
    # kable's escape=TRUE would turn "&infin;" into "&amp;infin;".
    expect_false(grepl("&amp;", txt, fixed = TRUE))
})

test_that("max_rows thins the sweep and records that it did", {
    skip_if_not_installed("knitr")
    res <- regsen_bounds(bfg_formula(), bfg(),
                          compare = bfg_compare(), cbar = seq(0.1, 1, 0.1))
    txt <- paste(as.character(regsen_table(res, format = "markdown", max_rows = 3,
                                      notes = TRUE)), collapse = "\n")
    expect_true(grepl("thinned", txt, fixed = TRUE))
})

test_that("regsen_table rejects non-regsensitivity input", {
    skip_if_not_installed("knitr")
    expect_error(regsen_table(mtcars), "regsensitivity object")
})

test_that("breakdown results tabulate too", {
    skip_if_not_installed("knitr")
    bd <- regsen_breakdown(bfg_formula(), bfg(),
                            compare = bfg_compare(), cbar = seq(0, 1, 0.5))
    txt <- paste(as.character(regsen_table(bd, format = "markdown", digits = 3)), collapse = "\n")
    expect_true(grepl("Breakdown", txt, fixed = TRUE))
})
