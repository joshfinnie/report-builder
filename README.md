# report-builder

Build APA 7 formatted PDFs from plain markdown with pandoc, tectonic and a BibTeX
bibliography. Write the paper, run one command, get a submission-ready PDF.

## Setup

```sh
brew install pandoc tectonic
```

## Use

```sh
cp _template.md ~/papers/unit7.md          # start a paper
cp references.bib ~/papers/                # its bibliography
./build.sh ~/papers/unit7.md               # -> unit7.pdf
./build.sh ~/papers/unit7.md docx          # -> unit7.docx
```

`build.sh` uses `references.bib` next to the paper when there is one, otherwise the
copy in this repo.

## What you write

Ordinary markdown. Citations use pandoc keys from the `.bib`: `[@key]` renders as
(Author, Year), and `@key` renders as Author (Year). The reference list goes wherever
you put

```markdown
## References

::: {#refs}
:::
```

Tables and figures follow a three-part pattern. Label, italic title, then the content:

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

## What is handled for you

`apa.lua` (a pandoc filter) and `apa.tex` (a LaTeX preamble) apply the APA rules that
are tedious by hand:

- Table and figure numbers, their italic titles, `*Note.*` lines and images are flush
  left, while body paragraphs keep their first-line indent.
- A figure's number, title and image are wrapped together so a page break cannot
  separate them.
- Table bodies are set small and single-spaced, which APA allows, while the number,
  title and note stay double-spaced.
- Space is reserved before a table so its number and title are never stranded at the
  foot of a page.
- References and each appendix start on a new page.
- The title page stands alone and carries no page number; pages are numbered top right.
- URLs break only after a slash, so `https://` never splits after the colon.

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
| `build.sh` | One-command build; picks the engine and wires everything together |
| `apa.lua` | Pandoc filter applying the layout rules above |
| `apa.tex` | LaTeX preamble: page numbering, title page, URL breaking |
| `apa.csl` | APA 7th edition citation style, from the CSL project (CC BY-SA 3.0) |
| `_template.md` | Skeleton paper with the YAML header and the table/figure patterns |
| `references.bib` | Starter bibliography; keep a per-paper copy beside each paper |
