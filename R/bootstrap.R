## bootstrap.R --- inference for the breakdown point via percentile or
## cluster bootstrap.
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
## Returns a `regsensitivity_boot` object: the original breakdown estimate,
## a vector of bootstrap replicates, and a percentile CI.

#' Bootstrap confidence interval for the breakdown point
#'
#' Computes a non-parametric (or cluster) bootstrap percentile confidence
#' interval for the breakdown point returned by [regsen_breakdown()] or the
#' scalar `$breakdown` field of [regsen_bounds()].
#'
#' @inheritParams regsen_breakdown
#' @param ... Additional arguments forwarded to [regsen_breakdown()] (the
#'   analysis to bootstrap).
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
#'   depends on how the work was divided.
#' @param ncores Number of cores for the replications. `1` (default) runs
#'   serially. Above 1 the package forks on macOS and Linux and falls back
#'   to a PSOCK cluster on Windows, which has no fork. A progress bar is
#'   not shown when running in parallel. Capped at `R`, and at 2 while
#'   `R CMD check --as-cran` is running, which forbids more; results do not
#'   depend on the cap.
#' @param show_progress Logical; print progress bar.
#'
#' @return An object of class `regsensitivity_boot` containing:
#'   `point`, `replicates`, `ci`, `level`, `R`, `cluster`, `na`.
#'
#' @details
#' For DMP analyses the breakdown point is computed exactly as in
#' [regsen_breakdown()]; when `rxbar`, `rybar` and `cbar` are all scalar the
#' returned breakdown is the rxbar breakdown for the (scalar) hypothesis on
#' beta. For Oster analyses the breakdown is the |delta| value at which
#' the hypothesis first fails.
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
                        ..., R = 999L,
                        cluster = NULL,
                        level = 0.95,
                        seed = NULL,
                        ncores = 1L,
                        show_progress = interactive()) {
    stopifnot(is.data.frame(data), R >= 1, level > 0, level < 1)
    ncores <- as.integer(ncores)
    if (is.na(ncores) || ncores < 1L) {
        stop("`ncores` must be a positive integer.", call. = FALSE)
    }
    ncores <- min(ncores, R, max_allowed_cores())

    if (!is.null(seed)) set.seed(seed)

    point_res <- regsen_breakdown(formula, data, ...)
    point <- point_res$results$breakdown[1]

    n <- nrow(data)
    if (!is.null(cluster)) {
        if (!cluster %in% names(data)) {
            stop("`cluster` column '", cluster, "' not found in data.",
                 call. = FALSE)
        }
        cluster_id <- data[[cluster]]
        cluster_levels <- unique(cluster_id)
    }

    # One seed per replicate, drawn once here. Each replicate then sets its
    # own seed before resampling, so a given `seed` yields the same
    # replicates whether the run is serial or spread over any number of
    # cores. Relying on parallel RNG substreams instead would make results
    # depend on the core count, which is exactly what a replication package
    # must not do.
    rep_seeds <- sample.int(.Machine$integer.max, R)

    boot_one <- function(b) {
        set.seed(rep_seeds[b])
        if (is.null(cluster)) {
            idx <- sample.int(n, replace = TRUE)
        } else {
            sampled <- sample(cluster_levels, length(cluster_levels),
                              replace = TRUE)
            idx <- unlist(lapply(sampled, function(g) which(cluster_id == g)))
        }
        d_b <- data[idx, , drop = FALSE]
        res <- tryCatch(
            regsen_breakdown(formula, d_b, ...),
            error = function(e) NULL
        )
        if (is.null(res) || nrow(res$results) == 0) {
            return(NA_real_)
        }
        res$results$breakdown[1]
    }

    if (ncores > 1L) {
        # A progress bar cannot report meaningfully from several workers,
        # so it is suppressed rather than printed wrongly.
        reps <- boot_parallel(boot_one, R, ncores)
    } else {
        reps <- numeric(R)
        if (show_progress) {
            message("Bootstrap (R=", R, ")...")
            pb <- utils::txtProgressBar(min = 0, max = R, style = 3)
        }
        for (b in seq_len(R)) {
            reps[b] <- boot_one(b)
            if (show_progress) utils::setTxtProgressBar(pb, b)
        }
        if (show_progress) close(pb)
    }

    na_count <- sum(is.na(reps))
    finite_reps <- reps[is.finite(reps)]
    alpha <- (1 - level) / 2
    ci <- stats::quantile(finite_reps,
                          probs = c(alpha, 1 - alpha),
                          names = FALSE,
                          na.rm = TRUE)

    structure(
        list(
            point = point,
            replicates = reps,
            ci = ci,
            level = level,
            R = R,
            cluster = cluster,
            ncores = ncores,
            na = na_count,
            point_res = point_res
        ),
        class = "regsensitivity_boot"
    )
}

#' @export
print.regsensitivity_boot <- function(x, ...) {
    cat("Bootstrap confidence interval for the breakdown point\n")
    cat(strrep("-", 60), "\n", sep = "")
    cat(sprintf("  R                  : %d\n", x$R))
    cat(sprintf("  Cluster bootstrap  : %s\n",
                if (is.null(x$cluster)) "no" else x$cluster))
    if (!is.null(x$ncores) && x$ncores > 1L) {
        cat(sprintf("  Cores              : %d\n", x$ncores))
    }
    cat(sprintf("  Confidence level   : %.0f%%\n", 100 * x$level))
    cat(sprintf("  Point estimate     : %.4f\n", abs(x$point)))
    cat(sprintf("  %s%% CI            : [%.4f, %.4f]\n",
                round(100 * x$level), abs(x$ci[1]), abs(x$ci[2])))
    if (x$na > 0) {
        cat(sprintf("  (Failed replicates : %d/%d)\n", x$na, x$R))
    }
    invisible(x)
}

# R CMD check --as-cran sets _R_CHECK_LIMIT_CORES_, and parallel then
# refuses to spawn more than two processes. Without this cap a user
# running check() on their own package -- with a vignette or example that
# calls regsen_boot(ncores = 4) -- would get a hard error out of
# parallel:::.check_ncores rather than a slower run. Silently honouring
# the limit is the behaviour that keeps their check green.
max_allowed_cores <- function() {
    chk <- Sys.getenv("_R_CHECK_LIMIT_CORES_", "")
    if (nzchar(chk) && !identical(tolower(chk), "false")) 2L else Inf
}

# Run `fn` R times across `ncores` workers.
#
# Forking (mclapply) is used where the OS provides it: workers inherit the
# whole session, so the data and the closure need no explicit export and
# nothing is copied until written to. Windows has no fork, so it gets a
# PSOCK cluster instead, which does need the closure's environment shipped
# to each worker -- slower to start, and the reason forking is preferred
# where available.
boot_parallel <- function(fn, R, ncores) {
    if (.Platform$OS.type != "windows") {
        # mc.set.seed = FALSE: each replicate seeds itself from the
        # pre-drawn vector, so letting the fork reseed would only add
        # core-count dependence back in.
        out <- parallel::mclapply(seq_len(R), fn,
                                  mc.cores = ncores,
                                  mc.set.seed = FALSE)
    } else {
        cl <- parallel::makeCluster(ncores)
        on.exit(parallel::stopCluster(cl), add = TRUE)
        parallel::clusterEvalQ(cl, {
            suppressMessages(requireNamespace("regsensitivity", quietly = TRUE))
        })
        parallel::clusterExport(cl, varlist = "fn", envir = environment())
        out <- parallel::parLapply(cl, seq_len(R), fn)
    }

    # mclapply signals a worker failure by returning a try-error in that
    # slot rather than throwing, so a crashed replicate must be mapped to NA
    # here or it would propagate as a list element into a numeric vector.
    vapply(out, function(z) {
        if (inherits(z, "try-error") || is.null(z) || length(z) != 1) {
            NA_real_
        } else {
            as.numeric(z)
        }
    }, numeric(1))
}
