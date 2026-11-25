#let accent = rgb("#173F5F")

#let note(body) = block(
  fill: rgb("#EEF3F7"),
  stroke: (left: 2.5pt + accent),
  inset: 9pt,
  radius: 3pt,
  width: 100%,
)[#body]

#let boundary(body) = note()[#strong[Evidence boundary.] #body]
