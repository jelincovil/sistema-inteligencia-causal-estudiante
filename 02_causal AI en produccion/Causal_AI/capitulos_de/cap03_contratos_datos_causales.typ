// Capítulo 3: Contratos de datos causales (el contrato C-01).
// Edición de ingeniería de datos (main_de.typ). Casos canónicos: scripts/cap03_dos_definiciones.py (semilla 11)
// y scripts/cap03_contrato.py (prueba de aceptación sobre real/jobs).
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Contratos de datos causales]
<de-cap-contratos>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Decisión:*], [Declarar los roles causales de cada columna en un esquema único que viaja con los datos, y no repetirlos en cada análisis],
    [*Pieza contratada:*], [El contrato C-01 (esquema de roles causales), el primero del libro],
    [*Contrato vs convención:*], [Una convención se recuerda; un contrato se ejecuta en una prueba de aceptación],
    [*Caso canónico:*], [Dos análisis, dos definiciones de X: mismo dato, efecto 1,00 frente a 1,50 (script con semilla)],
    [*Límite honesto:*], [El contrato comprueba ortografía de columnas y tiempos declarados; no verifica que el rol declarado sea el verdadero (@de-cap-tiempo)],
  )
]

== De las convenciones a los contratos
<sec-de-03-contratos>

Los pipelines viejos no fallan por ignorancia de sus autores: fallan porque todo el conocimiento que los mantiene correctos estaba en la cabeza de quien las construyó. "La columna `educ` es la escolaridad, no la etiqueta; el resultado se recalcula los domingos; nunca uses `exper` porque es posterior a la decisión" — acuerdos verbales, convenciones de equipo, una página de wiki que nadie relee. En la ingeniería de datos clásica, de @kleppmann2017 y @reis2022fundamentals, eso ya era una deuda: el esquema implícito se desincroniza de los datos y nadie recuerda cuándo. En un sistema causal es además una amenaza a la identificación, porque la decisión sobre qué es una covariable legítima, tomada de memoria, puede destruir la comparación del estimando sin lanzar ningún error (#cite(<sculley2015hiddendebt>, form: "prose") lo anota como deuda de datos en su sección de dependencias y configuración).

La salida de este libro para esa deuda no es más documentación: es *contratos*. Un contrato describe una pieza de ingeniería sin atarla a una tecnología — sea una clase, un paso de pipeline o un proceso manual — y lo describe con seis campos fijos:

+ *Operaciones*: lo que la pieza ofrece a quien la usa.
+ *Entrada* y *salida*: lo que recibe y lo que devuelve, al nivel que necesita quien implementa.
+ *Invariantes*: lo que debe cumplirse siempre, para cualquier entrada, y de forma comprobable — si no hay manera de verificarlo, no es un invariante sino un deseo.
+ *Modos de fallo*: cómo falla la pieza, incluyendo los fallos que el contrato existe para impedir y los que declara no poder ver.
+ *Prueba de aceptación*: el procedimiento que decide, sobre datos con verdad conocida o fallos inducidos a propósito, si una implementación cumple el contrato.

La diferencia entre invariante y prueba importa y es el núcleo del rigor de esta edición: *el invariante dice qué es verdad; la prueba es la evidencia de que lo es*. Una convención se recuerda; un contrato se ejecuta en CI cada vez que algo cambia. Todo contrato del libro lleva el mismo formato, y Parte III de cada parte los colecciona: el esquema de roles (C-01), la auditoría temporal (C-03), el registro de versiones y linaje (C-09) y la partición versionada (C-10), junto a los que la Parte IV añade en operación.

#definition(name: [Contrato de datos])[
  Un contrato de datos es la parte de un contrato que describe tablas, no servicios: qué columnas existen con qué rol, qué invariantes de contenido pueden decidirse con nombres y valores, cómo se reporta un fallo y con qué prueba de aceptación se comprueba. Lo que un contrato no puede verificar — que el rol declarado corresponde al rol causal verdadero — lo declara, porque firmarse a sí mismo como verificado es el fallo más caro de todos.
]

== El problema que añade el modo causal
<sec-de-03-problema>

La ingeniería de datos genérica pregunta qué formato usar, qué modelo de datos tiene sentido y cómo pasar datos entre procesos; esas preguntas siguen vigentes aquí. Pero un sistema causal añade una que un pipeline puramente predictivo jamás necesita responder: *¿qué rol estructural juega cada columna?* En predicción las columnas de entrada son en principio intercambiables, porque el modelo usa todas las que ayuden a reducir el error. En un problema causal no lo son. Una es el *tratamiento* $D$, otra es el *resultado* $Y$, algunas son *covariables* $X$ que pueden controlarse legítimamente y, lo más delicado, algunas que *parecen* covariables razonables son variables posteriores al tratamiento: están en la ruta causal entre $D$ e $Y$, o son efecto común de ambos, y controlarlas sesga la estimación — la distinción entre controles legítimos y malos controles que la edición de método de este libro desarrolla como criterio de puerta trasera.

La diferencia no es académica: tiene un precio medible. En el caso canónico de este capítulo, dos análisis que controlan conjuntos distintos de covariables sobre la misma tabla producen efectos de 1,00 y 1,50 — una brecha de 0,50 que no es ruido sino consecuencia de controlar una variable que contiene al tratamiento. Ninguna métrica de calidad de datos estándar detecta esa diferencia, porque ninguna es un problema de forma: es un problema de *qué comparación sostiene el dato*. El pipeline que no distingue roles desde el origen deja esa decisión en la memoria de cada analista, y la memoria falla de forma predecible cuando el sistema crece.

#figure(
  diagram(
  node-stroke: 0.6pt + gray.lighten(40%),
  node-fill: light,
  node-outset: 4pt,
  node-corner-radius: 3pt,
  spacing: (7mm, 12mm),
  edge-stroke: 0.8pt + accent,
  node((0, 0), [$X$ covariables#linebreak()pre-tratamiento]),
  node((2.6, 0), [$D$ tratamiento]),
  node((5.2, 0), [$Y$ resultado]),
  node((2.6, 1.7), [estimando $theta$], fill: rgb("ECF1F6")),
  node((5.2, 1.7), [columna posterior#linebreak()al tratamiento], stroke: (paint: crimson, dash: "dashed"), fill: crimson.lighten(94%)),
  edge((0, 0.3), (2.6, 1.4), "-|>"),
  edge((2.6, 0.3), (2.6, 1.4), "-|>"),
  edge((5.2, 0.3), (2.6, 1.4), "-|>"),
  edge((5.2, 1.7), (2.6, 1.7), stroke: (paint: crimson, thickness: 1pt, dash: "densely-dashed")),
  ),
  caption: [El esquema de roles: $X$, $D$, $Y$ (y $Z$, cuando hay instrumento) alimentan el estimando con un rol por columna. La columna posterior al tratamiento no entra al estimando: el contrato sólo lo deduce si alguien declaró su tiempo; ese es el límite honesto que el Cap. #ref(<de-cap-tiempo>, supplement: none) cierra.],
) <de-fig-esquema-roles>

Si el pipeline no distingue esos roles desde el origen, la tarea de no confundirlos recae en la memoria de quien escribe cada análisis, y eso falla de forma predecible cuando el sistema crece y más personas lo tocan. Un análisis puede controlar por una experiencia calculada con el tratamiento, otro no, y producir estimaciones no comparables sin que nadie lo note, exactamente como muestra el caso canónico de más abajo.

== El contrato C-01: esquema de roles causales
<sec-de-03-c01>

El libro adopta un *esquema de roles causales* único para todo dato que alimente una estimación, y lo formaliza como el primero de sus contratos. El esquema declara cuatro cosas — el tratamiento, el resultado, las covariables y, cuando aplica, los instrumentos —, ninguna función del sistema acepta una tabla sola, y el esquema es la única fuente de verdad sobre los roles: la corrección semántica importa, el formato físico no.

#contrato(
  "C-01",
  "Esquema de roles causales",
  operaciones: [
    _declarar_: construye el esquema a partir de los nombres del tratamiento, el resultado, las covariables y los instrumentos. _validar_: comprueba el esquema contra una tabla de datos. _proyectar_: devuelve de la tabla la matriz de covariables, el tratamiento y el resultado, en el orden declarado. _escribir_ y _leer_: pasan el esquema a un texto legible por personas y por máquinas, y de vuelta.
  ],
  entrada: [
    Los nombres de las columnas de cada rol (un tratamiento, un resultado, al menos una covariable, cero o más instrumentos) y la tabla de datos a la que el esquema se aplica.
  ],
  salida: [
    La matriz de covariables, el tratamiento y el resultado. El texto del esquema, en el formato que registra la ficha del modelo (Parte IV) y la edición de método.
  ],
  invariantes: [
    (1) Cada columna tiene un solo rol: ninguna aparece dos veces en el esquema. (2) Hay al menos una covariable. (3) Una tabla solo valida si contiene todas las columnas declaradas y si el tratamiento toma al menos dos valores distintos. (4) El orden de las covariables es parte del esquema y las proyecciones lo respetan. (5) Escribir y volver a leer devuelve un esquema igual al original. (6) El esquema no se modifica una vez creado: cambiar los roles produce otro esquema y deja intacto el que ya usan otras piezas. (7) Declarar una covariable es una afirmación causal que este contrato no verifica; la verifica la auditoría del C-03 (@de-cap-tiempo).
  ],
  fallos: [
    Una columna declarada que ya no está en los datos, porque cambió de nombre en el origen. El tratamiento o el resultado repetidos entre las covariables, o un instrumento incluido entre ellas. Un tratamiento constante en la muestra, porque un filtro dejó una sola rama. Un esquema que se desincroniza de los datos porque viaja por separado. Una covariable posterior al tratamiento que pasa todas las comprobaciones, porque el contrato solo ve nombres.
  ],
  aceptacion: [
    (a) Cada fallo estructural de la lista se provoca a propósito y la operación correspondiente lo rechaza con un mensaje que nombra la columna. (b) Escribir y leer devuelve un esquema igual, y el texto escrito valida contra el formulario de roles de la ficha del modelo. (c) Dos análisis que consumen el mismo esquema reciben la misma matriz de covariables y obtienen la misma estimación sobre el caso canónico de más abajo. (d) Una covariable posterior al tratamiento pasa la validación; el contrato no pretende detectarla y la prueba lo deja a la vista.
  ],
)

#caso-canonico("Dos análisis, dos definiciones de X")[
  Un conjunto de datos laborales estilizado, con efecto conocido. La educación de los padres $P$ y la edad $E$ son normales estándar independientes; la escolaridad depende de los padres, $D = 0.5 P + epsilon_D$, y el salario es $Y = D + 0.8 P + 0.5 E + epsilon_Y$, de modo que el efecto de un año de escolaridad vale exactamente 1. La tabla incluye una columna de experiencia potencial, $S = E - D$, calculada con la edad y la escolaridad — una práctica habitual en datos laborales: en el conjunto de datos de #cite(<card1995>, form: "prose"), tal como se distribuye públicamente, la experiencia se computa como edad menos escolaridad menos seis.

  Dos análisis leen la misma tabla. El primero controla por $\\{P, E\\}$ y el segundo por $\\{P, S\\}$. Los dos conjuntos existen en los datos, ninguno repite el tratamiento y ambos pasan cualquier validación estructural. Con 5 000 unidades y 200 repeticiones (semilla 11), el primero estima *1,00* y el segundo *1,50*, con desviaciones de 0,01 y 0,02 entre repeticiones.

  La brecha de 0,50 no es ruido. Como $S$ contiene a $D$, controlarla abre el camino $D arrow.r S arrow.l E arrow.r Y$, y el coeficiente de $D$ absorbe el efecto de la edad: sustituyendo $E = S + D$ queda $Y = 1.5 D + 0.8 P + 0.5 S + epsilon_Y$. Con un esquema único no hay dos definiciones de $X$ que comparar, y la discusión sobre si $S$ pertenece a él ocurre en un solo lugar y queda registrada. Lo que el esquema no decide es cuál de las dos es la correcta: eso lo decide la teoría causal y su auditoría temporal (@de-cap-tiempo), que deja $S$ fuera porque se calcula con el tratamiento.
]

#repo-ref[
  Regeneración exacta: #code[Causal_AI/scripts/cap03_dos_definiciones.py] (semilla 11). La clase de datos inmutable del esquema, que rechaza columnas con dos roles y valida contra la tabla, es la referencia del contrato C-01: #code[03_notebooks_caso_estudio/lib/schema.py] y su puente #code[CausalSchema.from_scenario("real/jobs")] desde los metadatos del benchmark.
]

== La prueba de aceptación sobre datos reales
<sec-de-03-aceptacion>

La promesa del contrato se mide contra tablas que existen. Sobre el escenario `real/jobs` del benchmark — esquema `treatment` / `re78` / 8 covariables — la implementación de referencia toma la tabla de entrenamiento y la valida (debe pasar), y toma versiones corrompidas a propósito (deben fallar, nombrando la columna):

#entero[
#table(
  columns: (2.8fr, 1.3fr, 3.2fr),
  align: (left, center, left),
  stroke: none,
  table.hline(stroke: 0.6pt),
  table.header([*Caso inducido*], [*Espera*], [*Sale*]),
  table.hline(stroke: 0.3pt),
  [Tabla de entrenamiento real], [Pasa], [Pasa: columnas presentes, el tratamiento varía],
  [El origen renombró `educ`], [Falla], [Falla: `Columnas ausentes en los datos: ['educ']`],
  [Un filtro dejó el tratamiento constante], [Falla], [Falla: `El tratamiento 'treatment' no varía`],
  [`treatment` colado entre covariables], [Falla], [Falla: `Columnas con dos roles: ['treatment']`],
  table.hline(stroke: 0.6pt),
)
]

Cada salida es la columna responsable, no un error genérico. Es la primera propiedad de la lista de la aceptación — todo fallo nombra a su culpable — y es la diferencia visible entre un contrato y un filtro de calidad de datos estándar: un test de nulidad también detectaría la columna ausente, pero solo después de que la estimación saliera con una interpretación equivocada; el contrato detiene antes de que haya un número que interpretar.

El mismo contrato viaja, en el benchmark, como datos adyacentes a los datos: `metadata.json` declara tratamiento, resultado y las covariables por nombre, e `identification.json` declara el conjunto de ajuste pre-tratamiento y la anotación causal completa del escenario (@de-cap-anatomia, la traza del Cap. 2). Quien consume el escenario no hereda roles de la memoria de nadie: los lee, los valida y los registra. El formato — CSV con metadatos vecinos, como aquí, o Parquet con el esquema embebido — no cambia el contrato; lo que el contrato exige es unicidad y versionado (@de-cap-versionado).

== Lo que el contrato no verifica
<sec-de-03-limite>

Un contrato firme sobre su propio límite es la diferencia entre gobernanza y decoración. El C-01 verifica ortografía y consistencia: ninguna covariable ha dicho en él ser pre-tratamiento salvo declaración de quien la inscribe. Una experiencia potencial $S$ pasa la validación tal como pasan las covariables legítimas, porque el contrato solo lee nombres. Por eso la entrega del esquema no es "los roles están bien" sino "los roles están *escritos*, y están escritos donde dos análisis los comparten por fuerza": la afirmación causal de las covariables la audita el C-03 con marcas de tiempo, y es el trabajo del Cap. #ref(<de-cap-tiempo>, supplement: none). Si algún sistema se comportara como si el C-01 validara la causalidad por sí solo, daría por revisada la identificación cuando solo revisó la ortografía.

== Cómo se diseña un contrato
<sec-de-03-diseno>

El paso de una convención a un contrato no es burocrático: es un proceso de decisión que este libro repite doce veces. El procedimiento que sigue funciona para cualquiera de ellos:

+ *Identificar la convención implícita.* Qué regla verbal o de wiki existe ya, y a qué fallo concreto protege. Si no hay convención, hay que escribir una desde el fallo: ¿qué salió mal la última vez que algo rompió?
+ *Escribir los invariantes como afirmaciones comprobables.* Cada invariante debe poder convertirse en un test que falla o pasa — no en una intención. "Las covariables deben ser pre-tratamiento" no es un invariante hasta que existe una forma de verificarlo; "ninguna columna aparece dos veces en el esquema" sí lo es.
+ *Declarar los modos de fallo que el contrato no puede ver.* Un contrato que promete más de lo que verifica es peor que no tener contrato: da una falsa sensación de control. El C-01 declara que no detecta variables posteriores al tratamiento; si no lo declarara, un equipo daría por revisada la identificación cuando solo revisó la ortografía.
+ *Escribir la prueba de aceptación.* El procedimiento que decide si una implementación cumple. Debe ser ejecutable: un script que corra en CI, un comando que cualquiera puede correr, un conjunto de corrupciones inducidas que produzcan fallos con mensajes esperados.
+ *Versionar el contrato.* Cuando cambia un invariante, es otro contrato. El registro (@de-cap-versionado) conserva la historia.

El resultado es que una convención que vivía en la memoria de una persona se convierte en un artefacto que una máquina ejecuta y que cualquier persona nueva puede leer. El costo es la fricción inicial de escribirlo; el beneficio es que el conocimiento deja de caducar.

== Anti-patrones del C-01
<sec-de-03-antipatrones>

En la práctica, los equipos que adoptan el C-01 sin entender su propósito cometen errores característicos:

*El esquema espejo.* Copiar los nombres de las columnas de la tabla y llamarlo esquema, sin decidir roles. Un espejo no decide nada: si el origen renombra una columna, el espejo la renombra también y el fallo pasa igual. El C-01 existe para que los roles se decidan una vez y no se redecidan por accidente.

*El esquema tentáculo.* Declarar el esquema en cinco lugares — un YAML, un docstring, un README, un comentario en el pipeline y la cabeza de alguien — y esperar que los cinco coincidan. El C-01 exige unicidad: un solo lugar, versionado, que viaja con los datos.

*El esquema confirmatorio.* Construir el esquema después de mirar los resultados, eligiendo los roles que hacen que el efecto salga mejor. El estimando se declara antes de mirar (Cap. 1); el esquema es la traducción de esa declaración a nombres de columna. Si se construye después, no es un esquema: es una justificación.

*El esquema sin prueba.* Tener el esquema pero nunca correr la validación. El C-01 sin su prueba de aceptación es una convención disfrazada de contrato — más peligrosa que la convención honesta, porque parece auditable y no lo es.

*El esquema que verifica causalidad.* Pedirle al C-01 que valide que las covariables son legítimas. El contrato no puede: solo ve nombres. La afirmación causal la audita el C-03 con marcas de tiempo, y la teoría causal la decide el grafo. Un C-01 que parece validar causalidad está mintiendo.

== Los contratos y el resto del libro
<sec-de-03-estructura>

El C-01 no está solo: es el primero de doce. Los demás lo consumen o lo extienden, y esa dependencia es deliberada:

#entero[
#table(
  columns: (1.2fr, 2fr, 2.4fr),
  align: (left, left, left),
  stroke: none,
  table.hline(stroke: 0.6pt),
  table.header([*Contrato*], [*Qué añade*], [*Qué exige del C-01*]),
  table.hline(stroke: 0.3pt),
  [C-03 auditoría temporal], [Marcas de tiempo por covariable], [El esquema declara los roles],
  [C-09 registro y linaje], [Hash, versión inmutable, champion], [El esquema viaja con la tabla],
  [C-10 partición y pared], [Semilla, cobertura, la pared], [El esquema define las columnas a particionar],
  [C-12 exigencias del estimador], [Nuisances OOS, ESS, trimming], [El esquema alimenta el bundle],
  table.hline(stroke: 0.6pt),
)
]

La lectura es: sin C-01, los demás no tienen qué validar. Un C-03 sin esquema no sabe qué covariable auditar; un C-09 sin esquema no sabe qué tabla hashear; un C-10 sin esquema no sabe qué columnas particionar. El C-01 es la base porque declara la estructura que todo lo demás presupone.

== El esquema como artefacto de identificación
<sec-de-03-identificacion>

Hay una lectura del C-01 que va más allá de la ingeniería: el esquema no es solo una interfaz de datos — es un *artefacto de identificación*. Cuando alguien declara que una columna es una covariable, está afirmando que esa variable puede controlarse legítimamente, es decir, que satisface el criterio de puerta trasera. Esa afirmación es causal, no técnica, y el esquema la registra en un formato que una máquina puede validar.

La distinción importa porque tiene consecuencias operativas. Si el esquema es solo una interfaz, cambiar un rol es una decisión de ingeniería: se actualiza el YAML, se versiona, se recompila. Si el esquema es un artefacto de identificación, cambiar un rol es una decisión *científica*: cambia qué estimando se computa, qué población cubre y qué supuestos se sostienen. Un equipo que trata los roles como decisiones de ingeniería puede cambiarlos sin pensar; un equipo que los trata como decisiones de identificación se detiene antes y pregunta: *¿qué afirmación causal estoy cambiando?*

El C-01 captura esa distinción en su invariante (6): el esquema no se modifica una vez creado. Cambiar los roles produce *otro* esquema — y ese otro esquema es otra pregunta causal, con otro estimando y otra población. El registro (@de-cap-versionado) conserva la historia: nadie puede cambiar la pregunta sin que quede registrado.

== El diseño del esquema en la práctica
<sec-de-03-practica>

El paso de la convención al contrato tiene un procedimiento que se repite en cualquier contexto:

*Identificar los roles que la pregunta exige.* La pregunta causal del Capítulo 1 determina qué roles se necesitan: si es un ATE, se necesita tratamiento, resultado y covariables; si hay instrumentos, se añaden; si la pregunta cambia, los roles cambian con ella. El esquema no se diseña en abstracto: se diseña para una pregunta.

*Elegir las columnas que llenan cada rol.* Aquí es donde la teoría causal entra: qué covariables son legítimas, cuáles son posteriores al tratamiento, cuáles son instrumentos. El C-01 no decide: registra la decisión. Pero al registrarla, la hace auditable — alguien más puede leerla y discrepar.

*Verificar contra la tabla.* El esquema que declara una columna inexistente no es un esquema: es un deseo. La validación contra la tabla real es el paso que separa la intención del hecho. El caso canónico muestra lo que pasa sin esa validación: dos análisis leen la misma tabla y obtienen efectos distintos.

*Versionar y registrar.* El esquema válido se registra con hash de la tabla a la que aplica. Cuando la tabla cambia — reextracción, filtro de negocio, cambio en el origen — el hash deja de coincidir y el registro lo detecta. Sin esa detección, el esquema de ayer se aplica a la tabla de hoy sin que nadie lo note.

== El fallo que el esquema previene y el que no
<sec-de-03-fallos>

El caso canónico muestra el fallo que el C-01 existe para impedir: dos análisis discrepando sobre los roles sin que nada lo detecte. Pero hay otro fallo que el C-01 *no* impide, y saber distinguirlos es la diferencia entre usar el contrato bien y usarlo como decoración.

El fallo que previene: *la deriva semántica silenciosa*. Sin esquema único, cada análisis define sus roles en su propio código, y dos definiciones pueden divergir sin que nadie lo note. El esquema único cierra esa puerta: hay un solo lugar donde los roles se deciden, y todo lo demás lo consume.

El fallo que no previene: *la deriva causal silenciosa*. Aunque los roles estén escritos y compartidos, pueden estar mal: una covariable declarada legítima puede ser un collider, una variable declarada pre-tratamiento puede ser post. El C-01 no lo ve porque solo lee nombres. Lo ve el C-03 con marcas de tiempo, y lo decide el grafo. El C-01 es necesario pero no suficiente: garantiza que la discusión sobre roles ocurra en un solo lugar, no que la discusión tenga razón.

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ Para el dataset de becas de la @sec-de-01-dos-preguntas, proponga el esquema C-01 completo (tratamiento, resultado, al menos tres covariables legítimas) y una columna que sería incorrecto incluir por posterior al tratamiento. _Pista:_ una calificación medida después de otorgar la beca no puede ser covariable, sí puede ser resultado.

+ En el caso canónico, suponga que el efecto de la edad sobre el salario pasa a 0. Dibuje el grafo y diga qué estima ahora el segundo análisis y por qué desaparece el sesgo. ¿Qué dos arcos hacían falta para que controlar $S$ sesgara? _Pista:_ el collider necesita la entrada de $E$ a $S$ y la salida de $E$ a $Y$.

+ La regla del esquema dice "un solo rol por columna". Dé un ejemplo de un instrumento que alguien incluyó también como covariable y explique qué va mal en cada uno de los dos errores posibles. _Pista:_ si el instrumento entra como covariable el estimador corre y devuelve un número; el fallo es silencioso igual que el del tratamiento repetido.

+ La validación (a) pasa sobre `observed_train.csv` y falla con un mensaje que nombra `educ` en (b). El equipo decide "arreglar el nombre en el pipeline" en vez de tocar el esquema. ¿Qué invariante del C-01 protege esa decisión, y por qué es la respuesta correcta aunque el esquema no haya cambiado? _Pista:_ (1) y (6): el esquema describe roles, no ortografía del origen; el punto del fallo es informar antes de estimar.

+ Escriba la prueba de aceptación conceptual de un nuevo fallo: una tabla donde el resultado llega con el tratamiento desplazado una fila. ¿Qué operación del contrato lo atrapa y con qué mensaje? Si ninguna, ¿por qué no puede el C-01 verlo? _Pista:_ desplazar filas no cambia nombres ni únicos: el fallo es de alineación, no de esquema; lo vería el registro por hash (@de-cap-versionado), no el validador de roles.

+ Su equipo tiene tres tablas con nombres de columnas distintos para el mismo concepto (`educ`, `educacion`, `years_of_educ`). Proponga cómo manejar esto sin crear un esquema tentáculo, y diga qué gana y qué pierde su propuesta frente a unificar los nombres en el origen. _Pista:_ el C-01 exige unicidad del esquema, no unicidad de nombres: cada tabla puede tener su esquema, pero cada esquema es uno.

+ Describa los tres pasos del diseño de un contrato (identificar la convención, escribir invariantes comprobables, declarar límites) aplicados al C-09 (registro con hash) en vez del C-01. ¿Qué cambia y qué se mantiene? _Pista:_ el procedimiento es el mismo; los invariantes y los fallos cambian.

+ Un colega dice: "el esquema es solo un YAML que documenta la tabla, no tiene efectos reales". Dé dos ejemplos concretos del capítulo donde el esquema produce un comportamiento verificable que el YAML sin contrato no produciría. _Pista:_ la validación que nombra la columna culpable y la inmutabilidad que impide cambiar roles sin versión nueva.

=== Notas bibliográficas

La fuente del marco datación-vs-contrato de este capítulo es la tradición de pipelines robustos de @kleppmann2017 (esquemas explícitos como frontera de compatibilidad) y @reis2022fundamentals (calidad como calidad-de-decisión, no como limpieza). La dependencia de configuración oculta que el esquema único cierra es deuda de datos en @sculley2015hiddendebt. La distinción entre controles legítimos y malos controles, que el contrato registra y la auditoría temporal verifica, se formaliza en la edición de método de este libro (criterio de puerta trasera; @bareinboim2025causalai). El ejemplo de la experiencia potencial viene de @card1995 y es la advertencia operativa del libro: una variable "estándar del campo" puede ser exactamente la fuga, como el caso canónico muestra en cifra.

#verdad-datos[
  Que el esquema exista y sea único no verifica la causalidad: verifica que dos análisis no pueden discrepar sobre el rol de una columna sin que alguien lo corrija en un solo lugar. Lo que debe ser verdad en los datos: un rol por columna, el esquema viajando con la tabla y validado contra ella, y toda operación de lectura del sistema recibiendo esquema + tabla, nunca tabla sola. Se comprueba corriendo la prueba de aceptación de la @sec-de-03-aceptacion sobre la tabla real y sus corrupciones, antes de permitir la primera estimación; los cuatro casos de la tabla son los únicos que el C-01 promete pillar, y lo dice.
]
