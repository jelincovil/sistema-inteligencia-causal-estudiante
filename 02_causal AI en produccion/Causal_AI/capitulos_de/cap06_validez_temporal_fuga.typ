// Capítulo 6: Validez temporal y control de fuga (el contrato C-03).
// Edición de ingeniería de datos (main_de.typ). Caso canónico: scripts/cap06_fuga.py (semilla 13).
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Validez temporal y control de fuga]
<de-cap-tiempo>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Una _feature_ que mejora el ajuste puede destruir el efecto: a más $R^2$, peor estimación, si entra por la ventana del tiempo],
    [*Decisión:*], [Auditar cada candidata contra su momento de medida y su rol causal antes de incluirla, no solo contra su poder predictivo],
    [*Pieza contratada:*], [El contrato C-03 (auditoría de _features_): dos especificaciones, $X_"base"$ y $X_"ampliada"$, y la regla conservadora],
    [*Caso canónico:*], [Efecto verdadero 1,00: de 1,55 sin controles al 0,00 con todas las variables, con $R^2$ subiendo de 0,69 a 0,99 (script con semilla)],
    [*Conexión:*], [Cierra el límite honesto del C-01 (@de-cap-contratos): valida lo que el esquema solo declaraba],
  )
]

== El problema: la columna que predice bien
<sec-de-06-problema>

La ingeniería de _features_ estándar evalúa una variable candidata con un solo criterio: ¿mejora el desempeño predictivo fuera de muestra? Con ese criterio, toda variable disponible al entrenar y correlacionada con $Y$ es bienvenida — y es exactamente por ahí por donde entra la fuga. En un problema causal el rol de la variable no se deduce de cuánto predice sino de *cuándo se midió y qué es en el grafo*: una feature puede reducir el error y a la vez ser un mediador, un collider o un registro tardío del resultado, y cada una de esas entradas vacía o sesga el coeficiente del tratamiento sin reducir una sola métrica de ajuste. El Cap. #ref(<de-cap-contratos>, supplement: none) lo dejó escrito como límite: el esquema C-01 verifica nombres, no causalidad; la verificación empieza aquí, y empieza por el tiempo.

En un sistema que opera, el momento importa dos veces. Al entrenar, una variable medida después del tratamiento filtra información del resultado y destruye la identificación. Al servir, además, el momento impone otra frontera, puramente operativa: la preparación de variables solo dispone de lo que es sabido en el instante de decidir, y una _feature_ que se computa con datos posteriores simplemente *no existe* en producción (o existe con otro valor): es el clásico _training-serving skew_, y su versión causal es peor, porque la estimación retrospectiva que la motivó era causalmente inválida antes de parti la cola. Las dos fronteras se describen con una sola idea que el capítulo opera: la *validez temporal*.

== Qué significa "antes": validez temporal y el as-of
<sec-de-06-asof>

#figure(
  linea-temporal(((-2.4, [medición de#linebreak()covariables], true), (-1.2, [registro de#linebreak()elegibilidad], true), (0, [momento de la#linebreak()decisión], false), (1.4, [asignación del#linebreak()tratamiento], false), (2.8, [observación del#linebreak()resultado], false), (4.2, [agregados tardíos:#linebreak()no entran], false))),
  caption: [El eje del tiempo y la validez de las variables. Solo lo verificable como anterior al momento de la decisión puede entrar en una pregunta de producción; y solo lo anterior al tratamiento puede entrar como control en las dos especificaciones ($X_"base"$ y $X_"ampliada"$). Los agregados tardíos quedan afuera por las dos puertas.],
) <de-fig-tiempo>

La validez temporal exige que toda _feature_ del pipeline responda con precisión dos preguntas:

+ *¿Cuándo se midió?* Contra un timestamp *de medición*, no de carga. La marca "fecha de ingreso a la base" no es la marca "fecha en que el evento ocurrió", y confundirlas es de las fugas más comunes de data warehouse real.
+ *¿Cuándo se decidió?* La ventana lícita de lo observable se cierra en el instante de la decisión que el sistema apoya — para el servicio, el momento de la consulta; para el entrenamiento retrospectivo, una fecha de decisión declarada por fila, no una fecha global conveniente.

El mecanismo que lo hace cumplir en pipelines, en la literatura de _feature stores_, es el *as-of join* (o _point-in-time join_): cada fila de entrenamiento se cruza con el historial de la _feature_ cortando estricto en su fecha de decisión, nunca en "hoy". El _as-of join_ no es una optimización: es la única forma en que una tabla retrospectiva imita el conocimiento real que había en producción cuando habría tocado decidir. Su invariante es el que este capítulo eleva a la tabla de decisión de abajo: *lo que no se puede verificar como anterior al momento declarado no entra*.

#entero[
#table(
  columns: (2fr, 2fr, 1fr, 1.3fr),
  align: (left, left, center, center),
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Momento de medida*], [*Rol declarado*], [*$X_"base"$*], [*$X_"ampliada"$*]),
  [Antes del tratamiento], [Confusor], [Sí], [Sí],
  [Antes del tratamiento], [Desconocido], [No], [Sí],
  [Antes del tratamiento], [Mediador, collider o post-tratamiento], [No], [No],
  [Después del tratamiento, en alguna unidad], [Cualquiera], [No], [No],
  [Sin marca de tiempo, o con faltantes en ella], [Cualquiera], [No], [No],
)
]

La última fila es la regla conservadora que la implementación hace cumplir: lo no verificable queda fuera. La tabla vale para el *efecto total*: si el estimando cambiara a un efecto directo o mediado, el mediador entraría por diseño y sería otra tabla de decisión —otro estimando, como en la @sec-de-01-estimando-comparacion—. La novedad frente a una ingeniería predictiva es la exigencia de *dos especificaciones*, que la sección siguiente justifica.

== El contrato C-03: auditoría de features
<sec-de-06-c03>

El analista rara vez sabe con certeza el rol de todo candidato; sabe el momento, a veces, y el grafo, con distinto grado de confianza. Si la regla fuera "solo lo declarado confusor", una confusión quedada fuera por cautela se cobra en sesgo; si fuera "todo lo verificable", un mal control entra y se cobra lo mismo. Los dos errores son asimétricos *y ningún criterio automático resuelve esa duda*. La respuesta del contrato es no resolverla: reportarla — con dos especificaciones siempre calculadas y, si difieren de forma material, registradas ambas:

#contrato(
  "C-03",
  [Auditoría de _features_],
  operaciones: [
    _auditar_: recibe las candidatas con su rol declarado y su marca de tiempo, junto con la marca del tratamiento, y devuelve una fila por candidata con su decisión de inclusión en cada especificación; _extraer_: devuelve la lista de covariables de una especificación, que pasa al campo de covariables del esquema (C-01) y de la ficha del modelo.
  ],
  entrada: [
    Las candidatas con su rol (confusor, mediador, collider, post-tratamiento o desconocido) y su marca de tiempo por unidad, y la marca del tratamiento por unidad. El estimando declarado es el efecto total; para otro estimando cambia la tabla de decisión.
  ],
  salida: [
    Una fila por candidata con su rol, la fracción de unidades en que se midió después del tratamiento, si su marca es verificable y las decisiones en $X_"base"$ y $X_"ampliada"$. Una advertencia por cada candidata con riesgo temporal o de rol ambiguo.
  ],
  invariantes: [
    (1) Ninguna candidata se omite en silencio: toda la que aparezca en los roles o en las marcas aparece en la salida, aunque sea para marcarse como no verificable. (2) Lo no verificable como anterior al tratamiento, por falta de marca o por faltantes en ella, no entra en ninguna especificación. (3) Una candidata medida después del tratamiento en alguna unidad no entra en ninguna. (4) Mediador, collider y post-tratamiento no entran en ninguna. (5) $X_"base"$ contiene solo confusores y está incluida en $X_"ampliada"$, que añade las de rol desconocido. (6) Una candidata sin rol declarado es de rol desconocido. (7) Con los mismos datos y roles, la salida es idéntica.
  ],
  fallos: [
    Un rol mal declarado: la auditoría confía en lo declarado, y un collider anotado como confusor entra en las dos. Una marca de tiempo que registra cuándo se cargó el dato y no cuándo se midió: la condición temporal queda cumplida en el papel. Un rol desconocido resuelto por conveniencia. Una sola especificación reportada cuando las dos difieren. Una candidata derivada cuya fórmula usa, aun vía columna intermedia, el resultado medido después.
  ],
  aceptacion: [
    (a) Un caso de borde por cada fila de la tabla, más la candidata que solo aparece en los roles y la que tiene faltantes en su marca: cada una cae en su casilla. (b) En el caso canónico de abajo, la auditoría deja $X_"base" = \\{C\\}$ y $X_"ampliada" = \\{C, U\\}$, y $B$, $M$, $K$ y $P$ quedan fuera de ambas. (c) Las seis estimaciones de la tabla se reproducen, y la brecha entre las dos especificaciones supera con holgura la desviación entre repeticiones.
  ],
)

== Caso canónico: cuatro tipos de feature y una verdad conocida
<sec-de-06-caso>

#caso-canonico("El peor modelo es el mejor predictor")[
  Seis variables con verdad conocida, semilla 13: $C$ y $U$ son confusores medidos antes del tratamiento; $B$ es un collider medido antes; $M$ es un mediador, y $K$ y $P$ una medición tardía — respectivamente del sistema y del resultado. El efecto total de $D$ sobre $Y$ es exactamente 1. Con 5 000 unidades y 200 repeticiones, ajustando regresión lineal con cada especificación — y midiendo el $R^2$ fuera de muestra en la mitad no usada para ajustar:

  #entero[
  #table(
    columns: (3fr, 2.2fr, 2.8fr),
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Controles*], [*Efecto estimado*], [*$R^2$ fuera de muestra*]),
    table.hline(stroke: 0.3pt),
    [Ninguno], [1,55], [0,69],
    [$X_"base"$ ($C$)], [1,35], [0,73],
    [$X_"ampliada"$ ($C$, $U$)], [1,00], [0,80],
    [con $B$ (collider previo)], [0,88], [0,82],
    [con $M$ (mediador)], [0,70], [0,84],
    [Todas (con $K$ y $P$)], [0,00], [0,99],
    table.hline(stroke: 0.6pt),
  )
  ]

  La trayectoria es la moraleja del capítulo en dos columnas: pasar de $X_"ampliada"$ a la selección por ajuste eleva el $R^2$ de 0,80 a 0,99 y empeora el efecto de 1,00 a 0,00 — porque $P$ es el resultado leído tarde y $K$ medio-sueño en su dirección. En este mundo $U$ es un confusor y la especificación correcta es $X_"ampliada"$; si fuera un collider, como $B$, la correcta sería $X_"base"$ (que aquí da 1,35). La brecha entre las dos especificaciones es de 0,35 en un mundo y de 0,09 en el otro, y ambos valores superan la desviación entre repeticiones. Los datos no dicen en cuál estamos: eso lo dice el grafo. Lo que los datos sí dicen, sin ambigüedad, es que ninguna de las dos columnas de la tabla es negociable con el poder predictivo.
]

#repo-ref[
  Regeneración de la tabla: #code[Causal_AI/scripts/cap06_fuga.py] (semilla 13). La función auditora de referencia — recorre candidatas de roles y marcas sin omitir ninguna, trata lo falto de marca como no verificable: reproduce la tabla de decisión con `#code[auditar_features]` y `#code[columnas_X]`. El mismo patrón vive, con datos reales, en los escenarios del benchmark, cuyas covariables declaradas pre-tratamiento se exigen en `identification.json`.
]

== La regla conservadora y la comparación de especificaciones
<sec-de-06-doble>

Tres consecuencias prácticas cierran el contrato. *Primera: lo no verificable queda fuera.* Entre incluir una variable cuyo momento se ignora y excluirla, el contrato elige excluirla y reportarla: el riesgo de la exclusión (una confusión omitida) se ve en la comparación de las dos especificaciones; el de la inclusión (una fuga) no se ve en ningún lado. *Segunda: la discrepancia es información, no un problema a esconder.* Si $X_"base"$ y $X_"ampliada"$ coinciden materialmente, la ambigüedad de rol no era material y el efecto se reporta sobre la ampliada; si difieren, la identificación tiene que revisarse antes de registrar — la acción _revisar identificación_ del vocabulario del Cap. #ref(<de-cap-anatomia>, supplement: none) — y las dos estimaciones se registran ambas, porque una ficha que oculta la duda es una ficha falsa. *Tercera: la auditoría confía en el rol declarado, y sabe que lo hace.* Ningún filtro de marcas salva un collider anotado como confusor; por eso el contrato exige que la decisión sobre roles dudosos quede registrada con nombre y razón, y por eso el _as-of join_ no sustituye al grafo: una cosa son las fechas y las formas, y otra la causalidad misma.

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ Para el estudio de retornos a la educación, clasifique como candidatas: habilidad cognitiva medida antes de ingresar; puntaje del examen de egreso; cercanía a una universidad; ingreso de los padres. ¿Cuál pasa a $X_"base"$, cuál a $X_"ampliada"$ y cuál queda fuera? _Pista:_ el puntaje de egreso se mide después de gran parte de la escolaridad.

+ Un promedio móvil de 4 semanas del resultado puede ser un control legítimo o una fuga. ¿De qué depende, qué rol le asignaría en cada caso y qué marca de tiempo tiene que tener para pasar la auditoría? _Pista:_ si la ventana de la semana $t$ incluye el resultado de semanas en las que el tratamiento ya había cambiado, filtra efecto; la marca debe ser del final de la ventana.

+ En el caso canónico, la última fila tiene $R^2 = 0,99$ y efecto 0,00. Explique, con el grafo, por qué $K$ y $P$ vacían el coeficiente del tratamiento aunque el modelo prediga casi perfectamente. _Pista:_ $P arrow.l Y$ y $D arrow.r K arrow.l Y$ abren caminos no causales hasta $D$: condicionarlos es comparar personas iguales en el resultado, no iguales antes del tratamiento.

+ Un pipeline lambda computa sus agregados en un batch nocturno con corte "hasta ayer a medianoche". Escriba, con las preguntas de la @sec-de-06-asof, el invariante que el _as-of join_ debe cumplir para que un evento de las 23:55 entre y uno de las 00:05 no. ¿Qué zona horaria y qué forma de timestamp de medición hace falta registrar para no mentir? _Pista:_ la pregunta correcta es "¿cuándo era visible en producción?" — y la medianoche del batch no es la medianoche del evento.

+ La comparación de especificaciones da $hat(theta)_"base" = 0,9$ y $hat(theta)_"ampliada" = 1,4$. Un colega propone "reportar el intermedio 1,15 para no discutir". Interprételo con las tres consecuencias de la @sec-de-06-doble y con la acción que corresponde del vocabulario de las cinco. _Pista:_ 1,15 no es el estimando de ningún plano: la duda es de grafo, no de punto estimado; la acción es revisar identificación y registrar ambas.

=== Notas bibliográficas

La fuente de la discusión predictiva de la fuga y del _point-in-time correctness_ en _feature stores_ es @huyen2022dmls (Cap. 5); este capítulo especializa esa higiene al caso causal, donde añade además la distinción de roles y las dos especificaciones. La clasificación de controles legítimos y malos — confusores, mediadores, colliders — se desarrolla con precisión en la edición de método de este libro (@pearl2009causality, @bareinboim2025causalai). El sesgo de post-tratamiento en estudios observacionales, que la tabla de decisión evita mecánicamente, está en @hernan2020whatif. El argumento del contrato de que el rol ambiguo se reporta comparando especificaciones, no resolviéndolo a la callada, es la regla documentada del capítulo: los números del caso canónico son sus pruebas, reproducibles en el repositorio.

#verdad-datos[
  Que toda covariable que entre al estimando tenga marca de tiempo de medición, verificable como anterior al tratamiento y al momento de la decisión; el _as-of join_ cortando estricto en la fecha declarada por fila; dos especificaciones siempre calculadas y registradas si difieren; y ninguna candidata omitida en silencio — las que no pasen quedan reportadas. Se comprueba reproduciendo la tabla del caso canónico y, en producción, auditando las advertencias de C-03 contra los timestamps del origen. Lo que esta validez no comprueba: que los roles declarados sean los verdaderos — el auditado temporal y el auditado causal son, deliberadamente, dos cosas distintas, y la segunda sigue siendo trabajo del grafo.
]
