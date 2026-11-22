// Capítulo 16: Post-Double-Selection LASSO
// Edición en capas: la teoría (L0), los algoritmos en pseudocódigo (L1) y los casos canónicos (L2) son lo que dura;
// los listados (L3), la réplica con datos reales y los ejercicios computacionales van dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Post-Double-Selection LASSO]
<cap-pds>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Selección de confusores en alta dimensión para estimación causal],
    [*Estimando:*], [$theta_0$ en el modelo $Y = D theta_0 + X^T gamma_0 + epsilon$],
    [*Identificación:*], [No confusión condicional, esparsidad aproximada, condición de autovalores restringidos],
    [*Método:*], [PDS LASSO: doble selección (LASSO de $Y$ y de $D$) y OLS final],
    [*Nuisance:*], [Conjuntos de controles seleccionados para $Y$ y para $D$],
    [*Garantía:*], [$sqrt(n)(hat(theta)_"PDS" - theta_0) arrow.r^(d) cal(N)(0, cal(V))$, uniforme sobre una clase de modelos],
    ..if not es-principios {([*Librerías:*], [scikit-learn, statsmodels])},
    [*Validación:*], [Sensibilidad a $lambda$, comparación con DML],
  )
]

#notatecnica[
Este capítulo abre la Parte III del libro, dedicada a diseños de identificación completos. El @cap-intervencion-contrafactual formalizó el criterio de puerta trasera de forma general; Post-Double-Selection es el procedimiento concreto para aplicarlo cuando el conjunto de controles candidatos es de alta dimensión y no se sabe, a priori, cuáles son verdaderamente confusores.
]

== Motivación aplicada
<sec-cap16_motivacion>

Una economista de la salud quiere estimar el efecto de dejar de fumar sobre el cambio de peso a lo largo de once años, con los datos de seguimiento de una cohorte nacional (el estudio NHEFS que Hernán y Robins usan como ejemplo canónico). Hay medio centenar de covariables medidas antes del tratamiento: demográficas, de hábitos, de salud y socioeconómicas. No todas son confusoras: algunas no afectan ni al tratamiento ni al resultado, otras afectan solo al resultado. La pregunta metodológica es cómo seleccionar automáticamente las confusoras relevantes sin inducir el sesgo post-selección del capítulo #ref(<cap-regularizacion>, supplement: none).

#cite(<belloni2014inference>, form: "prose") proponen el Post-Double-Selection (PDS) LASSO como solución. Las confusoras son las variables que predicen _tanto_ al tratamiento _como_ al resultado, y un LASSO que mira solo una de las dos ecuaciones puede dejar fuera una confusora que importa en la otra. Seleccionando por separado cada conjunto y tomando la unión, las confusoras relevantes quedan dentro con alta probabilidad, y las que se escapan lo hacen con un sesgo de segundo orden. El capítulo desarrolla PDS formalmente, lo contrasta con DML (capítulo #ref(<cap-dml>, supplement: none)), que no requiere esparsidad explícita, y muestra con dos casos de resultado conocido dónde funciona y dónde no.

== Teoría, supuestos y garantías
<sec-cap16_teoria>

=== Modelo de alta dimensión con efecto causal
<sec-cap16_modelo>

Consideramos el modelo
$
Y = D theta_0 + X^T gamma_0 + epsilon, quad D = X^T beta_0 + v,
$ <eq-hd-model>
donde $X in R^p$ con $p$ potencialmente mayor que $n$, $gamma_0$ y $beta_0$ son _sparse_ (con pocas componentes no nulas, o bien aproximables por pocas) y $theta_0$ es el parámetro causal de interés. Suponemos $E[epsilon | D, X] = 0$ y $E[v | X] = 0$. La primera condición es la no confusión condicional: dados los controles, el tratamiento es ignorable.

Sustituyendo $D$ en la primera ecuación se obtiene la _forma reducida_ $Y = X^T (gamma_0 + theta_0 beta_0) + (epsilon + theta_0 v)$, que también es esparsa si lo son $gamma_0$ y $beta_0$. Esto explica por qué el LASSO de $Y$ sobre $X$ sin incluir $D$ es un paso legítimo del procedimiento.

=== Post-Double-Selection (PDS)
<sec-cap16_pds>

El procedimiento consiste en tres pasos:

+ *Selección de controles para $D$:* LASSO de $D$ sobre $X$, con conjunto seleccionado $S_D$.
+ *Selección de controles para $Y$:* LASSO de $Y$ sobre $X$ (sin $D$), con conjunto seleccionado $S_Y$.
+ *OLS final:* regresión de $Y$ sobre $D$ y las variables de $S = S_Y union S_D$, sin penalización. Los intervalos de confianza usan errores estándar robustos a heterocedasticidad y cuantiles de la normal (o de la $t$, que es asintóticamente equivalente).

El OLS final, llamado _post-LASSO_, elimina el sesgo de contracción que el LASSO induce en los coeficientes seleccionados, y por eso es el estimador que se reporta, no los coeficientes del LASSO.

#theorem(name: [Belloni, Chernozhukov y Hansen, 2014])[
  Bajo esparsidad aproximada de $gamma_0$ y $beta_0$ con índice de esparsidad $s$ tal que $s^2 log^2(max(p, n)) / n -> 0$, condiciones de autovalores restringidos y regularidad de los momentos, y con la penalización del LASSO elegida como la @sec-cap16_lambda describe, el estimador PDS cumple
  $
  sqrt(n)(hat(theta)_"PDS" - theta_0) arrow.r^(d) cal(N)(0, cal(V)),
  $
  donde $cal(V) = E[v^2 epsilon^2] / E[v^2]^2$, y la convergencia es uniforme sobre una clase de modelos que no exige que el LASSO seleccione exactamente el soporte verdadero. La inferencia con errores estándar robustos es válida.
] <thm-pds-formal>

La uniformidad es lo que distingue a PDS de la inferencia ingenua tras una selección: el resultado vale aunque el LASSO omita coeficientes pequeños, porque los errores de selección que importan son de segundo orden, como el esquema de la @sec-cap16_intuicion muestra.

=== Pseudocódigo: Post-Double-Selection

#algorithm("Post-Double-Selection (PDS)")[
  #kwin[Entrada][Datos ${(Y_i, D_i, X_i)}_(i=1)^n$, penalización $lambda$ (teórica o por validación cruzada).]
  #kwout[Salida][Estimador $hat(theta)_"PDS"$ y error estándar robusto $hat(sigma)_"HC"$.]
  Estandarizar las columnas de $X$ (media 0, varianza 1). \
  Ejecutar LASSO de $D$ sobre $X$ con penalización $lambda$ e identificar $S_D = {j : hat(beta)_(D,j) != 0}$. \
  Ejecutar LASSO de $Y$ sobre $X$ con penalización $lambda$ e identificar $S_Y = {j : hat(beta)_(Y,j) != 0}$. \
  Unión: $S = S_Y union S_D$. \
  Estimar por OLS $Y$ sobre una constante, $D$ y $X_S$. \
  Calcular errores estándar robustos a heterocedasticidad. \
  #return-stmt[$hat(theta)_"PDS", hat(sigma)_"HC"$.]
] <alg-pds>

=== La elección de $lambda$ no es un detalle de implementación
<sec-cap16_lambda>

El teorema se enuncia "para un $lambda$ apropiadamente elegido", y conviene detenerse en esa cláusula porque es donde la práctica se aparta con más frecuencia de la teoría que la respalda.

La validación cruzada elige $lambda$ minimizando el error de *predicción* fuera de muestra. Es el criterio correcto si el objetivo es predecir, pero no es el criterio bajo el cual se demuestra el teorema. El $lambda$ óptimo para predicción tiende a ser más pequeño que el teóricamente justificado, porque incluir variables ligeramente informativas reduce el error cuadrático aunque introduzca sesgo en los coeficientes individuales; el resultado es un $hat(S)$ más grande de lo necesario y, en muestras pequeñas, un OLS final con demasiados regresores.

#cite(<belloni2014inference>, form: "prose") derivan en cambio un nivel de penalización *teóricamente justificado*. Para columnas estandarizadas y una pérdida promedio, es de la forma
$
lambda = (c dot.c sigma) / sqrt(n) dot.c Phi^(-1)(1 - gamma \/ (2 p)),
$
con $c approx 1.1$ y $gamma = 0.1 \/ log(max(p, n))$. La fórmula tiene una lectura directa: la penalización se calibra para dominar el "ruido máximo" entre las $p$ variables candidatas, de ahí el cuantil de la normal evaluado en una cola corregida por el número de comparaciones (un ajuste de Bonferroni), de modo que ninguna variable irrelevante entre por azar con probabilidad no despreciable. Como $sigma$ es desconocida, se estima iterativamente, o se usa la variante *rigurosa*, con una penalización distinta por variable que además corrige la heterocedasticidad.

La consecuencia práctica es una advertencia de doble filo. Con la penalización teórica, el conjunto seleccionado es pequeño y el procedimiento es conservador: protege contra falsos positivos, pero deja fuera las variables cuyo efecto no supera el umbral, y eso es inocuo solo si el sesgo que su omisión induce es de segundo orden. La recomendación operativa es reportar ambas versiones, la estimación con $lambda_"CV"$ y la estimación con $lambda_"BCH"$. Si coinciden, que es lo frecuente cuando $n$ es cómodo y la señal es clara, la elección era inmaterial y conviene decirlo. Si difieren, la discrepancia es información: señala que el resultado depende de cuántos controles se admitan, y ninguna de las dos cifras debería reportarse sola. La @sec-cap16_validacion desarrolla esta comparación como análisis de sensibilidad estándar.

=== Por qué la doble selección funciona
<sec-cap16_intuicion>

El sesgo post-selección del capítulo #ref(<cap-regularizacion>, supplement: none) surge porque el LASSO puede _omitir_ una confusora relevante cuando su coeficiente en la ecuación que se mira es pequeño. Un LASSO sobre la ecuación del resultado, con $D$ incluido, omite una variable $X_j$ cuyo efecto $gamma_(0,j)$ es chico, aunque esa variable determine fuertemente a $D$. Si se la omite en el OLS final, el sesgo sobre $hat(theta)$ es proporcional al *producto* $gamma_(0,j) beta_(0,j)$: lo que $X_j$ aporta a $Y$ por lo que $X_j$ aporta a $D$. Con una sola variable omitida y $E[v^2]$ la varianza de lo que de $D$ no explican los controles incluidos, el sesgo límite es $gamma_(0,j) beta_(0,j) \/ (beta_(0,j)^2 + E[v^2])$.

La doble selección usa el hecho de que un producto es pequeño solo si al menos uno de sus factores lo es. Una variable que queda fuera de $S = S_Y union S_D$ no superó el umbral en ninguna de las dos ecuaciones: tanto su efecto en la forma reducida de $Y$ como su efecto en $D$ son del orden de $lambda tilde sqrt(log p \/ n)$. Su contribución al sesgo es entonces del orden de $log p \/ n$ por variable, y sumada sobre a lo sumo $s$ variables relevantes omitidas es $O(s log p \/ n)$, que es $o(1 \/ sqrt(n))$ precisamente cuando $s$ es pequeño frente a $sqrt(n) \/ log p$. Esa es la condición de esparsidad del teorema, y este es el mismo argumento de producto que hace ortogonal al score de DML (@cap-ortogonalidad): el error de estimar los _nuisance_ entra al sesgo multiplicado, no sumado. El argumento es un esquema; la demostración requiere controlar además el error de estimación de los coeficientes seleccionados.

Esto precisa dos matices que el lenguaje habitual de "las confusoras son las que afectan a ambos" no recoge. Primero, la unión captura variables que predicen solo $D$ y no afectan a $Y$, que no son confusoras. Incluirlas no sesga bajo no confusión condicional, pero cuesta varianza, y con confusión no observada amplifica el sesgo (el @cap-intervencion-contrafactual muestra por qué). Segundo, las variables que predicen solo $Y$ son inocuas y reducen la varianza del estimador final.

#caso-canonico("Selección simple frente a doble selección")[
  Cien observaciones y 200 covariables correlacionadas ($Sigma_(i j) = 0.5^(|i - j|)$), con $theta_0 = 0.5$ y ruidos normales estándar. Los coeficientes decrecen con el índice, $beta_(0,j) = 4 \/ j^2$ para $D$ y $gamma_(0,j) = 0.6 \/ j^2$ para $Y$, de modo que $X_1$ es una confusora fuerte para el tratamiento ($beta_(0,1) = 4$) y débil para el resultado ($gamma_(0,1) = 0.6$, bajo el umbral de la penalización teórica con $n = 100$). La _selección simple_ es un LASSO de $Y$ sobre $D$ y $X$ con $D$ sin penalizar, seguido de OLS. Con 500 repeticiones y la penalización teórica en todos los LASSO:

  #table(
    columns: (2.2fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Método*], [*Sesgo*], [*Desv. est.*], [*Cobertura IC 95 %*]),
    table.hline(stroke: 0.3pt),
    [Sin controles], [+0,145], [0,020], [0,00],
    [Selección simple], [+0,145], [0,020], [0,00],
    [Doble selección (PDS)], [+0,032], [0,094], [0,92],
    [Oráculo ($X_1$ a $X_5$)], [+0,016], [0,099], [0,94],
    table.hline(stroke: 0.6pt),
  )

  La selección simple no selecciona nada (en promedio 0,002 variables) y coincide exactamente con la estimación sin controles: el sesgo de 0,145 es el de omitir a $X_1$, y como la desviación estándar es de apenas 0,02, el intervalo es estrecho y falla en todas las repeticiones. La doble selección elige en promedio 2,9 variables, entre ellas casi siempre $X_1$, que entra por la ecuación de $D$, y recupera una cobertura de 0,92 con un sesgo cercano al del oráculo. El precio es la varianza: la desviación estándar pasa de 0,02 a 0,09, porque con $n = 100$ el control $X_1$ y sus vecinas correlacionadas absorben variación del tratamiento. Un intervalo estrecho y equivocado no es mejor que uno ancho y correcto, y la selección simple solo parece más precisa.
]

=== Comparación con DML
<sec-cap16_comparacion_dml>

PDS y DML atacan el mismo problema, la estimación causal con muchos controles, con estrategias distintas:

#figure(
  caption: [PDS frente a DML.],
  table(
    columns: (1.1fr, 1.7fr, 1.7fr),
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Dimensión*], [*PDS LASSO*], [*DML*]),
    table.hline(stroke: 0.4pt),
    [Supuesto estructural], [Esparsidad aproximada de las dos ecuaciones y linealidad en $X$], [Que los _nuisance_ se estimen a una tasa de producto $o(n^(-1\/2))$; no exige esparsidad en sí],
    [Forma funcional], [Lineal en $X$, ampliable con un diccionario de transformaciones], [Cualquier aprendiz para los _nuisance_],
    [Efecto estimado], [Constante], [Constante (modelo parcialmente lineal) o heterogéneo (IRM, CATE)],
    [Inferencia], [Normal asintótica con errores robustos, uniforme sobre la clase de modelos], [Normal asintótica por la función de influencia del score ortogonal],
    ..if not es-principios {([Implementación], [#code[scikit-learn] más OLS], [#code[DoubleML], #code[econml]])},
    [Cuándo conviene], [Pocos controles relevantes, relación lineal, muestra pequeña], [Relaciones no lineales, muchas señales pequeñas, muestra moderada o grande],
    table.hline(stroke: 0.8pt),
  )
) <tab-pds-vs-dml>

#intuicion[
  *Caja de profundización: PDS con instrumentos y cuándo preferir PDS frente a DML*

  *Objetivo.* Extender PDS a variables instrumentales y entender cuándo preferir PDS sobre DML.

  *PDS con instrumentos.* Con un instrumento $Z$ y controles de alta dimensión, el mismo argumento de producto pide quitar el efecto de los controles de las tres variables que intervienen en el diseño. Una variante estándar selecciona, por separado, los controles que predicen $Y$, $D$ y $Z$ sobre $X$, y estima por mínimos cuadrados en dos etapas con la unión como controles. Cuando hay además muchos instrumentos, la selección de instrumentos es un problema aparte, que #cite(<belloni2012sparse>, form: "prose") tratan.

  *¿Cuándo usar cada uno?*
  - *PDS:* mejor con muestra pequeña, modelo lineal y esparsidad fuerte (pocos controles relevantes).
  - *DML:* mejor con no linealidades, dudas sobre la forma funcional o muchas variables con efectos pequeños.
  - *Regla práctica:* sin convicción sobre la linealidad y la esparsidad, DML; con ella y una muestra pequeña, PDS.

  *Límite de PDS.* Si hay *confusión densa* (muchas variables con efectos pequeños que en conjunto importan), la selección omite variables que juntas sesgan el resultado. La @sec-cap16_densa lo cuantifica.
]

=== Confusión densa
<sec-cap16_densa>

La esparsidad es un supuesto sobre la estructura del problema, y la selección con penalización teórica es conservadora. Cuando muchas variables tienen cada una un efecto pequeño sobre $D$ y sobre $Y$, ninguna supera individualmente el umbral y todas se omiten, pero el sesgo total es la suma de muchos productos pequeños.

#caso-canonico("Confusión densa")[
  Mil observaciones, 100 covariables independientes y $theta_0 = 1$. Cada covariable entra con coeficiente $0.1$ tanto en $D = 0.1 sum_j X_j + v$ como en $Y = D + 0.1 sum_j X_j + epsilon$, con ruidos normales estándar. Sin controles, el límite de $hat(theta)$ es $1 + 100 dot.op 0.1^2 \/ (100 dot.op 0.1^2 + 1) = 1.5$: un sesgo de 0,5. Con 150 repeticiones:

  #table(
    columns: (2.6fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Método*], [*Sesgo*], [*Desv. est.*], [*Cobertura IC 95 %*]),
    table.hline(stroke: 0.3pt),
    [Sin controles], [+0,499], [0,030], [0,00],
    [PDS con penalización teórica], [+0,457], [0,030], [0,00],
    [PDS con $lambda$ por validación cruzada], [0,000], [0,033], [0,94],
    [DML con LASSO (validación cruzada)], [+0,001], [0,036], [0,89],
    [DML con ridge (validación cruzada)], [+0,008], [0,035], [0,89],
    table.hline(stroke: 0.6pt),
  )

  La penalización teórica selecciona en promedio 6 de las 100 covariables, las que por azar muestral superan el umbral, y deja casi todo el sesgo (+0,457): el estimador es preciso (desviación estándar de 0,03) y su intervalo falla en todas las repeticiones. Lo que falla es la combinación de una penalización conservadora con confusión densa, no el LASSO en sí. Con $lambda$ por validación cruzada, el procedimiento selecciona las 100 covariables, es decir, se reduce a un OLS con todos los controles, y la cobertura es 0,94. Eso funciona aquí porque $p = 100$ es pequeño frente a $n = 1000$; con $p > n$ no existe el OLS completo, y en ese terreno la confusión densa no tiene salida dentro de PDS. DML con aprendices de _nuisance_ elegidos por validación cruzada (LASSO o ridge) también recupera el efecto, con una cobertura de 0,89 algo baja que con 150 repeticiones no se distingue del error de simulación, porque su validez no depende de que la selección sea esparsa. El diagnóstico práctico es este: si PDS con penalización teórica selecciona pocas variables y PDS con $lambda_"CV"$ selecciona muchas y además mueve la estimación, hay señales de confusión densa, y la discrepancia entre $lambda_"BCH"$ y $lambda_"CV"$ que la @sec-cap16_lambda pide reportar es la alarma.
]

== Sensibilidad y validación
<sec-cap16_validacion>

=== Sensibilidad a la elección de $lambda$
<sec-cap16_sensibilidad>

El resultado de PDS es una función de $lambda$, y trazar esa función es parte del análisis. Se calcula $hat(theta)(lambda)$ con su intervalo sobre una malla de valores y se lee la forma de la curva. Una *meseta amplia* alrededor del $lambda$ elegido indica que el resultado no depende de cuántos controles se admitan, y es la situación en que reportar una sola cifra es defendible. Una curva con pendiente pronunciada en el entorno del $lambda$ elegido indica lo contrario, que el efecto estimado es función de una decisión de hiperparámetro, y obliga a reportar el rango completo en lugar de un punto. Para $lambda$ muy grande el conjunto seleccionado se vacía y la curva converge a la estimación sin controles, de modo que el tramo donde la curva se despega de la meseta señala qué controles sostienen el resultado. Por eso el gráfico de sensibilidad no es un apéndice opcional sino parte del resultado, junto con la comparación $lambda_"CV"$ frente a $lambda_"BCH"$ de la @sec-cap16_lambda.

=== Una limitación del PDS estándar
<sec-cap16_limitacion>

A diferencia de DML, el procedimiento PDS tal como se presenta aquí no usa _cross-fitting_: las dos selecciones LASSO y el OLS final se calculan sobre la misma muestra. La teoría no lo necesita, porque la estructura lineal y la penalización controlan el sobreajuste por otra vía: el argumento descansa en la esparsidad y en cotas uniformes, no en independencia entre etapas. La contrapartida es que esa garantía es exactamente tan fuerte como los supuestos de linealidad y esparsidad: si alguno falla, PDS no tiene la red de seguridad que el _cross-fitting_ da a DML. Es una razón adicional, junto con la confusión densa, para preferir DML cuando no se tiene una convicción sustantiva sobre la forma funcional.

#capa-impl[
== Implementación en Python
<sec-cap16_implementacion>

=== Implementación de PDS
<sec-cap16_impl_pds>

#figure(
  kind: raw,
  caption: [Post-Double-Selection LASSO sobre NHEFS.],
  ```python
import pandas as pd
import numpy as np
from sklearn.linear_model import LassoCV
import statsmodels.api as sm

df = pd.read_csv("../data/datasets/real/public_causaldata/nhefs/data.csv")
# Outcome: cambio de peso. Treatment: qsmk (quit smoking)
# Seleccionar columnas numericas como controles
Y_col = "wt82_71"   # cambio de peso
D_col = "qsmk"      # dejo de fumar
# Excluir identificadores, muerte y variables medidas en 1982 (post-tratamiento)
POST = ["seqn", "id", "death", "yrdth", "modth", "dadth", "censored", "wt82",
        "sbp", "dbp", "smkintensity82_71", "hightax82", "price82", "tax82",
        "price71_82", "tax71_82"]
X_cols = [c for c in df.columns if c not in [Y_col, D_col] + POST]
# Limpiar (solo outcome y tratamiento; NA en controles -> 0 abajo)
df_clean = df.dropna(subset=[Y_col, D_col]).reset_index(drop=True)
Y = df_clean[Y_col].values
D = df_clean[D_col].values.astype(float)
X = df_clean[X_cols].select_dtypes(include=[np.number]).fillna(0).values
# Estandarizar: el LASSO penaliza por igual todas las columnas, y su escala importa
X = (X - X.mean(axis=0)) / np.where(X.std(axis=0) > 0, X.std(axis=0), 1.0)

def pds_lasso(Y, D, X, cv=5):
    """Post-Double-Selection LASSO."""
    # Paso 1: LASSO Y ~ X
    lasso_Y = LassoCV(cv=cv, max_iter=10000, random_state=42).fit(X, Y)
    S_Y = np.where(np.abs(lasso_Y.coef_) > 1e-8)[0]
    # Paso 2: LASSO D ~ X
    lasso_D = LassoCV(cv=cv, max_iter=10000, random_state=42).fit(X, D)
    S_D = np.where(np.abs(lasso_D.coef_) > 1e-8)[0]
    # Union
    S = sorted(set(S_Y) | set(S_D))
    print(f"Seleccionadas: {len(S)} variables (de {X.shape[1]})")
    # Paso 3: OLS Y ~ D + X_S
    if len(S) == 0:
        X_final = sm.add_constant(D)
    else:
        X_final = sm.add_constant(np.column_stack([D, X[:, S]]))
    ols = sm.OLS(Y, X_final).fit(cov_type="HC1")
    theta = ols.params[1]
    se = ols.bse[1]
    return theta, se, S

theta_pds, se_pds, S = pds_lasso(Y, D, X)
print(f"PDS: theta={theta_pds:.4f}  SE={se_pds:.4f}  IC=[{theta_pds-1.96*se_pds:.4f}, {theta_pds+1.96*se_pds:.4f}]")
```
) <lst-pds-nhefs>

#notatecnica[
  Tres advertencias sobre este listado. Primera, no forzar la inclusión de una covariable arbitraria: PDS usa la unión de las variables seleccionadas en los pasos de $Y$ y $D$, y la constante se agrega por separado con #code[add_constant]; forzar una columna puede introducir ruido, colisionadores o variables post-tratamiento. Segunda, el listado usa #code[LassoCV], es decir $lambda_"CV"$ y no la penalización teórica; para esta última, el paquete #code[hdmpy] implementa la penalización rigurosa de #cite(<belloni2014inference>, form: "prose"), y con #code[scikit-learn] puede construirse a mano fijando #code[alpha] en lugar de usar #code[LassoCV]. Tercera, los valores faltantes de los controles se reemplazan por cero, que es una imputación arbitraria (un nivel educativo faltante no es un nivel educativo cero); para un análisis real conviene imputar con un criterio explícito o añadir indicadores de faltante.
]

=== Comparación PDS frente a DML y a la selección manual
<sec-cap16_comparacion>

#figure(
  kind: raw,
  caption: [Comparación PDS vs. DML vs. selección manual.],
  ```python
from econml.dml import LinearDML
from sklearn.ensemble import GradientBoostingRegressor, GradientBoostingClassifier

# DML con GBM
est = LinearDML(model_y=GradientBoostingRegressor(n_estimators=200, random_state=42),
                model_t=GradientBoostingClassifier(n_estimators=200, random_state=42),
                discrete_treatment=True, cv=5, random_state=42).fit(Y, D, X=X)
ate_dml = est.ate(X=X)
lb, ub = est.ate_interval(X=X, alpha=0.05)
print(f"DML:  theta={ate_dml:.4f}  IC=[{lb:.4f}, {ub:.4f}]")

# Seleccion manual (5 controles obvios)
manual_cols = ["age", "sex", "race", "smokeintensity", "smokeyrs"]
X_manual = df_clean[manual_cols].fillna(0).values
X_final_m = sm.add_constant(np.column_stack([D, X_manual]))
ols_m = sm.OLS(Y, X_final_m).fit(cov_type="HC1")
print(f"Manual: theta={ols_m.params[1]:.4f}  SE={ols_m.bse[1]:.4f}")
```
) <lst-pds-vs-dml-code>

=== Réplica sobre NHEFS
<sec-cap16_caso>

NHEFS es el ejemplo canónico de #cite(<hernan2020whatif>, form: "prose") para el efecto de dejar de fumar sobre el peso; aquí se presenta cómo aplicar PDS, propuesto por #cite(<belloni2014inference>, form: "prose"), a ese tipo de datos. La réplica requiere 51 controles potenciales, excluidas las variables posteriores al tratamiento y las variables de fecha. Como el conjunto no está disponible en el entorno de revisión, esta edición no presenta estimaciones numéricas ni una figura basada en esa corrida. El listado siguiente conserva el procedimiento para ejecutar la réplica en un entorno que tenga los datos y para documentar la elección de $lambda$, los intervalos y la sensibilidad del resultado.

La comparación debe leerse con una cautela básica: PDS no demuestra por sí solo la no confusión condicional. Su función es proteger la selección de controles relevantes para el tratamiento y el resultado en un régimen de alta dimensión; la validez causal sigue dependiendo del diseño y de los supuestos declarados.

=== Sensibilidad al hiperparámetro lambda
<sec-cap16_impl_sensibilidad>

#figure(
  kind: raw,
  caption: [Procedimiento para analizar la sensibilidad al hiperparámetro $lambda$.],
  ```python
import matplotlib.pyplot as plt
from sklearn.linear_model import Lasso

lasso_Y_cv = LassoCV(cv=5, max_iter=10000).fit(X, Y)
lambda_cv = lasso_Y_cv.alpha_

lambdas = np.logspace(
    -3,
    max(0, np.log10(lambda_cv * 1.5)),
    30
)
thetas = []
for lam in lambdas:
    lY = Lasso(alpha=lam, max_iter=10000).fit(X, Y)
    lD = Lasso(alpha=lam, max_iter=10000).fit(X, D)
    S = sorted(set(np.where(np.abs(lY.coef_) > 1e-8)[0]) |
               set(np.where(np.abs(lD.coef_) > 1e-8)[0]))
    if len(S) == 0:
        continue
    X_f = sm.add_constant(np.column_stack([D, X[:, S]]))
    ols = sm.OLS(Y, X_f).fit(cov_type="HC1")
    thetas.append((lam, ols.params[1], ols.bse[1]))

thetas = np.array(thetas)
plt.figure(figsize=(8, 5))
plt.errorbar(thetas[:, 0], thetas[:, 1], yerr=1.96*thetas[:, 2], fmt="o-")
if lambdas.min() <= lambda_cv <= lambdas.max():
    plt.axvline(lambda_cv, color="green", ls="--", label=r"$\lambda_{CV}$")
plt.xscale("log")
plt.xlabel("Lambda (penalizacion LASSO)")
plt.ylabel("Estimacion PDS del efecto causal")
plt.title("Sensibilidad de PDS a la eleccion de $\\lambda$")
plt.legend()
plt.tight_layout()
plt.savefig("figuras/pds_sensitivity.png", dpi=120, bbox_inches="tight")
plt.show()
```
) <lst-pds-sensitivity>

El listado salta los valores de $lambda$ para los que el conjunto seleccionado queda vacío (la instrucción #code[continue]), de modo que la curva que produce no llega al estimador sin controles aunque la malla lo permita; para trazar ese tramo hay que calcular el OLS sin controles en esos puntos.
]

== Riesgos, límites y sensibilidad
<sec-cap16_riesgos>

La tabla #ref(<tab-riesgos-pds>, supplement: none) resume los principales riesgos al aplicar PDS, junto con sus consecuencias, diagnósticos y estrategias de mitigación.

#riesgos[
  #figure(
    caption: [Riesgos al aplicar PDS LASSO.],
    table(
      columns: (1.2fr, 1.5fr, 1.5fr, 1.8fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Confusión densa],
      [Selección incompleta de confusoras relevantes y sesgo que no desaparece al crecer $n$],
      [Simulación con un DGP de confusión densa, como el caso canónico],
      [DML con un aprendiz que no dependa de la esparsidad, o PDS con una penalización menor, reportada como sensibilidad],
      table.hline(stroke: 0.4pt),
      [$lambda$ inestable],
      [Resultados frágiles que cambian con $lambda$],
      [Curva de $hat(theta)(lambda)$: meseta frente a pendiente en el entorno del $lambda$ elegido],
      [Reportar el rango completo y contrastar $lambda_"CV"$ con $lambda_"BCH"$ (@sec-cap16_lambda)],
      table.hline(stroke: 0.4pt),
      [Controles post-tratamiento],
      [Sesgo por condicionar en variables afectadas por el tratamiento],
      [Construir un DAG del problema y fechar cada covariable respecto del tratamiento],
      [Excluir variables posteriores al tratamiento],
      table.hline(stroke: 0.4pt),
      [Variables que solo predicen el tratamiento],
      [Pérdida de eficiencia y, con confusión no observada, amplificación del sesgo],
      [Comparar el ancho del intervalo con y sin las variables de $S_D$ ausentes de $S_Y$],
      [Revisar $S_D backslash S_Y$ con criterio sustantivo; contrastar con el DAG (@cap-intervencion-contrafactual)],
      table.hline(stroke: 0.4pt),
      [Forma funcional lineal mal especificada],
      [Sesgo si la confusión es no lineal y el diccionario no la recoge],
      [Residuos de las dos ecuaciones frente a transformaciones de las covariables principales],
      [Ampliar el diccionario con polinomios e interacciones, o usar DML],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-pds>
]

== Ejercicios propuestos
<sec-cap16_ejercicios>

=== Ejercicios teóricos

+ Con $Y = theta D + gamma X + epsilon$, $D = beta X + v$ y $"Var"(X) = 1$, muestre que omitir $X$ en la regresión de $Y$ sobre $D$ da el límite $theta + gamma beta \/ (beta^2 + sigma_v^2)$. Para $beta = 2$, $gamma = 0.5$ y $sigma_v^2 = 1$, calcule el sesgo y explique por qué la selección simple puede omitir a $X$ mientras que la doble selección no.

+ Muestre, con el teorema de Frisch-Waugh-Lovell, que el $hat(theta)$ del OLS final es la pendiente de regresar el residuo de $Y$ sobre $X_S$ contra el residuo de $D$ sobre $X_S$, y relacione esa forma con el score ortogonal del @cap-ortogonalidad.

+ En el caso canónico de confusión densa, con $m$ variables de coeficiente $c$ en las dos ecuaciones y una varianza del error de $D$ igual a 1, muestre que el sesgo de omitirlas todas es $m c^2 \/ (m c^2 + 1)$ y compruebe el valor 0,5 del caso canónico. ¿Cuántas variables habría que incluir para reducir el sesgo a la mitad?

+ Explique por qué, bajo confusión no observada, incluir una variable que solo predice a $D$ puede aumentar el sesgo de $hat(theta)$, y qué parte de $S$ lo permitiría.

+ Con la penalización teórica y $n = 100$, $p = 200$, calcule el umbral $lambda$ de la @sec-cap16_lambda para $sigma = 1$, $c = 1.1$ y $gamma = 0.1 \/ log(200)$, y exprésela en errores estándar de un coeficiente marginal ($sigma \/ sqrt(n)$). ¿Por qué es mucho más exigente que el 1,96 habitual?

#capa-impl[
=== Ejercicios computacionales

+ Replique el #ref(<lst-pds-nhefs>, supplement: [listado]) sobre el dataset #code[close_college] (educación sobre salario, IV = #code[nearc4]). ¿Cambia el estimado IV al usar PDS para seleccionar controles?

+ Modifique el DGP del capítulo #ref(<cap-regularizacion>, supplement: none) para tener 20 confusoras y 80 variables irrelevantes. Compare PDS con selección simple en términos de cobertura.

+ Sobre el dataset #code[cps_mixtape], estime el retorno a la educación con PDS y compare con DML.

+ Repita el caso canónico de confusión densa. Verifique que PDS con penalización teórica queda sesgado, que PDS con $lambda_"CV"$ y DML con ridge no, y estudie qué ocurre con DML cuando el aprendiz de los _nuisance_ es un LASSO con penalización teórica.

+ Implemente la penalización teórica de #cite(<belloni2014inference>, form: "prose") descrita en la @sec-cap16_lambda y compare, sobre #code[nhefs], el $lambda_"BCH"$ resultante con el $lambda_"CV"$ del #ref(<lst-pds-nhefs>, supplement: [listado]). ¿Cuántas variables selecciona cada uno? ¿Cambia el efecto estimado o solo el tamaño del conjunto seleccionado?
]

== Lecturas complementarias
<sec-cap16_lecturas>

#cite(<belloni2014inference>, form: "prose") es el _paper_ fundacional. #cite(<belloni2012sparse>, form: "prose") extiende la selección a instrumentos. #cite(<chernozhukov2018double>, form: "prose") (capítulo #ref(<cap-dml>, supplement: none)) presenta el enfoque alternativo, y #cite(<chernozhukov2018applied>, form: "prose") ofrece un tratamiento pedagógico.
