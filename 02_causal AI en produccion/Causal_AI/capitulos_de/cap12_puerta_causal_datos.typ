// Capítulo 12: La puerta causal en el plano de datos.
// Edición de ingeniería de datos (main_de.typ). Caso canónico: scripts/cap12_puerta.py (semilla 20260712).
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[La puerta causal en el plano de datos]
<de-cap-puerta>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Una versión nueva de datos o features puede romper la identificación aunque el estimador no cambie],
    [*Decisión:*], [La puerta evalúa señales OOS contra umbrales declarados y produce pasa, alerta o falla antes de promover],
    [*Pieza contratada:*], [Contrato C-06 (compuerta de registro): solo la versión en pasa llega al alias champion],
    [*Casos canónicos:*], [v0001 pasa, v0002 alerta por deriva, v0003 falla por solapamiento roto (semilla 20260712)],
    [*Conecta:*], [El registro C-09 guarda las versiones; el monitor C-07 produce las señales en producción],
  )
]

== Promover datos, no solo modelos
<sec-de-12-problema>

En un sistema predictivo, la decisión de promover es comparación de métricas: si la versión nueva gana en validación, reemplaza a la vieja. En un sistema causal esa comparación es insuficiente, porque el objeto que se promueve no es solo un modelo: es un *bundle* de datos, features y estimador cuya combinación sostiene una afirmación causal. Una versión nueva del dataset — una reextracción, un cambio en el origen, un filtro de negocio — puede romper la identificación sin que el error predictivo se mueva. La puerta causal existe para interceptar exactamente eso: es la pieza que decide, con señales medibles, si una versión puede llegar a producción.

La puerta no sustituye el juicio: lo disciplina. Las señales orientan una revisión; no prueban la causa del cambio. Lo que la puerta garantiza es más modesto y más útil: que ninguna versión con identificación rota llega al alias `champion` sin que alguien lo vea y lo acepte explícitamente.

== Las tres señales de la puerta
<sec-de-12-senales>

La puerta consume las mismas señales del Capítulo 7 (C-02) y las traduce en estados de promoción. Tres señales, tres preguntas distintas:

+ *Solapamiento.* ¿Hay con quién comparar en la nueva versión? Se mide con la fracción de unidades con propensión estimada en zona de comparación. Si cae bajo el mínimo, la puerta falla: el estimando deja de ser computable.
+ *Deriva.* ¿La población de la versión nueva se parece a la que ajustó? Se mide con el PSI por covariable. Si cruza el umbral, la puerta alerta: la población cambió y hay que revisar la identificación antes de reentrenar.
+ *Balance.* ¿La asignación del tratamiento cambió de forma? Se mide con el SMD máximo entre tratados y controles. Si cruza el umbral, la puerta alerta: el mecanismo de asignación no es el declarado.

#figure(
  diagram(
    node-stroke: 0.6pt + gray.lighten(40%),
    node-fill: light,
    node-outset: 4pt,
    node-corner-radius: 3pt,
    spacing: (5mm, 8mm),
    edge-stroke: 0.8pt + accent,
    node((0, 0), [versión#linebreak()candidata]),
    node((2.6, 0), [puerta C-06], fill: rgb("EEF4F8")),
    node((5.2, 0.9), [champion], fill: green.lighten(85%)),
    node((5.2, 0), [alerta], fill: crimson.lighten(92%)),
    node((5.2, -0.9), [bloqueo], fill: crimson.lighten(92%)),
    edge((1.0, 0), (2.0, 0), "-|>"),
    edge((3.2, 0.1), (4.6, 0.9), "-|>", stroke: 0.8pt + green),
    edge((3.2, 0), (4.6, 0), "-|>", stroke: 0.8pt + orange),
    edge((3.2, -0.1), (4.6, -0.9), "-|>", stroke: 0.8pt + crimson),
  ),
  caption: [La puerta causal evalúa tres señales contra umbrales declarados y produce tres estados. Solo la versión en pasa llega al alias champion; alerta y falla exigen decisión humana explícita.],
) <de-fig-puerta>

== El contrato C-06: compuerta de registro
<sec-de-12-contrato>

#contrato(
  "C-06",
  "Compuerta de registro causal",
  operaciones: [
    _evaluar_: recibe una versión candidata y produce estado pasa, alerta o falla con motivo nombrado; _promover_: apunta el alias champion a la versión solo si el estado es pasa; _bloquear_: rechaza la promoción de una versión en falla y notifica; _aceptar_alerta_: permite promover una versión en alerta solo con aceptación explícita registrada.
  ],
  entrada: [
    La versión candidata (bundle C-12), las señales del C-02 (solapamiento, PSI, SMD) y los umbrales declarados en la tarjeta.
  ],
  salida: [
    El estado de la puerta con motivo, la decisión de promoción registrada y el alias champion actualizado o bloqueado.
  ],
  invariantes: [
    (1) Ninguna versión en estado falla llega al alias champion. (2) Una versión en alerta solo se promueve con aceptación explícita de una persona, registrada. (3) El motivo de cada estado nombra la señal y su valor contra el umbral. (4) Los umbrales vienen de la tarjeta (C-05) y no se ajustan después de mirar la señal. (5) Toda decisión de promoción queda registrada con hash de la versión y estado de la puerta.
  ],
  fallos: [
    Promover una versión en falla. Ajustar el umbral después de ver la señal para que pase. Registrar la promoción sin el motivo de la puerta. Reentrenar en lugar de revisar la identificación cuando la señal es deriva.
  ],
  aceptacion: [
    (a) La versión sana pasa y llega a champion. (b) La versión con deriva alerta y no se promueve sin aceptación. (c) La versión con solapamiento roto falla y queda bloqueada. Semilla 20260712 reproduce los tres estados.
  ],
)

== Caso canónico: tres versiones, tres estados
<sec-de-12-caso>

#caso-canonico("Tres versiones del mismo dataset, tres decisiones de puerta")[
  Sobre `observed_train.csv` de `real/jobs` (semilla 20260712 del script), tres versiones candidatas evaluadas contra los umbrales declarados `smd_max` 0,25, `psi_alerta` 0,25, `solape_min` 0,50:

  #entero[
  #table(
    columns: (1.4fr, 0.8fr, 0.9fr, 0.9fr, 0.9fr, 1.2fr),
    align: (left, center, center, center, center, left),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Versión*], [*n*], [*PSI*], [*SMD*], [*Solape*], [*Estado*]),
    table.hline(stroke: 0.3pt),
    [v0001 sana], [700], [0,011], [0,22], [100 %], [*pasa*],
    [v0002 deriva], [1 033], [1,347], [0,19], [100 %], [*alerta*],
    [v0003 positividad], [270], [3,237], [5,24], [0 %], [*falla*],
    table.hline(stroke: 0.6pt),
  )
  ]

  *v0001* es una submuestra sana de la misma población: todas las señales dentro de umbral, la puerta produce `pasa` y el alias champion la acepta. *v0002* envejece la población diez años: el PSI de la edad dispara la alerta — la identificación puede seguir siendo válida, pero alguien tiene que revisarla antes de reentrenar. *v0003* hace la asignación casi determinista por ingreso previo: el solapamiento cae a 0 %, la puerta produce `falla` y la promoción queda bloqueada. Solo v0001 llega a champion; v0002 y v0003 quedan en el registro con su estado y su motivo, esperando revisión humana.
]

#repo-ref[
  Script #code[Causal_AI/scripts/cap12_puerta.py] (semilla 20260712) reproduce la tabla de los tres estados. La implementación de referencia de la puerta con estados y alias atómico: #code[04_produccion_causal/src/causalops/puerta.py] y #code[registro_local.py].
]

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ La versión v0002 (deriva) produce alerta, no falla. ¿Por qué la puerta no la bloquea automáticamente, y qué decisión humana exige? _Pista:_ la deriva cambia la población pero no necesariamente rompe la identificación; alguien tiene que revisar el grafo antes de decidir.

+ Con el umbral de solapamiento en 0,50, la v0003 falla. Un equipo propone bajarlo a 0,10 para que pase. ¿Qué invariante del C-06 viola esa propuesta? _Pista:_ los umbrales vienen de la tarjeta y no se ajustan después de mirar la señal.

+ ¿Qué diferencia hay entre reentrenar y revisar identificación como respuesta a una alerta de deriva? _Pista:_ reentrenar ajusta el estimador a la nueva población; revisar identificación pregunta si la nueva población sigue siendo la del estimando declarado.

=== Notas bibliográficas

La compuerta de registro es la pieza del Capítulo 19 de la edición de método (model card y registro) traducida al plano de datos. Las señales que consume son las del C-02 (Capítulo 7 de este libro): balance, deriva y solapamiento con umbrales calibrados. La decisión de promover con estados y alias atómico es la que implementa #code[causalops.puerta] con #code[registro_local] en el repositorio de referencia.

#verdad-datos[
  Que ninguna versión con identificación rota llegue a producción sin revisión humana. Se comprueba con la semilla 20260712: la versión sana pasa, la versión con deriva alerta y exige aceptación explícita, la versión con solapamiento roto falla y queda bloqueada. Lo que la puerta no garantiza: que la versión en pasa sea causalmente válida — solo que sus señales observables están dentro de umbral. La identificación sigue siendo una declaración, no una medición.
]
