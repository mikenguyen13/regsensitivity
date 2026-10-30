## bootstrap.R --- inference for the breakdown point via percentile, BCa,
## or cluster bootstrap.
##
## The breakdown point is a function of the data (it depends on Var(Y, X, W1)
## after partialling out W0). Standard delta-method inference is awkward
## because the mapping involves a global optimization step in the DMP regime
## with non-smooth optimum. A non-parametric bootstrap is therefore the
## natural inferential device. This module implements both:
##
##   - the standard non-parametric bootstrap (rows i.i.d.)
##   - the cluster bootstrap (rows resampled at the cluster level), to match
##     the clustering structure used in many applied papers (e.g. the
##     km_grid_cel_code clusters in BFG 2020)
##
## and two interval types on top of either: the percentile interval, and the
## bias-corrected and accelerated (BCa) interval of Efron (1987). The
## breakdown point is a smooth but markedly nonlinear functional of an
## estimated variance matrix, so its bootstrap distribution is skewed in
## small samples and the percentile interval inherits that skewness without
## correcting for it. BCa corrects it with two constants: a median-bias
## correction read off the replicates, and an acceleration read off the
## delete-one jackknife over sampling units.
##
## Returns a `regsensitivity_boot` object: the original breakdown estimate,
## the vector of bootstrap replicates, and both intervals.

#' Bootstrap confidence interval for the breakdown point
#'
#' Computes a non-parametric (or cluster) bootstrap confidence interval for
#' the breakdown point returned by [regsen_breakdown()] or the scalar
#' `$breakdown` field of [regsen_bounds()]. Both a bias-corrected and
#' accelerated (BCa) interval and a percentile interval are returned; `type`
#' chooses which one `$ci` reports.
#'
#' @inheritParams regsen_breakdown
#' @param ... Additional arguments forwarded to [regsen_breakdown()] (the
#'   analysis to bootstrap).
#' @param type Interval type reported in `$ci`: `"bca"` (default) or
#'   `"perc"`. Under `"bca"` both intervals are computed and stored; under
#'   `"perc"` the jackknife BCa needs is skipped and `$ci_bca` is `NA`.
#'   See Details.
#' @param R Integer. Number of bootstrap replications. Defaults to 999.
#' @param cluster Optional character scalar naming a column of `data` to
#'   resample at the cluster level (e.g. `"km_grid_cel_code"` for the BFG
#'   2020 application). When NULL the standard non-parametric bootstrap is
#'   used.
#' @param level Two-sided confidence level for the percentile CI. Default
#'   0.95.
#' @param seed Optional integer seed for reproducibility. Results are
#'   identical for a given `seed` regardless of `ncores`: each replicate
#'   draws its own seed from a vector generated once up front, so nothing
#'   depends on how the work was divided. Passing a `seed` leaves the
#'   session's random stream where it was, so a bootstrap run inside a
#'   larger simulation does not disturb that simulation's own draws. With
#'   `seed = NULL` the replicate seeds come from the session stream, which
#'   is advanced by that one draw and nothing else.
#' @param ncores Number of cores for the replications and the jackknife.
#'   `NULL` (default) uses the session setting of [regsen_cores()], which
#'   is 1 unless changed; `"auto"` uses all but two of the machine's
#'   cores. A progress bar is not shown when running in parallel. Capped
#'   at `R`, and at 2 while `R CMD check --as-cran` is running, which
#'   forbids more; results do not depend on the cap. The breakdown
#'   computation inside each replicate always runs serially, so cores are
#'   not oversubscribed.
#' @param show_progress Logical; print progress bar.
#'
#' @return An object of class `regsensitivity_boot` containing: `point`,
#'   `replicates`, `ci` (the interval named by `type`), `ci_bca`, `ci_perc`,
#'   `z0`, `acceleration`, `type`, `level`, `R`, `cluster`, `na` (the
#'   number of replicates that could not be computed) and `infinite` (the
#'   number on which the hypothesis survived every value of the sensitivity
#'   parameter; these count as `+Inf` in the intervals rather than being
#'   dropped).
#'
#' @details
#' For DMP analyses the breakdown point is computed exactly as in
#' [regsen_breakdown()]; when `rxbar`, `rybar` and `cbar` are all scalar the
#' returned breakdown is the rxbar breakdown for the (scalar) hypothesis on
#' beta. For Oster analyses the breakdown is the |delta| value at which
#' the hypothesis first fails.
#'
#' The BCa interval takes the percentile interval and shifts the quantiles
#' it reads by two constants: `z0`, a median-bias correction equal to the
#' normal quantile of the share of replicates below the point estimate, and
#' `acceleration`, computed from the delete-one jackknife over sampling
#' units -- rows, or clusters when `cluster` is given. The jackknife costs
#' one breakdown computation per unit, which under an i.i.d. bootstrap
#' means one per row and usually dominates the run; both it and the
#' replicates honour `ncores`, and `type = "perc"` skips it. When the
#' jackknife is degenerate (every unit gives the same estimate, so the
#' acceleration is undefined) the BCa interval falls back to the percentile
#' interval and `acceleration` is `NA`.
#'
#' @export
#' @examples
#' \donttest{
#' data(bfg2020)
#' bfg2020$statea <- factor(bfg2020$statea)
#' w1 <- c("log_area_2010", "lat", "lon", "temp_mean", "rain_mean",
#'         "elev_mean", "d_coa", "d_riv", "d_lak", "ave_gyi")
#' form <- reformulate(c("tye_tfe890_500kNI_100_l6", w1, "statea"),
#'                     response = "avgrep2000to2016")
#' set.seed(1)
#' bb <- regsen_boot(form, bfg2020, compare = w1, cbar = 1,
#'                    R = 199, cluster = "km_grid_cel_code")
#' print(bb)
#' }
regsen_boot <- function(formula, data,
                        ..., type = c("bca", "perc"),
                        R = 999L,
                        cluster = NULL,
                        level = 0.95,
                        seed = NULL,
                        ncores = NULL,
                        show_progress = interactive()) {
    stopifnot(is.data.frame(data), length(R) == 1, R >= 1,
              level > 0, level < 1)
    R <- as.integer(R)
    type <- match.arg(type)
    ncores <- min(resolve_ncores(ncores), R)

    # Where the session's random stream is left when this returns. With a
    # `seed` the call is transparent: it starts from `seed` and puts the
    # caller's stream back as it found it, so a bootstrap dropped into the
    # middle of someone else's simulation does not redirect theirs. Without
    # one the call consumes randomness like any other random function, and
    # the stream is left advanced by exactly the seed draw below rather
    # than parked on the last replicate's seed. `exit_state` is read when
    # on.exit() fires, so the assignment after that draw is the one that
    # counts; until then it restores what we started with, which is what an
    # error part way through should leave behind.
    old_state <- get_random_seed()
    exit_state <- old_state
    on.exit(restore_random_seed(exit_state), add = TRUE)

    if (!is.null(seed)) set.seed(seed)

    # The point estimate may use the cores itself: nothing else is running
    # yet. Replicates below run serially inside, in parallel across.
    point_res <- regsen_breakdown(formula, data, ..., ncores = ncores)
    point <- point_res$results$breakdown[1]

    # Build the model matrices once; every replicate is a row subset of
    # them. `regsen_breakdown()` above has already validated the arguments,
    # so anything that goes wrong from here is a property of the resample.
    dots <- list(...)
    boot_args <- resolve_boot_args(...)
    inputs <- build_dgp_inputs(formula, data,
                               compare = dots$compare,
                               nocompare = dots$nocompare,
                               subset = dots$subset)
    evaluate <- function(rows) {
        res <- tryCatch(
            do.call(breakdown_from_dgp,
                    c(list(get_dgp(subset_dgp_inputs(inputs, rows))),
                      boot_args, list(ncores = 1L))),
            error = function(e) NULL
        )
        if (is.null(res) || nrow(res$results) == 0) {
            return(NA_real_)
        }
        res$results$breakdown[1]
    }

    n <- inputs$n
    if (!is.null(cluster)) {
        if (!cluster %in% names(data)) {
            stop("`cluster` column '", cluster, "' not found in data.",
                 call. = FALSE)
        }
        # The rows the model frame kept, in the order the inputs hold them.
        cluster_id <- data[[cluster]][inputs$rows]
        cluster_levels <- unique(cluster_id)
        unit_rows <- lapply(cluster_levels, function(g) which(cluster_id == g))
    } else {
        unit_rows <- NULL
    }

    # One seed per replicate, drawn once here. Each replicate then sets its
    # own seed before resampling, so a given `seed` yields the same
    # replicates whether the run is serial or spread over any number of
    # cores. Relying on parallel RNG substreams instead would make results
    # depend on the core count, which is exactly what a replication package
    # must not do.
    rep_seeds <- sample.int(.Machine$integer.max, R)
    if (is.null(seed)) exit_state <- get_random_seed()

    boot_one <- function(b) {
        set.seed(rep_seeds[b])
        idx <- if (is.null(cluster)) {
            sample.int(n, replace = TRUE)
        } else {
            unlist(unit_rows[sample.int(length(unit_rows), replace = TRUE)])
        }
        evaluate(idx)
    }

    reps <- run_replicates(boot_one, R, ncores, show_progress,
                           label = paste0("Bootstrap (R=", R, ")"))

    # NA is a replicate that could not be computed and is dropped; +Inf is
    # a replicate on which the hypothesis survived every value of the
    # sensitivity parameter, which is a legitimate value of the breakdown
    # point and stays in. Dropping it too would report a finite upper
    # endpoint for an interval whose upper tail is unbounded.
    na_count <- sum(is.na(reps))
    inf_count <- sum(is.infinite(reps))
    alpha <- (1 - level) / 2
    ci_perc <- stats::quantile(reps[!is.na(reps)],
                               probs = c(alpha, 1 - alpha),
                               names = FALSE, na.rm = TRUE)

    # BCa. The jackknife runs over the same units the bootstrap resamples,
    # so a cluster bootstrap gets a cluster jackknife. It costs one
    # breakdown computation per unit, which for an i.i.d. bootstrap is one
    # per row and dominates the run, so it is skipped when the caller has
    # asked for the percentile interval.
    if (type == "bca") {
        jack_units <- if (is.null(cluster)) seq_len(n) else seq_along(unit_rows)
        jack_one <- function(u) {
            drop <- if (is.null(cluster)) u else unit_rows[[u]]
            evaluate(seq_len(n)[-drop])
        }
        jack <- run_replicates(jack_one, length(jack_units),
                               min(ncores, length(jack_units)), show_progress,
                               label = paste0("Jackknife (",
                                              length(jack_units), " units)"))
        bca <- bca_interval(point, reps, jack, level)
    } else {
        jack <- numeric(0)
        bca <- list(ci = c(NA_real_, NA_real_), z0 = NA_real_,
                    acceleration = NA_real_, fellback = FALSE,
                    extreme = FALSE)
    }

    structure(
        list(
            point = point,
            replicates = reps,
            jackknife = jack,
            ci = if (type == "bca") bca$ci else ci_perc,
            ci_bca = bca$ci,
            ci_perc = ci_perc,
            z0 = bca$z0,
            acceleration = bca$acceleration,
            extreme_endpoint = bca$extreme,
            type = if (type == "bca" && bca$fellback) "perc" else type,
            requested_type = type,
            level = level,
            R = R,
            cluster = cluster,
            ncores = ncores,
            na = na_count,
            infinite = inf_count,
            point_res = point_res
        ),
        class = "regsensitivity_boot"
    )
}

# Arguments of `regsen_breakdown()` that `breakdown_from_dgp()` also takes.
# Anything else in `...` -- `compare`, `subset` and friends -- is already
# baked into the model matrices and must not be passed on.
resolve_boot_args <- function(...) {
    args <- list(...)
    keep <- c("analysis", "beta", "cbar", "clow", "rybar", "rybar_expr",
              "direction", "rxbar", "r2long", "maxovb", "r2long_type",
              "maxovb_type")
    args <- args[intersect(names(args), keep)]   # drops ncores too
    if (!is.null(args$analysis)) args$analysis <- match_analysis(args$analysis)
    args
}

# The BCa endpoints of Efron (1987): the percentile interval read at
# quantiles shifted by the median-bias correction z0 and the acceleration a.
#
# `a` comes from the skewness of the jackknife values. Both constants are
# undefined in degenerate cases -- every replicate on one side of the point
# estimate, or a jackknife with no spread -- and the interval then falls back
# to the percentile one rather than returning an endpoint built from an
# infinite z.
bca_interval <- function(point, reps, jack, level) {
    alpha <- (1 - level) / 2
    probs <- c(alpha, 1 - alpha)
    # Infinite replicates are kept, as in the percentile interval; only
    # the jackknife below needs finite values, for the acceleration.
    valid_reps <- reps[!is.na(reps)]
    fallback <- list(
        ci = stats::quantile(valid_reps, probs = probs, names = FALSE,
                             na.rm = TRUE),
        z0 = NA_real_, acceleration = NA_real_, fellback = TRUE,
        extreme = FALSE
    )
    if (length(valid_reps) < 10 || !is.finite(point)) return(fallback)

    share <- mean(valid_reps < point)
    if (share <= 0 || share >= 1) return(fallback)
    z0 <- stats::qnorm(share)

    jack <- jack[is.finite(jack)]
    if (length(jack) < 3) return(fallback)
    dev <- mean(jack) - jack
    denom <- 6 * sum(dev^2)^1.5
    if (!is.finite(denom) || denom <= 0) return(fallback)
    acc <- sum(dev^3) / denom
    if (!is.finite(acc)) return(fallback)

    zq <- stats::qnorm(probs)
    adj <- stats::pnorm(z0 + (z0 + zq) / (1 - acc * (z0 + zq)))
    if (any(!is.finite(adj))) return(fallback)
    ci <- stats::quantile(valid_reps, probs = adj, names = FALSE,
                          na.rm = TRUE)
    # An adjusted quantile past the smallest or largest replicate makes the
    # endpoint an extreme order statistic, which is where BCa is least
    # reliable; the fix is more replicates, and the caller reports it.
    nb <- length(valid_reps)
    extreme <- any(adj < 1 / (nb + 1)) || any(adj > nb / (nb + 1))
    list(ci = ci, z0 = z0, acceleration = acc, fellback = FALSE,
         extreme = extreme)
}

# Run `fn` over seq_len(n), serially with an optional progress bar or across
# `ncores` workers.
run_replicates <- function(fn, n, ncores, show_progress, label) {
    if (n == 0) return(numeric(0))
    if (ncores > 1L) {
        # A progress bar cannot report meaningfully from several workers,
        # so it is suppressed rather than printed wrongly.
        return(par_numeric(n, fn, ncores))
    }
    out <- numeric(n)
    if (show_progress) {
        message(label, "...")
        pb <- utils::txtProgressBar(min = 0, max = n, style = 3)
    }
    for (i in seq_len(n)) {
        out[i] <- fn(i)
        if (show_progress) utils::setTxtProgressBar(pb, i)
    }
    if (show_progress) close(pb)
    out
}

# The magnitude of a signed interval. An Oster breakdown delta carries the
# direction of selection in its sign, and what is quoted as "the breakdown
# point" is its magnitude, so the interval is reported for that. Taking
# abs() of the two endpoints separately reversed them for a negative
# interval and, for one straddling zero, hid that the magnitude may be as
# small as zero.
abs_interval <- function(ci) {
    if (any(is.na(ci))) return(abs(ci))
    if (ci[1] <= 0 && ci[2] >= 0) c(0, max(abs(ci))) else sort(abs(ci))
}


#' Print, summarize and plot a bootstrapped breakdown point
#'
#' `print()` gives the point estimate and the interval `regsen_boot()`
#' reported. `summary()` adds the analysis bootstrapped, both interval
#' types, the BCa constants, the distribution of the replicates (their
#' standard deviation is the bootstrap standard error) and the counts of
#' failed and infinite replicates. `plot()` draws the replicates with the
#' point estimate and the interval marked. `confint()` returns the interval
#' as a matrix, recomputing it from the stored replicates when `level` or
#' `type` differ from those of the run.
#'
#' Every value is the magnitude of the breakdown point, as printed by
#' [regsen_breakdown()].
#'
#' @param x,object A `regsensitivity_boot` object, or for the `print()`
#'   method of its summary, a `summary.regsensitivity_boot` object.
#' @param parm Ignored; there is one parameter.
#' @param level Confidence level. Defaults to the level of the run.
#' @param type `"bca"` or `"perc"`. Defaults to the interval the run
#'   reported. `"bca"` needs the jackknife, which a run with
#'   `type = "perc"` skipped.
#' @param bins Number of histogram bins.
#' @param base_size Base font size, passed to [theme_regsen()].
#' @param ... Ignored.
#'
#' @return `confint()` returns a 1 x 2 matrix. `summary()` returns an
#'   object of class `summary.regsensitivity_boot`. `plot()` returns a
#'   `ggplot` object.
#' @name regsen_boot-methods
#' @examples
#' \donttest{
#' data(bfg2020)
#' f <- avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon
#' bb <- regsen_boot(f, bfg2020, compare = c("log_area_2010", "lat", "lon"),
#'                   R = 99, type = "perc", seed = 1)
#' bb
#' summary(bb)
#' confint(bb, level = 0.9)
#' plot(bb)
#' }
NULL

#' @rdname regsen_boot-methods
#' @export
print.regsensitivity_boot <- function(x, ...) {
    cat("Bootstrap confidence interval for the breakdown point\n")
    cat(strrep("-", 60), "\n", sep = "")
    kind <- if (identical(x$type, "bca")) "BCa" else "percentile"
    cat(sprintf("  Point estimate     : %.4f\n", abs(x$point)))
    ci <- abs_interval(x$ci)
    cat(sprintf("  %s%% CI (%s)%s: [%.4f, %.4f]\n", round(100 * x$level),
                kind, strrep(" ", max(0, 10 - nchar(kind))), ci[1], ci[2]))
    cat(sprintf("  Replicates         : %d%s\n", x$R,
                if (is.null(x$cluster)) "" else
                    paste0(", resampling clusters of ", x$cluster)))
    if (identical(x$requested_type, "bca") && !identical(x$type, "bca")) {
        cat("  (BCa unavailable on these replicates; showing percentile)\n")
    }
    cat("\nUse summary() for the replicate distribution and both intervals.\n")
    invisible(x)
}

#' @rdname regsen_boot-methods
#' @export
summary.regsensitivity_boot <- function(object, ...) {
    reps <- abs(object$replicates[!is.na(object$replicates)])
    fin <- reps[is.finite(reps)]
    point <- abs(object$point)
    pr <- object$point_res
    structure(
        list(
            analysis = pr$analysis,
            treatment = pr$indvar,
            hypothesis = format_hypothesis(pr),
            point = point,
            ci = abs_interval(object$ci),
            ci_perc = abs_interval(object$ci_perc),
            ci_bca = abs_interval(object$ci_bca),
            type = object$type,
            requested_type = object$requested_type,
            level = object$level,
            z0 = object$z0,
            acceleration = object$acceleration,
            extreme_endpoint = object$extreme_endpoint,
            R = object$R,
            cluster = object$cluster,
            ncores = object$ncores,
            se = if (length(fin) > 1) stats::sd(fin) else NA_real_,
            bias = if (length(fin)) mean(fin) - point else NA_real_,
            quantiles = if (length(fin)) {
                stats::quantile(fin, c(0, 0.25, 0.5, 0.75, 1), names = TRUE)
            } else {
                NULL
            },
            na = object$na,
            infinite = object$infinite
        ),
        class = "summary.regsensitivity_boot"
    )
}

#' @rdname regsen_boot-methods
#' @export
print.summary.regsensitivity_boot <- function(x, ...) {
    cat("Bootstrap inference for the breakdown point\n")
    cat(strrep("-", 60), "\n", sep = "")
    cat(sprintf("  Analysis           : %s\n", x$analysis))
    cat(sprintf("  Treatment          : %s\n", x$treatment))
    cat(sprintf("  Hypothesis         : %s\n", x$hypothesis))
    cat(sprintf("  Replicates (R)     : %d\n", x$R))
    cat(sprintf("  Cluster bootstrap  : %s\n",
                if (is.null(x$cluster)) "no" else x$cluster))
    if (!is.null(x$ncores) && x$ncores > 1L) {
        cat(sprintf("  Cores              : %d\n", x$ncores))
    }

    cat("\n--- Estimate --------------------------------------------\n")
    cat(sprintf("  Point estimate     : %.4f\n", x$point))
    cat(sprintf("  Bootstrap SE       : %.4f\n", x$se))
    cat(sprintf("  Bootstrap bias     : %.4f\n", x$bias))
    lv <- round(100 * x$level)
    if (identical(x$type, "bca")) {
        cat(sprintf("  %s%% CI (BCa)       : [%.4f, %.4f]\n", lv,
                    x$ci_bca[1], x$ci_bca[2]))
        cat(sprintf("  Bias corr. (z0)    : %.4f\n", x$z0))
        cat(sprintf("  Acceleration       : %.4f\n", x$acceleration))
    } else if (identical(x$requested_type, "bca")) {
        cat("  (BCa unavailable on these replicates; showing percentile)\n")
    }
    cat(sprintf("  %s%% CI (percentile): [%.4f, %.4f]\n", lv,
                x$ci_perc[1], x$ci_perc[2]))
    if (isTRUE(x$extreme_endpoint)) {
        cat("  (A BCa endpoint is an extreme replicate; raise R)\n")
    }

    if (!is.null(x$quantiles)) {
        cat("\n--- Finite replicates -----------------------------------\n")
        q <- x$quantiles
        names(q) <- c("Min", "Q1", "Median", "Q3", "Max")
        print(round(q, 4))
    }
    if (x$na > 0) {
        cat(sprintf("\n  Failed replicates  : %d of %d, dropped\n", x$na, x$R))
    }
    if (!is.null(x$infinite) && x$infinite > 0) {
        cat(sprintf("  Infinite replicates: %d of %d, kept as +Inf; the ",
                    x$infinite, x$R),
            "hypothesis survived every value there\n", sep = "")
    }
    invisible(x)
}

#' @rdname regsen_boot-methods
#' @export
confint.regsensitivity_boot <- function(object, parm, level = object$level,
                                        type = object$type, ...) {
    type <- match.arg(type, c("bca", "perc"))
    stopifnot(is.numeric(level), length(level) == 1, level > 0, level < 1)
    same <- isTRUE(all.equal(level, object$level))
    ci <- if (type == "perc") {
        if (same) {
            object$ci_perc
        } else {
            alpha <- (1 - level) / 2
            stats::quantile(object$replicates, c(alpha, 1 - alpha),
                            names = FALSE, na.rm = TRUE)
        }
    } else {
        if (length(object$jackknife) == 0) {
            stop("the BCa interval needs the jackknife, which a run with ",
                 "type = \"perc\" skips; rerun regsen_boot() with ",
                 "type = \"bca\".", call. = FALSE)
        }
        if (same) {
            object$ci_bca
        } else {
            bca_interval(object$point, object$replicates, object$jackknife,
                         level)$ci
        }
    }
    probs <- c((1 - level) / 2, 1 - (1 - level) / 2)
    matrix(abs_interval(ci), nrow = 1,
           dimnames = list("breakdown",
                           paste(format(100 * probs, trim = TRUE,
                                        scientific = FALSE, digits = 3), "%")))
}

#' @rdname regsen_boot-methods
#' @export
plot.regsensitivity_boot <- function(x, bins = 30, base_size = 11, ...) {
    reps <- abs(x$replicates[!is.na(x$replicates)])
    fin <- reps[is.finite(reps)]
    if (length(fin) == 0) {
        stop("no finite replicates to plot.", call. = FALSE)
    }
    ci <- abs_interval(x$ci)
    kind <- if (identical(x$type, "bca")) "BCa" else "percentile"
    sub <- sprintf("%s%% %s interval shaded; point estimate dashed",
                   round(100 * x$level), kind)
    n_inf <- length(reps) - length(fin)
    if (n_inf > 0) {
        sub <- paste0(sub, sprintf("; %d infinite replicate(s) not drawn",
                                   n_inf))
    }
    ggplot2::ggplot(data.frame(breakdown = fin),
                    ggplot2::aes(x = .data$breakdown)) +
        ggplot2::annotate("rect", xmin = ci[1], xmax = ci[2],
                          ymin = -Inf, ymax = Inf,
                          fill = okabe_ito[1], alpha = 0.15) +
        ggplot2::geom_histogram(bins = bins, fill = "grey60",
                                colour = "white", linewidth = 0.2) +
        ggplot2::geom_vline(xintercept = abs(x$point), linetype = "dashed",
                            colour = okabe_ito[1], linewidth = 0.5) +
        ggplot2::labs(x = "Bootstrap breakdown point", y = "Replicates",
                      subtitle = sub) +
        theme_regsen(base_size = base_size, grid = "y")
}
