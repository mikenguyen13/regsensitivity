# Morning checklist — what’s ready, what’s left for you

Generated overnight. Everything that didn’t need your interactive
credentials or email confirmation is done.

------------------------------------------------------------------------

## ✅ Done overnight (you don’t need to do anything)

| What | Status / Result |
|----|----|
| Bug fix v0.1.0 → v0.1.1 | `quad_ineq_bounds` + 6 other functions hardened against NA propagation; 13 new regression tests added |
| Full test suite | **139 / 139 pass**, 0 warnings, 0 skips |
| `R CMD check --as-cran` | **0 errors, 0 warnings, 0 notes** |
| Spell check | **0 typos** (WORDLIST populated) |
| URL check | only “broken” URLs are your future GitHub repo (`github.com/mikenguyen13/regsensitivity`) and pkgdown site (`mikenguyen13.github.io/regsensitivity`) — they’ll work once you push |
| Code coverage | **81.5 %** — see `output/coverage.html` |
| pkgdown site | built locally to `docs/` — open `docs/index.html` in browser to preview |
| JSS paper | `paper-jss/paper.pdf` (10 pages, builds clean) |
| R Journal paper | `paper-rj/RJwrapper.pdf` (3 pages) |
| Vignettes (HTML) | `output/vignettes/*.html` |
| Source tarball | `/Users/mikenguyen/Downloads/regsensitivity_0.1.1.tar.gz` (550 KB) |
| Git repo | initialized with **single commit** by `Mike Nguyen <nguyennghia1301@gmail.com>` — zero Claude attribution |
| Win-builder resubmission | uploaded R-devel + R-release for 0.1.1 |
| Sanity-run case studies + benchmarks | all 4 scripts produce expected output |

## 📧 Check your gmail (~30 min after midnight)

Two win-builder emails should arrive by ~1:45 AM with the Windows check
results for 0.1.1. **Expected: 0 errors, 0 warnings, 1 note maximum**
(MikTeX warnings are normal). If you see another ERROR, do NOT proceed
to CRAN — wake me up.

## 📋 What’s LEFT FOR YOU TO DO (everything below needs your hands)

### Step 1 — Create the GitHub repo (2 min)

Open <https://github.com/new> in your browser and create: \* Owner: your
account \* Repository name: `regsensitivity` (must match `DESCRIPTION`
URL) \* Public \* **Do NOT initialize with README** (we already have
one)

Then in this directory:

``` bash
cd /Users/mikenguyen/Downloads/regsensitivity
git remote add origin git@github.com:mikenguyen13/regsensitivity.git
# (or https://github.com/mikenguyen13/regsensitivity.git if you use HTTPS auth)
git push -u origin main
```

If `mikenguyen13` is not your GitHub username, edit `DESCRIPTION` line
28-29 and `inst/CITATION` first, then re-run
`Rscript -e "devtools::document()"`.

### Step 2 — Wait for CI green (5 min)

After push, GitHub Actions will run R-CMD-check on 5 OS/R combinations
(macOS, Windows, Ubuntu × {devel, release, oldrel-1}). Watch the
**Actions** tab on your repo until all 5 are green. If any fail, read
the log; usually just a missing system dep on a runner — re-run.

### Step 3 — Submit to CRAN (interactive, 5 min)

In the same terminal:

``` bash
Rscript -e "devtools::release()"
```

This will: 1. Re-run R CMD check (passes). 2. Ask you a series of “Is X
OK?” questions — answer **yes** to each unless something looks wrong. 3.
Email you a confirmation link. 4. **Click that link within 24 hours.**

Then wait 1–3 weeks. A CRAN volunteer will email you. Address every
comment they raise and resubmit.

### Step 4 — Tag GitHub release + Zenodo DOI (3 min)

After CRAN accepts (or even before):

``` bash
git tag v0.1.1
git push origin v0.1.1
```

Then open <https://github.com/>/regsensitivity/releases/new — choose tag
`v0.1.1`, title “regsensitivity 0.1.1”, paste the NEWS.md section as
body, publish.

Then visit <https://zenodo.org/account/settings/github/> and flip the
toggle ON next to `regsensitivity`. Re-publish the GitHub release (or
push a new tag) and Zenodo will mint a DOI you can cite from
JSS/RJ/JOSS.

### Step 5 — Submit to publishing venues

**Tenure target — JSS (Journal of Statistical Software):** 1. Open
<https://www.jstatsoft.org/about/submissions> 2. Create an account if
you don’t have one 3. Upload `paper-jss/paper.pdf` (or the `.Rnw` if
they want the source) 4. Cover letter: emphasize the methodological
novelty (bootstrap CI for breakdown point, formula API, ggplot2
plotting, 26 paper-exact tests) and the wide applicability (the original
Stata module is heavily cited) 5. Suggested editors: anyone on the JSS
board who works on econometrics

**Backup — R Journal:** 1. Open
<https://journal.r-project.org/submissions.html> 2. Upload
`paper-rj/RJwrapper.pdf` 3. Same cover letter, but 6-12 page expectation

**Fast DOI — JOSS:** 1. Need Zenodo DOI from step 4 first 2. Open
<https://joss.theoj.org/papers/new> 3. Software repo:
`https://github.com/<you>/regsensitivity` 4. Branch: `main`, version:
`v0.1.1` 5. Submit; review starts in ~1 week 6. **Median time to
acceptance: 6 weeks**

### Step 6 — Citations infrastructure (already done)

`citation("regsensitivity")` in R returns the proper BibTeX. Once the
Zenodo DOI is minted, add it to `inst/CITATION` and re-document.

## 🚨 If something looks wrong

- **win-builder ERROR**: stop, send me the log
- **GitHub CI red**: read the log, usually a runner issue
- **CRAN feedback email**: forward to me; I’ll help draft the response
- **Spell typos creeping back**: add the word to `inst/WORDLIST`

## 📊 Sanity numbers you can spot-check

If `regsen_bounds(form, bfg2020, compare=w1, cbar=0.1)` gives anything
other than breakdown ≈ **1.1947**, something is wrong.

If `calibrate_rho(form, bfg2020, compare=w1)` doesn’t put `ave_gyi` at ≈
**118.3** at the top, something is wrong.

Both are pinned by paper-exact tests in `test-paper-table1.R`, so the
test suite will tell you first.

------------------------------------------------------------------------

## File tree summary (as of overnight build)

    regsensitivity/
    ├── DESCRIPTION                          # v0.1.1
    ├── NEWS.md                              # changelog
    ├── README.md                            # quickstart + Stata↔R crosswalk
    ├── inst/
    │   ├── CITATION                         # citation("regsensitivity") works
    │   ├── WORDLIST                         # spell check whitelist
    │   ├── casestudies/                     # 2 worked examples
    │   ├── benchmarks/                      # sensemakr + perf benchmarks
    │   ├── replication/                     # standalone DMP paper script
    │   └── stata-reference/                 # upstream Stata pkg artifacts
    ├── paper/                               # JOSS submission (paper.md)
    ├── paper-jss/                           # JSS submission (paper.pdf)
    ├── paper-rj/                            # R Journal submission (RJwrapper.pdf)
    ├── output/                              # built vignettes + coverage report
    ├── docs/                                # pkgdown site
    ├── R/                                   # 10 source files (~3500 LOC)
    ├── tests/testthat/                      # 11 test files, 139 assertions
    ├── vignettes/                           # 3 vignettes
    ├── .github/workflows/                   # 4 CI workflows
    ├── release.sh                           # staged submission helper
    └── MORNING_CHECKLIST.md                 # THIS FILE
