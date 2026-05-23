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
#' @param seed Optional integer seed for reproducibility.
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
                        show_progress = interactive()) {
    stopifnot(is.data.frame(data), R >= 1, level > 0, level < 1)
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

    boot_one <- function() {
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

    reps <- numeric(R)
    if (show_progress) {
        message("Bootstrap (R=", R, ")...")
        pb <- utils::txtProgressBar(min = 0, max = R, style = 3)
    }
    for (b in seq_len(R)) {
        reps[b] <- boot_one()
        if (show_progress) utils::setTxtProgressBar(pb, b)
    }
    if (show_progress) close(pb)

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
    cat(sprintf("  Confidence level   : %.0f%%\n", 100 * x$level))
    cat(sprintf("  Point estimate     : %.4f\n", abs(x$point)))
    cat(sprintf("  %s%% CI            : [%.4f, %.4f]\n",
                round(100 * x$level), abs(x$ci[1]), abs(x$ci[2])))
    if (x$na > 0) {
        cat(sprintf("  (Failed replicates : %d/%d)\n", x$na, x$R))
    }
    invisible(x)
}
