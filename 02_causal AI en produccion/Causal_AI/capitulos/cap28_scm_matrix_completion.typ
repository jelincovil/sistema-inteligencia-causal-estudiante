// Capítulo 28: Control sintético y matrix completion. Cierra la Parte VII.
// Edición en capas: la teoría (L0), los procedimientos (L1) y los casos canónicos con cifras verificadas (L2)
// son lo que dura; los listados (L3) van dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Control sintético y matrix completion]
<cap-scm-mc>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Estimar el efecto causal en un panel con una o pocas unidades tratadas],
    [*Estimando:*], [El efecto sobre la unidad tratada en cada período posterior, $tau_t$, y su promedio],
    [*Identificación:*], [La trayectoria sin tratamiento de la unidad tratada se reproduce con las de las no tratadas: combinación convexa (control sintético) o rango bajo (matrix completion)],
    [*Método:*], [Control sintético; matrix completion con norma nuclear],
    [*Nuisance:*], [Pesos $w_j$ (control sintético) o matriz $L$ (matrix completion)],
    [*Garantía:*], [Control sintético: sesgo acotado con buen ajuste previo y muchos períodos previos. Matrix completion: error que decrece con las entradas observadas bajo rango bajo e incoherencia, con garantías formales para faltantes aleatorios],
    ..if not es-principios {([*Librerías:*], [scipy.optimize y numpy])},
    [*Validación:*], [Ajuste previo, placebos en espacio y en tiempo, curva del efecto frente a $lambda$],
  )
]

#notatecnica[
En este capítulo, SCM designa el método de control sintético (_synthetic control method_) y no el modelo causal estructural del @cap-scm-pch; la sigla coincide por accidente. Los capítulos anteriores de esta parte estiman efectos de unidades individuales; este cierra la Parte VII con el caso de una o pocas unidades tratadas que se observan a lo largo del tiempo.
]

== Problema causal, estimando e identificación
<sec-cap28_motivacion>

Una economista del Banco Central debe estimar el efecto de una reforma tributaria aplicada en una región sobre la recaudación. No hay una región de control perfecta: todas tienen trayectorias distintas. El método de control sintético de #cite(<abadie2003economic>, form: "prose") construye un control ponderando regiones no tratadas, llamadas *donantes*, para reproducir la trayectoria previa de la región tratada. La diferencia entre lo que ocurrió después y lo que esa combinación predice es el efecto estimado.

El método clásico tiene límites conocidos: exige que la tratada se reproduzca bien con los donantes, maneja con dificultad varias unidades tratadas o adopción escalonada, y no produce errores estándar convencionales. #cite(<athey2021matrix>, form: "prose") proponen _matrix completion_ como alternativa: tratan la matriz de resultados sin tratamiento como una matriz de rango bajo con ruido, en la que las celdas tratadas son entradas faltantes que se imputan. El capítulo desarrolla ambos métodos, los compara con casos de verdad conocida y explica cómo se hace inferencia cuando hay una sola unidad tratada.

== Teoría, supuestos y garantías
<sec-cap28_teoria>

=== Control sintético
<sec-cap28_scm>

Hay una unidad tratada ($i = 1$) y $N$ donantes ($i = 2, dots, N+1$) observados en $t = 1, dots, T$, con tratamiento en los períodos $t > T_0$ para la unidad 1. Con resultados potenciales $Y_(i t)(0)$ y $Y_(i t)(1)$, el estimando es $tau_t = Y_(1 t)(1) - Y_(1 t)(0)$ para $t > T_0$. Lo que falta es $Y_(1 t)(0)$ después de $T_0$. Se identifica bajo cuatro supuestos:

- *Sin anticipación:* antes de $T_0$ el tratamiento no afecta a la unidad tratada.
- *Sin interferencia:* los donantes no reciben efectos indirectos de la intervención.
- *Modelo de factores para el resultado sin tratamiento:* $Y_(i t)(0) = delta_t + lambda_i^top mu_t + epsilon_(i t)$, con factores comunes $mu_t$, cargas $lambda_i$ específicas de cada unidad y ruido transitorio $epsilon_(i t)$.
- *Envolvente convexa:* existen pesos $w_j >= 0$ con $sum_j w_j = 1$ tales que $sum_j w_j lambda_j = lambda_1$, es decir, la tratada está dentro de la envolvente convexa de los donantes en el espacio de las cargas.

El control sintético estima los pesos con los datos previos:
$
hat(bold(w)) = op("argmin", limits: #true)_(bold(w)) sum_(t=1)^(T_0) (Y_(1 t) - sum_(j=2)^(N+1) w_j Y_(j t))^2, quad w_j >= 0, quad sum_j w_j = 1,
$
y el efecto estimado es $hat(tau)_t = Y_(1 t) - sum_j hat(w)_j Y_(j t)$ para $t > T_0$. #cite(<abadie2010synthetic>, form: "prose") muestran que, si los pesos reproducen exactamente la trayectoria previa y las cargas, el sesgo del estimador está acotado por una cantidad que se anula cuando crece el número de períodos previos, bajo condiciones sobre los choques transitorios. Dos advertencias sobre el alcance: la cota formal exige ajuste previo exacto, y en la práctica el ajuste solo es aproximado, de modo que hay que *mirarlo*; y la restricción convexa impide extrapolar, de modo que una unidad extrema no se reproduce con ningún vector de pesos.

=== Matrix completion
<sec-cap28_matrix_completion>

#cite(<athey2021matrix>, form: "prose") reinterpretan el problema como imputación. Sea $Y(0) in RR^(N times T)$ la matriz de resultados sin tratamiento, de la que solo se observan las celdas no tratadas. El modelo es
$
Y(0) = L + epsilon,
$
con $L$ de rango bajo ($"rank"(L) <= r << min(N, T)$) y ruido $epsilon$ cuya media, dado $L$ y el patrón de tratamiento, es cero. Con $cal(O)$ el conjunto de celdas observadas, el estimador con restricción explícita de rango,
$
hat(L) = op("argmin", limits: #true)_(L: "rank"(L) <= r) sum_((i, t) in cal(O)) (Y_(i t) - L_(i t))^2,
$ <eq-matrix-completion>
es no convexo y computacionalmente intratable en general. La solución estándar lo relaja sustituyendo el rango por la norma nuclear:
$
hat(L) = op("argmin", limits: #true)_L { sum_((i,t) in cal(O)) (Y_(i t) - L_(i t))^2 + lambda norm(L)_* }, quad norm(L)_* = sum_i sigma_i (L),
$
con $sigma_i (L)$ los valores singulares. La justificación es la del LASSO en el @cap-regularizacion: así como la norma $ell_1$ es la envolvente convexa de la cantidad de coeficientes no nulos y por eso induce esparsidad, la norma nuclear es la envolvente convexa del rango sobre la bola espectral y por eso induce rango bajo. #cite(<recht2010guaranteed>, form: "prose") establecen condiciones, análogas a la propiedad de isometría restringida del caso esparso, bajo las cuales la relajación recupera la solución de rango mínimo. El paralelo sirve también para las advertencias: igual que el LASSO contrae los coeficientes que selecciona, la norma nuclear contrae los valores singulares que retiene, lo que sesga $hat(L)$ hacia cero y por tanto el efecto estimado.

El efecto sobre la unidad tratada es $hat(tau) = (1 \/ (T - T_0)) sum_(t > T_0) (Y_(1 t) - hat(L)_(1 t))$.

La garantía de recuperación de $L$ tiene la forma habitual: el error decrece con el número de entradas observadas y crece con el rango, bajo incoherencia, que impide que la información de $L$ se concentre en pocas filas o columnas. Pero las garantías formales más simples suponen entradas faltantes *al azar*, y en un panel causal los faltantes son la asignación del tratamiento: bloques finales de períodos de las unidades tratadas. Ese patrón no es aleatorio, y es la razón de que la validez de matrix completion descanse en supuestos sobre $L$ y sobre el patrón de tratamiento, no en un teorema general, y de que convenga validarlo con placebos en lugar de darlo por válido.

=== Elegir $lambda$ o $r$: el hiperparámetro que fija el contrafactual
<sec-cap28_rango>

La decisión más consecuente del método es el nivel de regularización, porque determina literalmente el contrafactual. Con $lambda$ muy alto el modelo es rígido y no reproduce la trayectoria previa; el sesgo aparece como un mal ajuste visible y contrae el contrafactual de las unidades extremas. Con $lambda$ muy bajo el modelo tiene grados de libertad para ajustar el ruido previo y, al extrapolar al período posterior, parte del efecto estimado puede ser ese sobreajuste proyectado.

El procedimiento estándar es la *validación cruzada de bloque*: enmascarar artificialmente un bloque de celdas que sí se observan, imputarlas con cada valor candidato de $lambda$ y elegir el que minimiza el error de imputación fuera de muestra. La clave del diseño es que el patrón de enmascaramiento *imite la estructura del faltante real*: bloques de los últimos períodos previos y no celdas dispersas al azar, porque el problema real es de extrapolación temporal y no de imputación aleatoria. Validar con celdas dispersas produce un $lambda$ demasiado bajo.

Dos diagnósticos acompañan a la elección. Primero, la *curva del efecto estimado frente a $lambda$*: una meseta indica robustez, una pendiente pronunciada indica que el resultado es función del hiperparámetro (la misma lectura que en el @cap-pds). Segundo, el *ajuste previo* con el $lambda$ elegido: si el error de imputación previo es comparable a la magnitud del efecto estimado, no hay señal que distinguir del ruido, por bueno que sea el valor de validación cruzada.

=== Comparación entre ambos métodos
<sec-cap28_comparacion>

#figure(
  caption: [Control sintético y matrix completion.],
  table(
    columns: (1.2fr, 1fr, 1fr),
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([Dimensión], [Control sintético], [Matrix completion]),
    table.hline(stroke: 0.4pt),
    [Varias unidades tratadas], [Un control por unidad], [Natural: la misma matriz],
    [Adopción escalonada], [Un control por unidad y cohorte], [Natural: faltantes en bloques distintos],
    [Ajuste previo], [Exigido y verificable], [Implícito en la elección de $lambda$],
    [Inferencia], [Placebos por permutación], [Placebos o remuestreo; sin teoría estándar con una unidad tratada],
    [Supuesto estructural], [Tratada en la envolvente convexa de los donantes], [Rango bajo, incoherencia y patrón de tratamiento no informativo],
    table.hline(stroke: 0.8pt),
  )
) <tab-scm-vs-mc>

=== Inferencia con una sola unidad tratada
<sec-cap28_inferencia>

Con una sola unidad tratada no hay muestra sobre la que aplicar un teorema central del límite, de modo que el error estándar convencional no está definido. #cite(<abadie2015comparative>, form: "prose") formalizan la alternativa: un *test de permutación* que aplica el mismo procedimiento a cada donante como si hubiera sido el tratado, construye la distribución de efectos placebo y sitúa el de la unidad realmente tratada dentro de ella. Si cae en la cola extrema, se rechaza el efecto nulo. El $p$-valor es exacto bajo intercambiabilidad pero *discreto*: con $J$ donantes, el mínimo alcanzable es $1 \/ (J + 1)$. Con 9 donantes no se puede obtener $p < 0.10$, por grande que sea el efecto, y ese límite hay que reportarlo.

Los placebos con mal ajuste previo producen efectos posteriores grandes por construcción y contaminan la distribución de referencia. La práctica estándar es usar el cociente entre el error cuadrático medio posterior y el previo (RMSPE) en lugar del efecto crudo, o descartar los donantes con ajuste previo mucho peor que el de la tratada. Las variantes más recientes relajan la restricción convexa: #cite(<doudchenko2016balancing>, form: "prose") muestran que control sintético, diferencias en diferencias y varios emparejamientos son casos de una misma familia de regresiones sobre las unidades de control, que difieren en las restricciones sobre los pesos; #cite(<benmichael2021augmented>, form: "prose") corrigen el sesgo del ajuste imperfecto con un modelo de resultado, la misma lógica de aumento doblemente robusto del @cap-dml trasladada al panel.

#intuicion[
*Synthetic difference-in-differences y placebos en el tiempo.* #cite(<arkhangelsky2021synthetic>, form: "prose") combinan el control sintético con las diferencias en diferencias. Los pesos de unidad hacen que los controles reproduzcan la trayectoria previa de las tratadas, con un nivel libre; los pesos de tiempo hacen que los períodos previos más informativos reproduzcan el promedio posterior de los controles; y el efecto es una diferencia en diferencias ponderada con ambos pesos. Es más robusto que el control sintético cuando las tendencias paralelas no se cumplen del todo. En cuanto a los placebos, los *en espacio* reasignan el tratamiento a cada donante, y los *en el tiempo* aplican el método a un período previo donde no debería haber efecto; los primeros calibran la inferencia y los segundos detectan anticipación y mal ajuste.
]

== Procedimientos
<sec-cap28_algoritmo>

#algorithm("Control sintético clásico")[
  #kwin[Entrada][Resultado previo de la tratada $bold(Y)_(1, "pre") in RR^(T_0)$; donantes previos $bold(Y)_(0, "pre") in RR^(T_0 times N)$ y posteriores $bold(Y)_(0, "post") in RR^((T-T_0) times N)$; resultado posterior de la tratada $bold(Y)_(1, "post")$.]
  #kwout[Salida][Pesos $hat(bold(w))$, contrafactual sintético y efecto estimado por período.]
  Resolver la optimización restringida: \
  #h(1.5em) $hat(bold(w)) = op("argmin", limits: #true)_bold(w) norm(bold(Y)_(1, "pre") - bold(Y)_(0, "pre") bold(w))^2$ \
  sujeto a $w_j >= 0$ para todo $j$ y $sum_j w_j = 1$. \
  Calcular el contrafactual posterior: \
  #h(1.5em) $hat(bold(Y))_(1, "post") = bold(Y)_(0, "post") hat(bold(w))$ \
  Estimar el efecto por período: \
  #h(1.5em) $hat(tau)_t = Y_(1 t) - hat(Y)_(1, "post", t), quad t = T_0+1, dots, T$ \
  Verificar el ajuste previo y calcular los placebos de cada donante. \
  #return-stmt[$hat(bold(w)), hat(bold(Y))_(1, "post"), hat(bold(tau))$, ajuste previo y $p$-valor de permutación]
] <alg-scm_clasico>

#algorithm("Matrix completion con λ por validación cruzada de bloque")[
  #kwin[Entrada][Matriz de resultados $Y$, celdas observadas $cal(O)$, rejilla de valores de $lambda$, último período previo $T_0$.]
  #kwout[Salida][$lambda$ elegido, matriz imputada $hat(L)$ y efecto estimado.]
  Para cada $lambda$ de la rejilla: \
  #h(1.5em) enmascarar además los últimos períodos previos de algunas unidades de control; \
  #h(1.5em) imputar con umbralización suave de valores singulares (restar $lambda$ a cada valor singular, con piso en cero, y repetir hasta converger); \
  #h(1.5em) medir el error de imputación en el bloque enmascarado. \
  Elegir el $lambda$ de menor error promedio sobre varias elecciones de unidades enmascaradas. \
  Imputar con el $lambda$ elegido usando solo las celdas realmente observadas. \
  Estimar $hat(tau) = (T - T_0)^(-1) sum_(t > T_0) (Y_(1 t) - hat(L)_(1 t))$ y repetir el procedimiento como placebo sobre unidades no tratadas. \
  #return-stmt[$lambda$, $hat(L)$, $hat(tau)$ y su comparación con los placebos]
] <alg-matrix-completion>

== Casos canónicos y validación
<sec-cap28_caso_empirico>

Los casos usan un panel de factores con verdad conocida: 20 unidades, 30 períodos, rango 2 y ruido normal de desviación 0,5. Una unidad recibe un efecto aditivo de 2,5 desde el período 16, y las demás no reciben efecto. Las cifras promedian 200 repeticiones.#capa-impl[ El script es #code[herramientas/verificaciones/verif_cap28.py] y la figura sale de #code[herramientas/figuras/fig_cap28_scm_mc.py].]

#figure(
  image("../figuras/fig_cap28_scm_mc.png", width: 100%),
  caption: [Elaboración propia con datos sintéticos. (a) y (b): trayectoria de la unidad tratada, control sintético y matrix completion en una realización, con la unidad tratada dentro y fuera de la envolvente convexa de los donantes; la línea vertical marca el inicio del tratamiento. (c): raíz del error cuadrático medio del efecto estimado por matrix completion frente a $lambda$, en 200 repeticiones. Efecto verdadero 2,5.],
) <fig-cap28-scm-mc>

#caso-canonico("Dentro de la envolvente convexa, ambos métodos recuperan el efecto")[
  La unidad tratada tiene cargas dentro de las de los donantes (panel (a) de la @fig-cap28-scm-mc). El control sintético estima el efecto con sesgo de +0,011 y raíz del error cuadrático medio (RMSE) de 0,152; matrix completion con $lambda$ elegido por validación cruzada, sesgo de +0,008 y RMSE de 0,138. El ajuste previo del control sintético tiene RMSPE de 0,36, por debajo del ruido de 0,5, un valor menor que el ruido porque con 19 donantes y 15 períodos previos los pesos ajustan parte del ruido.
]

#caso-canonico("Fuera de la envolvente, el control sintético falla y lo delata el ajuste previo")[
  Ahora la unidad tratada tiene cargas extremas, fuera de las de todos los donantes (panel (b)). El control sintético ya no puede reproducirla: el RMSPE previo sube a 2,52, cinco veces el ruido, y el RMSE del efecto sube a 0,757. Matrix completion, que extrapola con la estructura de rango bajo, tiene RMSE de 0,482. El sesgo medio sigue siendo pequeño (+0,073 y +0,032) porque el error cambia de signo según la realización de los factores: lo que se degrada es la dispersión, de modo que una sola estimación puede errar mucho en cualquier sentido. El diagnóstico es el ajuste previo, no el efecto.
]

#caso-canonico("El hiperparámetro fija el contrafactual")[
  Con la tratada dentro de la envolvente, el RMSE del efecto es plano frente a $lambda$ (entre 0,135 y 0,143 para $lambda$ de 0,5 a 20): una meseta. Con la tratada extrema el RMSE crece con $lambda$: 0,46 con $lambda = 0.5$, 0,54 con 5, 0,75 con 10 y 1,02 con 20, porque la regularización contrae hacia cero el contrafactual de la unidad extrema. La elección por validación cruzada de bloque (0,482) queda cerca del mejor valor de la rejilla. Reportar la curva distingue el caso robusto del caso en que el resultado depende del hiperparámetro.
]

#caso-canonico("La inferencia por placebos tiene un piso discreto")[
  Con 19 donantes el $p$-valor mínimo es 0,05. Bajo efecto nulo, el test rechaza al 5 % en el 6,0 % de las repeticiones (nominal 5 %); con el efecto de 2,5 rechaza en el 87 %. Con 9 donantes el mínimo es 0,10: no rechaza nunca al 5 %, bajo efecto nulo rechaza al 10 % en el 11,5 % de las repeticiones y con efecto rechaza en el 79,5 %. Con pocos donantes, un efecto grande no puede producir un $p$-valor pequeño, y reportar el piso evita que el lector lo suponga continuo.
]

#cite(<abadie2010synthetic>, form: "prose") aplicaron el control sintético a la ley de control del tabaco de California (Proposición 99) sobre el consumo de cigarrillos, y #cite(<abadie2003economic>, form: "prose") al costo económico del conflicto en el País Vasco, los dos usos clásicos del método. Las cifras de esas aplicaciones no se reproducen aquí; lo que se usa de ellas es el procedimiento de inferencia por placebos del tercer caso.

#capa-impl[
== Implementación en Python
<sec-cap28_implementacion>

#figure(
  kind: raw,
  caption: [Control sintético y matrix completion sobre un panel de factores simulado.],
  ```python
import numpy as np
from scipy.optimize import minimize


def pesos_scm(y_pre, X_pre):
    """Pesos no negativos que suman uno y minimizan ||y_pre - X_pre w||^2."""
    J = X_pre.shape[1]
    res = minimize(lambda w: np.sum((y_pre - X_pre @ w) ** 2), np.ones(J) / J, method="SLSQP",
                   bounds=[(0, 1)] * J, constraints=[{"type": "eq", "fun": lambda w: w.sum() - 1}])
    return res.x


def soft_impute(Y, observada, lam, n_iter=300, tol=1e-5):
    """Imputa las celdas no observadas con umbralizacion suave de valores singulares."""
    M = np.where(observada, Y, 0.0)
    for _ in range(n_iter):
        U, s, Vt = np.linalg.svd(np.where(observada, Y, M), full_matrices=False)
        M_nuevo = (U * np.maximum(s - lam, 0.0)) @ Vt
        if np.linalg.norm(M_nuevo - M) < tol * (np.linalg.norm(M) + 1e-12):
            return M_nuevo
        M = M_nuevo
    return M


# Panel con factores: 20 unidades, 30 periodos, unidad 0 tratada desde t = 15 con efecto 2.5
rng = np.random.default_rng(0)
N, T, T0, TAU = 20, 30, 15, 2.5
carga = rng.standard_normal((N, 2))
carga[0] = [0.2, -0.1]                       # la tratada queda dentro de la envolvente de los donantes
Y = carga @ rng.standard_normal((2, T)) + 0.5 * rng.standard_normal((N, T))
Y[0, T0:] += TAU

# Control sintetico
w = pesos_scm(Y[0, :T0], Y[1:, :T0].T)
efecto_scm = (Y[0, T0:] - Y[1:, T0:].T @ w).mean()
rmspe_pre = np.sqrt(np.mean((Y[0, :T0] - Y[1:, :T0].T @ w) ** 2))      # ajuste previo: hay que mirarlo

# Matrix completion: las celdas posteriores de la tratada son las faltantes
observada = np.ones((N, T), dtype=bool)
observada[0, T0:] = False
efecto_mc = (Y[0, T0:] - soft_impute(Y, observada, lam=5.0)[0, T0:]).mean()

print(f"SCM: {efecto_scm:.3f} (RMSPE previo {rmspe_pre:.2f})   MC: {efecto_mc:.3f}   (verdad: {TAU})")
assert abs(efecto_scm - TAU) < 0.6 and abs(efecto_mc - TAU) < 0.6   # coherencia
```
) <lst-scm-sintetico>

#figure(
  kind: raw,
  caption: [Elección de $lambda$ por validación cruzada de bloque.],
  ```python
def lambda_por_cv(Y, observada, rejilla, T0, bloque=5, n_val=5, rondas=3, semilla=0):
    """Enmascara los ultimos `bloque` periodos previos de `n_val` unidades de control (la
    tratada es la unidad 0) y elige el lambda con menor error de imputacion en ese bloque."""
    rng = np.random.default_rng(semilla)
    cols = np.arange(T0 - bloque, T0)
    error = np.zeros(len(rejilla))
    for _ in range(rondas):
        filas = rng.choice(np.arange(1, Y.shape[0]), n_val, replace=False)
        m = observada.copy()
        m[np.ix_(filas, cols)] = False
        for k, lam in enumerate(rejilla):
            L = soft_impute(Y, m, lam)
            error[k] += np.mean((Y[np.ix_(filas, cols)] - L[np.ix_(filas, cols)]) ** 2)
    return rejilla[int(np.argmin(error))]


lam = lambda_por_cv(Y, observada, [1.0, 2.0, 3.0, 5.0, 8.0, 12.0], T0)
efecto_cv = (Y[0, T0:] - soft_impute(Y, observada, lam)[0, T0:]).mean()
print(f"lambda elegido: {lam}   efecto MC: {efecto_cv:.3f}")
assert lam in [1.0, 2.0, 3.0, 5.0, 8.0, 12.0] and abs(efecto_cv - TAU) < 0.6   # coherencia
```
) <lst-lambda-cv>

El segundo listado usa los objetos definidos en el primero. Para varias unidades tratadas o adopción escalonada, la máscara marca como faltante el bloque posterior de cada unidad tratada y el resto del código no cambia.
]

== Riesgos, límites y mitigación
<sec-cap28_riesgos>

#riesgos[
  #set text(size: 9pt)
  #figure(
    caption: [Riesgos en control sintético y matrix completion.],
    table(
      columns: (1.3fr, 1.5fr, 1.4fr, 1.6fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Mal ajuste previo], [El contrafactual no reproduce la trayectoria y el efecto mide el error de ajuste (caso 2)], [RMSPE previo frente al ruido y al efecto], [Ampliar donantes, relajar pesos o usar matrix completion],
      table.hline(stroke: 0.4pt),
      [Pocos donantes], [Control débil y $p$-valor acotado por abajo en $1\/(J+1)$ (caso 4)], [Número de donantes con buen ajuste; concentración de los pesos], [Ampliar el conjunto de donantes; reportar el $p$-valor mínimo alcanzable],
      table.hline(stroke: 0.4pt),
      [Tratada fuera de la envolvente convexa], [Ningún vector de pesos convexos la reproduce], [Cargas o covariables de la tratada frente al rango de los donantes], [Relajar los pesos o aumentar con un modelo de resultado],
      table.hline(stroke: 0.4pt),
      [$lambda$ mal elegido], [Contrafactual contraído o sobreajustado (caso 3)], [Curva del efecto frente a $lambda$; validación cruzada de bloque], [Elegir por bloque, reportar la curva y los placebos],
      table.hline(stroke: 0.4pt),
      [Donantes afectados o anticipación], [Se viola la ausencia de interferencia o de anticipación; el efecto se subestima], [Cercanía entre tratada y donantes; placebo en el tiempo], [Excluir donantes expuestos; dejar uno fuera; acotar $T_0$],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cap28>
]

*Límites.* Los dos métodos suponen que no hay interferencia entre unidades y que el mecanismo que genera los resultados sin tratamiento es estable antes y después de la intervención. Ninguno puede distinguir el efecto de la intervención de un choque simultáneo que solo afecta a la tratada, y los placebos solo detectan los choques que también afectan a los donantes.

== Ejercicios y notas bibliográficas
<sec-cap28_ejercicios>

=== Ejercicios teóricos
<sec-cap28_ejercicios_teoricos>

+ Explique por qué, en el segundo caso canónico, el sesgo medio es pequeño pero el error de cada estimación es grande, y qué señal observable avisa del problema.

+ Muestre que, bajo intercambiabilidad y el efecto nulo, $P(p <= k \/ (J+1)) <= k \/ (J+1)$ para el $p$-valor de permutación, y que el mínimo alcanzable es $1 \/ (J+1)$.

+ Demuestre que la solución de $min_L (1\/2) norm(M - L)_F^2 + lambda norm(L)_*$ es $L = U max(Sigma - lambda I, 0) V^top$ si $M = U Sigma V^top$ es la descomposición en valores singulares, y explique por qué eso implica que el estimador contrae hacia cero.

+ Explique por qué validar con celdas enmascaradas dispersas al azar produce un $lambda$ más bajo que validar con un bloque de períodos finales.

#capa-impl[
=== Ejercicios computacionales
<sec-cap28_ejercicios_computacionales>

+ Con el #ref(<lst-scm-sintetico>, supplement: [listado]), coloque la unidad tratada fuera de la envolvente convexa (por ejemplo, cargas $(3, 3)$) y compare el RMSPE previo y el efecto estimado de ambos métodos con el caso de la unidad central.

+ Replique el control sintético sobre el panel #code[texas] de la colección de datos públicos (la expansión de la capacidad carcelaria de Texas en 1993 y el encarcelamiento de hombres negros, con los demás estados como donantes). Reporte el efecto posterior y el $p$-valor de placebos con su mínimo alcanzable.

+ Modifique el #ref(<lst-scm-sintetico>, supplement: [listado]) para incluir efectos fijos de unidad y de tiempo en matrix completion. ¿Mejora la imputación?

+ Aplique matrix completion a un panel con adopción escalonada de la colección, como #code[abortion], y compare con el control sintético sobre una cohorte.
]

=== Notas bibliográficas
<sec-cap28_lecturas>

#cite(<abadie2003economic>, form: "prose") y #cite(<abadie2010synthetic>, form: "prose") son las referencias del control sintético clásico; #cite(<abadie2015comparative>, form: "prose") desarrolla la inferencia por permutación de placebos y las correcciones por ajuste previo que la hacen utilizable. #cite(<doudchenko2016balancing>, form: "prose") sitúan el control sintético, las diferencias en diferencias y el emparejamiento dentro de una familia común de estimadores de pesos, y son la mejor lectura para entender qué se supone al elegir cada uno. #cite(<benmichael2021augmented>, form: "prose") proponen el control sintético aumentado para el ajuste previo imperfecto. #cite(<athey2021matrix>, form: "prose") introduce matrix completion en el contexto causal y su relación con los estimadores anteriores, y #cite(<recht2010guaranteed>, form: "prose") establece la teoría de la relajación por norma nuclear. #cite(<arkhangelsky2021synthetic>, form: "prose") propone la diferencia en diferencias sintética como híbrido. Sobre la conexión con la literatura de diferencias en diferencias con adopción escalonada, los mismos problemas vistos desde el otro extremo del espectro de unidades tratadas, véase el @cap-panel-dmliv y sus referencias.
