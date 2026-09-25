## parallel.R --- one place for how many cores the package uses, and for
## running independent pieces of work across them.
##
## Every expensive loop in the package is embarrassingly parallel: the grid
## points of an identified set, the values of a breakdown frontier, the
## treatments of regsen_multi(), the replicates of regsen_boot(). None of
## them draws random numbers except the bootstrap, which seeds each
## replicate itself, so a parallel run returns exactly what a serial run
## returns.
##
## The default is serial. CRAN policy limits what a package may use without
## being asked to two cores, and a default that helped itself to the
## machine would surprise anyone on a shared server; so the user opts in,
## once per session, with regsen_cores().

#' Cores used by the package
#'
#' Sets or reads the number of cores that [regsen_bounds()],
#' [regsen_breakdown()], [regsen_multi()] and [regsen_boot()] use by
#' default. Each of those also takes an `ncores` argument for a single
#' call; this sets the session-wide default those arguments fall back to,
#' held in `options(regsensitivity.ncores)`.
#'
#' Parallel runs return exactly what serial runs return. The identified set
#' and the breakdown frontiers draw no random numbers, and the bootstrap
#' seeds each replicate from a vector drawn once up front, so nothing
#' depends on how the work was divided.
#'
#' @param n One of:
#'   * `NULL` (default): read the current setting without changing it.
#'   * a positive integer: use that many cores.
#'   * `"auto"`: use `parallel::detectCores() - 2`, and at least 1. Two are
#'     left free so the session, and whatever else the machine is doing,
#'     stay responsive.
#'
#'   Whatever is set, at most 2 are used while `R CMD check --as-cran` is
#'   running, which forbids more.
#'
#' @return The number of cores in effect after the call, invisibly when
#'   `n` is given.
#'
#' @details
#' On macOS and Linux the work is forked with [parallel::mclapply()], so the
#' data and model need no copying. Windows has no fork; it gets a PSOCK
#' cluster, which is slower to start and pays to ship the data once, so
#' there the gain is only worth having for long jobs (a bootstrap, or a
#' finite-`rybar` sweep with many grid points).
#'
#' What is parallel: the grid points of a [regsen_bounds()] sweep (only the
#' finite-`rybar` regime costs anything; the closed forms are cheap either
#' way), the values of a [regsen_breakdown()] frontier, the treatments of
#' [regsen_multi()], and the replicates and jackknife of [regsen_boot()].
#' Work inside a replicate or a treatment is run serially, so cores are
#' never oversubscribed by nesting.
#'
#' @examples
#' old <- getOption("regsensitivity.ncores")
#' regsen_cores()          # the current setting, 1 unless changed
#' regsen_cores(2)         # run the sweeps on two cores
#' regsen_cores(1)         # back to serial
#' options(regsensitivity.ncores = old)
#' \dontrun{
#' # Uses every core but two, so it is not run inside checks.
#' regsen_cores("auto")
#' }
#' @export
regsen_cores <- function(n = NULL) {
    if (is.null(n)) {
        return(resolve_ncores(NULL))
    }
    n <- resolve_ncores(n)
    options(regsensitivity.ncores = n)
    invisible(n)
}

# Turn an `ncores` argument, or the session option, into a validated
# positive integer, capped by what R CMD check allows.
resolve_ncores <- function(ncores) {
    if (is.null(ncores)) {
        ncores <- getOption("regsensitivity.ncores", 1L)
    }
    if (identical(ncores, "auto")) {
        ncores <- max(1L, parallel::detectCores() - 2L)
    }
    if (!is.numeric(ncores) || length(ncores) != 1L || is.na(ncores) ||
        ncores < 1) {
        stop("`ncores` must be a single positive integer, or \"auto\".",
             call. = FALSE)
    }
    min(as.integer(ncores), max_allowed_cores())
}

# R CMD check --as-cran sets _R_CHECK_LIMIT_CORES_, and parallel then
# refuses to spawn more than two processes. Without this cap a user
# running check() on their own package -- with a vignette or example that
# asks for four cores -- would get a hard error out of
# parallel:::.check_ncores rather than a slower run. Silently honouring
# the limit is the behaviour that keeps their check green.
max_allowed_cores <- function() {
    chk <- Sys.getenv("_R_CHECK_LIMIT_CORES_", "")
    if (nzchar(chk) && !identical(tolower(chk), "false")) 2L else Inf
}

# lapply() over seq_len(n), across `ncores` workers when that is more
# than one and there is more than one thing to do. Returns a list, one
# element per index; a worker that failed hands back a `try-error`, which
# the caller maps to whatever "unavailable" means for it.
#
# Forking (mclapply) is used where the OS provides it: workers inherit the
# whole session, so the data and the closure need no explicit export and
# nothing is copied until written to. Windows has no fork, so it gets a
# PSOCK cluster instead, which does need the closure's environment shipped
# to each worker -- slower to start, and the reason forking is preferred
# where available.
par_lapply <- function(n, fn, ncores) {
    ncores <- min(ncores, n)
    # Every job catches its own error. mclapply() preschedules jobs onto
    # cores and, when one job on a core errors, marks every job on that
    # core as failed; catching inside the job keeps a failure confined to
    # the one index it belongs to.
    safe <- function(i) try(fn(i), silent = TRUE)
    if (ncores <= 1L || n <= 1L) {
        return(lapply(seq_len(n), safe))
    }
    switch(parallel_backend(),
           fork  = par_lapply_fork(n, safe, ncores),
           psock = par_lapply_psock(n, safe, ncores))
}

# Fork where the OS provides it, a socket cluster otherwise. The option
# exists so the socket path can be exercised on a machine that can fork
# -- it is the path Windows users get, and the one a test suite run on
# macOS or Linux would otherwise never touch.
parallel_backend <- function() {
    b <- getOption("regsensitivity.backend", NULL)
    if (!is.null(b)) return(match.arg(b, c("fork", "psock")))
    if (.Platform$OS.type == "windows") "psock" else "fork"
}

par_lapply_fork <- function(n, safe, ncores) {
    # mc.set.seed = FALSE: the only caller that draws random numbers
    # seeds each replicate itself, so letting the fork reseed would
    # only add core-count dependence back in.
    parallel::mclapply(seq_len(n), safe, mc.cores = ncores,
                       mc.set.seed = FALSE)
}

# A socket worker is a fresh R session. It receives `safe` by
# serialization, which carries `safe`'s enclosing environment along --
# and that environment must contain only what the job needs. So `safe`
# is rebuilt here in a small environment holding just `fn`, rather than
# shipped from par_lapply()'s frame, which would drag the cluster object
# itself into every message. The package namespace that `fn` closes over
# is serialized by name and loaded on the worker from the same library
# path the master uses.
par_lapply_psock <- function(n, safe, ncores) {
    fn <- environment(safe)$fn
    job_env <- new.env(parent = globalenv())
    job_env$fn <- fn
    job <- function(i) try(fn(i), silent = TRUE)
    environment(job) <- job_env

    cl <- parallel::makeCluster(ncores)
    on.exit(parallel::stopCluster(cl), add = TRUE)
    lib <- .libPaths()
    parallel::clusterCall(cl, function(lib) {
        .libPaths(lib)
        suppressMessages(requireNamespace("regsensitivity", quietly = TRUE))
    }, lib)
    parallel::parLapply(cl, seq_len(n), job)
}

# par_lapply() for work that returns one number per index; a failed
# worker becomes NA. This is what the bootstrap wants, where a replicate
# that cannot be computed is a fact about the resample and is counted.
par_numeric <- function(n, fn, ncores) {
    out <- par_lapply(n, fn, ncores)
    vapply(out, function(z) {
        if (inherits(z, "try-error") || is.null(z) || length(z) != 1L) {
            NA_real_
        } else {
            as.numeric(z)
        }
    }, numeric(1))
}

# As above, but a failure is re-raised as the error it was. Serial code
# would have stopped with that error; running in parallel must not turn
# it into a silent NA in one cell of a frontier.
par_numeric_strict <- function(n, fn, ncores) {
    out <- par_lapply(n, fn, ncores)
    vapply(out, function(z) {
        if (inherits(z, "try-error")) stop(attr(z, "condition"))
        as.numeric(z)
    }, numeric(1))
}
