// Capítulo 26: Generalización y transportabilidad entre dominios. Cierra la Parte VI.
// Edición en capas: la teoría (L0), el procedimiento (L1) y los casos canónicos con cifras verificadas (L2)
// son lo que dura; el listado (L3) va dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Generalización y transportabilidad entre dominios]
<cap-generalizacion-transportabilidad>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Determinar si un efecto estimado en un dominio es válido en otro],
    [*Estimando:*], [El efecto en el dominio destino, $P^*(y | "do"(x))$],
    [*Identificación:*], [Diagrama de selección: qué mecanismos difieren entre dominio fuente y destino, y qué variables se miden en el destino],
    [*Método:*], [Teoría de transportabilidad (Pearl y Bareinboim); en el caso simple, reponderación por la distribución de las covariables del destino],
    [*Garantía:*], [Si el efecto es transportable, existe una fórmula que lo calcula combinando datos de ambos dominios; si no lo es, ningún ajuste con esos datos lo recupera],
    ..if not es-principios {([*Librerías:*], [Sin implementación estándar madura; el listado usa numpy y pandas])},
    [*Validación:*], [Muestra de resultados en el destino cuando sea posible; sensibilidad a diferencias de mecanismo no modeladas],
  )
]

== Problema causal, estimando e identificación
<sec-generalizacion-problema>

La ficha del modelo causal (@cap-model-card-causal) declara la población de entrenamiento y advierte que el modelo no debe usarse fuera de ella. Este capítulo formaliza qué significa "fuera de esa población" y bajo qué condiciones, ni nunca ni siempre, un efecto estimado en un dominio puede aplicarse legítimamente en otro. La noción informal de validez externa, tratada casi siempre de forma cualitativa en la econometría aplicada, tiene una versión formal y verificable en el marco de la PCH: la *transportabilidad*.

La pregunta importa en producción por una razón simple. Un sistema se entrena y se valida en un dominio y opera en otro, porque la población cambia, porque se abre un mercado nuevo o porque el tiempo pasa. La teoría dice qué hace falta saber del dominio nuevo, y cuánto, para que el efecto estimado siga siendo una guía.

== Teoría, supuestos y garantías
<sec-generalizacion-teoria>

=== Diagramas de selección
<sec-generalizacion-diagramas>

#definition(name: [Diagrama de selección])[
Un *diagrama de selección* es un grafo causal aumentado con nodos especiales $S$, uno por cada mecanismo que se sospecha difiere entre el dominio fuente $Pi$ y el dominio destino $Pi^*$, con una flecha $S_i arrow.r V_i$ que indica que el mecanismo que genera $V_i$ puede diferir entre dominios. Las variables sin nodo $S$ entrante comparten el mismo mecanismo generador en ambos dominios.
]

Por ejemplo, si un efecto se estimó en una población urbana ($Pi$) y se quiere aplicar a una rural ($Pi^*$), y se sospecha que la distribución de ingresos difiere entre ambas pero el mecanismo por el cual el ingreso afecta al resultado es el mismo, el diagrama tiene un nodo $S$ que apunta a la variable de ingreso (su *distribución* difiere) y ninguno que apunte a la ecuación estructural que relaciona ingreso con resultado (su *mecanismo* es el mismo). Dibujar ese diagrama obliga a declarar, variable por variable, qué se supone igual y qué se supone distinto, y es la parte del análisis que ninguna estimación sustituye.

=== Qué puede decirse del efecto en el destino
<sec-generalizacion-transportabilidad>

#definition(name: [Efecto transportable])[
Dado un diagrama de selección, el efecto $P^*(y | "do"(x))$ en el dominio destino es *transportable* desde el dominio fuente si existe una fórmula que lo expresa en términos de (i) cantidades estimables con datos experimentales o cuasi-experimentales del dominio fuente $Pi$ y (ii) cantidades observacionales del dominio destino $Pi^*$, típicamente la distribución de las variables a las que apunta algún nodo $S$.
]

El marco de los diagramas de selección y el término *transportabilidad* se introducen en #cite(<pearl2011transportability>, form: "prose"). El resultado central de @bareinboimpearl2013transportability es un algoritmo *completo*, análogo al cálculo-$"do"$ del @cap-intervencion-contrafactual, que determina para cualquier diagrama de selección si el efecto es transportable y, si lo es, produce la fórmula de transporte explícita. La completitud tiene aquí el mismo valor operativo que allá: si el algoritmo responde que no, ninguna técnica de reponderación, adaptación de dominio o ajuste de covariables recupera el efecto en el destino con esos datos y ese diagrama.

El caso simple y frecuente es el que se usa en el resto del capítulo. Sea $Z$ un conjunto de covariables medidas en ambos dominios y supóngase que los únicos nodos $S$ del diagrama apuntan a variables de $Z$: cambia su distribución, no ningún mecanismo.

#proposition(name: [Fórmula de transporte con una covariable])[
  Si el tratamiento es aleatorio en la fuente y los únicos nodos $S$ entrantes lo hacen a variables de $Z$, de modo que $Y perp perp S | Z, "do"(X)$ ($Z$ es *$S$-admisible*), entonces
  $
  P^*(y | "do"(x)) = sum_z P(y | "do"(x), z) thin P^*(z),
  $
  y en particular $"ATE"^* = sum_z "ATE"(z) thin P^*(z)$. La fórmula exige soporte: todo valor $z$ con $P^*(z) > 0$ debe tener $P(z) > 0$, porque de lo contrario no hay efecto condicional en la fuente que reponderar.
]
#proof(kind: "sketch")[
  Como $S$ solo apunta a $Z$, dado $Z$ el mecanismo que genera $Y$ bajo la intervención es el mismo en ambos dominios, de modo que $P^*(y | "do"(x), z) = P(y | "do"(x), z)$. La fórmula sigue de la ley de la probabilidad total bajo $P^*$. El efecto condicional se estima con el experimento de la fuente y $P^*(z)$ con datos del destino, sin resultados del destino.
]

Es el resultado de #cite(<pearl2014external>, form: "prose") para el caso en que $S$ apunta solo a una covariable. Los efectos que varían con $z$ son los que dependen de la reponderación: si el efecto condicional es el mismo en todo estrato, el efecto transportado es el de la fuente y la reponderación no cambia nada.

La reponderación se puede escribir también con pesos. Si $R = 1$ indica el dominio destino y $R = 0$ la fuente, el peso de una unidad de la fuente con covariables $x$ es
$
w(x) = frac(P(R = 1 | x), P(R = 0 | x)) dot.op frac(P(R = 0), P(R = 1)),
$
que equivale a la razón de densidades $P^*(x) \/ P(x)$ y cumple $E_Pi [w(X)] = 1$. Los odds de pertenencia sin la corrección por la proporción de cada muestra no suman uno y sesgan la reponderación.

Hay dos casos que la literatura nombra de forma distinta y que se confunden con facilidad. La *transportabilidad* pregunta si un efecto estimado en un dominio $Pi$ vale en un dominio $Pi^*$ *distinto*. La *generalización* pregunta algo más específico: si un efecto estimado sobre una *muestra seleccionada*, como los participantes de un ensayo o los clientes que aceptaron una oferta, vale para la población de la que se extrajo, cuando la selección no fue aleatoria. Es el caso en que el nodo $S$ apunta a un indicador de selección muestral y no a un mecanismo del dominio destino, y el resultado que lo cubre es la recuperación del sesgo de selección de #cite(<bareinboim2014selection>, form: "prose"). La distinción importa en producción: el @cap-monitoreo-causal vigila la deriva entre dominios (transportabilidad), mientras que la ficha de procedencia del @cap-datos-entrenamiento-causales documenta el sesgo de selección del que depende la generalización. Son dos amenazas distintas, con diagnósticos distintos.

#cite(<correa2020general>, form: "prose") extienden el marco a *intervenciones suaves*: acciones que no fijan una variable a un valor constante sino que modifican su mecanismo, como cambiar la regla de asignación de un subsidio en vez de dárselo a todos. Es la forma que toma la mayoría de las decisiones de política reales y la que el @cap-decisiones-estructurales formaliza como decisión estructural. Su resultado, también completo, es el que corresponde invocar cuando la pregunta no es si este efecto vale allá sino si esta *política* vale allá.

=== Por qué esto no es lo mismo que reestimar con más datos
<sec-generalizacion-noreesestimar>

Conviene distinguir la transportabilidad de dos prácticas más simples. No es lo mismo que *agrupar los datos de ambos dominios y reestimar*: si los mecanismos efectivamente difieren, agrupar sin más introduce sesgo, no lo elimina. Tampoco es lo mismo que *reentrenar el modelo con datos del dominio destino*, la opción por defecto en un sistema puramente predictivo (@cap-anatomia-sistema): reentrenar requiere datos etiquetados del destino, que con frecuencia no existen. Es la situación en la que la teoría de transportabilidad aporta algo que el _machine learning_ estándar no ofrece, porque permite, bajo el diagrama correcto, extrapolar sin resultados del destino.

== Procedimiento: evaluar la transportabilidad de un efecto
<sec-generalizacion-algoritmo>

#algorithm("Evaluación de la transportabilidad")[
  #kwin[Entrada][Efecto estimado en la fuente, descripción de la fuente y del destino, variables medidas en cada dominio.]
  #kwout[Salida][Veredicto de transportabilidad, fórmula de transporte y estimación con su cobertura, o lista de lo que falta medir.]
  Declarar la pregunta (un efecto o una política) y los dos dominios. \
  Dibujar el diagrama de selección: para cada variable, decir si su mecanismo o su distribución puede diferir, y por qué. \
  Decidir si el efecto es transportable; en el caso simple, comprobar que los nodos $S$ apuntan solo a covariables medidas en ambos dominios. \
  Si lo es, derivar la fórmula y comprobar el soporte: qué fracción del destino cae en valores observados en la fuente. \
  Estimar con reponderación por estratos o por pesos de dominio, y reportar la cobertura. \
  Si no lo es, decidir entre medir más variables en el destino, obtener resultados del destino o acotar con supuestos explícitos. \
  #return-stmt[Diagrama, fórmula, estimación, cobertura y sensibilidad a un mecanismo no anticipado, registrados en la ficha del modelo (@cap-model-card-causal).]
] <alg-transportabilidad>

El paso del diagrama es el único sin forma estadística, y es el que decide el resto. Dos analistas con los mismos datos y diagramas distintos llegan a veredictos distintos, y los datos no bastan para zanjar cuál diagrama es el correcto.

== Casos canónicos y validación
<sec-generalizacion-caso>

Los tres casos comparten un proceso con verdad conocida: $Y = 0.4 D + b thin D X + 0.5 X + epsilon$, con el tratamiento aleatorizado en la fuente, $X tilde N(0, 1)$ en la fuente y $X tilde N(1, 1.5^2)$ en el destino. Con $b = 0.3$ el efecto verdadero es $0.4 + 0.3 E[X]$: 0,4 en la fuente y 0,7 en el destino. Las cifras provienen de simulaciones con muestras de 20~000 observaciones por dominio, promediadas sobre 30 repeticiones.#capa-impl[ El script es #code[herramientas/verificaciones/verif_cap26.py].]

#caso-canonico("Reponderar por la covariable que difiere")[
  La diferencia de medias ingenua en la fuente da 0,40 y subestima el efecto en el destino. Reponderar los efectos por estrato con la distribución de $X$ en el destino da 0,59 con 5 estratos, 0,63 con 10, 0,65 con 20 y 0,67 con 50, contra una verdad de 0,70. Mejora con los estratos porque el efecto varía dentro de cada uno, y no llega a 0,70 porque los estratos extremos, abiertos, reciben una masa grande del destino, que es más disperso. Con pesos de un clasificador de dominio el promedio es 0,72, pero con una desviación entre repeticiones de 0,18, diez veces la de los estratos: con un destino más disperso que la fuente, los pesos tienen varianza infinita en teoría y enorme en la práctica.
]

#caso-canonico("Soporte: lo que la fuente no vio")[
  Se quita de la fuente su quintil más alto de $X$. Solo el 46 % del destino cae en estratos observados. Reponderar solo sobre esos estratos y renormalizar da 0,32, que coincide con el efecto verdadero de esa parte del destino (0,31). El efecto del destino completo es 0,70, y ningún método lo recupera desde esa fuente sin un supuesto adicional sobre cómo se comporta el efecto donde la fuente no tiene datos. Descartar esos estratos sin renormalizar subestimaría el efecto en la misma proporción, de modo que la cobertura se reporta y la fórmula se aplica solo a lo cubierto.
]

#caso-canonico("Un mecanismo que cambió no se ve desde la fuente")[
  En el destino el término de interacción es $b = 0.5$ en vez de 0,3, de modo que el efecto verdadero es $0.4 + 0.5 times 1 = 0.9$. El estimador reponderado usa solo los resultados de la fuente y las covariables del destino, ninguno de los cuales cambió, y devuelve 0,67 (50 estratos). Un error de más de 0,2 que ninguna estadística calculada con esos datos puede delatar: es el caso de un nodo $S$ que apunta a $Y$ y que el diagrama no declaró. Solo una muestra de resultados del destino lo revela.
]

El estimador de retorno a la educación de Card (1995), usado en varios capítulos del curso, se estimó en una población de hombres jóvenes de Estados Unidos, con salarios de 1976. Aplicarlo a otro país o a otra década exige preguntarse explícitamente si el mecanismo por el cual la educación afecta al salario (productividad, señalización, redes) es razonablemente estable entre esos dominios o si solo difiere la distribución de las covariables. En el primer caso ninguna fórmula simple lo resuelve y el efecto no es transportable sin supuestos adicionales fuertes; en el segundo, una reponderación como la del caso 1 podría ser defendible.

#capa-impl[
== Implementación en Python
<sec-generalizacion-implementacion>

#figure(
  kind: raw,
  caption: [Efecto transportado por reponderación de estratos, con cobertura del destino.],
  ```python
import warnings
import numpy as np
import pandas as pd


def efecto_transportado(df_fuente, df_destino, estrato, tratamiento, resultado):
    """Efecto por estrato en la fuente (tratamiento aleatorio) ponderado por la
    distribucion del estrato en el destino. Devuelve (efecto, cobertura): la cobertura
    es la fraccion del destino que cae en estratos observados en la fuente."""
    por_estrato = (
        df_fuente.groupby(estrato)
        .apply(lambda g: g.loc[g[tratamiento] == 1, resultado].mean()
                         - g.loc[g[tratamiento] == 0, resultado].mean())
        .dropna()
    )
    peso = df_destino[estrato].value_counts(normalize=True)
    comunes = por_estrato.index.intersection(peso.index)
    cobertura = peso[comunes].sum()
    if cobertura < 1:
        warnings.warn(f"Solo el {cobertura:.1%} del destino cae en estratos observados en la fuente.")
    return (por_estrato[comunes] * peso[comunes]).sum() / cobertura, cobertura


# Datos simulados: mismo mecanismo en ambos dominios, distinta distribucion de X
rng = np.random.default_rng(0)
n = 20_000
fuente = pd.DataFrame({"X": rng.normal(0, 1, n), "D": rng.binomial(1, 0.5, n)})
fuente["Y"] = 0.4 * fuente.D + 0.3 * fuente.D * fuente.X + 0.5 * fuente.X + rng.standard_normal(n)
destino = pd.DataFrame({"X": rng.normal(1, 1.5, n)})

# La covariable continua se discretiza con los mismos bordes en ambos dominios
bordes = [-np.inf, *fuente["X"].quantile(np.linspace(0, 1, 21)[1:-1]), np.inf]
for df in (fuente, destino):
    df["estrato"] = pd.cut(df["X"], bordes, labels=False)

efecto, cobertura = efecto_transportado(fuente, destino, "estrato", "D", "Y")
ingenuo = fuente.loc[fuente.D == 1, "Y"].mean() - fuente.loc[fuente.D == 0, "Y"].mean()
print(f"ingenuo={ingenuo:.3f}  transportado={efecto:.3f}  cobertura={cobertura:.2f}  (verdad del destino: 0.70)")
assert abs(ingenuo - 0.4) < 0.1 and 0.58 < efecto < 0.75 and cobertura == 1.0   # coherencia
```
) <lst-transporte-reponderacion>

El listado es el caso particular más simple y no el teorema general: es válido bajo un diagrama de selección donde $S$ apunta solo a la covariable de estratificación. La función avisa y reporta la cobertura en lugar de descartar en silencio los estratos del destino que la fuente no observó. Para covariables continuas o de dimensión alta, la reponderación por estratos cede su lugar a los pesos de un clasificador de dominio, con la advertencia del caso 1 sobre su varianza.
]

== Riesgos, límites y sensibilidad
<sec-generalizacion-riesgos>

#riesgos[
  #set text(size: 9pt)
  #figure(
    caption: [Riesgos al transportar un efecto entre dominios.],
    table(
      columns: (1.3fr, 1.5fr, 1.4fr, 1.6fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Asumir transportabilidad sin diagrama], [Equivale a un diagrama vacío no argumentado], [¿Hay un diagrama escrito y revisado?], [Escribirlo y declarar lo que se supone igual],
      table.hline(stroke: 0.4pt),
      [Leer "no hay evidencia de que difiera" como "no difiere"], [La falta de análisis se toma por evidencia a favor], [¿Qué se midió en el destino?], [Medir las covariables clave y una muestra de resultados],
      table.hline(stroke: 0.4pt),
      [Mecanismo cambiado y no declarado], [Error grande sin señal en los datos disponibles (caso 3)], [Comparar resultados del destino con los transportados], [Muestra de resultados del destino; sensibilidad],
      table.hline(stroke: 0.4pt),
      [Falta de soporte], [Se extrapola donde la fuente no tiene datos (caso 2)], [Cobertura del destino por estratos observados], [Reportar solo lo cubierto; no renormalizar en silencio],
      table.hline(stroke: 0.4pt),
      [Pesos con varianza enorme], [Estimación inestable cuando el destino es más disperso (caso 1)], [Distribución de los pesos y tamaño efectivo de muestra], [Estratos, recorte con sesgo declarado o ampliar la fuente],
      table.hline(stroke: 0.4pt),
      [Estratos demasiado gruesos], [Sesgo por heterogeneidad dentro del estrato (caso 1)], [Estimación con 5, 10, 20 y más estratos], [Refinar los estratos o modelar el efecto condicional],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cap26>
]

*Límites.* La fórmula de transporte es válida para las diferencias que declara el diagrama, y cualquier diferencia de mecanismo no anticipada la invalida. El algoritmo completo cubre casos donde el mecanismo mismo difiere y la fórmula combina cantidades experimentales de la fuente con observacionales del destino, y excede el alcance de este capítulo; la ausencia de una reponderación simple no equivale a la ausencia de transportabilidad.

== Ejercicios y notas bibliográficas
<sec-generalizacion-ejercicios>

=== Ejercicios teóricos
<sec-generalizacion-ejercicios-teoricos>

+ Para el ejemplo de la @sec-generalizacion-diagramas (población urbana y rural), dibuje el diagrama de selección descrito y explique qué habría que medir en el dominio rural para aplicar la fórmula de transporte.

+ Explique por qué reentrenar el modelo con datos del dominio destino no es una opción disponible en muchos de los casos de uso reales que motivan la teoría de transportabilidad.

+ Muestre con el proceso de los casos canónicos que el efecto verdadero del destino es $0.4 + 0.3 E^*[X]$, y que la fórmula de transporte da ese valor cuando los estratos son infinitesimalmente finos. ¿Qué ocurre con $b = 0$?

+ Demuestre que $E_Pi [w(X)] = 1$ para los pesos de dominio de la @sec-generalizacion-transportabilidad y que $E_Pi [w(X)^2]$ es infinita cuando el destino es normal con una varianza suficientemente mayor que la de la fuente. ¿A partir de qué cociente de varianzas ocurre, si las medias coinciden?

#capa-impl[
=== Ejercicio computacional
<sec-generalizacion-ejercicios-computacionales>

+ Con el proceso de los casos canónicos y el #ref(<lst-transporte-reponderacion>, supplement: [listado]), compare el efecto transportado con el efecto verdadero del destino y con la diferencia de medias ingenua de la fuente, y repita con 5, 10, 20 y 50 estratos. ¿Por qué mejora el resultado al aumentar los estratos? Luego quite de la fuente el estrato más alto y observe la cobertura. Con $b = 0$, el efecto es constante: ¿qué aprende de la reponderación en ese caso?
]

=== Notas bibliográficas
<sec-generalizacion-notas>

#cite(<pearl2011transportability>, form: "prose") introducen los diagramas de selección, y #cite(<pearl2014external>, form: "prose") desarrollan la fórmula de transporte que justifica la reponderación de este capítulo. #cite(<bareinboimpearl2013transportability>, form: "prose") establecen el algoritmo de decisión completo para transportabilidad, y #cite(<correa2020general>, form: "prose") lo extienden a intervenciones suaves, el caso relevante cuando lo que se quiere transportar es una política y no un efecto puntual. #cite(<bareinboim2025causalai>, form: "prose") presenta los tres de forma integrada con el resto de la Jerarquía Causal de Pearl. La noción informal de validez externa en econometría aplicada, con la que conviene contrastar este tratamiento formal, se discute en @imbens2015causal. Sobre la relación con el reentrenamiento en un sistema en producción, véanse el @cap-aprendizaje-continuo (cuándo actualizar) y el @cap-monitoreo-causal (cómo detectar que el dominio cambió).
