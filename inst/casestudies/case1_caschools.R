## Case study 1: California school districts (CASchools, AER package).
##
## A classic OVB example. We regress 5th-grade test scores on the
## student-teacher ratio, controlling for English-learner share and lunch
## subsidy receipt (proxy for income). Income and other school inputs are
## the natural omitted variables. The Stock-Watson textbook reports a
## coefficient around -1 to -3 on the student-teacher ratio depending on
## specification; we ask: how strong would an omitted variable have to be
## to overturn the negative-effect conclusion?

suppressPackageStartupMessages({
    library(regsensitivity)
    library(AER)
})
data("CASchools", package = "AER")
CASchools$score <- with(CASchools, (read + math) / 2)
CASchools$STR   <- CASchools$students / CASchools$teachers

# Calibration covariates: English-learner share, lunch subsidy share.
# Non-calibration controls: county fixed effects.
form <- score ~ STR + english + lunch + county
res_bnds <- regsen_bounds(
    form,
    data = CASchools,
    compare = c("english", "lunch"),
    cbar = 1
)
print(res_bnds)

cat("\n--- Breakdown frontier across cbar ---\n")
res_bd <- regsen_breakdown(
    form, data = CASchools,
    compare = c("english", "lunch"),
    cbar = seq(0, 1, 0.1)
)
print(res_bd)

cat("\n--- Cluster bootstrap CI on rxbar breakdown (R=199, clustered by county) ---\n")
set.seed(2026)
bb <- regsen_boot(
    form, data = CASchools,
    compare = c("english", "lunch"),
    cbar = 1,
    cluster = "county",
    R = 199,
    show_progress = FALSE
)
print(bb)
