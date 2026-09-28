#!/usr/bin/env bash
# Regression tests for preamble composition and the front-matter options.
#
#   ./test.sh
#
# Builds throwaway papers to LaTeX rather than PDF, so the whole suite runs in
# seconds and needs only pandoc. Assertions are on the generated preamble,
# which is where every bug these cover actually lives.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d -t report-builder-tests)"
trap 'rm -rf "$work"' EXIT

pass=0
fail=0

report() {
  if [[ "$1" == pass ]]; then
    pass=$((pass + 1))
    printf '  ok    %s\n' "$2"
  else
    fail=$((fail + 1))
    printf '  FAIL  %s\n' "$2"
    [[ -n "${3:-}" ]] && printf '        %s\n' "$3"
  fi
}

# paper <name> <style> <extra front matter> [body]
paper() {
  local name="$1" extra="$2" body="${3:-Body text.}"
  {
    printf -- '---\ntitle: "T"\nauthor: "A"\ndate: "D"\nlastname: "Surname"\n'
    [[ -n "$extra" ]] && printf '%s\n' "$extra"
    printf -- '---\n\n%s\n' "$body"
  } > "$work/$name.md"
}

# build <name> <style> -> writes $work/<name>.tex, returns pandoc's exit status
build() {
  "$here/build.sh" --no-bib "$work/$1.md" "$2" tex "$work/$1.tex" >/dev/null 2>&1
}

# assert_grep <desc> <file> <pattern> <expected count>
assert_grep() {
  local desc="$1" file="$2" pattern="$3" want="$4"
  local got
  got="$(grep -cE "$pattern" "$file" 2>/dev/null || true)"
  if [[ "$got" == "$want" ]]; then
    report pass "$desc"
  else
    report fail "$desc" "expected $want match(es) of /$pattern/, got $got"
  fi
}

# assert_before <desc> <file> <first pattern> <second pattern>
assert_before() {
  local desc="$1" file="$2" first="$3" second="$4"
  local a b
  a="$(grep -nE "$first" "$file" | head -1 | cut -d: -f1)"
  b="$(grep -nE "$second" "$file" | head -1 | cut -d: -f1)"
  if [[ -n "$a" && -n "$b" && "$a" -lt "$b" ]]; then
    report pass "$desc"
  else
    report fail "$desc" "expected /$first/ (line ${a:-none}) before /$second/ (line ${b:-none})"
  fi
}

echo "preamble composition"

paper hi "header-includes: |
  \\usepackage{soul}"
build hi apa
assert_grep "a paper's header-includes survives" "$work/hi.tex" '\\usepackage\{soul\}' 1
assert_before "style preamble comes before the paper's" "$work/hi.tex" \
  'APA 7 style preamble' '\\usepackage\{soul\}'
assert_before "the paper's entries land before begin{document}" "$work/hi.tex" \
  '\\usepackage\{soul\}' '\\begin\{document\}'
assert_grep "internal plumbing keys do not leak" "$work/hi.tex" 'rb-style-preamble|rb-extra-preamble' 0

echo "pagenumber"

paper pn_default ""
build pn_default apa
assert_grep "defaults to the header" "$work/pn_default.tex" '\\fancyhead\[R\]\{\\thepage\}' 1
assert_grep "defines no switch by default" "$work/pn_default.tex" '\\def\\rbPageNumberBottom' 0

paper pn_top "pagenumber: topright"
build pn_top apa
assert_grep "topright is explicit but equivalent" "$work/pn_top.tex" '\\def\\rbPageNumberBottom' 0

paper pn_bottom "pagenumber: bottomright"
build pn_bottom apa
assert_grep "bottomright defines the switch" "$work/pn_bottom.tex" '\\def\\rbPageNumberBottom\{\}' 1

paper pn_bad "pagenumber: sideways"
if build pn_bad apa; then
  report fail "an unknown value fails the build"
else
  report pass "an unknown value fails the build"
fi

echo "titlepage"

paper tp_default ""
build tp_default apa
assert_grep "renders by default" "$work/tp_default.tex" '\\def\\rbNoTitlePage' 0
assert_grep "maketitle is called by default" "$work/tp_default.tex" '^\\maketitle$' 1

paper tp_off "titlepage: false"
build tp_off apa
assert_grep "false defines the switch" "$work/tp_off.tex" '\\def\\rbNoTitlePage\{\}' 1
assert_grep "false blanks maketitle" "$work/tp_off.tex" '\\ifdefined\\rbNoTitlePage\\renewcommand\{\\maketitle\}\{\}' 1

echo "mla"

paper mla_ok "" "Writer heading

# Title

Body text."
build mla_ok mla
assert_grep "the surname reaches the preamble" "$work/mla_ok.tex" \
  '\\renewcommand\{\\mlaSurname\}\{Surname\}' 1
assert_before "mlaSurname is declared before it is renewed" "$work/mla_ok.tex" \
  '\\providecommand\{\\mlaSurname\}' '\\renewcommand\{\\mlaSurname\}'

printf -- '---\ntitle: "T"\n---\n\nBody.\n' > "$work/mla_bad.md"
if build mla_bad mla; then
  report fail "a missing lastname fails the build"
else
  report pass "a missing lastname fails the build"
fi

echo "styles still build"

paper smoke_apa ""
build smoke_apa apa && report pass "apa builds" || report fail "apa builds"
paper smoke_mla "" "Heading

# Title

Body."
build smoke_mla mla && report pass "mla builds" || report fail "mla builds"

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
