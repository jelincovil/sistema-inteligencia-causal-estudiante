// Capítulo 5: Particiones sembradas y la pared observado/evaluación (el contrato C-10).
// Edición de ingeniería de datos (main_de.typ). Caso canónico: scripts/cap05_splits.py
// (semilla 20240701; fuga por selección sobre la prueba).
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Particiones y la pared observado/evaluación]
<de-cap-particiones>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Evaluar es comparar con algo que el pipeline no debe tocar: la prueba es un recurso finito que deja de mentir o empieza a mentir en la primera mirada],
    [*Decisión:*], [La partición es una estructura de datos versionada, sembrada y con lado de la pared asignado a cada fila],
    [*Pieza contratada:*], [El contrato C-10 (partición versionada): semilla, método, disjuntividad y cobertura total],
    [*La pared:*], [Lo observado decide; lo reservado — prueba y verdad — mide una vez],
    [*Caso canónico:*], [Reproducibilidad por semilla (misma huella) y fuga por selección sobre la prueba (R² inflado ~7 veces, script con semilla)],
  )
]

== El problema: evaluar es comparar contra lo intacto
<sec-de-05-problema>

Todo número sobre el desempeño de un sistema presupone una comparación: el sistema contra lo que habría pasado sin él, el modelo nuevo contra el vigente, el estimador contra su variante barata. Para que esa comparación signifique algo, el juez — el conjunto de evaluación — no puede haber participado en las decisiones que se juzgan: ni en la selección de hiperparámetros, ni en la elección del estimador, ni en la decisión de promover. La exigencia parece obvia y se viola de forma rutinaria, porque las miradas no cuestan nada y la prueba es tentadoramente accesible: se echa un vistazo "solo para comprobar", se ajusta un umbral, se vuelve a mirar, y en la tercera iteración el número que la prueba reporta ya no mide al sistema: mide cuánto se le acopla el equipo a esa muestra concreta.

En ciencia de datos predictiva esto es folklore — el conjunto de prueba se usa una vez, al final, y antes de eso se divide entrenamiento y validación para decidir. Este libro lo trata como un contrato por dos motivos. Primero, porque en un sistema causal la violación es más cara: la comparación de la @de-eq-descomposicion solo vale si el lado de la comparación no fue seleccionado por quien mide. Segundo, porque el sistema sigue operando tras la primera evaluación, y el conjunto que hoy es "prueba" será mañana materia de un modelo nuevo: el recurso finito no se repone, y hay que gobernarlo (@de-cap-anatomia, las prácticas del bucle). La partición, entonces, no es un paso de muestreo al inicio del proyecto: es una *estructura de datos con dueño, semilla y versión*.

== La partición como estructura de datos
<sec-de-05-estructura>

Las tres piezas de una partición honesta son el procedimiento, la semilla y la asignación de lados de la pared:

+ *Los bloques y su rol*: `entrenamiento` para ajustar, `validación` para decidir (hiperparámetros, umbral de promoción, modelo candidato), `prueba` para medir una vez. Los roles deben declararse; el error clásico es usar la validación "una vez más" para lo que solo la prueba debía tolerar.
+ *El método*: aleatorio simple, o estratificado por la variable que no puede quedar desbalanceada — aquí, por tratamiento, de modo que cada bloque preserve la fracción $P(D=1)$. El método es una decisión del productor: con tratamientos raros o resultados raros, la aleatorización simple crea bloques sin casos y la partición se vuelve inútil para el estimando.
+ *La semilla*: lo que hace al sorteo reproducible. La semilla es parte del contrato, no una configuración descartable: sin ella, ya nadie sabe si la partición de ayer y la de hoy son la misma, y la evaluación consecutiva deja de ser continua.

El benchmark del repositorio de referencia lo lleva literalmente escrito: en `splits.json` del escenario `real/jobs` el productor declara `split_seed: 20240701`, el método `stratified_by_treatment_60_20_20`, los bloques con tamaños 1 033 / 344 / 345, un `file_sha256` y un `row_id_sha256` por bloque, y un bloque `validation` que certifica `covers_all_rows: true` y `no_overlap: true` (@de-cap-versionado). La partición viaja así como una versión más del dataset: el consumidor recalcula y verifica, y las dos condiciones — todo fila cubierta exactamente una vez, ninguna fila en dos bloques — son lo primero que el contrato de más abajo exige comprobar.

== El contrato C-10: partición versionada
<sec-de-05-c10>

#contrato(
  "C-10",
  "Partición versionada",
  operaciones: [
    _dividir_: reparte una tabla en bloques con proporciones y método declarados; _describir_: emite los metadatos de la partición — semilla, método, estratificación, tamaños, hashes por bloque; _verificar_: comprueba disjuntividad y cobertura exacta contra la tabla; _etiquetar_: asigna un lado de la pared a cada bloque — qué puede decidir y qué solo mide.
  ],
  entrada: [
    La tabla (con su hash, contrato C-09), la semilla, las proporciones por bloque y el método — en particular con qué variables estratificar.
  ],
  salida: [
    Los índices de cada bloque y el documento de metadatos versionado junto al dataset. La verificación pasa o falla nombrando la fila en conflicto.
  ],
  invariantes: [
    (1) Dada la tabla y la semilla, la partición es determinista: dos invocaciones producen bloques idénticos. (2) Los bloques son disjuntos y su unión es la tabla completa: toda fila cae exactamente en un bloque. (3) La partición viaja con el hash de la tabla: sobre otra tabla, es otra partición. (4) El lado derecho de la pared no entra en ningún ajuste ni decisión; la medición de la prueba se hace una vez. (5) Cambiar la semilla produce otra partición, registrada como cambio de versión y nunca como "la misma". (6) La estratificación se declara y no se elige mirando el resultado.
  ],
  fallos: [
    Reusar la semilla ante cada dato nuevo "porque así salía la partición buena"; probar semillas hasta obtener una partición favorable, que es mirar la prueba con más pasos. Un `join` defectuoso que solape una fila en dos bloques sin ninguna advertencia. Separar por tiempo y luego barajar internamente, rompiendo la temporalidad (@de-cap-tiempo). Validación usada tres veces hasta quedar, de facto, entrenamiento.
  ],
  aceptacion: [
    (a) La misma semilla dos veces produce la misma huella de bloques; otra semilla, otra huella (caso canónico A). (b) `verificar` confirma disjuntividad y cobertura sobre la tabla real (caso canónico A, y el `validation` de `splits.json`). (c) Con otra tabla, la misma semilla produce particiones distintas y el documento lo refleja. (d) La selección sobre la prueba queda medida: el ejercicio del mejor-de-100 produce el orden de inflación del caso canónico B.
  ],
)

== La pared: lo observado y lo reservado
<sec-de-05-pared>

La partición reparte las filas; la *pared* decide qué lado de la casa toca el pipeline cuando está decidiendo. Del lado izquierdo queda lo observado — entrenamiento, validación, todo lo que puede inspeccionar, graficar y usar para elegir modelo y umbral. Del lado derecho queda lo reservado: la prueba de uso único, y la verdad del DGP cuando la hay — $y_0$, $y_1$, $tau$ —, existente solo para evaluación final.

#figure(
  muro-datos((([`observed_train`]), ([`observed_validation`])), (([`observed_test` · uso único]), ([verdad: $y 0, y 1, tau$]))),
  caption: [La pared del gobierno del dato: el lado izquierdo lo tocan todas las decisiones del pipeline; al lado derecho solo entra la evaluación, una vez. Las columnas de verdad ($y_0$, $y_1$, $tau$) existen en el DGP para medir el prototipo: entrar al entrenamiento, al servicio o a cualquier decisión intermedia es la fuga que el contrato existe para impedir.],
) <de-fig-pared>

La pared no es paranoia: es la estructura sin la cual un sistema "aprende" de su propia evaluación y empieza a reportar un mundo que no existe. En el benchmark la aplica el productor — la verdad vive en archivos `truth_*` que ningún flujo público consume, y el repositorio lo hace cumplir también con chequeos sobre el árbol de trabajo — y en producción tiene dos análogos directos, ya mencionados con el bucle de la #ref(<de-fig-bucle>, supplement: [figura]): el *holdout permanente* (el grupo que el modelo no gobierna y que permite seguir midiendo el efecto mañana) y el *piso de exploración* (la fracción aleatoria que mantiene soporte común bajo política propia). Las dos son paredes para el dinero del sistema en operación, no solo para el prototipo.

== Caso canónico A: la partición es una función de la semilla
<sec-de-05-casoA>

#caso-canonico("Reproducir la partición")[
  Con la semilla 20240701 del benchmark y las proporciones 60/20/20, el script del repositorio divide las 1 722 filas y calcula la huella SHA-256 de los conjuntos de índices. La misma semilla, invocada dos veces, produce la misma huella: `cc477d0ca7defb98…` las dos veces. Con la semilla 20240702, la huella pasa a `7d626f58161184f9…`. Los bloques resultan 1 033 / 344 / 345 — los mismos tamaños que declara `splits.json` — sin solape alguno entre entrenamiento y prueba.

  La lectura operativa: la afirmación "la evaluación de la semana pasada" solo tiene sentido porque la partición es una función determinista de la semilla y la tabla. Cambiar cualquiera de las dos — una extracción nueva de la tabla, una semilla distinta — y la comparación entre semanas ya no es sobre el mismo juez.
]

== Caso canónico B: elegir mirando la prueba
<sec-de-05-casoB>

#caso-canonico("El mejor de 100 modelos de ruido")[
  Tómenese 100 modelos triviales, cada uno con una sola covariable generada como ruido puro estándar, sin relación ninguna con el resultado — no hay señal que explicar en ninguno. Ahora el equipo puede ser inocente o deshonesto con la prueba. La ruta inocente: reporta el R² medio de los 100 sobre la prueba: *0,0011*. La ruta deshonesta: elige el mejor de los 100 mirando esa misma prueba y lo presenta como "el modelo": su R² sobre la prueba es *0,0109*, casi siete veces. La prueba honesta de ese "mejor" modelo — columnas nuevas de la misma familia de ruido, sin selección alguna — vuelve a dar *0,0016*.

  Las tres cifras (semilla 20240701, script incluido) son la varianza del azar, nada más; el punto no es cuánto infla en este caso, sino que la inflación no lanza ningún error: la prueba sigue devolviendo números con total normalidad, con su gráfico y su tabla, exactamente igual que antes de ser usada tres veces. La única línea real de defensa es el invariante (4) del C-10: lo reservado mide una vez, y su documento de metadatos registra cuándo y por qué se midió. Cualquier evaluación posterior usa otra partición — o renuncia al calificativo de evaluación.
]

#repo-ref[
  Caso completo: #code[Causal_AI/scripts/cap05_splits.py] (semilla 20240701). Las particiones públicas del benchmark, con hash por bloque: #code[data_benchmark_causal/causal_benchmark_synthetic/datasets/real/jobs/splits.json] (y sus homólogos `ihdp`, `ihdp_medium`, `latent_confounder`, `10_vars_10_edges`). El registro de versiones que aloja la partición como versión del dataset: #code[04_produccion_causal/src/causalops/registro_local.py].
]

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ Un equipo ajusta el umbral de promoción con la validación y, "por completar", vuelve a mirar la prueba para confirmar que aguanta. ¿En qué invariante del C-10 quedó roto el proceso, aunque nadie cambió ningún archivo? _Pista:_ (4) y (5): la mirada ya es decisión; si la prueba ajusta el umbral, la partición deja de ser la registrada.

+ Explique por qué estratificar por tratamiento (en vez de aleatorizar de forma simple) es aquí una decisión de productor y no una mejora de desempeño. ¿En qué escenario del benchmark sería obligatoria y por qué? _Pista:_ piense en `latent_confounder` o cuando $P(D=1)$ caiga cerca de 0, o de 1: un bloque sin tratados no identifica nada.

+ Proponga la pared de un sistema en producción mes a mes: ¿dónde va el holdout permanente, dónde el piso de exploración y qué rol cumple el registro de asignación en cada uno? _Pista:_ repase la sección del bucle del Cap. #ref(<de-cap-anatomia>, supplement: none); una partición de uso único no responde a un sistema que sigue operando.

+ El equipo decide separar por fecha (todo lo previo a junio entrena, lo posterior evalúa) y luego barajar cada bloque "para evitar sesgos". ¿Qué ocurre con la validez temporal de features y con la interpretación del estimando tras el barajado? _Pista:_ la partición temporal no es una partición aleatoria; la versión del @de-cap-tiempo la obliga, y el barajado convierte una pregunta sobre el futuro en una sobre el pasado.

+ En el caso canónico B, alguien señala que "100 modelos es mucho; con 3 modelos de verdad no pasaría". ¿Tiene razón, en qué medida? Calcule la inflación esperada del mejor-de-3 bajo ruido puro y discuta por qué la regla del C-10 sigue sin admitir la mirada. _Pista:_ el punto no es el tamaño de la tasa sino que el número deja de medir generalización desde la primera selección.

=== Notas bibliográficas

La higiene de entrenamiento, validación y prueba, y la lectura del muestreo como diseño, son de @huyen2022dmls (Cap. 4) y del esquema de pruebas de producción de @breck2017mltestscore — este capítulo los eleva a contrato versionado. La fuga por mirar la evaluación es la "plumbing" deuda de datos de @sculley2015hiddendebt y el caso operativo que motiva la regla de uso único. El bucle sistema-mundo que obliga al holdout permanente y al piso de exploración se formaliza como predicción performativa en @perdomo2020performative, y su lectura para sistemas que deciden está en el Cap. #ref(<de-cap-anatomia>, supplement: none). El tratamiento de la partición como artefacto versionado con hash es la contribución propia del capítulo, en la línea de @kleppmann2017 y @reis2022fundamentals de tratar artefactos de datos como código, junto al contrato C-09.

#verdad-datos[
  Que la partición exista como estructura declarada — semilla, método, bloques, lado de la pared — versionada con el dataset, determinista dada la semilla, disjunta y completa, y que nada del lado reservado entre a ajustar, decidir o "confirmar por las dudas". Que las columnas de verdad ($y_0$, $y_1$, $tau$) existan solo para evaluación, y que en producción el análogo sea el holdout permanente con su registro de asignación. Se comprueba corriendo la doble prueba del caso canónico: la partición se reproduce por huella (A), y la inflación por selección queda medida y fuera de cualquier decisión (B). Que estas garantías hacen de la comparación una medición honesta es verdad; que las hagan *causal* no: la causalidad se la da el estimando declarado (Cap. #ref(<de-cap-dato-estimando>, supplement: none)) y los supuestos que el C-01 registra.
]
