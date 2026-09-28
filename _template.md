---
title: "Title of the Paper in Title Case"
author: |
  Author Name \
  Affiliation
date: "Month D, YYYY"
geometry: margin=1in
fontsize: 12pt
mainfont: "Times New Roman"
linestretch: 2
indent: true
---

## Introduction

Body paragraphs are ordinary markdown and keep their first-line indent. Cite with
pandoc keys from `references.bib`: [@chawla2002] for a parenthetical citation,
@chawla2002 for a narrative one. Either way the entry joins the reference list below.

## Some Section

Tables use this three-part pattern. The label and italic title are flush left
automatically, the table body is set small and single-spaced, and the note goes
underneath starting with *Note.*

**Table 1**

*Title of the Table in Title Case*

| Model | Pipeline | Accuracy |
|--------------------|------------------|--------|
| A | none | 0.8186 |
| B | SMOTE | 0.8089 |

*Note.* Explain abbreviations and anything the columns do not say for themselves.

<!--
Column widths come from the dash counts in the separator row above, not from the
content. If a cell wraps awkwardly, give that column more dashes and take some
from a numeric column.
-->

## References

::: {#refs}
:::

## Appendix

**Table A1**

*Title of the Appendix Table*

| Column | Value |
|-----------|-------|
| Something | 1.000 |

**Figure A1**

*Title of the Figure in Title Case*

![](figures/example.png){width=100%}

<!--
The figure's label, title and image are kept on one page automatically.
Set width as a percentage; 100% is the full text block.
-->
