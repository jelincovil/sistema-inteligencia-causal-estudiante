// Capítulo 9: Ingeniería de features sin fuga causal.
// Plantilla B: Sesión 8. Edición en capas: la regla de auditoría y el caso canónico (capas L2 y L0) son lo que dura; el listado
// y el ejercicio computacional (capa L3) van dentro de #capa-impl. Lo que es solo del curso va en #solo-curso.
#import "../template/template.typ": *

#chapter[Ingeniería de _features_ sin fuga causal]
<cap-features-sin-fuga>

#theorem-number-reset()

#cuadrodecision[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Decisión:*], [Auditar cada _feature_ candidata contra el grafo causal y contra el momento en que se mide antes de incluirla, no solo contra su poder predictivo],
    [*Alternativas:*], [Selección de _features_ por importancia predictiva vs. selección por rol causal],
    [*Trade-off clave:*], [Una _feature_ que mejora el ajuste predictivo puede empeorar la estimación causal],
    [*Insumo:*], [Los roles causales declarados en el esquema de datos del @cap-ingenieria-datos-causales],
    ..if not es-principios {([*Stack:*], [pandas])},
    [*Riesgo principal:*], [_Fuga_ (_leakage_) de información post-tratamiento disfrazada de covariable],
  )
]

#if es-curso [
#monorepo[
  Lab #code[L08] planta fugas deliberadas (outcome, tratamiento, interacciones) y las detecta antes de estimar. La Serie A2 (DML) y el escenario #code[ihdp_medium] asumen covariables solo pre-tratamiento. No usar columnas de ground truth (#code[y0], #code[y1], #code[tau]) fuera de celdas de evaluación. Rutas: #code[05_labs_sesion/L08_leakage_ihdp/] y notebook A2 en #code[03_notebooks_caso_estudio/notebooks/].
]

]
#if es-comercial [#nota-repo-comercial()]
== El problema de diseño
<sec-featuresfuga-problema>

La ingeniería de _features_ estándar, la de #cite(<huyen2022dmls>, form: "prose") (Capítulo 5), evalúa una _feature_ candidata con un solo criterio: ¿mejora el desempeño predictivo fuera de muestra? Con ese criterio, cualquier variable disponible al entrenar que esté correlacionada con $Y$ es bienvenida. El @cap-intervencion-contrafactual mostró por qué ese criterio es *insuficiente y a veces contraproducente* en un sistema causal: una _feature_ puede reducir el error de predicción y, a la vez, ser un mediador o un collider que sesga la estimación del efecto. El problema de diseño de este capítulo es construir un proceso que audite cada variable candidata contra su *rol en el grafo causal* y contra el *momento en que se mide*, no solo contra su poder predictivo. Es la versión operacional, en la preparación de variables, de la clasificación de controles del capítulo anterior.

En un sistema que opera, el momento importa dos veces. Al entrenar, una variable medida después del tratamiento filtra información del resultado. Al servir, la preparación de variables solo dispone de lo que se sabe en el instante de decidir: una _feature_ calculada en un lote nocturno con datos posteriores a la decisión funciona en el entrenamiento retrospectivo y, en servicio, no existe o existe con otro valor. Por eso la regla temporal se formula respecto del momento de la decisión, y por eso la preparación de variables debe ser una sola función para entrenamiento y servicio, una de las seis piezas del @sec-anatomia-implementacion.

== Opciones y trade-offs
<sec-featuresfuga-opciones>

#opciones[
  - *Selección por importancia predictiva.* Se agregan _features_ mientras mejoren una métrica de validación cruzada (RMSE, AUC). Es el flujo de trabajo estándar en _machine learning_ aplicado y el más rápido de ejecutar. Su riesgo específico en un contexto causal ya se discutió en el @cap-prediccion-causalidad: un modelo puede predecir excelente y estimar el efecto causal con sesgo severo, precisamente porque la importancia predictiva no distingue entre variación causal y variación espuria.
  - *Selección por rol causal, informada por el grafo.* Cada _feature_ candidata se clasifica primero según la @sec-intervcontra-controles del capítulo anterior (confusor, mediador, collider, post-tratamiento) y solo después se evalúa su aporte predictivo *dentro* de la categoría de controles legítimos. Requiere tener, aunque sea de forma preliminar, un DAG propuesto, lo cual no siempre es cómodo en la fase exploratoria de un proyecto, pero previene sistemáticamente la clase de error más costosa de este curso.
]

== #t-decision
<sec-featuresfuga-decision>

El libro adopta una etapa de *auditoría de features*, obligatoria antes de construir cualquier matriz de covariables $X$. Cada columna candidata se anota con su rol supuesto (confusor, mediador, collider, post-tratamiento o desconocido) y con la columna que registra cuándo se midió, y la auditoría produce no una sino *dos* especificaciones de $X$:

- $X_"base"$, con las variables anotadas como *confusor* y medidas antes del tratamiento. Es la especificación sobre la que se reporta la estimación principal.
- $X_"ampliada" = X_"base" union {"desconocido"}$, que añade las candidatas cuyo rol el analista no pudo determinar, siempre que sean pre-tratamiento. Es la especificación sobre la que se reporta el *análisis de sensibilidad*.

#entero[
#table(
  columns: (2fr, 2fr, 1fr, 1.3fr),
  align: (left, left, center, center),
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Momento de medida*], [*Rol declarado*], [*$X_"base"$*], [*$X_"ampliada"$*]),
  [Antes del tratamiento], [Confusor], [Sí], [Sí],
  [Antes del tratamiento], [Desconocido], [No], [Sí],
  [Antes del tratamiento], [Mediador, collider o post-tratamiento], [No], [No],
  [Después del tratamiento, en alguna unidad], [Cualquiera], [No], [No],
  [Sin marca de tiempo, o con valores faltantes en ella], [Cualquiera], [No], [No],
)
]

La última fila es la regla conservadora que el listado de referencia hace cumplir: lo que no se puede verificar como anterior al tratamiento no entra. Las reglas valen para el efecto total. Si el estimando fuera un efecto directo o un efecto mediado, el mediador entraría por diseño y el grafo sería otro; es un problema de identificación distinto.

La razón de exigir dos especificaciones en lugar de una regla única es que las dos decisiones posibles sobre una variable de rol desconocido tienen riesgos opuestos y no comparables: excluirla arriesga sesgo por confusión omitida, incluirla arriesga sesgo por mal control. Ningún criterio automático resuelve esa disyuntiva, pero reportar ambas estimaciones convierte la duda en información. Si el efecto es estable entre $X_"base"$ y $X_"ampliada"$, la ambigüedad de rol no era material. Si no lo es, la identificación tiene que revisarse antes de registrar el modelo, que es la acción _revisar identificación_ del @sec-anatomia-acciones. La condición temporal se aplica a *ambas* especificaciones: ninguna cantidad de análisis de sensibilidad rescata a una covariable medida después del tratamiento.

*Qué queda registrado.* El resultado de la auditoría no es un paso desechable. La lista de covariables con que se estima el efecto principal es el campo de roles de la ficha del modelo (@cap-model-card-causal), y es lo que el servicio exige a cada consulta (@cap-despliegue-servicio). Una ficha sin roles no pasa la compuerta de registro (@cap-cicd-causal). Cuando las estimaciones con $X_"base"$ y $X_"ampliada"$ difieren de forma material, se registran las dos.

#caso-canonico("Cuatro tipos de feature y una verdad conocida")[
  Seis variables continuas generadas con ruido normal. $C$ y $U$ son confusores observados y se miden antes del tratamiento. $A_1$ y $A_2$ no se observan: $A_1$ afecta solo al tratamiento y $A_2$ solo al resultado. $B = 0.8 A_1 + 0.8 A_2 + epsilon_B$ es un collider medido antes del tratamiento. El tratamiento es $D = 0.8 C + 0.8 U + 0.8 A_1 + epsilon_D$ y el mediador, $M = 0.5 D + epsilon_M$, se mide después. El resultado es $Y = 0.7 D + 0.6 M + C + U + 0.8 A_2 + epsilon_Y$, de modo que el efecto total de $D$ es $0.7 + 0.6 times 0.5 = 1$. Dos variables más se miden después: $K = 0.6 D + 0.6 Y + epsilon_K$, un collider, y $P = Y + 0.3 epsilon_P$, una medición tardía del propio resultado. El analista declara $C$ como confusor, $U$ como desconocido, $B$ y $K$ como collider, $M$ como mediador y $P$ como post-tratamiento. Con 5 000 unidades y 200 repeticiones, la regresión lineal de $Y$ sobre $D$ y cada especificación da lo siguiente (la desviación entre repeticiones es de 0,02 o menos en todas las filas):

  #table(
    columns: (3fr, 2.2fr, 2.8fr),
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Controles*], [*Efecto estimado*], [*$R^2$ fuera de muestra*]),
    table.hline(stroke: 0.3pt),
    [Ninguno], [1,55], [0,69],
    [$X_"base"$ ($C$)], [1,35], [0,73],
    [$X_"ampliada"$ ($C$, $U$)], [1,00], [0,80],
    [$X_"ampliada"$ y $B$ (collider previo)], [0,88], [0,82],
    [$X_"ampliada"$ y $M$ (mediador)], [0,70], [0,84],
    [Todas las variables], [0,00], [0,99],
    table.hline(stroke: 0.6pt),
  )

  Pasar de $X_"ampliada"$ a la selección por ajuste predictivo mejora el $R^2$ de 0,80 a 0,99 y empeora el efecto de 1,00 a 0,00. La última fila usa $K$ y $P$, que contienen información del resultado y vacían el coeficiente del tratamiento. En este mundo $U$ es un confusor y la especificación correcta es $X_"ampliada"$. Si en cambio $U$ fuera un collider previo, como $B$, la correcta sería $X_"base"$ (que daría 1,00) y $X_"ampliada"$ estimaría 0,91. La discrepancia entre las dos especificaciones es de 0,35 en un mundo y de 0,09 en el otro, y ambas superan con holgura la desviación de 0,02. Los datos solos no dicen en cuál de los dos mundos se está: eso lo decide el grafo.
]

== El contrato de la auditoría de _features_
<sec-featuresfuga-contrato>

La regla de la sección anterior se convierte en una pieza de ingeniería con el formato del C-01 (@sec-datoscausales-contrato). Cualquier implementación que cumpla este contrato sirve, sea una función, un paso de un pipeline o una revisión asistida.

#contrato(
  "C-03",
  [Auditoría de _features_],
  operaciones: [
    _auditar_: recibe las candidatas con el rol que el analista les asigna y con la columna que dice cuándo se midió cada una, junto con la columna que dice cuándo se asignó el tratamiento, y devuelve una fila por candidata con una decisión de inclusión para cada especificación. _extraer_: devuelve la lista de covariables de una especificación, que pasa a ser el campo de covariables del esquema (C-01) y de la ficha del modelo.
  ],
  entrada: [
    Las candidatas con su rol (confusor, mediador, collider, post-tratamiento o desconocido) y su marca de tiempo por unidad, y la marca de tiempo del tratamiento por unidad. El estimando es el efecto total; para otro estimando cambia la tabla de decisión (el mediador entraría en un efecto directo, por ejemplo).
  ],
  salida: [
    Una fila por candidata con su rol, la fracción de unidades en que se midió después del tratamiento, si su marca de tiempo es verificable y las decisiones de inclusión en $X_"base"$ y en $X_"ampliada"$. Una advertencia por cada candidata con riesgo temporal o de rol ambiguo.
  ],
  invariantes: [
    (1) Ninguna candidata se omite en silencio: toda la que aparezca en los roles o en las marcas de tiempo aparece en la salida. (2) Lo que no puede verificarse como anterior al tratamiento, por falta de marca o por faltantes en ella, no entra en ninguna especificación. (3) Una candidata medida después del tratamiento en alguna unidad no entra en ninguna. (4) Mediador, collider y post-tratamiento no entran en ninguna. (5) $X_"base"$ contiene solo confusores y está incluida en $X_"ampliada"$, que añade los de rol desconocido. (6) Una candidata sin rol declarado es de rol desconocido. (7) Con los mismos datos y los mismos roles, la salida es idéntica.
  ],
  fallos: [
    Un rol mal declarado: la auditoría confía en lo que se declara, y un confusor que en realidad es un collider entra en las dos especificaciones. Una marca de tiempo que registra cuándo se cargó el dato y no cuándo se midió: la condición temporal se cumple en el papel. Un rol desconocido que se resuelve por conveniencia en vez de por el grafo. Una sola especificación reportada cuando las dos difieren. Una candidata derivada cuya fórmula usa datos posteriores al tratamiento.
  ],
  aceptacion: [
    (a) Casos de borde, uno por cada caso de la tabla de decisión, más la candidata que solo aparece en los roles y la que tiene faltantes en su marca: cada una cae en la fila que le corresponde. (b) En el caso canónico, la auditoría deja $X_"base" = {C}$ y $X_"ampliada" = {C, U}$, y $B$, $K$, $M$ y $P$ quedan fuera de las dos. (c) Las seis estimaciones del caso canónico se reproducen, y la diferencia entre las dos especificaciones supera con holgura la desviación entre repeticiones.
  ],
)

*Nada se omite en silencio.* Una auditoría que solo recorre las candidatas con marca de tiempo deja pasar justo las que nadie sabe cuándo se midieron. Con el invariante (1) esas candidatas aparecen, marcadas como no verificables, y el analista ve la lista de lo que quedó fuera y por qué.

*Lo no verificable queda fuera.* Entre incluir una variable cuyo momento de medida se ignora y excluirla, el contrato elige excluirla y reportarlo. El riesgo de la exclusión (una confusión omitida) se ve en la comparación de las dos especificaciones. El de la inclusión (una fuga) no se ve en ningún lado.

*La auditoría confía en el rol declarado.* El contrato comprueba el tiempo y aplica la tabla, pero no puede saber si el rol es el correcto. Esa es la parte que depende del grafo y de quien lo dibuja, y por eso el contrato exige que la decisión sobre los roles dudosos quede registrada en la ficha del modelo.

#capa-impl[
== Implementación de referencia
<sec-featuresfuga-implementacion>

El listado implementa la tabla de la sección anterior. Recorre las _features_ que aparezcan en cualquiera de los dos diccionarios, de modo que una _feature_ sin marca de tiempo se marca como no verificable en lugar de omitirse en silencio, y trata como no verificable una marca con valores faltantes.

#figure(
  kind: raw,
  caption: [Auditoría de _features_ por marca de tiempo y por rol declarado.],
  ```python
import pandas as pd

# Roles que NUNCA entran en X cuando el estimando es el efecto total:
# su inclusion bloquea una parte del efecto o abre un camino espurio.
ROLES_PROHIBIDOS = {"mediador", "collider", "post_tratamiento"}

def auditar_features(df: pd.DataFrame, treatment_time_col: str,
                     feature_time_cols: dict[str, str],
                     roles_declarados: dict[str, str]) -> pd.DataFrame:
    """Marca cada feature con su riesgo de fuga temporal y con su rol causal
    declarado. Recorre todas las features que aparezcan en cualquiera de los
    dos diccionarios: una feature sin marca de tiempo no se omite, se marca
    como no verificable y queda fuera de ambas especificaciones.

    Devuelve dos indicadores de inclusion, no uno:
      - incluir_en_X_base:     especificacion principal (solo confusores)
      - incluir_en_X_ampliada: especificacion de sensibilidad (base + rol
                               desconocido, siempre verificablemente pre-tratamiento)
    """
    filas = []
    for feature in sorted(set(feature_time_cols) | set(roles_declarados)):
        rol = roles_declarados.get(feature, "desconocido")
        tiempo_col = feature_time_cols.get(feature)
        if tiempo_col is None:
            verificable, posterior = False, float("nan")
        else:
            t_feature, t_trat = df[tiempo_col], df[treatment_time_col]
            verificable = bool(t_feature.notna().all() and t_trat.notna().all())
            posterior = float((t_feature > t_trat).mean())
        pre_tratamiento = verificable and posterior == 0.0
        filas.append({
            "feature": feature,
            "rol_declarado": rol,
            "pct_medida_despues_del_tratamiento": posterior,
            "marca_de_tiempo_verificable": verificable,
            "riesgo_temporal": not pre_tratamiento,
            "incluir_en_X_base": pre_tratamiento and rol == "confusor",
            "incluir_en_X_ampliada": pre_tratamiento and rol not in ROLES_PROHIBIDOS,
        })
    resultado = pd.DataFrame(filas)

    riesgosas = resultado[resultado["riesgo_temporal"]
                          | (resultado["rol_declarado"] == "desconocido")]
    if len(riesgosas) > 0:
        print("ADVERTENCIA: features con riesgo de fuga o sin rol determinado:")
        print(riesgosas[["feature", "rol_declarado",
                         "pct_medida_despues_del_tratamiento",
                         "marca_de_tiempo_verificable"]])
    n_amb = (resultado["rol_declarado"] == "desconocido").sum()
    if n_amb:
        print(f"{n_amb} feature(s) de rol ambiguo -> reportar la estimacion "
              "con X_base y con X_ampliada, y comparar.")
    return resultado


def columnas_X(resultado: pd.DataFrame, especificacion: str = "base") -> list[str]:
    """Extrae la lista de covariables de una de las dos especificaciones."""
    col = f"incluir_en_X_{especificacion}"
    return resultado.loc[resultado[col], "feature"].tolist()
```
) <lst-auditoria-features>

La función no decide por el analista cuál de las dos especificaciones es la correcta: esa decisión sigue siendo suya, informada por el grafo. Lo que hace es imposible dos cosas: que una variable post-tratamiento, o una sin marca de tiempo verificable, entre a $X$ en silencio, y que una variable de rol ambiguo desaparezca sin dejar rastro. Aparece en la especificación ampliada y obliga a reportar la comparación. Las cifras del caso canónico salen de una simulación con semilla declarada que ejecuta este mismo listado y están en `herramientas/verificaciones/verif_listados_cap09.py`.
]

== #t-aplicacion
<sec-featuresfuga-aplicacion>

La auditoría se ejecuta sobre la matriz de covariables *antes* de estimar el modelo PLR/IRM del @cap-dml#solo-curso[ (en el Notebook de caso de estudio A2, Módulo 2)]. Esto conecta con un punto que ese capítulo asume resuelto: la validez de la ortogonalidad de Neyman depende de que $X$ contenga controles legítimos, no mediadores ni colliders disfrazados de covariables predictivas.

== Señales de alerta y checklist operativo
<sec-featuresfuga-alertas>

#checklist[
  - Una _feature_ mejora sustancialmente el ajuste predictivo del modelo de resultado sin que exista una razón causal clara para incluirla.
  - Ninguna columna del dataset tiene una marca de tiempo que permita verificar si fue medida antes o después del tratamiento, o esa marca tiene valores faltantes.
  - El equipo agregó una _feature_ "porque funcionaba mejor en las pruebas" sin volver a evaluar el DAG.
  - Existen _features_ derivadas cuya fórmula usa, aunque sea indirectamente, el resultado medido después del tratamiento.
  - La preparación de variables de servicio es una función distinta de la de entrenamiento, o calcula alguna _feature_ con datos posteriores al momento de decidir.
  - Las estimaciones con $X_"base"$ y $X_"ampliada"$ difieren de forma material y solo se registró una.
]

== Ejercicios y notas bibliográficas
<sec-featuresfuga-ejercicios>

=== Ejercicios conceptuales
<sec-featuresfuga-ejercicios-conceptuales>

+ Para el dataset de retornos a la educación, clasifique las siguientes variables candidatas a `covariates` según la tabla de la @sec-intervcontra-controles: habilidad cognitiva medida antes de ingresar a la escuela; puntaje de un examen de egreso universitario; cercanía geográfica a una universidad; ingreso de los padres.

+ Un promedio móvil del resultado de las últimas 4 semanas puede ser un control legítimo o una fuente de fuga. Explique de qué depende, qué rol le asignaría en cada caso y qué marca de tiempo debe tener para que la auditoría lo deje pasar.

+ En el caso canónico, la especificación con todas las variables tiene $R^2 = 0.99$ y estima un efecto de 0,00. Explique, con el grafo, por qué $K$ y $P$ vacían el coeficiente del tratamiento aunque el modelo prediga casi perfectamente.

#capa-impl[
=== Ejercicio computacional
<sec-featuresfuga-ejercicios-computacionales>

+ Aplique el #ref(<lst-auditoria-features>, supplement: [listado]) al conjunto de datos que eligió#solo-curso[ para el Notebook A1], declarando roles causales para al menos 6 covariables candidatas, de las cuales al menos una debe quedar como `desconocido` y al menos una debe carecer de marca de tiempo. Reporte cuántas quedan excluidas de $X_"base"$ y por qué motivo cada una, y compare $X_"base"$ con $X_"ampliada"$.

+ Estime el efecto con ambas especificaciones ($X_"base"$ y $X_"ampliada"$) y compare los dos intervalos de confianza. Si la diferencia es pequeña frente al ancho de los intervalos, ¿qué concluye sobre la variable de rol ambiguo? ¿Y si es grande? Explique por qué, en el segundo caso, *ninguna* de las dos estimaciones es defendible sin resolver antes la pregunta de identificación.
]

=== Notas bibliográficas
<sec-featuresfuga-notas>

#cite(<huyen2022dmls>, form: "prose"), Capítulo 5, cubre la ingeniería de _features_ genérica y la fuga de datos (_data leakage_) en su sentido predictivo estándar (por ejemplo, escalar antes de separar entrenamiento y prueba); este capítulo extiende esa discusión al tipo de fuga específico de sistemas causales. La clasificación de controles retomada aquí se desarrolla en @bareinboim2025causalai y @pearl2009causality, ya citados en el @cap-intervencion-contrafactual.
