#!/bin/sh
# Build the SVG copies of the paper's schematic figures used by the vignettes.
#
# The TikZ code is NOT duplicated here: it is extracted from paper.Rnw, which
# is the single source for both the paper and the vignettes. Each block there
# is delimited by "%% >>> schematic: <name>" / "%% <<< schematic" markers, and
# the shared \tikzset by "%% >>> schematic-style" / "%% <<< schematic-style".
# Re-run this after editing any marked block.
#
# Requires: pdflatex and gs (Ghostscript), both of which the paper build
# already needs. Output is PNG at 300 dpi rather than SVG: dvisvgm can only
# vectorize TikZ output when it is built with PostScript (Ghostscript) support
# or when mutool is present for its --pdf mode, and neither is guaranteed. The
# background is painted white rather than left transparent so the figures stay
# legible under the pkgdown dark-mode switch.
#
# Usage: tools/make-schematics.sh

set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
src="$root/paper-jss/paper.Rnw"
out="$root/vignettes/figures"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

[ -f "$src" ] || { echo "missing $src" >&2; exit 1; }
mkdir -p "$out"

extract() { # extract <start-marker> <end-marker>
    awk -v s="$1" -v e="$2" '
        index($0, s) { on = 1; next }
        index($0, e) { on = 0 }
        on           { print }
    ' "$src"
}

# The macros the schematics use, mirrored from the paper preamble. Kept minimal
# on purpose: if a block starts using a macro that is not listed here the build
# fails loudly rather than rendering a wrong figure.
macros='
\newcommand{\blong}{\beta_{\mathrm{long}}}
\newcommand{\rxbar}{\ensuremath{\overline{r}_X}}
\newcommand{\rybar}{\ensuremath{\overline{r}_Y}}
\newcommand{\cbar}{\ensuremath{\overline{c}}}
\newcommand{\clow}{\ensuremath{\underline{c}}}
\newcommand{\Var}{\operatorname{var}}
\newcommand{\code}[1]{\texttt{#1}}
'

style=$(extract '>>> schematic-style' '<<< schematic-style')
[ -n "$style" ] || { echo "no schematic-style block found in paper.Rnw" >&2; exit 1; }

for name in model covariates sensparams; do
    body=$(extract ">>> schematic: $name" '<<< schematic')
    if [ -z "$body" ]; then
        echo "no schematic block '$name' found in paper.Rnw" >&2
        exit 1
    fi

    cat > "$work/$name.tex" <<EOF
\\documentclass[border=4pt]{standalone}
\\usepackage{amsmath,amssymb,bm}
\\usepackage{tikz}
\\usetikzlibrary{positioning,arrows.meta,decorations.pathreplacing,calc}
$macros
$style
\\begin{document}
$body
\\end{document}
EOF

    (cd "$work" && pdflatex -interaction=nonstopmode -halt-on-error "$name.tex" >/dev/null)
    gs -dNOPAUSE -dBATCH -dQUIET -sDEVICE=png16m -r300 \
       -dTextAlphaBits=4 -dGraphicsAlphaBits=4 \
       -sOutputFile="$out/$name.png" "$work/$name.pdf"
    echo "wrote vignettes/figures/$name.png"
done
