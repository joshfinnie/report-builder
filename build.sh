#!/usr/bin/env bash
# Build an APA-formatted PDF (or .docx) from a markdown paper.
#
#   ./build.sh paper.md            -> paper.pdf
#   ./build.sh paper.md docx       -> paper.docx
#   ./build.sh paper.md pdf out.pdf
#
# Looks for references.bib next to the paper, falling back to the repo's copy.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

src="${1:-}"
fmt="${2:-pdf}"
if [[ -z "$src" ]]; then
  echo "usage: $(basename "$0") <paper.md> [pdf|docx] [output]" >&2
  exit 1
fi
[[ -f "$src" ]] || { echo "no such file: $src" >&2; exit 1; }

src_dir="$(cd "$(dirname "$src")" && pwd)"
out="${3:-$src_dir/$(basename "${src%.*}").$fmt}"

bib="$src_dir/references.bib"
[[ -f "$bib" ]] || bib="$here/references.bib"

args=(
  "$src"
  --from=markdown-implicit_figures
  --lua-filter="$here/apa.lua"
  --citeproc
  --csl="$here/apa.csl"
  --include-in-header="$here/apa.tex"
  --resource-path="$src_dir:$here"
  --output="$out"
)
[[ -f "$bib" ]] && args+=(--bibliography="$bib")

case "$fmt" in
  pdf)  args+=(--pdf-engine=tectonic) ;;
  docx) : ;;
  *)    echo "unknown format: $fmt (use pdf or docx)" >&2; exit 1 ;;
esac

pandoc "${args[@]}"
echo "wrote $out"
