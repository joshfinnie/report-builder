#!/usr/bin/env bash
# Build an APA- or MLA-formatted PDF (or .docx) from a markdown paper.
#
#   ./build.sh paper.md                -> paper.pdf, APA
#   ./build.sh paper.md mla            -> paper.pdf, MLA
#   ./build.sh paper.md mla docx       -> paper.docx, MLA
#   ./build.sh paper.md apa pdf out.pdf
#
# Looks for references.bib next to the paper, falling back to the repo's copy.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

src="${1:-}"
style="${2:-apa}"
fmt="${3:-pdf}"
if [[ -z "$src" ]]; then
  echo "usage: $(basename "$0") <paper.md> [apa|mla] [pdf|docx] [output]" >&2
  exit 1
fi
[[ -f "$src" ]] || { echo "no such file: $src" >&2; exit 1; }

case "$style" in
  apa|mla) ;;
  *) echo "unknown style: $style (use apa or mla)" >&2; exit 1 ;;
esac

src_dir="$(cd "$(dirname "$src")" && pwd)"
out="${4:-$src_dir/$(basename "${src%.*}").$fmt}"

bib="$src_dir/references.bib"
[[ -f "$bib" ]] || bib="$here/references.bib"

args=(
  "$src"
  --from=markdown-implicit_figures
  --lua-filter="$here/$style.lua"
  --citeproc
  --csl="$here/$style.csl"
  --include-in-header="$here/$style.tex"
  --resource-path="$src_dir:$here"
  --output="$out"
)
[[ -f "$bib" ]] && args+=(--bibliography="$bib")

surname_file=""
if [[ "$style" == mla ]]; then
  lastname="$(awk '/^---$/{n++; next} n==1 && /^lastname:/{print; exit}' "$src" \
    | sed -E 's/^lastname:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
  [[ -n "$lastname" ]] || { echo "add 'lastname: \"Surname\"' to $src's front matter for the MLA header" >&2; exit 1; }
  surname_file="$(mktemp -t report-builder-mla-surname)"
  trap 'rm -f "$surname_file"' EXIT
  printf '\\renewcommand{\\mlaSurname}{%s}\n' "$lastname" > "$surname_file"
  args+=(--include-in-header="$surname_file")
fi

case "$fmt" in
  pdf)  args+=(--pdf-engine=tectonic) ;;
  docx) : ;;
  *)    echo "unknown format: $fmt (use pdf or docx)" >&2; exit 1 ;;
esac

pandoc "${args[@]}"
echo "wrote $out"
