// Capítulo 22: Uplift modeling y targeting económico
// Edición en capas: la teoría (L0), los algoritmos en pseudocódigo (L1) y los casos canónicos (L2) son lo que dura;
// los listados (L3), el detalle de la réplica y los ejercicios computacionales van dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Uplift modeling y targeting económico]
<cap-uplift-targeting>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Asignación óptima de tratamientos con costos diferenciales y presupuesto],
    [*Estimando:*], [CATE por tratamiento $tau_(k)(x)$, valor de la política $V(pi)$],
    [*Identificación:*], [No confusión condicional y soporte común (o asignación aleatorizada)],
    [*Método:*], [Uplift modeling, asignación por _net score_, curvas Qini],
    [*Nuisance:*], [$hat(mu)_(k)(x)$, $hat(e)_(k)(x)$, costos $c_k$],
    [*Garantía:*], [Ranking evaluado fuera de muestra con intervalos por _bootstrap_; magnitud verificada con el _transformed outcome_],
    ..if not es-principios {([*Librerías:*], [causalml, econml])},
    [*Validación:*], [Curva Qini, AUUC, análisis de costo-efectividad],
  )
]

#notatecnica[
El @cap-policy-learning formalizó la política óptima como problema de decisión restringido; este capítulo cierra la Parte V con la práctica de *targeting* de marketing y programas sociales, y con las mismas curvas Qini ya usadas para validación en el @cap-validacion, ahora como criterio de evaluación de la política y no solo del estimador.
]

== Motivación aplicada
<sec-cap22_motivacion>

Una empresa de telecomunicaciones quiere reducir la _churn_ (baja de clientes). Dispone de tres acciones: (a) no hacer nada, (b) enviar un SMS con descuento, (c) llamar por teléfono con una oferta personalizada. El costo de cada acción es distinto: el SMS cuesta 0,5 dólares y la llamada 8. El efecto sobre la retención varía por cliente. La pregunta de política es a qué clientes aplicar cada acción, sujeto a un presupuesto total de 100~000 dólares.

El _uplift modeling_ es el análogo del policy learning en contextos de marketing. La métrica clave es el _uplift_: la diferencia en la probabilidad de conversión (o retención) entre recibir y no recibir el tratamiento. Los métodos se desarrollaron en la industria [@radcliffe2007using; @gutierrez2017causal] y se han integrado con la literatura académica de ML causal [@athey2021policy].

Este capítulo presenta los métodos clásicos de uplift, la evaluación por curvas Qini y la extensión a múltiples tratamientos y restricciones presupuestarias, con dos casos de resultado conocido: uno sobre por qué el ranking se evalúa fuera de muestra y otro sobre cómo se asigna un presupuesto entre dos acciones de costos muy distintos.

== Marco teórico formal
<sec-cap22_marco_teorico>

=== Uplift y CATE
<sec-cap22_uplift_cate>

El _uplift_ es matemáticamente equivalente al CATE:
$
"uplift"(x) = E[Y(1) - Y(0) | X = x] = tau(x).
$ <eq-uplift_cate>

La diferencia con el capítulo #ref(<cap-meta-learners>, supplement: none) es el foco aplicado: uplift modeling se pregunta por el _ranking_ (qué clientes tienen mayor uplift) y por la _cost-effectiveness_ (cuánto uplift se obtiene por dólar invertido), no solo por la estimación puntual del CATE.

Esa diferencia de foco tiene una consecuencia práctica que conviene fijar desde el principio, porque determina qué se puede y qué no se puede hacer con un modelo de uplift. Si la decisión es *a quién tratar con un presupuesto fijo*, basta con que el ranking sea correcto: la escala de $hat(tau)$ es irrelevante, y las métricas de ranking (Qini, AUUC) son el criterio adecuado. Si la decisión es *cuánto presupuesto asignar*, o *qué acción elegir entre varias con costos distintos*, el ranking no basta: hace falta que la *magnitud* de $hat(tau)$ esté bien calibrada, porque el punto de corte óptimo compara $tau_(k)(x)$ contra un costo $c_k$ medido en las mismas unidades. Un modelo puede tener un AUUC excelente y estar tan mal calibrado que la regla de asignación por _net score_ de la @sec-cap22_algoritmo gaste el doble de lo proyectado. Por eso este capítulo reporta siempre las dos cosas, ranking y calibración, y por eso el _transformed outcome_ del @cap-validacion, que sí da magnitudes insesgadas, reaparece aquí como diagnóstico obligatorio.

=== Qini y AUUC: teoría, supuestos y garantías
<sec-cap22_qini_auuc>

La curva Qini y el AUUC (_Area Under Uplift Curve_) son las métricas estándar para evaluar modelos de uplift en ausencia de _ground truth_ individual.

*Definición.* Sea $cal(D)$ una muestra con $n$ unidades, cada una con tratamiento $D_i in {0, 1}$ y resultado observado $Y_i$. Se ordenan las unidades por $hat(tau)(x_i)$ descendente. Para cada punto de corte $p in [0, 1]$, el uplift acumulado, en su versión ponderada por propensión, es
$
"uplift"(p) = (1 / n) sum_(i=1)^(floor(n p))
  (Y_i D_i / hat(e)(x_i) - (Y_i (1 - D_i)) / (1 - hat(e)(x_i))),
$ <eq-qini>
donde $hat(e)(x)$ es la propensión estimada (en un experimento es la fracción de tratados, constante). El AUUC integra esta curva sobre $p in [0, 1]$ y se normaliza respecto de una asignación aleatoria:
$
"AUUC" = integral_0^1 ("uplift"(p) - "uplift"_("aleatorio")(p)) dif p.
$ <eq-auuc>

*Supuestos.* La validez de la curva Qini y el AUUC requiere:
- *Inconfundibilidad:* $Y(1), Y(0) perp perp D | X$.
- *Soporte común:* $0 < e(x) < 1$ para todo $x$.
- *Propensity score correcto:* $hat(e)(x)$ es una estimación consistente de $e(x) = P(D = 1 | X = x)$.

Bajo estos supuestos, la @eq-qini estima de forma consistente el beneficio acumulado de tratar primero a las unidades que el modelo ordena arriba, $E[tau(X) bold(1){"rango"(X) <= p}]$. La curva *evalúa* un ordenamiento; no lo produce, y un modelo con un ordenamiento sin información da una curva sobre la diagonal.

*Lectura de la curva.* La pendiente de la curva en la posición $p$ es, por construcción, el uplift promedio de las unidades que ocupan esa posición: una curva que sube con fuerza al principio y se aplana o desciende al final indica que el modelo concentra el efecto en la cabeza del ranking y que tratar a todos rinde menos que tratar a los mejores. El AUUC es el análogo para uplift de la curva de Lorenz y el coeficiente de Gini, que #cite(<radcliffe2007using>, form: "prose") introduce y #cite(<gutierrez2017causal>, form: "prose") sitúan en la literatura de inferencia causal. En la práctica, curvas más arriba indican mejor capacidad de ranking, y con intervalos de confianza por _bootstrap_ sobre la muestra de evaluación es posible juzgar si las diferencias entre modelos superan el ruido.

*Uplift ponderado por costo.* Cuando los costos del tratamiento varían entre individuos, se pondera el uplift por el costo unitario:
$
"CW-uplift"(x) = (hat(tau)(x)) / (c(x)),
$ <eq-cw-uplift>
donde $c(x)$ es el costo del tratamiento para el cliente $x$. Esta métrica permite priorizar las acciones con mayor retorno por dólar invertido. Con una sola acción y un presupuesto, tratar por orden descendente de $hat(tau) \/ c$ es la solución del problema de la mochila fraccionaria, y por eso es el criterio natural; la regla de _net score_ de la sección siguiente lo contiene como caso particular.

#caso-canonico("El mismo modelo, dos evaluaciones")[
  Cinco mil clientes con ocho covariables uniformes en $[-1, 1]$, asignados al azar a control, SMS o llamada con probabilidades 0,4, 0,3 y 0,3. La retención basal es $0.45 + 0.08 x_2$ y los uplifts verdaderos son débiles, $tau_"SMS" = 0.06 - 0.05 x_0 + 0.03 x_1$ y $tau_"llamada" = 0.12 + 0.09 x_1 - 0.02 x_3$, de modo que las acciones difieren en unos pocos puntos porcentuales entre clientes. Se estima cada uplift con un T-learner de _gradient boosting_ (profundidad 3, 200 árboles) contra el brazo de control, y se calcula el área normalizada entre la curva Qini y la diagonal de dos maneras: dentro de muestra (modelo ajustado y evaluado sobre las 5~000 unidades) y en _hold-out_ (modelo ajustado sobre el 60 % y evaluado sobre el 40 % restante):

  #table(
    columns: (2fr, 1.2fr, 1.2fr),
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Acción*], [*Qini dentro de muestra*], [*Qini en _hold-out_*]),
    table.hline(stroke: 0.3pt),
    [SMS], [0,0755], [−0,0063],
    [Llamada], [0,0759], [−0,0068],
    table.hline(stroke: 0.6pt),
  )

  Dentro de la muestra de ajuste, el Qini es claramente positivo para las dos acciones, y fuera de ella es ligeramente negativo: el modelo ordena ruido, y la evaluación en la muestra de ajuste no lo delata. Con una heterogeneidad débil y un modelo flexible, el ranking aprendido es un artefacto de la muestra, y por eso el ranking se evalúa siempre en datos que el modelo no vio. Con una heterogeneidad marcada (uplifts que varían en decenas de puntos porcentuales), un modelo más suave y evaluación en _hold-out_, el Qini es positivo para las dos acciones y la correlación entre el uplift estimado y el verdadero es de 0,67 para el SMS y de 0,85 para la llamada; esa es la configuración del caso siguiente.
]

=== Multi-treatment uplift
<sec-cap22_multitreatment>

Cuando hay $K$ tratamientos posibles, el problema se extiende a estimar $tau_(k)(x) = E[Y(k) - Y(0) | X = x]$ para $k = 1, ..., K$. Sin restricción de presupuesto, la política óptima asigna a cada cliente la acción con mayor $v tau_(k)(x) - c_(k)(x)$, donde $v$ es el valor monetario del resultado (un cliente retenido) y $c_k$ el costo del tratamiento $k$, y no trata si el máximo no es positivo. El valor $v$ es lo que permite comparar una probabilidad con dólares; cuando no se conoce, el presupuesto es la única restricción y el costo sombra de la sección siguiente cumple su papel.

#intuicion[
  *Caja de profundización: _bootstrap_ para la curva Qini y _embeddings_ como covariables*

  *_Bootstrap_ para la curva Qini.* Una forma de comparar modelos de uplift con incertidumbre, con el modelo ya ajustado y sobre la muestra de evaluación:
  + Remuestrear la muestra de evaluación muchas veces (por ejemplo, 200).
  + Cada vez, recalcular la curva Qini y el AUUC de cada modelo.
  + Reportar el AUUC con su intervalo, y la diferencia entre modelos con el suyo.

  Esto evita confiar en un solo número que puede ser ruidoso.

  *_Embeddings_ como covariables.* Con texto, imágenes u otros datos no estructurados se pueden usar _embeddings_ (representaciones numéricas) como covariables $X$ para estimar el CATE. Un _embedding_ puede ser un proxy de variables sensibles como género o raza, de modo que su uso requiere la revisión de equidad que el @cap-explicacion-equidad desarrolla.
]

== Algoritmo: asignación por net score con presupuesto
<sec-cap22_algoritmo>

Resolver la asignación óptima de tratamientos con costos distintos y un presupuesto limitado requiere un enfoque de optimización. El método de _net score_ introduce un costo sombra $lambda$ que equilibra el beneficio marginal del tratamiento con su costo.

El problema formal: hay $K$ tratamientos con costos $c_k$ y un presupuesto $B$. Se quiere asignar a cada persona la acción que maximice el uplift neto (beneficio menos costo sombra) sin exceder $B$.

#algorithm("Asignación por net score con presupuesto")[
  #kwin[Entrada][$hat(tau)_(k)(x_i)$ para cada acción $k = 1, dots, K$ y cada unidad $i = 1, dots, N$; costos $c_k$; presupuesto $B$; precio de equilibrio $lambda_0 >= 0$ ($1 \/ v$ si se conoce el valor monetario $v$ del resultado, 0 si el presupuesto es la única restricción); tolerancia $delta$.]
  #kwout[Salida][Asignación $pi(x) in {0, 1, dots, K}$ que maximiza el uplift total sujeto a $sum_(i=1)^N c_(pi(x_i)) <= B$.]
  Para cada $lambda$, definir $pi_lambda (x) = "argmax"_k s_(k)(x)$ con $s_(k)(x) = hat(tau)_(k)(x) - lambda dot.c c_(k)$ y $s_0(x) = 0$ (no tratar), y $G(lambda) = sum_(i=1)^N c_(pi_lambda (x_i))$ su gasto. \
  *if* $G(lambda_0) <= B$ *then* #return-stmt[$pi_(lambda_0)$ (el presupuesto no ata).] \
  $lambda_"min" <- lambda_0$, $lambda_"max" <- max_(i,k) hat(tau)_(k)(x_i) \/ c_k$ (con $lambda_"max"$ nadie recibe tratamiento). \
  *repeat* #h(2pt) hasta $lambda_"max" - lambda_"min" < delta$: \
  #h(1.5em) $lambda <- (lambda_"min" + lambda_"max") / 2$ \
  #h(1.5em) *if* #h(2pt) $G(lambda) > B$ *then* #h(2pt) $lambda_"min" <- lambda$ \
  #h(1.5em) *else* #h(2pt) guardar $pi_lambda$ como mejor asignación factible y $lambda_"max" <- lambda$ \
  #return-stmt[la mejor asignación factible guardada.]
] <alg-net-score>

El parámetro $lambda$ es el multiplicador de Lagrange (costo sombra) de la restricción presupuestaria. Cuando $lambda = 0$, el algoritmo asigna según el uplift bruto; al aumentar $lambda$, se penalizan los tratamientos costosos, favoreciendo acciones más baratas. La bisección es válida porque el gasto $G(lambda)$ no crece con $lambda$ (a un precio mayor, ningún cliente pasa a una acción más cara), y converge al menor $lambda$ cuya asignación cabe en el presupuesto. Como el gasto cambia a saltos con $lambda$ (cada cliente pasa de una acción a otra de golpe), ese valor puede dejar sin usar una pequeña parte del presupuesto.

La solución de net score es equivalente a resolver
$
pi^*(x) = "argmax"_k { tau_(k)(x) - lambda^* c_(k)(x) },
$ <eq-net-score-opt>
donde $lambda^*$ es el costo sombra que agota el presupuesto $B$. Nótese que $lambda^*$ no es una penalización de regularización (como en LASSO), sino el precio implícito de relajar la restricción presupuestaria en una unidad. Con una sola acción, $tau(x) - lambda c >= 0$ equivale a $tau(x) \/ c >= lambda$, de modo que el net score trata a los clientes cuyo retorno por dólar supera el costo sombra: reproduce el orden de la mochila fraccionaria. Con varias acciones, compara entre sí las acciones de cada cliente. Con dos acciones de costos $c_s < c_l$, la acción cara se prefiere a la barata cuando $tau_l (x) - tau_s (x) > lambda (c_l - c_s)$, y a no tratar cuando $tau_l (x) > lambda c_l$: la acción cara solo se justifica donde su uplift adicional paga la diferencia de costo a precio $lambda$.

#caso-canonico("Un presupuesto entre dos acciones")[
  Mismos clientes y brazos, con heterogeneidad marcada: retención basal $0.40 + 0.08 x_2$, $tau_"SMS" = 0.06 - 0.16 x_0 + 0.08 x_1$ y $tau_"llamada" = 0.12 + 0.30 x_1 - 0.10 x_3$. El uplift de cada acción se estima contra el control con un T-learner suave (profundidad 2, 100 árboles) sobre el 60 % de la muestra y se evalúa en el _hold-out_ de 2~000 clientes. Costos de 0,5 y 8 dólares: tratar a todos con SMS cuesta 1~000 y llamar a todos, 16~000. Con un presupuesto de 4~000, el uplift total que las tres estrategias logran, medido con los efectos verdaderos (que solo se conocen porque los datos son sintéticos), es:

  #table(
    columns: (2.3fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Estrategia*], [*Gasto*], [*Tratados*], [*Uplift estimado*], [*Uplift verdadero*]),
    table.hline(stroke: 0.3pt),
    [A: solo SMS, a los de mayor $hat(tau)_"SMS"$], [687], [69 % SMS], [165,6], [142,4],
    [B: solo llamadas, a los de mayor $hat(tau)_"llamada"$], [4~000], [25 % llamada], [162,0], [164,0],
    [C: _net score_], [3~999], [54 % SMS y 22 % llamada], [278,3], [255,8],
    table.hline(stroke: 0.6pt),
  )

  La estrategia C supera a las otras dos y el multiplicador hace transparente por qué: con $lambda^* approx 0.022$, la llamada solo se asigna donde su uplift supera al del SMS en más de $7.5 times 0.022 approx 0.17$ (y supera a no tratar), y el SMS barato se usa en el resto. Las estrategias A y B fijan la acción de antemano y solo optimizan a quién alcanzar; C optimiza conjuntamente ambas decisiones, que es el problema real. A gasta apenas 687, porque mandar SMS a todos los clientes con uplift positivo estimado no agota el presupuesto, y B solo alcanza al 25 % con llamadas.
]

Hay una segunda lectura, menos cómoda. El uplift estimado de C (278,3) supera en 9 % al verdadero (255,8), y el de A (165,6) en 16 % al suyo (142,4). La asignación elige justo a los clientes donde el error de estimación es favorable, de modo que la cifra proyectada es optimista aunque el modelo esté bien calibrado en promedio. Para reportar el beneficio de la campaña no sirve la misma muestra con la que se asignó: hace falta un grupo de control retenido o un segundo _hold-out_.

La figura #ref(<fig-cap22-uplift>, supplement: none) resume el caso en dos paneles. El izquierdo ordena a los clientes del _hold-out_ por uplift estimado y acumula su uplift verdadero. El derecho compara las tres estrategias a distintos presupuestos.

#figure(
  image("../figuras/fig_cap22_uplift.png", width: 100%),
  caption: [Elaboración propia con datos sintéticos. Izquierda: uplift verdadero acumulado al tratar primero a los clientes de mayor uplift estimado (línea continua) frente a tratar al azar (línea punteada), para SMS y llamada. Derecha: uplift verdadero total de las estrategias A, B y C según el presupuesto; la línea vertical marca el presupuesto del caso canónico (4~000). Datos sintéticos con semilla fija ($n = 5 thin 000$, _hold-out_ de 2~000 clientes, T-learner con _gradient boosting_). El script que genera la figura está en el material de verificación.],
) <fig-cap22-uplift>

*Interpretación.* En el panel izquierdo, tratar al 20 % de clientes con mayor uplift estimado captura el 53 % del uplift total verdadero en el caso del SMS y el 55 % en el de la llamada, más del doble de lo que lograría una selección al azar. Las curvas alcanzan su máximo cerca del 70 % de los clientes y luego descienden: entre el 28 % y el 29 % de los clientes tiene uplift verdadero negativo, de modo que tratar a todos rinde menos que tratar a los mejores. Esa caída es lo que justifica el _targeting_, y es invisible para quien solo mira el uplift promedio.

En el panel derecho, la estrategia C rinde al menos tanto como A y B en todo el rango de presupuestos. La estrategia A se estanca desde un presupuesto de 750, porque solo hay SMS útiles para una parte de los clientes y mandar más no suma uplift. La estrategia B parte muy por debajo, porque cada llamada consume 16 veces lo que cuesta un SMS, y supera a A recién desde un presupuesto de 3~500. C combina lo mejor de ambas: con presupuestos bajos reparte SMS, y a medida que el presupuesto crece incorpora llamadas donde su uplift adicional lo justifica.

Un principio sostiene el diseño del estimador y no puede dejar de enunciarse: no existe forma de derivar $tau_("llamada")(x)$ a partir de $tau_("SMS")(x)$ escalándolo por un factor. Cada acción tiene su propio efecto heterogéneo, con su propio patrón, y estimarlo requiere que los datos contengan variación en esa acción. Si el histórico solo tiene SMS, no hay uplift de llamada que estimar. Cada uplift se estima contra el brazo de control sobre su propia muestra y solo después se predice sobre toda la población: comparar directamente el brazo de SMS contra el de llamada estimaría $tau_"llamada" - tau_"SMS"$, una diferencia de efectos que responde otra pregunta ("¿cuánto mejor es llamar que enviar un SMS?") y que no sirve para el problema de asignación, donde la alternativa relevante de cada acción es *no hacer nada*.

#capa-impl[
== Aplicación con Python
<sec-cap22_python>

=== Uplift modeling con causalml
<sec-cap22_causalml>

La biblioteca #code[causalml] @chen2020causalml proporciona implementaciones de meta-learners (S-, T-, X-, R- y DR-learner) y herramientas de validación como la curva Qini y el AUUC. El siguiente listado muestra un flujo completo de estimación y evaluación *con los dos tratamientos del caso* (SMS y llamada), porque el análisis de costo-efectividad requiere una estimación de uplift *por acción*, no una sola.

#figure(
  kind: raw,
  caption: [Uplift modeling multi-tratamiento con `causalml`: un estimador por acción.],
  ```python
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from xgboost import XGBRegressor
from causalml.inference.meta import BaseTRegressor
from causalml.metrics import plot_qini, qini_score

FEATURES = [f"x{i}" for i in range(8)]

def make_churn_data(n=5000, seed=42):
    """DGP sintetico de churn con TRES brazos: control, SMS, llamada.

    Los dos tratamientos tienen patrones de heterogeneidad distintos --
    ese es justamente el punto: no se derivan uno del otro.
    """
    rng = np.random.default_rng(seed)
    X = rng.uniform(-1, 1, (n, 8))
    # Asignacion a tres brazos (aleatoria: es una campana experimental)
    arm = rng.choice(["control", "sms", "call"], size=n, p=[0.4, 0.3, 0.3])
    tau_sms = 0.06 - 0.16 * X[:, 0] + 0.08 * X[:, 1]    # uplift del SMS (a algunos les hace dano)
    tau_call = 0.12 + 0.30 * X[:, 1] - 0.10 * X[:, 3]   # uplift de la llamada
    base = 0.40 + 0.08 * X[:, 2]                         # retencion basal
    p = base + (arm == "sms") * tau_sms + (arm == "call") * tau_call  # queda dentro de (0, 1)
    Y = (rng.uniform(size=n) < p).astype(int)
    df = pd.DataFrame(X, columns=FEATURES)
    df["y"], df["arm"] = Y, arm
    df["tau_sms_true"], df["tau_call_true"] = tau_sms, tau_call  # solo eval.
    return df

df = make_churn_data(5000)

# El uplift se estima en train y se evalua en test. Evaluar el ranking en la misma
# muestra donde se ajusto el modelo premia el sobreajuste, no la capacidad de ordenar.
train, test = train_test_split(df, test_size=0.4, random_state=0)
test = test.copy()

def uplift_por_accion(train, test, accion, features=FEATURES):
    """Estima tau_accion(x) contra el brazo de control, con datos de train.

    Se restringe la muestra a {control, accion}: comparar dos brazos
    activos entre si estimaria una diferencia de efectos, no un uplift.
    """
    sub = train[train["arm"].isin(["control", accion])]
    learner = BaseTRegressor(learner=XGBRegressor(max_depth=2, n_estimators=100,
                                                  learning_rate=0.05))
    learner.fit(X=sub[features].values,
                treatment=(sub["arm"] == accion).astype(int).values,
                y=sub["y"].values)
    return learner.predict(test[features].values).ravel()  # sobre todo el hold-out

# Un estimador por accion -> dos columnas de uplift, ambas estimadas
test["uplift_sms"] = uplift_por_accion(train, test, "sms")
test["uplift_call"] = uplift_por_accion(train, test, "call")

# Evaluacion de ranking, por accion, sobre su propia submuestra del hold-out
for accion in ["sms", "call"]:
    sub = test[test["arm"].isin(["control", accion])].copy()
    sub["treatment"] = (sub["arm"] == accion).astype(int)
    col = f"uplift_{accion}"
    q = qini_score(sub[["y", "treatment", col]],
                   outcome_col="y", treatment_col="treatment")[col]
    print(f"{accion:>5}: Qini (hold-out) = {q:.4f}")

sub_sms = test[test["arm"].isin(["control", "sms"])].copy()
sub_sms["treatment"] = (sub_sms["arm"] == "sms").astype(int)
plot_qini(sub_sms[["y", "treatment", "uplift_sms"]],
          outcome_col="y", treatment_col="treatment")
```
) <lst-uplift>

Las cifras de los casos canónicos salen de una réplica con _learners_ equivalentes de scikit-learn (un T-learner propio con #code[GradientBoostingRegressor] y el área de la curva Qini calculada sobre datos aleatorizados), porque XGBoost y #code[causalml] no están en el entorno de verificación; con otros _learners_ los números cambian, la conclusión no. La simulación está en #code[herramientas/verificaciones/verif_cap22.py]. En el caso del Qini dentro de muestra frente a _hold-out_, la configuración que lo exhibe (heterogeneidad débil, profundidad 3, 200 árboles) no es la del listado, que usa la heterogeneidad marcada y el modelo suave del segundo caso.

=== Costo-efectividad: tres estrategias
<sec-cap22_costo_efectividad>

El #ref(<lst-cost-effectiveness>, supplement: [listado]) implementa la comparación de tres estrategias de targeting (SMS, llamada y mixta) con el algoritmo de net score, con $lambda_0 = 0$.

#box(fill: light.lighten(50%), width: 100%, inset: 8pt, radius: 2pt)[
  *Nota:* El siguiente ejemplo es *ilustrativo con datos simulados*. En un caso real, #code[uplift_sms] y #code[uplift_call] se estiman mediante un X-learner u otro meta-learner (@cap-meta-learners) entrenado en datos históricos con tratamientos observados.
]

#figure(
  kind: raw,
  caption: [Análisis costo-efectividad: tres estrategias sobre el _hold-out_ y las columnas de uplift estimadas en el #ref(<lst-uplift>, supplement: [listado]).],
  ```python
# Costos unitarios y presupuesto de la campana, sobre el hold-out del listado anterior
COSTOS = {"nada": 0.0, "sms": 0.5, "call": 8.0}
BUDGET = 4_000   # con n = 2 000: llamar a todos costaria 16 000; mandar SMS a todos, 1 000

def uplift_total(df, asignacion, col_sms, col_call):
    """Uplift esperado y gasto de una asignacion accion-por-cliente."""
    u = np.where(asignacion == "sms", df[col_sms],
        np.where(asignacion == "call", df[col_call], 0.0))
    gasto = np.array([COSTOS[a] for a in asignacion]).sum()
    return u.sum(), gasto

d = test.reset_index(drop=True)
n = len(d)

def top_con_presupuesto(uplift, costo, budget):
    """A los de mayor uplift, mientras alcance el presupuesto y el uplift estimado sea positivo."""
    k = min(int(budget / costo), int((uplift > 0).sum()))
    return uplift.argsort()[::-1][:k]

# --- Estrategia A: solo SMS, a los de mayor uplift_sms ---
asig_a = np.full(n, "nada", dtype=object)
asig_a[top_con_presupuesto(d["uplift_sms"].to_numpy(), COSTOS["sms"], BUDGET)] = "sms"

# --- Estrategia B: solo llamadas, a los de mayor uplift_call ---
asig_b = np.full(n, "nada", dtype=object)
asig_b[top_con_presupuesto(d["uplift_call"].to_numpy(), COSTOS["call"], BUDGET)] = "call"

# --- Estrategia C: net score con costo sombra (Algoritmo de la seccion
#     anterior). Bisecta lambda hasta agotar el presupuesto sin pasarse. ---
def asignar_net_score(df, budget, tol=1e-6, max_iter=80):
    """Devuelve la asignacion factible (gasto <= budget) con el menor costo sombra hallado."""
    u_sms, u_call = df["uplift_sms"].to_numpy(), df["uplift_call"].to_numpy()
    lo = 0.0
    hi = max(u_sms.max() / COSTOS["sms"], u_call.max() / COSTOS["call"])  # con lam = hi nadie recibe nada
    mejor = np.full(len(df), "nada", dtype=object)
    for _ in range(max_iter):
        lam = (lo + hi) / 2
        scores = np.column_stack([
            np.zeros(len(df)),                       # no hacer nada
            u_sms - lam * COSTOS["sms"],
            u_call - lam * COSTOS["call"],
        ])
        asig = np.array(["nada", "sms", "call"], dtype=object)[scores.argmax(axis=1)]
        gasto = np.array([COSTOS[a] for a in asig]).sum()
        if gasto <= budget:
            mejor, hi = asig, lam    # factible: probar un costo sombra menor
        else:
            lo = lam                 # se pasa del presupuesto: subir el costo sombra
        if hi - lo < tol:
            break
    return mejor

asig_c = asignar_net_score(d, BUDGET)

for nombre, asig in [("A (solo SMS)", asig_a), ("B (solo llamadas)", asig_b),
                     ("C (net score, mixto)", asig_c)]:
    u_est, gasto = uplift_total(d, asig, "uplift_sms", "uplift_call")
    u_ver, _ = uplift_total(d, asig, "tau_sms_true", "tau_call_true")  # solo por ser sintetico
    print(f"Estrategia {nombre:22s} gasto={gasto:8.1f}  "
          f"uplift estimado={u_est:7.1f}  uplift verdadero={u_ver:7.1f}")
```
) <lst-cost-effectiveness>

Una advertencia sobre los datos de esta sección: la versión previa de los listados usaba un presupuesto de 100~000 dólares con 5~000 clientes, que nunca ata (llamar a todos cuesta 40~000), de modo que las estrategias A y B terminaban tratando a todos y el costo sombra se quedaba en cero. El presupuesto de 4~000 sobre el _hold-out_ de 2~000 clientes es lo que hace que la restricción sea efectiva y que la comparación sea informativa.
]

== Riesgos, límites y mitigación
<sec-cap22_riesgos>

El uso de uplift modeling para targeting con múltiples tratamientos y restricciones presupuestarias presenta riesgos metodológicos que deben diagnosticarse y mitigarse.

#riesgos[
  #set text(size: 9pt)
  #figure(
    caption: [Riesgos comunes en uplift modeling y targeting.],
    table(
      columns: (1.4fr, 1.5fr, 1.5fr, 1.8fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Multiplicar el uplift de una acción para inferir el de otra], [Comparación inválida entre acciones y política subóptima], [Verificar que cada tratamiento tiene su propia estimación de $hat(tau)_k$ en los datos], [Estimar $tau_(k)(x)$ por separado para cada acción $k$, contra el control],
      table.hline(stroke: 0.4pt),
      [Evaluar el ranking en la muestra de ajuste], [Un ranking de ruido parece útil (caso canónico "El mismo modelo, dos evaluaciones")], [Comparar el Qini dentro y fuera de muestra], [Evaluar siempre en datos retenidos; _bootstrap_ sobre la muestra de evaluación],
      table.hline(stroke: 0.4pt),
      [Optimizar solo el ranking sin validar la magnitud], [Mala calibración: el gasto real no coincide con el proyectado], [Comparar la calibración del CATE con el _transformed outcome_], [Reportar ranking y calibración; usar el _transformed outcome_ para magnitudes insesgadas],
      table.hline(stroke: 0.4pt),
      [Proyección optimista del beneficio], [El uplift proyectado de la política elegida supera al real (9 % en el caso canónico)], [Comparar el uplift proyectado con el medido en un grupo retenido], [Medir el beneficio en un control retenido o en un segundo _hold-out_, no en la muestra de asignación],
      table.hline(stroke: 0.4pt),
      [Costos mal medidos o costos hundidos], [Política errónea; se gasta en acciones con retorno negativo], [Sensibilidad de la política a $c_k$ variando ±20 %], [Costos reales (contables u operativos) e incertidumbre por _bootstrap_],
      table.hline(stroke: 0.4pt),
      [Datos históricos no aleatorizados], [El uplift confunde el efecto de la acción con la regla con que se asignó], [Revisar cómo se asignó cada acción y el solape por brazo], [Experimento de asignación aleatoria para entrenar; ponderación por propensión si no es posible],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cap22>
]

Además de los riesgos anteriores, es importante considerar la equidad: una estrategia que maximiza el uplift puede excluir sistemáticamente a grupos vulnerables. Se recomienda reportar la distribución demográfica de los tratados y evaluar si existen disparidades injustificadas en la asignación.

== Ejercicios propuestos
<sec-cap22_ejercicios>

=== Ejercicios teóricos

+ Muestre que, con una sola acción de costo $c > 0$, la regla $tau(x) - lambda c >= 0$ equivale a $tau(x) \/ c >= lambda$, y explique por qué ordenar por $tau \/ c$ resuelve el problema de la mochila fraccionaria con un presupuesto.

+ Con dos acciones de costos 0,5 y 8, derive las dos condiciones del net score para asignar la llamada y compruebe el umbral de $7.5 lambda$ del caso canónico. Si $lambda^* = 0.022$, ¿qué diferencia de uplift entre llamada y SMS hace falta?

+ Un modelo de uplift tiene un AUUC excelente. Si se multiplica $hat(tau)_"llamada"$ por 3, ¿cambia su Qini? ¿Cambia la asignación por net score para un presupuesto dado? Relacione el resultado con la distinción entre ranking y calibración de la @sec-cap22_uplift_cate.

+ Explique por qué el uplift proyectado de la política elegida es optimista aunque el modelo sea insesgado en promedio. Dé un ejemplo de dos clientes con el mismo uplift verdadero y errores de estimación distintos, y explique por qué un segundo _hold-out_ corrige el problema.

+ Con dos acciones, la de mayor efecto promedio puede no ser la que conviene a un cliente concreto. Dé las condiciones, en términos del net score, bajo las que a un cliente le conviene la acción de menor efecto promedio.

+ Discuta: ¿en qué casos el uplift modeling es preferible al policy learning formal?

#capa-impl[
=== Ejercicios computacionales

+ Replique el #ref(<lst-uplift>, supplement: [listado]) sobre #code[thornton_hiv] (un solo tratamiento). ¿Cuál es el Qini score?

+ Sobre el DGP del #ref(<lst-uplift>, supplement: [listado]), compare el uplift promedio de cada acción ($overline(tau)_"SMS"$ frente a $overline(tau)_"llamada"$) con el ranking que produce cada una. Verifique que la acción con mayor efecto promedio *no* es necesariamente la que conviene asignar a cada cliente.

+ Verifique la calibración de ambos estimadores de uplift contra los valores verdaderos (#code[tau_sms_true], #code[tau_call_true] del DGP). Luego multiplique artificialmente #code[uplift_call] por 3 y vuelva a correr el #ref(<lst-cost-effectiveness>, supplement: [listado]). ¿Cambia el Qini de esa acción? ¿Cambia la asignación óptima y el gasto?

+ Modifique el #ref(<lst-cost-effectiveness>, supplement: [listado]) para imponer la restricción de tratar al menos al 20 % de cada grupo demográfico. ¿Cómo cambia el uplift total?
]

== Lecturas complementarias
<sec-cap22_lecturas>

#cite(<radcliffe2007using>, form: "prose") introduce la curva Qini en el contexto de marketing directo, que es donde nace toda esta literatura. #cite(<rzepakowski2012decision>, form: "prose") desarrollan los árboles de uplift con criterios de división específicos (basados en divergencias entre las distribuciones de respuesta de tratados y controles) y son la referencia canónica del caso multi-tratamiento tratado en la @sec-cap22_multitreatment. #cite(<gutierrez2017causal>, form: "prose") revisan la literatura y conectan el vocabulario de uplift de la industria con el de inferencia causal académica; es una lectura recomendada para quien llegue desde cualquiera de los dos lados.#capa-impl[ #cite(<chen2020causalml>, form: "prose") documentan #code[causalml], la librería de Uber usada en este capítulo.] Para policy learning con restricciones presupuestarias tratado formalmente, @athey2021policy y el @cap-policy-learning.
