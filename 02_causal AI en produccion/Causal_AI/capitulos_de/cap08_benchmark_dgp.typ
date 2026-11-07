// Capítulo 8: Benchmarks y DGP como producto de datos (el contrato C-11).
// Edición de ingeniería de datos (main_de.typ). Caso canónico: scripts/cap08_benchmark.py
// (los cinco escenarios leídos de sus archivos reales).
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Benchmarks y procesos generadores como producto de datos]
<de-cap-benchmark>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Sin verdad conocida no hay prueba de aceptación: ninguna puerta puede prometer comportamiento si nunca se midió contra nada],
    [*Decisión:*], [El benchmark/DGP es un producto versionado, con semilla, splits con hash, estado de identificación explícito y la pared escrita],
    [*Pieza contratada:*], [El contrato C-11 (DGP y benchmark como producto), el canal productor-consumidor],
    [*Caso canónico:*], [Los cinco escenarios del paquete: tres identificables, uno *diseñado no identificable*, uno para descubrimiento — todo verificado sobre archivos],
    [*Regla de uso:*], [Solo lo observado decide; la verdad, aunque sintética, existe para evaluar — nunca para entrenar ni servir],
  )
]

== El problema: sin verdad no hay evidencia
<sec-de-08-problema>

Los contratos que este libro exige prueban — es la unidad de su rigor, desde el Cap. #ref(<de-cap-contratos>, supplement: none) — y probar comportamiento requiere conocer la respuesta correcta. Si ninguna base de datos del sistema contiene el efecto verdadero, ¿contra qué se calibró la puerta? ¿Cómo se sabe que el estimador recupera el efecto, que el diagnóstico detecta la fuga del Cap. #ref(<de-cap-tiempo>, supplement: none), o que el registro habría detectado la mutación del Cap. #ref(<de-cap-versionado>, supplement: none)? La respuesta de la tradición es la misma de siempre: *contra un proceso generador con verdad declarada por diseño* — el DGP — y contra colecciones de escenarios que llevan, cada uno, su verdad y sus violaciones conocidas: el benchmark.

El problema que este capítulo cierra es que un benchmark mal gobernado no es evidencia sino decoración: un proceso que nunca declara su semilla no es reproducible; una tabla que mezcla verdad y observación enseña al sistema a hacer trampa; un escenario sin estado de identificación declara implícitamente "esto se puede estimar", quizá falso. Las tres fallas importan porque son exactamente las que hacen el mentido de "verificado" sin ninguna técnica ni teoría detrás. Desde este capítulo (y en la Parte IV, con la puerta en producción), el benchmark deja de ser un cuaderno de datos y pasa a ser *un producto de datos con su propio contrato*.

== Dos familias de datos y dos regímenes de pared
<sec-de-08-regimenes>

El libro usa dos familias, ya distinguidas por la literatura y por la edición de método de este libro (su apéndice de datos y DGP): los *conjuntos reales o casi-reales* (procedencia publicada, efecto de referencia conocido solo aproximadamente — NSW/LaLonde y @hill2011bayesian son los dos de este paquete) y los *DGP sintéticos* (efecto conocido exactamente; el diseño dice cuál violación enciende cada diagnóstico). Un prototipo se acepta cuando funciona en ambas: acierta en los sintéticos y no se desmiente ni se contradice en los reales.

La pared se mantiene en ambas, pero con dos regímenes distintos — y los dos documentados:

#opciones[
  - *Verdad fuera del paquete (paquete público):* las columnas de verdad ($y_0$, $y_1$, $tau$, y sus archivos `truth_*`) permanecen del otro lado de la pared incluso como archivos: el paquete público no las contiene y sus metadatos las referencian como reservadas. Es el régimen de este benchmark: la decisión usa lo observado y la evaluación accede a la verdad solo al final y con aditamentos.
  - *Verdad adentro, con rol declarado (el demo de `causalops`):* en el flujo de producción local del repositorio de referencia, las filas vienen generadas por un DGP y la verdad se usa *para comprobar el comportamiento del prototipo*, como tests del contrato, no de manera confundida con entrenamiento o servicio. La pared no desaparece: se convierte en un registro de rol que se revisa como código ("`tau` no alimenta ninguna decisión"), con la misma prueba de aceptación del C-10.
]

Tanto en uno como en otro, la regla pragmática que el dominio de datos fija es lenguaje claro: *los datos sintéticos no se anuncian nunca como si fueran clínicos reales, y ninguna literatura externa sobre estos escenarios cambia qué datos el consumidor puede tocar* — la pared se mantiene independientemente de lo que diga la publicación de la fuente.

== Los cinco escenarios, leídos de sus archivos
<sec-de-08-escenarios>

El benchmark del repositorio lleva exactamente cinco escenarios, y la tabla que sigue está leída — no copiada — de los `metadata.json`, `identification.json` y `splits.json` de cada uno (el script del repositorio emite la misma tabla, regenerable):

#entero[
#table(
  columns: (2.8fr, 1.6fr, 0.9fr, 3.3fr),
  align: (left, center, center, left),
  stroke: none,
  table.hline(stroke: 0.6pt),
  table.header([*Escenario*], [*Unidades (split)*], [*Semilla*], [*Identificación declarada*]),
  table.hline(stroke: 0.3pt),
  [`real/jobs`], [1 722 (1 033/344/345)], [500], [Identificable por diseño; confusores simulados observados por supuesto],
  [`real/ihdp`], [747 (448/149/150)], [400], [Identificable por diseño (variante #cite(<hill2011bayesian>, form: "year"))],
  [`synthetic/inference/ihdp_medium`], [2 000 (1 200/400/400)], [343], [Identificable por diseño, tamaño medio],
  [`synthetic/edge_cases/latent_confounder`], [2 000], [543], [*No identificable desde lo observado*: confusor latente declarado],
  [`synthetic/linear_gaussian/10_vars_10_edges`], [1 000 (600/200/200)], [42], [Objetivo de estructura: descubrimiento, no estimación de efecto],
  table.hline(stroke: 0.6pt),
)
]

Tres lecturas de ingeniería de datos, no de estadística. *Primera: la semilla y el split viajan declarados en cada escenario* — uno por fila, `split_seed: 20240701` compartido entre paquetes del mismo corte; es exactamente lo que el C-09 exigía como identidad de versión y lo que el C-10 exige como identidad de partición. *Segunda: el estado de identificación es una propiedad del escenario, no una suposición del consumidor*: `latent_confounder` declara de frente que sin el confusor latente el efecto no se identifica desde lo observado — una trampa diseñada para enseñar y para medir lo que una puerta debe abstenerse —, y `10_vars_10_edges` declara que su pregunta es la reconstrucción de la estructura, no un efecto. *Tercera: ningún archivo de verdad llega en el paquete público para ninguno de los cinco escenarios:* el script confirma 0 archivos de `truth*.csv` en el paquete, y las referencias a ellos dentro de `splits.json` quedan como apuntadores a un material reservado, no como rutas.

#caso-canonico("El escenario que no se puede ganar")[
  `synthetic/edge_cases/latent_confounder`, con 2 000 unidades y partición 1 200/400/400, es el contraejemplo del libro: un DGP con un confusor que nadie midió y un estado de identificación que lo dice. Un estimador flexible puede ajustar la tabla impecablemente y estimar un efecto alejado del verdadero, sin que ninguna métrica predictiva alerte: el fallo vive exactamente donde la comparación del plano de datos no mira (invariante 6 del C-02). Por eso el escenario sirve de verificación de la puerta y del servicio: *una respuesta correcta ahí es una abstención, no un número*. El equipo que "resuelve" este escenario sin nuevas variables ni nuevos supuestos no ha identificado la verdad: ha estimado un número sin fundamento sobre lo observado; y el plano de datos lo dice con la propia ficha de identificación (`identification.json`).
]

== El contrato C-11: DGP y benchmark como producto
<sec-de-08-c11>

#contrato(
  "C-11",
  "DGP y benchmark como producto versionado",
  operaciones: [
    _publicar_: emite un escenario con metadato, identificación, partición y hashes; `verificar_integridad`: recomputa y comprueba los hashes y la estructura de los archivos públicos; `declarar_regimen`: dice de qué lado de la pared vive la verdad, si la hay; _usar_: consume solo lo observado para decisiones, y solo la verdad para evaluación — con autorización y registro de acceso.
  ],
  entrada: [
    El DGP o la fuente real, la semilla y el método de muestreo, las reglas de violación (qué supuesto enciende cada escenario) y el régimen de pared elegido (@sec-de-08-regimenes).
  ],
  salida: [
    `observed_*.csv` (las particiones), `splits.json` (semilla, método, hashes por bloque), `metadata.json` (nombre, semilla, origen, qué es real y qué es sintético), `identification.json` (estado y conjuntos de ajuste válidos).
  ],
  invariantes: [
    (1) Todo escenario declara su semilla de generación y de partición. (2) Ningún archivo del lado observado contiene columnas de verdad ($y_0$, $y_1$, $tau$). (3) El estado de identificación es explícito por escenario, y los escenarios no identificables se emiten como trampas declaradas, no aparentando estimabilidad. (4) Cada entrega se verifica por hash: ningún archivo cambia sin una versión nueva. (5) La verdad, cuando existe, sirve únicamente a la evaluación bajo registro. (6) Ningún escenario sintético se presenta como dato clínico o administrativo real; su procedencia se declara.
  ],
  fallos: [
    Una columna de verdad colada en `observed_*` — la lista de nombres la vela el validator del árbol, según régimen, y la entrega se detiene. Cambiar el CSV sin incrementar la versión. Un estado de identificación que promete más de lo que el DGP dice (el C-08 de la edición de método lo penaliza en operación). La lotería de semillas: probar generaciones hasta obtener una versión "mejor" — mirar la prueba con más pasos, ya castigado por el C-10.
  ],
  aceptacion: [
    (a) El barrido del paquete (script del repositorio) confirma por cada escenario: seed declarada, hash computable e igual al publicado del MANIFEST, 0 archivos de verdad en la zona observada, splits válidos. (b) Se interviene un archivo y la verificación falla. (c) `latent_confounder` se registra como no identificable y no como estimable. (d) Todo acceso de evaluación a verdad queda con registro de quién, cuándo y para qué estimando.
  ],
)

#figure(
  diagram(
  node-stroke: 0.6pt + gray.lighten(40%),
  node-fill: light,
  node-outset: 4pt,
  node-corner-radius: 3pt,
  spacing: (7mm, 9mm),
  edge-stroke: 0.8pt + accent,
  node((0, 1), [DGP declarado + semilla]),
  node((3.2, 1), [escenario versionado], fill: rgb("EEF4F8")),
  node((6.2, 0), [observado#linebreak()→ decisiones], fill: green.lighten(88%)),
  node((6.2, 2), [verdad#linebreak()→ evaluación], stroke: (paint: crimson, dash: "dashed"), fill: crimson.lighten(94%)),
  edge((1.8, 1), (3.2, 1), "-|>"),
  edge((3.2, 0.85), (6.2, 0.3), "-|>"),
  edge((3.2, 1.15), (6.2, 1.7), "-|>", stroke: (paint: crimson, dash: "dashed")),
  ),
  caption: [El canal productor-consumidor del C-11: de un DGP declarado sale un escenario versionado y dos ramas etiquetadas — lo observado, abierto a toda decisión, y la verdad, abierta solo a evaluación con registro. La rama punteada solo evalúa: ni entrenamiento ni servicio la tocan, y su acceso queda registrado.],
) <de-fig-canal>

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ El paquete incluye el escenario `latent_confounder`. Un colega dice: "con más regularización el modelo recupera "el efecto". ¿El problema de ese escenario es de regularización del estimador o de identificación?" _Pista:_ la identificación no es una propiedad del estimador ni del ajuste: sin el confusor, ninguna penalidad recupera el efecto — y la puerta honesta lo dice en la ficha.

+ Diseñe la ronda de aceptación de un nuevo escenario: qué mínimo 4 artefactos debe entregar, qué 2 verificaciones comprobadas y qué 3 fallos inducidos. _Pista:_ artes de los invariantes y de la prueba C-11.

+ El equipo dice "para la intranet basta la ficha estática del escenario; la semilla es decorativa". Contra la tabla del Cap. #ref(<de-cap-versionado>, supplement: none) (hash, semilla, commit), defienda por qué semilla y hash van juntas en el documento del escenario. _Pista:_ el documento será para que la evaluación de mañana sea sobre el mismo escenario que hoy: el hash sin semilla no regenera, la semilla sin hash no verifica.

+ ¿Bajo qué régimen opera el flujo local del repositorio, y bajo cuál el benchmark público? Dibuje las dos paredes con sus columnas de verdad y escriba el invariante obligado en cada una. _Pista:_ una pared es física (archivos ausentes) y la otra es de rol (columnas marcadas); la prueba de aceptación cambia pero no el principio.

+ `10_vars_10_edges` declara objetivo de estructura, no efecto. Si el equipo lo usa para entrenar un estimador de efectos, ¿qué declaración de la ficha queda falsa aunque el modelo prediga? _Pista:_ el estado de identificación es parte del estimando: predecir una tabla no es estimar con ella.

=== Notas bibliográficas

La distinción entre datos reales con referencia cirenta y DGP con verdad, ya presente en la literatura de evaluación (@lalonde1986, @dehejia1999causal), adquiere aquí la forma del benchmark público (@hill2011bayesian para el IHDP original). La promesa "sintético nunca se anuncia como real" y la regla de uso de `truth` solo para evaluación directa las formula este repositorio como condición de acceso al paquete, fue de las pocas reglas tan simples como decisivas del dominio. El tratamiento del benchmark como producto versionado — semilla, hash, estado y pared — es la contribución propia del capítulo: los archivos de los cinco escenarios son su prueba, y todos se recorren con el script del repositorio.

#verdad-datos[
  Que todo escenario usado en una prueba de aceptación declare semilla, origen, estado de identificación y hash; que ningún archivo observado lleve columnas de verdad, y que cada fila de evaluación a verdad quede con registro. Que el paquete incluya trampas declaradas (el escenario no identificable) y que cada consumidor las honre abstinéndose antes que estimando. Se comprueba con el barrido del script del repositorio — que hoy confirma 0 archivos de verdad en los cinco escenarios y declara las mismas cinco semillas, los mismos cinco estados — y fallando la verificación si algún byte cambia.
]
