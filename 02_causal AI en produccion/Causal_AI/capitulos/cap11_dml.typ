// Capítulo 11: Double/Debiased Machine Learning
// Edición en capas: la teoría (L0), los algoritmos en pseudocódigo (L1) y los casos canónicos (L2) son lo que dura;
// los listados (L3), la réplica con datos reales y los ejercicios computacionales van dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Double/Debiased Machine Learning]
<cap-dml>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Estimar retorno a la educación con controles de alta dimensión],
    [*Estimando:*], [$theta_0$, efecto parcial en PLR],
    [*Identificación:*], [No confusión condicional],
    [*Método:*], [DML-PLR / DML-IRM],
    [*Nuisance:*], [$hat(m)(X) = E[D | X]$, $hat(ell)(X) = E[Y | X]$],
    [*Garantía:*], [$sqrt(n) (hat(theta) - theta_0) arrow.r^(p) N(0, cal(V))$],
    [*Condición clave:*], [$sqrt(n) a_n^2 -> 0$],
    ..if not es-principios {([*Librerías:*], [DoubleML, econml])},
    [*Validación:*], [Placebos, sensibilidad a learners, cross-fitting],
  )
]

#notatecnica[
Este capítulo aplica la ortogonalidad de Neyman y el _cross-fitting_ del @cap-ortogonalidad al caso más estándar: los modelos PLR e IRM de Double Machine Learning, el estimador que el servicio del @cap-despliegue-servicio pone en producción#solo-curso[ (el primer notebook de producción del curso, B1)].
]

== Problema causal, estimando e identificación
<sec-cap11_problema>

El Ministerio de Educación desea estimar el efecto causal de una beca sobre el rendimiento académico de estudiantes de secundaria. Dispone de un panel con 60 covariables por estudiante (características familiares, rendimiento previo, características de la escuela, contexto barrial, expectativas subjetivas). La asignación de la beca no fue aleatoria: se priorizó a estudiantes con bajo rendimiento previo, pero también influyeron variables familiares y de contexto. La pregunta de política es: ¿cuál es el efecto promedio de la beca sobre el rendimiento?

En el capítulo #ref(<cap-ortogonalidad>, supplement: none) demostramos que el score ortogonal de Neyman permite estimar $theta_0$ con inferencia válida cuando $g_0$ y $m_0$ se estiman con ML. Este capítulo desarrolla el procedimiento completo, cubriendo los dos modelos centrales de la literatura: el modelo parcialmente lineal (PLR) y el modelo interactivo (IRM)#capa-impl[, con la librería #code[DoubleML] (Bach, Chernozhukov, Kurz y Spindler, 2021) y con #code[econml.dml]]. Discutimos la elección de _learners_ de _nuisance_, la selección de hiperparámetros, la verificación de _leakage_ en _cross-fitting_ y la sensibilidad de los resultados a estas elecciones.

== Teoría, supuestos y garantías
<sec-cap11_teoria>

=== Supuestos
<sec-cap11_supuestos>

Los supuestos de identificación para DML son los mismos del capítulo #ref(<cap-prediccion-causalidad>, supplement: none). En particular, se requiere:

- *No confusión condicional:* $Y(0), Y(1) perp perp D | X$.
- *Soporte común:* $0 < P(D = 1 | X) < 1$ c.s.
- *Consistencia:* $Y = Y(D)$.

Bajo estos supuestos, el ATE se identifica como $theta_0 = E[E[Y | D = 1, X] - E[Y | D = 0, X]]$.

=== Estimador y score
<sec-cap11_score>

==== Modelo parcialmente lineal (PLR)

Reproducimos el modelo PLR del capítulo #ref(<cap-ortogonalidad>, supplement: none):
$
Y = D theta_0 + g_0(X) + epsilon, quad D = m_0(X) + v,
$
con $E[epsilon | D, X] = 0$ y $E[v | X] = 0$. El score ortogonal es:
$
psi_(t "PLR")(W, theta, eta) = (D - m(X))(Y - g(X) - theta D).
$

Si en lugar de $g_0$ se estima $ell_0(X) = E[Y | X]$, el score ortogonal equivalente es el de Robinson, $(D - m(X)){Y - ell(X) - theta (D - m(X))}$, que es el que usa el algoritmo de esta sección.

==== Modelo interactivo (IRM)

El PLR asume que el efecto de $D$ es constante. Cuando sospechamos heterogeneidad en $X$, el modelo interactivo (IRM) es más apropiado. En el IRM, las _outcome regressions_ se modelan separadamente para $D = 0$ y $D = 1$:
$
Y = mu(D, X) + epsilon, quad D tilde "Bernoulli"(e_0(X)),
$
donde $mu(d, x) = E[Y | D = d, X = x]$ y $mu_(d)(x) equiv mu(d, x)$.

Bajo los supuestos de identificación de no confusión condicional y soporte común del capítulo #ref(<cap-prediccion-causalidad>, supplement: none), el ATE se identifica como:
$
theta_0 = E[mu(1, X) - mu(0, X)].
$

El score ortogonal correspondiente, derivado por @chernozhukov2018double, es:
$
psi_(t "IRM")(W, theta, eta) = mu(1, X) - mu(0, X) + (D(Y - mu(1, X)))/e(X) - ((1 - D)(Y - mu(0, X)))/(1 - e(X)) - theta,
$ <eq-irm-score>
donde $eta = (mu, e)$. Este score es la combinación clásica _doubly robust_ de @robins1994estimation ajustada para satisfacer ortogonalidad de Neyman. El score @eq-irm-score es la instancia IRM de la forma canónica de la Nota técnica #ref(<sec-cap10_teorema_dml>, supplement: none); la instancia sin promediar reaparece como $Gamma_i$ del DR-learner (@sec-cap12_drlearner) y como EIF del _policy value_ (@sec-cap21-estimacion).

#theorem(
  name: [Doble robustez + ortogonalidad]
)[
  El score @eq-irm-score es ortogonal de Neyman respecto a $eta = (mu, e)$. Adicionalmente, es _double robust_: si $hat(mu)$ o $hat(e)$ es consistente (no necesariamente ambos), $hat(theta)$ es consistente.
] <thm-dr>

#theorem(name: [Eficiencia semiparamétrica del estimador DML-IRM])[
  Bajo no confusión, soporte común y $Y$ acotado, la _efficient influence function_ (EIF) del funcional $theta_0 = E[mu(1, X) - mu(0, X)]$ en el modelo IRM es exactamente el integrando del score @eq-irm-score:
  $
  psi^*(W) = mu_1(X) - mu_0(X) + (D(Y - mu_1(X))) / e(X) - ((1 - D)(Y - mu_0(X))) / (1 - e(X)) - theta_0.
  $
  Por la cota de Cramér-Rao semiparamétrica (Ap. A, @sec-apA_estimacion_semiparam), el estimador DML-IRM es asintóticamente eficiente: ningún estimador regular puede tener varianza asintótica menor que
  $
  V_"eff" = E[(tau(X) - theta_0)^2 + (sigma_1^2(X)) / e(X) + (sigma_0^2(X)) / (1 - e(X))],
  $
  con $sigma_d^2(x) = "Var"(Y | X = x, D = d)$. La doble robustez (teorema de la @sec-cap11_score) y la eficiencia son propiedades complementarias: la primera protege contra mala especificación de un _nuisance_; la segunda certifica que, cuando ambos _nuisance_ convergen, no se puede hacer mejor. Los ejemplos de IF del Ap. A (@sec-apA_influence_functions) son las instancias de este resultado para IRM y PLR.
] <thm-efficiency-irm>

=== Garantías
<sec-cap11_garantias>

Bajo condiciones de regularidad y tasas de convergencia de los _learners_ nuisance, el estimador DML satisface:
$
sqrt(n) (hat(theta) - theta_0) arrow.r^(p) N(0, cal(V)),
$
donde $cal(V)$ es la varianza asintótica. La condición clave para que el error de los _learners_ nuisance no afecte la distribución asintótica es:
$
sqrt(n) a_n^2 -> 0,
$
donde $a_n$ resume, en esta versión simétrica, las tasas que exige el resto del score. En el PLR de Robinson la condición más precisa distingue los errores de $hat(m)$ y $hat(l)$, como muestra el @cap-ortogonalidad.

La tabla #ref(<tab-learners>, supplement: none) resume las opciones más usadas para estimar $hat(g), hat(m), hat(mu), hat(e)$, con sus tasas de convergencia típicas.

#entero[
#figure(
  caption: [Learners comunes para nuisance en DML.],
  table(
    columns: (1.1fr, 1.6fr, 1.1fr, 1.2fr),
    align: (left, left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header(
      [Learner], [Cuándo usar], [De qué depende la tasa], [Notas]
    ),
    table.hline(stroke: 0.4pt),
    [Bosque aleatorio], [No lineal, interactivo], [Regularidad de la función, dimensión efectiva y diseño del bosque], [No tiene una tasa universal; requiere condiciones específicas],
    [Boosting de gradiente], [No lineal, alta dimensión], [Clase base, profundidad, regularización y aproximabilidad], [La validación predictiva no prueba la condición de DML],
    [LASSO con validación cruzada], [Lineal, esparso, $p >> n$], [$sqrt(s log p / n)$], [Requiere esparsidad],
    [Ridge], [Lineal, denso], [Paramétrica si la especificación es correcta y $p$ es fijo], [No hace selección],
    [Boosting de histogramas], [No lineal, $n > 10^5$], [Las mismas condiciones de aproximación y regularización del boosting], [Escalable],
    [Red neuronal], [No lineal complejo], [Arquitectura, suavidad, dimensión y regularización], [Sensible a hiperparámetros],
    table.hline(stroke: 0.8pt),
  )
) <tab-learners>
]

Una tasa como $n^(-2/5)$ puede aparecer en un problema no paramétrico de baja dimensión y suavidad concreta; no es una propiedad genérica de los bosques ni del boosting. Para LASSO bajo esparsidad, la condición simétrica se traduce en $s log p = o(sqrt(n))$. En un problema concreto, las condiciones de tasa se justifican con resultados propios de la clase de _learner_ y del proceso de datos. El desempeño fuera de muestra de los _nuisance_ y la sensibilidad del efecto a la elección del _learner_ son diagnósticos útiles, pero no verifican por sí solos esas condiciones.

Los hiperparámetros de los _learners_ (profundidad de árboles, _learning rate_, $lambda$ de LASSO) se seleccionan típicamente por _cross-validation_ dentro de cada _fold_ de _cross-fitting_. Esto significa que el costo computacional es $K times ("CV interno")$. Una buena práctica es reportar la sensibilidad de los resultados a la elección de _learner_ y de hiperparámetros.

=== Diagnósticos cuantitativos de soporte común
<sec-cap11_soporte_comun>

La alerta "$hat(e)$ cerca de 0 o 1" (@tab-riesgos_dml) se vuelve operativa con dos cantidades medibles.

*ESS de Kish.* Para la componente IPW del estimador, el tamaño efectivo de muestra es
$
"ESS" = ((sum_i w_i)^2) / (sum_i w_i^2), quad w_i = D_i / hat(e)(X_i).
$
$"ESS"/n << 1$ señala que pocas unidades con $hat(e)$ extremo dominan la estimación: el soporte común es formalmente escaso aunque el histograma de $hat(e)$ "se vea bien" (@kish1965).

*Trimming óptimo.* #cite(<crump2009dealing>, form: "prose") derivan la regla de recorte simétrico $hat(e)(X) ∉ [alpha, 1 - alpha]$ que minimiza la varianza asintótica del ATE; el $alpha^*$ óptimo resuelve una condición de punto fijo sobre la varianza condicional y, en general, no tiene forma cerrada simple. Como regla práctica, que en su artículo funciona bien en un amplio rango de distribuciones del propensity score, proponen $alpha approx 0.1$, es decir, descartar $hat(e)(X) ∉ [0.1, 0.9]$. *Atención al estimando:* tras el _trimming_, el efecto identificado es el ATE sobre la población con _overlap_, no el ATE poblacional, y declararlo en la _model card_ (@cap-model-card-causal) es obligatorio.

*Regla operativa:* reportar $"ESS"/n$ y el rango de $hat(e)$ en todo resultado DML; si $hat(e) ∉ [0.05, 0.95]$ para más del 5 % de la muestra, reestimar con _trimming_ y reportar ambas cifras. El mismo diagnóstico se hereda en el DR-learner (@sec-cap12_drlearner) y en el _net score_ del @cap-uplift-targeting.

== Algoritmo e implementación
<sec-cap11_algoritmo>

#algorithm("DML con cross-fitting")[
  #kwin[Entrada][$(Y_i, D_i, X_i)_(i=1)^n$, learner $L$, folds $K$]
  #kwout[Salida][$hat(theta)$, $wide("SE")$]
  Partir los índices en $K$ folds. \
  #for-loop(`k`, 1, `K`)[
    Estimar $hat(ell)_(-k)(x) = E[Y | X=x]$ con los datos fuera del fold $k$ y predecir dentro del fold $k$ \
    Estimar $hat(m)_(-k)(x) = E[D | X=x]$ con los datos fuera del fold $k$ y predecir dentro del fold $k$
  ]
  Calcular residuos con las predicciones fuera de muestra: $u_i = Y_i - hat(ell)(X_i)$, $v_i = D_i - hat(m)(X_i)$ \
  $hat(theta) = (sum_i v_i u_i) / (sum_i v_i^2)$ \
  Calcular la influence function $psi_i = v_i (u_i - hat(theta) v_i)$ y $wide("SE") = sqrt(sum_i psi_i^2) / (sum_i v_i^2)$
] <alg-dml_crossfitting>

La verificación de que el _cross-fitting_ se hizo bien se reduce a cuatro invariantes sobre las particiones y los modelos:

+ Las particiones de prueba cubren cada observación exactamente una vez, y ninguna observación está a la vez en el entrenamiento y la prueba de un mismo fold.
+ Los modelos de _nuisance_ que predicen la unidad $i$ no se entrenaron con la unidad $i$.
+ Todo preprocesamiento (escalado, selección de variables, imputación) se ajusta solo con los datos de entrenamiento de cada fold.
+ Con particiones y semilla fijas la estimación es reproducible; al repetir el _cross-fitting_ con otras particiones, la dispersión entre repeticiones es pequeña frente al error estándar, o se reporta.

#caso-canonico("Con y sin cross-fitting")[
  Cinco covariables independientes y uniformes en $[-1, 1]$. Una función no lineal $h(X) = sin(3 x_0) + x_1^2$ confunde la relación: el tratamiento es $D = h(X) + epsilon_D$ y el resultado es $Y = 1 dot.c D + 2 h(X) + epsilon_Y$, con ruido normal estándar. El efecto verdadero es $theta_0 = 1$. Con 2 000 unidades y 20 repeticiones, los tres estimadores dan:

  #table(
    columns: (3fr, 1.2fr, 1.2fr),
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Estimador*], [*Media*], [*Desv. típica*]),
    table.hline(stroke: 0.3pt),
    [OLS con las cinco covariables lineales], [1,41], [0,025],
    [DML con boosting, sin _cross-fitting_], [0,86], [0,042],
    [DML con boosting, con _cross-fitting_ ($K = 5$)], [0,95], [0,021],
    table.hline(stroke: 0.6pt),
  )

  El OLS sufre un sesgo grande y estable, de unos 0,4 (la confusión no lineal no se captura con controles lineales). El DML sin _cross-fitting_ usa un _learner_ flexible para ajustar y para predecir sobre los mismos datos: los residuos quedan subestimados y el estimador pierde parte del efecto, con un sesgo de unos 0,14 hacia abajo. Con _cross-fitting_ el sesgo cae a unos 0,05. El sesgo que queda es el del error de estimación de los _nuisance_ con este tamaño muestral, que se reduce con más datos o con un _learner_ mejor ajustado.
]

#capa-impl[
=== DML con DoubleML para PLR

#figure(
  kind: raw,
  caption: [DML con librería DoubleML sobre NSW.],
  ```python
import doubleml as dml
from sklearn.ensemble import RandomForestRegressor, RandomForestClassifier
from sklearn.linear_model import LassoCV, LogisticRegressionCV
import pandas as pd

df = pd.read_csv("../data/datasets/real/public_causaldata/nsw_mixtape/data.csv")
Y = df["re78"].values
D = df["treat"].values
X = df[["age","educ","black","hisp","marr","nodegree","re74","re75"]].values

# PLR con Random Forest
obj_dml = dml.DoubleMLPLR(
    dml.DoubleMLData.from_arrays(X, Y, D),
    ml_l=RandomForestRegressor(n_estimators=200, min_samples_leaf=20, random_state=42),
    ml_m=RandomForestRegressor(n_estimators=200, min_samples_leaf=20, random_state=42),
    n_folds=5,
)
obj_dml.fit()
print(obj_dml.summary)
```
) <lst-doubleml-nsw>

=== DML con econml para CATE bajo PLR/etapa final lineal

```python
from econml.dml import LinearDML, CausalForestDML
from sklearn.ensemble import GradientBoostingRegressor, GradientBoostingClassifier

# LinearDML: asume CATE lineal en X
est = LinearDML(
    model_y=GradientBoostingRegressor(n_estimators=200, max_depth=4, random_state=42),
    model_t=GradientBoostingClassifier(n_estimators=200, max_depth=4, random_state=42),
    discrete_treatment=True,
    cv=5,
    random_state=42,
)
est.fit(Y, D, X=X)
# ATE
ate = est.ate(X=X)
ate_lb, ate_ub = est.ate_interval(X=X, alpha=0.05)
print(f"ATE: {ate:.2f}  IC 95%: [{ate_lb:.2f}, {ate_ub:.2f}]")

# CATE para los primeros 5 individuos
cate = est.effect(X[:5], T0=0, T1=1)
print(f"CATE (5 primeros): {cate}")
```

#code[LinearDML] implementa un modelo parcialmente lineal con etapa final lineal en $X$. No es una implementación general del score IRM no paramétrico para CATE.

=== Comparación de learners

Una práctica recomendada es comparar varios _learners_ para verificar robustez:

```python
from sklearn.linear_model import LassoCV, LogisticRegressionCV
from sklearn.ensemble import RandomForestRegressor

learners = {
    "Lasso": (LassoCV(cv=5), LogisticRegressionCV(cv=5, max_iter=1000)),
    "RF":    (RandomForestRegressor(n_estimators=200, min_samples_leaf=20, random_state=42),
              RandomForestClassifier(n_estimators=200, min_samples_leaf=20, random_state=42)),
    "GBM":   (GradientBoostingRegressor(n_estimators=200, max_depth=3, random_state=42),
              GradientBoostingClassifier(n_estimators=200, max_depth=3, random_state=42)),
}

for name, (ml_y, ml_t) in learners.items():
    est = LinearDML(model_y=ml_y, model_t=ml_t, discrete_treatment=True,
                    cv=5, random_state=42).fit(Y, D, X=X)
    ate = est.ate(X=X); lb, ub = est.ate_interval(X=X, alpha=0.05)
    print(f"{name:>8}: ATE={ate:7.2f}  IC=[{lb:7.2f}, {ub:7.2f}]")
```

=== Verificación de leakage

El _leakage_ entre _folds_ de _cross-fitting_ invalida la inferencia. #code[DoubleML] y #code[econml] manejan esto internamente, pero los invariantes 1 y 2 de la sección anterior se pueden comprobar sobre las particiones:

```python
import numpy as np
from sklearn.model_selection import KFold

def verificar_cross_fitting(n, n_folds=5, seed=42):
    """Comprueba los invariantes 1 y 2 sobre las particiones de cross-fitting."""
    kf = KFold(n_splits=n_folds, shuffle=True, random_state=seed)
    veces_en_prueba = np.zeros(n, dtype=int)
    for entrenamiento, prueba in kf.split(np.arange(n)):
        assert np.intersect1d(entrenamiento, prueba).size == 0, \
            "una unidad esta en el entrenamiento y en la prueba del mismo fold"
        veces_en_prueba[prueba] += 1
    assert (veces_en_prueba == 1).all(), \
        "alguna unidad no esta en exactamente un fold de prueba"
    return True

print(verificar_cross_fitting(len(Y)))
```

Si $D$ es binario, puede usarse un clasificador con #code[predict_proba] para el propensity, pero para el score de Robinson basta con estimar $E[D | X]$.
]

#intuicion[
*Caja de profundización: Refutación y diagnósticos de robustez*

*Objetivo.* Aprender a poner a prueba un estimador DML antes de confiar en sus resultados.

*Pruebas de refutación ("¿y si...?").*
- *Placebo treatment:* reemplazar $D$ por una variable aleatoria. El ATE debería ser cero. Si no lo es, algo anda mal.
- *Random common cause:* agregar una variable aleatoria como confusora. El ATE no debería cambiar sustancialmente.
- *Subset validation:* estimar en la mitad de los datos y verificar que el resultado es similar.

*Diagnósticos de nuisance.*
- Distribución de $hat(e)(X)$: si hay valores muy cercanos a 0 o 1, el estimador puede ser inestable.
- Comparar learners: si LASSO, bosques aleatorios y boosting dan ATE similares, hay más confianza.
]

== Caso empírico y validación
<sec-cap11_caso>

El diseño de referencia para esta parte del capítulo es el de @card1995, que instrumenta los años de educación con la proximidad geográfica a una universidad de cuatro años, bajo el argumento de que vivir cerca de una universidad reduce el costo de asistir sin afectar directamente el salario. (Conviene no confundirlo con el otro diseño IV clásico de la literatura de retornos a la educación, el de @angrist1991, que usa el trimestre de nacimiento interactuado con las leyes de escolaridad obligatoria.) #cite(<chernozhukov2018double>, form: "prose") desarrollan la extensión de DML a este tipo de diseño. El modelo es _partial linear IV_:
$
Y = D theta_0 + g_0(X) + epsilon, quad Z = r_0(X) + zeta, quad D = m_0(Z, X) + v,
$
donde $Z$ es el instrumento#capa-impl[. #code[DoubleML] ofrece el método #code[DoubleMLPLIV] para este caso].

#capa-impl[
El ejemplo de implementación usa el diseño de #cite(<card1995>, form: "prose") y permite comparar OLS, IV y DML-PLIV sobre una misma estructura. La especificación debe excluir #code[exper] de los controles: la experiencia potencial, calculada como edad menos educación menos seis, es una función del tratamiento y constituye una variable posterior. Por esa razón, esta edición no conserva cifras ni una figura de la corrida anterior que incluía #code[exper]. El procedimiento correcto es recalcular la réplica con las variables pretratamiento declaradas y documentar la elección de $K$, el intervalo y el diagnóstico del instrumento.
]

Conviene leer la comparación entre estimadores con cuidado y no como "IV corrige el sesgo de OLS y DML lo corrige mejor". Los tres estimadores de este diseño (OLS con controles, 2SLS y DML con instrumento) estiman objetos distintos. El coeficiente OLS es un efecto parcial bajo no confusión condicional en los controles observados, un supuesto que casi nadie defiende para la educación, por la habilidad no observada. Los dos estimadores IV recuperan, bajo monotonicidad y exclusión, un efecto promedio ponderado sobre los individuos cuya decisión educativa efectivamente respondió a vivir cerca de una universidad (un *LATE*), un subgrupo que no es la población general y que plausiblemente enfrentaba restricciones de crédito más severas. Que la estimación IV sea mayor que la de OLS, como suele ocurrir en esta literatura, es consistente con al menos dos explicaciones sustantivas distintas, la heterogeneidad del efecto concentrada en los _compliers_ o el error de medición en la educación que atenúa el OLS, y la evidencia de un solo estudio no las separa. El intervalo IV es mucho más ancho que el de OLS, y esa amplitud tiene una lectura mecánica: es el precio de identificar con la variación limitada que induce un instrumento de fuerza moderada, y anticipa la discusión de instrumentos débiles del @cap-panel-dmliv.

== Riesgos, límites y sensibilidad
<sec-cap11_riesgos>

#figure(
  caption: [Riesgos comunes en DML],
  table(
    columns: (1fr, 2.5fr),
    align: (left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Riesgo*], [*Descripción*]),
    table.hline(stroke: 0.4pt),
    [Learner único], [Reportar un único _learner_ sin análisis de sensibilidad. Siempre comparar al menos dos _learners_ (lineal + no lineal). Divergencias grandes señalan problemas de especificación.],
    [_Folds_ insuficientes], [Usar $K=2$ _folds_. Con $K=2$, la varianza del estimador aumenta sustancialmente. Recomendado: $K=4$ o $K=5$, con _repeated cross-fitting_ ($R >= 5$) si la varianza entre particiones es material (Nota técnica #ref(<sec-cap10_teorema_dml>, supplement: none)).],
    [Soporte común ignorado], [Si $hat(e)(X)$ está muy cerca de 0 o 1, las ponderaciones IPW explotan. Reportar $"ESS"/n$ y rango de $hat(e)$; _trimming_ con $alpha approx 0.1$ (@crump2009dealing, @sec-cap11_soporte_comun).],
    [Confusión no observada], [Asumir que DML "resuelve" la confusión no observada. DML requiere el supuesto de no confusión condicional. Si hay variables confusoras no observadas, DML es tan sesgado como OLS.],
    [Fuga entre _folds_], [Predecir una unidad con un modelo entrenado con ella, o ajustar el preprocesamiento con todos los datos: los residuos quedan subestimados y la inferencia deja de ser válida. Comprobar los cuatro invariantes del _cross-fitting_.],
    table.hline(stroke: 0.8pt),
  )
) <tab-riesgos_dml>

*Límites del PLR.* El PLR asume efecto constante de $D$. Si el efecto es heterogéneo, $theta_0$ se interpreta como un promedio ponderado que puede diferir del ATE. Para heterogeneidad explícita, usar IRM o bosques causales (capítulo #ref(<cap-causal-forests>, supplement: none)). Un modelo parcialmente lineal con etapa final lineal en $X$ estima un efecto lineal en las covariables; para un CATE no paramétrico bajo la estructura IRM hay que recurrir al DR-learner, a bosques causales o a scores localizados (@cap-meta-learners y @cap-causal-forests).

*Límites del IRM.* El IRM permite heterogeneidad pero asume _unconfoundedness_. Si el tratamiento es endógeno por variables no observadas, se requiere DML con instrumentos (DMLIV).

#diagnosticos[
  #table(
    columns: (1fr, 2fr, 1.2fr),
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Diagnóstico*], [*Qué evaluar*], [*Señal de alerta*]),
    table.hline(stroke: 0.4pt),
    [Overlap], [Histograma de $hat(m)(X)$], [Valores cerca de 0 o 1],
    [Nuisance], [$R^2$ fuera de muestra], [$R^2$ bajo],
    [Leakage], [Invariantes del _cross-fitting_], [Alguna unidad predicha con un modelo que la vio],
    [Estabilidad], [Cambio de learner], [ATE cambia mucho],
    table.hline(stroke: 0.8pt),
  )
]

== Ejercicios y notas bibliográficas
<sec-cap11_ejercicios>

=== Ejercicios teóricos

+ Demuestre que el score IRM de la @eq-irm-score tiene esperanza cero en $theta_0$ cuando $mu$ y $e$ son los verdaderos, y que sigue teniéndola si solo uno de los dos es correcto.

+ Explique por qué estimar los _nuisance_ y calcular los residuos sobre las mismas observaciones sesga el estimador cuando el _learner_ es flexible, y por qué el _cross-fitting_ lo evita.

+ En una muestra, el propensity estimado toma el valor 0,5 en 90 unidades tratadas y el valor 0,02 en 10 unidades tratadas. Calcule el ESS de Kish de la componente IPW y compárelo con el número de unidades tratadas. ¿Qué indica?

#capa-impl[
=== Ejercicios computacionales

+ Replique el #ref(<lst-doubleml-nsw>, supplement: [listado]) variando $K in {2, 3, 5, 10}$. ¿Cómo cambia el error estándar con $K$?

+ Sobre el dataset #code[cps_mixtape], estime el efecto de la educación sobre el salario con DML-PLR y compare con OLS. ¿En qué dirección cambia el estimado al usar DML?

+ Sobre #code[nhefs], estime el efecto de dejar de fumar sobre el cambio de peso con: (a) OLS con controles manuales, (b) DML-PLR con GBM, (c) DML-IRM con GBM. Compare.

+ Verifique empíricamente la doble robustez: reemplace $hat(mu)$ por una constante (modelo mal especificado) y observe que el ATE sigue siendo consistente si $hat(e)$ es consistente.
]

#cite(<chernozhukov2018double>, form: "prose") es el _paper_ fundacional. #cite(<foster2019orthogonal>, form: "prose") extiende el marco a casos más generales. Para una revisión pedagógica, @chernozhukov2018applied.#capa-impl[ #cite(<bach2021doubleml>, form: "prose") documenta la librería #code[DoubleML] y #cite(<battocchi2023econml>, form: "prose") documenta #code[econml].]
