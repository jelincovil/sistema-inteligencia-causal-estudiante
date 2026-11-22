// Capítulo 18: Diseño de investigación y selección de método
// Edición en capas: el mapa de decisión (L0 y L1) y los casos resueltos (L2) son lo que dura;
// la función de ejemplo (L3) va dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Diseño de investigación y selección de método]
<cap-mapa-decision>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Elegir el diseño causal apropiado según las características del problema],
    [*Estimando:*], [ATE, ATT, CATE, LATE, valor de una política],
    [*Identificación:*], [No confusión, validez de instrumentos, continuidad local, tendencias paralelas, combinación convexa],
    [*Método:*], [Mapa de decisión basado en el estimando, el diseño y los supuestos],
    [*Nuisance:*], [Dimensión ($p$ frente a $n$), heterogeneidad, endogeneidad, estructura temporal],
    [*Garantía:*], [Identificación bajo los supuestos propios de cada diseño; orden por credibilidad típica del supuesto],
    ..if not es-principios {([*Librerías:*], [DoubleML, econml, causalml, statsmodels])},
    [*Validación:*], [Placebos, sensibilidad a supuestos, diseño preregistrado],
  )
]

#notatecnica[
Este capítulo cierra la Parte III sintetizando los tres diseños de identificación completos del libro (la doble selección del @cap-pds, el DML de panel e instrumental del @cap-panel-dmliv y el DML no estructurado de la Parte II, @cap-dml) en un único mapa de decisión, y anticipa los diseños de heterogeneidad y _targeting_ de la Parte V.
]

== Motivación aplicada
<sec-cap18_motivacion>

Un analista del Banco Central recibe un encargo: estimar el efecto causal de una política monetaria sobre la inflación. Dispone de datos mensuales de diez años y de 30 covariables macroeconómicas, y la política se implementó en distintos momentos en distintos países. ¿Qué método usar? ¿DML? ¿Diferencias en diferencias? ¿Control sintético? ¿Bosques causales? ¿Alguno de ellos?

La elección metodológica es la decisión más importante de la inferencia causal aplicada. Un método inadecuado produce estimaciones sesgadas y conclusiones equivocadas por muy sofisticada que sea su implementación. Este capítulo no presenta métodos nuevos: organiza los ya vistos en un _mapa de decisión_ que conecta las características del problema (estimando, diseño, dimensión, heterogeneidad, instrumentos) con el método apropiado, y declara con franqueza qué parte de la decisión el mapa no puede tomar.

== Problema causal, estimando e identificación
<sec-cap18_problema_causal>

=== Dimensiones del problema causal

Todo problema causal aplicado puede caracterizarse en seis dimensiones que determinan la identificabilidad del efecto y el método apropiado:

+ *Dimensión de los controles $p$ frente al tamaño muestral $n$.* Si $p << n$ y las relaciones son aproximadamente lineales, OLS clásico basta. Si $p$ es comparable a $n$ o mayor, se requieren métodos de alta dimensión (doble selección, DML).
+ *Heterogeneidad del efecto.* Si el efecto se asume constante, el modelo lineal parcial es suficiente. Si hay heterogeneidad estructurada, se requieren el modelo interactivo, los meta-learners o los bosques causales.
+ *Endogeneidad del tratamiento.* Si se asume no confusión, aplican los métodos de selección sobre observables (_matching_, IPW, DML). Si hay endogeneidad por variables no observadas, se requieren instrumentos o diseños cuasi-experimentales (discontinuidad en la regresión, diferencias en diferencias).
+ *Estructura temporal.* Corte transversal, panel, serie temporal o adopción escalonada determinan la elección entre métodos.
+ *Disponibilidad de instrumentos.* Con un instrumento válido, IV o DML-PLIV. Sin él, hay que justificar la no confusión o usar métodos de sensibilidad.
+ *Objetivo de la estimación.* ATE, ATT, CATE, valor de una política o LATE son estimandos distintos y requieren métodos distintos.

=== Estimando e identificación

El estimando define qué cantidad poblacional se quiere aprender. Los más frecuentes son:

- *ATE* $= E[Y(1) - Y(0)]$: efecto promedio en toda la población. Identificable bajo no confusión y soporte común.
- *ATT* $= E[Y(1) - Y(0) | D = 1]$: efecto en los tratados. Solo requiere no confusión para el resultado sin tratamiento, $Y(0) perp perp D | X$.
- *CATE* $= E[Y(1) - Y(0) | X = x]$: efecto condicional en covariables. Requiere no confusión dentro de cada subgrupo.
- *LATE* $= E[Y(1) - Y(0) | "cumplidores"]$: efecto local en los cumplidores. Identificable con un instrumento relevante, con exclusión y monotonía.
- *Valor de una política* $= E[Y(pi(X))]$: valor de una regla de asignación. Se estima con aprendizaje de políticas (@cap-policy-learning).

La identificación, esto es, expresar el estimando como función de la distribución observada, depende de supuestos propios de cada diseño. La @tab-identificacion-jerarquica resume el supuesto clave de cada uno y qué tan creíble suele ser.

== Teoría, supuestos y garantías
<sec-cap18_teoria_supuestos>

=== Mapa de decisión metodológica

La @tab-decision-map organiza el mapa según diseño, dimensión y heterogeneidad, y empareja cada combinación con el método clásico y su contraparte de ML.

#figure(
  caption: [Mapa de decisión metodológica.],
  table(
    columns: (1.3fr, 1fr, 1fr, 1.4fr, 1.5fr),
    align: (left, left, left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Diseño*], [*Dimensión*], [*Heterog.*], [*Método clásico*], [*Método ML*]),
    table.hline(stroke: 0.4pt),
    [Corte transversal], [$p << n$], [No], [OLS], [No hace falta],
    [Corte transversal], [$p ~ n$], [No], [Doble selección], [DML con modelo lineal parcial],
    [Corte transversal], [$p << n$], [Sí], [Subgrupos ad hoc], [Meta-learners, bosque causal],
    [Corte transversal], [$p ~ n$], [Sí], [Sin equivalente simple], [DML interactivo, bosque causal],
    [IV], [$p << n$], [No], [2SLS], [No hace falta],
    [IV], [$p ~ n$], [No], [Doble selección con IV], [DML-PLIV],
    [Discontinuidad], [No aplica], [No], [Polinomio local], [Con ML solo para covariables],
    [Diferencias en diferencias], [No aplica], [No], [TWFE con un solo momento de adopción], [Sin ML necesario],
    [Panel con adopción escalonada], [No aplica], [No], [Callaway y Sant'Anna, Sun y Abraham, DiD sintético (nunca TWFE)], [Matrix completion],
    [Panel con $X_(i t)$], [$p ~ n$], [No], [Efectos fijos con controles], [DML de panel],
    [Optimización de políticas], [No aplica], [Sí], [Sin equivalente], [Aprendizaje de políticas, uplift],
    table.hline(stroke: 0.8pt),
  )
) <tab-decision-map>

=== Identificación jerárquica de diseños

Los diseños no tienen la misma _fuerza de identificación_. La @tab-identificacion-jerarquica los ordena por la credibilidad típica del supuesto clave que los sostiene. El orden es una regla general y no una ley: un instrumento con una exclusión dudosa puede ser menos creíble que un diseño de diferencias en diferencias con tendencias previas que se ven paralelas.

#figure(
  caption: [Identificación jerárquica de diseños causales (credibilidad típica del supuesto clave).],
  table(
    columns: (1.4fr, 1fr, 2.5fr),
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Diseño*], [*Credibilidad típica*], [*Supuesto clave y su contrastabilidad*]),
    table.hline(stroke: 0.4pt),
    [Experimento aleatorizado], [Alta], [Aleatorización. Se verifica con el balance de covariables y el cumplimiento],
    [Discontinuidad en la regresión], [Alta], [Continuidad de los resultados potenciales en el umbral. Se contrasta con densidad y covariables alrededor del corte],
    [Variables instrumentales], [Media a alta], [Relevancia (se contrasta) y exclusión (no se contrasta)],
    [Diferencias en diferencias], [Media], [Tendencias paralelas sin tratamiento. Se contrasta solo en los periodos previos],
    [Control sintético], [Media], [Combinación convexa de unidades no tratadas que reproduzca el contrafactual],
    [No confusión (selección sobre observables)], [Media a baja], [Ausencia de confusores no observados. No se contrasta; solo se analiza su sensibilidad],
    table.hline(stroke: 0.8pt),
  )
) <tab-identificacion-jerarquica>

Un diseño de mayor credibilidad requiere supuestos más creíbles y produce, por tanto, estimaciones más robustas. Al elegir, conviene priorizar el diseño de mayor credibilidad que sea factible con los datos disponibles.

=== Un procedimiento de decisión en el orden correcto

El mapa se usa en un orden que importa: primero el estimando y el diseño, después la dimensión y la heterogeneidad, y al final el estimador.

#algorithm("Selección de diseño y método")[
  #kwin[Entrada][Pregunta causal, estimando deseado, descripción de cómo se asignó el tratamiento y de los datos disponibles.]
  #kwout[Salida][Diseño de identificación, estimador y plan de validación.]
  Fijar el estimando (ATE, ATT, CATE, LATE, valor de una política) y la población a la que se aplicará. \
  *if* hubo aleatorización o una regla de asignación conocida con umbral *then* usar el diseño experimental o de discontinuidad. \
  *else if* hay un instrumento defendible (relevante y con exclusión argumentada) *then* usar IV o DML-PLIV y reportar el $F$ y el intervalo de Anderson-Rubin. \
  *else if* hay variación temporal o entre unidades con unidades tratadas y no tratadas *then* usar diferencias en diferencias o control sintético, con adopción escalonada tratada con estimadores robustos. \
  *else* asumir no confusión y justificarla con el diagrama causal; elegir el estimador por $p$ frente a $n$ y por la heterogeneidad (tabla del mapa). \
  Preregistrar el diseño y el estimador antes de ver los resultados. \
  Plan de validación: placebos, sensibilidad a los supuestos clave, comparación con un diseño de menor credibilidad. \
  #return-stmt[Diseño, estimador, plan de validación y supuestos por declarar.]
] <alg-seleccion-diseno>

=== Criterios adicionales de selección

Más allá del mapa y la jerarquía, tres criterios refinan la elección.

*Calidad de los controles.* Si los controles son ruidosos o están mal medidos, los métodos de ML, que los usan de forma intensiva, pueden empeorar la estimación. En ese caso son preferibles los diseños que dependen menos de $X$ (diferencias en diferencias, discontinuidad).

*Tamaño muestral.* La heterogeneidad se estima con mucho menos precisión que el efecto promedio. Con unos pocos cientos de observaciones, los métodos más parsimoniosos (OLS, _matching_, meta-learners simples) suelen ser preferibles a los bosques causales o a las redes profundas, cuya ventaja aparece con más datos. No hay un umbral universal, y la simulación con efecto conocido (@cap-prediccion-causalidad) es la forma de saber cuánto es "suficiente" en un caso concreto.

*Costo computacional y de mantenimiento.* Un método más complejo se paga también en operación: más tiempo de cómputo, más piezas que monitorear y más difícil de explicar. Esa carga debe compararse con la ganancia de credibilidad o de precisión.

#intuicion[
  *Caja de profundización: discontinuidad en la regresión y transportabilidad*

  *Objetivo.* Completar el mapa con dos temas adicionales.

  *Discontinuidad en la regresión.* Cuando el tratamiento se asigna según un umbral $c$ de una variable continua (por ejemplo, una beca para quienes obtienen más de 70 puntos), se compara a quienes quedaron justo arriba con quienes quedaron justo abajo. Es un experimento local alrededor del corte:
  $
  tau_"RD" = lim_(x -> c^+) E[Y | X = x] - lim_(x -> c^-) E[Y | X = x].
  $
  Si el umbral no se cumple de manera perfecta (algunos de abajo reciben el tratamiento y algunos de arriba no), el diseño es _difuso_ y se convierte en un diseño de variables instrumentales con el umbral como instrumento. El efecto es local en el corte y no se extrapola a otros puntos.

  *Transportabilidad.* Si un modelo se entrena con una población (Santiago), ¿sirve para otra (Temuco)? Dos situaciones son distintas: un _cambio en la distribución de covariables_, con el mismo mecanismo causal, que se puede corregir reponderando; y un _cambio de mecanismo_, donde la relación entre $X$, $D$ e $Y$ es otra, que ninguna reponderación corrige. Los diagramas de selección ayudan a decidir cuál es el caso (@cap-generalizacion-transportabilidad).
]

== Casos resueltos
<sec-cap18_casos>

Cuatro casos recorren el procedimiento. En ninguno la decisión es automática: cada uno termina con la lista de supuestos que el analista debe declarar.

*Caso 1: retorno a la educación con proximidad a la universidad como instrumento.* Escolaridad sobre salario, $n$ de unos pocos miles y pocos controles, con un instrumento candidato (vivir cerca de una universidad). Hay un instrumento relevante, el diseño es de corte transversal y no hay heterogeneidad que sea el objetivo: IV con 2SLS y controles pretratamiento, sin usar como control la experiencia potencial (que es función de la escolaridad, @cap-ingenieria-datos-causales). DML-PLIV solo si hubiera muchos controles o relaciones no lineales. Se declara la exclusión (la cercanía a una universidad no afecta el salario salvo por la escolaridad) y se reporta el $F$ de primera etapa y la sensibilidad a esa exclusión.

*Caso 2: política monetaria con adopción escalonada entre países.* Datos mensuales de diez años, 30 covariables, política adoptada en momentos distintos por pocos países. Hay variación temporal y entre unidades, adopción escalonada y pocas unidades tratadas: estimadores robustos a la adopción escalonada o control sintético (@cap-panel-dmliv, @cap-scm-mc), nunca TWFE, con un _event study_ como primer paso. La no confusión no se asume: se asume tendencias paralelas condicionales, que se contrasta en los periodos previos.

*Caso 3: beca con tratamiento aleatorizado y heterogeneidad.* Experimento con $n = 20~000$ y 50 covariables. La identificación está resuelta por el diseño. La decisión es sobre la estimación de la heterogeneidad: con muestra grande, un bosque causal o un DML interactivo (@cap-causal-forests), validado con curvas Qini y calibración (@cap-validacion), y luego aprendizaje de políticas si hay restricción presupuestaria (@cap-policy-learning).

*Caso 4: reforma tributaria con datos observacionales.* Panel de firmas, 100 covariables, $n = 800$, sin aleatorización ni instrumento. Se asume no confusión condicional, la más débil de las identificaciones. Con $p$ del orden de $n$, se usa la doble selección o DML con modelo lineal parcial (@cap-pds, @cap-dml), y la conclusión se acompaña de un análisis de sensibilidad a confusores no observados y de un placebo.

=== Validación de la elección metodológica

Para cada caso, la elección debe validarse con:
- *Placebo del tratamiento:* asignar un tratamiento falso y verificar que el estimador no encuentra efecto.
- *Sensibilidad a supuestos:* variar el método dentro del mismo diseño (distintos $K$ de _cross-fitting_, distintos _learners_) y verificar la estabilidad.
- *Comparación con diseños más débiles:* si es posible, estimar con un diseño de menor credibilidad y documentar la diferencia.

#capa-impl[
== Implementación en Python
<sec-cap18_implementacion>

La función siguiente codifica un primer descarte con umbrales ilustrativos. Es una ayuda para ordenar la conversación y no reemplaza al análisis de identificación; los umbrales ($p > 0.5 n$, $n < 1~000$) no tienen una justificación teórica y deben ajustarse al contexto.

#figure(
  kind: raw,
  caption: [Función de decisión metodológica (heurística de primer descarte).],
  ```python
def choose_method(n, p, has_iv, is_panel, has_heterogeneity, treatment_staggered=False):
    """Devuelve el método recomendado según las características del problema.

    ADVERTENCIA: es una heurística de primer descarte, no un sustituto del análisis
    de identificación. Presupone que la pregunta causal, el estimando y el grafo ya
    están definidos. Los umbrales son ilustrativos.
    """
    if is_panel and treatment_staggered:
        # Estimadores robustos a la adopción escalonada; nunca TWFE (pesos negativos).
        return ("Callaway-Sant'Anna / Sun-Abraham; DiD sintético "
                "o matrix completion si hay pocas unidades tratadas")
    if is_panel:
        return "DML-panel con transformación within" if p > 0.5 * n else "Efectos fijos con controles"
    if has_iv:
        return "DML-PLIV" if p > 0.3 * n else "2SLS clásico"
    if has_heterogeneity:
        return "Meta-learners (T o X)" if n < 1000 else "Bosque causal"
    if p > 0.3 * n:
        return "DML con modelo lineal parcial"
    return "Doble selección con LASSO" if p > 50 else "OLS con controles (HC1)"


if __name__ == "__main__":
    # Pruebas de coherencia con los casos del texto.
    assert "DML-PLIV" in choose_method(2000, 800, True, False, False)
    assert "Callaway" in choose_method(200, 10, False, True, False, treatment_staggered=True)
    assert choose_method(3000, 15, True, False, False) == "2SLS clásico"
    assert choose_method(500, 80, False, False, True) == "Meta-learners (T o X)"
```
) <lst-decision-map>
]

== Errores comunes y límites
<sec-cap18_errores>

#riesgos[
  #set text(size: 9pt)
  #figure(
    caption: [Riesgos comunes en la elección metodológica.],
    table(
      columns: (1.5fr, 1.5fr, 1.5fr, 1.8fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Usar ML cuando los métodos clásicos bastan], [Complejidad innecesaria, pérdida de interpretabilidad, más piezas que mantener], [$p << n$ y linealidad razonable], [OLS con errores robustos],
      table.hline(stroke: 0.4pt),
      [Usar DML sin justificar la no confusión], [Estimaciones sesgadas por una endogeneidad no resuelta], [Posibles confusores no observados], [IV, discontinuidad, diferencias en diferencias o control sintético; análisis de sensibilidad],
      table.hline(stroke: 0.4pt),
      [Cambiar de método según los resultados (_specification mining_)], [Sesgo de selección; inferencia inválida], [Elección metodológica posterior a ver los datos], [Preregistrar el diseño; elegir el método antes de estimar],
      table.hline(stroke: 0.4pt),
      [Tomar la jerarquía de credibilidad como ley], [Preferir un diseño de "alta" credibilidad con un supuesto indefendible en el caso concreto], [Argumentar los supuestos del caso, no del tipo de diseño], [Declarar la exclusión, la continuidad o las tendencias paralelas con evidencia del contexto],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cap18>
]

*Límites.* El mapa es orientativo. Los casos límite (panel con adopción escalonada y heterogeneidad, IV con muchos instrumentos débiles, discontinuidad con covariables de alta dimensión) requieren un análisis experto que el mapa no reemplaza.

Hay además un límite de fondo que conviene explicitar, porque la existencia de una función de selección invita a olvidarlo. El mapa organiza la elección del *estimador* dando por resuelta la de la *identificación*, que es la parte difícil del problema. Las seis dimensiones de la @sec-cap18_problema_causal son observables en los datos: $n$, $p$, si hay panel, si hay un instrumento candidato. Las condiciones que determinan la validez del resultado no lo son: si las covariables observadas cierran las rutas de puerta trasera, si el instrumento satisface la exclusión, si las tendencias habrían sido paralelas. Ningún argumento del mapa captura eso, y ninguna heurística puede. La jerarquía de la @tab-identificacion-jerarquica ordena los diseños por la credibilidad típica de esos supuestos precisamente porque es lo que el mapa no puede decidir. Elegir DML en lugar de OLS mejora la flexibilidad de la estimación, pero un diseño de mayor credibilidad, cuando los datos lo permiten, mejora algo que ninguna cantidad de flexibilidad compensa.

== Ejercicios propuestos
<sec-cap18_ejercicios>

+ Recomiende un método y declare los supuestos que debe argumentar en cada uno de los cinco problemas: (a) efecto de un experimento aleatorizado sobre el rendimiento escolar ($n = 5~000$, $p = 10$); (b) efecto de una reforma tributaria sobre la inversión ($n = 800$, $p = 100$); (c) efecto de un programa social sobre la pobreza con adopción escalonada en un panel; (d) efecto de un medicamento sobre la presión arterial con un instrumento; (e) efecto heterogéneo de becas sobre la deserción ($n = 20~000$, $p = 50$).

+ Justifique por qué DML no es adecuado cuando hay confusión no observada. ¿Qué alternativas existen y qué supuestos nuevos exigen?

+ Discuta en qué casos el bosque causal es preferible al R-learner y viceversa.

+ Construya un ejemplo en el que un instrumento con exclusión dudosa sea menos creíble que un diseño de diferencias en diferencias con tendencias previas paralelas, y explique qué evidencia cambiaría el orden.

#capa-impl[
+ Ejecute las pruebas de coherencia del #ref(<lst-decision-map>, supplement: [listado]) y agregue dos casos propios donde la heurística recomiende un método que usted no usaría, explicando por qué.
]

== Lecturas complementarias
<sec-cap18_lecturas>

#cite(<athey2019econometric>, form: "prose") ofrece una revisión moderna de los métodos. #cite(<imbens2015causal>, form: "prose") es la referencia canónica para los métodos clásicos. #cite(<chernozhukov2018applied>, form: "prose") es la referencia para DML. #cite(<athey2017beyond>, form: "prose") aporta una perspectiva de política.
