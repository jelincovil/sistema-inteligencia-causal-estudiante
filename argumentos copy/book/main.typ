#set document(
  title: "Causal Machine Learning and Artificial Intelligence",
  author: "Self-contained Rust evidence-engineering project",
  keywords: ("causal inference", "machine learning", "AIPW", "LaLonde", "evidence governance"),
)
#set page(paper: "a4", margin: (x: 2.05cm, y: 2.2cm), numbering: "1")
#set text(font: "Libertinus Serif", size: 10.5pt, lang: "en")
#set par(justify: true, leading: 0.64em, first-line-indent: 0pt)
#set heading(numbering: "1.1.1")
#set math.equation(numbering: "(1)")
#set table(stroke: 0.4pt + luma(72%), inset: 5pt, align: left + horizon)
#show heading: set text(fill: rgb("#173F5F"))
#show heading.where(level: 1): set text(size: 19pt)
#show heading.where(level: 2): set text(size: 13pt)
#show link: set text(fill: rgb("#135D8A"))
#show figure.where(kind: table): set figure.caption(position: top)
#show figure.caption: set text(size: 8.5pt, fill: luma(30%))
#show figure: set block(breakable: true)
#show raw.where(block: true): set block(fill: luma(96%), inset: 8pt, radius: 3pt)
#show raw: set text(font: "DejaVu Sans Mono", size: 8.2pt)

#import "common.typ": accent, boundary

#align(center)[
  #v(2.5cm)
  #text(size: 26pt, weight: "bold", fill: accent)[Causal Machine Learning\ and Artificial Intelligence]
  #v(0.8cm)
  #text(size: 15pt)[Identification, Estimation, Data Governance,\ and Argument Auditing]
  #v(1.1cm)
  #text(size: 11pt)[A self-contained technical book with an executable\ LaLonde / National Supported Work study]
  #v(1.3cm)
  #text[Rust workspace · deterministic protocol · candidate evidence only]
  #v(2cm)
]

#boundary[
  This book teaches and implements a causal workflow; it does not certify a causal effect. The executable case combines National Supported Work treated observations with a nonexperimental PSID comparison group. Its unmeasured-confounding, support, measurement, and transportability questions remain open. Passing Rust tests, valid argument structure, generated receipts, and SHA-256 hashes never discharge those scientific assumptions.
]

#pagebreak()
= Reader's contract <reader-contract>

This text separates four activities that are often incorrectly collapsed into “causal AI”:

+ define a scientific question and a target estimand;
+ justify identification before choosing an estimator;
+ implement a deterministic data and estimation protocol; and
+ preserve computational evidence without confusing it with substantive validity.

The running example is deliberately small and transparent. Logistic iteratively reweighted least squares, ridge-linear outcome models, cross-fitting, and augmented inverse-probability weighting are implemented directly in Rust. The purpose is inspectability, not a claim that these learners are optimal. Every empirical number in the case-study tables is generated from the saved JSON artifacts by `causal-ml report`; prose must not silently replace those outputs.

== How to read the dependencies

Chapters 1–4 define claims, causal models, assumptions, and support. Chapter 5 derives estimators and explains methods that are discussed but not executed. Chapter 6 is the computational case and includes its artifact-generated fragment. Chapters 7–8 govern uncertainty, transportability, data splits, monitoring, and deployment. Chapter 9 explains the separate argument kernel and its evidence limits. References in the form `@lalonde1986` resolve to the bibliography; labels link definitions and derivations within the book.

#outline(title: [Contents], depth: 3)

#include "chapters/01-claims.typ"
#pagebreak()
#include "chapters/02-potential-outcomes.typ"
#pagebreak()
#include "chapters/03-identification.typ"
#pagebreak()
#include "chapters/04-overlap.typ"
#pagebreak()
#include "chapters/05-estimation.typ"
#pagebreak()
#include "chapters/06-lalonde-case.typ"
#pagebreak()
#include "chapters/07-uncertainty.typ"
#pagebreak()
#include "chapters/08-governance.typ"
#pagebreak()
#include "chapters/09-argument-kernel.typ"

#pagebreak()
#bibliography("references.bib", title: [References])
