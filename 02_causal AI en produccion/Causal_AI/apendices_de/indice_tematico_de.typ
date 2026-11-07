// Índice temático — manual, por parte del libro.
#import "../template/template.typ": *
#import "../template/template_de.typ": *

#chapter[Índice temático]
<de-indice-tematico>

#theorem-number-reset()

Los términos se listan por parte, con el capítulo donde se introducen o desarrollan. Un término puede aparecer en varios capítulos: se anota el principal.

#entero[
#table(
  columns: (1.8fr, 0.6fr, 1.8fr, 0.6fr),
  align: (left, center, left, center),
  stroke: none,
  table.hline(stroke: 0.6pt),
  table.header([*Término*], [*Cap.*], [*Término*], [*Cap.*]),
  table.hline(stroke: 0.3pt),
  [abstención], [2, 13], [aleatorización], [1],
  [alias champion], [4, 12], [AIPW], [9],
  [as-of join], [6], [ATE / ATT / CATE], [1],
  [auditoría end-to-end], [15], [benchmark como producto], [8],
  [bundle], [4, 13], [calibración de umbrales], [7, 14],
  [comparación de poblaciones], [7], [contraste], [1],
  [contrato C-01 (roles)], [3], [contrato C-02 (poblaciones)], [7],
  [contrato C-03 (temporal)], [6], [contrato C-04 (servicio)], [13],
  [contrato C-05 (tarjeta)], [15], [contrato C-06 (puerta)], [12],
  [contrato C-07 (monitor)], [14], [contrato C-08 (sensibilidad)], [11],
  [contrato C-09 (linaje)], [4], [contrato C-10 (partición)], [5],
  [contrato C-11 (benchmark)], [8], [contrato C-12 (estimador)], [9],
  [control negativo], [11], [covariable post-tratamiento], [6],
  [cross-fitting], [9], [deriva], [7, 14],
  [doble robustez], [9], [DGP], [8],
  [estimando declarado], [1, 15], [ESS de Kish], [7, 9],
  [fuga temporal], [6], [heterogeneidad], [10],
  [holdout permanente], [2, 5], [identificación], [1, 12],
  [inmutabilidad], [4], [instrumento (fuerza)], [14],
  [invariantes], [3], [linaje], [4],
  [manifest con hash], [4, 15], [mecanismo de asignación], [2, 14],
  [monitoreo causal], [14], [no confusión condicional], [1, 15],
  [pared observado/evaluación], [5, 8], [partición sembrada], [5],
  [placebo por permutación], [11], [plano de datos], [2],
  [plano de método], [2, 9], [política (umbral)], [10],
  [prueba de aceptación], [3], [propensity score], [9, 14],
  [puerta causal], [12], [Qini], [10],
  [reversión de Simpson], [1], [sensibilidad Rosenbaum], [11],
  [SHA-256], [4], [soporte común], [9, 13],
  [splits con semilla], [5], [SMD], [7],
  [supuestos no observables], [15], [tarjeta causal], [15],
  [trimming de Crump], [9], [validez temporal], [6],
  [valor de política IPW], [10], [ventanas de producción], [12, 14],
  [verdad reservada], [5, 8],
  table.hline(stroke: 0.6pt),
)
]
