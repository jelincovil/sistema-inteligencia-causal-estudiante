// Capítulo 11: Diagnóstico sin verdad — placebo, control negativo y sensibilidad.
// Edición de ingeniería de datos (main_de.typ). Casos: scripts/cap11_diagnostico.py (semilla 20260711).
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Diagnóstico sin verdad]
<de-cap-diagnostico>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Sin verdad no hay métrica: ¿cómo saber si el efecto estimado es señal o artefacto?],
    [*Respuesta:*], [Tres pruebas que no necesitan verdad: placebo por permutación, control negativo y sensibilidad a confusor oculto],
    [*Criterio:*], [Falsación OOS: si el placebo da señal o el control negativo se mueve, la identificación falla],
    [*Pieza contratada:*], [Contrato C-08 (sensibilidad) + Q-02 (supuestos clasificados); umbral Gamma-star],
    [*Casos canónicos:*], [Placebo 500 perms: nula [-0,078,0,071] vs ATE 0,77; control neg. p=0,64; Gamma 0,8 cruza, 1,2 invierte (semilla 20260711)],
  )
]

== Sin verdad, con falsación
<sec-de-11-problema>

Los Capítulos 9–10 validan contra verdad sintética OOS. En producción no hay $tau$: el dato no trae su etiqueta causal. La salida no es renunciar a validar sino cambiar de métrica: falsar. Tres ideas con contrato:

- *Placebo por permutación:* rompe D–Y permutando D; bajo la nula de no efecto la distribución nula es el placebo y el ATE observado debe ser atípico.
- *Control negativo:* un outcome $Y_"nc"$ que comparte confusores con $Y$ pero no debe ser afectado por $D$; si $D$ "afecta" a $Y_"nc"$, la confusión es observable.
- *Sensibilidad:* cuánto confusor oculto $U$ haría cruzar el IC de "ATE" el 0 (Gamma-star paramétrico del DGP demo).

Las tres son OOS por construcción y no necesitan verdad: necesitan un DGP compañero donde la violación es inyectable.

== Placebo y control negativo
<sec-de-11-placebo>

*Lo que dice la teoría (edición de método, Cap. 14):* placebo y control negativo son tests de falsación, no de confirmación: un p grande no prueba identificación, solo no la refuta.

*La exigencia al dato:* toda estimación entrega junto a su IC un p-placebo (posición del ATE en la nula permutada, 500 perms) y un ATE de control negativo con p; ambos OOS y con semilla.

#caso-canonico("El placebo que no da señal y el control que no se mueve")[
  DGP base ATE=0,8, $n=2 000$, semilla 20260711. ATE observado 0,767 IC [0,696,0,838] $p<10^(-9)$.

  #entero[
  #table(
    columns: (2fr, 1.2fr, 1.4fr),
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Prueba*], [*ATE*], [*IC placebo / p*]),
    table.hline(stroke: 0.3pt),
    [Placebo 1 perm], [-0,009], [nula sd 0,037],
    [Placebo 500 perms], [-0,002], [[-0,078, 0,071]],
    [Control negativo], [-0,017], [p=0,64],
    table.hline(stroke: 0.6pt),
  )
  ]

  El placebo vive centrado en 0 con sd 0,037; el control negativo no se mueve ($p=0,64$). El ATE real (0,77) es atípico en esa nula ($p≈0$). Falsación pasada no certifica causalidad — pero su fallo (placebo con señal) habría abortado el deploy.
]

#repo-ref[
  Script #code[Causal_AI/scripts/cap11_diagnostico.py] (semilla 20260711) reproduce la tabla; la nula de 500 perms es la del contrato C-08.
]

== Sensibilidad: cuánto confusor haría cruzar el cero
<sec-de-11-sensibilidad>

*La promesa:* Rosenbaum Gamma y el paramétrico $gamma_u$ dicen cuánto $U$ no observado haría que el IC incluya el 0. No es p-valor: es umbral de robustez declarado.

*La exigencia al dato:* reporte Gamma-star — menor $gamma$ tal que IC toca 0 — con DGP inyectado $Y = 0,5 X_0 + 0,8 D + gamma_u U + epsilon$.

#caso-canonico("Gamma 0,8 roza, 1,2 invierte")[
  Mismo DGP, $gamma_u$ creciente:

  #entero[
  #table(
    columns: (1.2fr, 1.3fr, 1.5fr, 1fr),
    align: (center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*$gamma_u$*], [*ATE*], [*IC 95 %*], [*Lectura*]),
    table.hline(stroke: 0.3pt),
    [0,0], [0,767], [[0,696,0,838]], [robusto],
    [0,5], [0,586], [[0,502,0,670]], [robusto],
    [0,8], [0,115], [[0,017,0,213]], [roza 0],
    [1,2], [-0,214], [[-0,335,-0,092]], [invierte],
    table.hline(stroke: 0.6pt),
  )
  ]

  Gamma-star≈0,8 cruza, 1,2 invierte signo. El contrato exige declarar Gamma-star en la tarjeta (C-05) como "qué tamaño de confusor oculto haría fracasar la conclusión".
]

#figure(
  diagram(
    node-stroke: 0.6pt + gray.lighten(40%),
    node-fill: light,
    node-outset: 4pt,
    node-corner-radius: 3pt,
    spacing: (5mm, 8mm),
    edge-stroke: 0.8pt + accent,
    node((0, 1.2), [estimación#linebreak()ATE+IC]),
    node((2.6, 1.2), [placebo#linebreak()500 perms]),
    node((5.0, 1.2), [control neg.]),
    node((2.6, 0), [Gamma-star], fill: rgb("EEF4F8")),
    edge((0.9, 1.2), (1.8, 1.2), "-|>"),
    edge((3.4, 1.2), (4.2, 1.2), "-|>"),
    edge((2.6, 0.9), (2.6, 0.3), "-|>", stroke: 0.8pt + navy),
  ),
  caption: [Diagnóstico sin verdad: placebo, control negativo y sensibilidad convergen en Gamma-star. Sin verdad igual hay falsación OOS.],
) <de-fig-diagnostico>

== Contrato C-08: sensibilidad y falsación
<sec-de-11-contrato>

#contrato(
  "C-08",
  "Sensibilidad y falsación sin verdad",
  operaciones: [
    _placebo_: permuta D y reporta nula + p-placebo OOS; _control_negativo_: estima ATE sobre Y_nc que no debe moverse; _sensibilidad_: inyecta U con gamma creciente y reporta Gamma-star.
  ],
  entrada: [
    Bundle C-12 + Y_nc declarado + grid de gamma_u para DGP de sensibilidad.
  ],
  salida: [
    p-placebo + nula 500 perms + ATE_nc con p + curva ATE(gamma) y Gamma-star declarado en tarjeta.
  ],
  invariantes: [
    (1) Placebo y control negativo son OOS con semilla. (2) Fallo de cualquiera aborta deploy (Q-02). (3) Gamma-star se declara en C-05, no se oculta.
  ],
  fallos: [
    p-placebo con 20 perms y declarar p. Elegir Y_nc post-hoc que "pasa". Reportar Gamma-star sin IC.
  ],
  aceptacion: [
    (a) Placebo nula [-0,078,0,071] contiene 0 y excluye ATE 0,77. (b) Control negativo p=0,64. (c) Gamma-star 0,8 toca, 1,2 invierte.
  ],
)

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ Tu placebo da p=0,04. ¿Pasó o falló? ¿Qué acción del sistema corresponde? _Pista:_ Q-02, revisar identificación.

+ Eliges Y_nc después de ver que pasa. ¿Qué invariante violas? _Pista:_ Y_nc se declara con el estimando.

+ Gamma-star =0,3 en tu tarjeta. ¿Qué le dices al decisor? _Pista:_ poco robusto: confusor pequeño cruza.

=== Notas bibliográficas

Placebo por permutación: @imbens2015causal; control negativo: @lipsitch2010negative; sensibilidad Rosenbaum Gamma: @rosenbaum1983central. Lectura pipeline: todo falsación es OOS aquí.

#verdad-datos[
  Que toda estimación llegue con p-placebo 500 perms, control negativo y Gamma-star declarado. Se comprueba con semilla 20260711: nula correcta, control inmóvil, Gamma-star 0,8/1,2. Sin eso no hay deploy — aunque el ATE sea "significativo".
]
