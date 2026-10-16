#!/usr/bin/env bash
# Validate the wordmark assets, then render test documents in every paper
# format with and without the wordmark and check each title block. Needs
# quarto, xelatex, xmllint, rsvg-convert, pdftoppm and ImageMagick's compare.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
assets="$root/_extensions/policyengine/assets"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
ok() { printf 'ok - %s\n' "$1"; }
not_ok() {
  printf 'not ok - %s\n' "$1"
  failures=$((failures + 1))
}
check() {
  local description="$1"
  shift
  if "$@"; then ok "$description"; else not_ok "$description"; fi
}
has() { grep -qF -- "$2" "$1"; }
lacks() { ! grep -qF -- "$2" "$1"; }

# The SVG assets must parse as XML; rsvg-convert and browsers reject a
# comment that contains a double hyphen.
while IFS= read -r svg; do
  check "$svg parses as XML" xmllint --noout "$root/$svg"
done < <(git -C "$root" ls-files '*.svg')

# The committed PDF must still depict the SVG. Rasterize both at the SVG's
# size and count pixels that differ by more than 10%: the two renderers
# disagree on about 0.06% (antialiasing), a blank or mirrored wordmark on
# 10-18%, so 0.5% separates drift from noise.
pdf_matches_svg() {
  local width height differing
  rsvg-convert --background-color=white --output="$work/svg.png" \
    "$assets/policyengine-wordmark.svg" || return 1
  read -r width height < <(identify -format '%w %h\n' "$work/svg.png") || return 1
  pdftoppm -singlefile -png -scale-to-x "$width" -scale-to-y "$height" \
    "$assets/policyengine-wordmark.pdf" "$work/pdf" || return 1
  differing="$({ compare -metric AE -fuzz 10% "$work/svg.png" "$work/pdf.png" null: 2>&1 || true; } | awk '{print $1}')"
  printf '# %s of %d pixels differ\n' "$differing" "$((width * height))"
  awk -v d="$differing" -v n="$((width * height))" 'BEGIN { exit !(d != "" && d / n < 0.005) }'
}
check "policyengine-wordmark.pdf matches the SVG" pdf_matches_svg

project="$work/project"
mkdir -p "$project"
cp -R "$root/_extensions" "$project/"
printf 'project:\n  type: default\n' >"$project/_quarto.yml"

render() {
  local log="$work/$1.log"
  if (cd "$project" && quarto render "$1/paper.qmd" -M keep-tex:true) >"$log" 2>&1; then
    ok "$1 renders"
  else
    not_ok "$1 renders"
    sed 's/^/    /' "$log"
    return 1
  fi
}

wordmark_tex=']{policyengine-wordmark.pdf}'
wordmark_html='<img class="policyengine-wordmark" src="policyengine-wordmark.svg" alt="PolicyEngine">'
theme_affiliation_tex='\color{policyenginemuted} PolicyEngine\par}'
affiliation_html='<span class="affiliation">PolicyEngine</span>'

# The shipped example: wordmark by default, author affiliation kept.
mkdir -p "$project/example"
cp "$root/example/paper.qmd" "$project/example/"
if render example; then
  d="$project/example"
  check "example PDF includes the wordmark" has "$d/paper.tex" "$wordmark_tex"
  check "example PDF exists" test -s "$d/paper.pdf"
  check "example HTML includes the wordmark" has "$d/paper.html" "$wordmark_html"
  check "example HTML wordmark file sits beside the page" test -s "$d/policyengine-wordmark.svg"
  check "example HTML keeps the author affiliation" has "$d/paper.html" "$affiliation_html"
fi

case_document() {
  mkdir -p "$project/$1"
  cat >"$project/$1/paper.qmd"
}

# Without author affiliations, the wordmark replaces the theme byline.
case_document no-affiliation <<'EOF'
---
title: "No affiliation"
author: Ada Example
format:
  policyengine-paper-pdf: default
  policyengine-paper-html: default
---
Body.
EOF
if render no-affiliation; then
  d="$project/no-affiliation"
  check "no-affiliation PDF includes the wordmark" has "$d/paper.tex" "$wordmark_tex"
  check "no-affiliation PDF omits the theme byline" lacks "$d/paper.tex" "$theme_affiliation_tex"
  check "no-affiliation HTML includes the wordmark" has "$d/paper.html" "$wordmark_html"
  check "no-affiliation HTML omits the theme byline" lacks "$d/paper.html" "policyengine-affiliations"
fi

# `wordmark: false` removes it from both formats and restores the byline.
case_document opt-out <<'EOF'
---
title: "Opt out"
author: Ada Example
wordmark: false
format:
  policyengine-paper-pdf: default
  policyengine-paper-html: default
---
Body.
EOF
if render opt-out; then
  d="$project/opt-out"
  check "opt-out PDF omits the wordmark" lacks "$d/paper.tex" "policyengine-wordmark"
  check "opt-out PDF prints the theme byline" has "$d/paper.tex" "$theme_affiliation_tex"
  check "opt-out HTML omits the wordmark" lacks "$d/paper.html" "policyengine-wordmark"
  check "opt-out HTML prints the theme byline" has "$d/paper.html" "$affiliation_html"
fi

# A format-level `wordmark: false` affects only that format.
case_document pdf-opt-out <<'EOF'
---
title: "PDF opt out"
author: Ada Example
format:
  policyengine-paper-pdf:
    wordmark: false
  policyengine-paper-html: default
---
Body.
EOF
if render pdf-opt-out; then
  d="$project/pdf-opt-out"
  check "pdf-opt-out PDF omits the wordmark" lacks "$d/paper.tex" "policyengine-wordmark"
  check "pdf-opt-out HTML includes the wordmark" has "$d/paper.html" "$wordmark_html"
fi

# Self-contained HTML embeds the SVG instead of linking it.
case_document embedded <<'EOF'
---
title: "Embedded"
author: Ada Example
format:
  policyengine-paper-html:
    embed-resources: true
---
Body.
EOF
if render embedded; then
  d="$project/embedded"
  check "embedded HTML inlines the wordmark" has "$d/paper.html" 'class="policyengine-wordmark" src="data:image/svg+xml;base64,'
  check "embedded HTML does not link the wordmark file" lacks "$d/paper.html" 'src="policyengine-wordmark.svg"'
fi

# The base extension's HTML format shares the partials. Its PDF format is not
# rendered here: it already failed before the wordmark, because Quarto
# resolves its policyengine-font-dir to an extension path that pandoc escapes.
case_document base-html <<'EOF'
---
title: "Base HTML"
author: Ada Example
format:
  policyengine-html: default
---
Body.
EOF
if render base-html; then
  check "base-html includes the wordmark" has "$project/base-html/paper.html" "$wordmark_html"
fi

# Projects with an output directory copy the wordmark beside the page.
site="$work/site"
mkdir -p "$site/papers"
cp -R "$root/_extensions" "$site/"
printf 'project:\n  type: website\n  output-dir: _site\n' >"$site/_quarto.yml"
printf -- '---\ntitle: Home\n---\n' >"$site/index.qmd"
printf -- '---\ntitle: "In a website"\nformat: policyengine-paper-html\n---\nBody.\n' >"$site/papers/paper.qmd"
if (cd "$site" && quarto render) >"$work/site.log" 2>&1; then
  ok "website renders"
  check "website output includes the wordmark" has "$site/_site/papers/paper.html" "$wordmark_html"
  check "website output copies the wordmark file" test -s "$site/_site/papers/policyengine-wordmark.svg"
else
  not_ok "website renders"
  sed 's/^/    /' "$work/site.log"
fi

if ((failures > 0)); then
  printf '%d check(s) failed\n' "$failures"
  exit 1
fi
echo "All checks passed"
