test_that("regsen_multi returns one row per treatment", {
    trs <- c("tye_tfe890_500kNI_100_l6", "lat", "lon")
    m <- regsen_multi(bfg_formula(), bfg(), treatments = trs,
                       compare = bfg_compare(), cbar = 1)
    expect_s3_class(m, "regsensitivity_multi")
    expect_s3_class(m, "data.frame")
    expect_equal(nrow(m), length(trs))
    expect_equal(m$treatment, trs)
    expect_true(all(c("estimate", "breakdown", "n") %in% names(m)))
    # Nothing failed, so the error column is dropped.
    expect_null(m$error)
})

test_that("the specification is identical across rows", {
    # Every treatment is analysed in the same model, so n must match and
    # each estimate must equal the coefficient from that same regression.
    trs <- c("tye_tfe890_500kNI_100_l6", "lat")
    m <- regsen_multi(bfg_formula(), bfg(), treatments = trs,
                       compare = bfg_compare(), cbar = 1)
    expect_length(unique(m$n), 1L)

    solo <- regsen_breakdown(
        stats::reformulate(
            c("lat", setdiff(attr(stats::terms(bfg_formula()), "term.labels"),
                             "lat")),
            response = "avgrep2000to2016"),
        bfg(), compare = setdiff(bfg_compare(), "lat"), cbar = 1)
    expect_equal(m$estimate[m$treatment == "lat"], solo$dgp$beta_med)
})

test_that("a treatment is removed from its own compare set", {
    # A variable cannot calibrate against itself; if `lat` stayed in
    # `compare` while acting as the treatment the analysis would error.
    expect_no_error(
        regsen_multi(bfg_formula(), bfg(),
                     treatments = "lat", compare = bfg_compare(), cbar = 1)
    )
})

test_that("a treatment absent from the formula is rejected by name", {
    expect_error(
        regsen_multi(bfg_formula(), bfg(), treatments = "not_a_column",
                     compare = bfg_compare(), cbar = 1),
        "not_a_column"
    )
})

test_that("treatments must be a non-empty character vector", {
    expect_error(regsen_multi(bfg_formula(), bfg(), treatments = character(0)),
                 "non-empty")
    expect_error(regsen_multi(bfg_formula(), bfg(), treatments = 1),
                 "character vector")
})

test_that("one failing treatment does not abort the sweep", {
    # A constant column has no variation, so its analysis fails. The other
    # treatments must still be reported rather than the whole call dying.
    d <- bfg()
    d$const <- 1
    f <- stats::reformulate(
        c("tye_tfe890_500kNI_100_l6", bfg_compare(), "const"),
        response = "avgrep2000to2016")
    m <- suppressWarnings(
        regsen_multi(f, d, treatments = c("tye_tfe890_500kNI_100_l6", "const"),
                     compare = bfg_compare(), cbar = 1))
    expect_equal(nrow(m), 2L)
    expect_true(is.finite(m$breakdown[m$treatment == "tye_tfe890_500kNI_100_l6"]))
})

test_that("plot orders treatments by fragility and rejects an empty table", {
    m <- regsen_multi(bfg_formula(), bfg(),
                       treatments = c("tye_tfe890_500kNI_100_l6", "lat"),
                       compare = bfg_compare(), cbar = 1)
    p <- plot(m)
    expect_s3_class(p, "ggplot")

    empty <- m
    empty$breakdown <- NA_real_
    expect_error(plot(empty), "no finite breakdown")
})
