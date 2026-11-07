// Índice de autores — manual, con capítulo donde se cita.
#import "../template/template.typ": *
#import "../template/template_de.typ": *

#chapter[Índice de autores]
<de-indice-autores>

#theorem-number-reset()

#entero[
#table(
  columns: (1.6fr, 0.8fr, 2.6fr),
  align: (left, center, left),
  stroke: none,
  table.hline(stroke: 0.6pt),
  table.header([*Autor*], [*Caps.*], [*Contribución citada*]),
  table.hline(stroke: 0.3pt),
  [Angrist, J.], [1], [Diseños IV y LATE],
  [Bareinboim, E.], [1], [IA causal y PCH],
  [Breck, C.], [2], [ML Test Score],
  [Card, D.], [1, 9], [Retornos a la educación con IV],
  [Chernozhukov, V.], [9], [DML y ortogonalidad],
  [Crump, R. K.], [9], [Trimming y varianza asintótica],
  [Dehejia, R.], [1, 7], [NSW y controles observacionales],
  [Hernán, M. A.], [1], [What if (inferencia causal aplicada)],
  [Hill, J.], [8], [IHDP y BART],
  [Holland, P. W.], [1], [Problema fundamental],
  [Huyen, C.], [2, 7], [Designing ML Systems],
  [Imbens, G.], [1], [Causal Inference for Statistics],
  [Kastner, D.], [14], [ML in Production],
  [Kish, L.], [9], [Tamaño efectivo de muestra],
  [Kleppmann, M.], [3, 4], [Designing Data-Intensive Applications],
  [Künzel, P.], [10], [Meta-learners y cross-fitting],
  [LaLonde, R.], [1, 7], [NSW benchmark],
  [Lipsitch, M.], [11], [Control negativo],
  [Mitchell, M.], [15], [Model cards],
  [Neyman, J.], [1], [Resultados potenciales],
  [Paleyes, A.], [2], [Challenges in ML deployment],
  [Pearl, J.], [1], [Causalidad y PCH],
  [Perdomo, J.], [2], [Predicción performativa],
  [Reis, J.], [3], [Fundamentals of Data Engineering],
  [Rosenbaum, P.], [11], [Sensibilidad y Gamma],
  [Rubin, D. B.], [1, 7], [Resultados potenciales, balance],
  [Sculley, C.], [2], [Hidden technical debt in ML],
  [Wager, S.], [10], [Causal forests],
  table.hline(stroke: 0.6pt),
)
]
