# report-builder

Build APA 7 or MLA 9 formatted PDFs from plain markdown with pandoc, tectonic and a
BibTeX bibliography. Write the paper, run one command, get a submission-ready PDF.

## Setup

```sh
brew install pandoc tectonic
```

## Use

```sh
cp _template.md ~/papers/unit7.md          # start an APA paper
cp _template_mla.md ~/papers/essay1.md     # ...or an MLA paper
cp references.bib ~/papers/                # its bibliography
./build.sh ~/papers/unit7.md               # -> unit7.pdf, APA
./build.sh ~/papers/essay1.md mla          # -> essay1.pdf, MLA
./build.sh ~/papers/essay1.md mla docx     # -> essay1.docx, MLA
./build.sh --font-size 11 ~/papers/unit7.md  # -> unit7.pdf, 11pt
```

```
build.sh [options] <paper.md> [apa|mla] [pdf|docx|tex] [output]

  -b, --bib <file>       bibliography to cite from
      --no-bib           build without a bibliography
      --font-family <n>  override the paper's mainfont (PDF only)
      --font-size <n>    override the paper's fontsize, e.g. 11 or 11pt (PDF only)
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

Both templates set `fontsize: 12pt` and `mainfont: "Times New Roman"` in their front
matter, which is what APA and MLA both expect. To build a one-off in something else,
pass a flag:

```sh
./build.sh --font-family Georgia --font-size 11 ~/papers/essay1.md mla
```

A bare number is read as points, so `--font-size 11` and `--font-size 11pt` are the
same. Both flags override the paper's front matter for that build only, leaving the
file untouched. Change the front matter instead when you want it to stick.

Two limits are worth knowing. The flags apply to PDF output only; `.docx` takes its
formatting from a Word reference document, so the build warns and ignores them there.
And `mainfont` is a XeLaTeX/LuaLaTeX feature. Builds run through tectonic, which is
XeTeX, so this works, but `--font-family` would silently do nothing under pdflatex.

## Front matter options

Beyond the usual pandoc fields, a paper can set these to override the style locally.
Both default to what APA and MLA call for, so leaving them out changes nothing.

| Field | Default | Effect |
|---|---|---|
| `pagenumber` | `topright` | `bottomright` moves the page number into the footer |
| `titlepage` | `true` | `false` suppresses the template's title page so the paper can supply its own |

```yaml
---
title: "Title of the Paper"
pagenumber: bottomright
titlepage: false
---
```

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

MLA has no title page: the writer's heading (name, instructor, course, date) is the
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
- Space is reserved before a table so its label and title are never stranded at the
  foot of a page.
- A figure's label, title/caption and image are wrapped together so a page break
  cannot separate them.
- References/Works Cited and each appendix start on a new page.
- URLs break only after a slash, so `https://` never splits after the colon.

APA only:

- Table and figure numbers, their italic titles and `*Note.*` lines are flush left,
  while body paragraphs keep their first-line indent.
- The title page follows the APA 7 student format: 12pt throughout, double-spaced,
  bold title three lines down, then author, affiliation, course, instructor and due
  date on consecutive lines. It is page 1 and pages are numbered top right.

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
| `test.sh` | Regression tests for the preamble and the front-matter options |
