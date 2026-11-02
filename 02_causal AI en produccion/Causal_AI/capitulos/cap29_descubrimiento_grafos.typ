// Capítulo 29: Descubrimiento causal y grafos
// Edición en capas: la teoría (L0), los algoritmos en pseudocódigo (L1) y los casos canónicos (L2) son lo que dura;
// los listados (L3) y los ejercicios computacionales van dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Descubrimiento causal y grafos]
<cap-descubrimiento-grafos>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Inferir la estructura causal (grafo) a partir de datos observacionales],
    [*Estimando:*], [DAG $G = (V, E)$, "CPDAG", matriz de adyacencia $bold(W)$],
    [*Identificación:*], [Causal sufficiency, faithfulness, aciclicidad, Markov property],
    [*Método:*], [Basados en restricciones (PC, FCI); basados en score (GES); optimización continua (NOTEARS)],
    [*Nuisance:*], [Tests de independencia, matriz de pesos],
    [*Garantía:*], [Consistencia del esqueleto bajo faithfulness (PC); solución global bajo aciclicidad (NOTEARS)],
    ..if not es-principios {([*Librerías:*], [#code[dowhy], #code[causal-learn], #code[networkx]])},
    [*Validación:*], [SHD, precisión, recall, estabilidad por subsampling],
  )
]

#notatecnica[
Todo #solo-curso[el curso]#solo-comercial[el libro], hasta aquí, asumió que el grafo causal, o al menos el conjunto de puerta trasera, estaba dado por conocimiento de dominio. Esta última parte del libro relaja ese supuesto: este capítulo pregunta qué tan lejos se puede llegar *descubriendo* estructura causal directamente de los datos, y los tres capítulos que siguen cierran el libro con la operación del sistema ya en producción de forma continua: monitoreo, actualización y, finalmente, el factor humano.
]

== Motivación aplicada
<sec-cap29_motivacion>

Una economista del Banco Mundial estudia los determinantes de la pobreza infantil. Tiene 30 variables (ingreso familiar, educación parental, acceso a salud, nutrición, entorno barrial, etc.) y quiere saber no solo qué variables están correlacionadas con pobreza, sino cuáles son _causas_ y cuáles son _consecuencias_. Esta es la pregunta del _causal discovery_: inferir la estructura causal (grafo) a partir de datos observacionales.

A diferencia del resto #solo-curso[del curso]#solo-comercial[del libro], donde el grafo causal se asume conocido y el problema es estimar efectos, en causal discovery el grafo mismo es el objeto de estimación. #cite(<pearl2009causality>, form: "prose") formalizó el marco de DAGs (Directed Acyclic Graphs). #cite(<spirtes2000causation>, form: "prose") introdujo el algoritmo PC basado en tests de independencia condicional. #cite(<zheng2018dags>, form: "prose") propuso NOTEARS, que reformula el descubrimiento causal como optimización continua.

Este capítulo presenta los fundamentos de DAGs, el algoritmo PC y NOTEARS#capa-impl[, con implementaciones en #code[dowhy] y #code[causal-learn]]. Discute los límites para aplicaciones económicas: el supuesto de _causal sufficiency_ (no hay confusores no observados) es fuerte y raramente plausible.

== Marco teórico formal
<sec-cap29_marco_teorico>

=== DAGs y el criterio de puerta trasera
<sec-cap29_dags>

Un _DAG_ es un grafo dirigido acíclico $G = (V, E)$ donde los nodos son variables y las aristas $X_i arrow.r X_j$ indican causalidad directa. La distribución conjunta factoriza según el DAG:
$
p(X_1, dots, X_p) = product_i p(X_i | "parents"(X_i)).
$

El criterio de puerta trasera, que dice qué conjuntos de variables permiten identificar un efecto a partir de un DAG dado, se desarrolló en el @cap-intervencion-contrafactual. Este capítulo trata el problema inverso: no leer el grafo para decidir qué controlar, sino estimar el grafo mismo.

=== Algoritmo PC
<sec-cap29_pc>

El algoritmo PC (Spirtes y Glymour, 1991) construye un DAG en tres pasos:

+ *Esqueleto:* empezar con el grafo completo no dirigido. Para cada par $(X_i, X_j)$, testar independencia condicional dado subconjuntos de vecinos. Eliminar la arista si se encuentra independencia.
+ *Orientación de colisionadores:* para cada tripleta $X_i - X_k - X_j$ con $X_i$ y $X_j$ no adyacentes, orientar como $X_i arrow.r X_k arrow.l X_j$ si $X_k$ no pertenece al conjunto separador que hizo independientes a $X_i$ y $X_j$.
+ *Reglas de orientación:* aplicar las reglas de Meek para orientar las aristas restantes, evitando ciclos y nuevos colisionadores.

El output es una _CPDAG_ (Completed Partially Directed Acyclic Graph), que representa la clase de equivalencia de Markov: DAGs que no pueden distinguirse observacionalmente. Este es el límite duro del descubrimiento a partir de datos observacionales, y es una instancia del mismo principio que el Teorema de la Jerarquía Causal del @cap-scm-pch, visto desde el ángulo de la estructura: si dos grafos inducen las mismas independencias condicionales, ningún algoritmo que solo mire $P(v)$ puede separarlos.

#cite(<kalisch2007estimating>, form: "prose") establecen las propiedades estadísticas del algoritmo en alta dimensión: bajo _faithfulness_, suficiencia causal, normalidad multivariante y esparsidad del grafo verdadero, la CPDAG estimada por PC es consistente incluso cuando $p$ crece exponencialmente con $n$. Su análisis aporta además el resultado que más importa en la práctica: el costo computacional crece de forma exponencial con el grado máximo del grafo y solo de forma polinomial con $p$, lo que hace viable el algoritmo en grafos dispersos y lo vuelve inviable en grafos densos.

*Una tercera familia: métodos de score.* Junto a los métodos basados en restricciones (PC, FCI) y a los de optimización continua (NOTEARS), existe una tercera familia que busca el grafo que maximiza un criterio de ajuste penalizado, típicamente BIC, sobre el espacio de DAGs. Su representante canónico es GES (_Greedy Equivalence Search_), y #cite(<chickering2002optimal>, form: "prose") demuestra un resultado notable: pese a ser una búsqueda voraz sobre un espacio combinatorio enorme, GES es *consistente*, es decir, converge a la clase de equivalencia correcta con probabilidad tendiente a uno. La diferencia práctica con PC es de robustez: PC toma decisiones discretas e irreversibles (eliminar una arista tras un test), de modo que un error temprano se propaga a todo el resto del procedimiento; GES optimiza un criterio global y no arrastra ese tipo de error en cascada. En muestras pequeñas, donde los tests de independencia tienen poca potencia, la diferencia puede ser material.

#box(fill: orange.lighten(90%), width: 100%, inset: 8pt, radius: 2pt)[
  *Advertencia:* los métodos de las tres familias son *sensibles a la elección de hiperparámetros* (por ejemplo, el nivel de significancia $alpha$ en PC o la penalización en GES). @machlanski2024robustness (Machlanski et al. 2024, AISTATS) muestran que pequeños cambios en hiperparámetros pueden producir grafos radicalmente diferentes.

  *Recomendación:* usar análisis de sensibilidad y validación de expertos de dominio.
]

=== Pseudocódigo: PC skeleton
<sec-cap29_pc_skeleton>

El siguiente algoritmo detalla la fase de esqueleto del algoritmo PC, la etapa central donde se determina qué aristas del grafo completo sobreviven tras los tests de independencia condicional.

#algorithm("PC skeleton: esqueleto del grafo causal")[
  #kwin[Entrada][Datos $bold(X) in R^(n times p)$, nivel de significación $alpha$, orden máximo $m$]
  #kwout[Salida][Esqueleto no dirigido $G = (V, E)$]
  Inicializar $G$ como grafo completo no dirigido con $p$ nodos \
  $l <- 0$ \
  *while* #h(2pt) $l <= m$ y existe una arista $(X_i, X_j)$ en $G$ con $|"adj"(G, X_i) \\ {X_j}| >= l$ *do* \
  #h(1.5em) *for* #h(2pt) cada arista $(X_i, X_j)$ en $G$ con $|"adj"(G, X_i) \\ {X_j}| >= l$ *do* \
  #h(3.0em) *for* #h(2pt) cada subconjunto $S subset.eq "adj"(G, X_i) \\ {X_j}$ con $|S| = l$ *do* \
  #h(4.5em) *if* #h(2pt) test de independencia $X_i perp perp X_j | S$ no se rechaza a nivel $alpha$ *then* \
  #h(6.0em) Eliminar arista $(X_i, X_j)$ de $G$ \
  #h(6.0em) Registrar $S$ como _set separador_ $"sep"(X_i, X_j)$ \
  #h(6.0em) *break* \
  #h(4.5em) *end if* \
  #h(3.0em) *end for* \
  #h(1.5em) *end for* \
  #h(1.5em) $l <- l + 1$ \
  *end while* \
  #return-stmt[$G$ con sets separadores $"sep"(dot.c, dot.c)$]
] <alg-pc-skeleton>

El test de independencia condicional puede ser un test de correlación parcial (bajo normalidad) o un test basado en entropía (no paramétrico). La elección de $alpha$ controla la densidad del grafo estimado: $alpha$ pequeños producen grafos más dispersos. Los sets separadores $"sep"(X_i, X_j)$ se preservan para la etapa posterior de orientación de colisionadores.

El algoritmo se detiene cuando ningún nodo tiene más de $l$ vecinos, no cuando un nivel $l$ no elimina ninguna arista. La segunda regla parece razonable y es un error frecuente. Conviene además fijar las adyacencias al comenzar cada nivel (la variante "estable" de PC), para que el resultado no dependa del orden en que se listan las variables.

#caso-canonico("Un nivel sin eliminaciones no es el final")[
  Cuatro variables con aristas $A arrow.r B$, $A arrow.r X$, $A arrow.r Y$, $B arrow.r X$ y $B arrow.r Y$. Las variables $X$ e $Y$ no son adyacentes, pero solo quedan independientes condicionando en el par ${A, B}$: condicionando solo en $A$ sigue abierto el camino por $B$, y al revés. Con un oráculo de independencia, los niveles $l = 0$ y $l = 1$ no eliminan ninguna arista. Parar en el primer nivel sin eliminaciones deja el grafo completo, con la arista espuria $X - Y$; la regla correcta continúa hasta $l = 2$, separa $X$ de $Y$ con ${A, B}$ y recupera el esqueleto exacto.

  Con 5 000 unidades y un test de correlación parcial, una simulación reproduce las dos conductas: la regla incorrecta deja la arista espuria y la correcta recupera el esqueleto.
]

=== NOTEARS
<sec-cap29_notears>

#cite(<zheng2018dags>, form: "prose") reformulan el descubrimiento causal como optimización continua. La aciclicidad se impone con la restricción:
$
h(bold(W)) = "tr"(e^(bold(W) circle bold(W))) - p = 0,
$ <eq-notears-constraint>
donde $bold(W)$ es la matriz de pesos (adyacencia) y $circle$ es el producto de Hadamard. El problema es:
$
min_(bold(W)) norm(X - X bold(W))_F^2 + lambda norm(bold(W))_1 quad "sujeto a" quad h(bold(W)) = 0.
$

La ventaja: se resuelve con métodos de optimización continua (Lagrangiano aumentado), evitando la búsqueda combinatoria de PC.

#caso-canonico("Escala y orientación: la varsortability")[
  Un modelo lineal con cadena $X_0 arrow.r X_1 arrow.r X_2 arrow.l X_3$, pesos 2,0, 1,5 y 1,0, ruido normal estándar y una variable $X_4$ aislada. Las varianzas teóricas crecen a lo largo de las cadenas causales: 1 para $X_0$, 5 para $X_1$ y 13,25 para $X_2$. Esa regularidad de escala es una pista sobre el orden causal que un método de optimización continua puede explotar sin que haya detectado ninguna estructura.

  En la simulación de este capítulo (1 000 unidades), NOTEARS lineal recupera exactamente las tres aristas sobre los datos en su escala original. Sobre los mismos datos estandarizados, donde desaparece la pista, invierte la orientación de las tres y agrega una arista espuria. El resultado es el fenómeno de _varsortability_ documentado por #cite(<reisach2021beware>, form: "prose"), y la consecuencia práctica es reportar siempre las dos corridas, con y sin estandarización.
]

=== Límites: causal sufficiency
<sec-cap29_causal_sufficiency>

Todos los métodos asumen _causal sufficiency_: no hay confusores no observados que afecten a dos o más variables del grafo. En aplicaciones económicas este supuesto es fuerte.

#capa-impl[
== Implementación en Python
<sec-cap29_implementacion>

=== Construcción de DAGs con dowhy
<sec-cap29_dowhy>

#figure(
  kind: raw,
  caption: [Identificación con DAGs en dowhy.],
  ```python
import pandas as pd
from dowhy import CausalModel

# DAG del retorno a la educacion. Los nombres de nodo son los de las columnas
# del dataset; U es un confusor que NO esta en los datos. `fameduc` es una
# caracteristica familiar observada y anterior a la educacion. No se usa la
# experiencia potencial (edad - educ - 6) porque es funcion del tratamiento.
graph = """
graph [
  directed 1
  node [ id "nearc4" label "nearc4" ]
  node [ id "educ" label "educ" ]
  node [ id "lwage" label "lwage" ]
  node [ id "fameduc" label "fameduc" ]
  node [ id "U" label "U" ]
  edge [ source "nearc4" target "educ" ]
  edge [ source "educ" target "lwage" ]
  edge [ source "fameduc" target "educ" ]
  edge [ source "fameduc" target "lwage" ]
  edge [ source "U" target "educ" ]
  edge [ source "U" target "lwage" ]
]
"""

df = pd.read_csv("../data/datasets/real/public_causaldata/close_college/data.csv")
model = CausalModel(
    data=df,
    treatment="educ",
    outcome="lwage",
    graph=graph.replace("\n", " "),
)
# Con U sin observar no hay conjunto de ajuste valido: el estimando que queda
# es el del instrumento nearc4, y hay que pedirlo explicitamente.
identified_estimand = model.identify_effect(proceed_when_unidentifiable=True)
print(identified_estimand)
```
) <lst-dowhy-dag>

Dos detalles del listado importan. Los nombres de nodo del grafo deben coincidir con los de las columnas del dataset, porque `CausalModel` busca el tratamiento y el resultado por nombre, y el grafo debe declararse dirigido. Y el confusor $U$ no tiene columna: es la forma de decir que existe y que no se puede condicionar sobre él. Con ese grafo, ningún conjunto de variables observadas bloquea el camino $"educ" <- U -> "lwage"$, así que el criterio de la puerta trasera no identifica el efecto. Lo que sí hace el grafo es declarar que `nearc4` es un instrumento: no tiene flechas desde $U$ ni hacia el resultado, salvo a través de `educ`, y en el grafo sin la flecha $"educ" -> "lwage"$ queda $d$-separado de `lwage`. Ese es el estimando por variable instrumental que debe devolver `identify_effect`. Además, el DAG no incluye la experiencia potencial como causa de la educación: con la definición habitual (edad menos educación menos seis) es función del tratamiento, y tratarla como covariable previa, como se advirtió en el @cap-ingenieria-datos-causales, invalida el grafo.

=== PC con causal-learn y NOTEARS con la implementación de referencia
<sec-cap29_notears_py>

La librería #code[causal-learn] (implementación Python del Tetrad original) provee implementaciones eficientes de PC, FCI, GES y LiNGAM, pero no de NOTEARS. Para NOTEARS usamos la implementación de referencia de #cite(<zheng2018dags>, form: "prose"), distribuida como paquete #code[notears] en su repositorio público (`pip install git+https://github.com/xunzheng/notears`).

#figure(
  kind: raw,
  caption: [PC con causal-learn y NOTEARS con la implementación de referencia.],
  ```python
import numpy as np
import pandas as pd
from causallearn.search.ConstraintBased.PC import pc
from notears.linear import notears_linear  # implementación de referencia (Zheng et al.)

# --- Datos sintéticos ---
rng = np.random.default_rng(42)
n, d = 1000, 5
# Estructura: X0 -> X1 -> X2, X3 -> X2, X4 aislada
W_true = np.zeros((d, d))
W_true[0, 1] = 2.0; W_true[1, 2] = 1.5; W_true[3, 2] = 1.0
E = rng.standard_normal((n, d))
I = np.eye(d)
X = E @ np.linalg.inv(I - W_true)
df = pd.DataFrame(X, columns=[f"X{i}" for i in range(d)])

# --- PC ---
pc_graph = pc(df.values, alpha=0.05, indep_test="fisherz", show_progress=False)
print(pc_graph.G)  # CPDAG estimada (aristas --- sin orientar, --> orientadas)

# --- NOTEARS ---
W_est = notears_linear(df.values, lambda1=0.05, loss_type="l2")
print("W estimado (NOTEARS):\n", np.round(W_est, 2))

# --- Sensibilidad a la escala: misma corrida sobre datos estandarizados ---
Z = (df - df.mean()) / df.std()
W_std = notears_linear(Z.values, lambda1=0.05, loss_type="l2")
print("W estimado (NOTEARS, estandarizado):\n", np.round(W_std, 2))
```
) <lst-notears>

La función #code[pc] de #code[causal-learn] implementa el algoritmo completo con los tres pasos (esqueleto, colisionadores, reglas de Meek). El argumento #code[indep_test] permite elegir entre tests paramétricos (#code[fisherz]) y no paramétricos (#code[kci], #code[chisq]). NOTEARS, en cambio, es sensible a la escala de las variables, como muestra el caso canónico de la varsortability. La verificación se hizo con una reimplementación fiel de `notears_linear` (`herramientas/verificaciones/notears_ref.py`) y con la semilla del listado; en la escala original las varianzas muestrales fueron 1,0 para $X_0$, 5,3 para $X_1$ y 13,7 para $X_2$. La simulación de la regla de parada de PC está en `herramientas/verificaciones/verif_cap29.py`. La figura del caso de estudio se genera con `herramientas/figuras/fig_cap29_dag.py`, que estima los pesos con la misma reimplementación.
]

== Caso empírico y validación
<sec-cap29_caso_empirico>

=== Evaluación de grafos estimados
<sec-cap29_evaluacion_grafos>

Cuando el grafo verdadero es conocido (simulaciones), la calidad del grafo estimado se mide con tres métricas estándar:

- *SHD (Structural Hamming Distance):* número de inserciones, eliminaciones y reorientaciones de aristas que hacen falta para convertir el grafo estimado en el verdadero. Es una métrica global que penaliza errores de omisión, de comisión y de dirección.
- *Precisión:* proporción de aristas orientadas del grafo estimado que existen, con esa dirección, en el grafo verdadero. Mide qué tan confiable es cada arista que el algoritmo reporta.
- *Recall:* proporción de aristas verdaderas que el algoritmo logra recuperar, con su dirección. Mide qué tan completo es el descubrimiento.

Un ejemplo exacto fija las convenciones. En la cadena del caso canónico anterior ($X_0 arrow.r X_1 arrow.r X_2 arrow.l X_3$, con $X_4$ aislada), un PC ideal, con un oráculo de independencia, devuelve la CPDAG $X_0 - X_1$, $X_1 arrow.r X_2$, $X_3 arrow.r X_2$: la arista $X_0 - X_1$ queda sin orientar porque ambas direcciones son equivalentes de Markov. Contra el DAG verdadero su SHD es 1 (una reorientación pendiente), su precisión es 1,00 (las dos aristas orientadas son correctas) y su recall es 0,67 (dos de las tres aristas verdaderas recuperadas con su dirección). NOTEARS lineal sobre los datos en su escala original recupera las tres aristas orientadas y tiene SHD 0, precisión 1,00 y recall 1,00. El resultado de NOTEARS no es una ventaja del método: es el efecto de la escala, como muestra el caso canónico de la varsortability.

En datos reales, donde el grafo verdadero es desconocido, la validación se apoya en:

- *Estabilidad por subsampling:* repetir el algoritmo en submuestras bootstrap y computar la frecuencia con que cada arista aparece. Aristas con baja frecuencia (menos del 50 %) son sospechosas de espurias.
- *Análisis de sensibilidad:* variar $alpha$ (en PC) o $lambda$ (en NOTEARS) y observar cómo cambia la estructura. Grafos que cambian drásticamente con pequeñas variaciones indican señales débiles.
- *Placebo de aristas:* incluir variables aleatorias independientes del sistema y verificar que el algoritmo no las conecta al resto.

=== Caso de estudio: DAGs y descubrimiento causal

La figura #ref(<fig-cap29-dag>, supplement: none) muestra dos elementos complementarios. El panel izquierdo presenta un DAG explícito, supuesto por el analista, para el problema del retorno a la educación (Card, 1995), donde $U$ representa un confusor no observado (habilidad) que afecta tanto a la educación como al salario. El panel derecho muestra el grafo estimado por NOTEARS sobre datos sintéticos con estructura conocida (la cadena del caso canónico anterior, con una variable aislada).

#figure(
  image("../figuras/fig_cap29_dag.png", width: 100%),
  caption: [Elaboración propia. Izquierda: DAG supuesto para el retorno a la educación, basado en Card (1995); $U$ denota un confusor no observado. Derecha: DAG ponderado estimado por NOTEARS sobre datos sintéticos con estructura conocida ($X_0 arrow.r X_1$, $X_1 arrow.r X_2$, $X_3 arrow.r X_2$, y $X_4$ aislada); las etiquetas en las aristas son los pesos estimados.],
) <fig-cap29-dag>

*Interpretación.* El DAG del panel izquierdo formaliza la estructura causal supuesta: la proximidad a una universidad afecta la educación pero no directamente el salario (exclusión); el confusor no observado $U$ (habilidad) afecta a ambos, generando el sesgo de variable omitida que justifica el uso de variables instrumentales. El panel derecho muestra que NOTEARS recupera la estructura sobre datos sintéticos de escala favorable. Con datos económicos reales, aplicar un método de descubrimiento requiere cuidado: el supuesto de causal sufficiency raramente se satisface y el grafo estimado debe interpretarse como una guía exploratoria, no como evidencia definitiva.

#intuicion[
*Caja de profundización: d-separation y cómo evaluar un grafo estimado*

*Objetivo.* Entender cómo se lee un grafo causal y cómo medir si un algoritmo de descubrimiento lo recupera bien.

*d-separation: una forma de leer el grafo.* Decimos que un conjunto $Z$ "bloquea" un camino entre $X$ e $Y$ si:
- El camino tiene una *secuencia* ($X arrow.r Z arrow.r Y$ o $X arrow.l Z arrow.l Y$): $Z$ debe estar en el conjunto.
- El camino tiene un *fork* ($X arrow.l Z arrow.r Y$): $Z$ debe estar en el conjunto.
- El camino tiene un *collider* ($X arrow.r Z arrow.l Y$): $Z$ NO debe estar en el conjunto (ni ninguno de sus descendientes).

Si todos los caminos entre $X$ e $Y$ están bloqueados, $X perp perp Y | Z$.

*Evaluación de grafos estimados.* Cuando simulamos datos con un grafo verdadero, podemos comparar:
- *SHD (Structural Hamming Distance):* cuántas aristas (presentes, ausentes o mal orientadas) difieren entre el grafo verdadero y el estimado.
- *Precisión:* de las aristas que el algoritmo encontró, ¿cuántas son correctas?
- *Recall:* de las aristas verdaderas, ¿cuántas encontró el algoritmo?

*Métodos de descubrimiento.*
- *PC:* usa tests de independencia condicional. Bueno si hay suficientes datos.
- *FCI:* permite variables latentes (no observadas).
- *GES:* busca el grafo que maximiza un criterio de ajuste penalizado.
- *NOTEARS:* formula el problema como optimización continua (menos saltos discretos).
]

== Riesgos, límites y sensibilidad
<sec-cap29_riesgos>

=== Tabla de riesgos

#riesgos[
  #figure(
    caption: [Riesgos en descubrimiento causal y grafos],
    table(
      columns: (1.1fr, 1.4fr, 1.4fr, 1.4fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Causal sufficiency falsa], [Grafo sesgado: se omiten aristas o se introducen aristas espurias por la presencia de confusores no observados que afectan a múltiples variables], [Comparar resultados con FCI (no asume sufficiency); análisis de sensibilidad ante la posible presencia de _latent confounders_], [Usar FCI en lugar de PC cuando haya sospecha de variables latentes; reportar siempre el supuesto y discutir su plausibilidad en el contexto aplicado],
      [Faithfulness débil], [Independencias condicionales engañosas: una arista verdadera se elimina porque el test de independencia no la detecta (cancelación de caminos opuestos)], [Realizar tests de independencia con múltiples umbrales ($alpha = 0.01, 0.05, 0.10$) y verificar si la estructura es estable], [Usar tests no paramétricos (KCI) cuando las relaciones sean no lineales; aumentar $n$ si es posible; aplicar bootstrap de aristas para evaluar estabilidad],
      [Sobreajuste estructural], [Aristas espurias: el algoritmo detecta dependencias que son ruido muestral, especialmente con $p$ grande relativo a $n$], [Subsampling: repetir el algoritmo en $B$ submuestras bootstrap y retener solo aristas con frecuencia mayor que 70 %], [Regularización: aumentar $alpha$ en PC (grafos más dispersos) o $lambda$ en NOTEARS; usar BIC como criterio de selección de modelo; validar con hold-out],
      [Escala y orden de las variables], [El método de optimización continua explota la regularidad de escala (varsortability) y orienta mal las aristas], [Repetir la corrida con y sin estandarización y comparar las orientaciones], [Reportar solo las aristas cuya dirección sobrevive a ambas escalas; no confiar en la orientación como evidencia causal],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cap15>
]

=== Límites del descubrimiento causal

Causal discovery en economía es difícil por la presencia ubicua de confusores no observados. Los métodos son útiles como _exploración_ de estructura, no como reemplazo del razonamiento económico sustantivo. Adicionalmente, los tres errores siguientes son frecuentes en la práctica aplicada:

+ *Interpretar la CPDAG como DAG.* PC produce una clase de equivalencia; algunas aristas no se pueden orientar observacionalmente. Presentar el grafo como si todas las aristas estuvieran dirigidas induce una falsa certeza sobre la direccionalidad causal.
+ *Aplicar NOTEARS sin normalizar variables.* NOTEARS es sensible a escala; conviene estimar la matriz de pesos con y sin estandarización (media cero, varianza uno) y reportar ambas. Este punto es más grave de lo que sugiere su formulación como consejo de preprocesamiento: en un modelo lineal-gaussiano, reescalar las variables cambia el grafo que el criterio de NOTEARS considera óptimo, de modo que el "descubrimiento" puede estar reflejando las unidades de medida y no la estructura causal.
+ *Usar un solo umbral de significación.* La elección de $alpha$ en PC (o $lambda$ en NOTEARS) tiene un efecto grande sobre la densidad del grafo. Reportar siempre un análisis de sensibilidad con múltiples valores.

*Sobre el tercer punto, con más peso del que suele dársele.* #cite(<machlanski2024robustness>, form: "prose") evalúan sistemáticamente la sensibilidad de los algoritmos de descubrimiento a sus hiperparámetros y encuentran que el efecto de esa elección es *comparable o mayor* que las diferencias entre algoritmos: el ranking de métodos publicado en un _benchmark_ puede invertirse ajustando los hiperparámetros de forma distinta pero igualmente razonable. La implicación metodológica es incómoda y conviene asumirla: buena parte de las comparaciones "algoritmo A supera a algoritmo B" en esta literatura no es replicable fuera de la configuración exacta del estudio original.

Para la práctica de #solo-curso[este curso]#solo-comercial[este libro] se siguen dos reglas. Primera, *ningún grafo descubierto se reporta como un objeto único*: se reporta la familia de grafos obtenida al variar $alpha$ (o $lambda$) en un rango declarado, y las aristas se clasifican por su estabilidad a través de esa familia y de submuestras bootstrap. Segunda, *el output del descubrimiento no alimenta directamente la estimación*: una arista descubierta es una hipótesis para discutir con conocimiento de dominio, no un supuesto de identificación validado. Dejar que un algoritmo de descubrimiento fije el conjunto de puerta trasera que luego usará el DML es trasladar al algoritmo exactamente la responsabilidad que el @cap-scm-pch demostró que no puede tener.

== Ejercicios propuestos
<sec-cap29_ejercicios>

=== Ejercicios teóricos
<sec-cap29_ejercicios_teoricos>

+ Construya un DAG para el efecto de dejar de fumar sobre el peso, justificando cada arista. Identifique un conjunto de control mediante el criterio de puerta trasera del @cap-intervencion-contrafactual.

+ Dado el DAG $X arrow.r Z arrow.l Y$, ¿qué CPDAG devuelve un PC con oráculo? ¿Y para $X arrow.r Z arrow.r Y$? Explique por qué en el segundo caso ninguna arista puede orientarse.

+ Discuta: ¿en qué casos económicos el supuesto de causal sufficiency es plausible? Dé tres ejemplos donde no lo es.

+ Muestre, con el DAG del caso canónico de la regla de parada, que parar en el primer nivel sin eliminaciones es incorrecto. ¿Qué par de variables queda mal conectado y con qué conjunto separador se elimina?

#capa-impl[
=== Ejercicios computacionales
<sec-cap29_ejercicios_computacionales>

+ Aplique NOTEARS a un dataset sintético con 5 variables y estructura conocida, con y sin estandarización. ¿Recupera la estructura en cada caso?

+ Use #code[dowhy] para identificar el efecto de #code[educ] sobre #code[lwage] bajo tres DAGs distintos. ¿Cómo cambia el set de control recomendado?

+ Construya el DAG del ejercicio teórico 1 con #code[networkx] y compruebe el conjunto de control con la prueba de $d$-separación.
]

== Lecturas complementarias
<sec-cap29_lecturas>

#cite(<pearl2009causality>, form: "prose") es la referencia canónica para DAGs, $d$-separación y clases de equivalencia. #cite(<spirtes2000causation>, form: "prose") introduce el algoritmo PC y el marco de descubrimiento basado en restricciones; #cite(<kalisch2007estimating>, form: "prose") establece su consistencia en alta dimensión y es la referencia a citar cuando se aplica PC con $p$ grande. #cite(<chickering2002optimal>, form: "prose") demuestra la consistencia de GES y es la entrada a la familia de métodos basados en score, complementaria a las otras dos. #cite(<zheng2018dags>, form: "prose") reformulan el problema como optimización continua con la restricción de aciclicidad diferenciable (NOTEARS).

Sobre los límites prácticos del campo, #cite(<machlanski2024robustness>, form: "prose") documentan la sensibilidad a hiperparámetros discutida en la @sec-cap29_riesgos y son lectura obligada antes de tomar cualquier _benchmark_ de descubrimiento al pie de la letra; #cite(<reisach2021beware>, form: "prose") documentan el efecto de la escala en los métodos de optimización continua.#capa-impl[ #cite(<sharma2020dowhy>, form: "prose") documenta #code[dowhy]. Para la implementación en Python, #code[causal-learn] (#link("https://github.com/py-why/causal-learn")[https://github.com/py-why/causal-learn]) es la librería de referencia, con implementaciones de PC, FCI, GES y otros algoritmos de descubrimiento causal.]
