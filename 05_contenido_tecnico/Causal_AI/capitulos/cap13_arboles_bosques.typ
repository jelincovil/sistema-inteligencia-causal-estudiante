// Capítulo 13: Árboles y bosques causales
// Edición en capas: la teoría (L0), los algoritmos en pseudocódigo (L1) y los casos canónicos (L2) son lo que dura;
// los listados (L3), la réplica con datos reales y los ejercicios computacionales van dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Árboles y bosques causales]
<cap-causal-forests>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Identificar subgrupos con efectos heterogéneos],
    [*Estimando:*], [$"CATE"(x)$],
    [*Identificación:*], [No confusión, soporte común, SUTVA],
    [*Método:*], [Árboles causales honestos, bosques causales, _Generalized Random Forests_ (GRF)],
    [*Nuisance:*], [$m(x) = E[Y | X = x]$, $e(x)$],
    [*Garantía:*], [Normalidad asintótica puntual, con partición honesta y submuestreo],
    ..if not es-principios {([*Librerías:*], [econml, grf (R)])},
    [*Validación:*], [Calibración, importancia de variables con cautela, _policy trees_],
  )
]

#notatecnica[
Los meta-learners del @cap-meta-learners reutilizan _learners_ genéricos de fuera de la caja; este capítulo presenta una familia diseñada específicamente para el CATE, los árboles y bosques causales con partición _honesta_, que ofrece una teoría de inferencia propia a costa de mayor especialización.
]

== Motivación aplicada
<sec-cap13_motivacion>

Un organismo público quiere saber en qué subgrupos de hogares un programa de transferencias condicionadas aumenta más la asistencia escolar. Supongamos, a modo de ilustración, que el efecto promedio es de 3 puntos porcentuales pero que en algunos subgrupos es nulo y en otros supera los 10. Identificar esos subgrupos permitiría focalizar el programa y mejorar su costo-efectividad, y equivocarse al identificarlos tiene un costo simétrico: se deja fuera a quienes sí se benefician o se gasta en quienes no.

Los _causal trees_ @athey2016recursive y los _causal forests_ @wager2018estimation, junto con su generalización, los _Generalized Random Forests_ @athey2019generalized, son métodos diseñados para estimar CATEs con intervalos de confianza asintóticamente válidos. La idea que lo hace posible es la _honestidad_: la muestra que decide la partición del árbol no es la que estima el efecto dentro de cada hoja. Eso evita el sobreajuste estructural de los árboles estándar, que eligen justamente las divisiones donde el ruido favorece una diferencia grande.

Conviene ubicar la contribución con precisión, porque el nombre "bosque causal" sugiere una analogía con el bosque aleatorio predictivo que es engañosa. Un bosque aleatorio predice promediando predicciones. La versión original de Wager y Athey (2018) promedia las estimaciones de hoja de cada árbol; la formulación de GRF, que es la que sigue la literatura posterior, hace algo distinto: usa los árboles para inducir *pesos de vecindad* $omega_(i)(x)$ (cuán a menudo la observación $i$ cae en la misma hoja que el punto de consulta $x$) y resuelve con ellos una ecuación de momento local. El bosque es, entonces, un procedimiento adaptativo para elegir *qué vecinos son relevantes* para estimar el efecto en $x$, y la estimación propiamente dicha la hace el score causal. Esta distinción, que la @sec-cap13_grf desarrolla con un ejemplo numérico, explica por qué el método admite intervalos de confianza mientras que un T-learner con bosques aleatorios no.

Este capítulo desarrolla la teoría de árboles y bosques causales, muestra con dos casos de resultado conocido qué aporta la honestidad y en qué se diferencian los dos estimadores, y discute cuándo el método es apropiado frente a los meta-learners o al DML con efecto constante.

== Teoría, supuestos y garantías
<sec-cap13_teoria>

=== Árboles causales honestos
<sec-cap13_arboles_causales>

Un _causal tree_ es un árbol de decisión que particiona el espacio de covariables $X$ en hojas $cal(L)_1, ..., cal(L)_M$. Dentro de cada hoja $cal(L)_m$, el CATE se estima como la diferencia de medias entre tratados y controles:
$
hat(tau)(cal(L)_m) = 1/n_(1,m) sum_(i in cal(L)_m, D_i = 1) Y_i - 1/n_(0,m) sum_(i in cal(L)_m, D_i = 0) Y_i.
$ <eq-causal-tree-tau>

Esta estimación es válida como efecto de la hoja si dentro de ella la asignación es aleatoria o ignorable dado $X$; con datos observacionales, la diferencia de medias dentro de la hoja solo es razonable si las hojas son lo bastante finas para que la no confusión condicional se sostenga. Por eso las versiones con _nuisance_ de las secciones siguientes reemplazan la diferencia de medias por un score ortogonalizado.

La _honestidad_ exige que la muestra usada para decidir las divisiones (_splitting subsample_) sea distinta de la usada para estimar $hat(tau)$ (_estimation subsample_). Se logra dividiendo la muestra de entrenamiento en dos mitades antes de construir el árbol.

#definition(name: [Honestidad])[
  Un árbol causal es _honesto_ si las decisiones de partición son independientes de los resultados que se usan para estimar $hat(tau)$ dentro de cada hoja. Formalmente, existe una partición de la muestra de entrenamiento $S = S_("split") union S_("est")$, con $S_("split") inter S_("est") = emptyset$, tal que el árbol se construye usando $S_("split")$ y los efectos se estiman usando $S_("est")$.
] <def-honesty>

*Por qué importa la honestidad.* Sin ella, el árbol elige las divisiones que maximizan la diferencia de medias _observada_ entre tratados y controles, y eso introduce un sesgo de selección (la _maldición del ganador_): los CATEs estimados en las hojas elegidas tienden a ser mayores, en valor absoluto, que los verdaderos. Con honestidad, las divisiones se eligen con una muestra y se evalúan con otra, de modo que, dada la partición, la estimación de cada hoja es una diferencia de medias común y sin sesgo de selección. El caso canónico de más abajo lo cuantifica.

#algorithm("Causal tree honesto")[
  #kwin[Entrada][Muestra ${(Y_i, D_i, X_i)}_(i=1)^n$, tamaño mínimo de hoja $n_(min)$, mínimo de tratados por hoja $n_(1,min)$, mínimo de controles por hoja $n_(0,min)$.]
  #kwout[Salida][Árbol $cal(T)$ con hojas $cal(L)_1, ..., cal(L)_M$ y estimaciones $hat(tau)(cal(L)_m)$.]
  Dividir la muestra en $S_("split")$ (partición) y $S_("est")$ (estimación). \
  Inicializar $cal(T)$ con una sola hoja (raíz) que contiene $S_("split")$. \
  *while* haya hojas factibles sin dividir: \
  #h(1.5em) Seleccionar una hoja $cal(L)$ de $cal(T)$. \
  #h(1.5em) *for* cada posible división binaria $X_j <= c$: \
  #h(3em) Calcular el criterio $Q$ de @eq-causal-tree-criterion con la división, usando $S_("split")$. \
  #h(1.5em) Elegir la división que maximiza $Q$. \
  #h(1.5em) Si ambas hojas hijas cumplen $n_(min), n_(1,min), n_(0,min)$ tanto en $S_("split")$ como en $S_("est")$, aplicarla. \
  *for* cada hoja $cal(L)_m$ del árbol final: \
  #h(1.5em) Estimar $hat(tau)(cal(L)_m)$ usando solo $S_("est")$ según @eq-causal-tree-tau. \
  #return-stmt[$cal(T)$ con $hat(tau)(cal(L)_m)$ por hoja.]
] <alg-causal-tree-honest>

Las restricciones de tamaño deben cumplirse también en $S_("est")$, porque es allí donde se estima: una hoja que en la muestra de estimación no tenga ningún control queda sin estimación, y una con uno o dos tiene un error de estimación que ningún criterio sobre $S_("split")$ anticipa.

=== El criterio de partición
<sec-cap13_splitting>

El criterio habitual de un árbol predictivo es la reducción de varianza del resultado. Para un árbol causal, @athey2016recursive proponen un criterio con dos términos, que en su forma honesta es
$
Q(Pi) = 1/N_("split") sum_(i in S_("split")) hat(tau)(X_i; Pi)^2 - (1/N_("split") + 1/N_("est")) sum_(l in Pi) (hat(sigma)_(1,l)^2 / p + hat(sigma)_(0,l)^2 / (1 - p)),
$ <eq-causal-tree-criterion>
donde $Pi$ es la partición, $hat(tau)(X_i; Pi)$ es la estimación de la hoja de $X_i$ calculada en $S_("split")$, $p$ es la fracción de tratados y $hat(sigma)_(d,l)^2$ es la varianza muestral del resultado entre las unidades con $D = d$ de la hoja $l$. El primer término premia las particiones cuyas hojas tienen efectos estimados distintos entre sí (como el promedio de los $hat(tau)$ casi no cambia de una partición a otra, maximizarlo equivale a maximizar la dispersión de los CATE estimados). El segundo castiga las hojas donde la estimación será ruidosa, y por eso aparece $N_("est")$: la penalización anticipa la varianza con la que se estimará en la muestra honesta. Los factores exactos varían entre versiones del criterio; lo que importa es la estructura, heterogeneidad premiada y varianza de hoja penalizada.

En los _Generalized Random Forests_ el criterio no se evalúa exhaustivamente sino que se aproxima con pseudo-resultados basados en el gradiente de la ecuación de momento, de modo que cada división cuesta lo mismo que una división de un árbol de regresión estándar.

#caso-canonico("Honestidad y falsos descubrimientos")[
  Mil unidades, diez covariables independientes y uniformes en $[0, 1]$, tratamiento aleatorio con probabilidad 1/2 y resultado $Y = D tau(X) + epsilon$ con $epsilon tilde N(0, 1)$. El "árbol" tiene una sola división: entre las diez covariables, se elige la que, partida en su mediana, da la mayor diferencia $|hat(Delta)|$ entre los efectos estimados de las dos hojas. Se compara el procedimiento *adaptativo* (elegir y estimar con las mismas mil unidades) con el *honesto* (elegir con 500 y estimar con las otras 500). Con 4 000 repeticiones:

  #table(
    columns: (2.6fr, 1fr, 1fr),
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Medida*], [*Adaptativo*], [*Honesto*]),
    table.hline(stroke: 0.3pt),
    [Sin efecto ($tau = 0$): muestras con diferencia "significativa" al 5 %], [41 %], [5 %],
    [Sin efecto: $|hat(Delta)|$ medio entre hojas], [0,24], [0,15],
    [Efecto 0,2 solo si $X_0 > 0.5$: la división elegida usa $X_0$], [41 %], [25 %],
    table.hline(stroke: 0.6pt),
  )

  Si la división se hubiera fijado de antemano, $|hat(Delta)|$ medio sería 0,10 con las mil unidades y 0,14 con 500: la selección multiplica por 2,4 la heterogeneidad aparente del procedimiento adaptativo, mientras que el honesto solo refleja el ruido de la mitad de la muestra. El adaptativo "descubre" una diferencia significativa en el 41 % de las muestras donde no hay ninguna, casi exactamente $1 - 0.95^(10) approx 0.40$: con diez divisiones candidatas, la mejor cruza el umbral por azar la mayor parte de las veces. El honesto mantiene la tasa nominal del 5 %. El precio está en la última fila: con heterogeneidad real, el procedimiento honesto elige la covariable correcta solo el 25 % de las veces, frente al 41 % del adaptativo, porque dispone de la mitad de la muestra para decidir. La salida a ese dilema son los bosques: cada árbol es honesto, pero con submuestras distintas, de modo que una misma observación sirve para dividir en unos árboles y para estimar en otros.
]

== Estimador y score
<sec-cap13_estimador>

=== Del árbol al bosque: pesos de vecindad
<sec-cap13_grf>

Un _causal forest_ es un conjunto de $B$ árboles causales honestos, cada uno construido sobre una submuestra de tamaño $s < n$ extraída *sin reemplazo*; el submuestreo, y no un _bootstrap_ de tamaño $n$, es lo que sustenta la teoría asintótica. La versión original @wager2018estimation estima el CATE como el promedio de las estimaciones de hoja:
$
hat(tau)_("CF")(x) = 1/B sum_(b=1)^B hat(tau)_(b)(x),
$ <eq-cf-average>
donde $hat(tau)_(b)(x)$ es la @eq-causal-tree-tau de la hoja del árbol $b$ que contiene a $x$.

La formulación de GRF @athey2019generalized reescribe el bosque como un generador de pesos. Con $cal(L)_b (x)$ la hoja del árbol $b$ que contiene a $x$ y $S_("est",b)$ su muestra de estimación, el peso de la observación $i$ es
$
omega_(i)(x) = 1/B sum_(b=1)^B (bold(1){X_i in cal(L)_b (x), i in S_("est",b)}) / (|{j in S_("est",b) : X_j in cal(L)_b (x)}|),
$ <eq-grf-weights>
que suma 1 y es grande cuando $i$ cae a menudo en la misma hoja que $x$. El parámetro local $hat(theta)(x)$ se obtiene resolviendo una ecuación de momento ponderada, $sum_i omega_(i)(x) psi_(hat(theta)(x))(O_i) = 0$. Para el CATE con tratamiento ortogonalizado, el score es el del R-learner (@cap-meta-learners) y la solución tiene forma cerrada:
$
hat(tau)(x) = (sum_i omega_(i)(x) (Y_i - hat(m)(X_i))(D_i - hat(e)(X_i))) / (sum_i omega_(i)(x) (D_i - hat(e)(X_i))^2),
$ <eq-grf-tau>
una regresión de residuos sobre residuos, pero local, con pesos que el bosque elige adaptativamente. Los _nuisance_ $hat(m)$ y $hat(e)$ se estiman con _cross-fitting_ o con predicciones fuera de bolsa, por el mismo motivo de ortogonalidad del @cap-ortogonalidad. Si el tratamiento es binario y los _nuisance_ se toman constantes en la vecindad de $x$, la @eq-grf-tau es la pendiente de una regresión ponderada de $Y$ sobre $D$, es decir, la diferencia ponderada de medias entre tratados y controles.

#caso-canonico("Mismo bosque, dos estimadores")[
  Un bosque de dos árboles y seis observaciones. Para el punto de consulta $x$, la hoja del árbol 1 contiene a las observaciones 1 a 4 y la del árbol 2, a las observaciones 3 a 6.

  #table(
    columns: (auto, auto, auto, auto, auto, auto, auto),
    align: (center, center, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*$i$*], [*1*], [*2*], [*3*], [*4*], [*5*], [*6*]),
    table.hline(stroke: 0.3pt),
    [$D_i$], [1], [0], [1], [0], [1], [1],
    [$Y_i$], [5], [1], [4], [2], [9], [5],
    [Hoja árbol 1], [sí], [sí], [sí], [sí], [no], [no],
    [Hoja árbol 2], [no], [no], [sí], [sí], [sí], [sí],
    [$omega_(i)(x)$], [1/8], [1/8], [1/4], [1/4], [1/8], [1/8],
    table.hline(stroke: 0.6pt),
  )

  En la hoja 1, los tratados valen en promedio 4,5 y los controles 1,5, de modo que $hat(tau)_1 = 3.0$. En la hoja 2, hay tres tratados (promedio 6) y un solo control (valor 2), de modo que $hat(tau)_2 = 4.0$. El promedio de árboles de la @eq-cf-average es $(3.0 + 4.0) / 2 = 3.50$. Con los pesos de la @eq-grf-weights, los tratados (1, 3, 5, 6) suman peso 5/8 y su media ponderada es 5,40, y los controles (2, 4) suman 3/8 y su media ponderada es 1,67, de modo que el estimador ponderado da $5.40 - 1.67 = 3.73$.

  Los dos estimadores no coinciden, y la razón es estructural. El promedio de árboles trata las dos hojas como igual de informativas aunque la segunda estime el nivel de los controles con una sola observación. El estimador ponderado reúne todas las observaciones vecinas y da más peso a las que aparecen cerca de $x$ en ambos árboles (las observaciones 3 y 4). No es un detalle de implementación: es la razón por la que GRF permite una teoría de varianza para la ecuación de momento completa y no solo para cada hoja.
]

#intuicion[
  El bosque no estima el efecto; decide a quién se parece $x$. Cada árbol propone una vecindad de $x$ construida con la información de $S_("split")$, el bosque promedia esas vecindades en pesos $omega_(i)(x)$, y el efecto sale de comparar tratados y controles ponderados por esos pesos. Por eso el bosque puede ser flexible en la forma en que $tau$ depende de $X$ sin que la estimación deje de ser una comparación de tratados y controles entre unidades parecidas.
]

#algorithm("Causal forest (GRF), esquema")[
  #kwin[Entrada][Muestra ${(Y_i, D_i, X_i)}_(i=1)^n$, número de árboles $B$, tamaño de submuestra $s < n$, punto de consulta $x$.]
  #kwout[Salida][$hat(tau)(x)$ y una estimación de su varianza.]
  Estimar $hat(m)(X_i)$ y $hat(e)(X_i)$ con _cross-fitting_ o predicciones fuera de bolsa. \
  Calcular los residuos $tilde(Y)_i = Y_i - hat(m)(X_i)$ y $tilde(D)_i = D_i - hat(e)(X_i)$. \
  *for* $b = 1, ..., B$: \
  #h(1.5em) Extraer una submuestra $S_b$ de tamaño $s$ sin reemplazo y dividirla en $S_(b)^("split")$ y $S_(b)^("est")$. \
  #h(1.5em) Construir un árbol honesto sobre $S_(b)^("split")$ dividiendo según heterogeneidad de $tilde(Y)$ y $tilde(D)$. \
  Calcular los pesos $omega_(i)(x)$ de @eq-grf-weights sobre las muestras de estimación. \
  Calcular $hat(tau)(x)$ con @eq-grf-tau. \
  Estimar la varianza con un _jackknife infinitesimal_ por grupos de árboles. \
  #return-stmt[$hat(tau)(x)$ y su varianza estimada.]
] <alg-causal-forest>

#theorem(name: [Normalidad asintótica puntual del bosque causal])[
  Sean los datos i.i.d. con no confusión condicional y solape, $mu_(0)(x)$ y $mu_(1)(x)$ Lipschitz en $x$ y covariables con soporte acotado. Sea $hat(tau)(x)$ un bosque cuyos árboles son honestos, regulares, de divisiones con aleatoriedad y simétricos, entrenados sobre submuestras sin reemplazo de tamaño $s tilde n^beta$, con $beta$ en un intervalo $(beta_("min"), 1)$ que depende de la dimensión de $X$ y de la regularidad de los árboles. Entonces existe una varianza estimable $hat(V)(x)$ tal que
  $
  (hat(tau)(x) - tau(x)) / sqrt(hat(V)(x)) arrow.r^(d) N(0, 1),
  $
  y el estimador de varianza por _jackknife infinitesimal_ es consistente.
] <thm-cf-normality>

  #cite(<wager2018estimation>, form: "prose") demuestran este resultado para el estimador de la @eq-cf-average, y la extensión a los scores de GRF sigue el mismo argumento. Cuatro precisiones evitan que se lea más de lo que dice. Primera, la tasa de convergencia es local, depende de la probabilidad de caer en hojas cercanas a $x$, y no es una normalización $sqrt(n)$ universal; empeora con la dimensión de $X$, y $beta_("min")$ se acerca a 1 cuando $X$ tiene muchas covariables relevantes. Segunda, el resultado es *puntual*: cubre $tau(x)$ para un $x$ fijo y no a toda la función a la vez. Tercera, es una cobertura para el efecto condicional promedio $tau(x)$, no para el efecto individual $Y_(i)(1) - Y_(i)(0)$, que incluye un ruido que la varianza del estimador no captura (el @cap-validacion separa este objeto del intervalo conforme para un pseudoresultado). Cuarta, la garantía es asintótica y en muestras finitas el error de cobertura lo domina el sesgo, no la varianza: con muestras pequeñas o con $tau$ muy irregular, los intervalos son optimistas.

=== Comparación con meta-learners
<sec-cap13_comparacion_metalearners>

#figure(
  caption: [Bosque causal frente a meta-learners.],
  table(
    columns: (1.1fr, 1.7fr, 1.7fr),
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Dimensión*], [*Bosque causal (GRF)*], [*Meta-learners (S, T, X, DR, R)*]),
    table.hline(stroke: 0.4pt),
    [Inferencia sobre $tau(x)$], [Intervalos puntuales con teoría asintótica y varianza por _jackknife_ en grupos de árboles], [Con regresión final genérica, solo _bootstrap_ sin garantía de cobertura; con regresión final de series o de polinomios locales, el DR-learner sí la tiene @kennedy2023towards],
    [Flexibilidad], [Alta; la elige la partición adaptativa], [Alta; la elige el _learner_ base],
    [Honestidad], [Parte del diseño], [Opcional, solo si el _learner_ base la incorpora],
    [Lectura del resultado], [Pesos de vecindad inspeccionables; importancia de variables heurística], [Depende del _learner_ base],
    [Alta dimensión], [La tasa de inferencia se deteriora con la dimensión efectiva], [Depende del _learner_ base],
    [Caso ideal], [Se quieren intervalos puntuales sin especificar la forma de $tau$], [Se prioriza el error de estimación, o hay estructura conocida],
    table.hline(stroke: 0.8pt),
  )
) <tab-cf-vs-meta>

== Validación y lectura de la heterogeneidad
<sec-cap13_validacion>

=== Calibrar antes de interpretar
<sec-cap13_calibracion>

Un bosque produce un $hat(tau)(x)$ para cada unidad, y un mapa de esos valores siempre parece mostrar heterogeneidad, incluso cuando se ajusta sobre ruido (el caso canónico de la @sec-cap13_splitting ya mostró cuán fácil es que la selección la fabrique). Antes de leer el mapa hay que comprobar que contiene señal. La prueba de calibración regresa el resultado residualizado sobre dos términos, la predicción media y la desviación de cada predicción respecto de la media, ambos multiplicados por el tratamiento residualizado. Un coeficiente de la desviación cercano a 1 indica que el bosque capta heterogeneidad real y con la escala correcta; cercano a 0, que las diferencias entre predicciones son ruido; el de la predicción media debe rondar 1 si el nivel promedio está bien. La @sec-cap14_tests_heterogeneidad desarrolla este protocolo con BLP, BEST y CLAN y fija la regla de reporte: un mapa de heterogeneidad sin ese contraste es exploratorio.

=== Importancia de variables y _policy trees_
<sec-cap13_policy_trees>

#intuicion[
  *Caja de profundización: importancia de variables y _policy trees_*

  *Objetivo.* Interpretar un bosque causal más allá del CATE promedio sin sobreinterpretarlo.

  *¿Qué variables explican la heterogeneidad?* La importancia de variables de un bosque causal mide con qué frecuencia, y a qué profundidad, se usa cada variable para dividir. Es una pista de dónde mirar, no una medida de cuánto modifica el efecto cada variable: dos covariables muy correlacionadas se reparten la importancia, y una variable puede ser elegida por ruido. Sirve para decidir qué cortes explorar con un test, nunca como resultado por sí sola.

  *_Policy trees_: reglas simples para decidir.* Un _policy tree_ es un árbol de decisión de poca profundidad (2 o 3 niveles) que asigna el tratamiento. A diferencia de un árbol ajustado a los CATE estimados, se entrena maximizando el valor estimado de la política, la suma de los scores doblemente robustos $Gamma_i$ del @cap-meta-learners sobre las unidades que la regla manda a tratar. Produce reglas como «si edad $> 30$ y educación $> 12$, tratar; si no, no tratar».

  #cite(<athey2021policy>, form: "prose") formalizan este objeto: la clase de árboles de profundidad acotada tiene dimensión VC finita, lo que permite acotar el _regret_ de la política aprendida respecto de la mejor política *dentro de esa clase*. El @cap-policy-learning desarrolla el resultado; aquí basta retener que la interpretabilidad del _policy tree_ no es solo una concesión a la comunicación, sino la fuente misma de su garantía estadística: restringir la clase de políticas es lo que evita sobreajustar la regla de decisión al ruido del CATE estimado.

  *Cuidado con buscar subgrupos «a ojo».* Si se miran los datos para encontrar subgrupos con efectos grandes, aparecen incluso cuando no existen. Un _policy tree_ con honestidad y validación reduce el problema, y la pre-especificación de los subgrupos de interés lo evita casi por completo.
]

#capa-impl[
== Implementación en Python
<sec-cap13_implementacion>

=== Estimación con #code[CausalForestDML]
<sec-cap13_causaldml>

#figure(
  kind: raw,
  caption: [Causal Forest sobre NSW con mapas de heterogeneidad.],
  ```python
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from econml.dml import CausalForestDML
from sklearn.ensemble import GradientBoostingRegressor, GradientBoostingClassifier

df = pd.read_csv("../data/datasets/real/public_causaldata/nsw_mixtape/data.csv")
Y = df["re78"].values
D = df["treat"].values
X = df[["age", "educ", "black", "hisp", "marr", "nodegree", "re74", "re75"]].values

cf = CausalForestDML(
    model_y=GradientBoostingRegressor(n_estimators=200, max_depth=4, random_state=42),
    model_t=GradientBoostingClassifier(n_estimators=200, max_depth=4, random_state=42),
    discrete_treatment=True,
    n_estimators=400,
    min_samples_leaf=20,
    max_depth=8,
    cv=5,
    random_state=42,
)
cf.fit(Y, D, X=X)

# ATE
ate = cf.ate(X=X); lb, ub = cf.ate_interval(X=X, alpha=0.05)
print(f"ATE: {ate:.2f}  IC 95%: [{lb:.2f}, {ub:.2f}]")

# CATE
cate = cf.effect(X)
cate_lb, cate_ub = cf.effect_interval(X, alpha=0.05)
# cate_lb y cate_ub pueden usarse para graficar intervalos de confianza
# en mapas de heterogeneidad (no mostrado aquí).

# Mapa de heterogeneidad: CATE vs edad y educacion
fig, axes = plt.subplots(1, 2, figsize=(12, 5))
axes[0].scatter(df["age"], cate, c=cate, cmap="viridis", alpha=0.6)
axes[0].set_xlabel("Edad"); axes[0].set_ylabel("CATE estimado")
axes[0].set_title("Heterogeneidad por edad")
axes[1].scatter(df["educ"], cate, c=cate, cmap="viridis", alpha=0.6)
axes[1].set_xlabel("Educacion"); axes[1].set_ylabel("CATE estimado")
axes[1].set_title("Heterogeneidad por educacion")
plt.tight_layout()
plt.savefig("figuras/cf_heterogeneity_nsw.png", dpi=120, bbox_inches="tight")
plt.show()
```
) <lst-causal-forest-nsw>

=== Comparación con un X-learner
<sec-cap13_comparacion_implementacion>

#figure(
  kind: raw,
  caption: [Causal Forest vs. X-learner en datos sintéticos.],
  ```python
import numpy as np
from econml.dml import CausalForestDML
from econml.metalearners import XLearner
from sklearn.ensemble import GradientBoostingClassifier, GradientBoostingRegressor
# DGP con heterogeneidad estructurada
def make_heterogeneous_dgp(n=2000, seed=0):
    rng = np.random.default_rng(seed)
    X = rng.uniform(-1, 1, (n, 5))
    tau = 2 * X[:, 0] + X[:, 1] * X[:, 2]
    e = 0.5 + 0.3 * np.tanh(X[:, 3])
    D = (rng.uniform(size=n) < e).astype(int)
    Y = X[:, 4] + D * tau + rng.standard_normal(n) * 0.5
    return Y, D, X, tau

Y, D, X, tau_true = make_heterogeneous_dgp(2000, seed=42)
# Causal Forest
cf = CausalForestDML(n_estimators=400, min_samples_leaf=20, random_state=42,
                     model_y=GradientBoostingRegressor(),
                     model_t=GradientBoostingClassifier(),
                     discrete_treatment=True).fit(Y, D, X=X)
tau_cf = cf.effect(X)
# X-learner
xl = XLearner(models=GradientBoostingRegressor(),
              propensity_model=GradientBoostingClassifier()).fit(Y, D, X)
tau_xl = xl.effect(X)

print(f"CF RMSE: {np.sqrt(np.mean((tau_cf - tau_true)**2)):.4f}")
print(f"XL RMSE: {np.sqrt(np.mean((tau_xl - tau_true)**2)):.4f}")
```
) <lst-cf-vs-xl>

El resultado depende del DGP, del tamaño de muestra y de los _learners_ base; este listado es para repetir la comparación con otras semillas y tamaños, no para extraer un ranking.

=== Importancia de variables
<sec-cap13_feature_importance>

#figure(
  kind: raw,
  caption: [Importancia de variables en causal forest.],
  ```python
# Según la versión de econml, es una propiedad (cf.feature_importances_)
# o un método (cf.feature_importances()). Comprobar en la versión instalada.
importances = cf.feature_importances_
features = ["age", "educ", "black", "hisp", "marr", "nodegree", "re74", "re75"]
order = np.argsort(importances)[::-1]
for i in order:
    print(f"{features[i]:>12}: {importances[i]:.4f}")
```
) <lst-cf-importance>

=== Réplica sobre el programa NSW
<sec-cap13_nsw>

El listado #ref(<lst-causal-forest-nsw>, supplement: [listado]) define una réplica sobre #code[nsw_mixtape] (Lalonde, 1986), con 445 observaciones y ocho controles observables. Esta edición no reporta cifras de esa corrida porque la biblioteca necesaria no formaba parte del entorno de verificación. Antes de interpretar un ATE o un mapa de CATE, la réplica debe ejecutarse con la misma versión de datos y de biblioteca, fijar la semilla y aplicar el protocolo de calibración de la @sec-cap13_calibracion. La heterogeneidad aparente de un bosque no es evidencia suficiente para focalizar una política.
]

#pagebreak(weak: true)
== Riesgos, límites y sensibilidad
<sec-cap13_riesgos>

=== Tabla de riesgos
<sec-cap13_tabla_riesgos>

La tabla #ref(<tab-riesgos-cf>, supplement: none) resume los riesgos principales al usar árboles y bosques causales, junto con sus consecuencias, diagnósticos y estrategias de mitigación.

#riesgos[
  #set text(size: 9pt)
  #figure(
    caption: [Riesgos al usar árboles y bosques causales.],
    table(
      columns: (1.2fr, 1.5fr, 1.5fr, 1.8fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Árbol sin honestidad],
      [Sesgo de selección: los CATEs estimados en hojas tienden a ser mayores que los verdaderos],
      [Comparar estimaciones con y sin honestidad sobre la misma muestra, como en el caso canónico],
      [Partición explícita $S_("split") union S_("est")$; que las restricciones de tamaño valgan también en $S_("est")$],
      table.hline(stroke: 0.4pt),
      [Mapa de heterogeneidad sin calibrar],
      [Se interpreta como señal una dispersión que puede ser ruido],
      [Coeficiente de calibración de la desviación cercano a 0 o con intervalo que incluye el cero],
      [Reportar como exploratorio todo mapa sin ese contraste (@sec-cap14_tests_heterogeneidad)],
      table.hline(stroke: 0.4pt),
      [Búsqueda de subgrupos y comparaciones múltiples],
      [Falsos descubrimientos: efectos grandes donde no existen, e inflación del error tipo I al comparar muchos subgrupos],
      [Pre-registrar los subgrupos de interés; reportar todos los evaluados y el número de comparaciones],
      [Validación fuera de muestra con placebos y Qini; Bonferroni o FDR (_False Discovery Rate_); _policy trees_ con honestidad y validación],
      table.hline(stroke: 0.4pt),
      [Importancia de variables leída como causal],
      [Se atribuye a una variable un efecto que es de otra correlacionada, o ruido],
      [Repetir con otra semilla y con grupos de variables correlacionadas],
      [Usarla solo para elegir qué cortes contrastar con un test, no como resultado],
      table.hline(stroke: 0.4pt),
      [CATE fuera del soporte común],
      [El CATE no es identificable en regiones sin tratados o sin controles],
      [Reportar $hat(e)(x)$ para cada observación e inspeccionar su distribución],
      [Restringir el análisis al soporte común; no extrapolar a regiones sin solapamiento],
      table.hline(stroke: 0.4pt),
      [Muestra pequeña o $tau$ muy irregular],
      [Intervalos anchos o optimistas; inestabilidad del árbol; cobertura dominada por el sesgo],
      [Ancho promedio del IC y sensibilidad a la semilla del submuestreo],
      [Agrupar subgrupos, aumentar $n_(min)$ o usar métodos paramétricos más parsimoniosos],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cf>
]

=== Límites
<sec-cap13_limites>

El bosque causal estándar identifica con no confusión condicional y solape; los confusores no observados sesgan el CATE y ningún intervalo lo corrige. Para tratamientos con instrumento, GRF ofrece una variante cuya ecuación de momento es la del diseño de variables instrumentales (un _bosque instrumental_), y el capítulo #ref(<cap-panel-dmliv>, supplement: none) desarrolla el caso con instrumentos. Con datos agrupados o de panel, las submuestras y la honestidad deben formarse por grupo, no por observación: si observaciones de un mismo grupo caen en $S_("split")$ y en $S_("est")$, la dependencia dentro del grupo rompe la independencia que la honestidad supone y los intervalos resultan optimistas. Los efectos dinámicos en el tiempo requieren extensiones específicas.

== Ejercicios propuestos
<sec-cap13_ejercicios>

=== Ejercicios teóricos

+ Con una división fija, el estimador de la diferencia entre dos hojas tiene error estándar $sigma sqrt(8 / n_("hoja"))$ si cada hoja tiene $n_("hoja")$ unidades y la mitad tratadas. Muestre que, con $p$ divisiones candidatas independientes y ningún efecto, la probabilidad de que la mejor cruce $|z| > 1.96$ es $1 - 0.95^p$, y compárela con la tasa de 41 % del caso canónico para $p = 10$. ¿Por qué la coincidencia es solo aproximada?

+ En el caso canónico "Mismo bosque, dos estimadores", elimine la observación 6 (la hoja 2 pasa a tener las observaciones 3, 4 y 5) y recalcule el promedio de árboles y el estimador ponderado. ¿Cuál de los dos cambia más y por qué?

+ Explique por qué un T-learner con bosques aleatorios como _learners_ base no admite los intervalos del teorema de normalidad asintótica puntual de la @sec-cap13_grf, aunque use los mismos árboles. Nombre al menos tres ingredientes que el bosque causal añade.

+ Muestre que, con tratamiento binario y $hat(m)$ y $hat(e)$ constantes en la vecindad de $x$, la @eq-grf-tau es la pendiente de una regresión ponderada de $Y$ sobre $D$ con pesos $omega_(i)(x)$ y que esa pendiente es la diferencia ponderada de medias.

+ Con datos de $M$ escuelas y varios estudiantes por escuela, argumente por qué la honestidad debe aplicarse por escuela. ¿Qué se rompe si la división se hace por estudiante?

#capa-impl[
=== Ejercicios computacionales

+ Replique el #ref(<lst-causal-forest-nsw>, supplement: [listado]) variando #code[min_samples_leaf] en ${5, 10, 20, 50}$. ¿Cómo cambia la heterogeneidad estimada? Acompañe cada variante de la prueba de calibración.

+ Compare el bosque causal con el R-learner sobre el dataset #code[cps_mixtape]. ¿Qué método identifica más heterogeneidad, y con qué intervalos?

+ Use un bosque causal para estimar la heterogeneidad del efecto de primera etapa de #code[nearc4] sobre #code[educ] en el dataset #code[close_college]. ¿Qué subgrupos muestran mayor efecto del instrumento sobre la educación? Esto no es el CATE de #code[educ] sobre #code[lwage], sino la heterogeneidad en la primera etapa del diseño IV.

+ Implemente un árbol causal honesto «a mano» (sin #code[econml]) dividiendo la muestra en $S_("split")$ y $S_("est")$. Compare con la implementación de #code[econml] y con una versión adaptativa que estime en la misma muestra en que parte. Repita el caso canónico de la @sec-cap13_splitting.
]

== Lecturas complementarias
<sec-cap13_lecturas>

#cite(<athey2016recursive>, form: "prose") es el _paper_ fundacional de los árboles causales y del criterio de partición honesto. #cite(<wager2018estimation>, form: "prose") establece la consistencia y la normalidad asintótica puntual de los bosques causales, con la estimación de varianza por _jackknife infinitesimal_ que hace posibles los intervalos de la @sec-cap13_grf. #cite(<athey2019generalized>, form: "prose") generaliza el marco a GRF, reinterpretando el bosque como generador de pesos adaptativos para una ecuación de momento local (la lectura que este capítulo adopta). #cite(<athey2021policy>, form: "prose") es la referencia de los _policy trees_ mencionados en la caja de profundización y se desarrolla en el @cap-policy-learning.#capa-impl[ #cite(<oprescu2023econml>, form: "prose") documenta la implementación en #code[econml]; la implementación de referencia en R es el paquete `grf` de los propios autores.]
