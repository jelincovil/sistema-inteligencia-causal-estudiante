// Capítulo 17: Machine learning causal en datos de panel
// Edición en capas: la teoría (L0), el pseudocódigo (L1) y los casos canónicos con cifras verificadas (L2)
// son lo que dura; los listados (L3) van dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Machine learning causal en datos de panel]
<cap-panel-dmliv>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Estimar un efecto causal en panel con controles de alta dimensión, o con un instrumento],
    [*Estimando:*], [$theta_0$, efecto parcial en un modelo lineal parcial de panel con efectos fijos],
    [*Identificación:*], [Exogeneidad estricta condicional en efectos fijos y covariables; o exclusión y relevancia del instrumento],
    [*Método:*], [DML-panel (within, _cross-fitting_ por unidad) y DML-PLIV],
    [*Nuisance:*], [$g$, $m$ y $r$ sobre las covariables y un resumen de la trayectoria de la unidad],
    [*Garantía:*], [$sqrt(N)$-normalidad con $N$ unidades y errores estándar por conglomerado],
    [*Condición clave:*], [Efecto constante; tasa de producto de los _nuisance_; instrumento fuerte],
    ..if not es-principios {([*Librerías:*], [scikit-learn, DoubleML (opcional)])},
    [*Validación:*], [Simulación con verdad conocida, _event study_, F de primera etapa e intervalo de Anderson-Rubin],
  )
]

#notatecnica[
Con la doble selección (@cap-pds) como primer diseño de identificación completo, este capítulo extiende el mismo espíritu, controlar con rigor la confusión en alta dimensión, a dos estructuras de datos que rompen el supuesto de observaciones independientes de Double Machine Learning (@cap-dml): los datos de panel con efectos fijos y las variables instrumentales. También advierte sobre el límite de todo el enfoque cuando la adopción del tratamiento es escalonada.
]

== Problema causal, estimando e identificación
<sec-cap17_problema>

Una consultora evalúa el efecto de una reforma laboral sobre el empleo formal en 32 regiones observadas durante 10 años. La reforma se adoptó en distintas regiones en distintos años, lo que produce un panel con _adopción escalonada_ (_staggered adoption_). La pregunta de política es cuál es el efecto de la reforma sobre el empleo formal.

Los métodos clásicos (efectos fijos, diferencias en diferencias, control sintético) funcionan bien con pocos controles y relaciones lineales. Si hay muchas características regionales (sectoriales, demográficas, macroeconómicas) que afectan a la vez la adopción y el empleo, y su efecto no es lineal, los efectos fijos lineales pueden no bastar. #cite(<chernozhukov2018double>, form: "prose") extienden Double Machine Learning a paneles combinando la transformación _within_ con _cross-fitting_ por unidad.

El capítulo desarrolla tres cosas. Primero, DML para paneles: la transformación _within_ que elimina los efectos fijos, el _cross-fitting_ por unidad que preserva la inferencia válida y la salvedad que impone una función de controles no lineal. Segundo, la extensión a instrumentos, con el diagnóstico de instrumentos débiles que la acompaña. Tercero, el límite del enfoque: con adopción escalonada y efectos heterogéneos, la transformación _within_ es un estimador de efectos fijos bidireccionales y hereda sus problemas, que ningún _learner_ flexible corrige.

== Teoría, supuestos y garantías
<sec-cap17_teoria>

=== Modelo de panel con efectos fijos
<sec-cap17_fe_model>

Sea un panel balanceado con $N$ unidades observadas durante $T$ periodos y $n = N T$ observaciones. El modelo es
$
Y_(i t) = theta_0 D_(i t) + g_0(X_(i t)) + alpha_i + delta_t + epsilon_(i t),
$ <eq-panel-model>
donde $alpha_i$ es el efecto fijo de la unidad, $delta_t$ el del periodo, $g_0$ una función desconocida de las covariables que varían en el tiempo y $epsilon_(i t)$ el error. El parámetro causal es $theta_0$. La transformación _within_ bidireccional elimina ambos efectos fijos:
$
tilde(Y)_(i t) = Y_(i t) - overline(Y)_(i dot.c) - overline(Y)_(dot.c t) + overline(Y)_(dot.c dot.c),
$ <eq-within>
donde $overline(Y)_(i dot.c)$ es el promedio temporal de la unidad $i$, $overline(Y)_(dot.c t)$ el promedio transversal del periodo $t$ y $overline(Y)_(dot.c dot.c)$ la gran media. Aplicada a la @eq-panel-model y a $D$ resulta
$
tilde(Y)_(i t) = theta_0 tilde(D)_(i t) + tilde(g)_(i t) + tilde(epsilon)_(i t), quad tilde(g)_(i t) = g_0(X_(i t)) - overline(g)_(i dot.c) - overline(g)_(dot.c t) + overline(g)_(dot.c dot.c),
$ <eq-within-plr>
con $overline(g)_(i dot.c) = T^(-1) sum_t g_0(X_(i t))$ y los demás promedios definidos de la misma manera.

Esta forma requiere una advertencia que el tratamiento habitual omite. Si $g_0$ es lineal, $tilde(g)_(i t) = beta' tilde(X)_(i t)$ y basta con transformar también las covariables. Si $g_0$ no es lineal, la transformación _within_ *no conmuta* con $g_0$: el término $tilde(g)_(i t)$ depende de toda la trayectoria de covariables de la unidad (a través de $overline(g)_(i dot.c)$), no solo de $tilde(X)_(i t)$. Por eso los _learners_ deben recibir como atributos $X_(i t)$, un resumen de la trayectoria de la unidad (por ejemplo, su media $overline(X)_(i dot.c)$, como en los modelos de efectos aleatorios correlacionados de Mundlak) y el periodo $t$. La aproximación es buena cuando $overline(g)_(i dot.c)$ se parece a una función de esos resúmenes; el segundo caso canónico mide qué tan buena es.

=== Supuestos
<sec-cap17_supuestos>

#assumption(name: [Exogeneidad estricta])[
  $E[epsilon_(i t) | D_(i 1), dots, D_(i T), X_(i 1), dots, X_(i T), alpha_i] = 0$ para todo $i, t$.
] <asu-panel-exogeneity>

Es la versión de panel de la no confusión condicional: una vez que se controla por los efectos fijos de unidad y periodo y por las covariables observadas, la asignación del tratamiento es tan buena como aleatoria. Excluye la retroalimentación del resultado pasado hacia el tratamiento futuro, lo que descarta efectos dinámicos del tipo $Y_(i,t-1) -> D_(i t)$.

#assumption(name: [Efecto constante])[
  El efecto causal del tratamiento es constante: $theta_0$ no varía entre unidades ni periodos.
] <asu-panel-constant-effect>

Este supuesto es necesario para la formulación lineal parcial, y el resto del capítulo muestra que es más exigente de lo que parece cuando la adopción es escalonada.

#assumption(name: [Condición de producto])[
  Los _nuisance_ estimados cumplen $sqrt(n) a_n^2 -> 0$, donde $a_n$ es el máximo de los errores en $L^2$ de $hat(g)$ y $hat(m)$.
] <asu-panel-product>

Es la condición de producto del @cap-ortogonalidad: el error de los _nuisance_ debe converger más rápido que $n^(-1\/4)$ para que el sesgo de regularización sea de segundo orden.

=== DML para panel
<sec-cap17_dml_panel>

Con las variables transformadas, el modelo es lineal parcial y se aplica el score ortogonal de Neyman,
$
psi(W, theta, eta) = (tilde(D) - m(F)) (tilde(Y) - ell(F) - theta (tilde(D) - m(F))), quad eta = (ell, m),
$ <eq-score-panel>
donde $F_(i t) = (X_(i t), overline(X)_(i dot.c), t)$ son los atributos descritos arriba, $ell(F) = E[tilde(Y) | F]$ y $m(F) = E[tilde(D) | F]$. La ortogonalidad hace que el error de $hat(g)$ y de $hat(m)$ no contamine la estimación de $theta_0$ en primer orden, y el _cross-fitting_ se hace por unidad, no por observación, porque las observaciones de una misma unidad están correlacionadas.

#algorithm("DML-panel con transformación within")[
  #kwin[Entrada][Panel ${(Y_(i t), D_(i t), X_(i t))}$, $K$ _folds_, _learners_ para $ell$ y $m$.]
  #kwout[Salida][$hat(theta)$ y error estándar por conglomerado.]
  Calcular $tilde(Y)$ y $tilde(D)$ con la @eq-within y los atributos $F_(i t) = (X_(i t), overline(X)_(i dot.c), t)$. \
  Dividir las $N$ unidades en $K$ _folds_ (_cross-fitting_ por conglomerado). \
  #for-loop(`k`, 1, `K`)[
    Ajustar $hat(ell)^(-k)$ y $hat(m)^(-k)$ con las unidades fuera del _fold_ $k$. \
    Para las unidades del _fold_ $k$: $hat(u)_(i t) = tilde(Y)_(i t) - hat(ell)^(-k)(F_(i t))$ y $hat(v)_(i t) = tilde(D)_(i t) - hat(m)^(-k)(F_(i t))$.
  ]
  $hat(theta) = (sum_(i, t) hat(v)_(i t) hat(u)_(i t)) \/ (sum_(i, t) hat(v)_(i t)^2)$. \
  $hat(psi)_(i t) = hat(v)_(i t) (hat(u)_(i t) - hat(theta) hat(v)_(i t))$, $hat(J) = n^(-1) sum_(i, t) hat(v)_(i t)^2$. \
  $hat("se")(hat(theta)) = sqrt(sum_i (sum_t hat(psi)_(i t))^2) \/ (n |hat(J)|)$. \
  #return-stmt[$hat(theta)$, $hat("se")(hat(theta))$.]
] <alg-dml-panel-within>

El error estándar suma el score dentro de cada unidad antes de elevarlo al cuadrado, y eso captura la correlación intra-unidad que un error estándar _i.i.d._ ignora.

=== Garantías
<sec-cap17_garantias>

Bajo los supuestos anteriores y con $N -> infinity$ y $T$ fijo, $sqrt(N)(hat(theta) - theta_0)$ converge a una normal, con una varianza que el error estándar por conglomerado estima de forma consistente. La transformación _within_ elimina $alpha_i$ y $delta_t$ sin estimarlos, lo que sería inviable con ML y paneles largos. Esas garantías valen para el modelo con efecto constante; la advertencia sobre $tilde(g)$ del apartado anterior es una condición adicional, no un detalle: el error de aproximar la trayectoria de la unidad con un resumen entra como error de _nuisance_, y debe converger a la tasa que pide el supuesto de producto.

=== Variables instrumentales: DML-PLIV
<sec-cap17_dmliv>

Si $D$ es endógeno y se dispone de un instrumento $Z$, el modelo es
$
Y = theta_0 D + g_0(X) + epsilon, quad E[epsilon | X, Z] = 0,
$ <eq-dmliv-system>
con los tres _nuisance_ $ell(X) = E[Y | X]$, $m(X) = E[D | X]$ y $r(X) = E[Z | X]$, de modo que $g_0(X) = ell(X) - theta_0 m(X)$. El score ortogonal de @chernozhukov2018double es
$
psi(W, theta, eta) = (Z - r(X))(Y - g(X) - theta D), quad hat(theta) = (sum_i (Z_i - hat(r)(X_i))(Y_i - hat(ell)(X_i))) / (sum_i (Z_i - hat(r)(X_i))(D_i - hat(m)(X_i))).
$ <eq-score-pliv>

#theorem(name: [DML-PLIV])[
  Bajo exclusión $E[epsilon | X, Z] = 0$, relevancia $E[(D - m(X))(Z - r(X))] != 0$ y tasas de producto para $hat(ell), hat(m), hat(r)$ con _cross-fitting_, el estimador $hat(theta)$ es $sqrt(n)$-consistente y asintóticamente normal, con varianza $E[psi^2] \/ J^2$ y $J = E[(D - m(X))(Z - r(X))]$.
] <thm-dml-pliv>

*La relevancia no es un supuesto binario.* El teorema pide $J != 0$, pero la aproximación normal que lo respalda se degrada de forma continua a medida que $J$ se acerca a cero. Con un instrumento débil el estimador IV tiene un sesgo hacia el de OLS, su distribución deja de ser aproximadamente normal y los intervalos convencionales sub-cubren; el problema es de la aproximación asintótica misma, no del tamaño de muestra. El diagnóstico habitual es el estadístico $F$ de la primera etapa sobre los instrumentos excluidos, con la regla práctica $F > 10$. #cite(<stock2005testing>, form: "prose") tabulan valores críticos más precisos según el criterio que se adopte; por ejemplo, con un instrumento y un regresor endógeno, para que el test de Wald del 5 % no tenga un tamaño real superior al 10 % se necesita un $F$ de alrededor de 16. Reportar el $F$ es obligatorio en cualquier diseño IV del libro, y el @cap-monitoreo-causal lo convierte en una métrica de monitoreo continuo, porque la fuerza de un instrumento puede erosionarse con el tiempo sin que ninguna otra señal lo advierta.

El complemento del diagnóstico es la *inferencia robusta a instrumentos débiles*. El intervalo de *Anderson-Rubin* invierte tests: es el conjunto de valores $theta_0$ para los que no se rechaza $H_0: theta = theta_0$, y tiene la cobertura nominal cualquiera sea la fuerza del instrumento, a costa de poder ser un conjunto no acotado cuando la identificación es débil. Con muchos instrumentos, estadísticos robustos como el de Kleibergen y Paap y los valores críticos de Stock y Yogo (#cite(<stock2002survey>, form: "prose"); #cite(<andrews2019robust>, form: "prose")) reemplazan al $F$ de un solo instrumento; con instrumentos generados por ML, #cite(<belloni2012sparse>, form: "prose") tratan la selección óptima con LASSO, y el $F$ calculado sobre residuos ortogonalizados con ML no es el $F$ de una primera etapa lineal, de modo que no hereda las tablas de Stock y Yogo y conviene reportar ambos.

*Regla operativa del libro:* si $F <= 10$, el reporte de un diseño IV incluye el intervalo de Anderson-Rubin junto con el de Wald; si difieren de forma material, la estimación se declara sensible a la fuerza del instrumento y el @cap-monitoreo-causal la monitorea con doble umbral.

=== Adopción escalonada: el límite de la transformación within
<sec-cap17_escalonada>

Cuando distintas unidades reciben el tratamiento en distintos periodos, el estimador de efectos fijos bidireccionales (TWFE) no estima el efecto promedio sobre los tratados, sino un promedio ponderado de comparaciones $2 times 2$. #cite(<goodmanbacon2021>, form: "prose") lo descompone de forma exacta y muestra que incluye comparaciones "prohibidas": unidades recién tratadas contra unidades *ya tratadas antes*, que actúan como controles pese a estar bajo tratamiento. #cite(<dechaisemartin2020twoway>, form: "prose") demuestran que, con efectos heterogéneos en el tiempo, algunos de esos pesos son *negativos*: el coeficiente TWFE puede tener signo opuesto al efecto verdadero aunque el efecto sea positivo para todas las unidades y periodos. No es un problema de precisión que más datos resuelvan, sino de que el estimando implícito no es el que se quiere.

La transformación _within_ de la @sec-cap17_fe_model es TWFE, y por tanto *hereda el problema completo* si la adopción es escalonada y los efectos heterogéneos. El supuesto de efecto constante no es una simplificación menor: sostiene la validez del procedimiento. Flexibilizar los _nuisance_ con ML no repara un estimando mal definido, y ninguna cantidad de _gradient boosting_ en $hat(g)$ y $hat(m)$ corrige un peso negativo.

#intuicion[
  *Caja de profundización: diferencias en diferencias moderno*

  *Objetivo.* Saber qué hacer cuando la adopción es escalonada.

  *Estimadores robustos.*
  - *_Event study_:* graficar el efecto en cada periodo alrededor del tratamiento. Permite ver tendencias previas y la dinámica posterior. Es el punto de partida obligatorio.
  - *#cite(<callaway2021difference>, form: "prose"):* estimar $"ATT"(g, t)$ para cada cohorte de adopción $g$ y periodo $t$ usando solo controles nunca tratados o aún no tratados, y agregar con pesos explícitos y declarados.
  - *#cite(<sun2021estimating>, form: "prose"):* corrección análoga para especificaciones de _event study_, con interacciones cohorte por periodo.
  - *#cite(<borusyak2024revisiting>, form: "prose"):* imputación: se estima el contrafactual con las observaciones no tratadas y se imputa; es eficiente bajo errores homocedásticos y sin anticipación.

  *Recomendación.* Comenzar siempre con un _event study_. Con adopción escalonada, no usar TWFE (ni DML-panel sobre datos transformados) sin verificar antes la descomposición de Goodman-Bacon; si hay pesos negativos materiales, cambiar de estimador antes de preocuparse por la flexibilidad de los controles.
]

== Casos canónicos y validación
<sec-cap17_caso>

Las cifras de los tres casos provienen de simulaciones con semilla declarada.#capa-impl[ El script es #code[herramientas/verificaciones/verif_cap17.py].]

#caso-canonico("Adopción escalonada con efecto creciente")[
  Tres grupos de 20 unidades observados durante 12 periodos: tratados desde el periodo 4, tratados desde el 7 y nunca tratados. El efecto es $0.5 times$ (periodos de exposición), de modo que crece con el tiempo en tratamiento; el promedio verdadero sobre las celdas tratadas es 2,200. Con 200 repeticiones:

  #table(
    columns: (2.6fr, 1fr, 1fr),
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Estimador*], [*Media*], [*Desv. típica*]),
    table.hline(stroke: 0.3pt),
    [Verdad (promedio sobre celdas tratadas)], [2,200], [no aplica],
    [TWFE (_within_ bidireccional)], [1,455], [0,146],
    [Imputación (efectos fijos con celdas no tratadas)], [2,200], [0,154],
    table.hline(stroke: 0.6pt),
  )

  TWFE subestima el efecto en 0,745, un 34 %, porque usa al grupo tratado desde el periodo 4 como control del grupo tratado desde el 7, cuando el primero ya está en plena dinámica de efecto. El estimador de imputación recupera el valor verdadero. Con esta forma de efecto, la transformación _within_ de este capítulo comete el mismo error que TWFE.
]

#caso-canonico("Un panel con controles no lineales")[
  200 unidades, 8 periodos, una covariable $X_(i t) = xi_i + 0.7 nu_(i t)$ cuya media por unidad se asocia con el efecto fijo, $g_0(X) = 2 sin X + 0.5 X^2$ y asignación $P(D = 1) = "sigm"(1.5 sin X + 0.5 xi_i)$, con efecto verdadero $theta_0 = 1$. Con 30 repeticiones:

  #table(
    columns: (2.6fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Estimador*], [*Media*], [*Desv. típica*], [*Sesgo*]),
    table.hline(stroke: 0.3pt),
    [TWFE con $X$ lineal], [1,325], [0,115], [0,325],
    [DML sin transformación _within_], [1,170], [0,080], [0,170],
    [DML-panel (_within_ y atributos de trayectoria)], [1,027], [0,065], [0,027],
    table.hline(stroke: 0.6pt),
  )

  El DML-panel reduce el sesgo de 0,325 a 0,027, y el intervalo del 95 % con error estándar por unidad cubre en 0,97 de las repeticiones (con 30 repeticiones la cifra tiene un margen de error de varios puntos y no se distingue de 0,95). Prescindir de la transformación _within_ es peor que aplicarla (sesgo de 0,170), porque los efectos fijos confunden. El sesgo residual de 0,027 puede atribuirse en parte a que el resumen de trayectoria (la media de $X$ de la unidad) no reproduce exactamente la media de $g_0(X)$, como anticipa la advertencia sobre $tilde(g)$.
]

#caso-canonico("Un instrumento débil")[
  $Y = D + epsilon$, $D = pi Z + v$, con correlación 0,8 entre $epsilon$ y $v$ (confusión fuerte), $n = 200$ y 400 repeticiones. Se compara el intervalo de Wald con el de Anderson-Rubin sobre la rejilla $[-6, 8]$:

  #table(
    columns: (1fr, 1fr, 1.2fr, 1.2fr, 1.2fr, 1.4fr),
    align: (center, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*$pi$*], [*$F$ medio*], [*Mediana de $hat(theta)$*], [*Cobertura Wald*], [*Cobertura AR*], [*AR no acotado*]),
    table.hline(stroke: 0.3pt),
    [0,05], [1,4], [1,48], [0,87], [0,95], [0,92],
    [0,10], [2,9], [1,09], [0,89], [0,95], [0,77],
    [0,30], [18,9], [0,99], [0,93], [0,95], [0,05],
    [1,00], [201,4], [1,00], [0,93], [0,95], [0,00],
    table.hline(stroke: 0.6pt),
  )

  El intervalo de Anderson-Rubin tiene la cobertura nominal en los cuatro casos, a costa de ser no acotado en 92 % y 77 % de las muestras cuando el instrumento es muy débil. El intervalo de Wald sub-cubre (0,87 y 0,89) y es siempre acotado, es decir, parece informativo cuando no lo es: un intervalo de Wald angosto con $F$ cercano a 1 es una señal de alarma, no de precisión.
]

#capa-impl[
== Implementación en Python
<sec-cap17_implementacion>

Los dos listados son manuales y no dependen de la versión de ninguna biblioteca de DML; usan #code[numpy] y #code[scikit-learn]. La implementación de referencia en Python, con _cross-fitting_ por conglomerado y varias extensiones, es #code[DoubleML] @bach2021doubleml, y para el DiD con adopción escalonada están los paquetes #code[did] (Callaway y Sant'Anna) y #code[fixest] (Sun y Abraham), ambos de R.

#figure(
  kind: raw,
  caption: [DML-panel manual: transformación _within_, atributos de trayectoria y _cross-fitting_ por unidad.],
  ```python
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import GroupKFold


def doble_dem(v, N, T):
    """Y_it - Y_i. - Y_.t + Y_.. para un panel balanceado ordenado por unidad y luego por tiempo."""
    M = v.reshape(N, T)
    return (M - M.mean(1, keepdims=True) - M.mean(0, keepdims=True) + M.mean()).ravel()


def dml_panel(Y, D, X, unidad, t, N, T, K=5, seed=0):
    """Devuelve theta y el error estándar por unidad. X es un vector (n,) con una covariable."""
    Yt, Dt = doble_dem(Y, N, T), doble_dem(D, N, T)
    # Atributos: X_it, media de X de la unidad (trayectoria) y periodo.
    Xbar = np.array([X[unidad == i].mean() for i in range(N)])[unidad]
    F = np.column_stack([X, Xbar, t])
    u, v = np.zeros(len(Y)), np.zeros(len(Y))
    for tr, te in GroupKFold(K).split(F, groups=unidad):
        g = RandomForestRegressor(100, min_samples_leaf=10, random_state=seed, n_jobs=-1).fit(F[tr], Yt[tr])
        m = RandomForestRegressor(100, min_samples_leaf=10, random_state=seed, n_jobs=-1).fit(F[tr], Dt[tr])
        u[te], v[te] = Yt[te] - g.predict(F[te]), Dt[te] - m.predict(F[te])
    theta = (v * u).sum() / (v * v).sum()
    psi = v * (u - theta * v)
    J = (v * v).mean()
    por_unidad = np.array([psi[unidad == i].sum() for i in range(N)])
    se = np.sqrt((por_unidad ** 2).sum()) / (len(Y) * abs(J))
    return theta, se


if __name__ == "__main__":
    # Prueba de coherencia con un proceso lineal sencillo: el efecto verdadero es 1.
    rng = np.random.default_rng(0)
    N, T = 100, 6
    unidad = np.repeat(np.arange(N), T); t = np.tile(np.arange(T), N)
    X = rng.standard_normal(N * T)
    D = (X + rng.standard_normal(N * T) > 0).astype(float)
    Y = D + X + rng.standard_normal(N)[unidad] + 0.2 * t + rng.standard_normal(N * T)
    theta, se = dml_panel(Y, D, X, unidad, t, N, T)
    print(f"theta = {theta:.3f} (se {se:.3f}); verdadero = 1.0")
    assert abs(theta - 1.0) < 0.5
```
) <lst-dml-panel>

El divisor del error estándar usa $hat(J) = n^(-1) sum hat(v)^2$, que coincide con el denominador de $hat(theta)$; si se cambia el estimador, el error estándar debe recalcularse con el score correspondiente.

#figure(
  kind: raw,
  caption: [DML-PLIV manual con _cross-fitting_ y diagnóstico del $F$ de primera etapa.],
  ```python
import numpy as np
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.model_selection import KFold


def dml_pliv(Y, D, Z, X, K=5, seed=0):
    """theta = sum (Z - r)(Y - l) / sum (Z - r)(D - m), con l, m, r ajustados fuera del fold."""
    n = len(Y)
    ry, rd, rz = np.zeros(n), np.zeros(n), np.zeros(n)
    for tr, te in KFold(K, shuffle=True, random_state=seed).split(X):
        for objetivo, res in ((Y, ry), (D, rd), (Z, rz)):
            mod = GradientBoostingRegressor(n_estimators=200, random_state=seed).fit(X[tr], objetivo[tr])
            res[te] = objetivo[te] - mod.predict(X[te])
    theta = (rz * ry).sum() / (rz * rd).sum()
    psi = rz * (ry - theta * rd)
    J = (rz * rd).mean()
    se = psi.std(ddof=1) / (abs(J) * np.sqrt(n))
    # F de primera etapa sobre residuos ortogonalizados (no es el F lineal de Stock y Yogo)
    b = (rz * rd).sum() / (rz * rz).sum()
    F = b ** 2 * (rz * rz).sum() / (((rd - b * rz) ** 2).sum() / (n - 1))
    return theta, se, F
```
) <lst-dml-pliv>

Sobre el conjunto #code[close_college], los controles son #code[black], #code[smsa], #code[south] y #code[married]; no se incluye #code[exper] porque es función de la escolaridad (@cap-ingenieria-datos-causales). Un intervalo de Anderson-Rubin se obtiene con la rejilla de valores de $theta$ y el estadístico de la @sec-cap17_dmliv.
]

== Riesgos, límites y sensibilidad
<sec-cap17_riesgos>

#riesgos[
  #set text(size: 9pt)
  #figure(
    caption: [Riesgos comunes en DML con panel e instrumentos.],
    table(
      columns: (1.4fr, 1.4fr, 1.4fr, 1.6fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [No transformar _within_], [Sesgo por $alpha_i$ no observado (caso 2)], [Comparar DML con y sin la transformación], [Aplicarla siempre, o incluir efectos fijos explícitos],
      table.hline(stroke: 0.4pt),
      [Transformar solo $X$ con $g$ no lineal], [Error de aproximación en $tilde(g)$ que no desaparece], [Comparar el sesgo con y sin resumen de trayectoria en los atributos], [Atributos $(X_(i t), overline(X)_(i dot.c), t)$ o un modelo de efectos aleatorios correlacionados],
      table.hline(stroke: 0.4pt),
      [_Cross-fitting_ por observación en lugar de por unidad], [Errores estándar subestimados], [Verificar que los _folds_ agrupan unidades], [Validación cruzada agrupada por unidad],
      table.hline(stroke: 0.4pt),
      [Adopción escalonada con efectos heterogéneos], [Estimando mal definido: pesos negativos; el coeficiente puede tener signo opuesto (caso 1)], [_Event study_ con adelantos y rezagos; descomposición de Goodman-Bacon], [Cambiar de estimador, no de _learner_: Callaway y Sant'Anna, Sun y Abraham, Borusyak et al.],
      table.hline(stroke: 0.4pt),
      [Instrumento débil], [Sesgo hacia OLS, distribución no normal, intervalos que sub-cubren (caso 3)], [$F$ de primera etapa; compararlo con el umbral de Stock y Yogo], [Reportar el $F$; intervalo de Anderson-Rubin junto con el de Wald si $F <= 10$],
      table.hline(stroke: 0.4pt),
      [Varianza _i.i.d._ con correlación intra-unidad], [Inferencia inválida por errores estándar subestimados], [Comparar el error estándar por unidad con el _i.i.d._], [Sumar el score por unidad antes de elevarlo al cuadrado],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cap17>
]

*Límites.* Las garantías del capítulo valen con efecto constante, exogeneidad estricta y $N$ grande con $T$ fijo. La exogeneidad estricta excluye la retroalimentación del resultado hacia el tratamiento; con efectos dinámicos hay que modelarlos de manera explícita. Y con instrumentos, la exclusión no se puede contrastar con los datos: la relevancia sí.

== Ejercicios propuestos
<sec-cap17_ejercicios>

=== Ejercicios teóricos

+ Demuestre que la transformación _within_ bidireccional de la @eq-within elimina $alpha_i$ y $delta_t$ en un panel balanceado. ¿Qué falla si el panel no es balanceado?

+ Muestre que, si $g_0$ es lineal, $tilde(g)_(i t) = beta' tilde(X)_(i t)$, y que si $g_0(x) = x^2$ el término $tilde(g)_(i t)$ depende de la varianza temporal de $X_(i dot.c)$, no solo de $tilde(X)_(i t)$.

+ Verifique que el score @eq-score-pliv es ortogonal respecto de $(ell, m, r)$ bajo $E[epsilon | X, Z] = 0$.

+ Con dos cohortes $A$ (tratada en $t = 2$) y $B$ (tratada en $t = 4$) y un efecto que crece con la exposición, calcule los pesos del TWFE sobre las comparaciones $2 times 2$ y encuentre una configuración donde alguno sea negativo.

+ Para el tercer caso canónico, aproxime la esperanza de $F$ para $pi = 0.05$ y $n = 200$ (con $Z$ y $v$ normales estándar, $F$ es del orden de $1 + n pi^2$) y explique por qué un intervalo de Wald angosto con $F$ cercano a 1 no es informativo.

#capa-impl[
=== Ejercicios computacionales

+ Reemplace #code[RandomForestRegressor] por #code[GradientBoostingRegressor] en el #ref(<lst-dml-panel>, supplement: [listado]) y compare el sesgo y la cobertura sobre el proceso del segundo caso canónico.

+ Construya un panel con tendencias previas no paralelas y muestre que el DML-panel produce un estimado sesgado.

+ Aplique el #ref(<lst-dml-pliv>, supplement: [listado]) a un proceso con un instrumento débil y verifique que el $F$ calculado alerta antes de que el intervalo de Wald sea engañoso.

+ Sobre un panel con adopción escalonada, estime el efecto con TWFE y con un estimador de imputación, y compare con el efecto verdadero (primer caso canónico).
]

== Lecturas complementarias
<sec-cap17_lecturas>

#cite(<chernozhukov2018double>, form: "prose") cubre DML-PLIV. Sobre instrumentos débiles, #cite(<stock2005testing>, form: "prose") es la referencia de los valores críticos y #cite(<belloni2012sparse>, form: "prose") la del caso con muchos instrumentos seleccionados por LASSO.

La literatura de DiD con adopción escalonada es donde más ha cambiado el estado del arte en los últimos años, y conviene leerla en orden: #cite(<goodmanbacon2021>, form: "prose") descompone el estimador TWFE y muestra de dónde vienen las comparaciones problemáticas; #cite(<dechaisemartin2020twoway>, form: "prose") establecen el resultado de pesos negativos que vuelve inservible al TWFE bajo heterogeneidad; y las tres propuestas correctivas principales son #cite(<callaway2021difference>, form: "prose") (agregación explícita de $"ATT"(g, t)$), #cite(<sun2021estimating>, form: "prose") (_event study_ con interacciones cohorte por periodo) y #cite(<borusyak2024revisiting>, form: "prose") (imputación del contrafactual). Para el diagnóstico de tendencias previas en diseños de _event study_, véase @freyaldenhoven2021local. El @cap-scm-mc retoma esta familia de problemas desde el control sintético y la _matrix completion_.
