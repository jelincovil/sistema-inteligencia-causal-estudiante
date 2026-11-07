// Capítulo 2: Anatomía de un sistema de decisión (los dos planos).
// Edición de ingeniería de datos (main_de.typ). Caso canónico: scripts/cap02_traza.py.
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Anatomía de un sistema de decisión]
<de-cap-anatomia>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Un modelo entrenado y un sistema en producción son dos objetos distintos; entre ambos vive el plano de datos],
    [*Decisión:*], [Separar plano de método y plano de datos, y darle a cada uno su dueño y sus invariantes],
    [*Vocabulario:*], [Cinco acciones del sistema, siempre con el mismo sentido: abstenerse, revisar, alertar, reentrenar, continuar],
    [*Caso canónico:*], [La traza de una consulta por el sistema, sobre el escenario `real/jobs` del benchmark],
    [*Prepara:*], [Todos los contratos del libro (Caps. #ref(<de-cap-contratos>, supplement: none) a #ref(<de-cap-tiempo>, supplement: none) y Parte IV)],
  )
]

== Dos planos, dos responsabilidades
<sec-de-02-dos-planos>

Un equipo entrena un estimador de efectos y obtiene intervalos razonables, diagnósticos satisfactorios y una historia convincente sobre el mecanismo. Si ese estimador se entrega tal cual a un equipo de producto para decidir a quién ofrecer un subsidio, algo saldrá mal en semanas: la función que calcula las covariables en producción no será exactamente la de entrenamiento; nadie sabrá qué hacer con un valor faltante; tres meses después, nadie podrá decir si la población servida sigue pareciéndose a la de entrenamiento; y si el sistema empieza a fallar, nadie recibirá una alerta hasta que un usuario se queje. #cite(<huyen2022dmls>, form: "prose") lo formuló con precisión: lo que la gente llama "el sistema de machine learning" es apenas un componente de un sistema que incluye la interfaz, el stack de datos, el cómputo y la infraestructura que lo desarrolla, despliega, monitorea y actualiza — y la evidencia empírica recopilada por #cite(<paleyes2022challenges>, form: "prose") confirma que la fracción de fallos atribuible al algoritmo mismo es minoritaria.

Este libro estructura esa observación en dos planos con responsabilidades distintas:

- *Plano de método.* Identificación y estimación: los supuestos bajo los que la comparación de la @de-eq-descomposicion se hace interpretable, el estimador, la incertidumbre. Tiene su tratamiento completo en la edición de método de este libro y aquí solo aparece como *consumidor*: cada estimador le exige al dato tasas de convergencia, solapamiento, covariables legítimas y particiones honestas.
- *Plano de datos.* La cadena que preserva la comparación: el contrato de roles (@de-cap-contratos), la ficha de procedencia y el registro de versiones (@de-cap-versionado), la partición sembrada y la pared (@de-cap-particiones), la validez temporal (@de-cap-tiempo) y, en operación, la puerta y el monitor que Parte IV describe. Su dueño natural es la ingeniería de datos, y su unidad de rigor no es el teorema sino el *contrato con prueba de aceptación ejecutable*.

#definition(name: [El invariante del plano de datos])[
  Ninguna pieza del plano de método consume datos sin pasar por el plano de datos: toda estimación llega con su esquema y su semilla, toda evaluación con su partición y su versión, y toda decisión de promoción con su registro. Si una sola pieza toma datos por un camino lateral — un cuaderno suelto, una copia descargada, una columna extraída ad hoc —, el invariante está roto aunque el estimador sea impecable, porque ya nadie puede reconstruir sobre qué versión de qué tabla se estimó qué.
]

La separación de planos no es burocracia: responde a un trade-off real que compite por el tiempo de todo equipo. El enfoque centrado en el modelo optimiza la especificación estadística sobre un dataset fijo, y es el modo dominante de la academia; el centrado en el sistema reparte el esfuerzo entre datos, modelo e infraestructura, y es el único que sobrevive el contacto con datos que cambian y usuarios que dependen del sistema @huyen2022dmls @sculley2015hiddendebt. La discusión de deuda técnica de #cite(<sculley2015hiddendebt>, form: "prose") y la rúbrica operativa de #cite(<breck2017mltestscore>, form: "prose") son las referencias de ese trade-off; este libro las adopta y les añade lo que ellas no tratan: que cuando el objetivo es un *efecto*, la "deuda de datos" no solo degrada la precisión — destruye la comparación que hace de la estimación una afirmación causal.

== El sistema desplegado es una intervención
<sec-de-02-intervencion>

Hasta aquí hablamos del sistema como si mirara el mundo y respondiera. Esa imagen es cómoda y es falsa. En cuanto el sistema decide a quién se le ofrece el subsidio, deja de ser observador: sus decisiones son una intervención sobre el mundo que mide, y esas decisiones se convierten en los datos con los que se entrenará su próxima versión. El bucle es corto:

#figure(
  diagram(
  node-stroke: 0.6pt + gray.lighten(40%),
  node-fill: light,
  node-outset: 4pt,
  node-corner-radius: 3pt,
  spacing: (8mm, 10mm),
  edge-stroke: 0.8pt + accent,
  node((0, 0), [datos $t$]),
  node((2.2, 0), [modelo $t$], fill: rgb("EEF4F8")),
  node((4.4, 0), [decisión $t$], fill: crimson.lighten(92%)),
  node((4.4, 2), [mundo $t+1$]),
  node((0, 2), [datos $t+1$]),
  edge((0, 0), (2.2, 0), "-|>"),
  edge((2.2, 0), (4.4, 0), "-|>"),
  edge((4.4, 0), (4.4, 2), "-|>", [intervención], stroke: (paint: crimson, thickness: 1.4pt)),
  edge((4.4, 2), (0, 2), "-|>"),
  edge((0, 2), (0, 0), "-|>", [realimenta]),
  ),
  caption: [El sistema desplegado como bucle causal. La arista carmesí no observa el mundo: lo modifica. La muestra del modelo de mañana la selecciona el modelo de hoy, y sin un holdout permanente ni registro de la asignación, el bucle destruye la identificación que la edición de método asume.],
) <de-fig-bucle>

Dibujado así, tres consecuencias se hacen visibles y ningún diagnóstico de predicción las detecta. *Primera: la asignación del tratamiento pasa a ser la política del propio modelo.* Si el sistema recomienda siempre la misma acción para un mismo perfil, la probabilidad de tratamiento dado $X$ vale 0 o 1 en los datos nuevos: sin variación no hay con quién comparar, y el efecto deja de estar identificado por los datos que el sistema mismo produce. Es la condición de soporte común, rota por construcción y no por mala suerte. *Segunda: solo se observa el resultado de quienes recibieron la acción.* El crédito no concedido no registra si habría sido pagado: el modelo nuevo aprende de una muestra que el modelo viejo seleccionó, y el sesgo se acumula con cada reentrenamiento @sculley2015hiddendebt. *Tercera: lo que se quiere medir puede cambiar con la política.* Un modelo que dispara una intervención preventiva consigue que muchos casos que marcó no ocurran, y su precisión aparente empeora: cuando la predicción influye en el resultado, la pregunta correcta deja de ser cuánto acertó el modelo y pasa a ser qué habría ocurrido sin él — la predicción _performativa_ de @perdomo2020performative.

La salida no es dejar de decidir con modelos: es diseñar el plano de datos para que el sistema siga siendo identificable mientras opera, con tres prácticas que todo pipeline de decisión debe registrar. *Reservar un holdout permanente*: un grupo pequeño, asignado al azar, que el modelo no gobierna y que garantiza comparación válida mañana (@de-cap-particiones). *Registrar con qué probabilidad se asignó cada acción*: sin ese log no hay corrección posible por la forma en que se decidió. *Mantener un piso de exploración*: una fracción mínima de asignación aleatoria dentro de cada perfil, de modo que ninguno quede sin comparación. Cuestan valor de corto plazo; compran que el efecto siga siendo medible el año próximo.

== Las cinco acciones del sistema
<sec-de-02-acciones>

Un sistema que opera necesita un vocabulario cerrado para lo que hace frente a lo que observa. Este libro usa cinco acciones, siempre con el mismo sentido, de modo que "alertar" o "abstenerse" signifiquen lo mismo en el servicio, en la ficha del modelo, en las pruebas automáticas y en el monitor. La tabla las ordena de la más restrictiva a la menos restrictiva.

#entero[
#table(
  columns: (1.2fr, 3.4fr, 1.4fr),
  align: left,
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Acción*], [*Qué significa*], [*Quién actúa*]),
  [Abstenerse], [El sistema no devuelve un número: responde "sin respuesta" a esa consulta, o a todas, porque no puede sostener el efecto (por ejemplo, la consulta está fuera del soporte declarado).], [El sistema],
  [Revisar identificación], [Un supuesto de identificación dejó de sostenerse o dejó de poder comprobarse. No se promueve ninguna versión nueva hasta que alguien revise el diseño y los supuestos.], [Una persona],
  [Alertar], [Una señal superó su umbral de aviso. El sistema sigue respondiendo y una persona recibe la señal junto con su evidencia.], [Una persona],
  [Reentrenar], [El estimador se ajusta de nuevo con datos nuevos, sin cambiar el estimando ni la población declarados.], [El sistema, bajo una regla de promoción],
  [Continuar], [Ninguna señal supera su umbral. El sistema sigue respondiendo con la versión vigente.], [El sistema],
)
]

Cuando varias acciones aplican a la vez, prevalece la más restrictiva. El orden no es arbitrario. Abstenerse va primero porque un número sin sustento es peor que ningún número. Revisar va antes que alertar, porque un supuesto roto no se arregla con un aviso. Y reentrenar queda por debajo de alertar a propósito: ante un cambio en los datos, lo primero es preguntar qué cambió, y reentrenar solo es la respuesta cuando cambió la distribución de covariables y el efecto sigue siendo el mismo; si el cambio alteró quién recibe el tratamiento o cómo se mide el resultado, reentrenar produce un modelo nuevo para un problema distinto. Qué señal dispara cada acción y con qué umbral lo deciden los capítulos de operación de la Parte IV; aquí solo se fija el vocabulario, y la regla de oro de este libro en producción: *las señales orientan una revisión; no prueban por sí solas la causa del cambio*.

== El esqueleto en el plano de datos
<sec-de-02-esqueleto>

Las piezas del plano de datos de este libro, en el orden en que el dato las recorre:

#figure(
  diagram(
  node-stroke: 0.6pt + gray.lighten(40%),
  node-fill: light,
  node-outset: 4pt,
  node-corner-radius: 3pt,
  spacing: (6mm, 11mm),
  edge-stroke: 0.8pt + accent,
  node((0, 0), [identificación#linebreak()edición de método], fill: rgb("ECF1F6")),
  node((2.6, 0), [estimación], fill: rgb("ECF1F6")),
  node((5.2, 0), [servicio + abstención], fill: rgb("ECF1F6")),
  node((0, 2), [contratos#linebreak()C-01, C-03]),
  node((1.3, 2), [particiones]),
  node((2.6, 2), [registro + linaje]),
  node((3.9, 2), [puerta]),
  node((5.2, 2), [monitor]),
  edge((0, 0.3), (0, 1.7), "--|>"),
  edge((2.6, 0.3), (2.6, 1.7), "--|>"),
  edge((5.2, 0.3), (5.2, 1.7), "--|>"),
  ),
  caption: [Los dos planos del sistema. El plano de método (fila superior) estima y sirve; el plano de datos (fila inferior) sostiene la comparación en cada pieza. Las aristas punteadas son las exigencias que el método le baja al dato.],
) <de-fig-dos-planos>

+ *Contrato de roles (C-01, Cap. #ref(<de-cap-contratos>, supplement: none)):* cada columna, un solo rol; el esquema viaja con los datos; nada entra como covariable sin declararse.
+ *Ficha de procedencia y registro (C-09, Cap. #ref(<de-cap-versionado>, supplement: none)):* cada versión de datos y de artefacto con hash; el linaje dato → estimador → promoción; el alias `champion` como único camino a producción.
+ *Partición sembrada y pared (C-10, Cap. #ref(<de-cap-particiones>, supplement: none)):* entrenamiento, validación y prueba como estructura versionada; lo reservado para evaluación del otro lado del muro.
+ *Auditoría temporal (C-03, Cap. #ref(<de-cap-tiempo>, supplement: none)):* ninguna covariable entra sin marca de tiempo verificada ni rol resuelto.
+ *Puerta y monitor (Parte IV):* la decisión de promover con estados `pasa`, `alerta`, `falla`, y las señales que después obligan a revisar.

La lista es deliberadamente corta. Una anatomía confiable no es la que tiene más piezas sino la que, ante una consulta — *¿sobre qué versión de qué tabla se estimó este número, con qué roles, en qué partición, para qué estimando?* — responde sin depender de la memoria de nadie.

== Caso canónico: una traza por el sistema
<sec-de-02-traza>

#caso-canonico("La consulta completa sobre `real/jobs`")[
  El benchmark del repositorio de referencia incluye el escenario `real/jobs`, una réplica sintética estilo LaLonde (1986) del programa NSW, con 1 722 unidades y verdad conocida guardada al otro lado de la pared. Recorremos una consulta — *¿cuál es el efecto del programa de entrenamiento sobre los ingresos de 1978?* — pieza por pieza, usando solo lo que los archivos declaran (script con traza completa en el repositorio):

  #entero[
  #table(
    columns: (1.2fr, 4.4fr),
    align: (left, left),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Pieza*], [*Lo que el archivo aporta*]),
    table.hline(stroke: 0.3pt),
    [1. Dato bruto], [`observed.csv`: 1 722 filas, 10 columnas.],
    [2. Contrato C-01], [Tratamiento `treatment`, resultado `re78`; 8 covariables pre-tratamiento declaradas como conjunto de ajuste en `identification.json`.],
    [3. Procedencia], [`metadata.json`: asignación 722 experimental + 1 000 observacional (estilo LaLonde); el origen declara qué es real y qué es sintético.],
    [4. Partición C-10], [`splits.json`, semilla 20240701, método estratificado por tratamiento 60/20/20: 1 033 train / 344 validación / 345 prueba, cada uno con su hash SHA-256.],
    [5. Comparación cruda], [$E[Y|D=1] - E[Y|D=0] = 1\\\\,644\\\\,9$ USD ($E[Y|D=1] = 8\\\\,364\\\\,8$, $E[Y|D=0] = 6\\\\,719\\\\,9$; $P(D=1)=0\\\\,254$).],
    [6. Referencia del DGP], [El diseño fija el ATE en torno a 1 800 USD, fuera de la tabla observada: la pared, vigente.],
    table.hline(stroke: 0.6pt),
  )
  ]

  La lectura del paso 5 no es el ATE: mezcla el efecto con la selección del programa, en la dosis exacta de @de-eq-descomposicion (los participantes del NSW no eran una muestra aleatoria de la población con la que se les compara). Que esa comparación crude llegue al plano de método *con* su esquema, su procedencia, su partición y su hash — y no como una tabla suelta — es el trabajo del plano de datos, y la única razón por la que la corrección posterior puede verificarse.
]

#repo-ref[
  Escenario completo: #code[data_benchmark_causal/causal_benchmark_synthetic/datasets/real/jobs/] (`metadata.json`, `identification.json`, `splits.json`, `observed_*.csv`). Traza reproducible: #code[Causal_AI/scripts/cap02_traza.py]. Implementación del registro y la puerta: #code[04_produccion_causal/src/causalops/].
]

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ Enumere los componentes de un sistema de ML según @huyen2022dmls y asigne cada uno a uno de los dos planos. ¿Qué componente queda disputado entre ambos? _Pista:_ la preparación de variables es el punto de fricción clásico: es ingeniería, pero traiciona la identificación si ignora los tiempos (Cap. #ref(<de-cap-tiempo>, supplement: none)).

+ Explique por qué reentrenar con datos nuevos es más delicado en un sistema causal que en uno predictivo, usando el bucle de la #ref(<de-fig-bucle>, supplement: [figura]). _Pista:_ piense en quién seleccionó la muestra del próximo modelo.

+ Un banco decide créditos con un modelo y cada mes reentrena con los créditos otorgados. Dibuje el bucle y responda: ¿qué llega al modelo del mes siguiente sobre los solicitantes rechazados? ¿Qué cambia si el banco asigna al azar el 2 % de los créditos? _Pista:_ las dos prácticas del holdout y del piso de exploración.

+ Para cada situación, indique cuál de las cinco acciones aplica y si prevalece alguna: (a) una covariable se desplazó y la señal superó su umbral; (b) llega una consulta fuera del soporte; (c) una política interna hizo que el perfil alto jamás reciba la oferta; (d) ninguna señal supera su umbral. _Pista:_ la respuesta de (c) empieza por preguntarse si cambió la asignación, no por reentrenar.

+ En el esqueleto de la #ref(<de-fig-dos-planos>, supplement: [figura]), señale qué pieza detecta cada uno de estos fallos, y en qué capítulo aparece su contrato: columna renombrada en el origen; tabla que cambió tras el registro; partición reutilizada dos veces; covariable calculada con el resultado. _Pista:_ cada fallo tiene exactamente una pieza destinataria; si hay dos sin pieza, el esqueleto tiene agujero.

=== Notas bibliográficas

#cite(<huyen2022dmls>, form: "prose") es la fuente de la filosofía sistema-céntrica y del marco de cuatro requisitos que este capítulo adapta a los dos planos. #cite(<sculley2015hiddendebt>, form: "prose") documenta la deuda técnica acumulada en el resto del sistema y sus bucles de retroalimentación ocultos, que aquí reaparecen como el bucle causal de la #ref(<de-fig-bucle>, supplement: [figura]). #cite(<breck2017mltestscore>, form: "prose") aporta la rúbrica operativa complementaria, y #cite(<paleyes2022challenges>, form: "prose") la evidencia empírica de que los fallos no viven en el algoritmo. La predicción performativa es de @perdomo2020performative. Sobre el eje de este libro en particular, la tradición de ingeniería de datos de @kleppmann2017 y @reis2022fundamentals es el referente de la robustez de pipelines que aquí se especializa al enunciado causal.

#verdad-datos[
  Que el modelo entrena bien no dice nada sobre si el sistema puede sostener su afirmación: la afirmación vive en la comparación, y la comparación vive en el plano de datos. Lo que debe ser verdad en los datos: que cada pieza del sistema consuma por el canal del invariante — esquema, semilla, partición, versión — y que el bucle de intervención no borre la única variación que permite medir el efecto (holdout permanente, piso de exploración, log de asignación). Se comprueba preguntando la consulta del esqueleto — versión, roles, partición, estimando — y exigiendo respuesta sin memoria humana; en el caso canónico esa pregunta se responde con archivos, no con opiniones.
]
