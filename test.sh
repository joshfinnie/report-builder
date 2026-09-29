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
skip=0

report() {
  if [[ "$1" == skip ]]; then
    skip=$((skip + 1))
    printf '  skip  %s\n' "$2"
    [[ -n "${3:-}" ]] && printf '        %s\n' "$3"
    return
  fi
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

render() {
  "$here/build.sh" --no-bib "$work/$1.md" "$2" pdf "$work/$1.pdf" >/dev/null 2>&1
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

echo "fonts"

# Pandoc writes the size on its own line inside \documentclass[ ... ]{article}.
class_size() {
  sed -n '/documentclass\[/,/]{article}/p' "$1" | grep -oE '[0-9]+pt' | head -1
}
main_font() {
  grep -o 'setmainfont\[\]{[^}]*}' "$1" | sed 's/.*{//;s/}//'
}

# APA 7 approves each font at a particular size, so a preset sets both.
assert_font() {
  local desc="$1" file="$2" want_family="$3" want_size="$4"
  local got_family got_size
  got_family="$(main_font "$file")"
  got_size="$(class_size "$file")"
  if [[ "$got_family" == "$want_family" && "$got_size" == "$want_size" ]]; then
    report pass "$desc"
  else
    report fail "$desc" "got [${got_family:-none} / $got_size], wanted [${want_family:-none} / $want_size]"
  fi
}

font_build() {
  "$here/build.sh" --no-bib "${@:2}" "$work/font_base.md" apa tex "$work/$1.tex" >/dev/null 2>&1
}

# A paper naming its own font, as every paper written before presets does.
paper font_base 'mainfont: "Times New Roman"
fontsize: 12pt'
build font_base apa
assert_font "a paper's own mainfont is left alone" "$work/font_base.tex" "Times New Roman" "12pt"

for pair in "arial:Arial:11pt" "aptos:Aptos:12pt" "calibri:Calibri:11pt" \
            "georgia:Georgia:11pt" "times:Times New Roman:12pt" \
            "lucida-sans:Lucida Sans Unicode:10pt"; do
  name="${pair%%:*}"; rest="${pair#*:}"
  family="${rest%:*}"; size="${rest##*:}"
  font_build "font_$name" --font "$name"
  assert_font "--font $name gives $family at $size" "$work/font_$name.tex" "$family" "$size"
done

# Computer Modern is not a system font; leaving mainfont unset is what picks it.
font_build font_cm --font computer-modern
assert_font "--font computer-modern leaves mainfont unset" "$work/font_cm.tex" "" "10pt"

# A flag must beat the paper's own front matter. That is why build.sh routes
# these through preamble.lua instead of passing them straight to pandoc, which
# would apply them before the paper's metadata rather than after.
font_build font_over --font arial
assert_font "--font overrides the paper's mainfont" "$work/font_over.tex" "Arial" "11pt"
font_build font_size --font arial --font-size 14
assert_font "--font-size beats the preset's size" "$work/font_size.tex" "Arial" "14pt"
font_build font_fam --font arial --font-family Optima
assert_font "--font-family beats the preset's family" "$work/font_fam.tex" "Optima" "11pt"

# In front matter a preset only fills what the paper left unset.
paper font_fm 'font: georgia'
build font_fm apa
assert_font "front matter font: fills family and size" "$work/font_fm.tex" "Georgia" "11pt"

paper font_both 'font: georgia
mainfont: "Optima"'
build font_both apa
assert_font "an explicit mainfont wins over font:" "$work/font_both.tex" "Optima" "11pt"

if font_build font_bad --font helvetica; then
  report fail "an unapproved font name fails the build"
else
  report pass "an unapproved font name fails the build"
fi

echo "tables"

table_rows="| Iterations | Correct route |
|---|---|
| 50 | 65/200 |
| 100 | 148/200 |
| 200 | 199/200 |
| 1,000 | 200/200 |"

paper tbl_bare "" "Body.

$table_rows"
build tbl_bare apa
# 1 header row + 4 body rows + 3 rules, and no label above it.
assert_grep "an unlabelled table reserves its own height" "$work/tbl_bare.tex" \
  '\\rbTableNeed\{8\}\{0\}' 1

paper tbl_label "" "Body.

**Table 1**

*A Short Table*

$table_rows

*Note.* Something."
build tbl_label apa
assert_grep "a labelled table reserves the label and title too" "$work/tbl_label.tex" \
  '\\rbTableNeed\{8\}\{2\}' 1

# The macro is defined once in the preamble; every other hit is a use.
uses="$(grep -o '\\rbTableNeed{[0-9]' "$work/tbl_label.tex" | wc -l | tr -d ' ')"
if [[ "$uses" == "1" ]]; then
  report pass "a labelled table reserves space exactly once"
else
  report fail "a labelled table reserves space exactly once" "got $uses reservations"
fi

paper tbl_mla "" "Heading

# Title

**Table 1**

A Short Table

$table_rows"
build tbl_mla mla
assert_grep "mla reserves the same way" "$work/tbl_mla.tex" '\\rbTableNeed\{8\}\{2\}' 1

# A table taller than a page has to stay breakable, or its rows fall off the
# end. This one is far longer than a page and must still render.
long_rows="| N | Value |
|---|---|"
for n in $(seq 1 60); do
  long_rows="$long_rows
| $n | row $n |"
done
paper tbl_long "" "Body.

$long_rows"
render tbl_long apa \
  && report pass "a table longer than a page still renders" \
  || report fail "a table longer than a page still renders"

echo "code blocks"

fence='```'
code_body="Prose above.

${fence}python
import numpy as np
def f(a_very_long_parameter_name, another_long_one, third_one, fourth_one, fifth=0.75):
    return np.zeros([9, 9])
${fence}"

paper code_apa "" "$code_body"
build code_apa apa
assert_grep "fvextra is loaded" "$work/code_apa.tex" '\\usepackage\{fvextra\}' 1
# Both the highlighted and the plain verbatim environment wrap.
assert_grep "long lines are set to wrap" "$work/code_apa.tex" 'breaklines' 2
assert_grep "the shaded panel has a colour" "$work/code_apa.tex" \
  '\\definecolor\{shadecolor\}' 1

render code_apa apa \
  && report pass "apa renders a code block" \
  || report fail "apa renders a code block"

paper code_mla "" "Heading

# Title

$code_body"
render code_mla mla \
  && report pass "mla renders a code block" \
  || report fail "mla renders a code block"

# Pandoc defines Shaded only when the document has highlighted code, so a paper
# with none at all must not trip the redefinition.
paper code_none "" "Prose only, no code anywhere."
render code_none apa \
  && report pass "apa renders with no code block at all" \
  || report fail "apa renders with no code block at all"
paper code_none_mla "" "Heading

# Title

Prose only."
render code_none_mla mla \
  && report pass "mla renders with no code block at all" \
  || report fail "mla renders with no code block at all"

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

# Rendered-geometry checks.
#
# Everything above asserts the mechanism: that the right macro, option or
# package reaches the preamble. None of it asserts the outcome on the page, and
# the two bugs these cover were both silent. A code line running clean off the
# paper produces no Overfull warning at all, and a table splitting across pages
# is perfectly valid LaTeX. Both were found by measuring a rendered PDF.
#
# These need poppler for pdftotext. Without it they are skipped, so the suite
# still runs on pandoc and tectonic alone.
echo "rendered output"

# How many pages carry a line matching a pattern. longtable repeats a table's
# header row on every continuation page, so more than one page means it split.
pages_matching() {
  pdftotext -layout "$1" - | awk -v RS='\f' -v pat="$2" '
    { n = split($0, L, "\n"); for (i = 1; i <= n; i++) if (L[i] ~ pat) { hit++; break } }
    END { print hit + 0 }'
}

# The right-most point any word reaches, in PDF points.
max_right_edge() {
  pdftotext -bbox "$1" - 2>/dev/null \
    | grep -o 'xMax="[0-9.]*"' | grep -o '[0-9.]*' | sort -g | tail -1
}

if ! command -v pdftotext >/dev/null 2>&1; then
  report skip "a short table near a page break stays whole" "pdftotext not installed"
  report skip "a long table still splits and repeats its header" "pdftotext not installed"
  report skip "a long code line stays inside the right margin" "pdftotext not installed"
  report skip "ordinary prose stays inside the right margin" "pdftotext not installed"
else
  # Letter paper is 612pt wide; a 1in margin puts the text edge at 540pt.
  # A point of slack absorbs the rules booktabs draws to the column edge.
  edge=541

  short_rows="| Iterations | Correct route | Did not terminate |
|---|---|---|"
  for n in 1 2 3 4 5 6 7 8; do
    short_rows="$short_rows
| $n | $n/200 | ok |"
  done

  # \vspace leaves room for the header and a couple of rows but not the whole
  # table, which is what makes this a real test: without a reservation the
  # table starts on this page and spills onto the next. Push much further and
  # the \vspace itself overflows, so the table starts on a fresh page and
  # would pass no matter what. The splitting window here is 7.0in to 7.5in.
  #
  # The table is unlabelled on purpose. That is the case that used to reserve
  # no space at all, and the one that showed up in a real paper.
  paper geo_split "geometry: margin=1in" "Body text.

\`\`\`{=latex}
\\vspace*{7.25in}
\`\`\`

$short_rows"
  if render geo_split apa; then
    hit="$(pages_matching "$work/geo_split.pdf" '^[[:space:]]*Iterations')"
    if [[ "$hit" == "1" ]]; then
      report pass "a short table near a page break stays whole"
    else
      report fail "a short table near a page break stays whole" \
        "its header row appears on $hit pages, so the table split"
    fi
  else
    report fail "a short table near a page break stays whole" "build failed"
  fi

  # The converse: a table too tall for a page must still break, or its rows
  # fall off the end. longtable repeats the header, which is what we look for.
  long_rows="| Iterations | Correct route |
|---|---|"
  for n in $(seq 1 60); do
    long_rows="$long_rows
| $n | $n/200 |"
  done
  paper geo_long "geometry: margin=1in" "Body text.

$long_rows"
  if render geo_long apa; then
    hit="$(pages_matching "$work/geo_long.pdf" '^[[:space:]]*Iterations')"
    if [[ "$hit" -gt 1 ]]; then
      report pass "a long table still splits and repeats its header"
    else
      report fail "a long table still splits and repeats its header" \
        "its header row appears on $hit page(s); rows may have been dropped"
    fi
  else
    report fail "a long table still splits and repeats its header" "build failed"
  fi

  fence='```'
  paper geo_code "geometry: margin=1in" "Body text.

${fence}python
TD = rewards_new[current_state, next_state] + gamma * Q[next_state, np.argmax(Q[next_state,])] - Q[current_state, next_state]
${fence}"
  if render geo_code apa; then
    got="$(max_right_edge "$work/geo_code.pdf")"
    if awk -v g="$got" -v e="$edge" 'BEGIN { exit !(g <= e) }'; then
      report pass "a long code line stays inside the right margin"
    else
      report fail "a long code line stays inside the right margin" \
        "text reaches ${got}pt, past the ${edge}pt margin"
    fi
  else
    report fail "a long code line stays inside the right margin" "build failed"
  fi

  paper geo_prose "geometry: margin=1in" "Ordinary prose with no code and no tables at all, long enough to wrap across several lines of the text block so the measurement means something."
  if render geo_prose apa; then
    got="$(max_right_edge "$work/geo_prose.pdf")"
    if awk -v g="$got" -v e="$edge" 'BEGIN { exit !(g <= e) }'; then
      report pass "ordinary prose stays inside the right margin"
    else
      report fail "ordinary prose stays inside the right margin" \
        "text reaches ${got}pt, past the ${edge}pt margin"
    fi
  else
    report fail "ordinary prose stays inside the right margin" "build failed"
  fi
fi


echo
if [[ "$skip" -gt 0 ]]; then
  printf '%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
else
  printf '%d passed, %d failed\n' "$pass" "$fail"
fi
[[ "$fail" -eq 0 ]]
