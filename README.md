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
```

`build.sh <paper.md> [apa|mla] [pdf|docx] [output]` defaults to `apa` and `pdf`. It
uses `references.bib` next to the paper when there is one, otherwise the copy in this
repo.

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
needs a `lastname:` field for the "Lastname #" running head MLA requires on every page.

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
| `apa.tex` | LaTeX preamble: page numbering, title page, URL breaking |
| `apa.csl` | APA 7th edition citation style, from the CSL project (CC BY-SA 3.0) |
| `_template.md` | Skeleton APA paper with the YAML header and the table/figure patterns |
| `mla.lua` | Pandoc filter applying the MLA layout rules above |
| `mla.tex` | LaTeX preamble: running head, no title page, URL breaking |
| `mla.csl` | MLA 9th edition citation style, from the CSL project (CC BY-SA 3.0) |
| `_template_mla.md` | Skeleton MLA paper with the heading block and the table/figure patterns |
| `references.bib` | Starter bibliography; keep a per-paper copy beside each paper |
