test_that("regsen_explore validates its inputs before launching", {
    # These must fail at the call site, not as a red banner in a browser.
    expect_error(regsen_explore("not a formula", bfg()), "must be a formula")
    expect_error(regsen_explore(bfg_formula(), "not data"), "must be a data frame")
})

test_that("an unfittable model reports at the call site", {
    d <- bfg()
    expect_error(
        regsen_explore(no_such_outcome ~ tye_tfe890_500kNI_100_l6, d),
        "could not be fitted"
    )
})

test_that("the app ships with the package", {
    # system.file() is empty during load_all(), so check the source tree
    # when the installed path is unavailable.
    p <- system.file("shiny", "explorer", "app.R", package = "regsensitivity")
    if (!nzchar(p)) p <- testthat::test_path("..", "..", "inst", "shiny",
                                             "explorer", "app.R")
    expect_true(file.exists(p))
    # It must parse, or the failure would only appear once a user launches.
    expect_no_error(parse(p))
})

test_that("the explorer environment is private to the package", {
    # Inputs live in a package-local environment, so two explorers cannot
    # overwrite each other and nothing is left in the user's workspace.
    e <- regsensitivity:::.regsen_explore_env
    expect_true(is.environment(e))
    expect_identical(parent.env(e), emptyenv())
    expect_false(exists("formula", envir = globalenv(), inherits = FALSE))
})
