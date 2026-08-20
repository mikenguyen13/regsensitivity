## table.R --- tidy accessors and publication-ready table output.

#' Extract sensitivity results as a tidy data frame
#'
#' Returns the results table of a `regsensitivity` object as a plain
#' `data.frame`, with the sensitivity parameters and the bounds (or the
#' breakdown frontier) in columns.
#'
#' This is the recommended entry point for producing tables. Because the
#' return value is an ordinary data frame it can be handed to whichever
#' table package you already use -- `knitr::kable()`, \pkg{kableExtra},
#' \pkg{gt}, \pkg{modelsummary}, \pkg{huxtable}, \pkg{tinytable} or
#' \pkg{xtable} -- rather than committing the package to one of them.
#' [regsen_table()] wraps the common case.
#'
#' @param x A `regsensitivity` object, from [regsen_bounds()] or
#'   [regsen_breakdown()].
#' @param row.names,optional Ignored, present for S3 compatibility with
#'   [base::as.data.frame()].
#' @param digits Optional number of significant digits to round numeric
#'   columns to. `NULL` (default) leaves the values at full precision, which
#'   is what you want when the result feeds further computation.
#' @param finite_only Logical. If `TRUE`, drop rows where every bound is
#'   non-finite. Defaults to `FALSE` so that the unbounded region of the
#'   sweep stays visible.
#' @param ... Ignored.
#'
#' @return A `data.frame`.
#'
#' @examples
#' \donttest{
#' data(bfg2020)
#' res <- regsen_bounds(
#'     avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
#'     data = bfg2020, compare = c("log_area_2010", "lat", "lon"), cbar = 0.1
#' )
#' head(as.data.frame(res))
#' }
#' @export
as.data.frame.regsensitivity <- function(x, row.names = NULL, optional = FALSE,
                                          digits = NULL, finite_only = FALSE,
                                          ...) {
    out <- x$results
    if (is.null(out) || nrow(out) == 0) {
        return(data.frame())
    }
    out <- as.data.frame(out, stringsAsFactors = FALSE)

    if (isTRUE(finite_only)) {
        bcols <- intersect(c("bmin", "bmax", "breakdown"), names(out))
        if (length(bcols)) {
            keep <- Reduce(`|`, lapply(out[bcols], is.finite))
            out <- out[keep, , drop = FALSE]
        }
    }
    if (!is.null(digits)) {
        num <- vapply(out, is.numeric, logical(1))
        out[num] <- lapply(out[num], signif, digits = digits)
    }
    rownames(out) <- NULL
    out
}

#' Render a sensitivity analysis as a publication-ready table
#'
#' Formats the results of [regsen_bounds()] or [regsen_breakdown()] for a
#' manuscript. The `format` argument selects the output flavour, so the same
#' call works in an Rmd/Qmd document knitting to PDF, to HTML, or to a
#' Markdown target such as GitHub or Typst.
#'
#' For LaTeX the default follows the convention most economics journals
#' expect: `booktabs` rules, and table notes wrapped in a `threeparttable`
#' environment so the note block is set to the width of the table rather
#' than the width of the page. Both are switchable.
#'
#' Anything this function does not expose can be done by taking
#' [as.data.frame()] of the object and passing it to the table package of
#' your choice; nothing here is a dead end.
#'
#' @param x A `regsensitivity` object.
#' @param format One of `"latex"`, `"html"`, `"markdown"`, `"pipe"` or
#'   `"simple"`. Defaults to `"latex"` when knitting to PDF and
#'   `"markdown"` otherwise.
#' @param digits Significant digits for the numeric columns.
#' @param caption Table caption. `NULL` for none.
#' @param label LaTeX label, used as `\\label{tab:<label>}`. Ignored for
#'   non-LaTeX formats.
#' @param notes Character vector of table notes, one element per line. Set
#'   to `NULL` for none, or `TRUE` to use an automatically generated note
#'   recording the analysis, hypothesis and sample size -- which is the
#'   information a referee will look for.
#' @param booktabs Logical; use `booktabs` rules in LaTeX output.
#' @param threeparttable Logical; wrap LaTeX output and its notes in a
#'   `threeparttable` environment. Requires `\\usepackage{threeparttable}`
#'   in the document preamble.
#' @param align Column alignment string, e.g. `"lrrr"`. `NULL` left-aligns
#'   character columns and right-aligns numeric ones.
#' @param col_names Optional character vector of column headings. `NULL`
#'   uses tidied versions of the internal names.
#' @param escape Logical; escape special characters. Set `FALSE` if you are
#'   supplying LaTeX markup in `col_names` or `caption`.
#' @param max_rows Optional integer. If the sweep is longer than this, the
#'   table is thinned to `max_rows` evenly spaced rows and a note records
#'   that this happened. `NULL` keeps every row.
#' @param ... Passed to [knitr::kable()].
#'
#' @return A `knitr_kable` object, which prints as the requested markup and
#'   renders directly in an Rmd/Qmd chunk.
#'
#' @examples
#' \donttest{
#' data(bfg2020)
#' res <- regsen_bounds(
#'     avgrep2000to2016 ~ tye_tfe890_500kNI_100_l6 + log_area_2010 + lat + lon,
#'     data = bfg2020, compare = c("log_area_2010", "lat", "lon"),
#'     cbar = c(0.1, 0.5, 1)
#' )
#' regsen_table(res, format = "markdown", digits = 3)
#' regsen_table(res, format = "latex", notes = TRUE,
#'              caption = "Identified sets", label = "idset")
#' }
#' @export
regsen_table <- function(x,
                         format = NULL,
                         digits = 3,
                         caption = NULL,
                         label = NULL,
                         notes = NULL,
                         booktabs = TRUE,
                         threeparttable = TRUE,
                         align = NULL,
                         col_names = NULL,
                         escape = TRUE,
                         max_rows = NULL,
                         ...) {
    if (!requireNamespace("knitr", quietly = TRUE)) {
        stop("regsen_table() needs the 'knitr' package. ",
             "Install it, or use as.data.frame() and format the result ",
             "with whichever table package you prefer.", call. = FALSE)
    }
    if (!inherits(x, "regsensitivity")) {
        stop("`x` must be a regsensitivity object.", call. = FALSE)
    }

    format <- resolve_table_format(format)

    df <- as.data.frame(x)
    if (nrow(df) == 0) {
        stop("no results to tabulate.", call. = FALSE)
    }

    thinned <- FALSE
    if (!is.null(max_rows) && nrow(df) > max_rows) {
        idx <- unique(round(seq(1, nrow(df), length.out = max_rows)))
        df <- df[idx, , drop = FALSE]
        thinned <- TRUE
    }

    # Alignment must be read off the *numeric* frame: formatting below turns
    # every column into character, which would left-align the numbers.
    if (is.null(align)) align <- default_align(df)

    # Non-finite bounds are meaningful here -- they say the identified set is
    # unbounded -- so render them rather than blanking them out.
    df <- format_table_cells(df, digits = digits, format = format)

    if (is.null(col_names)) col_names <- pretty_colnames(names(df), format)

    notes <- resolve_notes(notes, x, thinned = thinned, max_rows = max_rows)

    kable_args <- list(
        x         = df,
        format    = format,
        digits    = NA,          # already formatted as character
        caption   = caption,
        col.names = col_names,
        align     = align,
        escape    = escape,
        row.names = FALSE
    )
    if (format == "latex") kable_args$booktabs <- booktabs
    kable_args <- c(kable_args, list(...))

    out <- do.call(knitr::kable, kable_args)

    if (length(notes)) {
        out <- attach_notes(out, notes, format = format,
                            threeparttable = threeparttable)
    }
    if (format == "latex" && !is.null(label)) {
        out <- add_latex_label(out, label)
    }
    out
}

# Choose a sensible default format from the knitting context.
resolve_table_format <- function(format) {
    if (!is.null(format)) {
        return(match.arg(format,
                         c("latex", "html", "markdown", "pipe", "simple")))
    }
    fmt <- NULL
    if (requireNamespace("knitr", quietly = TRUE)) {
        fmt <- knitr::opts_knit$get("rmarkdown.pandoc.to")
    }
    if (is.null(fmt)) return("markdown")
    if (fmt %in% c("latex", "beamer")) "latex" else if (fmt == "html") "html"
    else "markdown"
}

# Render numbers at fixed significant digits, keeping infinities legible in
# whichever markup we are emitting.
format_table_cells <- function(df, digits, format) {
    # HTML gets the literal character rather than an &infin; entity: kable's
    # escape=TRUE would turn the leading "&" into "&amp;" and the entity
    # would render as text. \u escapes keep the source ASCII for CRAN.
    inf_pos <- switch(format,
        latex = "$+\\infty$", html = "+\u221e", "+Inf")
    inf_neg <- switch(format,
        latex = "$-\\infty$", html = "\u2212\u221e", "-Inf")

    for (j in seq_along(df)) {
        col <- df[[j]]
        if (!is.numeric(col)) next
        chr <- formatC(col, format = "fg", digits = digits, flag = "#")
        chr <- trimws(chr)
        chr[is.na(col)]           <- ""
        chr[!is.na(col) & col ==  Inf] <- inf_pos
        chr[!is.na(col) & col == -Inf] <- inf_neg
        df[[j]] <- chr
    }
    df
}

# Map internal column names onto something a reader recognises.
pretty_colnames <- function(nms, format) {
    latex <- identical(format, "latex")
    map <- c(
        rxbar     = if (latex) "$\\bar{r}_x$"      else "rxbar",
        rybar     = if (latex) "$\\bar{r}_y$"      else "rybar",
        cbar      = if (latex) "$\\bar{c}$"        else "cbar",
        delta     = if (latex) "$\\delta$"         else "delta",
        r2long    = if (latex) "$R^2_{\\text{long}}$" else "R2(long)",
        maxovb    = "Max OVB",
        bmin      = if (latex) "$\\beta_{\\min}$"  else "Lower",
        bmax      = if (latex) "$\\beta_{\\max}$"  else "Upper",
        breakdown = "Breakdown",
        index     = "Index",
        beta1     = if (latex) "$\\beta_1$" else "beta1",
        beta2     = if (latex) "$\\beta_2$" else "beta2",
        beta3     = if (latex) "$\\beta_3$" else "beta3"
    )
    out <- unname(map[nms])
    out[is.na(out)] <- nms[is.na(out)]
    out
}

default_align <- function(df) {
    paste(vapply(df, function(c) if (is.numeric(c)) "r" else "l",
                 character(1)), collapse = "")
}

# TRUE means "write the note for me": record what a referee needs to judge
# the table -- which analysis, which hypothesis, how many observations.
resolve_notes <- function(notes, x, thinned, max_rows) {
    if (is.null(notes)) return(character(0))
    if (isFALSE(notes))  return(character(0))

    if (isTRUE(notes)) {
        notes <- sprintf(
            "Sensitivity analysis: %s. Outcome: %s. Treatment: %s. N = %s.",
            x$analysis, x$depvar, x$indvar, format(x$n, big.mark = ","))
        hyp <- tryCatch(format_hypothesis(x), error = function(e) NULL)
        if (!is.null(hyp)) {
            notes <- c(notes, sprintf("Hypothesis: %s.", hyp))
        }
    }
    notes <- as.character(notes)
    if (isTRUE(thinned)) {
        notes <- c(notes, sprintf(
            "Table thinned to %d evenly spaced rows of the full sweep.",
            max_rows))
    }
    notes
}

# Append notes in the idiom of the target format.
#
# Everything below works line by line with fixed string matching. Using
# sub()/gsub() here would silently eat the backslashes in the LaTeX we are
# inserting, because backslash is an escape character in a regex
# *replacement* -- \item arrives as "item".
attach_notes <- function(kbl, notes, format, threeparttable) {
    txt <- as.character(kbl)

    if (format == "latex") {
        if (threeparttable) {
            note_block <- c(
                "\\begin{tablenotes}[flushleft]",
                "\\small",
                paste0("\\item ", notes),
                "\\end{tablenotes}")
            lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
            # Prefix match: the emitted line carries the column spec, e.g.
            # "\begin{tabular}[t]{rrrrr}", so it never equals the bare name.
            lines <- insert_before(lines, "\\begin{tabular}",
                                   "\\begin{threeparttable}", prefix = TRUE)
            lines <- insert_after(lines, "\\end{tabular}",
                                  c(note_block, "\\end{threeparttable}"))
            txt <- paste(lines, collapse = "\n")
        } else {
            txt <- paste0(txt, "\n\n",
                          paste0("\\footnotesize ", notes, collapse = "\n\n"))
        }
    } else if (format == "html") {
        txt <- paste0(
            txt, "\n<div class=\"regsen-notes\" style=\"font-size:90%\">\n",
            paste0("<p>", notes, "</p>", collapse = "\n"),
            "\n</div>")
    } else {
        txt <- paste0(txt, "\n\n", paste0("*", notes, "*", collapse = "\n\n"))
    }

    structure(txt, format = format, class = "knitr_kable")
}

add_latex_label <- function(kbl, label) {
    txt   <- as.character(kbl)
    lab   <- sprintf("\\label{tab:%s}", label)
    lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]

    # After the caption if there is one, otherwise straight after the float
    # opens. Either position lets \ref{} resolve to the table number.
    anchor <- if (any(startsWith(lines, "\\caption{"))) "\\caption{" else
                                                        "\\begin{table}"
    lines <- insert_after(lines, anchor, lab, prefix = TRUE)
    structure(paste(lines, collapse = "\n"), format = "latex",
              class = "knitr_kable")
}

# Insert `what` immediately before/after the first line matching `target`.
# `prefix = TRUE` matches on the start of the line rather than the whole of
# it, for anchors such as "\caption{" that carry trailing text.
match_line <- function(lines, target, prefix) {
    hit <- if (prefix) startsWith(trimws(lines), target) else
                       trimws(lines) == target
    which(hit)[1]
}

insert_before <- function(lines, target, what, prefix = FALSE) {
    i <- match_line(lines, target, prefix)
    if (is.na(i)) return(lines)
    append(lines, what, after = i - 1L)
}

insert_after <- function(lines, target, what, prefix = FALSE) {
    i <- match_line(lines, target, prefix)
    if (is.na(i)) return(lines)
    append(lines, what, after = i)
}
