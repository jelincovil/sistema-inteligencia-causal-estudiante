"""knowledge.py — Gestión y búsqueda de fichas de conocimiento.

Búsqueda léxica determinista con ranking reproducible. No necesita LLM.
Las fichas se empaquetan como recursos dentro del wheel.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from .models import FichaConocimiento

# Las fichas se definen como datos Python para empaquetado fácil.
# En producción pueden migrarse a YAML en resources/knowledge/.
_FICHAS: list[dict] = []


def _registrar(**kwargs) -> None:
    """Registra una ficha desde kwargs."""
    _FICHAS.append(kwargs)


# ================================================================ FICHAS
# 24 temas obligatorios de 03_CONOCIMIENTO.md

_registrar(
    id="estimando",
    titulo="Estimando: qué compara el sistema",
    pregunta_operativa="¿Qué contraste causal estoy computando y sobre qué población?",
    alcance="Definición y declaración del estimando antes de mirar datos.",
    condiciones=["Pregunta causal formulada", "Población identificada"],
    principios=[
        "El estimando se declara antes de mirar los datos",
        "ATE, ATT, CATE y policy value son objetos distintos",
        "El intervalo cubre el estimando declarado, no efectos individuales",
    ],
    pasos=[
        "Formular la pregunta causal en una oración",
        "Elegir el tipo de estimando (ATE/ATT/CATE/policy)",
        "Declarar la población de validez",
        "Clasificar los supuestos (observable/no observable)",
        "Registrar en la declaración del proyecto",
    ],
    evidencia_requerida=["declaracion_causal", "supuestos_clasificados"],
    fallos=["Cambiar el estimando después de ver resultados", "No declarar población"],
    alternativas=["Reportar múltiples estimandos con sus poblaciones"],
    ejemplo="ATE de treatment sobre re78 en la población de entrenamiento de real/jobs.",
    limitaciones=["La declaración no verifica la corrección del estimando"],
    fuentes=[
        {"cita": "Imbens & Rubin 2015", "url": "https://doi.org/10.1017/CBO9781139025751", "tipo": "libro"},
        {"cita": "Hernán & Robins 2020", "url": "https://www.hsph.harvard.edu/miguel-hernan/causal-inference-book/", "tipo": "libro"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-01"],
    criterios_relacionados=["Q-01"],
    etiquetas=["fundamento", "declaración"],
)

_registrar(
    id="identificacion_backdoor",
    titulo="Identificación por criterio de puerta trasera",
    pregunta_operativa="¿Qué conjunto de covariables bloquea los caminos espurios?",
    alcance="Selección de conjuntos de ajuste legítimos mediante DAG.",
    condiciones=["DAG propuesto", "Conjunto de covariables candidatas"],
    principios=[
        "El criterio de puerta trasera determina qué controlar",
        "Controlar un collider abre un camino espurio",
        "Controlar un mediador bloquea parte del efecto",
    ],
    pasos=[
        "Dibujar el DAG con las variables relevantes",
        "Identificar caminos de puerta trasera de D a Y",
        "Verificar qué conjunto bloquea todos los caminos",
        "Registrar el conjunto de ajuste en el esquema",
    ],
    evidencia_requerida=["dag_referencia", "conjunto_ajuste"],
    fallos=["Controlar post-tratamiento", "Omitir confusor clave"],
    alternativas=["Front-door", "IV", "DiD cuando aplica"],
    ejemplo="En real/jobs: controlar por age, educ, black, hispan, married, nodegree, re74, re75.",
    limitaciones=["El DAG es una suposición, no un dato"],
    fuentes=[
        {"cita": "Pearl 2009", "url": "https://doi.org/10.1145/1644001.1644020", "tipo": "articulo"},
        {"cita": "Bareinboim et al 2025", "url": "https://doi.org/10.1145/3732543", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-01", "C-03"],
    criterios_relacionados=["Q-01", "Q-02"],
    etiquetas=["fundamento", "identificación"],
)

_registrar(
    id="supuestos_no_observables",
    titulo="Supuestos no observables: cómo declararlos y acotarlos",
    pregunta_operativa="¿Qué supuestos no puedo verificar y qué hago con ellos?",
    alcance="Clasificación y tratamiento de supuestos no observables.",
    condiciones=["Al menos un supuesto identificado como no observable"],
    principios=[
        "Todo sistema causal descansa en al menos un supuesto no observable",
        "Un supuesto no observable sin criterio de revisión es una deuda",
        "La sensibilidad acota, no prueba",
    ],
    pasos=[
        "Listar todos los supuestos del diseño",
        "Clasificar cada uno como observable o no observable",
        "Para cada no observable: justificar, acotar con sensibilidad, programar revisión",
        "Registrar en la tarjeta del modelo",
    ],
    evidencia_requerida=["supuestos_clasificados", "sensibilidad"],
    fallos=["Ocultar supuestos no observables", "Sin criterio de revisión"],
    alternativas=["Holdout aleatorizado cuando es posible"],
    ejemplo="No confusión condicional: declarada, con Gamma de Rosenbaum como cota.",
    limitaciones=["La sensibilidad es una cota bajo supuestos del modelo"],
    fuentes=[
        {"cita": "Rosenbaum 2002", "url": "https://doi.org/10.1007/978-1-4757-4132-7", "tipo": "libro"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-05", "C-08"],
    criterios_relacionados=["Q-02"],
    etiquetas=["fundamento", "gobernanza"],
)

_registrar(
    id="roles",
    titulo="Roles causales de columnas",
    pregunta_operativa="¿Qué columna es tratamiento, resultado, covariable o instrumento?",
    alcance="Declaración y validación del esquema de roles.",
    condiciones=["Tabla de datos disponible", "Pregunta causal formulada"],
    principios=[
        "Cada columna tiene exactamente un rol",
        "El esquema viaja con los datos",
        "Declarar no es verificar: el C-01 no comprueba causalidad",
    ],
    pasos=[
        "Identificar tratamiento y resultado por nombre",
        "Listar covariables candidatas",
        "Validar que ninguna columna tiene doble rol",
        "Serializar el esquema para el registro",
    ],
    evidencia_requerida=["esquema_roles", "validacion_estructura"],
    fallos=["Tratamiento colado entre covariables", "Columna renombrada"],
    alternativas=["Esquemas múltiples para estimandos distintos"],
    ejemplo="real/jobs: treatment, re78, 8 covariables pre-tratamiento.",
    limitaciones=["El C-01 no detecta post-tratamiento (eso es C-03)"],
    fuentes=[
        {"cita": "Kleppmann 2017", "url": "https://doi.org/10.1093/oso/9780199642611.001.0001", "tipo": "libro"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-01"],
    criterios_relacionados=["Q-01"],
    etiquetas=["ingeniería", "esquema"],
)

_registrar(
    id="temporalidad",
    titulo="Validez temporal y control de fuga",
    pregunta_operativa="¿Cuándo se midió cada feature y es anterior al tratamiento?",
    alcance="Auditoría de features contra marcas de tiempo.",
    condiciones=["Marcas de tiempo por feature", "Momento del tratamiento conocido"],
    principios=[
        "Lo no verificable como pre-tratamiento queda fuera",
        "La fecha de ingesta no es la fecha de medición",
        "Dos especificaciones cuando hay rol ambiguo",
    ],
    pasos=[
        "Listar features candidatas con su timestamp",
        "Verificar cada una contra el momento del tratamiento",
        "Clasificar: pre-tratamiento, post-tratamiento, sin verificar",
        "Reportar ambas especificaciones si hay ambigüedad",
    ],
    evidencia_requerida=["auditoria_temporal", "especificaciones"],
    fallos=["Feature derivada del resultado", "Timestamp de ingesta usado como medición"],
    alternativas=["As-of join para point-in-time correctness"],
    ejemplo="score_post = 0.6*re78 + 0.4*D: derivada del resultado, bloqueada.",
    limitaciones=["La auditoría confía en el rol declarado"],
    fuentes=[
        {"cita": "Huyen 2022", "url": "https://doi.org/10.1093/oso/9780199642611.001.0001", "tipo": "libro"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-03"],
    criterios_relacionados=["Q-03"],
    etiquetas=["ingeniería", "fuga"],
)

_registrar(
    id="particiones",
    titulo="Particiones sembradas y la pared",
    pregunta_operativa="¿Cómo separo entrenamiento de evaluación sin fuga?",
    alcance="Diseño y verificación de particiones con semilla.",
    condiciones=["Tabla con hash versionado", "Proporciones declaradas"],
    principios=[
        "La semilla es parte del contrato",
        "La prueba mide una vez",
        "La verdad vive al otro lado de la pared",
    ],
    pasos=[
        "Elegir proporciones y método de estratificación",
        "Fijar semilla antes de mirar resultados",
        "Verificar disjunción y cobertura",
        "Etiquetar lados de la pared",
    ],
    evidencia_requerida=["particion_versionada", "hash_verificado"],
    fallos=["Reusar semilla hasta que salga bien", "Solape por join defectuoso"],
    alternativas=["Separación por tiempo cuando aplica"],
    ejemplo="real/jobs: 60/20/20 estratificado por tratamiento, semilla 20240701.",
    limitaciones=["La partición no garantiza ausencia de fuga semántica"],
    fuentes=[
        {"cita": "Huyen 2022 Cap 4", "url": "https://doi.org/10.1093/oso/9780199642611.001.0001", "tipo": "libro"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-10"],
    criterios_relacionados=["Q-05"],
    etiquetas=["ingeniería", "partición"],
)

_registrar(
    id="preprocesamiento_fold",
    titulo="Preprocesamiento dentro del fold",
    pregunta_operativa="¿Dónde se ajusta el escalado, la imputación y la selección?",
    alcance="Garantía de que el preprocesamiento no ve el fold de prueba.",
    condiciones=["Partición de folds definida", "Preprocesamiento declarado"],
    principios=[
        "Todo preprocesamiento se ajusta dentro del fold de entrenamiento",
        "El preproceso global antes de partir es fuga",
    ],
    pasos=[
        "Declarar qué preprocesamiento se aplica",
        "Verificar que se ajusta solo con datos del fold de entrenamiento",
        "Aplicar la misma transformación al fold de prueba",
    ],
    evidencia_requerida=["invariantes_crossfitting"],
    fallos=["Escalar antes de partir", "Imputar con la media global"],
    alternativas=["Pipeline de sklearn que encapsula el preprocesamiento"],
    ejemplo="Estandarización: media y desviación del fold k-1 aplicadas al fold k.",
    limitaciones=["Requiere disciplina en la implementación"],
    fuentes=[
        {"cita": "Chernozhukov et al 2018", "url": "https://doi.org/10.1111/rssb.12261", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-12"],
    criterios_relacionados=["Q-05"],
    etiquetas=["estimación", "cross-fitting"],
)

_registrar(
    id="aipw_dml",
    titulo="AIPW y DML: estimación doblemente robusta",
    pregunta_operativa="¿Cómo estimo el ATE con ML sin perder inferencia válida?",
    alcance="Estimación AIPW con cross-fitting para ATE.",
    condiciones=["Supuestos de identificación declarados", "Partición de folds"],
    principios=[
        "El score ortogonal de Neyman permite nuisance con ML",
        "El cross-fitting elimina el sobreajuste del nuisance",
        "La doble robustez: si una pierna falla, la otra sostiene",
    ],
    pasos=[
        "Declarar el estimando y los supuestos",
        "Particionar en K folds con semilla",
        "Por fold: ajustar outcome y propensity fuera, predecir dentro",
        "Calcular el score AIPW por unidad",
        "Promediar para el ATE, SE por influencia",
    ],
    evidencia_requerida=["scores_aipw", "ess_solape", "comparacion_learners"],
    fallos=["Sin cross-fitting: sesgo por sobreajuste", "Ambos nuisances mal"],
    alternativas=["PLR de Robinson", "IRM interactivo"],
    ejemplo="real/jobs: AIPW K=5 semilla 4242, ATE 1638.6 SE 325.0.",
    limitaciones=["No garantiza cobertura del intervalo sin condiciones de tasa"],
    fuentes=[
        {"cita": "Chernozhukov et al 2018", "url": "https://doi.org/10.1111/rssb.12261", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-12"],
    criterios_relacionados=["Q-04"],
    etiquetas=["estimación", "dml"],
)

_registrar(
    id="incertidumbre",
    titulo="Incertidumbre: qué cubre el intervalo",
    pregunta_operativa="¿Qué afirma exactamente mi IC del 95%?",
    alcance="Interpretación correcta de intervalos de confianza causales.",
    condiciones=["Estimación con SE calculado"],
    principios=[
        "El IC cubre el estimando poblacional, no efectos individuales",
        "Un IC del CATE no es un IC del efecto individual",
        "La cobertura asintótica requiere condiciones de tasa",
    ],
    pasos=[
        "Declarar qué objeto cubre el intervalo",
        "Reportar el SE y el método de cálculo",
        "No confundir IC del ATE con IC de predicción individual",
    ],
    evidencia_requerida=["ic_con_objeto_declarado"],
    fallos=["Presentar IC del ATE como efecto individual"],
    alternativas=["Intervalos simultáneos para múltiples comparaciones"],
    ejemplo="ATE 1596.0 [1004.8, 2187.3]: cubre el efecto promedio, no el de María.",
    limitaciones=["La cobertura exacta no está garantizada en muestras finitas"],
    fuentes=[
        {"cita": "Imbens & Rubin 2015", "url": "https://doi.org/10.1017/CBO9781139025751", "tipo": "libro"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-12", "C-05"],
    criterios_relacionados=["Q-01"],
    etiquetas=["estimación", "interpretación"],
)

_registrar(
    id="overlap_ess",
    titulo="Soporte común y ESS de Kish",
    pregunta_operativa="¿Hay con quién comparar en mi muestra?",
    alcance="Diagnóstico de solapamiento mediante ESS y rango de propensión.",
    condiciones=["Propensidad estimada"],
    principios=[
        "ESS/n bajo: pocas unidades dominan la estimación",
        "El histograma de propensión puede verse bien con ESS pésimo",
        "Sin soporte, la comparación es extrapolación",
    ],
    pasos=[
        "Estimar la propensidad",
        "Calcular ESS = (sum w)^2 / sum w^2",
        "Reportar ESS/n y el rango de la propensidad",
        "Declarar la regla de alerta",
    ],
    evidencia_requerida=["ess_reportado", "rango_propensidad"],
    fallos=["Ignorar ESS bajo", "Reportar solo el histograma"],
    alternativas=["Trimming de Crump con declaración de estimando"],
    ejemplo="e = sigma(4x0): ESS 85 de 3000, ESS/n = 0.03.",
    limitaciones=["El ESS no distingue la causa del solapamiento insuficiente"],
    fuentes=[
        {"cita": "Kish 1965", "url": "https://doi.org/10.4236/ojs.2014.45072", "tipo": "articulo"},
        {"cita": "Crump et al 2009", "url": "https://doi.org/10.1111/j.1541-0420.2008.01143.x", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-02", "C-12"],
    criterios_relacionados=["Q-04"],
    etiquetas=["diagnóstico", "soporte"],
)

_registrar(
    id="trimming_poblacion",
    titulo="Trimming y cambio de población",
    pregunta_operativa="Si recorto por soporte, ¿sobre quién vale mi efecto?",
    alcance="Declaración del cambio de estimando tras trimming.",
    condiciones=["Trimming aplicado o considerado"],
    principios=[
        "El trimming cambia el estimando, no solo la varianza",
        "Reportar el ATE recortado como poblacional completo es falso",
        "La ficha debe documentar la población post-trimming",
    ],
    pasos=[
        "Calcular qué fracción se excluye",
        "Declarar el nuevo estimando y su población",
        "Registrar en la ficha del modelo",
        "El servicio se abstiene donde el efecto no aplica",
    ],
    evidencia_requerida=["estimando_post_trimming", "fraccion_excluida"],
    fallos=["Recortar y no declarar", "Decir 'ATE completo' tras recorte"],
    alternativas=["No recortar y reportar mayor varianza"],
    ejemplo="Trimming 42% conserva: el ATE vale sobre el 42% con soporte, no sobre el 100%.",
    limitaciones=["La decisión de recortar es del dominio, no del pipeline"],
    fuentes=[
        {"cita": "Crump et al 2009", "url": "https://doi.org/10.1111/j.1541-0420.2008.01143.x", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-12", "C-14"],
    criterios_relacionados=["Q-04", "Q-07"],
    etiquetas=["diagnóstico", "estimando"],
)

_registrar(
    id="sensibilidad",
    titulo="Análisis de sensibilidad Rosenbaum",
    pregunta_operativa="¿Cuánto confusor oculto haría cruzar el cero?",
    alcance="Cuantificación de robustez frente a confusión no medida.",
    condiciones=["Efecto estimado con SE", "Método de sensibilidad elegido"],
    principios=[
        "Gamma mide la fuerza del confusor que revertiría la conclusión",
        "Gamma de Rosenbaum tiene dominio >= 1",
        "La sensibilidad acota, no prueba ausencia de confusión",
    ],
    pasos=[
        "Calcular Gamma con el método elegido",
        "Reportar Gamma con su interpretación",
        "Declarar el criterio de revisión asociado",
    ],
    evidencia_requerida=["gamma_reportada", "interpretacion"],
    fallos=["Gamma < 1 con método Rosenbaum", "No interpretar Gamma"],
    alternativas=["E-value", "Control negativo como proxy"],
    ejemplo="Gamma 0.8: un confusor moderado hace cruzar el cero. Poco robusto.",
    limitaciones=["La interpretación de Gamma depende del contexto"],
    fuentes=[
        {"cita": "Rosenbaum 2002", "url": "https://doi.org/10.1007/978-1-4757-4132-7", "tipo": "libro"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-08"],
    criterios_relacionados=["Q-02"],
    etiquetas=["diagnóstico", "confusión"],
)

_registrar(
    id="cate",
    titulo="CATE y heterogeneidad",
    pregunta_operativa="¿En quién difiere el efecto?",
    alcance="Estimación y validación de heterogeneidad de efectos.",
    condiciones=["Estimando declarado (CATE o policy)", "Datos suficientes por estrato"],
    principios=[
        "El CATE se valida OOS, no in-sample",
        "La Qini mide ranking, no magnitud",
        "Intervalos que se solapan: heterogeneidad sugerida, no concluida",
    ],
    pasos=[
        "Entrenar meta-learner (S/T/X) solo en train",
        "Evaluar PEHE OOS contra verdad del DGP o Qini OOS",
        "Reportar por estrato con IC",
    ],
    evidencia_requerida=["pehe_oos_o_qini", "por_estrato_con_ic"],
    fallos=["PEHE in-sample", "Elegir corte por máxima diferencia"],
    alternativas=["Efecto único (ATE) cuando no hay potencia"],
    ejemplo="nodegree=1: 1060 [233,1887] vs nodegree=0: 2345 [1357,3333]: solapan.",
    limitaciones=["Sin verdad, no hay PEHE: solo Qini"],
    fuentes=[
        {"cita": "Künzel et al 2019", "url": "https://doi.org/10.1073/pnas.1804597116", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-12"],
    criterios_relacionados=["Q-04"],
    etiquetas=["estimación", "heterogeneidad"],
)

_registrar(
    id="policy_evaluation",
    titulo="Evaluación de políticas",
    pregunta_operativa="¿Quién tratar y con qué presupuesto?",
    alcance="Valor de política y comparación con baselines.",
    condiciones=["CATE estimado OOS", "Regla de decisión declarada"],
    principios=[
        "El valor de política se estima OOS con IPW",
        "Comparar con aleatorio y tratar-a-todos",
        "El umbral se declara antes de mirar el valor",
    ],
    pasos=[
        "Declarar el umbral de tratamiento",
        "Estimar V(pi) por IPW OOS",
        "Comparar con aleatorio y todos",
        "Reportar proporción tratada",
    ],
    evidencia_requerida=["valor_ipw_oos", "comparacion_baselines"],
    fallos=["Elegir umbral maximizando valor in-sample"],
    alternativas=["Policy óptima con restricciones de presupuesto"],
    ejemplo="tau>0: valor 0.55 vs aleatorio 0.07, trata 60%.",
    limitaciones=["El valor IPW hereda la calidad del propensity"],
    fuentes=[
        {"cita": "Athey & Wager 2021", "url": "https://doi.org/10.1073/pnas.1900467118", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-12"],
    criterios_relacionados=["Q-04"],
    etiquetas=["estimación", "política"],
)

_registrar(
    id="iv",
    titulo="Variables instrumentales",
    pregunta_operativa="¿Tengo un instrumento válido y suficientemente fuerte?",
    alcance="Condiciones de validez y fuerza de instrumentos.",
    condiciones=["Instrumento candidato identificado"],
    principios=[
        "Relevancia: el instrumento mueve el tratamiento",
        "Exclusión: solo afecta el resultado a través del tratamiento",
        "El F de primera etapa mide la fuerza",
    ],
    pasos=[
        "Verificar F de primera etapa > 10",
        "Discutir plausibilidad de exclusión",
        "Reportar LATE, no ATE",
    ],
    evidencia_requerida=["f_primera_etapa", "discusion_exclusion"],
    fallos=["F < 10 con inferencia inválida", "Confundir LATE con ATE"],
    alternativas=["DML-IV", "Diseño observacional"],
    ejemplo="Card 1995: cercanía a universidad, F moderado, LATE en compliers.",
    limitaciones=["La exclusión no es comprobable con datos"],
    fuentes=[
        {"cita": "Card 1995", "url": "https://doi.org/10.2307/2118320", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-08"],
    criterios_relacionados=["Q-02"],
    etiquetas=["identificación", "iv"],
)

_registrar(
    id="did",
    titulo="Diferencias en diferencias",
    pregunta_operativa="¿Puedo comparar antes y después entre grupos?",
    alcance="DiD con tendencias paralelas.",
    condiciones=["Datos de panel pre y post", "Grupo de control comparable"],
    principios=[
        "Las tendencias paralelas son el supuesto clave",
        "El control sintético es una extensión",
        "Los tests de placebo temporal validan el supuesto",
    ],
    pasos=[
        "Verificar tendencias pre-tratamiento paralelas",
        "Estimar el efecto DiD",
        "Test de placebo con periodo pre falsificado",
    ],
    evidencia_requerida=["tendencias_paralelas", "placebo_temporal"],
    fallos=["Tendencias no paralelas ignoradas"],
    alternativas=["Control sintético", "Rambachan & Roth para tendencias"],
    ejemplo="Texas 1993: expansión carcelaria, DiD con condados de control.",
    limitaciones=["El supuesto de tendencias no es comprobable post-tratamiento"],
    fuentes=[
        {"cita": "Rambachan & Roth 2023", "url": "https://doi.org/10.1093/restud/rdad018", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-08"],
    criterios_relacionados=["Q-02"],
    etiquetas=["identificación", "panel"],
)

_registrar(
    id="rd",
    titulo="Discontinuidad de regresión",
    pregunta_operativa="¿Hay un corte administrativo que asigne el tratamiento?",
    alcance="RDD con validación de continuidad y ancho de banda.",
    condiciones=["Variable de forzamiento con umbral", "Continuidad en el umbral"],
    principios=[
        "La comparación es local al umbral",
        "El ancho de banda se elige con método, no a ojo",
        "Los tests de McCrary validan la densidad",
    ],
    pasos=[
        "Verificar densidad de la variable de forzamiento",
        "Elegir ancho de banda (Imbens-Kalyanaraman o CV)",
        "Estimar el efecto local en el umbral",
    ],
    evidencia_requerida=["test_mccrary", "ancho_de_banda_justificado"],
    fallos=["Ancho de banda elegido post-hoc"],
    alternativas=["RDD difuso cuando hay no cumplimiento"],
    ejemplo="Lee et al 2004: elecciones reñidas, umbral en 50%.",
    limitaciones=["El efecto es local al umbral, no poblacional"],
    fuentes=[
        {"cita": "Imbens & Lemieux 2008", "url": "https://doi.org/10.1016/j.jeconom.2007.05.001", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-08"],
    criterios_relacionados=["Q-02"],
    etiquetas=["identificación", "rd"],
)

_registrar(
    id="transportabilidad",
    titulo="Transportabilidad y validez externa",
    pregunta_operativa="¿El efecto de mi muestra vale en la población objetivo?",
    alcance="Condiciones para transportar efectos entre poblaciones.",
    condiciones=["Efecto estimado en muestra fuente", "Población objetivo definida"],
    principios=[
        "La validez externa no se hereda del tamaño de muestra",
        "Transportar requiere supuestos sobre qué difiere",
        "El soporte de covariables limita dónde se puede extrapolar",
    ],
    pasos=[
        "Comparar distribución de covariables fuente vs objetivo",
        "Identificar qué mecanismos podrían diferir",
        "Declarar el dominio de validez del efecto",
    ],
    evidencia_requerida=["comparacion_poblaciones", "dominio_validez"],
    fallos=["Asumir que el efecto transporta sin evidencia"],
    alternativas=["Re-ponderar por propensión de participación"],
    ejemplo="Efecto de NSW: no transporta a CPS sin re-ponderar.",
    limitaciones=["La validez externa es un juicio de dominio, no un test"],
    fuentes=[
        {"cita": "Bareinboim & Pearl 2013", "url": "https://doi.org/10.1145/2487575.2487645", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-14"],
    criterios_relacionados=["Q-02"],
    etiquetas=["validez", "generalización"],
)

_registrar(
    id="linaje",
    titulo="Linaje, versionado y reproducibilidad",
    pregunta_operativa="¿Puedo reconstruir qué datos y código produjeron este número?",
    alcance="Registro de versiones con hash y alias champion.",
    condiciones=["Artefactos con hash SHA-256", "Registro local persistente"],
    principios=[
        "El hash es identidad, no paranoia",
        "Las versiones son inmutables",
        "El alias champion se escribe atómicamente",
    ],
    pasos=[
        "Hash de cada artefacto (datos, código, config)",
        "Registrar versión con manifest",
        "Promover solo con puerta en pasa",
        "Invalidar verificaciones al cambiar artefactos",
    ],
    evidencia_requerida=["manifest_con_hash", "champion_resuelto"],
    fallos=["Editar in-place", "Tabla sustituida sin registro"],
    alternativas=["MLflow", "DVC cuando el equipo lo soporta"],
    ejemplo="v0001 con hash cd5a772e... de observed_train.csv.",
    limitaciones=["El hash verifica integridad, no veracidad causal"],
    fuentes=[
        {"cita": "Kleppmann 2017", "url": "https://doi.org/10.1093/oso/9780199642611.001.0001", "tipo": "libro"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-09"],
    criterios_relacionados=["Q-08"],
    etiquetas=["ingeniería", "versionado"],
)

_registrar(
    id="servicio",
    titulo="Servicio de estimación causal",
    pregunta_operativa="¿Cómo sirvo el efecto sin exponer los datos?",
    alcance="Servicio local con bundle y abstención.",
    condiciones=["Bundle validado del registro", "Soporte declarado en tarjeta"],
    principios=[
        "El bundle viaja, el dato no",
        "La abstención es respuesta de primera clase (HTTP 200)",
        "Dos consultas idénticas devuelven lo mismo",
    ],
    pasos=[
        "Cargar bundle del registro (champion)",
        "Para cada consulta: verificar soporte",
        "Dentro: responder con efecto, IC, versión",
        "Fuera: abstenerse sin número",
    ],
    evidencia_requerida=["humo_servicio", "abstencion_verificada"],
    fallos=["Servir número fuera de soporte", "Leer tabla de entrenamiento"],
    alternativas=["CLI equivalente cuando HTTP no aplica"],
    ejemplo="GET /efecto → 1596.0 [1004.8, 2187.3] v0001; age=99 → abstención.",
    limitaciones=["El servicio no reentrena por request"],
    fuentes=[
        {"cita": "Huyen 2022 Cap 5", "url": "https://doi.org/10.1093/oso/9780199642611.001.0001", "tipo": "libro"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-04"],
    criterios_relacionados=["Q-07"],
    etiquetas=["operación", "servicio"],
)

_registrar(
    id="monitoreo",
    titulo="Monitoreo causal en producción",
    pregunta_operativa="¿Sigue siendo válido el efecto que sirvo?",
    alcance="Cuatro señales causal-aware sobre ventanas de producción.",
    condiciones=["Referencia fija", "Pipeline de re-estimación disponible"],
    principios=[
        "Drift marginal no basta: vigilar mecanismo de asignación",
        "El efecto se reestima, no se predice",
        "Una sola acción, no cuatro semáforos",
    ],
    pasos=[
        "Comparar ventana contra referencia fija",
        "Puntuar propensity de referencia en ventana",
        "Reestimar efecto y contrastar formalmente",
        "Producir una acción del vocabulario de cinco",
    ],
    evidencia_requerida=["senales_ventana", "accion_producida"],
    fallos=["Reajustar propensity en ventana", "Solo monitorear marginales"],
    alternativas=["Monitoreo genérico de MLOps como complemento"],
    ejemplo="Regla X1→X2: señal (ii) detecta sin mover marginales.",
    limitaciones=["La confusión no observada no tiene señal"],
    fuentes=[
        {"cita": "Sculley et al 2015", "url": "https://doi.org/10.5555/2969442.2969461", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-07"],
    criterios_relacionados=["Q-06"],
    etiquetas=["operación", "monitoreo"],
)

_registrar(
    id="seguridad",
    titulo="Seguridad en sistemas causales",
    pregunta_operativa="¿Qué datos no deben salir del sistema y cómo lo garantizo?",
    alcance="Separación de verdad, secretos, y límites del workspace.",
    condiciones=["Pared definida", "Workspace delimitado"],
    principios=[
        "La verdad del DGP nunca llega al pipeline del agente",
        "Los secretos van por referencia, no en código",
        "Rechazar rutas fuera del workspace autorizado",
    ],
    pasos=[
        "Verificar que truth_* no está en observed_*",
        "Configurar secretos por variables de entorno",
        "Validar rutas contra el workspace",
    ],
    evidencia_requerida=["pared_verificada", "sin_secretos_en_codigo"],
    fallos=["Truth colado en observed", "Credenciales en el bundle"],
    alternativas=["Vault para secretos en producción"],
    ejemplo="comprobar_pared: truth_train.csv no existe en el paquete.",
    limitaciones=["La seguridad física del workspace es responsabilidad del host"],
    fuentes=[
        {"cita": "Kleppmann 2017", "url": "https://doi.org/10.1093/oso/9780199642611.001.0001", "tipo": "libro"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-10", "C-11"],
    criterios_relacionados=["Q-05"],
    etiquetas=["seguridad", "operación"],
)

_registrar(
    id="incidentes_rollback",
    titulo="Incidentes y rollback",
    pregunta_operativa="¿Qué hago cuando el monitor alerta?",
    alcance="Procedimiento de respuesta a incidentes y reversión segura.",
    condiciones=["Monitor en producción", "Registro con versiones"],
    principios=[
        "Las señales orientan revisión, no prueban la causa",
        "El rollback apunta a una versión anterior íntegra",
        "Toda decisión de rollback queda registrada",
    ],
    pasos=[
        "Leer la acción del monitor (alertar/abstenerse/revisar)",
        "Si abstenerse: detener servicio inmediatamente",
        "Si revisar: investigar identificación antes de tocar el modelo",
        "Si rollback: apuntar champion a versión anterior",
    ],
    evidencia_requerida=["accion_registrada", "version_rollback"],
    fallos=["Reentrenar sin revisar identificación", "Rollback sin registro"],
    alternativas=["Canary: servir versión vieja a fracción del tráfico"],
    ejemplo="Ventana de positividad: falla → champion vuelve a v0000.",
    limitaciones=["El rollback no arregla el problema de datos subyacente"],
    fuentes=[
        {"cita": "Sculley et al 2015", "url": "https://doi.org/10.5555/2969442.2969461", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-06", "C-07"],
    criterios_relacionados=["Q-06"],
    etiquetas=["operación", "incidente"],
)

_registrar(
    id="nube_costos",
    titulo="Nube y costos",
    pregunta_operativa="¿Qué cambia al desplegar en nube y cuánto cuesta?",
    alcance="Preparación de despliegue en contenedores administrados.",
    condiciones=["Dockerfile sin privilegios", "Configuración por variables"],
    principios=[
        "El mismo bundle y contrato en local y nube",
        "Los secretos van por referencia del gestor de la plataforma",
        "La equivalencia es contractual, no bit a bit",
    ],
    pasos=[
        "Empaquetar en imagen Docker sin privilegios",
        "Configurar variables de entorno para la plataforma",
        "Definir límites de recursos y plan de rollback",
        "Documentar costos estimados",
    ],
    evidencia_requerida=["dockerfile_validado", "config_sin_secretos"],
    fallos=["Secretos en la imagen", "Sin plan de rollback"],
    alternativas=["Cloud Run, ECS, Lambda con adaptadores"],
    ejemplo="Dockerfile copia bundle, no datos. Cloud Run con 512MB.",
    limitaciones=["Sin credenciales no se verifica el despliegue real"],
    fuentes=[
        {"cita": "Reis & Housley 2022", "url": "https://doi.org/10.1093/oso/9780199642611.001.0001", "tipo": "libro"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-04", "C-05"],
    criterios_relacionados=["Q-07", "Q-08"],
    etiquetas=["operación", "nube"],
)

_registrar(
    id="placebo_control_negativo",
    titulo="Placebo y control negativo",
    pregunta_operativa="¿Puedo falsar mi resultado sin verdad?",
    alcance="Tests de falsación que no requieren datos de verdad.",
    condiciones=["Efecto estimado", "Outcome de control negativo disponible"],
    principios=[
        "El placebo permuta el tratamiento: el efecto debe desaparecer",
        "El control negativo comparte confusores pero no es afectado",
        "Un p grande no prueba identificación, solo no la refuta",
    ],
    pasos=[
        "Permutar tratamiento 500+ veces, construir distribución nula",
        "Verificar que el ATE observado es atípico en la nula",
        "Estimar efecto sobre control negativo: debe ser cero",
    ],
    evidencia_requerida=["p_placebo", "ate_control_negativo"],
    fallos=["Placebo con 20 permutaciones", "Control negativo post-hoc"],
    alternativas=["Sensibilidad Rosenbaum como complemento"],
    ejemplo="Placebo: nula [-0.078, 0.071], ATE 0.77 (p < 0.001). Control: p=0.64.",
    limitaciones=["La ausencia de señal no certifica causalidad"],
    fuentes=[
        {"cita": "Lipsitch et al 2010", "url": "https://doi.org/10.1093/aje/kwq239", "tipo": "articulo"},
    ],
    fecha_revision="2026-11-07",
    contratos_relacionados=["C-08"],
    criterios_relacionados=["Q-02"],
    etiquetas=["diagnóstico", "falsación"],
)


# ================================================================ BÚSQUEDA

def _tokenizar(texto: str) -> set[str]:
    """Tokenización simple: minúsculas, sin acentos, palabras de 3+ letras."""
    import unicodedata
    normalizado = unicodedata.normalize("NFD", texto.lower())
    sin_acentos = "".join(c for c in normalizado if unicodedata.category(c) != "Mn")
    return {t for t in re.split(r"\W+", sin_acentos) if len(t) >= 3}


def buscar_conocimiento(
    consulta: str, limite: int = 10, **filtros: str
) -> list[dict]:
    """Búsqueda léxica determinista con ranking por relevancia.

    Args:
        consulta: texto libre (español o inglés).
        limite: máximo de resultados.
        filtros: etiqueta, contrato, criterio, dominio.

    Returns:
        Lista de fichas con score, ordenada por relevancia.
    """
    tokens = _tokenizar(consulta)
    if not tokens:
        return []
    resultados = []
    for ficha in _FICHAS:
        # Aplicar filtros
        if "etiqueta" in filtros and filtros["etiqueta"] not in ficha.get("etiquetas", []):
            continue
        if "contrato" in filtros and filtros["contrato"] not in ficha.get("contratos_relacionados", []):
            continue
        if "criterio" in filtros and filtros["criterio"] not in ficha.get("criterios_relacionados", []):
            continue
        # Calcular score
        texto_ficha = " ".join([
            ficha.get("titulo", ""),
            ficha.get("pregunta_operativa", ""),
            ficha.get("alcance", ""),
            " ".join(ficha.get("principios", [])),
            " ".join(ficha.get("etiquetas", [])),
        ])
        tokens_ficha = _tokenizar(texto_ficha)
        interseccion = tokens & tokens_ficha
        if not interseccion:
            continue
        score = len(interseccion) / len(tokens)
        # Bonus por coincidencia en título
        tokens_titulo = _tokenizar(ficha.get("titulo", ""))
        if tokens & tokens_titulo:
            score += 0.2
        resultados.append({
            "id": ficha["id"],
            "titulo": ficha["titulo"],
            "score": round(score, 3),
            "pregunta": ficha.get("pregunta_operativa", ""),
        })
    resultados.sort(key=lambda r: (-r["score"], r["id"]))
    return resultados[:limite]


def obtener_ficha(id_ficha: str) -> dict | None:
    """Recupera una ficha completa por id."""
    for ficha in _FICHAS:
        if ficha["id"] == id_ficha:
            return ficha
    return None


def listar_fichas() -> list[str]:
    """Lista los ids de todas las fichas."""
    return sorted(f["id"] for f in _FICHAS)


def contar_fichas() -> int:
    """Número total de fichas registradas."""
    return len(_FICHAS)
