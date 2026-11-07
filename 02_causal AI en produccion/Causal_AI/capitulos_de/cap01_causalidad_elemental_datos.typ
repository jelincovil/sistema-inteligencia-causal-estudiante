// Capítulo 1: Causalidad elemental para ingeniería de datos.
// Edición de ingeniería de datos (main_de.typ). Caso canónico: scripts/cap01_simpson.py (semilla 7).
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Causalidad elemental para ingeniería de datos]
<de-cap-dato-estimando>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Distinguir qué comparación sostiene un dato: asociativa o causal],
    [*Idea central:*], [El estimando es una comparación, y el plano de datos decide si es computable],
    [*Herramienta:*], [Resultados potenciales $Y(1), Y(0)$; el invariante de comparabilidad],
    [*Caso canónico:*], [La reversión de Simpson, con verdad conocida (script con semilla)],
    [*Prepara:*], [El primer contrato del libro (Cap. #ref(<de-cap-contratos>, supplement: none)) y el registro de versiones (Cap. #ref(<de-cap-versionado>, supplement: none))],
  )
]

== Dos preguntas que parecen la misma
<sec-de-01-dos-preguntas>

Suponga dos preguntas sobre un programa de becas universitarias. La primera: _¿los estudiantes becados tienen, en promedio, mejores calificaciones que los no becados?_ La segunda: _¿dar una beca a un estudiante mejora sus calificaciones?_ Las dos se responden, en apariencia, con el mismo tipo de dato — una tabla de estudiantes, una marca de quién recibió beca y un registro de calificaciones — y sin embargo son preguntas radicalmente distintas. La primera es una pregunta *asociativa*: describe un patrón en los datos tal como existen. La segunda es una pregunta *causal*: describe qué pasaría si se interviniera el mundo, otorgando una beca que de otro modo no se habría otorgado.

La confusión entre ambas no es un error ingenuo, y no la comete solo quien estima. También la comete un pipeline. Un sistema que ingiere la tabla y computa "mejores calificaciones con beca" está respondiendo la primera pregunta con exactitud técnica impecable — ningún error de redondeo, ningún valor faltante, ninguna inconsistencia de formato — y sirviéndola en el lugar de la segunda. Quien diseñó el pipeline no mintió en ninguna parte; simplemente *nunca escribió qué comparación estaba computando*. Ese silencio es el origen del problema que ocupa a este libro: el dato, movido correctamente, entrega respuestas asociativas a un consumidor que cree haber pedido causales.

Y el silencio se vuelve más caro cuando el modelo deja de describir y pasa a decidir. Suponga que el programa usa el sistema para repartir los cupos entre quienes tienen mayor calificación esperada. Todo parecerá funcionar: el error de predicción es bajo, el tablero está en verde. Pero el sistema estará entregando las becas a quienes habrían obtenido buenas notas de todos modos, y el efecto que el programa buscaba producir se perderá sin que ninguna métrica de calidad de datos lo registre, porque *la fuga no es de datos: es de pregunta*. De ahí la pregunta que organiza este libro, y que ningún proceso de ingesta, por correcto que sea, contesta solo: _¿cuánto mejora la calificación de quienes reciben beca gracias al sistema, comparado con lo que habrían obtenido sin él?_ Este libro está dedicado a una tesis concreta: *ninguna cantidad de datos, por limpia y puntual que llegue, convierte una pregunta asociativa en una causal*. Convertir una en otra requiere supuestos explícitos sobre cómo se generaron los datos, y esos supuestos, en un sistema real, se ganan o se pierden en el plano de datos: en los roles de las columnas, en las marcas de tiempo, en las particiones, en las versiones.

== El estimando es una comparación que el dato debe sostener
<sec-de-01-estimando-comparacion>

Un ingeniero de datos no estima efectos: preserva lo que hace posible estimarlos. La traducción directa de la sección anterior al plano de datos empieza por una definición que el libro usa con el mismo sentido en todos sus capítulos.

#definition(name: [Estimando])[
  El estimando es la comparación causal que el sistema se obliga a servir: qué contraste — por ejemplo, el efecto promedio del tratamiento, $theta = E[Y(1) - Y(0)]$ —, sobre qué población, bajo qué supuestos declarados. El estimando no se "descubre" en los datos: se declara antes de mirar, y el plano de datos verifica después si la comparación declarada es computable con lo que hay.
]

La definición aparenta sencillez y tiene dientes. "Qué contraste" exige saber cuál es el tratamiento y cuál el resultado, por nombre de columna. "Sobre qué población" exige saber qué filas entran y por qué regla llegaron ahí. "Bajo qué supuestos" exige identificar qué covariables son legítimas para el ajuste, y eso solo puede declararse si alguien registró *cuándo se midió cada una y con qué rol causal*. Cuatro demandas de datos que una tabla ancha no lleva escritas por ninguna parte:

+ *Rama.* El dato debe registrar, unidad por unidad, en qué rama del contraste estuvo: tratada o no tratada. Sin la marca, no hay dos lados de la comparación que computar.
+ *Comparabilidad.* Las dos ramas deben ser comparables: si la asignación depende de variables que no se midieron, la comparación directa mezcla el efecto con la selección, en la dosis que desarrolla la @sec-de-01-problema-fundamental.
+ *Precedencia.* Las covariables de control deben medirse *antes* del tratamiento; una variable posterior es una fuga temporal, y el dato estándar no la distingue de una covariable legítima salvo que lleve marca de tiempo (@de-cap-tiempo).
+ *Unicidad.* El estimando es sobre una versión concreta de los datos; si la tabla cambia bajo los pies, la afirmación estimada ayer se refiere a nada hoy (@de-cap-versionado).

Estas demandas son la agenda del libro: el rol de las columnas es el contrato del Cap. #ref(<de-cap-contratos>, supplement: none); la unicidad de la versión, el del Cap. #ref(<de-cap-versionado>, supplement: none); la partición que permite evaluar con honestidad, el del Cap. #ref(<de-cap-particiones>, supplement: none); y la precedencia temporal, el del Cap. #ref(<de-cap-tiempo>, supplement: none). Cada una se escribe como un contrato numerado, porque una convención se recuerda y un contrato se ejecuta.

== La reversión de Simpson: la comparación que cambia de signo
<sec-de-01-simpson>

La advertencia de la sección anterior se estudia en su forma más cruda con una escena clásica, que aquí se responde con números generados por un proceso con verdad conocida.

#caso-canonico("La reversión de Simpson")[
  Un hospital evalúa dos tratamientos, A y B, para una misma condición. La gravedad del caso — 72 % de los pacientes llegan graves — decide en gran parte qué tratamiento recibe cada uno: el tratamiento A se reserva para los casos leves (lo recibe el 90 % de ellos) y el B para los graves (75 %). El dato dice la verdad completa: dentro de cada estrato, *B es mejor*; en casos leves, éxito de 0,86 con A contra 0,90 con B; en casos graves, 0,55 contra 0,60.

  #entero[
  #table(
    columns: (2fr, 1.4fr, 1.4fr, 2.2fr),
    align: (left, center, center, left),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Población*], [*A*], [*B*], [*Lectura*]),
    table.hline(stroke: 0.3pt),
    [Casos leves], [0,862], [0,904], [B mejor],
    [Casos graves], [0,548], [0,598], [B mejor],
    [Agregado], [0,732], [0,614], [A parece mejor],
    table.hline(stroke: 0.6pt),
  )
  ]

  Agregando, el veredicto se invierte: A tiene una tasa global de 0,732 contra 0,614 de B. No hay truco de medición: la inversión es consecuencia de que A trabajó sobre casos fáciles y B sobre casos difíciles, de modo que el agregado compara perfiles distintos. Con 40 000 pacientes simulados (semilla 7), el agregado y los estratos salen exactamente como lo indica la tabla; el script del repositorio reproduce la escena y sus tres lecturas. El problema no es estadístico, es semántico: el agregado responde la pregunta _¿cuáles pacientes mejoraron con A?_ y el estrato responde _¿cuál tratamiento conviene aplicar?_; solo la segunda es la pregunta causal.
]

La lección no es "desagregue siempre por gravedad", que la tabla misma deja sin defensa: si la asignación hubiera dependido de alguna otra variable — la hora de ingreso, el seguro, el barrio — el desagregado correcto sería otro. La lección es que *no existe una respuesta puramente estadística a qué desagregación es la correcta*: se requiere una teoría causal — la gravedad afecta a la asignación y al resultado — y esa teoría solo puede protegerse si el dato registra la gravedad como columna, con su tiempo de medida y su rol declarado. Cuando la gravedad no se mide, la inversión no se corrige; cuando se mide pero nadie declaró su rol, se corrige solo si alguien recuerda condicionar.

== El problema fundamental de la inferencia causal
<sec-de-01-problema-fundamental>

Formalicemos. Con el marco de resultados potenciales (Neyman, #cite(<neyman1923>, form: "year"); Rubin, #cite(<rubin1974>, form: "year")), cada unidad $i$ tiene dos resultados potenciales: $Y_i(1)$, el que se observaría si recibiera el tratamiento, y $Y_i(0)$, el que se observaría si no lo recibiera. El efecto causal individual es la diferencia $Y_i(1) - Y_i(0)$.

#definition(name: [El problema fundamental de la inferencia causal])[
  Para cualquier unidad $i$ solo se observa uno de los dos resultados potenciales, el de la rama que efectivamente recibió; el otro permanece contrafactual. El efecto individual $Y_i(1) - Y_i(0)$ nunca puede calcularse directamente para ninguna unidad, sin importar cuánto dato se recolecte sobre ella @holland1986.
]

Lo que sí puede estimarse, bajo supuestos, es un efecto promedio sobre grupos distintos. Lo que el dato entrega sin supuestos es la *diferencia de medias observada*, $Delta = E[Y | D = 1] - E[Y | D = 0]$, que con la restricción de consistencia $Y = D dot.c Y(1) + (1 - D) dot.c Y(0)$ se descompone en

$
Delta = underbrace(E[Y(1) - Y(0) | D = 1], "ATT: efecto sobre los tratados") + underbrace(E[Y(0) | D = 1] - E[Y(0) | D = 0], "sesgo de selección").
$ <de-eq-descomposicion>

El segundo término compara los resultados que tratados y no tratados habrían tenido *sin tratamiento*: es cero solo si ambos grupos eran comparables de partida, y es incalculable con datos, porque involucra el resultado potencial no observado. Las escenas de la @sec-de-01-simpson son casos donde ese término no es cero y domina. La aleatorización lo anula *por diseño* — si $D$ es independiente de $(Y(0), Y(1))$, entonces $Delta$ estima el efecto —, y lo que ningún experimento garantiza es exactamente lo que la mayoría de los pipelines hereda: una asignación decidida por alguien, con información que quedó o no quedó en los datos.

Aquí está la división de trabajo del libro. *El sesgo de selección no corrige nadie en el plano de datos*: no hay ninguna transformación, ninguna normalización y ningún test de calidad que lo mida, porque vive en la parte no observada de @de-eq-descomposicion. Lo que el plano de datos controla, y controla por completo, es si el sistema llega a la comparación con todo lo necesario para esa corrección: las marcas de rama, las covariables pre-tratamiento con sus tiempos, la partición honesta para evaluar y la versión exacta sobre la que se estimó. El plano de método — la edición hermana de este libro — aporta después los supuestos de identificación y el estimador. El plano de datos es, entonces, la condición necesaria: si destruye la comparación antes de llegar al estimador, ninguna teoría de identificación la rescata.

#figure(
  flujo-lineal(([pregunta causal], [estimando#linebreak()declarado], [roles y tiempos#linebreak()en el contrato], [partición#linebreak()sembrada], [estimación + abstención])),
  caption: [El camino del dato al estimando, con la demanda que cada pieza introduce. La comparación es computable solo si cada demanda anterior ya se cumple.],
) <de-fig-flujo-dato>

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ Para cada pregunta, indique si es asociativa o causal, y justifique en una oración: (a) ¿los países con más médicos per cápita tienen menor mortalidad infantil? (b) ¿contratar más médicos reduciría la mortalidad en un país específico? (c) ¿los clientes a quienes se les ofreció descuento renovaron más? (d) ¿la oferta de descuento hizo renovar a más clientes? _Pista:_ en cada caso, pregunte quién decidió a quién tratar y con qué información.

+ Proponga un ejemplo propio de correlación espuria por una variable confusora. ¿Está la confusora medida en su base de datos? Si no, dígalo qué demanda de las cuatro de la @sec-de-01-estimando-comparacion no se cumple. _Pista:_ si la confusora no existe como columna pre-tratamiento, el problema empieza antes del grafo.

+ En el caso canónico de Simpson, agregue un tercer tratamiento C, aplicado solo a graves, con tasa verdadera de éxito 0,55. ¿Qué lee el agregado? ¿Cambia lo que un pipeline debería registrar para discernir? _Pista:_ lo relevante sigue siendo la columna de gravedad y el rol del tratamiento; ninguna métrica de calidad detecta la inversión.

+ Un equipo entrena un modelo que predice ventas a partir de una marca de promoción, con $R^2$ de 0,95 fuera de muestra, y concluye que "la promoción explica el 95 % de las ventas". ¿Qué comparación computó el modelo, y qué comparación cree el equipo haber computado? _Pista:_ la asociación predicha mezcla efecto y selección; el $R^2$ alto dice solo que el patrón es estable.

+ Su equipo renombró la columna del resultado de `ingreso_2024` a `y`, y nadie lo comunicó. ¿Qué demanda de las cuatro queda rota primero, y en qué capítulo de este libro se escribe el contrato que la protege? _Pista:_ el estimando no cambió, pero la tabla dejó de ser la que el estimador cree leer; la primera línea de defensa es la unicidad de los roles (Cap. #ref(<de-cap-contratos>, supplement: none)).

=== Notas bibliográficas

El marco de resultados potenciales se origina en @neyman1923 para experimentos aleatorizados y se extiende a estudios observacionales en @rubin1974; #cite(<holland1986>, form: "prose") formaliza el problema fundamental, y su tratamiento completo, incluyendo cuándo el ATT y el ATE coinciden, está en @imbens2015causal, Capítulo 1. La descomposición en ATT más sesgo de selección es estándar; la exposición aplicada más leída es @hernan2020whatif. La paradoja de Simpson se describe en @simpson1951, documentada ya en @yule1903. La escalera de la causalidad de Pearl — asociación, intervención, contrafactual — se resume en @pearlmackenzie2018 y, en su versión formal, en la edición de método de este libro, junto al tratamiento completo de la identificación que este capítulo solo nombra. La lectura en términos de ingeniería — qué demanda del dato corresponde a qué pieza del sistema — es la contribución propia de esta edición, alimentada por la tradición de la ingeniería de datos de @kleppmann2017 y @reis2022fundamentals, a la que el Cap. #ref(<de-cap-contratos>, supplement: none) vuelve con su primer contrato.

#verdad-datos[
  Que una comparación asociativa y una causal se calculen sobre la misma tabla no las vuelve intercambiables; el signo de la lectura puede invertirse sin que cambie ninguna celda. Lo que debe ser verdad en los datos: las cuatro demandas de la @sec-de-01-estimando-comparacion — marcas de rama, ramas comparables, covariables anteriores al tratamiento, y una versión única de la tabla — y deben serlo *a nombre de columna y de fila*, no como intención. Se comprueban declarando el estimando antes de mirar y verificando después que la comparación declarada es la que el pipeline computó; ninguna métrica de calidad de datos estándar las vigilaba en el caso canónico, y allí mismo se vio el precio.
]
