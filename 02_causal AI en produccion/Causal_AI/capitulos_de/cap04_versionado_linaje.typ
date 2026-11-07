// Capítulo 4: Versionado, linaje e inmutabilidad (el contrato C-09).
// Edición de ingeniería de datos (main_de.typ). Caso canónico: scripts/cap04_linaje.py,
// con los hashes reales del escenario real/jobs del benchmark.
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Versionado, linaje e inmutabilidad]
<de-cap-versionado>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Una afirmación causal es un enunciado sobre un conjunto de datos concreto; si la tabla cambia, el enunciado queda huérfano],
    [*Decisión:*], [Versiones inmutables con hash de contenido, y promoción atómica a través de un alias único (`champion`)],
    [*Pieza contratada:*], [El contrato C-09 (registro de versiones y linaje), con su puerta de integridad],
    [*Acompaña:*], [La ficha de procedencia del tratamiento: quién asignó, con qué información, bajo qué regla],
    [*Caso canónico:*], [Registro de `real/jobs`, mutación detectada y promoción atómica (hashes reales, script con salida verificable)],
  )
]

== El problema: la afirmación y su sujeto
<sec-de-04-problema>

Una afirmación causal es un enunciado sobre un sujeto concreto: _el efecto del programa es de 1 800 dólares, estimado sobre la tabla X con el esquema Y_ — y su fuerza depende de que el sujeto siga existiendo y siga siendo el mismo. En un pipeline sin versionado, la frase se dice igual pero el sujeto ya no significa nada: el "mismo" archivo se sobrescribe con una extracción nueva, dos personas leen dos copias llamadas igual, y nadie decide si la estimación publicada la semana pasada corresponde a la tabla de ayer o a la de hoy. El caso más barato es el teorista que dice "estime con los datos de enero" y nadie sabe cuál archivo era; el más caro es el sistema que promueve a producción sobre una tabla `train_latest.csv` que ayer tenía 1 033 filas y hoy 1 041, y la promoción queda sellada contra algo que ya nadie puede reconstruir.

La tradición de los pipelines robustos entiende la solución como inmutabilidad: lo que entró no se edita, se sustituye por una versión nueva que deja la anterior intacta. @kleppmann2017 la defiende como el principio de los logs de eventos, y @reis2022fundamentals la traslada al ciclo de vida del dato. Este libro la exige con una razón adicional, que los dos no tratan: *el enunciado causal es más frágil que el predictivo*. Una predicción sobre una tabla que cambió es algo obsoleto pero sigue existiendo; un efecto estimado sobre una tabla que cambió ya no es la misma comparación: cambió posiblemente su mecanismo de asignación, su tiempo y su soporte, los tres platos de la identificación. Por eso el versionado de datos, aquí, es una prueba de identificación además de una higiene de pipeline.

== El hash de contenido: la identidad de un dataset
<sec-de-04-hash>

La herramienta mínima del versionado es el *hash de contenido*: una función que toma el archivo y devuelve una larga cadena hexadecimal, con la propiedad de que cambiarle un byte cambia la cadena. Este libro usa SHA-256 por convención, y la regla operativa es la de los _content-addressable storage_ de la ingeniería de datos: *el nombre de una versión de datos es su hash, no una fecha ni un adjetivo del equipo*. Una fecha engaña ("enero" existe dos veces, si se reextrajo el proceso); un hash no.

El benchmark del repositorio de referencia lo hace literal: en `splits.json` del escenario `real/jobs` el productor publica, por cada partición, el `file_sha256` del archivo y un `row_id_sha256` de los índices involucrados, más el bloque `validation` con `covers_all_rows: true` y `no_overlap: true`. Es una promesa escrita: el consumidor recalcula y comprueba. Sobre los archivos reales, ambos cálculos coinciden byte a byte (el entrenamiento, `cd5a772ead64f4164c…`, es lo que el productor declara y lo que el consumidor recomputa), y si algún byte cambiara en camino, la rectificación lo detecta sin análisis de contenido alguno: la identidad de un dataset es una sola línea.

== La ficha de procedencia del tratamiento
<sec-de-04-procedencia>

El hash le dice a un equipo qué tabla está describiendo; no le dice nada sobre cómo esa tabla llegó a la forma que tiene. La pieza de procedencia que este libro exige, inspirada en la lectura de los datos de entrenamiento como diseño antes que como insumo (@huyen2022dmls, Cap. 4), es la *ficha de procedencia del tratamiento*:

+ *Mecanismo de asignación*: ¿la asignación fue aleatorizada, cuasi-aleatorizada (un umbral administrativo, una lotería institucional) u observacional pura — la decisión histórica de personas o reglas?
+ *La información del asignador*: ¿qué sabía quien asignó, y coincide con las covariables observadas? Si el asignador usó algo que no se midió, lo dota todo: la "no confusión condicional" es un supuesto sobre ese punto exacto.
+ *La relación temporal*: la asignación del tratamiento es anterior a la medición del resultado, y las covariables declaradas pre-tratamiento lo son de verdad (@de-cap-tiempo).
+ *La regla de elegibilidad*: cualquier corte administrativo que excluyó filas antes de la tabla — geografía, fecha, umbrales — y que determina la población del estimando.

La ficha es un requisito previo a toda estimación, y es parte del registro: cuando cambia el origen — otra regla de elegibilidad, otro canal de asignación —, el estimador vigente pierde su procedencia válida aunque su código no haya cambiado, y el registro debe reflejarlo. La extensión observacional vs experimental del escenario `real/jobs` es el ejemplo corriente: la misma pregunta corre sobre una submuestra aleatorizada y sobre una observacional, y la ficha de procedencia es exactamente lo que las distingue (este contraste fundó la literatura moderna de evaluación de programas, de @lalonde1986 y @dehejia1999causal, que el Cap. #ref(<de-cap-anatomia>, supplement: none) recorre como traza).

== El contrato C-09: registro de versiones y linaje
<sec-de-04-c09>

#contrato(
  "C-09",
  "Registro de versiones y linaje",
  operaciones: [
    _registrar_: crea una versión inmutable con manifiesto, a partir del artefacto validado (estimación + ficha), citando el hash del conjunto de datos; `verificar_integridad`: recomputa los hashes de los archivos de una versión y los compara con el manifiesto; _promover_: apunta un alias (típicamente `champion`) a una versión; _resolver_: lee a qué versión apunta el alias.
  ],
  entrada: [
    El artefacto estimado y su ficha validada, el hash SHA-256 del conjunto de datos, y la decisión de puerta que acompaña (Parte IV; aquí queda el registro). El hash del código, idealmente el commit del repositorio limpio.
  ],
  salida: [
    Una carpeta de versión `vNNNN` con `estimacion.json`, `tarjeta.json` y `manifest.json`; el alias `champion` apuntando a la versión promovida. Leer alias devuelve la versión íntegra.
  ],
  invariantes: [
    (1) Las versiones no se editan: registrar crea, nunca sobrescribe; un cambio produce otra versión. (2) El manifiesto de cada versión contiene los hashes de sus archivos y el dataset con el que estimó. (3) La integridad recomputa y compara; no confía en nada más. (4) El alias se reescribe de forma atómica (archivo temporal y renombrado, nunca edición in-place), de modo que ningún lector ve un apuntador a mitad de cambio. (5) Una versión con puerta `falla` nunca se promueve; una con `alerta` solo si alguien la acepta explícitamente. (6) Todo registro cita además del hash del dato, la semilla y la versión de código con la que se estimó.
  ],
  fallos: [
    Alguien edita un archivo ya registrado (la integridad lo detecta en el siguiente chequeo). La tabla de datos es sustituida sin registro (el hash dejó de coincidir). Una promoción que escribe el alias in-place y un lector concurrente recoge un apuntador roto. Registrar sin la decisión de puerta que acompaña. Versiones duplicadas por ruido de formateo externo al contenido.
  ],
  aceptacion: [
    (a) Se registra `v0001` y la integridad pasa. (b) Se muta una copia de cualquier archivo de la versión y la verificación falla, nombrando el archivo. (c) Champion se promueve y resuelve en la versión promovida; el proceso nunca entrega un apuntador parcial. (d) Una versión con puerta `falla` no promociona por más que se invoque. (e) Dos registros en secuencia sobre contenido igual dejan dos versiones históricas, no una sobreescrita.
  ],
)

#caso-canonico("El registro y una mutación silenciosa")[
  Con los archivos reales del escenario `real/jobs`, el script del repositorio registra una versión y luego intenta estropearla. El manifiesto de `v0001` queda así — cifras recalculadas, no citadas de memoria:

  #entero[
  #table(
    columns: (2.2fr, 3.4fr),
    align: (left, left),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Archivo*], [*sha256*]),
    table.hline(stroke: 0.3pt),
    [`observed_train.csv`], [`cd5a772ead64f416…`],
    [`observed_validation.csv`], [`cee91dab6987ee3c…`],
    [`observed_test.csv`], [`2093dbef51d20b43…`],
    [`splits.json`], [`101274c23c9c9747…`],
    table.hline(stroke: 0.6pt),
  )
  ]

  El hash del entrenamiento coincide con el declarativo del productor en `splits.json` — la mesa de la verdad entre dos computaciones independientes. Después se inyecta una mutación: dos filas espurias al final del entrenamiento. El hash pasa a `1de3fd53c1baf11b…` y la puerta de integridad del C-09 bloquea la promoción: *los datos mutados no son la versión registrada*. El alias `champion` apunta a `v0001` tras una escritura atómica: archivo temporal y renombrado, nunca edición in-place.
]

#figure(
  cadena-linaje(
    (([`observed_train.csv`] + linebreak() + [sha256 cd5a77…]), ([train + 2 filas] + linebreak() + [sha256 1de3fd…])),
    (([estimación v0001] + linebreak() + [semilla 42 · puerta pasa]),),
    ([champion] + linebreak() + [→ v0001]),
  ),
  caption: [El linaje mínimo auditable: cada versión de dataset con su hash alimenta la estimación que la consumió, y el alias queda apuntando a la versión promovida. El mutante de la derecha no llega al alias: la puerta de integridad lo detiene en el registro.],
) <de-fig-linaje>

El registro cita también la semilla y el código. La semilla porque la diferencia de medias es una función del azar si el estimador lo tiene; el código como el commit del árbol limpio — si hay cambios sin confirmar, el registro no cita ningún hash de código y la reproducibilidad queda deuda (@de-fig-linaje): la implementación de referencia decide justamente esto con una función de "commit limpio" que solo informa el hash de HEAD si el árbol está limpio.

#repo-ref[
  Registro local de referencia (versiones inmutables, manifest con hashes, alias atómico `champion`, sin MLflow): #code[04_produccion_causal/src/causalops/registro_local.py]. Caso reproducible: #code[Causal_AI/scripts/cap04_linaje.py] (con los hashes reales del escenario). La promoción, la puerta y la ficha son contratos de la Parte IV: aquí queda que el registro los consume, no los decide.
]

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ Un equipo renombra `train_v3.csv` a `train.csv` "porque downstream espera ese nombre". ¿Qué rompe, si produce una nueva versión de la tabla y por qué el hash del registro no es el mismo que el esperado por el promotor de champion? _Pista:_ el alias responde a una versión íntegra; el nombre del archivo no es su identidad.

+ Explique por qué el hash del entrenamiento de `real/jobs`, recalculado por dos procesos independientes, tiene que coincidir para que el canal productor-consumidor funcione. ¿Qué falla si los dos procesos recalculan sobre archivos "iguales" pero con distinto orden de filas? _Pista:_ el orden de filas es contenido: el hash los distingue; la equivalencia semántica queda con el productor, que ordena de forma determinista.

+ La mutación del caso canónico agrega dos filas al final. Proponga una mutación más sutil que pase el hash del entrenador pero rompa la estimación de igual manera: ¿quién la detecta — el C-09, el C-01, o nadie? _Pista:_ si se muta solo `splits.json` dejando la tabla intacta, el linaje deja de ser el del registro.

+ La ficha de procedencia dice `mecanismo: observacional administrativo`. El equipo quiere una frase que suene mejor y escribe `cuasi-experimental`. ¿Qué cambia, si todo lo demás queda igual? _Pista:_ la frase es una afirmación sobre la información del asignador; si miente, la puerta no la detecta y el estimando cambia de supuesto. De ahí que la procedencia sea una declaración auditada, no una etiqueta.

+ ¿Es correcto versionar las particiones (@de-cap-particiones) dentro del mismo registro C-09, o el benchmark bien pudo haberlo dejado adyacente en `splits.json`? Defienda los dos diseños con las exigencias del contrato. _Pista:_ el hilo es único e inmutable también si la tabla y su partición viajan juntas; la separación en dos archivos agrega una arista de linaje que hay que auditar igual.

=== Notas bibliográficas

La inmutabilidad como fundamento de pipelines confiables es de @kleppmann2017 (logs y store append-only) y @reis2022fundamentals (ciclo de vida del data lake). Ledger de contenido direccionable por hash: la tradición de los content-addressable storage, aquí aplicada al dataset como artefacto auditable. La contraposición experimental/observacional del escenario de escuela LaLonde es de @lalonde1986 y @dehejia1999causal, inmersa en este libro como traza permanente (@de-cap-anatomia). La lectura de los datos de entrenamiento como diseño en vez de insumo es de @huyen2022dmls, Cap. 4. El argumento de que procedencia y promoción son una misma pieza de linaje es la contribución propia del capítulo: los manifiestos del benchmark lo instancian, y `registro_local.py` los implementa.

#verdad-datos[
  Que todo número publicado del sistema responda a una versión con hash del dataset, una semilla y un commit limpio, con el alias `champion` como único punto de promoción — reescrito de forma atómica, sin edición in-place. Que la ficha de procedencia del tratamiento nombre el mecanismo de asignación, la información del asignador, la relación temporal y la regla de elegibilidad, y que una mutación del archivo quede detectada por la puerta de integridad, como en el caso canónico. Lo que no se prueba aquí: que la versión promovida siga siendo válida en sus supuestos — eso es trabajo de los contratos de la Parte IV; el registro solo garantiza que nadie intercambió el sujeto del enunciado.
]
