// Capítulo 6: Regularización, selección de variables y sesgo post-selección
// Edición en capas: la teoría (L0), el pseudocódigo (L1) y los casos canónicos con cifras verificadas (L2)
// son lo que dura; los listados (L3) van dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Regularización, selección de variables y sesgo post-selección]
<cap-regularizacion>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Sesgo post-selección al inferir después de seleccionar variables],
    [*Estimando:*], [$theta_0$ en regresión de alta dimensión],
    [*Identificación:*], [No confusión condicional y esparsidad aproximada],
    [*Método:*], [LASSO, Ridge, Elastic Net, Post-LASSO OLS],
    [*Nuisance:*], [Selección de variables],
    [*Garantía:*], [Tasa $ell_2$ bajo _restricted eigenvalue_ (@bickel2009simultaneous); consistencia de *selección* solo bajo irrepresentabilidad (@zhao2006model), una condición mucho más fuerte],
    ..if not es-principios {([*Librerías:*], [scikit-learn, numpy])},
    [*Validación:*], [Monte Carlo con efecto conocido, sensibilidad a $lambda$],
  )
]

#notatecnica[
El @cap-prediccion-causalidad estableció que responder una pregunta causal en alta dimensión exige seleccionar controles sin sesgar la inferencia. Este capítulo formaliza ese problema, la selección de variables y el sesgo post-selección que induce, y es, junto con el capítulo anterior, el prerrequisito técnico de Double Machine Learning (@cap-dml, Parte II).
]

== Problema causal, estimando e identificación
<sec-cap06_problema>

Una economista laboral quiere estimar el efecto de un programa de capacitación sobre el salario posterior. Dispone de un panel con 80 variables de control potenciales: características demográficas, historial laboral, sector, región, características del empleador, expectativas subjetivas y un conjunto de variables administrativas. No sabe cuáles de ellas son confusoras (asociadas a la vez con la asignación al programa y con el salario) y cuáles son irrelevantes. La intuición clásica sugiere incluirlas todas, pero con 80 controles y $n = 1~000$ observaciones OLS tiene una varianza alta y poca potencia.

La salida aparentemente natural es seleccionar variables con LASSO y luego correr OLS con las seleccionadas. Es una idea peligrosa: la selección induce un sesgo en la inferencia posterior que se conoce como _post-selection inference_ o inferencia selectiva. @leeb2006can y @potscher2009confidence mostraron que los intervalos construidos después de una selección consistente pueden tener una cobertura muy inferior a la nominal, y que el problema no desaparece con muestras grandes.

El capítulo desarrolla tres ideas. Primero, presenta LASSO, Ridge y Elastic Net como métodos de regularización con propiedades estadísticas distintas. Segundo, formaliza el sesgo post-selección y muestra por qué la inferencia ingenua puede fallar y por qué a veces no falla: la diferencia depende de qué tan fuertes sean las confusoras. Tercero, anticipa la solución, la doble selección de Belloni, Chernozhukov y Hansen (@cap-pds), como ejemplo de cómo el ML puede integrarse con inferencia válida cuando el procedimiento respeta la estructura del problema causal.

== Teoría, supuestos y garantías
<sec-cap06_teoria>

=== Supuestos
<sec-cap06_supuestos>

Para que LASSO sea consistente en alta dimensión se requiere esparsidad: solo unas pocas componentes de $beta$ son distintas de cero. Para leer el coeficiente de $D$ como un efecto causal se requiere además la no confusión condicional del @cap-prediccion-causalidad, con los controles $X$ como conjunto de ajuste.

#assumption(name: [Esparsidad])[
  El vector verdadero $beta_0$ tiene a lo más $s << n$ componentes no nulas, con $s log p = o(n)$.
] <asu-sparsity>

=== Estimadores penalizados
<sec-cap06_estimador>

Sea el modelo lineal de alta dimensión $bold(Y) = bold(X) beta + epsilon$, con $bold(X) in RR^(n times p)$ y $beta in RR^p$. Cuando $p$ es comparable a $n$ o mayor, OLS tiene una varianza alta o ni siquiera está definido ($p > n$). Los estimadores penalizados resuelven el problema contrayendo los coeficientes hacia cero.

#definition(name: [LASSO])[
  El estimador LASSO @tibshirani1996lasso resuelve
  $
  hat(beta)_("LASSO") = op("argmin", limits: #true)_(beta in RR^p) { (1 / (2n)) norm(Y - X beta)_2^2 + lambda norm(beta)_1 },
  $
  donde $norm(beta)_1 = sum_j abs(beta_j)$ es la norma $ell_1$ y $lambda >= 0$ el hiperparámetro de penalización.
] <def-lasso>

#definition(name: [Ridge])[
  El estimador Ridge @hoerl1970ridge usa la penalización $ell_2$:
  $
  hat(beta)_("Ridge") = op("argmin", limits: #true)_beta { (1 / (2n)) norm(Y - X beta)_2^2 + lambda norm(beta)_2^2 }.
  $
] <def-ridge>

#definition(name: [Elastic Net])[
  Elastic Net @zou2005elasticnet combina ambas penalizaciones:
  $
  hat(beta)_("EN") = op("argmin", limits: #true)_beta { (1 / (2n)) norm(Y - X beta)_2^2 + lambda [ alpha norm(beta)_1 + (1 - alpha) norm(beta)_2^2 ] },
  $
  con $alpha in [0, 1]$ que mezcla las dos penalizaciones.
] <def-elasticnet>

La diferencia clave es que LASSO produce _selección de variables_ (algunos $hat(beta)_j$ son exactamente cero), mientras que Ridge solo contrae los coeficientes sin seleccionar. Elastic Net combina ambos comportamientos y es preferible cuando hay grupos de variables muy correlacionadas.

=== Garantías de estimación
<sec-cap06_garantias>

#theorem(name: [Tasa de convergencia del LASSO])[
  Bajo esparsidad y la _restricted eigenvalue condition_ de @bickel2009simultaneous con constante $kappa > 0$, si $lambda asymp sqrt(log p \/ n)$, entonces con probabilidad alta
  $
  norm(hat(beta)_("LASSO") - beta_0)_1 = O_(p)(s sqrt(log p \/ n)), quad
  norm(hat(beta)_("LASSO") - beta_0)_2 = O_(p)(sqrt(s log p \/ n)).
  $
] <thm-lasso-rate>

La tasa $sqrt(s log p \/ n)$ es óptima en el sentido minimax, salvo constantes y factores logarítmicos. Pero el teorema garantiza consistencia en norma $ell_2$, no componente a componente y menos aún del *conjunto seleccionado*. Aunque $hat(beta)_("LASSO")$ se acerque a $beta_0$ en norma global, cada componente puede tener un sesgo apreciable, sobre todo las que el LASSO contrae o selecciona mal.

=== Recuperar el soporte exige mucho más que recuperar el vector
<sec-cap06_soporte>

Conviene separar dos garantías que suelen confundirse, porque su diferencia motiva el resto del capítulo. El teorema anterior acota el error de *estimación* bajo la _restricted eigenvalue condition_, una condición relativamente débil. Recuperar el *soporte* $S_0 = {j : beta_(0,j) != 0}$, es decir, que $hat(S) = S_0$ con probabilidad tendiente a uno, requiere una condición estrictamente más fuerte sobre la correlación entre variables dentro y fuera del soporte.

#assumption(name: [Condición de irrepresentabilidad])[
  Sea $X_(S_0)$ la submatriz de columnas activas y $X_(S_0^c)$ la de las inactivas. Existe $eta in (0, 1]$ tal que
  $
  norm(X_(S_0^c)^T X_(S_0) (X_(S_0)^T X_(S_0))^(-1) "sign"(beta_(0, S_0)))_infinity <= 1 - eta.
  $
] <asu-irrepresentable>

#theorem(name: [Consistencia de selección del LASSO])[
  Bajo la condición de irrepresentabilidad, condiciones de regularidad sobre el ruido y un $lambda$ apropiado, el LASSO es _sign-consistent_: $P("sign"(hat(beta)_("LASSO")) = "sign"(beta_0)) -> 1$. Recíprocamente, si la norma anterior es mayor que 1 en el límite, el LASSO no recupera los signos verdaderos con probabilidad tendiente a uno, para ningún valor de $lambda$.
] <thm-irrepresentable>

Este resultado, de #cite(<zhao2006model>, form: "prose"), es una mala noticia disfrazada de teorema. La condición de irrepresentabilidad no es verificable en la práctica (depende de $S_0$, lo desconocido) y falla justamente en el escenario que más importa para la inferencia causal: cuando una variable irrelevante está muy correlacionada con las confusoras verdaderas. La parte recíproca es la clave: no se trata de que el LASSO necesite más datos, sino de que hay diseños donde ninguna elección de $lambda$ recupera el soporte. La lección operativa es que *el conjunto seleccionado por LASSO nunca debe leerse como "las variables que verdaderamente importan"*, y que ningún procedimiento causal debería depender de que la selección sea exactamente correcta. La doble selección del @cap-pds se diseña bajo esa premisa: no necesita $hat(S) = S_0$, solo que $hat(S)$ contenga las confusoras relevantes con alta probabilidad.

=== El problema de Leeb y Pötscher
<sec-cap06_leeb>

#cite(<leeb2006can>, form: "prose") demostraron un resultado perturbador. Si se selecciona un subconjunto $hat(S)$ de variables y luego se corre OLS sobre $hat(S)$ y se reporta el intervalo habitual al 95 %, la cobertura real puede ser muy inferior.

#theorem(name: [Leeb y Pötscher: no uniformidad (esquema)])[
  Sea un procedimiento de selección de modelo consistente. La distribución del estimador post-selección no puede estimarse de manera uniformemente consistente respecto del parámetro, y el ínfimo, sobre el espacio de parámetros, de la cobertura del intervalo ingenuo (el que ignora la selección) puede quedar muy por debajo del nivel nominal, incluso cerca de cero, a lo largo de secuencias de coeficientes de orden $n^(-1\/2)$.
] <thm-leeb-potscher>

#intuicion[
  Imagine que el verdadero $beta_j$ es positivo pero muy pequeño. LASSO lo selecciona solo si la estimación preliminar de $beta_j$ es suficientemente grande. Condicionado a haber sido seleccionado, $hat(beta)_j$ tiende a ser mayor que $beta_j$, un sesgo de selección análogo al sesgo de publicación. El intervalo post-selección, que no condiciona en ese hecho, queda centrado en un valor sesgado. Y lo preocupante son los coeficientes "localmente pequeños", del orden de $n^(-1\/2)$: no son tan grandes como para ser seleccionados con certeza ni tan pequeños como para no importar.
]

=== Por qué la doble selección corrige el problema
<sec-cap06_omision>

La razón de fondo del problema, y de su solución, se ve en una descomposición del sesgo por omitir variables. Sea el modelo $Y = theta D + sum_j gamma_j X_j + epsilon$ y sea $S$ el conjunto de controles que se incluyen en el OLS final.

#proposition(name: [Sesgo por omisión de controles])[
  Si el OLS final de $Y$ sobre $D$ y $X_S$ deja fuera el conjunto $S^c$, el límite en probabilidad del coeficiente de $D$ es
  $
  theta + sum_(j in S^c) gamma_j delta_j, quad delta_j = ("Cov"(tilde(D)_S, X_j)) / ("Var"(tilde(D)_S)),
  $
  donde $tilde(D)_S$ es el residuo de proyectar $D$ sobre $X_S$ (y la constante), y $delta_j$ es el coeficiente de $tilde(D)_S$ en la regresión de $X_j$. En consecuencia, $|"sesgo"| <= sum_(j in S^c) |gamma_j| |delta_j|$.
] <prop-omision>

#proof(kind: "sketch")[
  Por el teorema de Frisch-Waugh-Lovell, el coeficiente de $D$ es $"Cov"(tilde(D)_S, Y) \/ "Var"(tilde(D)_S)$. Se sustituye $Y = theta D + sum_(j in S) gamma_j X_j + sum_(j in S^c) gamma_j X_j + epsilon$; el residuo $tilde(D)_S$ es ortogonal a $X_S$ y a $epsilon$, y $"Cov"(tilde(D)_S, D) = "Var"(tilde(D)_S)$.
]

El sesgo es una suma de *productos*: un coeficiente de la ecuación de $Y$ ($gamma_j$) por una medida de cuánto se asocia $X_j$ con $D$ ($delta_j$). La selección ingenua, que mira solo la ecuación de $Y$, omite las variables con $gamma_j$ pequeño, sin importar cuán grande sea $delta_j$. Y un $gamma_j$ pequeño con un $delta_j$ grande es justamente lo que no se puede dejar fuera. La doble selección añade la ecuación de $D$: una variable solo queda fuera si *ambos* coeficientes son pequeños, y entonces su producto es de segundo orden. Es la misma estructura de producto que sostiene la ortogonalidad del @cap-ortogonalidad.

=== Dos familias de respuestas
<sec-cap06_respuestas>

La literatura posterior a Leeb y Pötscher desarrolló dos estrategias frente al problema.

La primera es la *inferencia selectiva condicional*: aceptar que la selección ocurrió y hacer inferencia sobre la distribución de $hat(beta)_j$ condicionada al evento de selección. #cite(<lee2016exact>, form: "prose") muestran que, para el LASSO con $lambda$ fijo, ese evento es un politopo en el espacio de $Y$, lo que permite construir intervalos con cobertura condicional exacta mediante una normal truncada. Es elegante, pero condiciona en un evento aleatorio y puede producir intervalos muy anchos.

La segunda es la *desregularización* (_de-biasing_): corregir de forma explícita el sesgo que la penalización introduce en la componente de interés y construir un estimador asintóticamente normal y centrado. #cite(<zhang2014confidence>, form: "prose") y #cite(<vandegeer2014asymptotically>, form: "prose") desarrollan esta vía, que da inferencia no condicional y uniformemente válida sobre el parámetro de interés.

La segunda familia es la relevante para este libro, por una razón conceptual y no solo técnica: en un problema causal no interesa la inferencia sobre "las variables que el LASSO seleccionó", sino sobre un parámetro estructural fijado antes de mirar los datos, el efecto de $D$ sobre $Y$. La doble selección (@cap-pds) y Double Machine Learning (@cap-dml) comparten la lógica de la ortogonalidad: construyen un momento insensible al error de selección o de estimación de los _nuisance_. Ninguno intenta que el LASSO seleccione bien; ambos construyen procedimientos cuya validez no depende de que lo haga.

#cite(<belloni2014inference>, form: "prose") propusieron la solución para el caso causal: seleccionar dos veces, una para predecir $Y$ con $X$ y otra para predecir $D$ con $X$, y correr OLS de $Y$ sobre $D$ y la unión de las variables seleccionadas.

#theorem(name: [Doble selección con LASSO (esquema)])[
  Bajo esparsidad aproximada, una penalización apropiada, regularidad estándar y un número de controles relevantes $s$ con $s^2 log^2 (max(p, n)) \/ n -> 0$, el estimador de doble selección es asintóticamente normal con la misma varianza que un estimador que conociera el conjunto verdadero de controles (el estimador oráculo), y la inferencia con errores estándar robustos es válida. El enunciado completo, con la penalización y las condiciones, está en el @cap-pds.
] <thm-pds>

== Algoritmo
<sec-cap06_algoritmo>

El procedimiento Post-LASSO ingenuo es la práctica común que induce sesgo post-selección, y sirve de referencia para contrastar con la doble selección del @cap-pds.

#algorithm("Post-LASSO OLS (selección ingenua)")[
  #kwin[Entrada][Datos ${(Y_i, D_i, X_i)}_(i=1)^n$, penalización $lambda >= 0$.]
  #kwout[Salida][Estimador $hat(theta)$ y error estándar robusto $hat(sigma)$.]
  Ejecutar LASSO de $Y$ sobre $(D, X)$ con penalización $lambda$. \
  Identificar $hat(S) = {j : hat(beta)_j != 0}$ entre las columnas de $X$ (la columna de $D$ se fuerza a permanecer). \
  Estimar por OLS $Y$ sobre una constante, $D$ y $X_(hat(S))$. \
  Calcular errores estándar robustos a heterocedasticidad (HC1). \
  #return-stmt[$hat(theta)_"OLS", hat(sigma)_"HC1"$.]
] <alg-post-lasso-ols>

#intuicion[
  *Caja de profundización: partialling-out y doble LASSO*

  *Objetivo.* Entender dos herramientas para limpiar el efecto de las covariables antes de estimar el efecto causal.

  *Partialling-out.* Para estimar el efecto de $D$ sobre $Y$ se "limpian" ambas variables de la influencia de $X$:
  $
  tilde(Y) = Y - E[Y | X], quad tilde(D) = D - E[D | X].
  $
  Luego se estima $theta$ con la regresión de $tilde(Y)$ sobre $tilde(D)$ sin intercepto (teorema de Frisch-Waugh-Lovell).

  *Doble LASSO.* En alta dimensión hay que seleccionar las variables relevantes:
  + LASSO de $Y$ sobre $X$ da $S_Y$, las variables que predicen $Y$.
  + LASSO de $D$ sobre $X$ da $S_D$, las que predicen $D$.
  + Unión: $S = S_Y union S_D$.
  + OLS de $Y$ sobre $D$ y los controles de $S$.

  *¿Por qué funciona?* Una confusora afecta a $Y$ y a $D$. Si se selecciona lo que afecta a cada uno, se capturan todas las confusoras relevantes, como muestra la proposición de la @sec-cap06_omision. Esa es la base de la doble selección del @cap-pds.
]

== Casos canónicos y validación
<sec-cap06_caso>

Los dos casos usan un proceso generador con $theta_0 = 1$, $n = 500$, $p = 100$ y cinco confusoras $X_0, dots, X_4$ (el resto es ruido). $D = bold(1){X beta_D + epsilon_D > 0}$ e $Y = D + X gamma + epsilon$, con ruidos normales estándar. Las cifras se calculan con 300 repeticiones, LASSO por validación cruzada de cinco pliegues y errores estándar HC1.#capa-impl[ El script es #code[herramientas/verificaciones/verif_cap06.py].] Las columnas son el sesgo medio, la desviación típica y la cobertura del intervalo al 95 %.

#caso-canonico("Confusoras fuertes: la selección ingenua casi no sesga")[
  Cada confusora pesa 0,7 en $Y$ y 0,5 en $D$. Con $n = 500$ el LASSO las encuentra siempre (las cinco entran en las 300 repeticiones), y el procedimiento ingenuo funciona.

  #table(
    columns: (2.2fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Procedimiento*], [*Sesgo*], [*Desv. típica*], [*Cobertura*]),
    table.hline(stroke: 0.3pt),
    [Post-LASSO ingenuo (validación cruzada)], [−0,007], [0,119], [0,937],
    [Doble selección (validación cruzada)], [−0,025], [0,116], [0,943],
    [Doble selección con $lambda$ teórico], [0,002], [0,112], [0,953],
    [Oráculo (OLS con las cinco confusoras)], [0,002], [0,112], [0,953],
    table.hline(stroke: 0.6pt),
  )

  Ningún procedimiento se equivoca de manera relevante. Es un caso útil precisamente porque desmiente la idea de que seleccionar siempre invalida la inferencia: el problema aparece cuando la señal de alguna confusora es débil.
]

#caso-canonico("Confusoras débiles en Y y fuertes en D: el caso de Leeb y Pötscher")[
  Cada confusora pesa 0,1 en $Y$ (unas 2,2 veces $n^(-1\/2)$, el rango de los coeficientes "localmente pequeños") y 1,0 en $D$. La penalización teórica sigue la fórmula de #cite(<belloni2014inference>, form: "prose") del @sec-cap16_lambda con $c = 1,1$.

  #table(
    columns: (2.2fr, 1fr, 1fr, 1fr, 1.3fr),
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Procedimiento*], [*Sesgo*], [*Desv. típica*], [*Cobertura*], [*Confusoras incluidas (de 5)*]),
    table.hline(stroke: 0.3pt),
    [Post-LASSO ingenuo (validación cruzada)], [0,012], [0,144], [0,883], [4,16],
    [Doble selección (validación cruzada)], [−0,035], [0,130], [0,953], [5,00],
    [Post-LASSO ingenuo con $lambda$ teórico], [0,206], [0,135], [0,453], [1,49],
    [Doble selección con $lambda$ teórico], [−0,003], [0,130], [0,953], [5,00],
    [Oráculo], [−0,003], [0,130], [0,953], [5,00],
    table.hline(stroke: 0.6pt),
  )

  Con $lambda$ de validación cruzada, que selecciona de forma generosa, el daño es moderado (cobertura de 0,88, con una confusora perdida en promedio). Con la penalización teórica, más estricta, el procedimiento ingenuo pierde casi todas las confusoras (incluye 1,49 de 5), el sesgo es de 0,21 y el intervalo del 95 % cubre el valor verdadero solo el 45 % de las veces. La doble selección conserva las cinco confusoras gracias a la ecuación de $D$ y se comporta como el oráculo.
]

Los dos casos juntos son la lección del capítulo: la inferencia ingenua no *siempre* falla, pero no hay forma de saber desde los datos si se está en el primer caso o en el segundo, porque lo que distingue ambos es el tamaño de coeficientes desconocidos. Un procedimiento cuya validez no depende de esa distinción es lo que se necesita.

#capa-impl[
== Implementación en Python
<sec-cap06_implementacion>

El listado reproduce el segundo caso canónico con #code[numpy] y #code[scikit-learn], sin depender de #code[statsmodels]: los errores estándar HC1 se calculan a mano.

#figure(
  kind: raw,
  caption: [Sesgo post-selección: Post-LASSO ingenuo, doble selección y oráculo con efecto conocido.],
  ```python
import numpy as np
from scipy.stats import norm
from sklearn.linear_model import Lasso, LassoCV


def generar(n=500, p=100, gamma=0.1, beta_d=1.0, k=5, seed=0):
    """theta = 1; las k primeras variables son confusoras; el resto es ruido."""
    rng = np.random.default_rng(seed)
    X = rng.standard_normal((n, p))
    bd = np.zeros(p); bd[:k] = beta_d
    gy = np.zeros(p); gy[:k] = gamma
    D = (X @ bd + rng.standard_normal(n) > 0).astype(float)
    Y = 1.0 * D + X @ gy + rng.standard_normal(n)
    return Y, D, X


def ols_hc1(Y, D, Xs):
    """Coeficiente de D y su error estándar HC1 en OLS de Y sobre constante, D y Xs."""
    n = len(Y)
    Z = np.column_stack([np.ones(n), D, Xs])
    b = np.linalg.lstsq(Z, Y, rcond=None)[0]
    e = Y - Z @ b
    ZtZi = np.linalg.inv(Z.T @ Z)
    meat = (Z * e[:, None]).T @ (Z * e[:, None])
    V = ZtZi @ meat @ ZtZi * n / (n - Z.shape[1])
    return b[1], np.sqrt(V[1, 1])


def alfa_teorico(y, n, p, c=1.1):
    """Penalización tipo Belloni-Chernozhukov-Hansen en la escala de sklearn."""
    gamma = 0.1 / np.log(max(n, p))
    return c * y.std() * norm.ppf(1 - gamma / (2 * p)) / np.sqrt(n)


def seleccionar(modelo, X, y):
    return np.abs(modelo.fit(X, y).coef_) > 1e-8


def post_lasso_ingenuo(Y, D, X, alfa=None):
    """LASSO de Y sobre [D, X]; OLS final con D forzada y las columnas seleccionadas."""
    n, p = X.shape
    modelo = LassoCV(cv=5) if alfa is None else Lasso(alpha=alfa, max_iter=5000)
    sel = seleccionar(modelo, np.column_stack([D, X]), Y)[1:]
    return ols_hc1(Y, D, X[:, sel])


def doble_seleccion(Y, D, X, alfa_y=None, alfa_d=None):
    """Unión de lo que predice Y y lo que predice D."""
    m_y = LassoCV(cv=5) if alfa_y is None else Lasso(alpha=alfa_y, max_iter=5000)
    m_d = LassoCV(cv=5) if alfa_d is None else Lasso(alpha=alfa_d, max_iter=5000)
    sel = seleccionar(m_y, X, Y) | seleccionar(m_d, X, D)
    return ols_hc1(Y, D, X[:, sel])


def monte_carlo(reps=300, **dgp):
    filas = {"ingenuo (CV)": [], "ingenuo (teórico)": [], "doble selección (teórico)": [], "oráculo": []}
    for r in range(reps):
        Y, D, X = generar(seed=r, **dgp)
        n, p = X.shape
        a = alfa_teorico(Y, n, p)
        filas["ingenuo (CV)"].append(post_lasso_ingenuo(Y, D, X))
        filas["ingenuo (teórico)"].append(post_lasso_ingenuo(Y, D, X, alfa=alfa_teorico(Y, n, p + 1)))
        filas["doble selección (teórico)"].append(doble_seleccion(Y, D, X, alfa_teorico(Y, n, p), alfa_teorico(D, n, p)))
        filas["oráculo"].append(ols_hc1(Y, D, X[:, :5]))
    for nombre, v in filas.items():
        b, se = np.array(v).T
        print(f"{nombre:28s} sesgo={b.mean() - 1:+.3f}  sd={b.std(ddof=1):.3f}  cobertura={np.mean(np.abs(b - 1) <= 1.96 * se):.3f}")


if __name__ == "__main__":
    # Prueba de coherencia: el oráculo debe quedar cerca de 1 en una sola réplica.
    Y, D, X = generar(seed=0)
    assert abs(ols_hc1(Y, D, X[:, :5])[0] - 1.0) < 0.5
    monte_carlo()
```
) <lst-post-selection-bias>

La cobertura se calcula con el error estándar estimado en cada réplica, no con la dispersión de los $hat(theta)$ entre réplicas. Con $gamma = 0.7$ y $beta_D = 0.5$ el mismo código reproduce el primer caso canónico.

#figure(
  kind: raw,
  caption: [Partialling-out manual con LASSO.],
  ```python
import numpy as np
from sklearn.linear_model import LassoCV


def partialling_out_theta(Y, D, X):
    """Estima theta limpiando Y y D de la influencia de X con LASSO (sin cross-fitting)."""
    y_res = Y - LassoCV(cv=5).fit(X, Y).predict(X)
    d_res = D - LassoCV(cv=5).fit(X, D).predict(X)
    return np.mean(d_res * y_res) / np.mean(d_res * d_res)
```
) <lst-partialling-out>

Este partialling-out ajusta y evalúa en la misma muestra. Es una ilustración del mecanismo: la versión con _cross-fitting_ es la del @cap-ortogonalidad.
]

== Riesgos, límites y sensibilidad
<sec-cap06_riesgos>

#riesgos[
  #set text(size: 9pt)
  #figure(
    caption: [Riesgos de la selección de variables en problemas causales.],
    table(
      columns: (1fr, 1fr, 1fr, 1.2fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Inferir después de seleccionar con una sola ecuación], [Confusoras débiles en $Y$ quedan fuera; cobertura inválida (45 % en el segundo caso canónico)], [Monte Carlo bajo un proceso plausible; comparar la selección con la de la ecuación de $D$], [Doble selección o ortogonalización (@cap-pds, @cap-dml)],
      table.hline(stroke: 0.4pt),
      [Leer el conjunto seleccionado como "las variables importantes"], [Interpretación causal de la selección], [Estabilidad de la selección con submuestreo], [Reportar el efecto de $D$, no la lista de variables],
      table.hline(stroke: 0.4pt),
      [Interpretar un coeficiente de LASSO como causal], [Sesgo de contracción], [Comparar con Post-LASSO y con OLS completo si $p < n$], [Post-LASSO o Double Machine Learning],
      table.hline(stroke: 0.4pt),
      [$lambda$ inestable], [Selección frágil], [Resultados para varios valores de $lambda$], [Reportar la penalización de validación cruzada y la teórica],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cap06>
]

*Límites del enfoque.* La doble selección asume esparsidad aproximada: pocas variables son realmente confusoras. Si la confusión es densa (muchas variables pequeñas que importan colectivamente), la selección con penalización teórica puede fallar y se prefiere Double Machine Learning (@cap-dml), que no exige esparsidad estricta; el @sec-cap16_densa lo muestra con cifras. Además, la doble selección es un método de regresión lineal: para heterogeneidad estructurada en $X$ se usan bosques causales (@cap-causal-forests) o meta-learners (@cap-meta-learners).

#checklist[
  - *Verificar la cobertura empírica:* ejecutar un Monte Carlo bajo el proceso generador supuesto y confirmar que los intervalos post-selección alcanzan la cobertura nominal.
  - *Sensibilidad a $lambda$:* reportar resultados para varios valores de $lambda$ (por ejemplo, el de validación cruzada y el teórico) y verificar que la selección y el coeficiente de $D$ no cambian de manera drástica.
  - *Estabilidad de la selección:* usar _bootstrap_ o submuestreo para ver qué fracción de las veces entra cada variable.
  - *Comparar con OLS completo:* si $p < n$, contrastar el Post-LASSO con OLS sin selección para medir el costo de la regularización.
  - *Reportar ambos:* presentar siempre el Post-LASSO ingenuo junto con la doble selección, para transparentar el efecto de la ecuación de $D$.
]

== Ejercicios y notas bibliográficas
<sec-cap06_ejercicios>

=== Ejercicios teóricos

+ Demuestre que Ridge no hace selección de variables: muestre que $hat(beta)_("Ridge")$ tiene todas sus componentes distintas de cero en general. ¿Por qué es preferible a LASSO cuando hay grupos de variables muy correlacionadas?

+ Con dos regresores $X_1, X_2$ de varianza 1 y correlación $rho$, y $beta_0 = (1, 0)$, calcule el lado izquierdo de la condición de irrepresentabilidad y encuentre para qué valores de $rho$ se cumple.

+ Complete la demostración de la proposición de la @sec-cap06_omision y calcule, para el segundo caso canónico, el sesgo de omitir las cinco confusoras. Compare con 0,206, el sesgo observado del procedimiento ingenuo con $lambda$ teórico, que incluye 1,49 de ellas en promedio.

+ Explique con la proposición de la @sec-cap06_omision por qué una confusora con $gamma_j$ pequeño y $delta_j$ grande es omitida por la selección ingenua pero incluida por la doble selección, y por qué una con ambos pequeños puede omitirse sin consecuencias de primer orden.

#capa-impl[
=== Ejercicios computacionales

+ Replique el #ref(<lst-post-selection-bias>, supplement: [listado]) variando $p in {20, 50, 100, 200}$. ¿Cómo cambian el sesgo y la cobertura con la dimensión?

+ Con el mismo proceso, barra $gamma$ en ${0.05, 0.1, 0.3, 0.7}$ y trace la cobertura del procedimiento ingenuo con $lambda$ teórico. ¿A partir de qué $gamma$ deja de ser un problema?

+ Implemente la función #code[partialling_out_theta] del #ref(<lst-partialling-out>, supplement: [listado]) y verifique que recupera $theta$ en un proceso lineal. ¿Qué pasa si $X$ contiene variables de ruido puro?

+ Sobre el conjunto #code[nhefs], compare (a) OLS con cinco controles elegidos a mano, (b) LASSO ingenuo y (c) doble selección. Compare los tres estimadores y sus errores estándar.
]

=== Notas bibliográficas

#cite(<tibshirani1996lasso>, form: "prose") y #cite(<hoerl1970ridge>, form: "prose") son las referencias originales. #cite(<hastie2015statistical>, form: "prose") ofrece un tratamiento moderno de la regularización en alta dimensión. #cite(<bickel2009simultaneous>, form: "prose") establece la tasa $ell_2$ bajo _restricted eigenvalue_ y #cite(<zhao2006model>, form: "prose") la condición de irrepresentabilidad y su recíproca para la consistencia de selección; leerlos en secuencia es la forma más económica de internalizar por qué "el LASSO funciona" significa cosas muy distintas según lo que se le pida. #cite(<leeb2006can>, form: "prose") y #cite(<potscher2009confidence>, form: "prose") son las referencias obligadas sobre el problema de la inferencia post-selección; #cite(<lee2016exact>, form: "prose") desarrolla la vía de la inferencia selectiva condicional, y #cite(<zhang2014confidence>, form: "prose") junto con #cite(<vandegeer2014asymptotically>, form: "prose") la de _de-biasing_, que es la que este libro sigue. #cite(<belloni2014inference>, form: "prose") introduce la doble selección. Para una revisión pedagógica, véase @chernozhukov2018applied.
