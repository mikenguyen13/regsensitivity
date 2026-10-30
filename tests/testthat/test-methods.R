## The S3 surface: accessors, and print/summary/plot for every class.

small_formula <- function() {
    avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon
}
small_compare <- function() c("log_area_2010", "lat", "lon")

test_that("accessors return what the fields hold, without the internals", {
    b <- regsen_bounds(small_formula(), bfg(), compare = small_compare(),
                       cbar = 0.1)
    expect_equal(breakdown_point(b), abs(b$breakdown))
    expect_equal(breakdown_point(b, signed = TRUE), b$breakdown)
    expect_equal(identified_set(b), as.data.frame(b))
    expect_named(coef(b), c("short", "medium"))
    expect_equal(coef(b)[["medium"]], b$dgp$beta_med)
    expect_equal(nobs(b), b$n)
    sp <- sensitivity_params(b)
    expect_false(any(c("scalar", "nonscalar") %in% names(sp)))
    expect_equal(sp$cbar, 0.1)
    expect_error(breakdown_frontier(b), "not a breakdown frontier")

    bk <- regsen_breakdown(small_formula(), bfg(), compare = small_compare(),
                           cbar = c(0, 0.5, 1))
    fr <- breakdown_frontier(bk)
    expect_named(fr, c("cbar", "breakdown"))
    expect_equal(fr$cbar, c(0, 0.5, 1))
    expect_equal(breakdown_point(bk), abs(bk$results$breakdown))
    expect_error(identified_set(bk), "breakdown frontier")
})

test_that("a signed Oster breakdown keeps its sign only when asked", {
    o <- regsen_breakdown(small_formula(), bfg(), analysis = "oster",
                          r2long = 1, beta = bnd_eq(0))
    expect_equal(breakdown_point(o, signed = TRUE), o$results$breakdown)
    expect_true(all(breakdown_point(o) >= 0))
})

test_that("summary() is distinct from print() and carries more detail", {
    b <- regsen_bounds(small_formula(), bfg(), compare = small_compare(),
                       cbar = 0.1)
    s <- summary(b)
    expect_s3_class(s, "summary.regsensitivity")
    p_out <- capture.output(print(b))
    s_out <- capture.output(print(s))
    expect_false(identical(p_out, s_out))
    expect_true(length(s_out) > length(p_out))
    expect_true(any(grepl("Call:", s_out)))
    expect_true(any(grepl("Comparison set", s_out)))
    expect_true(any(grepl("Summary statistics", s_out)))
    expect_false(any(grepl("Summary statistics", p_out)))

    # holds: the identified set lies wholly above the hypothesised 0.
    expect_equal(s$results$holds, b$results$bmin > 0)
})

test_that("print() thins a long table and summary() shows all of it", {
    b <- regsen_bounds(small_formula(), bfg(), compare = small_compare(),
                       cbar = 0.1, rxbar = seq(0, 2, length.out = 40))
    expect_output(print(b), "of 40 rows")
    s_out <- capture.output(print(summary(b)))
    expect_false(any(grepl("of 40 rows", s_out)))
})

test_that("summary of a frontier names the swept parameter", {
    bk <- regsen_breakdown(small_formula(), bfg(), compare = small_compare(),
                           cbar = c(0, 1))
    s <- summary(bk)
    expect_true("cbar" %in% names(s$results))
    expect_output(print(s), "Breakdown range")
})

test_that("regsensitivity_summary has print, summary and plot", {
    rs <- regsen_summary(small_formula(), bfg(), compare = small_compare())
    s <- summary(rs)
    expect_s3_class(s, "summary.regsensitivity_summary")
    expect_s3_class(s$dmp_bounds, "summary.regsensitivity")
    expect_output(print(s), "Oster")
    p <- plot(rs)
    expect_s3_class(p, "regsensitivity_plots")
    expect_s3_class(p$dmp_bounds, "ggplot")
    expect_s3_class(plot(rs, which = "oster"), "ggplot")
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off())
    expect_silent(print(p))
})

test_that("regsensitivity_multi has summary and an accessor", {
    m <- regsen_multi(small_formula(), bfg(),
                      treatments = c("tye_tfe890_500kNI_100_l6", "lat"),
                      compare = small_compare(), cbar = 1)
    bp <- breakdown_point(m)
    expect_named(bp, c("tye_tfe890_500kNI_100_l6", "lat"))
    s <- summary(m)
    expect_s3_class(s, "summary.regsensitivity_multi")
    expect_equal(s$table$breakdown, sort(m$breakdown))
    expect_equal(s$analysis, "DMP (2026)")
    expect_output(print(s), "Most fragile first")
})

test_that("regsensitivity_boot has summary, plot and confint", {
    bb <- regsen_boot(small_formula(), bfg(), compare = small_compare(),
                      R = 40, seed = 1, show_progress = FALSE)
    expect_equal(breakdown_point(bb), abs(bb$point))
    s <- summary(bb)
    expect_s3_class(s, "summary.regsensitivity_boot")
    expect_equal(s$se, stats::sd(abs(bb$replicates[is.finite(bb$replicates)])))
    p_out <- capture.output(print(bb))
    s_out <- capture.output(print(s))
    expect_true(length(s_out) > length(p_out))
    expect_true(any(grepl("Bootstrap SE", s_out)))

    ci <- confint(bb)
    expect_equal(dim(ci), c(1L, 2L))
    expect_equal(as.numeric(ci), regsensitivity:::abs_interval(bb$ci_bca))
    # A new level is recomputed from the stored replicates and jackknife.
    ci90 <- confint(bb, level = 0.9)
    expect_true(ci90[1] >= ci[1] && ci90[2] <= ci[2])
    expect_equal(colnames(confint(bb, level = 0.9, type = "perc")),
                 c("5 %", "95 %"))
    expect_s3_class(plot(bb), "ggplot")

    bp <- regsen_boot(small_formula(), bfg(), compare = small_compare(),
                      R = 20, seed = 1, type = "perc", show_progress = FALSE)
    expect_error(confint(bp, type = "bca"), "jackknife")
})

test_that("the whitened quadratic forms match the explicit inverse", {
    set.seed(3)
    V <- crossprod(matrix(rnorm(40), 10, 4))
    u <- rnorm(4); v <- rnorm(4)
    w <- regsensitivity:::whitener(V)
    expect_equal(sum(w(u) * w(v)), as.numeric(t(u) %*% solve(V) %*% v))

    # Singular: the fallback is the Moore-Penrose pseudo-inverse.
    A <- matrix(rnorm(8), 4, 2)
    S <- tcrossprod(A)
    u <- as.numeric(A %*% rnorm(2)); v <- as.numeric(A %*% rnorm(2))
    w <- regsensitivity:::whitener(S)
    e <- eigen(S, symmetric = TRUE)
    pinv <- e$vectors[, 1:2] %*% diag(1 / e$values[1:2]) %*% t(e$vectors[, 1:2])
    expect_equal(sum(w(u) * w(v)), as.numeric(t(u) %*% pinv %*% v))
})
