// Capítulo 21: Aprendizaje de políticas óptimas (Policy Learning)
// Edición en capas: la teoría (L0), los algoritmos en pseudocódigo (L1) y los casos canónicos (L2) son lo que dura;
// los listados (L3) y los ejercicios computacionales van dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Aprendizaje de políticas óptimas]
<cap-policy-learning>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Aprender una regla de asignación óptima bajo restricciones presupuestarias y de equidad],
    [*Estimando:*], [Valor de la política $V(pi)$, _welfare regret_],
    [*Identificación:*], [No confusión, SUTVA, soporte común],
    [*Método:*], [Árbol de política, estimación doblemente robusta del valor],
    [*Nuisance:*], [$mu_(d)(x)$, $e_(d)(x)$, CATE $tau(x)$],
    [*Garantía:*], [Regret $O_(p)(sqrt("VC"(Pi) \/ n))$ sobre una clase $Pi$ de VC-dimensión finita (Kitagawa y Tetenov, 2018; extendido a _nuisance_ estimados por ML en Athey y Wager, 2021)],
    ..if not es-principios {([*Librerías:*], [#code[econml.policy]])},
    [*Validación:*], [_Hold-out_, _cross-fitting_, valor doblemente robusto con intervalo],
  )
]

#notatecnica[
Con la Parte IV completa, el estimador causal ya se puede publicar y operar en producción (@cap-model-card-causal y @cap-cicd-causal). Este capítulo abre la Parte V y cambia la pregunta: hasta ahora el libro estimó *cuánto* efecto tiene un tratamiento; desde aquí, la pregunta es *a quién* asignarlo, reutilizando el CATE de los meta-learners y los bosques causales (@cap-meta-learners y @cap-causal-forests) como insumo de una regla de decisión.
]

== Motivación aplicada
<sec-cap21-motivacion>

Un ministerio debe decidir a qué hogares ofrecer un programa de capacitación laboral. El programa es costoso (1~000 dólares por hogar) y solo puede cubrir al 30 % de la población. El CATE estimado varía ampliamente: en algunos hogares el efecto sobre ingresos es de 2~500 dólares y en otros es cercano a cero. La pregunta de política es: _dada una restricción presupuestaria, ¿qué regla de asignación maximiza el bienestar agregado?_

Este es el problema de _policy learning_: encontrar una regla $pi: cal(X) -> {0, 1}$ que maximice el _valor de la política_ $V(pi) = E[Y(pi(X))]$ sujeto a restricciones presupuestarias o de equidad. #cite(<kitagawa2018should>, form: "prose") y #cite(<athey2021policy>, form: "prose") desarrollaron el marco formal, mostrando que bajo no confusión se puede aprender la política óptima con garantías de _welfare regret_.

Este capítulo desarrolla la teoría del policy learning, muestra con tres casos de resultado conocido cómo se comporta el valor de una política frente al presupuesto y cómo se evalúa con inferencia válida, y discute las extensiones a restricciones presupuestarias y de equidad.

== Teoría, supuestos y garantías
<sec-cap21-teoria>

=== Valor de una política y _welfare regret_
<sec-cap21-policy-value>

Con $mu_(d)(x) = E[Y | X = x, D = d]$ y $tau(x) = mu_1(x) - mu_0(x)$, el valor de una regla $pi$ es
$
V(pi) = E[Y(pi(X))] = E[pi(X) mu_1(X) + (1 - pi(X)) mu_0(X)] = E[mu_0(X) + pi(X) tau(X)].
$

Como $E[mu_0(X)]$ no depende de $pi$, comparar políticas equivale a comparar el _valor incremental_ $tilde(V)(pi) = V(pi) - V(0) = E[pi(X) tau(X)]$, el valor respecto de no tratar a nadie. La política óptima es
$
pi^*(x) = bold(1){tau(x) > 0},
$
y el _welfare regret_ mide cuánto pierde una regla $hat(pi)$ respecto de la óptima:
$
"Regret"(hat(pi)) = V(pi^*) - V(hat(pi)) = E[(pi^*(X) - hat(pi)(X)) tau(X)].
$

=== Estimación del valor de la política
<sec-cap21-estimacion>

Bajo no confusión, $V(pi)$ es identificable también a partir de datos observacionales. Con $e_(d)(x) = P(D = d | X = x)$, el estimador _doubly robust_ es
$
hat(V)(pi) = (1 / n) sum_i [ hat(mu)_(pi(X_i))(X_i) + (bold(1){D_i = pi(X_i)}) / (hat(e)_(pi(X_i))(X_i)) (Y_i - hat(mu)_(pi(X_i))(X_i)) ].
$ <eq-policy-value-dr>
Restando el mismo estimador para $pi = 0$ se obtiene la forma que usan los algoritmos de este capítulo, $hat(tilde(V))(pi) = (1 \/ n) sum_i pi(X_i) hat(Gamma)_i$, donde $hat(Gamma)_i$ es el _score_ doblemente robusto del CATE (el mismo $Gamma_i$ del DR-learner del @cap-meta-learners):
$
hat(Gamma)_i = hat(mu)_1(X_i) - hat(mu)_0(X_i) + D_i (Y_i - hat(mu)_1(X_i)) / hat(e)_1(X_i) - (1 - D_i) (Y_i - hat(mu)_0(X_i)) / hat(e)_0(X_i).
$ <eq-gamma-policy>

Conviene separar con cuidado dos resultados que se citan a menudo de forma intercambiable, porque responden preguntas distintas y sus supuestos no son los mismos. El primero es la inferencia sobre el valor de una política dada; el segundo, la garantía de regret de una política aprendida.

#proposition(name: [Inferencia sobre el valor de una política fija])[
  Sea $pi$ una regla fija, o aprendida con una muestra independiente de la que se usa para evaluarla. Bajo no confusión, soporte común y _nuisance_ estimados por _cross-fitting_ a tasas que cumplen la condición de producto, la _efficient influence function_ de $V(pi)$ es
  $
  psi_pi (W) = mu_(pi(X))(X) + (bold(1){D = pi(X)}) / (e_(pi(X))(X)) dot.op (Y - mu_(pi(X))(X)) - V(pi),
  $
  caso particular de la forma canónica de la Nota técnica #ref(<sec-cap10_teorema_dml>, supplement: none). Por tanto
  $
  sqrt(n) (hat(V)(pi) - V(pi)) arrow.r^(d) cal(N)(0, E[psi_pi^2]),
  $
  y para comparar dos políticas $pi_A, pi_B$ sobre las mismas observaciones, la diferencia $hat(V)(pi_A) - hat(V)(pi_B)$ es asintóticamente normal con varianza $E[(psi_(pi_A) - psi_(pi_B))^2] \/ n$, de modo que el estadístico
  $
  z = (hat(V)(pi_A) - hat(V)(pi_B)) / (hat(sigma)_(A B) \/ sqrt(n)), quad hat(sigma)_(A B)^2 = "Var"_n (hat(psi)_(pi_A) - hat(psi)_(pi_B)),
  $
  se compara con una normal estándar, donde $hat(psi)_pi$ es la función de influencia estimada de cada política sobre cada observación.
] <prop-policy-value-inference>

La condición de que $pi$ sea fija o independiente de la muestra de evaluación es esencial. Si $hat(pi)$ se aprendió con las mismas observaciones que se usan para estimar su valor, el estimador sufre la misma maldición del ganador que el árbol sin honestidad del @cap-causal-forests: la regla fue elegida justamente por rendir bien en esa muestra. Por eso la evaluación se hace en un _hold-out_ y la comparación de dos reglas, con el estadístico anterior sobre el mismo _hold-out_; reportar _welfare_ puntuales sin ese test no permite decir cuál de dos políticas es mejor.

=== Garantías de aprendizaje
<sec-cap21-garantias>

El teorema de *regret óptimo* $O_p (n^(-1\/2))$ para clases de políticas con VC-dimensión finita se debe a #cite(<kitagawa2018should>, form: "prose"). Los métodos basados en GRF para policy learning @athey2021policy implementan esta teoría mediante árboles de decisión honestos.

#theorem(name: [Kitagawa y Tetenov, 2018: maximización del bienestar empírico])[
  Sea $Pi$ una clase de políticas con VC-dimensión finita $"VC"(Pi)$, y sea
  $
  hat(pi)_"EWM" = op("argmax", limits: #true)_(pi in Pi) hat(V)(pi)
  $
  el maximizador del _welfare_ empírico, con propensión conocida o estimada a tasa paramétrica. Bajo soporte común acotado ($e(x) in [underline(e), 1 - underline(e)]$) y resultados acotados, el _regret_ respecto de la mejor política *dentro de la clase* satisface
  $
  E[max_(pi in Pi) V(pi) - V(hat(pi)_"EWM")] = O(sqrt("VC"(Pi) \/ n)),
  $
  y esta tasa es minimax-óptima sobre la clase.
] <thm-ewm>

Dos precisiones sobre este enunciado, ambas importantes en la práctica. Primera: el regret se mide contra $max_(pi in Pi) V(pi)$, la mejor política *de la clase*, no contra la política óptima sin restricciones $pi^*(x) = bold(1){tau(x) > 0}$. La diferencia entre ambas, el *error de aproximación* de la clase, no desaparece con más datos y es el precio de exigir reglas interpretables. Segunda: la garantía no requiere estimar bien el CATE. La maximización empírica optimiza directamente el _welfare_ y puede producir una política casi óptima aunque $hat(tau)$ sea un estimador mediocre, lo que explica por qué "el CATE tiene RMSE alto" y "la política es buena" no son afirmaciones contradictorias.

El resultado de #cite(<athey2021policy>, form: "prose") extiende este marco al caso que interesa a este libro: cuando $hat(V)$ se construye con _nuisance_ ($hat(mu)_d$, $hat(e)$) estimados con _machine learning_ en vez de conocidos.

#theorem(name: [Athey y Wager, 2021: policy learning con nuisance estimados])[
  Si $hat(pi)$ maximiza el estimador doblemente robusto @eq-policy-value-dr sobre una clase $Pi$ de VC-dimensión finita, con _nuisance_ estimados por _cross-fitting_ a tasas que satisfacen la condición de producto $sqrt(n) a_n^2 -> 0$, entonces el regret respecto de la mejor política de la clase conserva la tasa $O_(p)(sqrt("VC"(Pi) \/ n))$: el error de estimación de los _nuisance_ entra solo a segundo orden.
] <thm-policy-learning>

La estructura del argumento es la misma que la del @cap-ortogonalidad (ortogonalidad más _cross-fitting_ hacen que el error de los _nuisance_ sea de segundo orden), aplicada ahora a un problema de optimización sobre una clase de funciones en lugar de a la estimación de un escalar. Ese es el aporte específico de Athey y Wager; la garantía de regret con clases de VC-dimensión finita es de Kitagawa y Tetenov.

=== Evaluación de políticas con datos históricos
<sec-cap21-evaluacion>

#intuicion[
  *Caja de profundización: evaluación de políticas con datos históricos*

  *Objetivo.* Estimar cuánto valdría una política sin tener que implementarla.

  *El problema.* Hay una política $pi(x)$ que decide a quién tratar. Se quiere su valor esperado $V(pi) = E[Y(pi(X))]$, pero solo se observa $Y$ bajo la política original, no bajo la nueva.

  *Tres formas de estimar $V(pi)$ sin implementar la política:*
  - *IPS (_Inverse Propensity Scoring_):* cada observación cuenta solo si lo que recibió coincide con lo que la nueva política le habría asignado, y se pondera por $1 \/ e_(D_i)(X_i)$, la inversa de la probabilidad de haber recibido eso.
  - *SNIPS (_Self-Normalized IPS_):* igual que IPS pero normalizando los pesos para mayor estabilidad.
  - *DR (_Doubly Robust_):* combina la predicción directa con IPS. Si el modelo de resultado o el propensity es correcto, el estimador es consistente.

  *Precaución.* Si la nueva política trata a personas muy diferentes de las que fueron tratadas originalmente (poco solapamiento), los pesos explotan y los estimadores IPS y DR se vuelven inestables. Es una extrapolación.
]

=== Restricciones presupuestarias
<sec-cap21-restricciones>

Si la restricción es tratar a lo más a una fracción $beta$ de la población, la política óptima es
$
pi^*_("budget")(x) = bold(1){tau(x) > c}, quad c = max(q_(1-beta), 0),
$
donde $q_(1-beta)$ es el cuantil $1 - beta$ de $tau(X)$. Se trata a quienes están en el $beta$ superior de $tau$, pero nunca a quien tiene $tau <= 0$: si menos de una fracción $beta$ de la población se beneficia, el presupuesto no se agota. El umbral $c$ es el precio sombra del presupuesto: la regla trata a quien devuelve más que $c$ por unidad tratada, el mismo costo sombra $lambda$ de la asignación por _net score_ del @cap-uplift-targeting. Cuando el presupuesto no ata, $c = 0$ y se recupera $pi^*$.

#caso-canonico("Valor de la política frente al presupuesto")[
  Cinco covariables normales estándar, $tau(X) = 1 + 2 X_0 + X_1$ (media 1, desviación típica $sqrt(5) approx 2.24$), resultado sin tratamiento $X_2$, ruido normal estándar y asignación aleatoria. Con orden perfecto, tratar a la fracción $beta$ de mayor $tau$ rinde $V(beta) = beta mu + sigma phi(Phi^(-1)(1 - beta))$, con $mu = 1$, $sigma = sqrt(5)$, $Phi$ la normal estándar y $phi$ su densidad.

  #table(
    columns: (3.4fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Política*], [*30 %*], [*50 %*], [*100 %*]),
    table.hline(stroke: 0.3pt),
    [Orden perfecto con piso ($tau$ conocido)], [1,077], [1,392], [1,480],
    [Orden estimado con piso (T-learner, 3~000)], [1,067], [1,381], [1,469],
    [Al azar con la misma fracción], [0,300], [0,500], [1,000],
    table.hline(stroke: 0.6pt),
  )
]

Tratar a todos rinde 1,000 (el efecto medio). Con el 30 % de presupuesto, el _targeting_ rinde 3,6 veces lo que rinde tratar al azar la misma fracción, y con una señal fuerte y 3~000 unidades de entrenamiento el orden estimado casi coincide con el perfecto (1,067 frente a 1,077; desviación típica entre repeticiones de 0,008). La curva crece hasta $beta^* = P(tau > 0) = 0,67$ y se aplana en $E[tau^+] = 1,48$, porque el piso en cero impide seguir tratando a quien perjudica. Dos lecturas se desprenden. Primera, la ventaja sobre "tratar a todos" depende del presupuesto: con una fracción menor que aproximadamente 0,27 el valor del _targeting_ queda por debajo de 1,00, el de tratar a todos, referente que un presupuesto tan escaso no permite alcanzar; y el valor máximo, $E[tau^+] = 1,48$, supera a tratar a todos porque trata solo a quien se beneficia. Segunda, con una señal débil o una muestra pequeña la brecha entre el orden estimado y el perfecto crece, y esa brecha es lo que el _regret_ mide.

La figura #ref(<fig-cap21-policy-value>, supplement: none) muestra las cuatro curvas del caso canónico.

#figure(
  image("../figuras/fig_cap21_policy_value.png", width: 85%),
  caption: [Elaboración propia. Valor de la política frente al presupuesto en el caso canónico. Verde discontinua: orden perfecto con piso en cero. Azul: orden por CATE estimado (T-learner), con banda de una desviación típica entre 20 repeticiones. Gris punteada: tratamiento al azar de la misma fracción. Roja punteada: tratar a todos. La línea vertical marca el presupuesto del 30 %. El script que genera la figura está en el material de verificación.],
) <fig-cap21-policy-value>

*Una advertencia sobre la forma de la curva.* Que el _targeting_ domine al tratamiento aleatorio en todo el rango de presupuesto no es un hallazgo empírico sino una consecuencia mecánica de que $hat(tau)$ ordene mejor que el azar; una curva así no valida nada por sí sola. Lo informativo es lo contrario: si la curva de _targeting_ *no* se separa de la aleatoria, la conclusión correcta es que no hay heterogeneidad accionable, y la política óptima es tratar a todos o a nadie según el signo del ATE. Es un resultado perfectamente respetable que el _baseline_ de efecto constante del @cap-validacion está diseñado para detectar antes de invertir en un sistema de _targeting_ que no aporta valor.

#caso-canonico("Un piso en cero")[
  Mismas covariables, pero con $tau(X) = 2 X_0 + X_1 - 1.5$, de modo que solo el 24,6 % de la población se beneficia, y un presupuesto del 30 %. Con 3~000 unidades, 50 repeticiones y el mismo CATE estimado para las dos reglas, tratar al 30 % superior a secas, aunque el 5 % de esos tengan efecto estimado negativo, rinde 0,309, mientras que tratar solo a quien tiene CATE estimado positivo (el 24,8 % de la población) rinde 0,319. El umbral $max(q_(0.70), 0)$ evita gastar presupuesto donde el efecto es negativo; ignorar ese piso cuesta _welfare_ en cuanto el presupuesto supera a la fracción que se beneficia.
]

== Algoritmo: árbol de política con presupuesto
<sec-cap21-algoritmo>

Una política de la clase de árboles de profundidad acotada se aprende maximizando el valor incremental empírico, no ajustando un árbol de regresión a los CATE estimados: la regla de cada hoja es tratar si el promedio de los _scores_ $hat(Gamma)_i$ de la hoja supera el precio $c$, y el árbol se elige para maximizar la suma de esas ganancias.

#algorithm("Árbol de política con restricción presupuestaria")[
  #kwin[Entrada][Datos $(X_i, hat(Gamma)_i)_(i=1)^n$ con $hat(Gamma)_i$ de la @eq-gamma-policy estimados por _cross-fitting_, presupuesto $beta in (0, 1)$, profundidad máxima $d_"max"$, tamaño mínimo de hoja $n_"min"$, tolerancia $delta$.]
  #kwout[Salida][Regla $hat(pi): cal(X) -> {0, 1}$ que trata a lo sumo una fracción $beta$ y maximiza el valor incremental estimado.]
  Dada un precio $c >= 0$, construir el árbol $cal(T)_c$ de profundidad a lo sumo $d_"max"$ y hojas de al menos $n_"min"$ unidades que maximice $sum_m max(0, sum_(i in cal(L)_m) (hat(Gamma)_i - c))$, y fijar $hat(pi)_c (x) = bold(1){sum_(i in cal(L)_m) (hat(Gamma)_i - c) > 0}$ para $x in cal(L)_m$. \
  *if* la fracción tratada por $hat(pi)_0$ es a lo sumo $beta$ *then* #return-stmt[$hat(pi)_0$ (el presupuesto no ata).] \
  $c_"min" <- 0$, $c_"max" <- max_i hat(Gamma)_i$ (con $c_"max"$ nadie recibe tratamiento). \
  *repeat* #h(2pt) hasta $c_"max" - c_"min" < delta$: \
  #h(1.5em) $c <- (c_"min" + c_"max") / 2$ y construir $hat(pi)_c$ \
  #h(1.5em) *if* #h(2pt) la fracción tratada por $hat(pi)_c$ supera $beta$ *then* #h(2pt) $c_"min" <- c$ \
  #h(1.5em) *else* #h(2pt) guardar $hat(pi)_c$ y $c_"max" <- c$ \
  Estimar $hat(V)(hat(pi))$ y su intervalo con la proposición de la @sec-cap21-estimacion en una muestra _hold-out_ distinta. \
  #return-stmt[la mejor regla factible guardada.]
] <alg-policy-tree-budget>

La bisección es válida porque la fracción tratada no crece con $c$. Como con las asignaciones por _net score_, el tratamiento cambia a saltos con el precio, de modo que la regla factible puede dejar sin usar una pequeña parte del presupuesto. Con una clase de árboles de profundidad 2 o 3 la búsqueda de la partición óptima es exhaustiva y exacta para unas decenas de covariables, y es lo que hace que el árbol de política sea una herramienta aplicable.

#caso-canonico("Un intervalo centrado en lo que se estima")[
  Con el DGP del primer caso, 3~000 unidades, un árbol de política de profundidad 3 aprendido en el 70 % de la muestra y evaluado en el 30 % restante, se construye el intervalo de la proposición de la @sec-cap21-estimacion con la estimación doblemente robusta como centro. En 200 repeticiones, contiene el _welfare_ verdadero de la política el 99 % de las veces, algo por encima del 95 % nominal, con un sesgo medio de la estimación de 0,0002. El exceso se explica porque el valor "verdadero" se calcula como un promedio sobre la misma muestra de evaluación, con la que el estimador comparte buena parte de la variación. Un intervalo centrado en el valor verdadero, en cambio, cubriría el 100 % por construcción, y por eso mismo no informaría nada: la variabilidad se mide en torno de lo que se estima, no de lo que se quiere recuperar.
]

#capa-impl[
== Implementación en Python
<sec-cap21-implementacion>

=== Policy learning con econml
<sec-cap21-policy-econml>

#advertencia[
*Este listado es sintético, no aplicado.* El código toma las covariables numéricas del dataset #code[gov_transfers] pero *simula* el tratamiento y el resultado a partir de un CATE conocido. Esa elección es deliberada y tiene una razón metodológica, no de conveniencia: el objetivo aquí es evaluar el _policy learning_ comparando la política aprendida contra el _welfare_ verdadero, y ese contraste solo es posible cuando $tau(x)$ se conoce por construcción. Con datos reales no existe _ground truth_ del CATE (@cap-validacion) y lo único que puede reportarse es un valor estimado, no un regret. Léase, pues, como una verificación de que el procedimiento recupera la política correcta cuando *sabemos* cuál es, y no como evidencia sobre el efecto real de las transferencias gubernamentales.
]

#figure(
  kind: raw,
  caption: [Policy learning con evaluación hold-out sobre un DGP sintético (covariables reales de `gov_transfers`, tratamiento y resultado simulados).],
  ```python
import numpy as np
import pandas as pd
from econml.dml import CausalForestDML
from econml.policy import PolicyTree, PolicyForest
from sklearn.ensemble import GradientBoostingRegressor, GradientBoostingClassifier
from sklearn.model_selection import train_test_split

# --- DGP SINTETICO -------------------------------------------------
# Las covariables X son reales (gov_transfers); D, tau e Y se SIMULAN
# para disponer del CATE verdadero y poder medir el regret.
df = pd.read_csv("../data/datasets/real/public_causaldata/gov_transfers/data.csv")
rng = np.random.default_rng(42)
n = len(df)
X = df.select_dtypes(include=[np.number]).dropna(axis=1).values[:n]
X = X[:, :10]  # limitar a 10 features
D = rng.binomial(1, 0.5, n)          # asignacion aleatoria SIMULADA
tau_true = 2 * X[:, 0] + X[:, 1]     # CATE verdadero SIMULADO
Y = X[:, 2] + D * tau_true + rng.standard_normal(n)
# -------------------------------------------------------------------

# Separar muestra hold-out
X_train, X_test, Y_train, Y_test, D_train, D_test, tau_train, tau_test = train_test_split(
    X, Y, D, tau_true, test_size=0.3, random_state=42
)

# Paso 1: estimar CATE en train
cf = CausalForestDML(
    model_y=GradientBoostingRegressor(n_estimators=200, random_state=42),
    model_t=GradientBoostingClassifier(n_estimators=200, random_state=42),
    discrete_treatment=True,
    n_estimators=400,
    min_samples_leaf=20,
    cv=5,
    random_state=42
).fit(Y_train, D_train, X=X_train)

# Paso 2: aprender politica en train
policy = PolicyTree(max_depth=3, min_samples_leaf=50, random_state=42)
policy.fit(X_train, cf.effect(X_train))

# Paso 3: evaluar la politica en test (hold-out)
pi_test = policy.predict(X_test)

# Evaluacion con ground truth sintetico
welfare_test = tau_test[pi_test == 1].mean() * pi_test.mean()

print(f"Welfare en hold-out (tau verdadero simulado): {welfare_test:.4f}")
print(f"Fraccion tratada en hold-out: {pi_test.mean():.3f}")

# Paso 4: estimar el welfare incremental en hold-out, con IC via influence function.
# welfare_test usa el tau verdadero del DGP: es el valor que se quiere recuperar, y solo
# existe porque los datos son sinteticos. Con datos reales solo se dispone de la estimacion
# doblemente robusta (v_hat), y el IC debe centrarse en ella, no en welfare_test.
# cf.effect() da tau_hat, NO mu_1(X): hacen falta mu_1 y mu_0 por separado (T-learner)
# para construir el score doblemente robusto. No se puede aproximar con tau_hat solo.
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import GradientBoostingRegressor as GBR_mu

e_hat = LogisticRegression(max_iter=1000).fit(X_train, D_train).predict_proba(X_test)[:, 1]
mu1_hat = GBR_mu(random_state=42).fit(X_train[D_train == 1], Y_train[D_train == 1]).predict(X_test)
mu0_hat = GBR_mu(random_state=42).fit(X_train[D_train == 0], Y_train[D_train == 0]).predict(X_test)
pi = pi_test.astype(int)

# Score IRM (forma canonica del Cap. 10, fila "ATE bajo IRM"), ponderado por pi(X):
# es el integrando doblemente robusto de V_tilde(pi) = E[pi(X) tau(X)].
score_irm = ((mu1_hat - mu0_hat)
             + D_test * (Y_test - mu1_hat) / np.clip(e_hat, 0.01, 0.99)
             - (1 - D_test) * (Y_test - mu0_hat) / np.clip(1 - e_hat, 0.01, 0.99))
v_hat = np.mean(pi * score_irm)
psi_pi = pi * score_irm - v_hat
se_pi = psi_pi.std(ddof=1) / np.sqrt(len(Y_test))
print(f"Welfare DR en hold-out: {v_hat:.4f}  IC 95%: [{v_hat - 1.96 * se_pi:.4f}, {v_hat + 1.96 * se_pi:.4f}]")
print(f"Welfare verdadero (solo por ser sintetico): {welfare_test:.4f}")
```
) <lst-policy-learning>

El intervalo se centra en la estimación doblemente robusta y no en el _welfare_ calculado con el CATE verdadero. En una simulación de verificación con 200 repeticiones (semillas 0 a 199), el intervalo así construido contuvo el _welfare_ verdadero el 99 % de las veces y la estimación quedó centrada (sesgo medio de 0,0002). El código está en #code[herramientas/verificaciones/verif_cap21.py], que reemplaza #code[CausalForestDML] y #code[PolicyTree] por equivalentes de scikit-learn (un T-learner con #code[GradientBoostingRegressor] y un árbol de regresión sobre $hat(tau)$), porque EconML no está en el entorno de verificación. El listado entrena el #code[PolicyTree] con $hat(tau)$ como recompensa del tratamiento (una versión de plug-in); la versión doblemente robusta del algoritmo usa los $hat(Gamma)_i$ en lugar de $hat(tau)_i$. La figura y la tabla del caso canónico salen de #code[herramientas/figuras/fig_cap21_policy_value.py].

=== Restricción presupuestaria
<sec-cap21-budget-python>

#figure(
  kind: raw,
  caption: [Policy learning con restricción presupuestaria.],
  ```python
# Restriccion: tratar como maximo al 30 % con mayor CATE, y solo a quien se beneficia.
# cf y el hold-out (X_test, tau_test) vienen del listado anterior.
cate = cf.effect(X_test)
umbral = max(np.quantile(cate, 0.70), 0.0)   # top 30 %, pero nunca con efecto estimado <= 0
pi_budget = (cate > umbral).astype(int)
welfare_budget = np.mean(pi_budget * tau_test)   # tau verdadero: solo por ser sintetico
print(f"Fraccion tratada: {pi_budget.mean():.3f} (tope 0.30)")
print(f"Welfare con restriccion presupuestaria (30%): {welfare_budget:.4f}")
print(f"Welfare de tratar a todos: {tau_test.mean():.4f}")
print("Welfare de no tratar a nadie: 0.0")
```
) <lst-budget-policy>
]

== Riesgos, límites y sensibilidad
<sec-cap21-riesgos>

#riesgos[
  #set text(size: 9pt)
  #figure(
    caption: [Riesgos comunes en policy learning.],
    table(
      columns: (1.3fr, 1.5fr, 1.5fr, 1.8fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Evaluar en la muestra de aprendizaje], [Valor optimista (maldición del ganador): la regla se eligió por rendir bien ahí], [Comparar el valor dentro y fuera de muestra], [Evaluar en un _hold-out_ y con _cross-fitting_; intervalo centrado en la estimación (proposición de la @sec-cap21-estimacion)],
      table.hline(stroke: 0.4pt),
      [Comparar políticas sin test], [Declarar mejor a una regla por una diferencia de ruido], [Estadístico $z$ sobre el mismo _hold-out_], [Reportar el valor de cada regla con su intervalo y el del diferencial],
      table.hline(stroke: 0.4pt),
      [Omitir el piso en cero], [Se gasta presupuesto en quien tiene efecto negativo (0,309 frente a 0,319 en el caso canónico)], [Fracción tratada frente a fracción con CATE estimado positivo], [Umbral $c = max(q_(1-beta), 0)$],
      table.hline(stroke: 0.4pt),
      [Ignorar equidad], [Exclusión sistemática de grupos minoritarios], [Auditar la distribución demográfica de los tratados], [Imponer restricciones de paridad demográfica o _equalized CATE_ (@cap-etica-interpretabilidad)],
      table.hline(stroke: 0.4pt),
      [CATE mal calibrado], [Política subóptima (umbral de tratamiento incorrecto)], [Gráfico de calibración: $hat(tau)(x)$ frente a resultados observados], [DR-learner o bosque causal con _cross-fitting_; recalibrar],
      table.hline(stroke: 0.4pt),
      [Solape débil], [Pesos $1 \/ hat(e)$ extremos en el score $hat(Gamma)$; árbol que sigue el ruido], [Distribución de $hat(e)$ y de los pesos], [Recorte de $hat(e)$, restringir la política al soporte común],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cap21>
]

*Límites.* Policy learning requiere no confusión. Si hay variables confusoras no observadas, la política aprendida puede estar sesgada. Además, las garantías de regret son asintóticas y relativas a la mejor política de la clase; con muestras pequeñas, la política aprendida puede estar lejos de la óptima, y con una clase demasiado simple el error de aproximación domina.

== Ejercicios propuestos
<sec-cap21-ejercicios>

=== Ejercicios teóricos

+ Muestre que $hat(V)(pi) - hat(V)(0) = (1 \/ n) sum_i pi(X_i) hat(Gamma)_i$ con $hat(Gamma)_i$ de la @eq-gamma-policy, a partir de la @eq-policy-value-dr.

+ Con $tau tilde cal(N)(mu, sigma^2)$ y orden perfecto, deduzca la fórmula $V(beta) = beta mu + sigma phi(Phi^(-1)(1 - beta))$ del caso canónico para $beta$ menor o igual que $P(tau > 0)$. Calcule $V(0.3)$ con $mu = 1$ y $sigma = sqrt(5)$, el $beta^*$ y el máximo $E[tau^+]$, y compárelos con la tabla.

+ Con un presupuesto $beta$ mayor que $P(tau > 0)$, ¿por qué la política óptima trata solo a $P(tau > 0)$ de la población? Relacione el precio $c$ del algoritmo con el costo sombra de la asignación por _net score_ (@cap-uplift-targeting).

+ Explique por qué evaluar una política en la misma muestra con la que se aprendió sobreestima su valor, y por qué el intervalo de la proposición de la @sec-cap21-estimacion deja de ser válido en ese caso.

+ Dé un ejemplo de $tau(x)$ para el cual la mejor política de la clase de árboles de profundidad 1 tenga un error de aproximación grande frente a $pi^*$, y explique por qué más datos no lo reducen.

+ Discuta: ¿cómo modificaría el algoritmo para imponer _equalized CATE_ entre dos grupos demográficos?

#capa-impl[
=== Ejercicios computacionales

+ Replique el #ref(<lst-policy-learning>, supplement: [listado]) sobre #code[nsw_mixtape]. ¿Qué regla de política se aprende, y con qué intervalo de su valor?

+ Compare tres políticas: (a) tratar a todos, (b) tratar al azar al 30 %, (c) tratar al top 30 % por CATE estimado. ¿En cuánto mejora el _welfare_? Repita con el estadístico $z$ de la proposición de la @sec-cap21-estimacion.

+ Construya un DGP donde la política óptima trate solo a un subgrupo pequeño. Verifique que el policy learning lo identifica.
]

== Lecturas complementarias
<sec-cap21-lecturas>

#cite(<kitagawa2018should>, form: "prose") introducen la _Empirical Welfare Maximization_ y la cota de regret sobre clases de VC-dimensión finita; #cite(<athey2021policy>, form: "prose") la extienden al caso con _nuisance_ estimados por ML mediante el _score_ doblemente robusto, que es la versión usada en este capítulo. Leer ambos en ese orden evita la confusión de atribución más común en la literatura aplicada. #cite(<zhang2012estimating>, form: "prose") es un precursor importante por la vía de reformular la elección de política como un problema de clasificación ponderada. Para policy learning bajo restricciones presupuestarias, de equidad o de forma de la regla, #cite(<kitagawa2021constrained>, form: "prose") tratan el caso general de clasificación restringida, y el @cap-etica-interpretabilidad retoma el _trade-off_ entre _welfare_ y equidad que de ahí se sigue. La conexión con la teoría de la decisión estadística, con policy learning como caso particular de reglas de tratamiento bajo identificación parcial, se desarrolla en el @cap-decisiones-estructurales.
