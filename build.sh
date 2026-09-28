#!/usr/bin/env bash
# Build an APA- or MLA-formatted PDF (or .docx) from a markdown paper.
#
#   ./build.sh paper.md                -> paper.pdf, APA
#   ./build.sh paper.md mla            -> paper.pdf, MLA
#   ./build.sh paper.md mla docx       -> paper.docx, MLA
#   ./build.sh paper.md apa pdf out.pdf
#   ./build.sh --bib custom.bib paper.md
#   ./build.sh --no-bib paper.md
#   ./build.sh --font-family Georgia --font-size 11 paper.md
#
# Looks for <paper>.bib next to the paper, falling back to references.bib.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

usage() {
  cat <<'USAGE'
usage: build.sh [options] <paper.md> [apa|mla] [pdf|docx] [output]

options:
  -b, --bib <file>       bibliography to cite from
      --no-bib           build without a bibliography
      --font-family <n>  override the paper's mainfont (PDF only)
      --font-size <n>    override the paper's fontsize, e.g. 11 or 11pt (PDF only)
  -h, --help             show this message

Defaults to apa and pdf. Font flags override the paper's front matter.
USAGE
}

bib_arg=""
no_bib=false
font_family=""
font_size=""
positional=()

require_arg() {
  if [[ -z "${2:-}" ]]; then
    echo "error: $1 requires an argument" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bib|--bibliography|-b)
      require_arg "$1" "${2:-}"
      bib_arg="$2"
      shift 2
      ;;
    --bib=*|--bibliography=*|-b=*)
      bib_arg="${1#*=}"
      shift
      ;;
    --no-bib|--no-bibliography)
      no_bib=true
      shift
      ;;
    --font-family)
      require_arg "$1" "${2:-}"
      font_family="$2"
      shift 2
      ;;
    --font-family=*)
      font_family="${1#*=}"
      shift
      ;;
    --font-size)
      require_arg "$1" "${2:-}"
      font_size="$2"
      shift 2
      ;;
    --font-size=*)
      font_size="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        positional+=("$1")
        shift
      done
      break
      ;;
    -*)
      echo "unknown option: $1" >&2
      exit 1
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done

if [[ "$no_bib" == true && -n "$bib_arg" ]]; then
  echo "error: cannot specify both --bib and --no-bib" >&2
  exit 1
fi

# A bare number is a point size: --font-size 11 means 11pt.
if [[ -n "$font_size" ]]; then
  if [[ "$font_size" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    font_size="${font_size}pt"
  elif [[ ! "$font_size" =~ ^[0-9]+(\.[0-9]+)?(pt|mm|cm|in|em|ex|bp|dd|pc|sp)$ ]]; then
    echo "error: --font-size expects a size like 11 or 11pt, got: $font_size" >&2
    exit 1
  fi
fi

src="${positional[0]:-}"
style="${positional[1]:-apa}"
fmt="${positional[2]:-pdf}"
out="${positional[3]:-}"

if [[ -z "$src" ]]; then
  usage >&2
  exit 1
fi
[[ -f "$src" ]] || { echo "no such file: $src" >&2; exit 1; }

case "$style" in
  apa|mla) ;;
  *) echo "unknown style: $style (use apa or mla)" >&2; exit 1 ;;
esac

src_dir="$(cd "$(dirname "$src")" && pwd)"
[[ -z "$out" ]] && out="$src_dir/$(basename "${src%.*}").$fmt"

bib=""
if [[ "$no_bib" == true ]]; then
  bib=""
elif [[ -n "$bib_arg" ]]; then
  [[ -f "$bib_arg" ]] || { echo "no such bibliography file: $bib_arg" >&2; exit 1; }
  bib="$(cd "$(dirname "$bib_arg")" && pwd)/$(basename "$bib_arg")"
else
  paper_bib="$src_dir/$(basename "${src%.*}").bib"
  if [[ -f "$paper_bib" ]]; then
    bib="$paper_bib"
  elif [[ -f "$src_dir/references.bib" ]]; then
    bib="$src_dir/references.bib"
  else
    echo "no bibliography found for $src (looked for $paper_bib and $src_dir/references.bib); specify --bib <file> or --no-bib" >&2
    exit 1
  fi
fi

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
[[ -n "$bib" ]] && args+=(--bibliography="$bib")

# Command-line metadata overrides the paper's front matter.
[[ -n "$font_family" ]] && args+=(--metadata=mainfont:"$font_family")
[[ -n "$font_size" ]] && args+=(--metadata=fontsize:"$font_size")

case "$fmt" in
  pdf)  args+=(--pdf-engine=tectonic) ;;
  docx)
    if [[ -n "$font_family" || -n "$font_size" ]]; then
      echo "warning: --font-family/--font-size affect PDF output only; ignored for docx" >&2
    fi
    ;;
  *)    echo "unknown format: $fmt (use pdf or docx)" >&2; exit 1 ;;
esac

pandoc "${args[@]}"
echo "wrote $out"
