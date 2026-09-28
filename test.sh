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

paper tp_student "titlepage: student"
build tp_student apa
assert_grep "student is explicit but equivalent" "$work/tp_student.tex" '\\def\\rb' 0

paper tp_true "titlepage: true"
build tp_true apa
assert_grep "true is a synonym for student" "$work/tp_true.tex" '\\def\\rb' 0

paper tp_off "titlepage: false"
build tp_off apa
assert_grep "false defines the switch" "$work/tp_off.tex" '\\def\\rbNoTitlePage\{\}' 1
assert_grep "false blanks maketitle" "$work/tp_off.tex" '\\ifdefined\\rbNoTitlePage\\renewcommand\{\\maketitle\}\{\}' 1

paper tp_pro "titlepage: professional"
build tp_pro apa
assert_grep "professional defines the switch" "$work/tp_pro.tex" '\\def\\rbProfessionalTitlePage\{\}' 1
assert_grep "professional sets a running head" "$work/tp_pro.tex" '\\fancyhead\[L\]\{\\rbShortTitle\}' 1
assert_grep "the short title falls back to the title" "$work/tp_pro.tex" \
  '\\def\\rbShortTitle\{T\}' 1

paper tp_short "titlepage: professional
shorttitle: \"A Shorter One\""
build tp_short apa
assert_grep "shorttitle wins and is capitalised" "$work/tp_short.tex" \
  '\\def\\rbShortTitle\{A SHORTER ONE\}' 1

paper tp_long "titlepage: professional
shorttitle: \"$(printf 'x%.0s' {1..70})\""
build tp_long apa
assert_grep "a long short title is cut to 50 characters" "$work/tp_long.tex" \
  "\\\\def\\\\rbShortTitle\\{X{50}\\}" 1

paper tp_bad "titlepage: sideways"
if build tp_bad apa; then
  report fail "an unknown titlepage value fails the build"
else
  report pass "an unknown titlepage value fails the build"
fi

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

# The assertions above stop at the generated LaTeX, which cannot catch a
# preamble that is well formed but does not compile, such as a macro used by
# one style but declared only by another. These render for real.
echo "pdf smoke (runs tectonic, slower)"

render() {
  "$here/build.sh" --no-bib "$work/$1.md" "$2" pdf "$work/$1.pdf" >/dev/null 2>&1
}

mla_body="Heading

# Title

Body."

for combo in "apa:" "apa:titlepage: professional" "apa:titlepage: false" \
             "apa:pagenumber: bottomright"; do
  style="${combo%%:*}"
  extra="${combo#*:}"
  name="pdf_apa_$(echo "${extra:-default}" | tr -c 'a-z0-9' '_')"
  paper "$name" "$extra"
  render "$name" "$style" \
    && report pass "apa renders with [${extra:-defaults}]" \
    || report fail "apa renders with [${extra:-defaults}]"
done

for extra in "" "titlepage: professional" "pagenumber: bottomright"; do
  name="pdf_mla_$(echo "${extra:-default}" | tr -c 'a-z0-9' '_')"
  paper "$name" "$extra" "$mla_body"
  render "$name" mla \
    && report pass "mla renders with [${extra:-defaults}]" \
    || report fail "mla renders with [${extra:-defaults}]"
done

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
