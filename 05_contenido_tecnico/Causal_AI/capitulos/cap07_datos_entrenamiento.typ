// Capítulo 7 (nuevo): Datos de entrenamiento en sistemas causales
// Plantilla B: Sesión 6. Edición en capas: la ficha de procedencia, el chequeo de balance (con su criterio y sus errores típicos)
// y el caso canónico (capas L1, L2 y L0) son lo que dura; el listado y el ejercicio computacional (capa L3) van dentro de
// #capa-impl, y lo que es solo del curso va en #solo-curso.
#import "../template/template.typ": *

#chapter[Datos de entrenamiento en sistemas causales]
<cap-datos-entrenamiento-causales>

#theorem-number-reset()

#cuadrodecision[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Decisión:*], [Tratar la asignación del tratamiento como parte del proceso de muestreo a auditar, no como un dato dado],
    [*Alternativas:*], [Usar los datos "tal como llegan" vs. auditar explícitamente el mecanismo de asignación],
    [*Trade-off clave:*], [Velocidad de arranque vs. riesgo de sesgo de selección no detectado],
    ..if not es-principios {([*Stack:*], [pandas, `pandera`, tests de balance])},
    [*Riesgo principal:*], [Confundir "faltante al azar" con "faltante por selección relacionada al tratamiento"],
  )
]

== El problema de diseño
<sec-datosentrenamiento-problema>

#cite(<huyen2022dmls>, form: "prose") dedica su Capítulo 4 a una idea que la comunidad de _machine learning_ tarda en internalizar: los datos de entrenamiento casi nunca son una muestra aleatoria simple del universo sobre el que luego se aplicará el modelo, y cómo se generaron (el proceso de muestreo, cómo se etiquetó, qué faltó y por qué) determina la validez de cualquier cosa que se entrene sobre ellos. En un sistema *causal* este problema no es solo una amenaza a la precisión predictiva: es una amenaza directa a la *identificación*. Si la asignación del tratamiento en los datos históricos está relacionada con variables no observadas, ningún ajuste posterior por covariables observadas, por sofisticado que sea el estimador, corrige el problema. El problema de diseño de este capítulo es entonces: ¿cómo se estructuran la recolección y el muestreo de los datos de entrenamiento para que las amenazas a la identificación queden documentadas y, cuando sea posible, mitigadas, en lugar de descubrirse después de haber estimado el efecto?

No es un problema que se resuelva una sola vez. Un sistema desplegado genera él mismo la asignación de los datos futuros (@cap-anatomia-sistema), de modo que cada reentrenamiento hereda una asignación que condicionó el sistema anterior. La auditoría de este capítulo se repite en cada reentrenamiento y se reutiliza como señal de monitoreo (@cap-monitoreo-causal).

== Opciones y trade-offs
<sec-datosentrenamiento-opciones>

#opciones[
  - *Usar los datos "tal como llegan".* Se toma el conjunto de datos disponible y se procede directamente a la estimación. Es la opción más rápida y, en la práctica, la más común. El riesgo es que el mecanismo de asignación del tratamiento (quién decidió, con qué información, a quién tratar) quede completamente implícito, y que cualquier sesgo de selección relacionado con variables no observadas nunca se detecte porque nadie lo buscó explícitamente.
  - *Auditar el mecanismo de asignación antes de estimar.* Se documenta explícitamente, para el conjunto de datos en cuestión: ¿la asignación fue aleatorizada, cuasi-aleatorizada (por ejemplo, un umbral administrativo) u observacional pura? ¿Qué información tenía quien decidió asignar el tratamiento, y coincide con las covariables observadas en los datos? Este paso no reemplaza el análisis de identificación de los capítulos anteriores: lo *precede*, y a menudo revela qué covariables son plausiblemente suficientes para el criterio de puerta trasera antes de intentar ajustar ningún modelo.
]

Un segundo trade-off, heredado de la discusión de #cite(<huyen2022dmls>, form: "prose") sobre "etiquetas naturales", es específico de los sistemas causales. En muchos casos el "tratamiento" es una decisión que ya ocurrió en el pasado dentro de un proceso administrativo o de negocio (a quién se le otorgó un crédito, a quién se le dio un descuento). Estas asignaciones pasadas tienen la ventaja de estar disponibles a bajo costo, pero la desventaja de que la regla de decisión histórica, a menudo no documentada, es exactamente la fuente potencial de confusión que el análisis de identificación debe descubrir.

== #t-decision
<sec-datosentrenamiento-decision>

El libro exige que todo conjunto de datos usado para estimar vaya acompañado de una *ficha de procedencia del tratamiento*, una extensión del esquema de datos del @cap-ingenieria-datos-causales que documenta, como mínimo: el mecanismo de asignación (aleatorizado, cuasi-experimental u observacional), la relación temporal entre la asignación y la medición del resultado, y cualquier regla de elegibilidad conocida. Completar la ficha es un requisito previo a cualquier estimación#solo-curso[, y es parte de la entrega del Notebook de caso de estudio A1 (@cap-ingenieria-datos-causales)]. Es la versión operacional del "problema causal, estimando e identificación" que abre cada capítulo de Plantilla A.

La ficha de procedencia no se queda en un cuaderno de trabajo. El mecanismo de asignación es el tipo de diseño de identificación que declara la ficha del modelo (@cap-model-card-causal), y la fuente de los datos es lo que esa ficha registra junto con su huella. Cuando la ficha de procedencia cambia (otra regla de elegibilidad, otro canal de asignación), el modelo entrenado con los datos anteriores deja de tener una procedencia válida, aunque su código no haya cambiado.

== El chequeo de balance
<sec-datosentrenamiento-balance>

La herramienta mínima para auditar el mecanismo de asignación es el *chequeo de balance*: comparar la distribución de cada covariable entre tratados y controles. Aquí conviene ser preciso sobre qué estadístico usar, porque la elección por defecto, un $t$-test por covariable, es la equivocada por dos razones independientes.

Primero, el $t$-test responde la pregunta incorrecta. Su $p$-valor mezcla el tamaño de la diferencia con el tamaño de la muestra: con $n$ grande, diferencias irrelevantes resultan "significativas"; con $n$ pequeño, desbalances severos pasan el test. Pero lo que amenaza la identificación es la *magnitud* del desbalance (cuánta extrapolación tendrá que hacer el estimador) y no si esa magnitud es distinguible de cero. El estadístico apropiado es por tanto una medida de tamaño de efecto, la *diferencia media estandarizada* (SMD, también llamada _standardized bias_):
$
"SMD"_j = (overline(X)_(j,1) - overline(X)_(j,0)) / sqrt((s_(j,1)^2 + s_(j,0)^2) \/ 2),
$
que es invariante a las unidades de medida y no crece con $n$. #cite(<rubin2001using>, form: "prose") propone dos criterios operativos que se han vuelto convencionales: $|"SMD"_j| < 0.25$ (por convención, más exigente, $< 0.1$) y una razón de varianzas $s_(j,1)^2 \/ s_(j,0)^2$ dentro de $[0.5, 2]$. El segundo criterio importa y suele olvidarse: dos grupos pueden tener la misma media y distribuciones tan distintas en dispersión que el soporte común sea escaso en las colas, lo que compromete el supuesto de solapamiento antes que el de no confusión.

Segundo, si aun así se reportan $p$-valores (y hay una razón legítima para hacerlo cuando la asignación *debería* haber sido aleatoria, como en la submuestra experimental de un RCT), evaluar $p$ covariables al 5 % produce por construcción $approx 0.05 p$ rechazos espurios. Con 40 covariables, esperar dos "desbalances significativos" bajo aleatorización perfecta es lo normal, no una anomalía. Cualquier lectura del chequeo debe corregir por comparaciones múltiples (Holm o Benjamini–Hochberg) o, mejor, apoyarse en la distribución completa de las SMD.

#caso-canonico("Cuarenta covariables y dos mecanismos de asignación")[
  Cuarenta covariables independientes, normales estándar. En el primer mecanismo el tratamiento se asigna con una moneda justa. Se simulan 200 experimentos de 500 unidades y en cada uno se cuenta cuántas covariables rechaza el $t$-test al 5 %. En el segundo, 2 000 unidades reciben el tratamiento con probabilidad $sigma(1.2 X_0)$, es decir, la asignación depende solo de $X_0$.

  Bajo aleatorización perfecta, el $p$-valor crudo rechazó en 1,98 covariables por experimento en promedio, y con la corrección de Holm en 0,05. Con asignación que depende de $X_0$, la $"SMD"$ de esa covariable fue 1,12, la bandera del criterio de 0,25 se activó solo para ella y ninguna de las otras 39 la activó.
]

Un número alto de covariables desbalanceadas no invalida por sí solo el análisis observacional (es, de hecho, la situación esperada cuando la asignación no fue aleatoria) y, sobre todo, *no es el chequeo el que identifica el efecto*: el balance en las covariables observadas no dice nada sobre las no observadas, que son las que rompen la no confusión. Lo que el chequeo aporta es más modesto y más útil: cuantifica cuánta corrección tendrá que hacer el estimador, y por tanto cuánto de la estimación final descansará en extrapolación del modelo en vez de en comparaciones respaldadas por datos. Una SMD de 1,5 en una covariable relevante advierte que el estimador comparará poblaciones con poco solapamiento efectivo, mucho antes de que un diagnóstico de _propensity score_ lo revele en el @cap-dml.

Dos lecturas específicas del reporte merecen atención. Si covariables que *deberían* ser irrelevantes para la asignación (por ejemplo, una característica administrativa sin relación aparente con el criterio de elegibilidad) resultan fuertemente desbalanceadas, es señal de que el mecanismo de asignación real difiere del documentado, y amerita revisar el DAG propuesto antes de proceder. Y si el porcentaje de faltantes difiere sistemáticamente entre tratados y controles, el problema ya no es de balance sino de selección sobre quién aparece en los datos. Si la ausencia depende de variables observadas, se puede corregir reponderando. Si depende del propio resultado no observado, el faltante es no aleatorio en el sentido de #cite(<rubin1976inference>, form: "prose") y ningún ajuste por covariables observadas lo corrige.

El mismo chequeo se reutiliza más adelante con otro propósito. Aplicado a datos de entrenamiento contra una ventana reciente, es la primera señal del monitoreo (@cap-monitoreo-causal). Aplicado a los datos de un modelo reentrenado contra los de la versión vigente, es la comparación de poblaciones de la regla de promoción (@cap-aprendizaje-continuo). En los dos casos el umbral se calibra con muestras de la misma población y no se hereda de la convención.

== El contrato de la comparación de poblaciones
<sec-datosentrenamiento-contrato>

El chequeo de balance no sirve solo para este capítulo. El libro lo usa con tres pares de poblaciones: tratados y controles (aquí), datos de entrenamiento y ventana reciente (@cap-monitoreo-causal) y versión vigente y datos de un candidato (@cap-aprendizaje-continuo). Lo que se fija es la comparación de poblaciones, con el formato del C-01 (@sec-datoscausales-contrato), de modo que los tres usos compartan sus reglas.

#contrato(
  "C-02",
  "Comparación de poblaciones",
  operaciones: [
    _comparar_: recibe dos poblaciones de unidades, descritas por las covariables del esquema (C-01), y devuelve para cada covariable la diferencia media estandarizada, la razón de varianzas y una bandera por cada criterio.
  ],
  entrada: [
    Las dos poblaciones, con las covariables del esquema. Los criterios: el umbral de la diferencia estandarizada y el intervalo admitido para la razón de varianzas, escritos antes de mirar los datos y calibrados para el tamaño de las muestras (regla del @sec-monitoreo-decision).
  ],
  salida: [
    Una fila por covariable con la diferencia estandarizada (con signo), la razón de varianzas y las dos banderas. Si se piden $p$-valores, se corrigen por comparaciones múltiples y se rotulan como secundarios.
  ],
  invariantes: [
    (1) El estadístico principal mide tamaño de efecto y no crece con el número de unidades; ningún $p$-valor decide por sí solo. (2) Intercambiar las poblaciones cambia el signo de la diferencia, invierte la razón de varianzas y deja las banderas igual. (3) Con las mismas poblaciones el resultado es idéntico. (4) El umbral se calibra con muestras de una misma población y se fija antes de comparar; no se hereda de la convención. (5) Los valores faltantes no entran en el cálculo, así que una diferencia en la proporción de faltantes entre las poblaciones no aparece en la comparación y se mide aparte. (6) La comparación habla solo de covariables observadas.
  ],
  fallos: [
    Una muestra pequeña con el umbral de la convención: la bandera se enciende con ruido. Un umbral relajado después de ver el resultado. Un $p$-valor no significativo leído como ausencia de desbalance. Un faltante diferencial que la comparación no ve. Un balance perfecto en lo observado leído como prueba de que no hay confusión.
  ],
  aceptacion: [
    (a) Se reproduce el caso canónico de este capítulo: con la moneda justa los rechazos crudos rondan el 5 % de las covariables y los de Holm casi no aparecen, y con asignación que depende de $X_0$ se activa la bandera de $X_0$ y ninguna otra. (b) Intercambiar las poblaciones cumple el invariante (2). (c) Con dos muestras de una misma población, la frecuencia de banderas se mide y se compara con la que dio la calibración; con una muestra pequeña y el umbral de la convención, supera a la calibrada. (d) Con un faltante diferencial inyectado y sin diferencias en lo observado, la comparación no señala nada y la medida aparte sí.
  ],
)

*Tamaño de efecto y no $p$-valor.* Lo que amenaza la identificación es cuánta extrapolación tendrá que hacer el estimador, no si esa magnitud se distingue de cero. Un estadístico que crece con $n$ cambia de veredicto cuando cambia el tamaño de la muestra, y las tres comparaciones del libro se hacen con muestras de tamaños muy distintos.

*El umbral se calibra y se fija antes.* El valor de 0,25 es un punto de partida razonable para decidir qué desbalance importaría, pero con pocas unidades la diferencia entre dos muestras de la misma población ya lo supera con frecuencia. Medir esa frecuencia, y escribir el umbral antes de comparar, evita relajarlo hasta que el resultado sea el esperado.

*Solo lo observado.* El contrato dice con todas las letras que no cubre las covariables que nadie midió ni la selección sobre quién aparece en los datos. Si no lo dijera, un chequeo limpio se leería como una garantía de identificación.

#capa-impl[
== Implementación de referencia
<sec-datosentrenamiento-implementacion>

El listado calcula, para cada covariable, la SMD, la razón de varianzas, el $p$-valor crudo y el ajustado por Holm, y las dos banderas de los criterios anteriores.

#figure(
  kind: raw,
  caption: [Chequeo de balance: SMD, razón de varianzas y $p$-valores con corrección de Holm.],
  ```python
import numpy as np
import pandas as pd
from scipy.stats import ttest_ind


def chequeo_balance(df, tratamiento, covariables, smd_max=0.25, razon_var=(0.5, 2.0)):
    """Balance entre tratados y controles. Devuelve una fila por covariable con la
    diferencia media estandarizada (SMD), la razon de varianzas, el p-valor crudo
    y el p-valor ajustado por Holm, mas las dos banderas de los criterios de Rubin."""
    T, C = df[df[tratamiento] == 1], df[df[tratamiento] == 0]
    filas = []
    for c in covariables:
        v_t, v_c = T[c].var(), C[c].var()
        filas.append({
            "covariable": c,
            "smd": (T[c].mean() - C[c].mean()) / np.sqrt((v_t + v_c) / 2),
            "razon_var": v_t / v_c,
            "p_crudo": ttest_ind(T[c], C[c], equal_var=False).pvalue,
        })
    r = pd.DataFrame(filas).set_index("covariable")
    # Holm: p ordenados, cada uno por (m - rango), forzando monotonia y truncando a 1
    orden = r["p_crudo"].sort_values()
    m = len(orden)
    holm = np.minimum(1.0, np.maximum.accumulate(orden.to_numpy() * (m - np.arange(m))))
    r["p_holm"] = pd.Series(holm, index=orden.index)
    r["viola_smd"] = r["smd"].abs() > smd_max
    r["viola_razon_var"] = ~r["razon_var"].between(*razon_var)
    return r

# Uso: resumen = chequeo_balance(df, esquema.treatment, esquema.covariates)   (esquema: C-01, Cap. 4)
#      print(resumen.round(3)); print(resumen[["viola_smd", "viola_razon_var"]].sum())
```
) <lst-chequeo-balance>

El ajuste de Holm del listado coincide con una implementación independiente, y las cifras del caso canónico salen de una simulación con semilla declarada que ejecuta este mismo listado. Está en `herramientas/verificaciones/verif_cap07.py`.
]

== #t-aplicacion
<sec-datosentrenamiento-aplicacion>

#cite(<lalonde1986>, form: "prose") comparó las estimaciones de métodos econométricos observacionales contra el _benchmark_ experimental del programa NSW y encontró que diferían sustancialmente, el resultado que fundó la literatura moderna de evaluación de programas. #cite(<dehejia1999causal>, form: "prose") reexaminaron el mismo caso construyendo la extensión observacional (submuestras de CPS y PSID como controles) que sigue siendo el banco de pruebas estándar del campo.

Su utilidad pedagógica aquí es que ofrece los dos regímenes con el mismo tratamiento y el mismo resultado. La submuestra experimental tiene asignación aleatorizada por diseño, y el chequeo de balance debería mostrar SMD pequeñas. La extensión observacional no la tiene, y las tablas descriptivas de #cite(<dehejia1999causal>, form: "prose") muestran grupos de comparación muy distintos de los tratados, de modo que el mismo chequeo debería mostrar SMD grandes en varias covariables. Aplicar el chequeo a ambas versiones y comparar las dos distribuciones de SMD es la forma más directa de ver, en números y no en abstracto, qué significa que un conjunto de datos sea o no "como aleatorizado".#solo-curso[ El Notebook A1 usa este caso por esa razón.]

== Señales de alerta y checklist operativo
<sec-datosentrenamiento-alertas>

#checklist[
  - Nadie en el equipo puede explicar, en una oración, cómo se decidió históricamente quién recibía el tratamiento.
  - No se ejecutó ningún chequeo de balance de covariables antes de estimar el efecto, o no se repite en cada reentrenamiento.
  - Existen valores faltantes en el resultado $Y$ que están sistemáticamente relacionados con el tratamiento (posible sesgo de selección en el seguimiento, no solo en la asignación).
  - La ficha de procedencia del tratamiento no distingue si la asignación fue anterior o posterior a la medición de alguna covariable "de control".
  - La ficha de procedencia no se actualizó cuando cambió la regla de asignación, y el modelo vigente sigue declarando la procedencia anterior.
  - Se reporta el $p$-valor del $t$-test por covariable sin corrección por comparaciones múltiples, o se lee un desbalance "no significativo" en una muestra pequeña como ausencia de desbalance.
]

== Ejercicios y notas bibliográficas
<sec-datosentrenamiento-ejercicios>

=== Ejercicios conceptuales
<sec-datosentrenamiento-ejercicios-conceptuales>

+ Para el conjunto de datos de becas del @cap-causalidad-elemental, redacte una ficha de procedencia del tratamiento hipotética, incluyendo el mecanismo de asignación más plausible.

+ Explique por qué un desbalance fuerte en una covariable *administrativa, sin relación aparente con el criterio de elegibilidad* es una señal de alerta más seria que un desbalance en una covariable directamente relacionada con dicho criterio.

+ Un sistema reentrena cada mes con los datos del mes anterior, en los que la asignación la decidió el modelo vigente. Explique qué esperaría ver en el chequeo de balance de esos datos y qué le diría sobre la identificación; piense en el solapamiento si la regla del modelo vigente es determinista.

#capa-impl[
=== Ejercicio computacional
<sec-datosentrenamiento-ejercicios-computacionales>

+ Aplique el #ref(<lst-chequeo-balance>, supplement: [listado]) a las dos versiones del conjunto de datos de Lalonde (experimental y observacional). Reporte, para cada una, la distribución de SMD y cuántas covariables violan cada criterio de Rubin, y relacione el resultado con el mecanismo de asignación de cada submuestra.

+ Sobre la submuestra *experimental* (donde la asignación fue aleatoria por diseño), compare cuántas covariables resultan "significativas" con $p$ crudo al 5 % frente a cuántas lo son con la corrección de Holm. Explique por qué el primer número no es evidencia de que la aleatorización haya fallado.
]

=== Notas bibliográficas
<sec-datosentrenamiento-notas>

#cite(<huyen2022dmls>, form: "prose"), Capítulo 4, desarrolla en detalle el rol del muestreo y las "etiquetas naturales" en sistemas de ML generales. La lógica del chequeo de balance como diagnóstico de identificación es estándar en la literatura de evaluación de programas: #cite(<imbens2015causal>, form: "prose") ofrece su tratamiento formal completo, y #cite(<rubin2001using>, form: "prose") es la fuente de los criterios operativos (SMD y razón de varianzas), en el contexto de diseño de estudios observacionales sin mirar el resultado. #cite(<rosenbaum1983central>, form: "prose") es la referencia fundacional del _propensity score_, que el @cap-dml usará como componente _nuisance_ y que ofrece la versión resumida de este mismo diagnóstico en una sola dimensión. #cite(<lalonde1986>, form: "prose") y #cite(<dehejia1999causal>, form: "prose") son las referencias del caso NSW#solo-curso[ usado en el Notebook A1]. Sobre datos faltantes y la distinción MCAR/MAR/MNAR que subyace al diagnóstico de faltantes diferenciales, la referencia canónica es #cite(<rubin1976inference>, form: "prose").
