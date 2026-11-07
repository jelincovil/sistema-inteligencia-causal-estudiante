// Capítulo 15: Tarjetas, registro y auditoría end-to-end.
// Edición de ingeniería de datos (main_de.typ). Caso canónico: scripts/cap15_tarjeta.py (semilla 20260715).
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Tarjetas, registro y auditoría end-to-end]
<de-cap-tarjeta>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Nadie puede reconstruir qué se estimó, sobre qué datos, con qué supuestos y bajo qué umbrales, sin leer el código],
    [*Decisión:*], [La tarjeta viaja con el artefacto y es la única fuente de verdad sobre el estimando, los supuestos y los umbrales],
    [*Pieza contratada:*], [Contrato C-05 (tarjeta causal): estimando, supuestos clasificados, umbrales, limitaciones y uso previsto],
    [*Casos canónicos:*], [El flujo completo sobre real/jobs: pregunta → esquema → splits → ATE 1596.0 → tarjeta → v0001 → puerta pasa → champion → servicio (semilla 20260715)],
    [*Cierra:*], [El libro entero en una corrida: cada contrato de los capítulos 3–14 deja su artefacto en la traza],
  )
]

== El cierre del libro en una corrida
<sec-de-15-cierre>

Este capítulo no introduce una pieza nueva del pipeline: introduce la pieza que las une. La tarjeta causal es el documento que viaja con el artefacto y declara, en un formato que una máquina puede validar, lo que el sistema sostiene y lo que no: el estimando, la población, los supuestos con su clase, los umbrales de la puerta, las limitaciones y el uso previsto. Sin ella, cada pregunta de auditoría — ¿qué se estimó?, ¿sobre qué versión del dato?, ¿con qué supuestos?, ¿bajo qué umbrales se promovió? — se responde leyendo código o preguntando a quien lo escribió, y ambas respuestas caducan.

La corrida end-to-end de este capítulo ejercita los doce contratos del libro en orden, sobre el escenario `real/jobs` del benchmark. Cada paso deja un artefacto verificable; la traza completa cabe en una pantalla y un equipo puede auditarla en minutos.

#figure(
  flujo-lineal(([pregunta], [esquema#linebreak()C-01], [splits#linebreak()C-10], [estimación#linebreak()C-12], [tarjeta#linebreak()C-05], [registro#linebreak()C-09], [puerta#linebreak()C-06], [champion], [servicio#linebreak()C-04])),
  caption: [La corrida end-to-end del libro: cada contrato deja su artefacto y la traza es auditable de punta a punta. La tarjeta (C-05) es el documento que une todas las piezas.],
) <de-fig-end-to-end>

== El contrato C-05: tarjeta causal
<sec-de-15-contrato>

#contrato(
  "C-05",
  "Tarjeta causal del modelo",
  operaciones: [
    _construir_: produce la tarjeta desde los resultados de la estimación y la puerta, con los supuestos clasificados; _validar_: comprueba la estructura contra el esquema (campos obligatorios, clases de supuesto, umbrales presentes); _registrar_: la tarjeta viaja con la versión en el registro (C-09) y el servicio la lee para responder.
  ],
  entrada: [
    La pregunta declarada (estimando, población, supuestos). Los resultados de la estimación (efecto, SE, IC, semilla). El resultado de la puerta (chequeos con valores y umbrales). La sensibilidad de los supuestos no observables.
  ],
  salida: [
    Un documento JSON válido con: estimando, datos (n, hash, fuente), estimación (método, efecto, SE, IC, semilla), supuestos (observables con prueba y umbral; no observables con justificación, sensibilidad y criterio de revisión), umbrales de la puerta, limitaciones y uso previsto.
  ],
  invariantes: [
    (1) Todo supuesto no observable lleva su sensibilidad o la declaración explícita de que no hay cuantificación válida, y su criterio de revisión. (2) Todo supuesto observable lleva su prueba, su valor y su umbral. (3) El hash del dataset y la semilla son parte de la tarjeta. (4) La tarjeta valida contra el esquema antes de registrarse: una tarjeta inválida no se promueve. (5) Las limitaciones incluyen el soporte: la tarjeta dice dónde el efecto no aplica. (6) El uso previsto declara qué decisiones soporta y cuáles no.
  ],
  fallos: [
    Una tarjeta sin supuestos no observables: parece más limpia y miente. Un supuesto observable sin umbral: la puerta no puede evaluarlo. Una tarjeta que no valida contra el esquema y se registra igual. Un uso previsto que promete más de lo que el estimando cubre.
  ],
  aceptacion: [
    (a) La tarjeta del caso canónico valida contra el esquema con estimando, datos, estimación, supuestos clasificados y umbrales. (b) El registro la guarda con hash y semilla. (c) El servicio la lee para responder dentro del soporte y abstenerse fuera. (d) Una tarjeta sin supuestos no observables o sin umbrales no valida. Semilla 20260715.
  ],
)

== Caso canónico: la corrida completa
<sec-de-15-caso>

#caso-canonico("De la pregunta al servicio en nueve pasos auditables")[
  Sobre `observed_train.csv` de `real/jobs` (semilla 20260715 del script), la corrida completa produce esta traza:

  #entero[
  #table(
    columns: (0.6fr, 1.6fr, 3.6fr),
    align: (center, left, left),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Paso*], [*Pieza*], [*Artefacto que deja*]),
    table.hline(stroke: 0.3pt),
    [1], [Pregunta], [ATE de treatment sobre re78, población de 1 033 unidades, supuestos declarados],
    [2], [Esquema C-01], [tratamiento=treatment, resultado=re78, 8 covariables],
    [3], [Splits C-10], [hash OK, semilla 20240701, la pared vigente],
    [4], [Estimación], [ATE 1 596,0, SE 301,6, IC [1 004,8 -- 2 187,3], ESS/n 0,71],
    [5], [Tarjeta C-05], [estimando + supuestos clasificados + umbrales, válida contra esquema],
    [6], [Registro C-09], [v0001 con manifest, hash del dataset y semilla],
    [7], [Puerta C-06], [sana pasa, deriva alerta, positividad falla],
    [8], [Champion], [v0001 — solo la ventana sana en pasa se promueve],
    [9], [Servicio C-04], [dentro: respuesta con efecto e IC; age 99: abstención sin número],
    table.hline(stroke: 0.6pt),
  )
  ]

  La trazabilidad completa: pregunta → esquema → splits (hash) → ATE 1 596,0 → tarjeta → v0001 → puerta pasa → champion → servicio. El hash del dataset (`cd5a772ead64f416…`) permite a cualquier persona verificar que el número servido es el registrado. El humo de la corrida pasa: hash OK, puerta pasa para la ventana sana, servicio responde dentro y se abstiene fuera.
]

#repo-ref[
  Script #code[Causal_AI/scripts/cap15_tarjeta.py] (semilla 20260715) reproduce la traza completa. La implementación de referencia de la tarjeta con validación contra esquema: #code[04_produccion_causal/src/causalops/tarjeta.py]; el flujo end-to-end: #code[flujo.py]; el esquema: #code[04_produccion_causal/esquemas/causal-model-card.local.schema.json].
]

== Qué audita una persona con esta traza
<sec-de-15-auditoria>

La corrida end-to-end convierte las preguntas de auditoría en verificaciones de artefactos. Esta sección desarrolla cada una, porque la diferencia entre un sistema auditable y uno que solo parece auditable está en los detalles:

+ *¿Qué se estimó?* La tarjeta lo dice: ATE de treatment sobre re78, efecto total, población de entrenamiento. No se necesita leer código ni preguntar a quien lo escribió: el JSON es la fuente de verdad.

+ *¿Sobre qué datos?* El hash del dataset en la tarjeta y el manifest del registro lo verifican: recomputar el SHA-256 del archivo de entrenamiento y comparar con el declarado. Si no coincide, la versión registrada no es la que se sirvió — y eso es un fallo del registro, no del estimador.

+ *¿Con qué supuestos?* La tarjeta los clasifica: observables con prueba y umbral, no observables con justificación y criterio de revisión. Un supuesto observable sin umbral no es un supuesto: es un deseo. Un supuesto no observable sin criterio de revisión es una deuda que nadie programó.

+ *¿Bajo qué umbrales se promovió?* La tarjeta declara los umbrales y la puerta registró su decisión con el motivo. Si alguien cambió un umbral después de ver la señal para que la versión pasara, la fecha del umbral en la tarjeta y la fecha de la promoción en el registro no coinciden — y esa discrepancia es auditable.

+ *¿Sigue siendo válido?* El monitor del Capítulo 14 evalúa las ventanas contra la misma referencia y produce una acción. La referencia es fija: si alguien la cambió sin registrar, las alertas no son comparables en el tiempo.

+ *¿Qué pasa si la consulta cae fuera del soporte?* El servicio se abstiene sin número, y la tarjeta declara el soporte. La abstención no es un error 5xx: es una respuesta de primera clase con estado y motivo.

Ninguna de estas respuestas requiere leer código. Esa es la diferencia entre un prototipo y un sistema auditable, y es el cierre del libro: el plano de datos entrega, para cada afirmación causal que el sistema hace, la evidencia de que la afirmación sigue siendo computable, registrada y vigente.

== El proceso de auditoría paso a paso
<sec-de-15-proceso>

Un auditor que llega a esta traza sin contexto previo puede verificarla en cinco pasos, en este orden:

#entero[
#table(
  columns: (0.5fr, 2fr, 3fr),
  align: (center, left, left),
  stroke: none,
  table.hline(stroke: 0.6pt),
  table.header([*Paso*], [*Qué verificar*], [*Cómo*]),
  table.hline(stroke: 0.3pt),
  [1], [La pared], [Intentar cargar `truth_*.csv`; debe fallar con `FileNotFoundError` — ese fallo es el contrato cumplido],
  [2], [El hash del dataset], [Recomputar el SHA-256 del CSV de entrenamiento y comparar con el manifest del registro; si no coincide, la versión no es la que se sirvió],
  [3], [La puerta], [Verificar que ninguna versión en estado `falla` llegó al alias `champion`; si hay promociones en `alerta`, buscar la aceptación explícita registrada],
  [4], [La tarjeta], [Validar el JSON contra el esquema: estimando, supuestos clasificados, umbrales, limitaciones, uso previsto; una tarjeta sin no observables es inválida],
  [5], [El servicio], [Enviar una consulta dentro del soporte (debe responder con efecto e IC) y una fuera (debe abstenerse sin número); dos idénticas deben devolver lo mismo],
  table.hline(stroke: 0.6pt),
)
]

Los cinco pasos se corren en minutos. El tiempo que no se gasta en verificar se gasta en discutir: *¿es el estimando correcto para la decisión que el sistema apoya?* — y esa pregunta no la responde la traza, la responde el dominio.

== Mantenimiento de la tarjeta
<sec-de-15-mantenimiento>

La tarjeta no es un documento que se escribe una vez: es un artefacto vivo que viaja con cada versión. Cuando algo cambia — el estimador, el dataset, los umbrales, los supuestos — la tarjeta cambia con él, y el registro conserva la historia:

#entero[
#table(
  columns: (1.6fr, 2fr, 2fr),
  align: (left, left, left),
  stroke: none,
  table.hline(stroke: 0.6pt),
  table.header([*Qué cambia*], [*Qué pasa con la tarjeta*], [*Qué queda en el registro*]),
  table.hline(stroke: 0.3pt),
  [El dataset], [El hash cambia; la tarjeta se reescribe con el nuevo hash], [Una versión nueva con su manifest],
  [El estimador], [El método y la estimación cambian; la tarjeta se reescribe], [Una versión nueva con su estimación],
  [Los umbrales], [La tarjeta se reescribe con los nuevos umbrales y su fecha de calibración], [La puerta registra la decisión con los umbrales vigentes],
  [Un supuesto], [Si es observable: cambia su valor o su umbral; si es no observable: cambia su sensibilidad o su criterio de revisión], [El monitor evalúa con los umbrales de la tarjeta vigente],
  [El soporte], [Los rangos cambian; la abstención del servicio se recalibra], [El servicio lee la tarjeta de la versión vigente],
  table.hline(stroke: 0.6pt),
)
]

La regla es simple: *cada versión del sistema tiene su tarjeta, y el alias `champion` apunta a una de ellas*. Si alguien quiere saber qué supuestos sostenían la versión de la semana pasada, lee la tarjeta de esa versión — no la vigente. El registro (@de-cap-versionado) garantiza que esa historia no se pierde.

== La tarjeta como gobernanza
<sec-de-15-gobernanza>

Hay una lectura del C-05 que va más allá de la documentación: la tarjeta es la pieza que hace *gobernables* los sistemas causales. Sin ella, gobernar un sistema de decisión significa confiar en quien lo construyó; con ella, significa verificar artefactos que cualquiera puede leer.

La distinción tiene consecuencias operativas. Un sistema sin tarjeta puede ser correcto, pero su corrección es invisible: nadie puede distinguir entre «funciona porque los supuestos se sostienen» y «funciona porque nadie ha mirado». Un sistema con tarjeta puede estar mal, pero su error es *auditable*: alguien puede leer los supuestos, ver cuál se rompió y saber qué corregir. La diferencia entre los dos mundos no es la calidad del sistema sino la *velocidad de corrección* cuando algo falla.

La tarjeta también cambia la conversación entre quien construye el sistema y quien lo usa. Sin tarjeta, la conversación es «confía en mí, funciona». Con tarjeta, la conversación es «estos son los supuestos que sostienen el número, aquí están sus pruebas y sus umbrales, y aquí está qué pasaría si se rompen». La segunda conversación es incómoda — obliga a declarar lo que no se sabe — pero es la única que escala más allá del equipo que construyó el sistema.

== Qué queda fuera del alcance
<sec-de-15-limites>

Este capítulo cierra el libro, y lo cierra declarando lo que el sistema *no* hace. La traza end-to-end garantiza que cada afirmación causal del sistema es computable, registrada y vigente. No garantiza que la afirmación sea *correcta* — la corrección depende de que los supuestos declarados sean verdaderos, y eso lo decide el dominio, no la ingeniería.

Tres límites que el libro deja explícitos:

+ *La confusión no observada no tiene señal.* El monitor del Capítulo 14 vigila cuatro señales observables; ninguna detecta una causa no medida que afecte al tratamiento y al resultado. La tarjeta lo declara como supuesto no observable con su sensibilidad, pero la sensibilidad es una cota, no una prueba.
+ *La validez externa no se computa.* La tarjeta declara el soporte de las covariables, pero no puede declarar que la población futura se parecerá a la de entrenamiento. Eso lo vigila el monitor con deriva de covariables, pero la deriva no prueba que la función causal sea la misma.
+ *El estimando correcto es una decisión, no un cálculo.* Todo el aparato de este libro entrega la mejor estimación posible del estimando declarado. Si el estimando declarado no sirve a la decisión que el sistema apoya, ningún rigor estadístico lo arregla.

Estos límites no son defectos del sistema: son las fronteras honestas de lo que la ingeniería de datos puede garantizar. Lo que este libro ha construido es la condición necesaria — el pipeline que preserva la identificación — para que la decisión causal sea defendible. La condición suficiente sigue siendo humana: el dominio que declara los supuestos, la auditoría que los verifica y el criterio que decide cuándo dejar de creer en el número.

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ Una tarjeta llega sin supuestos no observables. ¿Por qué el contrato la rechaza, y qué parecería estar prometiendo esa tarjeta? _Pista:_ sin la clase no observable declarada, la tarjeta sugiere que todo supuesto es verificable — y eso es falso por construcción.

+ El servicio lee la tarjeta para responder. ¿Qué tres campos de la tarjeta usa en cada consulta, y qué pasaría si faltara cada uno? _Pista:_ el efecto y su IC (la respuesta), el soporte (la abstención) y la versión (la trazabilidad).

+ Su equipo reentrena con datos nuevos y la puerta produce alerta. Describa los artefactos que quedan en el registro y qué decisión humana falta. _Pista:_ la versión nueva con su manifest y su estado alerta; falta la aceptación explícita registrada antes de promover.

=== Notas bibliográficas

La tarjeta causal extiende la model card de @mitchell2019modelcards con la clasificación de supuestos del Capítulo 2 de este libro y los umbrales de la puerta del Capítulo 12. El registro con hash y alias champion es la pieza del Capítulo 4 (C-09). La corrida end-to-end que cierra el capítulo es la demostración que la guía del proyecto final del curso exige: escenario sano se registra y promueve, positividad bloquea, cambio de identificación alerta.

#verdad-datos[
  Que toda afirmación causal del sistema llegue con su tarjeta válida — estimando, supuestos clasificados, umbrales, limitaciones y uso previsto — registrada con hash y semilla, promovida por una puerta que dejó su decisión con motivo, y servida por un servicio que responde dentro del soporte y se abstiene fuera. Se comprueba con la semilla 20260715: la traza completa de nueve pasos sale en verde y cada artefacto es verificable sin leer código. Lo que la traza no certifica: que los supuestos declarados sean verdaderos — eso lo decide el dominio, la auditoría humana y el tiempo. Lo que sí certifica: que nadie puede cambiar el sujeto del enunciado sin que el registro lo detecte.
]
