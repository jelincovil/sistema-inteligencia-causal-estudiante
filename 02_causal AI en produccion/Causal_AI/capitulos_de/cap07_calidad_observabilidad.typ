// Capítulo 7: Calidad y observabilidad de datos para decisiones (el contrato C-02).
// Edición de ingeniería de datos (main_de.typ). Caso canónico: scripts/cap07_calidad.py
// (semilla 20240701; PSI/KS sobre la edad real de real/jobs).
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Calidad y observabilidad de datos para decisiones]
<de-cap-calidad>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [«Calidad» para decisiones no es limpieza: un dato impoluto puede no sostener ninguna comparación causal],
    [*Decisión:*], [Medir comparabilidad (balance), estabilidad (deriva) y completitud (faltantes) como señales del plano de datos, con umbrales calibrados y escritos antes de mirar],
    [*Pieza contratada:*], [El contrato C-02 (comparación de poblaciones), restituido en el plano de datos],
    [*Casos canónicos:*], [Balance: el t-test miente por azar (2,02 rechazos de 40) y Holm lo calla (0,04); PSI/KS sobre la edad real; faltantes 9,6× que la SMD no ve],
    [*Conecta:*], [Las señales de este capítulo son las que el monitor consume en la Parte IV],
  )
]

== El problema: la calidad que importa
<sec-de-07-problema>

Las métricas de calidad de datos estándar — puntualidad, completitud, consistencia, unicidad — son necesarias y no llegan. Contestan si el dato está bien formado; callan en la sola pregunta que este libro hace: ¿sostiene este dato la comparación que el estimando declara? Una tabla impecable por todos esos criterios puede llegar con un desbalance severo entre tratados y controles, con una deriva que la vuelve otra población respecto de la que ajustó el modelo, o con faltantes que mezclan el mecanismo de selección en cada resultado. Ninguna de las tres fallas marca ninguna alarma de limpieza, porque ninguna es una falla de forma: son fallas de *estructura de decisión*, y solo se ven midiendo comparaciones.

Este capítulo instrumenta tres de esas comparaciones como métricas del plano de datos, arrancadas de la discusión de los datos de entrenamiento como diseño (@huyen2022dmls, Cap. 4) y de los criterios clásicos de la evaluación de programas (@rubin2001using, @imbens2015causal). Cada una responde una pregunta distinta: el *balance* — ¿los dos lados del estimando se parecen en lo medible, o la comparación va a apoyarse en extrapolación?; la *deriva* — ¿la población que hoy llega es la misma que la que ajustó el estimador?; los *faltantes diferenciales* — ¿quién desaparece de los datos, y depende de la decisión? Las tres comparten una regla de lectura que es la primera invariante del contrato: *tamaño de efecto, no $p$-valor* — lo que amenaza la comparación es la magnitud del problema, no si se distingue de cero.

== El chequeo de balance
<sec-de-07-balance>

Para cada covariable $j$, la *diferencia media estandarizada* es

$
"SMD"_j = (overline(X)_(j,1) - overline(X)_(j,0)) \/ sqrt((s_(j,1)^2 + s_(j,0)^2) \/ 2),
$

que no crece con $n$ y no cambia de unidad si la covariable cambia de escala. Los criterios operativos de @rubin2001using son $|"SMD"_j| < 0,25$ (más estricto, $< 0,1$) y una razón de varianzas $s_(j,1)^2 \/ s_(j,0)^2$ dentro de $[0,5, 2]$ — y el segundo se olvida con frecuencia: dos grupos con la misma media y dispersiones muy distintas tienen poco soporte común en las colas.

La alternativa que el equipo hará si nadie lo avisa — un $t$-test por covariable — responde la pregunta incorrecta y la responde mal dos veces: su $p$-valor mezcla magnitud con tamaño de muestra, y al pavimentar 40 comparaciones al 5 % produce por construcción alrededor de dos desbalances espurios. El caso canónico vuelve a hacer la misma pieza en números, con verdad conocida.

#caso-canonico("Cuarenta covariables y dos mecanismos de asignación")[
  Cuarenta covariables independientes, normales estándar. Dos regímenes: (i) *moneda justa* — el tratamiento al azar — y (ii) *asignación confundida* — la probabilidad de tratamiento es $sigma(1,2 X_0)$, es decir, depende solo de la primera covariable —, cada uno con 200 experimentos (semilla 20240701).

  Bajo moneda justa, el $t$-test crudo al 5 % marcó en promedio *2,02* covariables "desbalanceadas" por experimento sobre 40: la anomalía habitual que no es anomalía. Con la corrección de Holm, el promedio cayó a *0,04*: los rechazos eran ruido, como exige la teoría. La SMD contra la otra afirmación por encima de los criterios — con asignación confundida, la SMD de $X_0$ es *1,16*, y la bandera $|"SMD"| > 0,25$ se enciende exactamente en *1 de 40* covariables, la correcta; la mayor $|"SMD"|$ fuera de $X_0$ fue 0,13.

  Los dos regímenes producen por tanto lecturas distintas y ambas correctas: en el primero la estadística que mide *tamaño de efecto* dice "1", y la que mide *significancia* dice "2" por azar; en el segundo la SMD localiza la confusora sin ambigüedad. Y la razón de varianzas de $X_0$ agrega una nota honesta: 1,01, dentro de $[0,5, 2]$ — el desbalance está en la media, no en la dispersión.
]

Un número alto de SMD no invalida el análisis observacional, y sobre todo *no es el chequeo el que identifica el efecto*: el balance en lo observado silencia nada sobre lo no observado (eso es lo que la Parte IV vigila con el supuesto faltante del estimando). Lo que el chequeo cuantifica sí es útil: cuánta corrección deberá hacer el estimador, y por tanto cuánto de la estimación final apoyará sobre extrapolación en vez de datos.

== La deriva: la comparación mueve sus dos lados
<sec-de-07-deriva>

El balance compara tratados contra controles dentro de un mismo corte; la *deriva* compara una mismísima covariable entre dos tiempos: el train que ajustó contra la ventana que hoy llega. Los dos estadísticos de la literatura, ya implementados por el repositorio de referencia, son el *PSI* (_population stability index_) — una distancia simétrica entre dos histogramas, 0 si son iguales y creciente al alejarse — y el *KS* — el máximo de la distancia entre las dos empíricas. Son mediciones sin $p$-valor y por eso pertenecen al contrato de la comparación: con umbrales calibrados y escritos antes de mirar.

#caso-canonico("Una ventana envejecida sobre la edad verdadera")[
  Sobre la edad del train de `real/jobs` (1 033 filas reales del benchmark; semilla fija), el script hace tres ventanas: una réplica honesta — la otra mitad del mismo train — y dos envejecidas a propósito, +5 y +10 años. Las cifras en el orden de la tabla:

  #entero[
  #table(
    columns: (3fr, 1.4fr, 1.4fr, 2.4fr),
    align: (left, center, center, left),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Ventana*], [*PSI*], [*KS*], [*Lectura*]),
    table.hline(stroke: 0.3pt),
    [Réplica honesta], [0,008], [0,032], [estable, como debe],
    [+5 años], [0,585], [0,159], [deriva, y fuerte],
    [+10 años], [1,413], [0,297], [población otra],
    table.hline(stroke: 0.6pt),
  )
  ]

  Con el umbral de calibración usual — PSI $<$ 0,1 estable, 0,1–0,25 revisar, $>$ 0,25 alertar — la réplica pasa y las dos envejecidas superan el rango de alerta; la magnitud del KS confirma el orden. La moraleja no está en el umbral heredado — el contrato exige calibrarlo con muestras de la misma población, y eso toca hacerlo a cada equipo — sino en la dirección de lectura: la métrica señala qué cambió, y *qué acción corresponde se decide contra el estimando*, porque una deriva en una covariable irrelevante no es lo mismo que una deriva en la confusora (es exactamente la pregunta que devuelve la decisión del monitor, Parte IV, al vocabulario de las cinco acciones del Cap. #ref(<de-cap-anatomia>, supplement: none)).
]

#figure(
  diagram(
  node-stroke: 0.6pt + gray.lighten(40%),
  node-fill: light,
  node-outset: 4pt,
  node-corner-radius: 3pt,
  spacing: (7mm, 11mm),
  edge-stroke: 0.8pt + accent,
  node((0, 0), [referencia#linebreak()train ajustó]),
  node((0, 2), [ventana#linebreak()producción]),
  node((3.4, 1), [comparación#linebreak()C-02], fill: rgb("EEF4F8")),
  node((6.6, 0.4), [continuar], fill: green.lighten(88%)),
  node((6.6, 1.6), [alertar / revisar#linebreak()identificación], fill: crimson.lighten(92%)),
  edge((0.6, 0.2), (3.4, 1), "-|>"),
  edge((0.6, 1.8), (3.4, 1), "-|>"),
  edge((3.4, 1), (6.6, 1.6), "-|>", stroke: (paint: crimson, dash: "dashed")),
  edge((3.4, 1), (6.6, 0.4), "-|>"),
  ),
  caption: [La deriva como comparación C-02: las dos poblaciones — la que ajustó y la que llega — se miden con el mismo contrato que compara tratados contra controles. El umbral se calibra y se fija antes de mirar; la acción sale del vocabulario del sistema, no del estadístico.],
) <de-fig-deriva>

== Lo que la comparación no ve: faltantes por selección
<sec-de-07-faltantes>

Toda comparación de covariables se hace entre quienes figuran. Si la ausencia depende de la decisión — los tratados registran menos su ingreso anterior porque los incentivó a ocultarlo, digamos — la comparación se hace entre dos subconjuntos seleccionados por el propio proceso, y ni la SMD ni el PSI lo detectan si las distribuciones de los completos se parecen: el $p$-valor que nadie mira ya no es el problema, es la estructura de quién falta. El contrato separa este diagnóstico — *la tasa de faltantes se mide aparte, por brazo* — precisamente porque no cabe dentro de la comparación de covariables (invariante 5 del C-02).

#caso-canonico("Faltantes 9,6 veces más frecuentes en un brazo")[
  Sobre `observed_train.csv` (`real/jobs`), inyecte el mecanismo de pérdida siguiente: 30 % de probabilidad de perder `re75` a los tratados, 3 % a los controles — una ausencia que el propio tratamiento induce (semilla 7). Entre los completos, la SMD de `re75` es *0,016*: impecable en apariencia. La tasa de faltantes es *0,27* en tratados contra *0,03* en controles, una razón de *9,6*: la mismísima relación que el primer invariante protegía. Si el faltante depende además del resultado — típicamente: los que habrían vendido mal no reportan —, la ausencia no es aleatoria en el sentido de @rubin1976inference y ningún ajuste sobre los completos la corrige; solo el diseño — medir por qué falta, y eso sale de los datos.
]

== El contrato C-02, leído del plano de datos
<sec-de-07-c02>

Con los tres diagnósticos unidos, el contrato de la comparación queda como este libro lo hereda del aparato de la edición de método — con el mismo número, porque las mismas reglas ya le servían al entrenamiento — y leído ahora completo en su rol de plano de datos:

#contrato(
  "C-02",
  "Comparación de poblaciones",
  operaciones: [
    _comparar_: recibe dos poblaciones de unidades y devuelve, por covariable, la diferencia media estandarizada, la razón de varianzas, el PSI, el KS y una bandera por criterio. Los pares de poblaciones del libro: tratados contra controles (este capítulo), train contra ventana (deriva: la #ref(<de-fig-deriva>, supplement: [figura])) y versión vigente contra candidata (promoción, Parte IV).
  ],
  entrada: [
    Las dos poblaciones con las covariables del esquema (C-01). Los criterios: umbrales de SMD, de varianzas y de PSI/KS, escritos antes de mirar los datos y calibrados para el tamaño de las muestras y para el estimando declarado.
  ],
  salida: [
    Una fila por covariable con magnitudes y banderas, y la lectura de acción producida contra el vocabulario del sistema. Si se piden $p$-valores, se corrigen por comparaciones múltiples y se rotulan como secundarios.
  ],
  invariantes: [
    (1) El estadístico principal mide tamaño de efecto y no crece con el número de unidades; ningún $p$-valor decide solo. (2) Intercambiar las poblaciones invierte signos y razones y deja las banderas igual. (3) Con las mismas poblaciones el resultado es idéntico. (4) El umbral se calibra con muestras de la misma población y queda fijo antes de comparar. (5) Los faltantes no entran en la comparación y su diferencial se mide aparte. (6) La comparación habla solo de lo observado: no certifica lo no observado.
  ],
  fallos: [
    Una muestra pequeña con umbrales heredados: banderas por ruido. El umbral relajado después de mirar. El $p$-valor no significativo leído como ausencia. El faltante diferencial que la comparación no ve. El balance observado leído como garantía de no confusión.
  ],
  aceptacion: [
    (a) Caso A: moneda justa rechaza ~2 de 40 en crudo y ~0 en Holm, y la asignación en $X_0$ enciende solo $X_0$. (b) Caso B: la réplica honesta pasa el umbral y las ventanas desplazadas lo superan, en el orden medido. (c) Intercambio de poblaciones cumple el invariante (2). (d) Con un faltante diferencial inyectado y sin diferencias en lo observado, la comparación no señala y la medida aparte sí — con el número de veces que relación lo sostenga.
  ],
)

#repo-ref[
  Regeneración de los tres casos: #code[Causal_AI/scripts/cap07_calidad.py] (semillas 20240701 y 7). Implementación de referencia de las señales (PSI/KS/SMD/ESS): #code[04_produccion_causal/src/causalops/diagnosticos.py]. La acción que cada señal dispara, en producción, la decide el monitor causal de la Parte IV.
]

== De la métrica a la acción
<sec-de-07-accion>

Una métrica de observabilidad sin acción es una reflexión que nadie pide, y una acción sin métrica es una ansiedad con horario — las dos caras de la misma imprudencia. El camino de este libro, gradual y deliberado, es:

+ La señal se escribe con nombre, magnitud y población, nunca como "algo cambió". SMD y PSI se reportan por covariable, y el faltante diferencial por razón de tasas.
+ El umbral sale de la calibración local y de la relevancia al estimando, no de la convención heredada; el 0,25/0,1 es un arranque, y el C-02 exige escribirlo antes.
+ La acción sale del vocabulario de las cinco del Cap. #ref(<de-cap-anatomia>, supplement: none): *continuar* si se está dentro del umbral; *alertar* si se lo cruza y el estimando no cambió de población; *revisar identificación* si la deriva o el desbalance tocan la confusora o la regla de asignación; y *abstenerse* si la ventana actual no se parece a la población del soporte declarado — el servicio no entrega un número que ya nadie puede defender.
+ El monitor de la Parte IV las consume como señales periódicas, y el reporte nunca concluye por la causa del cambio: la señal obliga la revisión, no prueba nada.

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ El monitor marca un SMD de 0,31 en una covariable de contexto que *sabe* no ser confusora y un PSI de 0,05 en la confusora principal. ¿Qué acción de las cinco corresponde, y por qué no es "revisar identificación" por el número alto? _Pista:_ la magnitud mide el problema, la relevancia decide la acción: el grafo decide cuál alarma importa.

+ En una muestra de 80 unidades, con umbrales heredados, la mitad de las covariables enciende bandera. Describa el diagnóstico correcto: ¿se detectó un desbalance o un mal contrato? _Pista:_ calibración del invariante (4): el umbral de la convención presupone un tamaño de muestra.

+ Un equipo lee el caso B y propone "reportar PSI y KS solo cuando un gráfico óptico parezca feo". ¿Por qué el contrato lo prohíbe con el invariante (4)? _Pista:_ el umbral visual es un umbral posterior a mirar; la calibración ocurre antes o no ocurre.

+ La tasa de faltantes difiere 9,6 veces por brazo pero la SMD de los completos es 0,016. El equipo concluye "los completos están balanceados: imputamos y seguimos". ¿Qué más preguntaría antes de aceptar la imputación? _Pista:_ si la ausencia depende del resultado, ningún método de imputación sobre los completos lo corrige (MNAR).

+ Una ventana de producción cambió en la edad pero la ficha de procedencia del tratamiento del Cap. #ref(<de-cap-versionado>, supplement: none) no describe el mecanismo de asignación más nuevo. ¿Cuál es el estado de la ficha y qué acción corresponde? _Pista:_ la procedencia vieja no sigue inaugurando al estimador nuevo; es exactamente la condición de revisión del registro.

=== Notas bibliográficas

Los tres diagnósticos de este capítulo son los tres de la literatura clásica de evaluación: la SMD y la razón de varianzas de @rubin2001using, el ancla de la comparación de poblaciones como tamaño de efecto en @imbens2015causal y la clasificación de faltantes de @rubin1976inference, y el ancla experimental del benchmark del repositorio (@lalonde1986, @dehejia1999causal). La tradición de la ingeniería de datos vigila lo mismo con el nombre general de deriva en @kleppmann2017 y @reis2022fundamentals; y la unificación de ambos en una sola pieza — la comparación de poblaciones contratada, con umbrales calibrados y con acciones — es la contribución propia.

#verdad-datos[
  Que tres comparaciones estén instrumentadas, cada una respondiendo otra pregunta y ninguna decidiendo por $p$-valor: balance en cada evaluación (SMD y razón de varianzas, con banderas calibradas), deriva de cada covariable de cada despliegue (PSI/KS contra el train), y faltantes por brazo medidos aparte en cada ventana. Que los umbrales existan antes de mirar y estén escritos, con la calibración local que el contrato exige. Se comprueba reproduciendo los tres casos del capítulo (semillas 20240701 y 7, script del repositorio): en cada uno, el comportamiento esperado sale — Holm calla al azar, la SMD localiza la confusora, los faltantes salen por la ventanilla correcta. Lo que las señales no prueban: la causa del cambio ni la validez del estimando — eso es revisión humana, y es exactamente la lectura que el monitor de la Parte IV disciplina.
]
