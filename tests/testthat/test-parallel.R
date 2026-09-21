## Parallel execution: the results must not depend on how many cores did
## the work, and the session default must be what regsen_cores() says.

# The frontier and identified-set cases below take a few seconds each
# serially; two cores is what R CMD check allows, and enough to prove the
# point.
two <- 2L

test_that("regsen_cores() reads, sets and validates the session default", {
    old <- getOption("regsensitivity.ncores")
    on.exit(options(regsensitivity.ncores = old), add = TRUE)
    options(regsensitivity.ncores = NULL)
    expect_equal(regsen_cores(), 1L)
    expect_equal(regsen_cores(2), 2L)
    expect_equal(regsen_cores(), 2L)
    expect_equal(getOption("regsensitivity.ncores"), 2L)
    auto <- regsen_cores("auto")
    expect_true(auto >= 1L)
    expect_true(auto <= max(1L, parallel::detectCores() - 2L))
    for (bad in list(0, -1, "four", c(2, 3), NA, 1.5 - 1.5)) {
        expect_error(regsen_cores(bad), "ncores")
    }
    # A bad value leaves the setting untouched.
    regsen_cores(1)
    expect_error(regsen_cores("many"))
    expect_equal(regsen_cores(), 1L)
})

test_that("the cap under R CMD check --as-cran is honoured", {
    old <- Sys.getenv("_R_CHECK_LIMIT_CORES_", unset = NA)
    on.exit(if (is.na(old)) Sys.unsetenv("_R_CHECK_LIMIT_CORES_")
            else Sys.setenv("_R_CHECK_LIMIT_CORES_" = old), add = TRUE)
    Sys.setenv("_R_CHECK_LIMIT_CORES_" = "TRUE")
    expect_equal(regsensitivity:::resolve_ncores(8), 2L)
    expect_equal(regsensitivity:::resolve_ncores(1), 1L)
    Sys.setenv("_R_CHECK_LIMIT_CORES_" = "false")
    expect_equal(regsensitivity:::resolve_ncores(3), 3L)
})

test_that("a failing job stays confined to its own index", {
    fn <- function(i) if (i == 2) stop("boom") else i * 10
    for (nc in c(1L, two)) {
        out <- regsensitivity:::par_lapply(4, fn, nc)
        expect_equal(out[[1]], 10)
        expect_true(inherits(out[[2]], "try-error"))
        expect_equal(out[[3]], 30)     # same core as 2 under prescheduling
        expect_equal(out[[4]], 40)
        expect_equal(regsensitivity:::par_numeric(4, fn, nc), c(10, NA, 30, 40))
        expect_error(regsensitivity:::par_numeric_strict(4, fn, nc), "boom")
    }
})

test_that("finite-rybar identified sets are identical across cores", {
    skip_on_cran()
    a <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                       rxbar = c(0.3, 0.6, 0.9), rybar = c(0.5, 1), cbar = 1,
                       ncores = 1)
    b <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                       rxbar = c(0.3, 0.6, 0.9), rybar = c(0.5, 1), cbar = 1,
                       ncores = two)
    expect_identical(a$results, b$results)
    expect_identical(a$breakdown, b$breakdown)
})

test_that("closed-form sets take the serial path and match", {
    a <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                       cbar = c(0.1, 0.5, 1))
    b <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                       cbar = c(0.1, 0.5, 1), ncores = two)
    expect_identical(a$results, b$results)
})

test_that("breakdown frontiers are identical across cores", {
    skip_on_cran()
    args <- list(bfg_formula(), bfg(), compare = bfg_compare())
    ry1 <- do.call(regsen_breakdown, c(args, list(cbar = 1, direction = "rybar",
                                                  rxbar = c(0.5, 1, 2), ncores = 1)))
    ry2 <- do.call(regsen_breakdown, c(args, list(cbar = 1, direction = "rybar",
                                                  rxbar = c(0.5, 1, 2), ncores = two)))
    expect_identical(ry1$results, ry2$results)
    rx1 <- do.call(regsen_breakdown, c(args, list(cbar = c(0.5, 1), rybar = 1,
                                                  ncores = 1)))
    rx2 <- do.call(regsen_breakdown, c(args, list(cbar = c(0.5, 1), rybar = 1,
                                                  ncores = two)))
    expect_identical(rx1$results, rx2$results)
    ce1 <- do.call(regsen_breakdown, c(args, list(cbar = c(0.5, 1),
                                                  rybar_expr = function(r) r,
                                                  ncores = 1)))
    ce2 <- do.call(regsen_breakdown, c(args, list(cbar = c(0.5, 1),
                                                  rybar_expr = function(r) r,
                                                  ncores = two)))
    expect_identical(ce1$results, ce2$results)
})

test_that("regsen_multi() is identical across cores and reports failures per row", {
    trs <- c("tye_tfe890_500kNI_100_l6", "lat", "lon")
    a <- regsen_multi(bfg_formula(), bfg(), treatments = trs,
                      compare = bfg_compare(), cbar = 1, ncores = 1)
    b <- regsen_multi(bfg_formula(), bfg(), treatments = trs,
                      compare = bfg_compare(), cbar = 1, ncores = two)
    expect_identical(as.data.frame(a), as.data.frame(b))
    # A fun that errors on one treatment: the others still come back.
    boom <- function(formula, data, compare = NULL, ...) {
        if (all.vars(formula)[2] == "lat") stop("no lat")
        regsen_breakdown(formula, data, compare = compare, ...)
    }
    m <- regsen_multi(bfg_formula(), bfg(), treatments = trs,
                      compare = bfg_compare(), fun = boom, cbar = 1,
                      ncores = two)
    expect_equal(m$error[m$treatment == "lat"], "no lat")
    expect_true(all(is.finite(m$breakdown[m$treatment != "lat"])))
})

test_that("the socket backend gives what the fork backend gives", {
    # The socket path is what Windows users get, and the one a fork-capable
    # machine would otherwise never exercise. A socket worker is a fresh
    # session: an argument left as an unevaluated promise reaches it as a
    # promise into a frame that does not exist there, which is exactly the
    # bug this guards against. It needs the installed package, since the
    # worker loads the namespace by name.
    skip_if(exists(".__DEVTOOLS__", asNamespace("regsensitivity")),
            "package is loaded with load_all(); the socket worker needs it installed")
    old <- getOption("regsensitivity.backend")
    on.exit(options(regsensitivity.backend = old), add = TRUE)
    options(regsensitivity.backend = "psock")
    expect_equal(regsensitivity:::parallel_backend(), "psock")

    fn <- function(i) if (i == 2) stop("boom") else i * 10
    expect_equal(regsensitivity:::par_numeric(4, fn, two), c(10, NA, 30, 40))

    # A closure argument evaluated only inside the worker.
    helper <- function() bfg_compare()
    trs <- c("tye_tfe890_500kNI_100_l6", "lat")
    m2 <- regsen_multi(bfg_formula(), bfg(), treatments = trs,
                       compare = helper(), cbar = 1, ncores = two)
    m1 <- regsen_multi(bfg_formula(), bfg(), treatments = trs,
                       compare = bfg_compare(), cbar = 1, ncores = 1)
    expect_identical(as.data.frame(m2), as.data.frame(m1))

    bb <- regsen_boot(bfg_formula(), bfg(), compare = helper(), cbar = 1,
                      R = 4, seed = 1, type = "perc", show_progress = FALSE,
                      ncores = two)
    bb1 <- regsen_boot(bfg_formula(), bfg(), compare = bfg_compare(), cbar = 1,
                       R = 4, seed = 1, type = "perc", show_progress = FALSE,
                       ncores = 1)
    expect_identical(bb$replicates, bb1$replicates)
    expect_equal(bb$na, 0L)

    b2 <- regsen_bounds(bfg_formula(), bfg(), compare = helper(),
                        rxbar = c(0.3, 0.6), rybar = 1, cbar = 1, ncores = two)
    b1 <- regsen_bounds(bfg_formula(), bfg(), compare = bfg_compare(),
                        rxbar = c(0.3, 0.6), rybar = 1, cbar = 1, ncores = 1)
    expect_identical(b2$results, b1$results)
})

test_that("the session default reaches every entry point", {
    old <- getOption("regsensitivity.ncores")
    on.exit(options(regsensitivity.ncores = old), add = TRUE)
    regsen_cores(two)
    bb <- regsen_boot(bfg_formula(), bfg(), compare = bfg_compare(), cbar = 1,
                      R = 4, seed = 1, type = "perc", show_progress = FALSE)
    expect_equal(bb$ncores, two)
    regsen_cores(1)
    bb1 <- regsen_boot(bfg_formula(), bfg(), compare = bfg_compare(), cbar = 1,
                       R = 4, seed = 1, type = "perc", show_progress = FALSE)
    expect_equal(bb1$ncores, 1L)
    expect_identical(bb$replicates, bb1$replicates)
})
