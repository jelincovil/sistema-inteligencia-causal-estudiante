// Capítulo 5: Predicción y causalidad: por qué el ML no es causal por defecto
// Edición en capas: la teoría (L0), el procedimiento en pseudocódigo (L1) y los casos canónicos con cifras
// verificadas (L2) son lo que dura; el listado (L3) va dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Predicción y causalidad: por qué el ML no es causal por defecto]
<cap-prediccion-causalidad>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Distinguir una respuesta predictiva de una respuesta causal],
    [*Estimando:*], [$"ATE"$, $"ATT"$, $"CATE"(x)$, valor de una política],
    [*Identificación:*], [No confusión condicional, soporte común, SUTVA],
    [*Método:*], [Contraste predictivo frente a contraste causal, con verdad conocida],
    [*Nuisance:*], [$mu_(d)(x)$, $e(x)$],
    [*Garantía:*], [Identificación bajo supuestos; sesgo de primer orden del estimador por sustitución],
    ..if not es-principios {([*Librerías:*], [scikit-learn, numpy])},
    [*Validación:*], [Simulación con efecto conocido, cobertura de intervalos, placebos],
  )
]

#notatecnica[
Este capítulo retoma la distinción entre asociación y causalidad presentada de forma intuitiva en el @cap-causalidad-elemental y formalizada con modelos estructurales y la Jerarquía Causal de Pearl en el @cap-scm-pch. Aquí el foco pasa de "¿qué pregunta estoy haciendo?" a "¿cómo la respondo con datos de alta dimensión?", la pregunta que estructura toda la Parte II.
]

== Problema causal, estimando e identificación
<sec-cap05_problema>

Un economista del Ministerio de Desarrollo Social debe decidir a qué hogares beneficiar con un programa de transferencias condicionadas. El presupuesto solo alcanza para el 30 % de la población elegible. Dispone de cien variables socioeconómicas por hogar (ingresos, composición familiar, escolaridad, empleo, vivienda, salud) y de un registro histórico de hogares que recibieron o no el programa, con el ingreso posterior observado. La pregunta relevante es _causal_: ¿qué hogares verían el mayor aumento de ingresos si recibieran el programa? La pregunta _predictiva_, qué hogares tendrán mayores ingresos en el futuro con independencia del programa, es distinta y, para focalizar, a menudo equivocada.

La distinción importa porque los algoritmos corrientes de _machine learning_ (regresión ridge, bosques aleatorios, _gradient boosting_, redes neuronales) se optimizan para predecir, no para estimar efectos. Un bosque que predice con alta precisión el ingreso futuro de un hogar puede dar una estimación sesgada del efecto del programa, por dos razones estructurales. Primero, un modelo predictivo no distingue la variación de $Y$ asociada a $D$ porque $D$ la causa de la que se asocia porque $D$ comparte causas con $Y$: esa distinción la aporta el supuesto de identificación, no el algoritmo. Segundo, la regularización que mejora la predicción fuera de muestra contrae justamente el coeficiente que interesa, un fenómeno que se llama sesgo inducido por la regularización.

El capítulo sostiene que la inferencia causal descansa en supuestos de identificación económicos, no estadísticos, y que el aporte del ML consiste en flexibilizar la estimación de los componentes auxiliares (_nuisance_) sin vulnerar esos supuestos. Fija la notación de resultados potenciales en alta dimensión, define los estimandos centrales del libro (ATE, ATT, CATE y valor de una política) y muestra con tres simulaciones de efecto conocido tres maneras distintas de equivocarse: un predictor excelente que estima mal el efecto, un sesgo que no desaparece con más datos y un control que crea el sesgo que pretendía evitar.

Conviene evitar también la conclusión simétrica y equivocada de que la predicción sea siempre el instrumento inadecuado. #cite(<kleinberg2015prediction>, form: "prose") identifican una clase entera de problemas de política, los _prediction policy problems_, en los que la decisión depende de un pronóstico y no de un efecto causal. Su ejemplo es la prótesis de cadera o rodilla: el beneficio de operar crece con los años de vida que le quedan al paciente, de modo que lo que falta saber para decidir es cuánto vivirá, una pregunta predictiva. El criterio para distinguir ambos regímenes es preciso: *si la decisión cambia la variable sobre la que se razona, la pregunta es causal; si solo depende de un estado del mundo que ocurriría de todos modos, la pregunta es predictiva*. Focalizar un subsidio por "quién se beneficiaría más" es causal, porque asignarlo cambia el ingreso. Focalizarlo por "quién es más pobre" pide predecir la pobreza basal, que se realiza con o sin el programa, y equivale a focalizar por beneficio solo si se supone que el efecto crece con la pobreza o si el objetivo es de equidad y no de eficiencia. Muchos sistemas de _targeting_ en producción mezclan ambos criterios sin declararlo, y la tabla #ref(<tab-pred-causal>, supplement: none) existe para forzar esa declaración.

#figure(
  caption: [Régimen predictivo y régimen causal.],
  table(
    columns: (1.2fr, 1.5fr, 1.8fr),
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header(
      [*Dimensión*], [*Predicción*], [*Causalidad*]
    ),
    table.hline(stroke: 0.4pt),
    [Objetivo], [Minimizar el error fuera de muestra], [Estimar $tau(x)$ con intervalo válido],
    [Estimando], [$E[Y | X]$], [$E[Y(1) - Y(0) | X]$],
    [Métrica de éxito], [RMSE, exactitud, AUC], [Sesgo, cobertura, RMSE de $hat(tau)$],
    [Datos requeridos], [Solo $Y, X$ observados], [Requiere $Y(0), Y(1)$, que no se observan a la vez],
    [Supuestos clave], [Datos i.i.d., estacionariedad], [No confusión, soporte común, SUTVA],
    [Regularización], [Bienvenida (mejora la generalización)], [Peligrosa si recae sobre el efecto (introduce sesgo en $tau$)],
    [Validación], [Validación cruzada estándar], [Placebos, curvas Qini, _benchmarks_ y simulación con verdad conocida],
    table.hline(stroke: 0.8pt),
  )
) <tab-pred-causal>

== Teoría, supuestos y garantías
<sec-cap05_teoria>

=== Supuestos
<sec-cap05_supuestos>

Se adopta el marco de @neyman1923 y @rubin1974. Cada unidad $i$ tiene dos resultados potenciales: $Y_(i)(1)$ si recibe el tratamiento e $Y_(i)(0)$ si no lo recibe. La asignación observada es $D_i in {0, 1}$ y el resultado observado cumple la restricción de consistencia $Y_i = D_i Y_(i)(1) + (1 - D_i) Y_(i)(0)$. Las covariables pretratamiento $X_i in RR^p$ forman un vector cuya dimensión $p$ puede ser grande (decenas o cientos) e incluso crecer con $n$. Tres supuestos permiten identificar $tau(x)$ con datos observacionales.

#assumption(name: [No confusión condicional])[
  $Y(0), Y(1) perp perp D | X$.
] <asu-unconfoundedness>

#assumption(name: [Soporte común])[
  Existe $underline(e) > 0$ tal que $underline(e) < P(D = 1 | X = x) < 1 - underline(e)$ para todo $x$ en el soporte de $X$.
] <asu-overlap>

#assumption(name: [SUTVA: no interferencia y versión única])[
  El resultado potencial de la unidad $i$ depende solo de su propio tratamiento, $Y_(i)(d_1, dots, d_n) = Y_(i)(d_i)$, y el tratamiento no tiene versiones ocultas que cambien el resultado.
] <asu-sutva>

Estos supuestos son _económicos_: su validez depende del contexto sustantivo y no de la cantidad de datos. La no confusión exige haber observado todas las variables que afectan a la vez la asignación y el resultado. El soporte común exige que haya unidades tratadas y no tratadas en cada región del espacio de covariables. SUTVA prohíbe efectos cruzados entre unidades y versiones distintas del tratamiento bajo un mismo nombre. Solo el soporte común puede diagnosticarse con los datos (mirando la distribución del propensity score). La no confusión no se contrasta con datos observados, porque involucra $Y(0)$ e $Y(1)$ de las mismas unidades, que nunca se observan juntas; SUTVA depende del diseño del programa. La responsabilidad de justificarlos recae en el economista y no en el algoritmo.

=== Estimandos e identificación
<sec-cap05_estimador>

#definition(name: [Estimandos causales centrales])[
  Bajo SUTVA, los estimandos de interés son
  $
  "ATE": & quad theta = E[Y(1) - Y(0)], \
  "ATT": & quad theta_("ATT") = E[Y(1) - Y(0) | D = 1], \
  "CATE": & quad tau(x) = E[Y(1) - Y(0) | X = x], \
  "Valor de una política": & quad V(pi) = E[Y(pi(X))],
  $
  donde $pi: RR^p -> {0, 1}$ es una regla de asignación del tratamiento.
]

El libro se centra en $tau(x)$ y $V(pi)$, porque son los estimandos que el ML permite abordar de una manera genuinamente nueva: la heterogeneidad del efecto y la optimización de políticas que se apoyan en ella (@cap-meta-learners y @cap-policy-learning).

#proposition(name: [Identificación del CATE])[
  Bajo consistencia y los supuestos de no confusión condicional y soporte común, para todo $x$ del soporte,
  $
  mu_(d)(x) = E[Y | X = x, D = d] = E[Y(d) | X = x], quad tau(x) = mu_1(x) - mu_0(x),
  $
  y por tanto $theta = E[tau(X)]$, $theta_("ATT") = E[tau(X) | D = 1]$ y $V(pi) = E[mu_0(X) + pi(X) tau(X)]$.
] <prop-identificacion>

#proof[
  Por consistencia, $E[Y | X = x, D = d] = E[Y(d) | X = x, D = d]$. Por no confusión condicional, $E[Y(d) | X = x, D = d] = E[Y(d) | X = x]$. El soporte común garantiza que el evento $D = d$ tiene probabilidad positiva dado $X = x$, de modo que el condicionamiento está bien definido. Los demás estimandos siguen de la ley de las esperanzas iteradas.
]

La proposición contiene una lección que el resto del capítulo precisa. Bajo no confusión condicional, el contraste predictivo $E[Y | X, D = 1] - E[Y | X, D = 0]$ *coincide* con el efecto causal. Un modelo predictivo no está equivocado por naturaleza al leerse en clave causal. Falla por dos razones concretas y separables: porque el supuesto de identificación no se cumple (hay confusión no observada, el caso 2 más abajo), o porque la función $mu_d$ se estima mal justamente en la dirección que importa (el caso 1). Por eso la respuesta correcta a "¿puedo leer este modelo como causal?" nunca es un sí o un no genérico, sino una revisión de los dos supuestos de arriba y de la calidad de la estimación.

=== Sesgo de primer orden del estimador por sustitución
<sec-cap05_garantias>

Si se estiman $hat(mu)_0$ y $hat(mu)_1$ con un método de ML y se calcula $hat(tau)(x) = hat(mu)_1(x) - hat(mu)_0(x)$, se obtiene el _T-learner_ del @cap-meta-learners, y su promedio $hat(theta) = (1 \/ n) sum_i hat(tau)(X_i)$ es el estimador por sustitución del ATE. La pregunta es bajo qué condiciones $hat(theta)$ admite inferencia en alta dimensión. La respuesta es negativa, y se explica con una descomposición exacta.

#proposition(name: [Sesgo de primer orden del estimador por sustitución])[
  Sean $hat(mu)_0, hat(mu)_1$ estimados en una muestra independiente de la que se usa para promediar, y sea $hat(tau) = hat(mu)_1 - hat(mu)_0$. Entonces
  $
  hat(theta) - theta = underbrace(b_n, "sesgo") + underbrace((P_n - P)(hat(tau)), O_p (n^(-1\/2))), quad b_n = E[hat(tau)(X) - tau(X) | hat(mu)] ,
  $
  y $|b_n| <= norm(hat(mu)_1 - mu_1)_(L^2) + norm(hat(mu)_0 - mu_0)_(L^2)$. El sesgo $b_n$ es de primer orden en el error de los _nuisance_. Si ese error converge a una tasa $a_n$ con $sqrt(n) a_n -> infinity$, como ocurre con los estimadores flexibles en dimensión alta, entonces $sqrt(n)(hat(theta) - theta)$ no es asintóticamente normal centrada en cero.
] <prop-sesgo-sustitucion>

#proof(kind: "sketch")[
  Se suma y resta $P hat(tau)$, con $P$ la esperanza bajo la distribución verdadera y $P_n$ el promedio muestral: $hat(theta) - theta = (P_n - P) hat(tau) + P(hat(tau) - tau)$. El primer término tiene varianza $"Var"(hat(tau)(X)) \/ n$ condicional en $hat(mu)$, porque $hat(tau)$ es independiente de la muestra de promediado, y es por tanto $O_p (n^(-1\/2))$ si $hat(tau)$ está acotada en $L^2$. El segundo es $b_n$, y la desigualdad sigue de Cauchy-Schwarz y de la desigualdad triangular.
]

Dos consecuencias operacionales. Primera, $b_n$ no se puede estimar sin conocer $mu_d$, de modo que ningún error estándar calculado con los datos lo corrige: un intervalo $hat(theta) plus.minus 1.96 hat("SE")$ queda centrado en el lugar equivocado. Segunda, la regularización hace que $b_n$ sea sistemático y no solo ruido: contrae $hat(mu)_d$ hacia una función más simple, y el sesgo resultante no desaparece al aumentar $n$ a la velocidad que exigiría la inferencia. Recuperar la $sqrt(n)$-consistencia requiere cambiar el estimador de modo que el error de los _nuisance_ entre solo a segundo orden. Eso es la ortogonalización de Neyman combinada con _cross-fitting_ (@cap-ortogonalidad y @cap-dml), y es la razón de ser de la Parte II.

== Procedimiento: simulación con verdad conocida
<sec-cap05_algoritmo>

Ninguna de las dos fuentes de error anteriores se ve en los datos reales, donde el efecto verdadero se desconoce. Se ven en un experimento controlado: se genera un conjunto de datos a partir de un proceso conocido con efecto $theta_0$ fijo, se aplica el estimador y se compara con $theta_0$. Este procedimiento es la herramienta de validación más barata del libro y se usa en casi todos los capítulos.

#algorithm("Simulación con verdad conocida")[
  #kwin[Entrada][Proceso generador $G$ con efecto causal conocido $theta_0$, tamaño muestral $n$, estimador $hat(theta)(dot)$, número de repeticiones $R$.]
  #kwout[Salida][Sesgo, desviación típica, cobertura del intervalo y, si procede, $R^2$ predictivo.]
  #for-loop(`r`, 1, `R`)[
    Generar $(Y, D, X)$ de $G$ con semilla $r$ y también una muestra independiente $(Y', D', X')$. \
    Calcular $hat(theta)_r$ y su intervalo de confianza con la muestra $(Y, D, X)$. \
    Calcular el $R^2$ predictivo del modelo ajustado sobre $(Y', D', X')$.
  ]
  Sesgo $= (1 \/ R) sum_r hat(theta)_r - theta_0$; cobertura $= (1 \/ R) sum_r bold(1){theta_0 in "IC"_r}$. \
  #return-stmt[Sesgo, desviación típica de $(hat(theta)_r)$, cobertura, $R^2$ medio.]
] <alg-sim-verdad>

La salida admite una lectura en tres filas. Un sesgo cercano a cero con cobertura nominal valida el estimador *bajo ese proceso*. Un $R^2$ predictivo alto con sesgo grande muestra que la calidad predictiva no certifica el efecto. Un sesgo constante en $n$ con cobertura que se hunde al crecer $n$ señala un problema de identificación, no de estimación.

== Casos canónicos y validación
<sec-cap05_caso>

Los tres casos usan el procedimiento anterior. Las cifras están promediadas sobre las repeticiones que se indican.#capa-impl[ Salen de #code[herramientas/verificaciones/verif_cap05.py].]

#caso-canonico("Un bosque que predice bien y estima mal")[
  Diez covariables normales estándar, $D$ binaria con $P(D = 1 | X) = "sigm"(0.8 X_0 + 0.8 X_1)$ y $Y = D + 2 X_0 + X_1 + 0.5 X_2 + epsilon$, de modo que el efecto verdadero es $theta_0 = 1$ y la confusión es solo por variables observadas. Con $n = 2~000$ y 30 repeticiones:

  #table(
    columns: (3fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Estimador*], [*Media*], [*Desv. típica*], [*Sesgo*]),
    table.hline(stroke: 0.3pt),
    [Contraste de un bosque con $(D, X)$], [0,815], [0,133], [−0,185],
    [OLS con los controles], [1,003], [0,048], [0,003],
    [Residualización con bosques y _cross-fitting_], [1,020], [0,047], [0,020],
    table.hline(stroke: 0.6pt),
  )

  El bosque, entrenado para predecir $Y$ con $(D, X)$, alcanza un $R^2$ fuera de muestra de 0,84 y, sin embargo, subestima el efecto en casi un 19 %. La razón es de regularización: $D$ aporta una fracción pequeña de la varianza de $Y$ (unos 0,25 frente a los 5,25 de la señal de $X$), los árboles tienden a dedicar sus divisiones a $X_0$ y $X_1$, y la dependencia de $Y$ respecto de $D$ queda contraída. OLS acierta porque el modelo está bien especificado, y la residualización con bosques (adelanto del @cap-ortogonalidad) lo recupera sin exigir linealidad.
]

#caso-canonico("El sesgo que no se va con más datos")[
  Se añade una variable $U$ no observada que afecta a la asignación y al resultado: $D = bold(1){0.8 U + 0.5 X_0 + epsilon_D > 0}$, $Y = D + 1.5 U + X_0 + epsilon$, efecto verdadero $theta_0 = 1$. Se estima por OLS con los controles observados, con errores estándar robustos y 200 repeticiones por tamaño:

  #table(
    columns: (1fr, 1fr, 1fr, 1fr, 1.2fr),
    align: (center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*$n$*], [*Media*], [*Sesgo*], [*Desv. típica*], [*Cobertura IC 95 %*]),
    table.hline(stroke: 0.3pt),
    [500], [2,518], [1,518], [0,151], [0,00],
    [2~000], [2,524], [1,524], [0,083], [0,00],
    [8~000], [2,521], [1,521], [0,039], [0,00],
    [32~000], [2,521], [1,521], [0,020], [0,00],
    table.hline(stroke: 0.6pt),
  )

  La desviación típica se reduce a la mitad cada vez que $n$ se cuadruplica, y el sesgo no se mueve. Con más datos la estimación es más precisa y sigue igual de equivocada, y el intervalo, cada vez más estrecho, nunca contiene el valor verdadero. Un bosque con $(D, X)$ da lo mismo (sesgo de 1,60, 1,55 y 1,53 con $n = 500$, 2~000 y 8~000, sobre 10 repeticiones): ningún algoritmo recupera una variable que no está en $X$.
]

#caso-canonico("Controlar por todo lo disponible")[
  $A$ y $B$ son normales estándar independientes, $D = A + epsilon_D$, $Y = D + B + epsilon_Y$ y $C = A + B + epsilon_C$ es una variable que ambos causan (un _collider_). El efecto de $D$ sobre $Y$ es 1 y no hay confusión: $A$ y $B$ no se asocian. Con 200~000 observaciones, el coeficiente de $D$ es 0,999 sin controlar por $C$ y 0,798 al controlar por $C$, que coincide con el valor exacto $4 \/ 5$ del Ejercicio 3; con $n = 10~000$ y 200 repeticiones, la media al controlar por $C$ es 0,802 (desviación típica de 0,010). En esa muestra grande, la correlación entre $A$ y $B$ es −0,003 y, al condicionar en el 20 % superior de $C$, pasa a ser −0,293.
]

El tercer caso es el mecanismo inverso al de la confusión: allí condicionar *elimina* una asociación espuria; aquí la *crea*, y explica por qué "controlar por todo lo disponible" no es una estrategia conservadora sino una fuente activa de sesgo. #cite(<elwert2014endogenous>, form: "prose") llaman a este fenómeno sesgo de selección endógena: dos variables independientes se vuelven dependientes al condicionar en una causa común o en un descendiente de ella. El @cap-intervencion-contrafactual formaliza cuándo ocurre cada caso mediante el criterio de puerta trasera; aquí basta con dejar instalada la intuición numérica. Hay una variante más cotidiana del mismo error: usar como control una variable posterior al tratamiento. La experiencia potencial de un trabajador, definida como edad menos escolaridad menos seis, es función exacta de la escolaridad y no puede incluirse como control en una regresión del salario sobre los años de estudio.

=== Interpretación económica
<sec-cap05_interpretacion>

#intuicion[
  *Caja de profundización: tres tipos de preguntas causales*

  *Objetivo.* Distinguir las preguntas que solo observan, las que intervienen y las que imaginan escenarios alternativos.

  *Ejemplo económico.* Un gerente de banco quiere saber:
  + ¿Los clientes con más ingresos piden más crédito? (se observa)
  + ¿Qué pasa si se baja la tasa de interés? (se interviene)
  + ¿Este cliente habría pedido crédito si no se le hubiera subido la tasa? (se imagina)

  *Los tres niveles de Pearl.* En general, las cantidades
  $
  P(Y | X = x), quad P(Y | "do"(X = x)), quad P(Y_x | X = x', Y = y')
  $
  son tres objetos distintos.
  - *Nivel 1, asociación ("ver"):* $P(Y | X)$. Ejemplo: "los clientes con más ingresos piden más crédito".
  - *Nivel 2, intervención ("hacer"):* $P(Y | "do"(X))$. Ejemplo: "si se baja la tasa, ¿cuánto aumenta el crédito?"
  - *Nivel 3, contrafactual ("imaginar"):* $P(Y_x | X = x', Y = y')$. Ejemplo: "Juan no pidió crédito con la tasa alta; ¿lo habría pedido con la tasa baja?"

  *Importante.* Un modelo de ML entrenado con datos observacionales aprende el nivel 1. Para decidir una política (nivel 2) hacen falta supuestos causales adicionales, y para responsabilizar a un caso individual (nivel 3) hace falta además un modelo del mecanismo.
]

#capa-impl[
== Implementación en Python
<sec-cap05_implementacion>

Los listados reproducen los casos 1 y 3 con una versión autocontenida del procedimiento (solo #code[numpy] y #code[scikit-learn]). El caso 2 cambia el generador del caso 1 por el que describe el recuadro correspondiente y repite la estimación OLS para cada $n$.

#figure(
  kind: raw,
  caption: [Caso 1: contraste predictivo, OLS y residualización con _cross-fitting_ sobre un proceso con efecto conocido.],
  ```python
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import KFold


def generar(n, rng, p=10, theta=1.0):
    X = rng.standard_normal((n, p))
    e = 1.0 / (1.0 + np.exp(-(0.8 * X[:, 0] + 0.8 * X[:, 1])))
    D = rng.binomial(1, e)
    Y = theta * D + 2.0 * X[:, 0] + X[:, 1] + 0.5 * X[:, 2] + rng.standard_normal(n)
    return X, D, Y


def ols(D, X, Y):
    Z = np.column_stack([np.ones(len(Y)), D, X])
    return np.linalg.lstsq(Z, Y, rcond=None)[0][1]


def contraste_bosque(X, D, Y, seed):
    # Predictivo: ajusta E[Y | D, X] y deriva respecto de D. No es un estimador causal por diseño.
    rf = RandomForestRegressor(n_estimators=200, min_samples_leaf=5, random_state=seed, n_jobs=-1)
    rf.fit(np.column_stack([D, X]), Y)
    uno = np.column_stack([np.ones(len(Y)), X])
    cero = np.column_stack([np.zeros(len(Y)), X])
    return (rf.predict(uno) - rf.predict(cero)).mean(), rf


def residualizacion(X, D, Y, seed, k=5):
    # Residual sobre residual con nuisance ajustados fuera del fold (adelanto del Cap. 10).
    ry, rd = np.zeros(len(Y)), np.zeros(len(Y))
    for tr, te in KFold(k, shuffle=True, random_state=seed).split(X):
        my = RandomForestRegressor(n_estimators=100, min_samples_leaf=5, random_state=seed, n_jobs=-1).fit(X[tr], Y[tr])
        md = RandomForestRegressor(n_estimators=100, min_samples_leaf=5, random_state=seed, n_jobs=-1).fit(X[tr], D[tr])
        ry[te], rd[te] = Y[te] - my.predict(X[te]), D[te] - md.predict(X[te])
    return (rd * ry).sum() / (rd * rd).sum()


def simular(reps=30, n=2000):
    est = {"bosque": [], "ols": [], "residualizacion": []}
    for r in range(reps):
        X, D, Y = generar(n, np.random.default_rng(1000 + r))
        est["bosque"].append(contraste_bosque(X, D, Y, r)[0])
        est["ols"].append(ols(D, X, Y))
        est["residualizacion"].append(residualizacion(X, D, Y, r))
    for nombre, v in est.items():
        v = np.array(v)
        print(f"{nombre:16s} media={v.mean():.3f}  sd={v.std(ddof=1):.3f}  sesgo={v.mean() - 1.0:+.3f}")


if __name__ == "__main__":
    # Prueba de coherencia: con el efecto verdadero 1.0, OLS debe quedar cerca de 1.
    X, D, Y = generar(2000, np.random.default_rng(0))
    assert abs(ols(D, X, Y) - 1.0) < 0.25
    simular()
```
) <lst-pred-vs-causal>

#figure(
  kind: raw,
  caption: [Caso 3: asociación creada al condicionar en un _collider_ y sesgo al controlar por él.],
  ```python
import numpy as np

rng = np.random.default_rng(42)
n = 200_000
A, B = rng.standard_normal(n), rng.standard_normal(n)
C = 0.8 * A + 0.8 * B + rng.standard_normal(n)        # A -> C <- B

alto = C > np.quantile(C, 0.8)
print("Corr(A,B):", np.corrcoef(A, B)[0, 1])
print("Corr(A,B | C en el 20% superior):", np.corrcoef(A[alto], B[alto])[0, 1])

# Efecto de D sobre Y sin confusión: A causa D, B causa Y, ambos causan C2.
D = A + rng.standard_normal(n)
Y = 1.0 * D + B + rng.standard_normal(n)
C2 = A + B + rng.standard_normal(n)
sin = np.linalg.lstsq(np.column_stack([np.ones(n), D]), Y, rcond=None)[0][1]
con = np.linalg.lstsq(np.column_stack([np.ones(n), D, C2]), Y, rcond=None)[0][1]
print(f"Efecto de D (verdadero 1.0): sin C = {sin:.3f}, controlando C = {con:.3f}")
assert abs(sin - 1.0) < 0.05 and abs(con - 0.8) < 0.05   # coherencia con el valor exacto 4/5
```
) <lst-collider-simulation>

El primer listado ilustra con un efecto conocido lo que con datos reales no puede verse: el bosque tiene un $R^2$ fuera de muestra alto y estima mal el efecto. Con datos reales solo se dispone de uno de los dos lados de esa comparación.
]

== Riesgos, límites y sensibilidad
<sec-cap05_riesgos>

#riesgos[
  #set text(size: 9pt)
  #figure(
    caption: [Riesgos al confundir predicción con causalidad.],
    table(
      columns: (1fr, 1fr, 1fr, 1.5fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header(
        [*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]
      ),
      table.hline(stroke: 0.4pt),
      [Confundir predicción con causalidad],
      [Política errónea basada en un contraste predictivo],
      [Comparar el contraste $E[Y | X, D = 1] - E[Y | X, D = 0]$ con una referencia de efecto conocido],
      [Definir $Y(1), Y(0)$ y el estimando antes de estimar. La derivada de un predictor respecto de $D$ solo es causal si se cumple la identificación y $mu_d$ se estima bien en esa dirección (caso 1)],
      table.hline(stroke: 0.4pt),
      [Omitir confusores],
      [Sesgo que no se corrige con más datos (caso 2)],
      [Construir un DAG, buscar placebos y analizar la sensibilidad a un confusor no observado],
      [Justificar la no confusión con teoría económica o usar un diseño alternativo. Si un confusor no está en $X$, ningún algoritmo lo recupera],
      table.hline(stroke: 0.4pt),
      [Controlar por un _collider_ o por una variable posterior al tratamiento],
      [Se crea una asociación espuria o se bloquea parte del efecto (caso 3)],
      [Revisar el orden temporal de cada control y su lugar en el DAG],
      [Controlar solo por variables previas al tratamiento o por causas de $D$ e $Y$ que el DAG justifique],
      table.hline(stroke: 0.4pt),
      [Interpretar la importancia de variables (valores de Shapley) como causal],
      [Sobreinterpretar lo que es una descripción del predictor],
      [Preguntarse qué intervención justificaría la lectura],
      [Reportar la importancia como descriptiva y estimar el efecto de intervenir con el estimando causal],
      table.hline(stroke: 0.4pt),
      [Reportar el RMSE como evidencia de calidad causal],
      [Falsa confianza en un efecto sesgado],
      [Comparar métricas predictivas con métricas causales (Qini, cobertura)],
      [Validar con placebos, Qini y verdad sintética. En el caso 1 un $R^2$ de 0,84 convive con un sesgo de casi 19 %],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cap05>
]

*Límites del marco.* El marco de resultados potenciales supone no interferencia. En contextos con efectos cruzados (epidemias, redes sociales, externalidades) este supuesto se vulnera y se requieren métodos específicos, como la inferencia bajo interferencia o los diseños con aleatorización por conglomerados; quedan fuera del alcance de este volumen, y @aronow2017 es una referencia. El checklist completo de validación de métodos causales está en el apéndice #ref(<ap-checklists>, supplement: none).

== Ejercicios y notas bibliográficas
<sec-cap05_ejercicios>

=== Ejercicios teóricos

+ Clasifique cada pregunta como asociación, intervención o contrafactual: (a) ¿los alumnos con mejores notas tienen mejor salario?, (b) ¿sirve dar becas para mejorar notas?, (c) ¿María habría entrado a la universidad si le hubieran dado la beca?

+ Demuestre que, bajo no confusión condicional, $E[Y | D = 1] - E[Y | D = 0]$ difiere en general del ATE, y exprese la diferencia en términos de $mu_0(x)$ y de la distribución de $X$ en cada grupo. ¿Qué papel juega el soporte común?

+ En el tercer caso canónico, con $D = A + epsilon_D$, $Y = D + B + epsilon_Y$ y $C = A + B + epsilon_C$ (todas las perturbaciones normales estándar independientes), muestre que el coeficiente de $D$ en la regresión de $Y$ sobre $D$ y $C$ vale $4 \/ 5$. Sugerencia: aplique el teorema de Frisch-Waugh-Lovell y calcule $"Cov"(B, D - C \/ 3)$.

+ Justifique con la proposición de la @sec-cap05_garantias por qué un intervalo $hat(theta) plus.minus 1.96 hat("SE")$ del estimador por sustitución puede tener cobertura muy por debajo de 95 % aunque $hat(mu)_d$ sea un buen predictor. ¿Qué condición sobre $a_n$ lo evita?

+ La experiencia potencial es $"exper" = "edad" - "educ" - 6$. Muestre que, al incluirla como control en una regresión del salario sobre $"educ"$, el coeficiente de $"educ"$ compara personas con distinta escolaridad *y distinta edad* (la misma experiencia potencial), de modo que ya no mide el efecto de un año más de estudio a igual edad. ¿Qué comparación representa entonces?

#capa-impl[
=== Ejercicios computacionales

+ Reemplace #code[RandomForestRegressor] por #code[GradientBoostingRegressor] en el #ref(<lst-pred-vs-causal>, supplement: [listado]). ¿Aumenta o disminuye el sesgo del contraste predictivo? ¿Por qué?

+ Modifique el generador para que el efecto de $D$ sea $2$ en lugar de $1$ y verifique si el sesgo relativo del bosque cambia. Relacione el resultado con el argumento de la fracción de varianza explicada por $D$.

+ Construya un conjunto sintético con una variable $U$ no observada y verifique que el sesgo de OLS y de un bosque no disminuye al aumentar $n$ (caso 2).

+ Ejecute el #ref(<lst-collider-simulation>, supplement: [listado]) y explique por qué aparece una correlación entre $A$ y $B$ al condicionar en $C$.

=== Ejercicios aplicados

+ Sobre el conjunto #code[close_college], estime el retorno a la educación con (a) OLS sin controles y (b) OLS con #code[black], #code[smsa], #code[south] y #code[married]. No use #code[exper] como control: es función de la escolaridad. Compare los dos coeficientes.

+ Sobre #code[nsw_mixtape] (LaLonde), calcule la diferencia de medias de #code[re78] entre tratados y controles. Luego estime el ATE por OLS con #code[age], #code[educ], #code[black], #code[hisp], #code[marr], #code[nodegree], #code[re74] y #code[re75]. ¿Cuánto cambia la estimación y qué dice eso del balance observacional?
]

=== Notas bibliográficas

#cite(<athey2017beyond>, form: "prose") ofrece la motivación conceptual del campo. #cite(<imbens2015causal>, form: "prose") es la referencia canónica sobre resultados potenciales. #cite(<hernan2020whatif>, form: "prose") presenta de forma accesible el marco contrafactual. #cite(<mullainathan2017machine>, form: "prose") discute las diferencias prácticas entre predicción y estimación causal en políticas públicas, y #cite(<kleinberg2015prediction>, form: "prose") es la referencia obligada para el argumento simétrico: cuándo la pregunta de política es genuinamente predictiva, que el capítulo desarrolla en la @sec-cap05_problema. #cite(<elwert2014endogenous>, form: "prose") es el tratamiento de referencia del sesgo por _collider_ del tercer caso canónico. Para una revisión técnica reciente, véanse @athey2019econometric y @chernozhukov2018applied. @pearl2009causality, disponible en español como _Causalidad_, expone en profundidad la jerarquía causal y los modelos estructurales que subyacen a la distinción entre asociación, intervención y contrafactual. Sobre el ejemplo clásico de retornos a la educación con proximidad a una universidad como instrumento, véase @card1995 y su tratamiento en el @cap-ingenieria-datos-causales.
