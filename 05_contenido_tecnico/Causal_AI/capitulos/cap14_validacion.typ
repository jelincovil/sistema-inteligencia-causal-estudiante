// Capítulo 14: Validación, refutación y sensibilidad
#import "../template/template.typ": *

#chapter[Validación, refutación y sensibilidad]
<cap-validacion>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Validar modelos causales sin ground truth],
    [*Estimando:*], [CATE, ranking por efecto],
    [*Identificación:*], [No confusión, placebos, refutación],
    [*Método:*], [Curvas Qini y AUUC, transformed outcome, placebos, E-value],
    [*Nuisance:*], [$hat(e)(X), hat(mu)_(d)(X)$],
    [*Garantía:*], [Detección de fallos gruesos bajo refutación; cota de sensibilidad a confusión no observada (E-value)],
    ..if not es-principios {([*Librerías:*], [econml, scikit-learn, causalml])},
    [*Validación:*], [Suite de refutación, placebos, sensibilidad],
  )
]

#notatecnica[
Los tres capítulos anteriores (@cap-ortogonalidad, @cap-dml, @cap-meta-learners, @cap-causal-forests) presentaron estimadores; este capítulo cierra el bloque de estimación preguntando cómo saber si un estimador de CATE, en ausencia de _ground truth_, es confiable, y extiende la pregunta, en su última sección, a cómo organizar ese proceso de evaluación como parte de un sistema versionado y no solo como un chequeo puntual.
]

== Motivación aplicada
<sec-cap14_motivacion>

Un banco ha entrenado un modelo de uplift para decidir a qué clientes ofrecer una línea de crédito pre-aprobada. El modelo produce un CATE estimado para cada cliente. Antes de desplegarlo, el equipo de riesgo debe validar que el modelo realmente distingue clientes con alto uplift de clientes con bajo uplift. El problema fundamental: *no se observa el CATE verdadero* para ningún cliente, porque cada cliente recibe solo un tratamiento (no ambos resultados potenciales).

Esta es la situación estándar en aplicaciones reales de ML causal: el estimando de interés (CATE, policy value) no es observable, lo que hace inválida la validación cruzada estándar de ML supervisado. Este capítulo desarrolla estrategias de validación indirecta: curvas Qini, curvas uplift, transformed outcomes, validación con placebos, y comparación con benchmarks clásicos. Para datasets sintéticos con ground truth, también discutimos métricas directas de error (RMSE en $tau$, cobertura del IC).

== Teoría, supuestos y garantías
<sec-cap14_teoria>

=== El problema fundamental
<sec-cap14_problema_fundamental>

En ML supervisado estándar, la validación se basa en comparar predicciones $hat(Y)$ con observaciones $Y$. Para estimadores de CATE, el análogo sería comparar $hat(tau)(x)$ con $tau(x)$, pero $tau(x)$ no se observa. La única excepción son los datos sintéticos con DGP conocido, donde $tau(x)$ se computa analíticamente.

#proposition(name: [Imposibilidad de validación directa])[
  Para cualquier estimador $hat(tau)$ y cualquier dataset real $(Y, D, X)$, no existe función de los datos que permita estimar el error $norm(hat(tau) - tau)$ sin supuestos adicionales.
] <prop-no-direct-validation>

La solución es recurrir a _proxy metrics_ y a _placebo tests_ que, aunque no miden el error directamente, sí detectan fallos gruesos del estimador.

=== Curva Qini (versión acumulada)
<sec-cap14_qini>

La curva Qini evalúa el ranking por $hat(tau)$. Una versión acumulada ordena las unidades por $hat(tau)$ descendente y compara el uplift acumulado contra una asignación aleatoria:

$
Q_("cum")(q) = sum_(i in T(q)) Y_i - (|T(q)|) / (|C(q)|) sum_(i in C(q)) Y_i,
$

cuando $|C(q)| > 0$. Si $|C(q)| = 0$, la cantidad no está definida y debe regularizarse o excluirse del gráfico.

También puede definirse un uplift promedio top-$q$:

$
Q_("avg")(q) = 1/|T(q)| sum_(i in T(q)) Y_i - 1/|C(q)| sum_(i in C(q)) Y_i.
$

*Supuestos.* La curva Qini no requiere conocer $tau(x)$, pero su validez como proxy de ranking supone que los residuos $epsilon_i = Y_i - mu_(D_i)(X_i)$ son intercambiables entre tratados y controles. No garantiza ausencia de sesgo en la magnitud de $hat(tau)$, solo calidad de ranking.

*Garantías.* Bajo no confusión y soporte común, si $hat(tau)$ es monótono respecto a $tau$, la curva Qini es creciente y domina al baseline aleatorio. La pendiente inicial alta indica concentración de unidades con alto efecto en el top del ranking.

Interpretación:

- Si $hat(tau)$ es informativo, la curva acumulada debe ubicarse por encima del baseline aleatorio, con pendiente inicial alta.
- El uplift promedio top-$q$ no tiene por qué crecer con $q$; si el ranking es correcto, suele decrecer a medida que se incorporan unidades con menor efecto.
- Una curva Qini creciente en términos acumulados indica buen ranking, pero no garantiza ausencia de sesgo en la magnitud de $hat(tau)$.

*Resumen escalar: AUUC y coeficiente Qini.* Comparar dos curvas visualmente no escala cuando hay que evaluar muchos modelos o automatizar la decisión en un pipeline de CI (@cap-cicd-causal). Se usan por eso dos resúmenes escalares, que conviene no confundir. El *AUUC* (_Area Under the Uplift Curve_) es simplemente el área bajo la curva de uplift acumulado; depende de la escala de $Y$ y del tamaño muestral, por lo que solo tiene sentido comparar AUUC entre modelos evaluados sobre exactamente la misma muestra. El *coeficiente Qini* normaliza esa área restando el _baseline_ aleatorio y dividiendo por el área del modelo perfecto, produciendo un número comparable entre datasets, análogo al coeficiente de Gini del que toma el nombre.

Dos advertencias operativas. Primera: ambos son métricas de *ranking*, no de calibración: un modelo que multiplique todos sus $hat(tau)$ por 10 tiene exactamente el mismo AUUC y produciría un presupuesto de campaña diez veces mal dimensionado. Segunda: ambos son estadísticos muestrales con varianza no despreciable, especialmente en las colas del ranking donde $|C(q)|$ es pequeño; reportar un AUUC sin banda de confianza por _bootstrap_ invita a declarar ganador a un modelo que no lo es. El @cap-uplift-targeting retoma estas métricas como criterio de evaluación de la política y no solo del estimador.

=== Curva uplift y transformed outcome
<sec-cap14_uplift_transformed>

La _uplift curve_ normaliza por el tamaño total:
$
U(q) = 1/n sum_(i in T(q)) Y_i - 1/n sum_(i in C(q)) Y_i dot.c (|T(q)|) / (|C(q)|).
$

El _transformed outcome_ @athey2019using construye una variable $Y^star$ cuya esperanza es $tau(X)$:
$
Y_i^star = Y_i dot.c (D_i - hat(e)(X_i)) / (hat(e)(X_i)(1 - hat(e)(X_i))).
$ <eq-transformed-outcome>

#proposition[
  Si $hat(e) = e_0$, entonces $E[Y^star | X] = tau(X)$.
] <prop-transformed-outcome>

*Supuestos.* La validez de $Y^star$ como proxy requiere que $hat(e)$ sea consistente para el verdadero propensity score $e_0$. Si $hat(e)$ está mal especificado, $E[Y^star | X] != tau(X)$.

*Garantías.* $Y^star$ permite usar métricas de ML supervisado (RMSE, correlación) sobre $hat(tau)$. La desventaja: $Y^star$ tiene alta varianza, especialmente cuando $hat(e)$ es cercano a 0 o 1. Con $sigma_1^2(X), sigma_0^2(X)$ las varianzas condicionales de $Y$ bajo tratamiento y control, la varianza de $Y^star$ condicional en $X$ es:
$
"Var"(Y^star | X) = (sigma_1^2(X) + mu_1(X)^2) / e_0(X) + (sigma_0^2(X) + mu_0(X)^2) / (1 - e_0(X)) - tau(X)^2,
$
que explota cuando $e_0(X) -> 0$ o $e_0(X) -> 1$: el término dominante en cada límite es, respectivamente, $1\/e_0(X)$ o $1\/(1-e_0(X))$, independientemente del resto de la expresión.

=== Placebo tests
<sec-cap14_placebo_tests>

Un _placebo test_ estima el efecto causal en un contexto donde debería ser cero. La lógica es simple: si el estimador produce un efecto no nulo donde sabemos que no debería haberlo, el estimador está sesgado.

*Supuestos.* El placebo test requiere que en el contexto placebo se cumplan los mismos supuestos de identificación que en el contexto real. Si no, un resultado no nulo podría deberse a violación de supuestos en el placebo y no a un problema del estimador.

*Garantías.* Bajo la hipótesis nula de efecto nulo y correcta especificación, el estimador debe producir un efecto indistinguible de cero. Un resultado significativo en un placebo es evidencia de mala especificación.

Tres variantes comunes:

- *Placebo temporal:* estimar el efecto en un periodo pre-tratamiento. Si el estimador es válido, el efecto debe ser cercano a cero.
- *Placebo por subgrupo:* estimar el efecto en un subgrupo que no debería responder al tratamiento (p. ej., efecto de un programa escolar sobre jubilados).
- *Placebo por outcome:* estimar el efecto sobre un outcome que no debería responder (p. ej., efecto de becas sobre altura).

#caso-canonico("Placebo temporal con confusor no observado")[
  Se simulan $n = 1 thin 500$ unidades observadas en dos periodos. Una covariable observada $X tilde N(0, 1)$ y un confusor no observado $U tilde N(0, 1)$ afectan al resultado en ambos periodos, $Y_t = 1 + 0.5 X + s U + epsilon_t$ con $epsilon_t tilde N(0, 1)$, y quien recibe el programa depende de ambos, $P(D = 1) = sigma(0.8 X + s U)$. El programa llega en el periodo 1 y su efecto verdadero es 0.3. El parámetro $s$ gobierna la confusión no observada: con $s = 0$ no hay ninguna, y con $s = 1$ es fuerte.
]

En una corrida con semilla fija, el placebo del periodo 0 (cuando el programa aún no existe) da, con $s = 0$, un efecto de 0,06 cuyo intervalo de 95 % contiene el cero, y el efecto real del periodo 1 se estima en 0,40 con un intervalo que cubre 0,3. Con $s = 1$ el placebo da 0,86 con un intervalo que excluye el cero con holgura, y el efecto real se estima en 1,02, más de tres veces la verdad. El placebo no corrigió nada, pero avisó que la estimación del periodo 1 no se podía creer. Y lo hizo sin conocer $U$: le bastó observar un efecto donde no podía haberlo.

=== Sensibilidad a confusión no observada: protocolo de tres niveles
<sec-cap14_evalue>

Los placebos detectan mala especificación, pero no responden la pregunta que más importa y que ningún test puede responder con los datos disponibles: *¿cuán fuerte tendría que ser un confusor no observado para anular el resultado?* La literatura de análisis de sensibilidad la convierte en una pregunta cuantitativa y reportable. La formulación más difundida hoy es el *E-value* de #cite(<vanderweele2017evalue>, form: "prose").

#definition(name: [E-value])[
Para una razón de riesgos estimada $"RR" > 1$, el *E-value* es
$
"E" = "RR" + sqrt("RR" ("RR" - 1)),
$
y se interpreta como la intensidad común mínima bajo una parametrización simétrica de las asociaciones confusor--tratamiento y confusor--resultado, por encima de las covariables ya medidas, que alcanzaría a explicar completamente la asociación observada. Para el límite del intervalo de confianza más cercano a la nulidad se calcula un segundo E-value, que indica la intensidad simétrica necesaria para llevarlo hasta la nulidad.
]

La lectura anterior es la parametrización *simétrica*: impone la misma intensidad a las dos asociaciones. En general, si $"RR"_("UD")$ mide la asociación confusor--tratamiento y $"RR"_("UY")$ la asociación confusor--resultado, el factor conjunto que acota el sesgo es
$
frac("RR"_("UD") "RR"_("UY"), "RR"_("UD") + "RR"_("UY") - 1).
$
Para explicar la razón de riesgos observada, ese factor debe alcanzarla. Una de las dos asociaciones puede ser menor que el E-value si la otra es mayor; la fórmula simétrica no exige que cada una supere $"E"$. El confusor puede representar además un conjunto de variables no medidas, no necesariamente una sola variable.

La virtud del E-value es que traduce la amenaza a la identificación a una escala que un experto de dominio puede juzgar. Decir "el resultado es sensible a confusión no observada" no es accionable; decir "haría falta un confusor no medido asociado al tratamiento y al resultado con RR $>= 3.2$, cuando el confusor observado más fuerte de que disponemos tiene RR $= 1.6$" invita a una discusión sustantiva concreta: ¿existe una variable plausible de esa magnitud que no hayamos medido?

Sus límites deben declararse con la misma claridad. El E-value resume una cota necesaria bajo el modelo de sensibilidad, no una prueba de ausencia de confusión ni una probabilidad. No incorpora información sobre qué asociaciones son plausibles en el dominio. Su formulación estándar está definida sobre razones de riesgo; aplicarlo a un efecto en diferencias requiere una transformación de escala justificada. Si el estimando o la escala no admiten esa transformación, corresponde otro análisis de sensibilidad.

*Nivel 2: sensibilidad en escala $R^2$.* Para estimaciones tipo PLR (DML-PLR, PDS), la pregunta equivalente es: ¿qué $R^2$ parcial con $D$ y con $Y$ tendría que tener un confusor no observado $U$ para anular el efecto? Si $r_(Y dot.op U | X, D)^2$ y $r_(D dot.op U | X)^2$ denotan las fracciones de varianza residual explicadas por $U$, el efecto deja de ser significativo cuando ambas superan un umbral derivable del $t$-estadístico observado (#cite(<cinellihazlett2020>, form: "prose"); la formulación en escala $R^2$ se remonta a #cite(<imbens2003sensitivity>, form: "prose")). La ventaja sobre el E-value: se reporta contra _benchmarks_ observados (el $R^2$ parcial del confusor medido más fuerte) en la misma escala del modelo estimado, sin cambio de escala a razones de riesgo.

*Nivel 3: identificación parcial.* Cuando el supuesto puede fallar parcialmente, el reporte correcto es un intervalo de _bounds_. Con $Y in [0, 1]$ y sin ningún supuesto de no confusión, #cite(<manski1990nonparametric>, form: "prose") muestra que, con $a = E[Y | D=1] P(D=1) - E[Y | D=0] P(D=0)$ (la diferencia de medias ponderada por la proporción de cada grupo),
$
theta = E[Y(1) - Y(0)] in [ a - P(D=1), thin a + P(D=0) ],
$
de ancho exactamente 1. Los _bounds_ solo se estrechan si se está dispuesto a acotar la fuerza de la confusión no observada, que es la pregunta que plantean los Niveles 1 y 2.

*Regla de reporte.* Todo resultado observacional que alimente una decisión#solo-curso[ (en el proyecto final, @sec-apE_sensibilidad)] usa al menos un análisis de sensibilidad compatible con su estimando, su escala y su diseño. El E-value es pertinente para razones de riesgo o transformaciones justificadas; la sensibilidad en escala $R^2$ corresponde a estimaciones lineales tipo PLR; los _bounds_ corresponden cuando el resultado y los supuestos permiten construirlos. El informe nombra el objeto acotado, compara la magnitud con referencias de dominio y declara qué queda fuera del análisis. Ninguna métrica aislada decide automáticamente el despliegue.

=== Validación con datos sintéticos
<sec-cap14_sinteticos>

Para datasets sintéticos con $tau(x)$ conocido, se reportan:

- *Sesgo:* $E[hat(tau)(X) - tau(X)]$.
- *RMSE:* $sqrt(E[(hat(tau)(X) - tau(X))^2])$.
- *Cobertura del IC:* fracción de $x$ tales que $tau(x) in [hat(tau)(x) plus.minus 1.96 hat(sigma)(x)]$.
- *Policy regret:* diferencia entre $V(pi^*)$ y $V(hat(pi))$ donde $pi^*$ es la política óptima y $hat(pi)$ se deriva de $hat(tau)$.

=== Tests formales de heterogeneidad: BLP, GATES y CLAN
<sec-cap14_tests_heterogeneidad>

La curva Qini evalúa _ranking_; no responde si la heterogeneidad detectada es estadísticamente distinguible de cero. #cite(<chernozhukov2020generic>, form: "prose") proveen tests con control de tipo I, sin _ground truth_, mediante _sample-splitting_ (la misma lógica del _cross-fitting_ del @cap-ortogonalidad).

*BLP (Best Linear Predictor).* Sea $hat(T)(X)$ un score de prioridad (p. ej. $hat(tau)$ de un _causal forest_). En la muestra de evaluación, con el _transformed outcome_ $Y^star$ (Ec. @eq-transformed-outcome):
$
Y_i^star = beta_1 + beta_2 (hat(T)_i - overline(T)) + epsilon_i.
$
El test $H_0: beta_2 = 0$ es un test válido de "no hay heterogeneidad linealmente detectable por $hat(T)$". El coeficiente $beta_1$ estima el efecto promedio, y $beta_2$ mide cuánto del efecto covaría con el puntaje: vale 1 si $hat(T)$ coincide con $tau$ y 0 si no aporta nada.

*GATES (Grouped Average Treatment Effects).* Particionar la muestra de evaluación por cuantiles de $hat(T)$ y estimar el efecto medio de cada grupo con intervalos que tengan en cuenta la comparación entre grupos. La comparación de los grupos extremos, a veces resumida como _best subgroup treatment effect_, es un caso particular de esta familia.

*CLAN (Classification Analysis).* Comparar las características observadas de los grupos definidos por GATES, por ejemplo qué covariables distinguen al grupo de efecto alto del de efecto bajo. CLAN describe quién integra esos grupos; no es el nombre de sus efectos medios.

#capa-impl[Las bibliotecas de CATE ofrecen piezas distintas de esta evaluación. En EconML, #code[DRTester] documenta BLP, calibración y Qini; no debe citarse como implementación de GATES o CLAN sin comprobar una extensión adicional.]

*Regla de reporte.* El informe elige la prueba que responde a su afirmación: BLP para asociación lineal entre score y efecto, GATES para efectos por grupos y CLAN para caracterizarlos. Si la evidencia no distingue la heterogeneidad del ruido, la conclusión se declara exploratoria. No es necesario ejecutar las tres pruebas en todo caso.

=== Intervalos conformes para el pseudoresultado transformado
<sec-cap14_conformal>

*El problema.* El teorema de cobertura del CATE del @cap-causal-forests da cobertura para $tau(x)$, no para el efecto individual $Y_(i)(1) - Y_(i)(0)$. El procedimiento de esta sección calibra un _transformed outcome_ observable; por tanto, su objeto de cobertura tampoco es el efecto individual. Es útil para evaluar la dispersión predictiva de ese pseudoresultado alrededor de $hat(tau)(x)$, siempre que se lo nombre así.

*Procedimiento (split conformal sobre transformed outcome).* Bajo asignación aleatorizada o _propensity_ conocido, $Y_i^star$ (Ec. @eq-transformed-outcome) satisface $E[Y^star | X] = tau(X)$:

+ Particionar en entrenamiento $cal(D)_1$ y calibración $cal(D)_2$.
+ Entrenar $hat(tau)$ en $cal(D)_1$.
+ En $cal(D)_2$ calcular residuos no conformes $R_i = abs(Y_i^star - hat(tau)(X_i))$.
+ $hat(C)(x) = [hat(tau)(x) - hat(q), thin hat(tau)(x) + hat(q)]$, con $hat(q)$ el cuantil $ceil((m+1)(1-alpha))/m$ de ${R_i}$.

#proposition(name: [Cobertura conforme])[
  Si las observaciones son intercambiables, $P(Y_"nuevo"^star in hat(C)(X_"nuevo")) >= 1 - alpha$, sin supuestos distribucionales sobre $(Y, D, X)$.
] <prop-conformal-coverage>

Dos advertencias. Primera: la cobertura es para el _transformed outcome_ (un proxy insesgado del efecto), no para $Y_(i)(1) - Y_(i)(0)$ literal (#cite(<leicandes2021>, form: "prose") tratan la versión con contrafactuales imputados). Segunda: con _propensity_ estimado se requiere _conformal_ ponderado (#cite(<tibshirani2019conformal>, form: "prose")); la versión sin ponderar es válida solo si $hat(e) approx e_0$. Para la base de predicción conforme libre de distribución, ver #cite(<lei2018distribution>, form: "prose"), y #cite(<romano2019conformalized>, form: "prose") para la variante de regresión cuantílica conforme.

*Integración en producción:* el servicio de estimación (@sec-despliegue-contrato) no presenta este intervalo como intervalo del efecto individual. Si lo expone con fines diagnósticos, lo etiqueta como intervalo predictivo del pseudoresultado y mantiene separado el intervalo de inferencia para el CATE. La _model card_ (@cap-model-card-causal) declara el objeto cubierto por cada uno. Obtener cobertura para resultados potenciales o para el ITE requiere otro procedimiento y supuestos adicionales, como los estudiados por #cite(<leicandes2021>, form: "prose").

#capa-impl[
== Implementación en Python
<sec-cap14_implementacion>

=== Curva Qini sobre datos sintéticos
<sec-cap14_impl_qini>

El listado entrena en una parte de los datos y evalúa en otra, y compara tres rankings sobre la misma muestra de evaluación: el del CATE estimado, el de una regla de riesgo que ignora la causalidad y el orden perfecto, que solo existe porque los datos son sintéticos. Para usar un estimador de EconML basta sustituir la función `t_learner` por el ajuste de un `CausalForestDML` en la muestra de entrenamiento y devolver su `effect` sobre la de evaluación.

#figure(
  kind: raw,
  caption: [Curva Qini en una muestra de evaluación, con tres rankings y el azar como referencia.],
  ```python
import numpy as np
import matplotlib.pyplot as plt
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.model_selection import train_test_split

# DGP con CATE conocido (solo posible con datos sinteticos)
def make_dgp(n=3000, seed=0):
    rng = np.random.default_rng(seed)
    X = rng.uniform(-1, 1, (n, 5))
    e = 1 / (1 + np.exp(-0.5 - 0.3 * X[:, 0]))
    D = (rng.uniform(size=n) < e).astype(int)
    tau = 2 + 3 * X[:, 0] - X[:, 1] ** 2
    mu0 = X[:, 2] + X[:, 3]
    Y = mu0 + D * tau + rng.standard_normal(n) * 0.5
    return Y, D, X, tau

def gbm():
    return GradientBoostingRegressor(n_estimators=200, max_depth=3, random_state=42)

def t_learner(Y, D, X, X_nuevo):
    """CATE estimado y riesgo basal (resultado esperado sin tratamiento)."""
    m1 = gbm().fit(X[D == 1], Y[D == 1])
    m0 = gbm().fit(X[D == 0], Y[D == 0])
    return m1.predict(X_nuevo) - m0.predict(X_nuevo), m0.predict(X_nuevo)

def qini_curve(Y, D, score):
    """Qini acumulada: ordena por score descendente (no es el uplift promedio top-q)."""
    o = np.argsort(-score)
    y, d = Y[o], D[o]
    cum_T = np.cumsum(y * d)
    cum_C = np.cumsum(y * (1 - d))
    n_C = np.cumsum(1 - d)
    n_T = np.cumsum(d)
    qini = cum_T - cum_C * n_T / np.clip(n_C, 1, None)
    return np.arange(1, len(y) + 1) / len(y), qini

# Particion: se entrena en una parte y se evalua en otra (hold-out)
Y, D, X, tau = make_dgp(3000, seed=42)
tr, te = train_test_split(np.arange(len(Y)), test_size=0.4, random_state=0)
tau_hat, riesgo = t_learner(Y[tr], D[tr], X[tr], X[te])

# Metricas directas (solo posibles con ground truth)
rmse = np.sqrt(np.mean((tau_hat - tau[te]) ** 2))
bias = np.mean(tau_hat - tau[te])
print(f"RMSE: {rmse:.3f}  Bias: {bias:.3f}")

def area(q, x):
    return np.sum((q[1:] + q[:-1]) * np.diff(x)) / 2     # regla del trapecio

# Rankings comparados sobre el mismo hold-out
rankings = {"T-learner (por CATE estimado)": tau_hat,
            "Regla de riesgo (sin causalidad)": riesgo,
            "Orden perfecto (CATE verdadero)": tau[te]}
curvas = {k: qini_curve(Y[te], D[te], s) for k, s in rankings.items()}
frac, q_perfecto = curvas["Orden perfecto (CATE verdadero)"]
azar = q_perfecto[-1] * frac                       # linea recta: tratar al azar
for k, (_, q) in curvas.items():
    coef = (area(q, frac) - area(azar, frac)) / (area(q_perfecto, frac) - area(azar, frac))
    print(f"{k:34s} coeficiente Qini = {coef:.3f}")

plt.figure(figsize=(8, 5))
for k, (f, q) in curvas.items():
    plt.plot(f, q, label=k, lw=2)
plt.plot(frac, azar, label="Azar", lw=2, ls="--", color="gray")
plt.xlabel("Fracción de la muestra de evaluación (mayor puntaje primero)")
plt.ylabel("Uplift acumulado (Qini)")
plt.legend()
plt.title("Curva Qini en hold-out: validación del ranking por CATE")
plt.tight_layout()
plt.savefig("qini_curve.png", dpi=120, bbox_inches="tight")
```
) <lst-qini>

=== Placebo test
<sec-cap14_impl_placebo>

El listado genera un panel de dos periodos y aplica el placebo temporal dos veces: sin confusor no observado y con uno. En el segundo caso el programa llega a quienes ya estaban mejor, y el placebo debe delatarlo.

#figure(
  kind: raw,
  caption: [Placebo temporal sobre un panel sintético, con y sin confusor no observado.],
  ```python
import numpy as np
import pandas as pd
from econml.dml import LinearDML
from sklearn.ensemble import RandomForestRegressor, RandomForestClassifier

# Panel sintetico de dos periodos: el programa llega en t = 1
def make_panel(n=1500, seed=0, sesgo=0.0):
    rng = np.random.default_rng(seed)
    x = rng.normal(size=n)                          # covariable observada
    u = rng.normal(size=n)                          # confusor NO observado
    p = 1 / (1 + np.exp(-0.8 * x - sesgo * u))      # quien se trata depende de x y de u
    treated = (rng.uniform(size=n) < p).astype(int)
    y0 = 1 + 0.5 * x + sesgo * u + rng.normal(size=n)                   # antes del programa
    y1 = 1 + 0.5 * x + sesgo * u + 0.3 * treated + rng.normal(size=n)   # despues
    return pd.DataFrame({"x": x, "treated_group": treated, "y_t0": y0, "y_t1": y1})

def efecto(df, y):
    est = LinearDML(model_y=RandomForestRegressor(n_estimators=100, random_state=42),
                    model_t=RandomForestClassifier(n_estimators=100, random_state=42),
                    discrete_treatment=True, cv=3, random_state=42)
    X = df[["x"]].to_numpy()
    est.fit(df[y].to_numpy(), df["treated_group"].to_numpy(), X=X)
    return est.ate(X=X), *est.ate_interval(X=X, alpha=0.05)

for sesgo in (0.0, 1.0):
    df = make_panel(sesgo=sesgo)
    # Placebo temporal: efecto del programa sobre el outcome ANTERIOR al programa
    pl, lb, ub = efecto(df, "y_t0")
    print(f"sesgo={sesgo}: ATE placebo {pl:.3f}  IC [{lb:.3f}, {ub:.3f}]  contiene 0: {lb <= 0 <= ub}")
    ef, lb, ub = efecto(df, "y_t1")
    print(f"         ATE real    {ef:.3f}  IC [{lb:.3f}, {ub:.3f}]  (verdad 0.3)")
```
) <lst-placebo>
]

== Caso empírico y validación
<sec-cap14_caso>

=== Suite de refutación
<sec-cap14_refutation>

La tabla #ref(<tab-refutation-suite>, supplement: none) resume las pruebas de refutación estándar para validar modelos causales sin ground truth. Estas pruebas no garantizan que el modelo sea correcto, pero detectan fallos gruesos de especificación.

#figure(
  caption: [Suite de refutación para modelos causales.],
  table(
    columns: (1.2fr, 1.8fr, 1.8fr),
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Prueba*], [*Qué hace*], [*Interpretación*]),
    table.hline(stroke: 0.4pt),
    [Placebo treatment], [Reemplaza $D$ por variable aleatoria], [El efecto estimado debe caer a cero; si no, el modelo detecta señal espuria],
    [Random common cause], [Agrega una covariable ruido independiente de $Y$ y $D$], [El efecto estimado debe ser estable; un cambio grande indica sensibilidad a ruido],
    [Subset validation], [Remuestrea los datos (bootstrap) y reestima], [La distribución bootstrap del efecto debe ser estable; varianza alta sugiere sobreajuste],
    [Transformed outcome], [Construye $Y^star$ y evalúa $hat(tau)$ con métricas supervisadas], [$E[Y^star | X] = tau(X)$ bajo $hat(e)$ correcto; permite RMSE y correlación],
    [BLP/BEST], [Test de heterogeneidad sobre $hat(T)$], [$beta_2$ no significativo $=>$ la heterogeneidad no supera el ruido (@sec-cap14_tests_heterogeneidad)],
    table.hline(stroke: 0.8pt),
  )
) <tab-refutation-suite>

=== Curva Qini comparativa
<sec-cap14_qini_comparativa>

#caso-canonico("Qini con CATE conocido")[
  Se simulan $n = 3 thin 000$ unidades con cinco covariables independientes $X_1, dots, X_5 tilde U(-1, 1)$. El tratamiento depende débilmente de la primera, $D tilde "Bernoulli"(sigma(0.5 + 0.3 X_1))$, el efecto es $tau(X) = 2 + 3 X_1 - X_2^2$ y el resultado es $Y = X_3 + X_4 + D tau(X) + epsilon$ con $epsilon tilde N(0, 0.5^2)$. El efecto varía entre unidades y es negativo en el 22 % de la población. El resultado sin tratamiento, $X_3 + X_4$, no tiene relación con el efecto: quién tiene más riesgo y a quién le sirve más el tratamiento son preguntas distintas. El 60 % de las unidades entrena el estimador y el 40 % restante, que el estimador no vio, evalúa.
]

La figura #ref(<fig-cap14-qini>, supplement: none) compara, sobre esa muestra de evaluación, tres rankings: el del CATE estimado por un T-learner con _gradient boosting_, el de una regla de riesgo que ordena por el resultado esperado sin tratamiento, y el orden perfecto, que usa el CATE verdadero y solo existe con datos sintéticos. El azar es la recta que une el origen con el uplift total.

#figure(
  image("../figuras/fig_cap14_qini.png", width: 85%),
  caption: [Elaboración propia. Curva Qini en una muestra de evaluación de 1 200 unidades: ranking por CATE estimado (T-learner), regla de riesgo sin causalidad, orden perfecto y azar. Datos sintéticos con $tau(x) = 2 + 3x_1 - x_2^2$ y $n = 3 thin 000$; semillas 42 (datos), 0 (partición) y 42 (_boosting_).],
) <fig-cap14-qini>

*Interpretación.* El ranking por CATE estimado sigue de cerca al orden perfecto: su coeficiente Qini es 0,999. Al tratar al 20 % con mayor puntaje acumula un uplift de 651 (en unidades de $Y$), frente a los 277 que daría el azar. La regla de riesgo, en cambio, ordena como el azar: su coeficiente es $-0.05$. Es el error que el @cap-causalidad-elemental advierte, visible aquí en una cifra. Las curvas de los dos rankings informativos alcanzan su máximo antes del final (con el 82 % de la muestra la del T-learner y con el 86 % la del orden perfecto) y luego bajan, porque el 21 % de las unidades de evaluación tiene efecto negativo y tratarlas resta. Esa caída es lo que un promedio global oculta y una curva Qini deja ver. El generador es deliberadamente favorable, con heterogeneidad fuerte y suave, y un coeficiente tan alto no debe esperarse con datos reales. Las métricas directas (RMSE de 0,33 y sesgo de 0,014 sobre $tau$) existen solo porque los datos son sintéticos.

El experimento de #cite(<thornton2008demand>, form: "prose")#solo-curso[ (dataset #code[thornton_hiv])] evalúa el efecto de incentivos monetarios sobre la demanda de resultados de test de VIH en Malaui. Su valor para este capítulo es que el tratamiento fue *aleatorizado*, de modo que la identificación no está en discusión y toda desviación detectada por la suite de refutación es atribuible al estimador y no al diseño. Es la situación de control que permite calibrar qué tan informativas son las métricas indirectas antes de aplicarlas a datos observacionales, donde ambas fuentes de error se confunden.

#intuicion[
  *Caja de profundización: Pruebas de refutación y análisis de sensibilidad*

  *Objetivo.* Aprender a poner a prueba un modelo causal cuando no tenemos el efecto verdadero.

  *Pruebas de placebo.*
  - *Placebo treatment:* asignar el tratamiento aleatoriamente y reestimar. El ATE debería ser cero.
  - *Placebo outcome:* usar una variable que sabemos que no es afectada por el tratamiento como si fuera $Y$.
  - *Placebo temporal:* en datos de panel, aplicar el método a un período prepolíticas donde no debería haber efecto.

  *¿Qué tan sensible es mi resultado a un confusor no observado?* Incluso si controlamos por muchos confusores observados, siempre puede haber uno no observado. El *E-value* (@sec-cap14_evalue) responde: ¿qué tan fuerte tendría que ser ese confusor para explicar mi resultado? Un E-value grande sugiere robustez, pero "grande" solo tiene sentido *comparado con la fuerza de los confusores que sí se midieron*, no contra un umbral universal.

  *Bootstrap para curvas Qini.* Podemos remuestrear los datos muchas veces y recalcular la curva Qini cada vez. Esto nos da bandas de confianza alrededor de la curva y permite comparar modelos formalmente.
]

== Riesgos, límites y sensibilidad
<sec-cap14_riesgos>

=== Tabla de riesgos
<sec-cap14_tabla_riesgos>

La tabla #ref(<tab-riesgos-cap07>, supplement: none) resume los principales riesgos al validar modelos causales sin ground truth, junto con sus consecuencias, diagnóstico y mitigación.

#riesgos[
  #figure(
    caption: [Riesgos en la validación de modelos causales sin ground truth.],
    table(
      columns: (1.4fr, 1.4fr, 1.4fr, 1.8fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Validar con $R^2$ de $Y$],
      [Falsa confianza en estimaciones sesgadas],
      [Comparar $R^2$ predictivo con métricas causales (Qini, placebos)],
      [Usar placebos, Qini y ground truth sintético. El $R^2$ predictivo de $Y$ no correlaciona con la calidad de la estimación causal. Un modelo puede predecir $Y$ perfectamente y producir CATEs totalmente sesgados],
      table.hline(stroke: 0.4pt),
      [Omitir placebo tests en datos reales],
      [No detectar mala especificación del estimador],
      [Verificar que se aplicaron placebos antes de desplegar],
      [Sin ground truth, los placebos son la única validación de especificación. Son obligatorios],
      table.hline(stroke: 0.4pt),
      [Sobreinterpretar la curva Qini],
      [Creer que un ranking informativo implica CATE insesgado],
      [Comparar magnitud de $hat(tau)$ con benchmarks o transformed outcome],
      [Una curva Qini creciente indica que el ranking es informativo, pero no que el CATE estimado sea insesgado. Puede haber sesgo uniforme que preserve el ranking],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cap07>
]

=== Límites
<sec-cap14_limites>

Las métricas indirectas (Qini, uplift, transformed outcome) solo detectan fallos gruesos. No garantizan ausencia de sesgo. La validación definitiva requiere replicación en experimentos controlados o datasets sintéticos con ground truth.

*¿Cuándo no usar este enfoque?* La validación indirecta no reemplaza un diseño de identificación creíble. Si el supuesto de no confusión es cuestionable, ninguna suite de refutación lo rescata. En esos casos, priorizar diseños cuasi-experimentales (RDD, DID, IV) sobre la validación post-hoc.

== Evaluación offline en el ciclo de vida del sistema
<sec-cap14_evaluacion_offline>

Las secciones anteriores de este capítulo responden una pregunta estadística: ¿el estimador de CATE es razonable? Esta sección, que extiende el capítulo con una perspectiva de ingeniería de sistemas siguiendo a @huyen2022dmls (Capítulo 6, "Model Development and Offline Evaluation"), responde una pregunta distinta y complementaria: *¿cómo se organiza el proceso de evaluación offline para que sea comparable a través del tiempo y de distintas versiones del modelo?*

=== _Baselines_ obligatorios

#cite(<huyen2022dmls>, form: "prose") insiste en que ningún modelo se evalúa en el vacío: siempre debe compararse contra al menos un _baseline_ simple. Para un sistema de estimación causal, se recomiendan tres _baselines_ mínimos antes de aceptar cualquier estimador de CATE como el de producción:

#table(
  columns: (1.3fr, 2.7fr),
  align: left,
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Baseline*], [*Qué revela*]),
  [Efecto constante (ATE vía DML, @cap-dml)], [Si el CATE estimado no supera a un efecto constante en la curva Qini, la heterogeneidad modelada no aporta valor accionable.],
  [Regla aleatoria], [Piso de referencia: cualquier estimador debe superar claramente a targetear al azar.],
  [Regla basada en riesgo (sin causalidad)], [Detecta si el "efecto heterogéneo" estimado es, en realidad, una reformulación de quién tiene mayor $Y$ esperado sin tratamiento, un error de confusión entre pronóstico de riesgo y efecto causal ya discutido en el @cap-causalidad-elemental. En el caso canónico de la figura #ref(<fig-cap14-qini>, supplement: none), esta regla obtiene un coeficiente Qini de $-0.05$.],
  [RATE del estimador candidato vs. efecto constante], [Si RATE no supera al efecto constante, la heterogeneidad no aporta valor (consistente con la advertencia de la Figura #ref(<fig-cap21-policy-value>, supplement: none)).],
)

=== Selección formal de estimadores de CATE: RATE

El @cap-meta-learners compara meta-learners por RMSE sobre $tau$, métrica disponible solo con _ground truth_ sintético. En datos reales, el criterio formal es RATE (_Rank-Weighted Average Treatment Effect_, #cite(<yadlowsky2021rate>, form: "prose")). Se parte de la curva TOC (_Targeting Operator Characteristic_), que para cada fracción $q$ mide cuánto más gana el top-$q$ del ranking respecto del efecto promedio:
$
"TOC"(q) = E[tau(X) | X in "top"_q (hat(tau))] - E[tau(X)], quad "RATE" = integral_0^1 w(q) "TOC"(q) dif q,
$
con $w(q) = 1$ (el AUTOC, que pesa igual todo el ranking) o $w(q) = q$ (el análogo de Qini, que pesa más el tramo donde se trata a más gente). Un RATE positivo indica que el ranking concentra efecto en su cabeza; uno cercano a cero, que no distingue mejor que el azar. En el caso canónico de la figura #ref(<fig-cap14-qini>, supplement: none), calculado con el CATE verdadero sobre la muestra de evaluación, el AUTOC vale 1,49 para el ranking del T-learner y $-0.004$ para el de la regla de riesgo.

El RATE se estima con puntajes doblemente robustos sobre una muestra de evaluación y admite inferencia (#cite(<yadlowsky2021rate>, form: "prose")). Para elegir entre dos estimadores conviene reportar la diferencia de sus RATE con un intervalo calculado sobre la misma muestra, por ejemplo con _bootstrap_, de modo que la diferencia no se confunda con ruido.

#capa-impl[El `RScorer` de EconML (`econml.score.RScorer`) puntúa estimadores con la pérdida R de #cite(<nie2021quasi>, form: "prose"), un criterio distinto de RATE y complementario. Para RATE, el paquete `grf` de R trae una implementación.]

*Regla de decisión.* La elección entre meta-learners y _causal forest_ en datos reales se documenta con la diferencia de RATE y su intervalo, no con la inspección visual de la curva Qini. Qini sigue siendo la métrica de reporte para audiencias de negocio (@cap-uplift-targeting); RATE es la métrica de decisión interna.

=== Versionado del proceso de evaluación

Un segundo punto que DMLS enfatiza y que la literatura puramente estadística de validación causal rara vez menciona: el *proceso* de evaluación offline (qué _baselines_, qué partición de datos, qué semilla aleatoria) debe versionarse junto con el modelo, no solo el modelo mismo. Sin esto, comparar "la nueva versión del estimador es mejor que la anterior" es una afirmación no verificable: dos evaluaciones hechas con particiones distintas de los datos no son comparables, sin importar cuán rigurosa sea cada una por separado. La pieza de pruebas del @cap-anatomia-sistema existe exactamente para fijar este proceso una vez y reutilizarlo.

Esta perspectiva de sistema es la que conecta este capítulo con el siguiente: una vez que el proceso de evaluación offline está versionado y es reproducible, la pregunta natural es cómo llevar el estimador que pasó esa evaluación a un servicio que otros puedan consultar, el tema del @cap-despliegue-servicio.

== Ejercicios y notas bibliográficas
<sec-cap14_ejercicios>

=== Ejercicios propuestos
<sec-cap14_ejercicios_propuestos>

+ Compare tres estimadores de CATE (por ejemplo un bosque causal, un X-learner y un T-learner) sobre la misma muestra de evaluación del caso canónico de la @sec-cap14_qini_comparativa. ¿Cuál obtiene el coeficiente Qini más alto, y cuánta incertidumbre tiene esa diferencia? #capa-impl[(Parta del #ref(<lst-qini>, supplement: [listado]).)]

+ Construya un DGP donde el CATE sea constante ($tau(x) = tau$ para todo $x$). Verifique que la curva Qini es plana, y explique por qué el coeficiente Qini, que divide por el área del orden perfecto, deja de ser informativo en ese caso.

+ En el caso canónico, la regla de riesgo ordena como el azar porque el resultado sin tratamiento no se relaciona con el efecto. Construya un DGP donde ambos estén positivamente correlacionados y otro donde lo estén negativamente. Prediga el signo del coeficiente Qini de la regla de riesgo en cada uno y verifíquelo. ¿Qué implica para una campaña que se dirige a "los clientes con más riesgo"?

+ Sobre un conjunto observacional con varios periodos previos al tratamiento#solo-curso[ (por ejemplo #code[cps_mixtape])], estime el CATE con un bosque causal y aplique un placebo temporal. Si el placebo rechaza, ¿qué supuesto se está violando y qué diseño lo corrige?

+ Implemente el _transformed outcome_ $Y_i^star$ de la ecuación #ref(<eq-transformed-outcome>, supplement: none) y calcule la correlación entre $Y_i^star$ y $hat(tau)$. ¿Es alta? En el caso canónico vale 0,53 aunque el ranking es casi perfecto. Explique por qué la correlación no se acerca a 1 y qué dice eso sobre usar $Y^star$ como métrica. Pista: compare la varianza de $Y^star$ con la de $tau$ (10,1 frente a 3,1).

=== Lecturas complementarias
<sec-cap14_lecturas>

#cite(<gutierrez2017causal>, form: "prose") revisa la literatura de uplift e introduce el _transformed outcome_ usado en la @sec-cap14_uplift_transformed. #cite(<athey2019using>, form: "prose") formaliza la validación causal aplicada. #cite(<schuler2018comparison>, form: "prose") compara sistemáticamente estrategias de selección de modelo para CATE y es la referencia empírica más útil para decidir con qué métrica quedarse. Para Qini, @radcliffe2007using. #cite(<vanderweele2017evalue>, form: "prose") es la referencia del E-value (@sec-cap14_evalue) y contiene las tablas de conversión de escala necesarias para aplicarlo fuera de razones de riesgo. #cite(<thornton2008demand>, form: "prose") documenta el experimento aleatorizado usado como banco de pruebas con identificación no discutida. Sobre el versionado del proceso de evaluación de la @sec-cap14_evaluacion_offline, véase @huyen2022dmls, Capítulo 6.
