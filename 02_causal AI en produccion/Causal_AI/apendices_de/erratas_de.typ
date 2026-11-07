// Página de erratas — vacía para 1.0-rc.
#import "../template/template.typ": *
#import "../template/template_de.typ": *

#chapter[Erratas]
<de-erratas>

#theorem-number-reset()

Esta página se actualiza con cada reimpresión. En la edición 1.0-rc no hay erratas conocidas. Si encuentra una, repórtela al repositorio de referencia del libro con el número de página y el texto exacto.

#entero[
#table(
  columns: (0.6fr, 1fr, 2fr, 2fr),
  align: (center, left, left, left),
  stroke: none,
  table.hline(stroke: 0.6pt),
  table.header([*Pág.*], [*Dice*], [*Debe decir*], [*Motivo*]),
  table.hline(stroke: 0.3pt),
  table.hline(stroke: 0.6pt),
)
]
