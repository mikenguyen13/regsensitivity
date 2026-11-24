# Snapshot of public usage signals for regsensitivity.
#
# Run monthly and append to paper-rj/engagement-log.csv; the log is the
# evidence of uptake for the R Journal resubmission (article 2026-199).
#
#   Rscript tools/engagement-stats.R
#
# Needs only base R + jsonlite. GitHub's unauthenticated API allows 60
# requests an hour, which is plenty here.

stopifnot(requireNamespace("jsonlite", quietly = TRUE))

pkg   <- "regsensitivity"
repo  <- "mikenguyen13/regsensitivity"
first <- "2026-10-20" # first CRAN release
today <- format(Sys.Date())

get_json <- function(url) {
  tryCatch(jsonlite::fromJSON(url), error = function(e) {
    warning("could not read ", url, ": ", conditionMessage(e))
    NULL
  })
}

cran_total <- get_json(sprintf(
  "https://cranlogs.r-pkg.org/downloads/total/%s:%s/%s", first, today, pkg
))
cran_month <- get_json(sprintf(
  "https://cranlogs.r-pkg.org/downloads/total/last-month/%s", pkg
))
gh       <- get_json(sprintf("https://api.github.com/repos/%s", repo))
gh_iss   <- get_json(sprintf(
  "https://api.github.com/repos/%s/issues?state=all&per_page=100", repo
))
revdeps  <- tryCatch(
  tools::package_dependencies(pkg, reverse = TRUE,
                              which = c("Depends", "Imports", "Suggests"))[[pkg]],
  error = function(e) character()
)

# Issues opened by someone other than the maintainer are the signal the
# editor asked for; the maintainer's own issues are not.
n_ext_issues <- if (is.null(gh_iss) || length(gh_iss) == 0) 0L else
  sum(gh_iss$user$login != "mikenguyen13")

row <- data.frame(
  date                 = today,
  cran_downloads_total = if (is.null(cran_total)) NA else cran_total$downloads,
  cran_downloads_30d   = if (is.null(cran_month)) NA else cran_month$downloads,
  gh_stars             = if (is.null(gh)) NA else gh$stargazers_count,
  gh_forks             = if (is.null(gh)) NA else gh$forks_count,
  gh_external_issues   = n_ext_issues,
  cran_reverse_deps    = length(revdeps)
)
print(row, row.names = FALSE)

log <- file.path("paper-rj", "engagement-log.csv")
if (dir.exists(dirname(log))) {
  write.table(row, log, sep = ",", row.names = FALSE,
              col.names = !file.exists(log), append = file.exists(log))
  message("appended to ", log)
}
