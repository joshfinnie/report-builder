# report-builder

Build APA 7 or MLA 9 formatted PDFs from plain markdown with pandoc, tectonic and a
BibTeX bibliography. Write the document, run one command, get a correctly formatted PDF.

## Setup

```sh
brew install pandoc tectonic
brew install poppler          # optional, for the rendered-output tests
```

Run `./test.sh` to check a change. Poppler is only needed for the tests that
measure a rendered PDF; without it those are reported as skipped and the rest
still run.

## Use

```sh
cp _template.md ~/docs/paper.md            # start an APA paper
cp _template_mla.md ~/docs/essay.md        # ...or an MLA paper
cp references.bib ~/docs/                  # its bibliography
./build.sh ~/docs/paper.md                 # -> paper.pdf, APA
./build.sh ~/docs/essay.md mla             # -> essay.pdf, MLA
./build.sh ~/docs/essay.md mla docx        # -> essay.docx, MLA
./build.sh --font-size 11 ~/docs/paper.md  # -> paper.pdf, 11pt
```

```
build.sh [options] <paper.md> [apa|mla] [pdf|docx|tex] [output]

  -b, --bib <file>       bibliography to cite from
      --no-bib           build without a bibliography
      --font <name>      an APA 7 approved font, setting family and size:
                         arial, aptos, calibri, computer-modern, georgia,
                         lucida-sans, times (PDF only)
      --font-family <n>  override just the family (PDF only)
      --font-size <n>    override just the size, e.g. 11 or 11pt (PDF only)
  -h, --help             show this message
```

Style defaults to `apa` and format to `pdf`. The `tex` format writes out the LaTeX
pandoc generates instead of rendering it, which is the quickest way to see what the
preamble actually ended up as. For the bibliography, it checks:

1. A file specified via `-b` / `--bib <file>`
2. `<paper>.bib` next to the paper (matching the markdown file's basename)
3. `references.bib` next to the paper

If no bibliography is found, the build exits with an error unless `--no-bib` is passed.

## Fonts

APA 7 approves six fonts, each at a particular size, and pairs the two: Georgia is
approved at 11pt, not at 12pt. Pick one by name and get both.

| `font:` | Family | Size |
|---|---|---|
| `times` | Times New Roman | 12pt |
| `georgia` | Georgia | 11pt |
| `computer-modern` | LaTeX's own (Latin Modern) | 10pt |
| `calibri` | Calibri | 11pt |
| `arial` | Arial | 11pt |
| `aptos` | Aptos | 12pt |
| `lucida-sans` | Lucida Sans Unicode | 10pt |

The first three are serif, the rest sans serif. Both templates ship with
`font: times`.

```yaml
---
font: georgia
---
```

```sh
./build.sh --font georgia ~/docs/essay.md mla
```

`--font` overrides whatever the paper asks for. To change one half, `--font-family`
and `--font-size` override the family or the size on their own, and beat `--font`:

```sh
./build.sh --font arial --font-size 14 ~/docs/paper.md
```

A bare number is read as points, so `--font-size 11` and `--font-size 11pt` are the
same. Flags apply to that build only and leave the file untouched. In front matter,
`font:` fills in only what the paper has not set itself, so an explicit `mainfont:`
or `fontsize:` still wins.

Three limits are worth knowing. The options apply to PDF output only; `.docx` takes
its formatting from a Word reference document, so the build warns and ignores them
there. `mainfont` is a XeLaTeX/LuaLaTeX feature, and builds run through tectonic,
which is XeTeX, so this works, but a family would silently do nothing under
pdflatex. And the font has to be installed and registered with the operating
system: Calibri, Aptos and Lucida Sans Unicode do not ship with macOS. A missing
one fails the build with `Package fontspec Error: The font "X" cannot be found.`

## Front matter options

Beyond the usual pandoc fields, a paper can set these to override the style locally.
Both default to what APA and MLA call for, so leaving them out changes nothing.

| Field | Default | Effect |
|---|---|---|
| `pagenumber` | `topright` | `bottomright` moves the page number into the footer |
| `titlepage` | `student` | `professional` swaps in the professional title page; `false` suppresses it entirely |
| `shorttitle` | the title | The running head the professional title page carries, capitalised and cut to 50 characters |

```yaml
---
title: "Title of the Paper"
pagenumber: bottomright
titlepage: professional
shorttitle: "Short Running Head"
---
```

APA 7 defines two title pages and this builds either. The student format is the
default: title, then an author block of author, affiliation, course and instructor,
then the due date. The professional format drops the due date and adds a running head.
Which lines the author block carries is up to the paper, since it is just the `author`
field. `titlepage: true` is a synonym for `student`.

For anything these do not cover, a paper's own `header-includes` is spliced into the
preamble after the style file, so it wins:

```yaml
---
header-includes: |
  \fancyhf{}
  \fancyfoot[C]{\thepage}
---
```

This is the supported way to deviate from a style. Editing `apa.tex` or `mla.tex` to
suit one paper is not: those files are shared by every paper you build, and APA
defaults are meant to stay APA defaults.

## What you write

Ordinary markdown. Citations use pandoc keys from the `.bib`. In APA, `[@key]` renders
as (Author, Year) and `@key` renders as Author (Year); in MLA, `[@key]` renders as
(Author page) and `@key` renders as Author (page). The reference list goes wherever
you put

```markdown
## References     <!-- "## Works Cited" in MLA -->

::: {#refs}
:::
```

### APA tables and figures

Label, italic title, then the content:

```markdown
**Table 1**

*Title of the Table in Title Case*

| Model | Accuracy |
|--------------------|--------|
| A | 0.8186 |

*Note.* Anything the columns do not say for themselves.
```

```markdown
**Figure A1**

*Title of the Figure in Title Case*

![](figures/example.png){width=100%}
```

### MLA tables and figures

A table's label and (plain, unitalicized) title still go above it, but a figure's
"Fig. N." caption goes below the image instead of above it:

```markdown
**Table 1**

Title of the Table in Title Case

| Model | Accuracy |
|--------------------|--------|
| A | 0.8186 |

Source: Anything the columns do not say for themselves, or drop this line entirely.
```

```markdown
![](figures/example.png){width=100%}

**Fig. 1.** Caption text describing the figure.
```

MLA has no title page. The writer's heading that MLA 9 specifies (name, instructor,
course, date) is the
first paragraph of the document, and the title is a level-1 heading
(`# Title of the Paper`) right after it. `mla.lua` formats both automatically: the
heading flush left, the title centered and unstyled. The paper's front matter also
needs a `lastname:` field for the "Lastname #" running head MLA requires on every page;
`mla.lua` reads it and defines the running head from it, and stops the build with a
clear message if the field is missing.

## What is handled for you

`apa.lua`/`mla.lua` (pandoc filters) and `apa.tex`/`mla.tex` (LaTeX preambles) apply
the style rules that are tedious by hand.

Shared:

- Table bodies are set small and single-spaced, which both styles allow, while the
  label, title and note/source line stay double-spaced.
- Space is reserved before a table for the whole block: its label, its title and
  every row. A table that fits on a page is never split across one, whether or not
  it carries a label. A table taller than a page still breaks, and its header row
  repeats on each continuation, which is what both styles ask for.
- A figure's label, title/caption and image are wrapped together so a page break
  cannot separate them.
- References/Works Cited and each appendix start on a new page.
- URLs break only after a slash, so `https://` never splits after the colon.
- Code blocks wrap instead of running off the page, and a wrapped line is marked
  with a continuation arrow so it does not read as a new one. Each block sits on a
  light panel that breaks across pages when the listing is long. Syntax highlighting
  is pandoc's default; `--highlight-style` on the pandoc call picks another.

APA only:

- Table and figure numbers, their italic titles and `*Note.*` lines are flush left,
  while body paragraphs keep their first-line indent.
- The title page follows the APA 7 student format by default: 12pt throughout,
  double-spaced, bold title three lines down, then the author block, then the due
  date. `titlepage: professional` drops the due date and adds a running head. It is
  page 1 either way and pages are numbered top right.

MLA only:

- The writer's heading and the figure captions below each image are flush left.
- The title is centered, plain text, with no section numbering.
- There is no title page; every page is headed "Lastname #" top right.

## Controlling table column widths

Column widths come from the dash counts in the separator row, not from the content.
If a cell wraps awkwardly, give that column more dashes and take some from a numeric
column:

```markdown
| Model | Pipeline | Accuracy |
|--------------------|------------------|--------|
```

## Files

| File | Purpose |
|---|---|
| `build.sh` | One-command build; picks the style and engine and wires everything together |
| `apa.lua` | Pandoc filter applying the APA layout rules above |
| `preamble.lua` | Pandoc filter composing the preamble so a paper's `header-includes` survives |
| `apa.tex` | LaTeX preamble: page numbering, title page, URL breaking |
| `apa.csl` | APA 7th edition citation style, from the CSL project (CC BY-SA 3.0) |
| `_template.md` | Skeleton APA paper with the YAML header and the table/figure patterns |
| `mla.lua` | Pandoc filter applying the MLA layout rules above, plus the running-head surname |
| `mla.tex` | LaTeX preamble: running head, no title page, URL breaking |
| `mla.csl` | MLA 9th edition citation style, from the CSL project (CC BY-SA 3.0) |
| `_template_mla.md` | Skeleton MLA paper with the heading block and the table/figure patterns |
| `references.bib` | Starter bibliography; keep a per-paper copy beside each paper |
| `test.sh` | Regression tests for the preamble, the front-matter options and the rendered page |
