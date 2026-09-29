---
title: "Title of the Paper in Title Case"
lastname: "Lastname"
geometry: margin=1in
font: times
linestretch: 2
indent: true
---

Author Name\
Instructor Name\
Course Title\
Month D, YYYY

# Title of the Paper in Title Case

Body paragraphs are ordinary markdown and keep their first-line indent. Cite with
pandoc keys from `references.bib`: [@chawla2002, 321] for a parenthetical citation,
@chawla2002 for a narrative one. Either way the entry joins the Works Cited below.

## Some Section

Tables use this three-part pattern. The number and title are flush left
automatically, the table body is set small and single-spaced, and an optional
source note goes underneath starting with *Source:*.

**Table 1**

Title of the Table in Title Case

| Model | Pipeline | Accuracy |
|--------------------|------------------|--------|
| A | none | 0.8186 |
| B | SMOTE | 0.8089 |

Source: Explain where the data came from, or drop this line entirely.

<!--
Column widths come from the dash counts in the separator row above, not from the
content. If a cell wraps awkwardly, give that column more dashes and take some
from a numeric column.
-->

Figures use the image first, then a caption paragraph starting with the bold
"Fig. N." label directly below it.

![](figures/example.png){width=100%}

**Fig. 1.** Caption text describing the figure.

## Works Cited

::: {#refs}
:::

## Appendix

**Table A1**

Title of the Appendix Table

| Column | Value |
|-----------|-------|
| Something | 1.000 |

![](figures/example.png){width=100%}

**Fig. A1.** Caption text describing the figure.

<!--
A figure's image and its caption are kept on one page automatically.
Set width as a percentage; 100% is the full text block.
-->
