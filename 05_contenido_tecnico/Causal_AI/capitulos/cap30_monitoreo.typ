// Capítulo 30: Monitoreo de supuestos causales en producción.
// Plantilla B: Sesión 25. Notebook de producción local #4 (parte 1). Edición en capas: el contrato C-07 y los casos
// canónicos (capas L2 y L0) son lo que dura; el listado y la aplicación con tablero (capa L3) van dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Monitoreo de supuestos causales en producción]
<cap-monitoreo-causal>

#theorem-number-reset()

#cuadrodecision[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Decisión:*], [Monitorear la validez de los supuestos causales, no solo la distribución de entradas y salidas],
    [*Alternativas:*], [Monitoreo genérico de ML (drift de _inputs_/_outputs_) vs. monitoreo causal-aware (drift de identificación)],
    [*Trade-off clave:*], [Costo de cómputo del monitoreo adicional vs. riesgo de servir estimaciones inválidas sin saberlo],
    ..if not es-principios {([*Stack:*], [`scipy.stats` y tablero local de monitoreo])},
    [*Riesgo principal:*], [Que el servicio siga respondiendo con normalidad mientras aparecen cambios que obligan a revisar el efecto y sus condiciones de validez],
  )
]

#if es-curso [
#monorepo[
  Monitor de referencia: #code[04_produccion_causal/B4_monitoreo_causal/] (scripts locales y reportes JSON/CSV; KS de covariables, regla de asignación y estabilidad del efecto). Labs #code[L25] y #code[L27] (reentrenar vs alertar). Humo: #code[B4_monitoreo_causal/tests/test_monitor.py] y #code[B4_monitoreo_causal/scripts/run_monitor.py]. El monitoreo del curso es *docente y simulado* sobre el benchmark; en un sistema real se conecta al tráfico local del endpoint B1. Verificación de las cifras: #code[herramientas/verificaciones/verif_cap30.py] y #code[verif_listados_cap30.py].
]

]
#if es-comercial [#nota-repo-comercial()]
== El problema de diseño
<sec-monitoreo-problema>

El monitoreo estándar de sistemas de ML en producción, el que describe @kastner2024mlip en su discusión de _data distribution shifts_, vigila si la distribución de las variables de entrada o de las predicciones se aleja de la observada en entrenamiento. Ese monitoreo es necesario pero *no suficiente* para un sistema causal: el servicio del Capítulo 15 puede seguir respondiendo con total normalidad mientras aparecen señales que obligan a revisar el efecto servido, como una pérdida de soporte, una caída de fuerza del instrumento o un cambio del efecto reestimado. Ninguna señal aislada identifica automáticamente su causa. El problema de diseño de este capítulo es definir qué métricas deben monitorearse y qué revisión proporcionada activa cada una.

== Opciones y trade-offs
<sec-monitoreo-opciones>

#opciones[
  - *Monitoreo genérico.* Vigila solo la distribución univariada de las covariables de entrada (tests de Kolmogorov-Smirnov o similares) y, si acaso, la distribución de las predicciones. Es barato de implementar y es lo que ofrecen la mayoría de las herramientas de MLOps por defecto. No detecta, por construcción, un cambio en la relación entre covariables y tratamiento cuando las marginales permanecen iguales. Ese cambio no prueba por sí solo una ruptura de identificación, pero vuelve obsoleta la descripción de referencia del mecanismo de asignación y puede dejar fuera nuevas causas de tratamiento y resultado.
  - *Monitoreo causal-aware.* Extiende el monitoreo genérico con métricas específicas: reejecutar el chequeo de balance del @cap-datos-entrenamiento-causales sobre los datos recientes, verificar que el soporte común no se haya erosionado y, cuando aplica, verificar que la fuerza del instrumento (el $F$-estadístico de la primera etapa, @cap-panel-dmliv) no haya caído por debajo de los umbrales convencionales. Es más costoso de mantener y requiere mantener disponible el pipeline de estimación completo, no solo el servicio de predicción, para poder recalcular estas métricas periódicamente.
]

== #t-decision
<sec-monitoreo-decision>

El sistema de referencia #solo-curso[del curso]#solo-comercial[del libro] monitorea cuatro métricas causales específicas, además del monitoreo genérico de _inputs_: *(i)* _drift_ de covariables por variable; *(ii)* _drift_ de la relación *entre* covariables y tratamiento respecto de la referencia; *(iii)* fuerza de la relación tratamiento-instrumento en la ventana reciente, cuando el diseño la usa; *(iv)* estabilidad del efecto *reestimado* en ventanas móviles, contrastada mediante un test formal y no por inspección de si un número cae dentro de un intervalo.

Cuatro precisiones sobre el diseño de estas métricas, porque la versión ingenua de cada una falla de forma característica.

*Sobre (i): el test KS no es suficiente y su $p$-valor engaña.* Con ventanas grandes, el test de Kolmogorov–Smirnov rechaza ante diferencias irrelevantes; con ventanas pequeñas, no detecta diferencias materiales. Es el mismo problema que el $t$-test tenía en el chequeo de balance del @cap-datos-entrenamiento-causales, y admite la misma solución: reportar un *tamaño de efecto* junto al $p$-valor. Las dos medidas convencionales son la *ASMD* (diferencia media estandarizada absoluta, la SMD ya usada en aquel capítulo, aplicada ahora entre entrenamiento y ventana reciente) y el *PSI* (_Population Stability Index_), $"PSI" = sum_b (p_b - q_b) log(p_b \/ q_b)$ sobre una discretización en _bins_, cuyos umbrales convencionales en la industria son $"PSI" < 0.1$ (estable), $0.1$–$0.25$ (revisar) y $> 0.25$ (deriva material).

El PSI tiene además un defecto de implementación frecuente. Si el histograma de la ventana se calcula con los bordes de entrenamiento, los valores que caen fuera de ese rango se descartan, y esos son justo los de una cola nueva. En una simulación donde el 20 % de los valores recientes cae en una cola que el entrenamiento no tenía, esa versión reporta un PSI de 0,05 (estable) y la que abre el primer y el último _bin_ al infinito reporta 0,22 (revisar).

*Sobre (ii): el _drift_ del mecanismo puede no mover ninguna marginal.* Esta es la métrica que distingue el monitoreo causal del genérico, y suele omitirse. Si el criterio con que se asigna el tratamiento cambia, la distribución de cada $X_j$ puede permanecer idéntica. Ese cambio es compatible tanto con un mundo donde la no confusión condicional se conserva como con otro donde una causa nueva y no medida afecta al tratamiento y al resultado. La señal no separa esos mundos; indica que la evidencia usada para describir la asignación ya no representa la ventana reciente y que corresponde revisar el conjunto de ajuste, el soporte y el proceso que generó el tratamiento. La forma económica de vigilarlo es preguntar si el _propensity score_ aprendido en la referencia sigue ordenando bien la asignación en la ventana reciente: se ajusta $hat(e)(X)$ con los datos de referencia, se calcula su AUC sobre la ventana nueva y se compara con su AUC de validación cruzada en la referencia. Una caída indica cambio respecto de la referencia, no su causa.

La versión tentadora, reajustar el _propensity_ en cada ventana y comparar las AUC, falla justo en el caso que importa. Si pasa a mandar otra covariable con una fuerza parecida a la de la anterior, el AUC reajustado apenas se mueve, porque la regla nueva es tan predecible como la vieja. En una simulación donde la regla pasa de depender de una covariable a depender de otra (ventanas de 400 observaciones, 100 réplicas), el criterio reajustado detectó el cambio en 2 % de las ventanas; puntuar el modelo de referencia lo detectó en todas y no dio falsas alarmas en las ventanas sin cambio.

*Sobre (iii): el $F$ debe ser el del instrumento, no el del modelo.* La fuerza del instrumento se mide con el $F$ de la primera etapa para el instrumento excluido. El $F$ global de la regresión mide el ajuste conjunto de todos los regresores, y se infla cuando las covariables predicen bien el tratamiento aunque el instrumento no aporte nada. El umbral convencional $F > 10$ proviene de #cite(<stock2005testing>, form: "prose") y está derivado para un solo instrumento y una primera etapa lineal. Aplicarlo fuera de ese caso exige justificación adicional.

*Sobre (iv): comparar un punto contra un intervalo no es un test.* Verificar si el efecto reciente cae dentro del IC original ignora por completo la incertidumbre del efecto reciente, y por tanto ni controla el error de tipo I ni tiene potencia interpretable. El contraste correcto es entre dos estimaciones, cada una con su error estándar: bajo independencia de las dos ventanas, $ z = (hat(theta)_"rec" - hat(theta)_"orig") \/ sqrt("SE"_"rec"^2 + "SE"_"orig"^2) $ es aproximadamente normal estándar bajo la hipótesis nula de efecto estable. Esto exige *reestimar* el efecto en la ventana reciente, no solo predecir con el modelo antiguo, que por construcción devuelve el efecto antiguo. Es la razón por la que el monitoreo causal requiere mantener disponible el pipeline de estimación completo y no solo el servicio de inferencia.

*Sobre los umbrales: se calibran, no se heredan.* Un umbral fijo mezcla dos cosas. La distribución de un estadístico cuando nada cambió depende del tamaño de la ventana y de cuántas covariables se vigilan, así que el mismo número resulta demasiado sensible en un sistema y demasiado romo en otro. El procedimiento es tomar ventanas del propio periodo de referencia (sin cambio por construcción), calcular el estadístico en cada una y fijar el umbral en el cuantil que corresponde a la tasa de falsas alarmas que el equipo está dispuesto a tolerar. Los umbrales convencionales de este capítulo (PSI de 0,1 y 0,25, ASMD de 0,25, $F > 10$) son puntos de partida para ese ejercicio, no sustitutos de él.

#caso-canonico("Ventana nula del test KS")[
  Una referencia de 2000 observaciones y seis covariables independientes, todas normales estándar. Se extraen 1000 ventanas sin ningún cambio, de tamaño $n$, y en cada una se registra el mayor KS entre las seis covariables.

  #table(
    columns: (1fr, 2fr, 2fr),
    align: (center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*$n$*], [*Falsa alarma con umbral fijo 0,12*], [*Umbral calibrado (percentil 95)*]),
    table.hline(stroke: 0.3pt),
    [100], [57 %], [0,17],
    [300], [menos de 1 %], [0,10],
    [1000], [0 %], [0,07],
    table.hline(stroke: 0.6pt),
  )

  El umbral fijo dispara en más de la mitad de las ventanas pequeñas aunque no haya cambiado nada, y es demasiado romo en las grandes. Con ventanas de 300 observaciones y un desplazamiento de 0,3 desviaciones estándar en una sola covariable, el umbral calibrado detecta el 76 % de las ventanas y el fijo, el 53 %. Las cifras provienen de una simulación con semillas fijas y se reproducen con la verificación del Cap. 30 del material complementario.
]

== El contrato del monitoreo causal
<sec-monitoreo-contrato>

El libro no fija una herramienta de monitoreo: fija un contrato. Cualquier sistema, sea un tablero, una tarea programada o una alerta por correo, lo cumple si pasa su prueba de aceptación. Este contrato cierra el ciclo con los anteriores: lee la ficha del modelo (C-05), reestima con el mismo pipeline que pasó la compuerta de registro (C-06) y devuelve una de las cinco acciones del @sec-anatomia-acciones.

#contrato(
  "C-07",
  "Monitoreo causal",
  operaciones: [
    _evaluar_: recibe una ventana reciente de datos y devuelve el reporte de las cuatro señales y la acción que corresponde. _calibrar_: toma ventanas del periodo de referencia, sin cambio por construcción, y fija los umbrales para una tasa de falsas alarmas declarada.
  ],
  entrada: [
    La referencia (los datos de entrenamiento, con su huella). Los roles causales y el efecto con su error estándar, tal como los registra la ficha del modelo (@cap-model-card-causal), junto con los supuestos que la ficha declara observables y sus umbrales. Una función que reestima el efecto con el pipeline completo. Los umbrales vigentes, con la tasa de falsas alarmas y la fecha con que se calibraron.
  ],
  salida: [
    Para cada señal, su valor, su umbral y su estado, nunca un semáforo sin número. Una sola acción, la de la primera pregunta que falla según el orden de la @tab-monitoreo-acciones.
  ],
  invariantes: [
    (1) La referencia es fija: toda comparación usa la misma, de modo que las alertas son comparables en el tiempo. (2) Todo umbral lleva su tasa de falsas alarmas y su fecha de calibración. (3) El mecanismo de asignación se puntúa con el modelo de la referencia y no se reajusta en la ventana. (4) El efecto se reestima, no se predice con el modelo antiguo, y el contraste propaga los dos errores estándar. (5) Con la misma ventana, la misma referencia y los mismos umbrales, el reporte es idéntico. (6) Una ventana demasiado pequeña para calibrar, o con valores faltantes en las columnas vigiladas, se reporta como "sin evidencia" y nunca como "todo en orden".
  ],
  fallos: [
    Un umbral heredado de otro sistema: alarmas constantes o silencio. Reajustar el _propensity_ en cada ventana: el cambio de regla pasa inadvertido. Comparar el efecto reciente contra el intervalo antiguo en vez de contrastar dos estimaciones. Un PSI con los bordes de entrenamiento cerrados: la cola nueva se descarta. Vigilar solo el efecto, y reaccionar siempre tarde, o solo las marginales, y alertar sin consecuencia. Un contraste con $alpha = 0.05$ evaluado cada día: da, en teoría, una falsa alarma cada veinte días en ventanas independientes.
  ],
  aceptacion: [
    Sobre un generador con verdad conocida (el caso canónico de más abajo) se comprueba que cada cambio inyectado enciende la señal que le corresponde y no las demás. (a) Sin cambio, la tasa de ventanas con alguna señal encendida no supera la tasa declarada en la calibración. (b) Un desplazamiento marginal enciende la (i). (c) Un cambio de regla de asignación, sin mover ninguna marginal, enciende la (ii) y no la (i). (d) Un instrumento sin fuerza enciende la (iii). (e) Un cambio del efecto enciende la (iv).
  ],
)

El contrato reutiliza lo que ya existe en capítulos anteriores. La señal (i) es el chequeo de balance del @cap-datos-entrenamiento-causales con los mismos estadísticos de tamaño de efecto, aplicado ahora a entrenamiento contra ventana reciente y no a tratados contra controles. La (ii) reutiliza el _propensity score_ que el @cap-dml ya estima como _nuisance_. La (iii) es el diagnóstico de instrumentos débiles del @cap-panel-dmliv. La (iv) necesita el pipeline de estimación completo y no solo el modelo servido en el @cap-despliegue-servicio.

#caso-canonico("Un generador con cuatro cambios posibles")[
  Se simulan unidades con tres covariables normales estándar $X_1, X_2, X_3$ y un instrumento $Z tilde N(0, 1)$. El tratamiento es binario, $D tilde "Bernoulli"(sigma(X_1 + 0.8 Z))$, y el resultado es $Y = tau D + X_1 + 0.5 X_3 + epsilon$ con $tau = 0.5$ y $epsilon tilde N(0, 1)$. La referencia tiene 3 000 unidades y cada ventana reciente, 400. Se inyecta un cambio por vez: un desplazamiento de $X_3$ en una desviación estándar; un cambio de regla, con la asignación dependiendo de $X_2$ en lugar de $X_1$; un instrumento sin efecto sobre el tratamiento; y un efecto que baja de 0,5 a 0,1.

  La tabla da el porcentaje de 100 ventanas recientes en que se enciende cada señal.

  #table(
    columns: (3fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Cambio inyectado*], [*(i)*], [*(ii)*], [*(iii)*], [*(iv)*]),
    table.hline(stroke: 0.3pt),
    [Ninguno], [0 %], [0 %], [0 %], [2 %],
    [Desplazamiento de $X_3$ en una DE], [100 %], [0 %], [0 %], [2 %],
    [Regla de asignación ($X_1$ pasa a $X_2$)], [0 %], [100 %], [0 %], [1 %],
    [Instrumento sin efecto], [0 %], [0 %], [99 %], [2 %],
    [Efecto de 0,5 a 0,1], [0 %], [0 %], [0 %], [95 %],
    table.hline(stroke: 0.6pt),
  )
]

Cada cambio contemplado en el generador enciende la señal diseñada para verlo y casi ninguna otra. La tercera fila muestra que la señal (ii) detecta una regla de asignación distinta aunque ninguna marginal se mueva; la señal todavía no dice si apareció confusión no observada. La cuarta es la pérdida de fuerza del instrumento, que detecta la (iii) en el 99 % de las ventanas, y la última es el cambio de efecto, que solo detecta la (iv), en el 95 %. Sin cambio alguno, la única señal que se enciende es la (iv), en el 2 % de las ventanas, por debajo del 5 % nominal. Estas tasas son por ventana. En una serie de ventanas sucesivas las falsas alarmas se acumulan: en las series de deriva de la @sec-monitoreo-aplicacion, el 42 % de las series de diez ventanas tuvo al menos una falsa alarma de la (iv).

Una observación sobre el orden de las alertas, que es lo que hace útil el reporte en vez de solo ruidoso. Las cuatro métricas no son intercambiables. El _drift_ marginal (i) puede indicar que cambió la población objetivo sin que cambie la función causal. El _drift_ del mecanismo de asignación (ii) exige revisar la identificación porque la referencia dejó de describir quién recibe el tratamiento, aunque no demuestra por sí solo que apareció confusión. La caída de fuerza del instrumento (iii) sí compromete la inferencia basada en ese instrumento. El cambio en el efecto (iv) puede reflejar un mecanismo distinto, una población distinta o un problema del estimador. El valor del reporte está en leer las cuatro juntas y conservar abiertas esas explicaciones hasta reunir evidencia adicional.

#capa-impl[
== Implementación de referencia
<sec-monitoreo-implementacion>

El listado implementa las cuatro señales como funciones independientes y un reporte que las combina. Lee los roles y el efecto de la ficha del modelo, de modo que no depende de ningún objeto serializado del notebook.

#figure(
  kind: raw,
  caption: [Las cuatro métricas de monitoreo causal sobre una ventana reciente de datos.],
  ```python
import numpy as np
import pandas as pd
from scipy import stats
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import cross_val_predict

# --- (i) Drift marginal de covariables: tamano de efecto + p-valor ----
def drift_covariables(df_train, df_rec, covariables, psi_bins=10):
    """PSI y ASMD por covariable. El p-valor KS se reporta pero NO se usa
    como criterio: con ventanas grandes rechaza ante diferencias
    irrelevantes (mismo problema que el t-test en el chequeo de balance)."""
    filas = []
    for c in covariables:
        a, b = df_train[c].dropna(), df_rec[c].dropna()
        s_pool = np.sqrt((a.var(ddof=1) + b.var(ddof=1)) / 2)
        asmd = abs(a.mean() - b.mean()) / s_pool if s_pool > 0 else 0.0
        # PSI sobre bins definidos por los cuantiles de ENTRENAMIENTO. Los
        # extremos se abren a +-inf: con los bordes de entrenamiento,
        # np.histogram descartaria los valores nuevos fuera de rango, que son
        # justo la cola que el monitoreo tiene que ver.
        bordes = np.unique(np.quantile(a, np.linspace(0, 1, psi_bins + 1)))
        bordes[0], bordes[-1] = -np.inf, np.inf
        p = np.histogram(a, bins=bordes)[0] / len(a)
        q = np.histogram(b, bins=bordes)[0] / len(b)
        eps = 1e-6
        p, q = np.clip(p, eps, None), np.clip(q, eps, None)
        psi = float(((p - q) * np.log(p / q)).sum())
        filas.append({
            "covariable": c, "asmd": asmd, "psi": psi,
            "p_ks": stats.ks_2samp(a, b).pvalue,
            # Umbrales convencionales; declararlos, no descubrirlos
            "alerta": (psi > 0.25) or (asmd > 0.25),
        })
    return pd.DataFrame(filas).sort_values("psi", ascending=False)

# --- (ii) Drift de la relacion X -> D (activa revision de identificacion) -
def drift_mecanismo_asignacion(df_train, df_rec, covariables, tratamiento,
                               tolerancia=0.10):
    """Lo que el modelo aprendio sobre COMO se asigna el tratamiento, sigue
    valiendo en la ventana reciente? Se ajusta el propensity en la referencia
    y se PUNTUA en la ventana. Reajustarlo en cada ventana no sirve: si cambia
    QUE covariable manda pero no cuanto, el AUC reajustado casi no se mueve.
    La tolerancia es un punto de partida: calibrela con ventanas sin cambio."""
    modelo = LogisticRegression(max_iter=1000)
    p_cv = cross_val_predict(modelo, df_train[covariables], df_train[tratamiento],
                             cv=5, method="predict_proba")[:, 1]
    auc_train = roc_auc_score(df_train[tratamiento], p_cv)
    modelo.fit(df_train[covariables], df_train[tratamiento])
    p_rec = modelo.predict_proba(df_rec[covariables])[:, 1]
    auc_rec = roc_auc_score(df_rec[tratamiento], p_rec)
    return {"auc_entrenamiento": auc_train, "auc_reciente": auc_rec,
            "delta_auc": auc_rec - auc_train,
            "alerta": (auc_train - auc_rec) > tolerancia}

# --- (iii) Fuerza del instrumento -------------------------------------
def fuerza_instrumento(df_rec, instrumento, tratamiento, covariables, umbral_f=10):
    """F de la PRIMERA ETAPA sobre el instrumento excluido, no el F global del
    modelo: ese mide el ajuste conjunto de TODOS los regresores e infla el
    diagnostico cuando las covariables predicen bien el tratamiento.
    Umbral convencional F > 10 (Stock y Yogo, 2005); por debajo, alerta."""
    y = df_rec[tratamiento].to_numpy(float)
    W = np.c_[np.ones(len(y)), df_rec[covariables].to_numpy(float)]
    Z = np.c_[W, df_rec[instrumento].to_numpy(float)]

    def rss(X):
        beta = np.linalg.lstsq(X, y, rcond=None)[0]
        return float(((y - X @ beta) ** 2).sum())

    rss_r, rss_u = rss(W), rss(Z)            # sin y con el instrumento
    f_stat = (rss_r - rss_u) / (rss_u / (len(y) - Z.shape[1]))
    return {"f_primera_etapa": f_stat, "alerta_debil": f_stat < umbral_f}

# --- (iv) Estabilidad del efecto: contraste formal entre ventanas ------
def estabilidad_efecto(reestimar, df_rec, theta_orig, se_orig, alpha=0.05):
    """Reestima el efecto en la ventana reciente y contrasta H0: los dos
    efectos son iguales, propagando AMBOS errores estandar.

    `reestimar(df) -> (theta, se)` corre el pipeline de estimacion completo.
    No basta con predecir con el modelo antiguo: eso devuelve, por
    construccion, el efecto antiguo."""
    theta_rec, se_rec = reestimar(df_rec)
    se_combinado = np.sqrt(se_orig**2 + se_rec**2)
    z = (theta_rec - theta_orig) / se_combinado
    p_valor = 2 * (1 - stats.norm.cdf(abs(z)))
    return {"theta_original": theta_orig, "theta_reciente": theta_rec,
            "se_reciente": se_rec, "z": z, "p_valor": p_valor,
            "alerta": p_valor < alpha}

def reporte_monitoreo(df_train, df_rec, roles, reestimar, theta_orig, se_orig):
    """`roles` es la seccion "roles" de model_card.json (tratamiento, covariables,
    instrumentos); theta_orig y se_orig salen de metricas.efecto y metricas.ic95."""
    cov, trat = roles["covariables"], roles["tratamiento"]
    drift = drift_covariables(df_train, df_rec, cov)
    reporte = {
        "drift_covariables": drift,
        "drift_mecanismo_asignacion": drift_mecanismo_asignacion(
            df_train, df_rec, cov, trat),
        "estabilidad_efecto": estabilidad_efecto(
            reestimar, df_rec, theta_orig, se_orig),
    }
    if roles.get("instrumentos"):
        reporte["fuerza_instrumento"] = fuerza_instrumento(
            df_rec, roles["instrumentos"][0], trat, cov)
    reporte["requiere_atencion"] = bool(
        drift["alerta"].any()
        or reporte["drift_mecanismo_asignacion"]["alerta"]
        or reporte["estabilidad_efecto"]["alerta"]
        or reporte.get("fuerza_instrumento", {}).get("alerta_debil", False)
    )
    return reporte
```
) <lst-monitoreo-causal>

En el listado, `drift_covariables` implementa la señal (i), `drift_mecanismo_asignacion` la (ii), `fuerza_instrumento` la (iii) y `estabilidad_efecto` la (iv). La función de reestimación que recibe `estabilidad_efecto` corre el pipeline del @cap-dml sobre la ventana y devuelve el efecto y su error estándar.
]

== #t-aplicacion
<sec-monitoreo-aplicacion>

La aplicación del contrato muestra el *orden temporal* en que se encienden las alertas ante una deriva gradual. En una simulación con diez ventanas sucesivas de 400 observaciones, en las que la media de una covariable sube 0,2 desviaciones estándar por ventana, la señal (i) se enciende en la segunda ventana (mediana de 40 series), tanto si la covariable modula el efecto como si no. Lo que distingue un caso del otro es la (iv). Si la covariable no modula el efecto, la (iv) no pasa de su tasa de falsas alarmas: se enciende en el 4,8 % de las ventanas. Si lo modula, $tau(X)=0.5+0.5X_2$, el ATE de cada ventana es $"ATE"_t=0.5+0.5E_t[X_2]$. Al desplazarse la media de $X_2$, cambia el efecto promedio aunque la función $tau(x)$ permanezca intacta. La señal (iv) se enciende en el 82 % de las ventanas, por primera vez en la ventana 2,5 (mediana), y ninguna de las 40 series quedó sin alerta. Ese cambio puede ser el resultado correcto para una población nueva, no un fallo del estimador. Si la pregunta exige comparar mecanismos, hay que estandarizar ambas ventanas a una población de referencia justificada; si describe cada ventana, corresponde reportar el nuevo ATE y su nueva población.

El caso complementario es el cambio de regla de asignación del tratamiento, que no mueve ninguna distribución marginal de covariables. Ahí la señal (i) no reporta nada y solo la (ii) detecta que la referencia dejó de describir la asignación (@sec-monitoreo-contrato). Es la demostración práctica de por qué un monitoreo de MLOps genérico no basta para un sistema causal. El paso siguiente es una revisión de identificación: averiguar si la nueva regla depende solo de covariables observadas con soporte suficiente o si introduce una causa no medida del tratamiento y del resultado.

#capa-impl[#solo-curso[La práctica de producción B4 ejecuta]#solo-comercial[Una implementación de referencia ejecuta] la función `reporte_monitoreo` del #ref(<lst-monitoreo-causal>, supplement: [listado]) y guarda reportes JSON/CSV sobre un escenario simulado de _drift_ gradual. La interfaz de tablero es opcional y no forma parte del contrato.]

== De la señal a la acción
<sec-monitoreo-accion>

Un reporte con cuatro semáforos deja sin responder lo importante: qué hacer. El sistema de referencia usa cinco acciones (continuar, alertar, abstenerse, revisar la identificación y reentrenar) y hace las preguntas en orden de gravedad: la primera que falla decide.

#figure(
  caption: [Orden de las preguntas de monitoreo y la acción que dispara cada una.],
  table(
    columns: (1.5fr, 2fr, 1.5fr),
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Pregunta*], [*Si falla*], [*Acción*]),
    table.hline(stroke: 0.4pt),
    [1) ¿Hay soporte suficiente de tratados y controles?], [Sin soporte no hay estimador que juzgar; responder sería extrapolar], [*Abstenerse* de responder para esas unidades],
    [2) ¿Sigue respaldada la identificación?], [Cambió el mecanismo de asignación respecto de la referencia o se debilitó el instrumento, aunque el efecto todavía se vea estable], [*Revisar la identificación* (decide una persona)],
    [3) ¿Pasa la estadística y es comparable la población?], [El pipeline falla o la población cambió; el efecto puede seguir siendo válido, pero para otra población], [*Alertar*],
    [4) ¿Cambió el efecto?], [Con lo anterior en orden, un cambio de efecto sí justifica actualizar el modelo], [*Reentrenar*, con el champion-challenger del @cap-aprendizaje-continuo],
    [Todo en orden], [], [*Continuar*],
    table.hline(stroke: 0.8pt),
  )
) <tab-monitoreo-acciones>

El orden se defiende por lo que cada fallo deja sin sentido. Sin soporte, las demás señales no significan nada. Un instrumento debilitado invalida la inferencia que depende de él; un cambio de asignación, en cambio, abre una revisión y no anticipa su veredicto. Una población distinta puede dar un efecto perfectamente válido para otro objetivo. Un cambio de efecto que llega junto con un pipeline roto o una población nueva no es buena razón para reemplazar el modelo sin mirar. Otro orden puede sostenerse, pero no tener ninguno acaba en reentrenar cada vez que algo se mueve y borrar la referencia antes de entender el cambio.

Las cuatro señales vigilan supuestos observables. El que más pesa, que no haya confusión que las covariables medidas no recojan, no tiene señal: el sistema puede estar quieto en las cuatro y sesgado por una causa que nadie midió. Eso no se arregla con un quinto semáforo. Se arregla con otra cosa, que es declarar cuánto margen tiene la decisión frente a ese supuesto y cuándo se vuelve a mirar (@cap-supuestos-no-observables).

== Señales de alerta y checklist operativo
<sec-monitoreo-alertas>

#checklist[
  - El sistema solo monitorea la disponibilidad del servicio (¿responde?), no la validez estadística de lo que responde.
  - El chequeo de balance del entrenamiento nunca se vuelve a ejecutar sobre datos de producción.
  - No existe una ventana de referencia fija para comparar la estabilidad del efecto; cada comparación usa un punto de referencia distinto, haciendo las alertas no comparables en el tiempo.
  - Las alertas de monitoreo se generan pero nadie las revisa: no hay un proceso definido de qué hacer cuando el reporte pide atención (retomado en el @cap-aprendizaje-continuo).
  - Los umbrales se heredaron de otro sistema o de una guía, sin medir cuántas alarmas dan en ventanas sin cambio.
  - Todos los semáforos están en verde y nadie ha dicho qué pasa con los supuestos que ningún semáforo vigila (@cap-supuestos-no-observables).
]

== Ejercicios y notas bibliográficas
<sec-monitoreo-ejercicios>

=== Ejercicios conceptuales
<sec-monitoreo-ejercicios-conceptuales>

+ Explique por qué el monitoreo genérico de _drift_ de predicciones (vigilar solo la distribución de $hat(Y)$) puede no detectar un problema de validez causal aunque la distribución de $hat(Y)$ se mantenga estable.

+ Para el sistema #solo-curso[del Notebook A2 (DML sobre retornos a la educación)]#solo-comercial[de DML sobre retornos a la educación], proponga un escenario concreto de cambio en los datos que dispare la alerta de fuerza del instrumento sin disparar ninguna alerta de _drift_ de covariables.

+ Construya un escenario simulado en el que la regla de asignación del tratamiento cambie (por ejemplo, que pase a depender de una covariable que antes no usaba) *manteniendo idénticas todas las distribuciones marginales de covariables*. Verifique que la señal (i) no reporta nada y que la (ii) sí. Proponga dos procesos compatibles con esa alerta: uno que conserve la no confusión al observar la nueva covariable y otro que introduzca una causa no medida. Diga qué evidencia adicional los distinguiría.

+ Compare, sobre una ventana con _drift_ leve, el veredicto del test formal de estabilidad del efecto con el del criterio ingenuo ("¿el efecto reciente cae dentro del IC original?"). Muestre un caso en que ambos difieran y argumente cuál de los dos debe gobernar la alerta.

+ La señal (iv) con $alpha = 0.05$ tiene una tasa nominal de falsas alarmas del 5 % por ventana sin cambio. Si el sistema evalúa una ventana nueva cada día, ¿cada cuántos días esperaría una falsa alarma? Proponga una regla (por ejemplo, exigir la alerta en dos ventanas consecutivas) y calcule cómo cambian la tasa de falsas alarmas y la demora en detectar un cambio real, suponiendo ventanas independientes.

#capa-impl[
=== Ejercicio de infraestructura #solo-curso[(Lab, arranca Notebook B4)]
<sec-monitoreo-ejercicios-infra>

+ Implemente el #ref(<lst-monitoreo-causal>, supplement: [listado]) sobre su modelo#solo-curso[ del Notebook A2/B1]#solo-comercial[ causal ya desplegado], simulando una ventana de datos recientes con _drift_ deliberado en al menos una covariable. Verifique que el reporte detecta el _drift_ introducido.
]

=== Notas bibliográficas
<sec-monitoreo-notas>

#cite(<kastner2024mlip>, form: "prose") y #cite(<huyen2022dmls>, form: "prose") (Capítulo 8, "Data Distribution Shifts and Monitoring") desarrollan el monitoreo de _drift_ genérico que este capítulo extiende, incluida la taxonomía de _covariate shift_, _label shift_ y _concept drift_ que conviene tener presente al interpretar el reporte. El umbral convencional de $F > 10$ para descartar instrumentos débiles proviene de #cite(<stock2005testing>, form: "prose"), introducido en el @cap-panel-dmliv; recuérdese que está derivado para el caso de un instrumento y una primera etapa lineal, y que aplicarlo fuera de ese caso exige justificación adicional. Los criterios de balance sobre los que se apoya la señal (i) (ASMD y su umbral) son los de #cite(<rubin2001using>, form: "prose"), ya usados en el @cap-datos-entrenamiento-causales; el PSI, en cambio, no tiene una referencia académica canónica, pues es una convención de la industria del riesgo crediticio, y sus umbrales deben tratarse como reglas prácticas calibradas al dominio, no como criterios con respaldo teórico.
