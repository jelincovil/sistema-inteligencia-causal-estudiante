// Apéndice G: Plantilla de model card causal
#import "../template/template.typ": *

#chapter[Plantilla de _model card_ causal]
<ap-model-card-causal>

#theorem-number-reset()

Este apéndice desarrolla en detalle la plantilla de _model card_ causal introducida en el @cap-model-card-causal, con la explicación de cada campo y un ejemplo completo. Se usa para todo modelo causal registrado en el repositorio local#(if es-curso [ a lo largo del curso, incluido el proyecto final]).

== Campos obligatorios y su propósito
<sec-apG-campos>

#table(
  columns: (1.3fr, 2.7fr),
  align: left,
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Campo*], [*Qué debe responder*]),
  [Estimando], [¿Qué cantidad exacta se estima? (ATE, CATE$(x)$, LATE, política óptima). No basta con nombrar la variable de resultado.],
  [Diseño de identificación], [¿Experimental, cuasi-experimental (panel, IV, RDD) u observacional puro? Determina qué tan defendible es el resultado sin supuestos adicionales.],
  [Supuestos declarados], [Lista explícita, con la clase de cada supuesto. Los *observables* (soporte común, balance, fuerza del instrumento, estabilidad del efecto) llevan un umbral calibrado y su última verificación. Los *no observables* (no confusión condicional, exclusión del instrumento, tendencias paralelas posteriores al tratamiento) llevan un método de sensibilidad compatible o el estado `sin_cuantificacion_valida`, su limitación y un plazo de revisión (@cap-supuestos-no-observables); ninguno se declara "verificado". Referencia al DAG cuando exista uno (@cap-intervencion-contrafactual).],
  [Población de entrenamiento], [Las variables que delimitan la población (edad, geografía, período temporal, criterio de elegibilidad), que son la información mínima para aplicar el criterio de transportabilidad del @cap-generalizacion-transportabilidad antes de reusar el modelo, y la regla de soporte que el servicio hace cumplir (en la versión de referencia, el rango de cada covariable observado al entrenar, calculado de los datos y no escrito a mano).],
  [Roles causales], [¿Qué columna es el tratamiento, cuál el resultado, cuáles las covariables y los instrumentos? Es el `CausalSchema` (@cap-ingenieria-datos-causales) guardado como datos.],
  [Métricas], [Efecto puntual, intervalo de confianza, tamaño de muestra y especificación del estimador (_learner_, número de _folds_). Cada intervalo nombra su objeto: ATE, CATE puntual, efecto de grupo o pseudoresultado transformado. La calibración conforme de un pseudoresultado no se registra como cobertura del efecto individual.],
  [Resultados de validación], [Resultado de la prueba placebo (@cap-validacion) y del chequeo de balance (@cap-datos-entrenamiento-causales) más recientes.],
  [No usar este modelo para], [Lista explícita de usos indebidos previsibles: poblaciones fuera de rango, decisiones individuales sin considerar el intervalo, reinterpretación del ATE como efecto garantizado.],
  [Historial de versiones], [Fecha de cada reentrenamiento, resultado del proceso _champion-challenger_ (@cap-aprendizaje-continuo) que lo promovió.],
)

== Plantilla completa
<sec-apG-plantilla>

#figure(
  kind: raw,
  caption: [Plantilla completa de _model card_ causal, para copiar y guardar junto al artefacto local.],
  ```markdown
---
license: mit
tags: [causal-inference, <metodo-usado>]
---

# <Nombre del modelo>

## Estimando
<Que cantidad causal exacta estima este modelo.>

## Diseno de identificacion
<Experimental / cuasi-experimental / observacional. Justificacion breve.>

## Supuestos declarados
### Observables (con umbral y ultima verificacion)
- Soporte comun: <metrica> <operador> <umbral>. Ultima verificacion
  <fecha>: <valor> (<paso / no paso>).
- <Balance, fuerza del instrumento, estabilidad del efecto, segun el diseno>
### No observables (con sensibilidad y plazo de revision)
- No confusion condicional en: <lista de covariables>.
  Sensibilidad: <metodo compatible o sin_cuantificacion_valida>.
  Si se cuantifica: valor critico de la decision <valor>;
  escala de referencia <covariable observada, rango del efecto>.
  Si no: limitacion <por que no hay metodo valido disponible>.
  Calculada el <fecha>; revisar antes del <fecha>.
- <Otros supuestos del diseno: exclusion del instrumento,
  tendencias paralelas posteriores al tratamiento>
- DAG (si existe): <enlace o referencia>

## Poblacion de entrenamiento
<Variables que delimitan la poblacion. Rango temporal. Fuente de datos.>
**No valido fuera de esta poblacion sin verificar transportabilidad.**

## Metricas
- Efecto estimado: <valor> (IC 95%: [<inf>, <sup>])
- n = <tamano de muestra>
- Especificacion: <learner, K-folds, etc.>

## Resultados de validacion
- Prueba placebo: <paso / no paso, fecha>
- Chequeo de balance: <resultado, fecha>

## No usar este modelo para
- <Uso indebido 1>
- <Uso indebido 2>

## Historial de versiones
| Version | Fecha | Cambio | Promovido por |
|---------|-------|--------|----------------|
| 1.0     | <fecha> | Version inicial | n/a |
```
) <lst-apG-plantilla-completa>

== Checklist antes de registrar
<sec-apG-checklist>

#checklist[
  - Todos los campos obligatorios de la @sec-apG-campos están completos, ninguno dice "N/A" sin justificación.
  - La sección "No usar este modelo para" incluye al menos un uso indebido específico del dominio del modelo, no solo genérico.
  - El `CausalSchema` (@cap-ingenieria-datos-causales) del modelo se registró junto con el artefacto serializado.
  - La _model card_ se actualizó en el mismo registro local que cualquier reentrenamiento (ninguna versión del modelo circula con una _model card_ desactualizada).
]

== Esquema legible por máquinas
<sec-apG-schema>

La _model card_ Markdown es para personas. Para máquinas existe el mismo contrato en forma de una ficha JSON que viaja junto al artefacto y que la operación _metadatos_ del servicio devuelve tal cual (@sec-despliegue-contrato). Para que sea verificable en el CI local del @cap-cicd-causal se fija un esquema JSON versionado. Sus campos son los de la tabla de la @sec-apG-campos, con dos diferencias deliberadas: el historial de versiones completo vive en el Markdown y el JSON lleva solo la versión vigente, y se añaden los roles causales para que el servicio no dependa de ningún objeto serializado. Esta es la versión 2 del esquema; la anterior solo pedía el nombre de cada supuesto.

#figure(
  kind: raw,
  caption: [Esquema JSON versionado de la _model card_ causal (`causal-model-card-v2`).],
  ```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "causal-model-card-v2",
  "type": "object",
  "required": ["schema_version", "estimando", "diseno_identificacion", "supuestos",
               "roles", "poblacion", "metricas", "validacion", "no_usar_para", "version"],
  "properties": {
    "schema_version": {"const": "causal-model-card-v2"},
    "estimando": {
      "type": "object", "required": ["tipo", "formula"],
      "properties": {"tipo": {"enum": ["ATE", "ATT", "CATE", "LATE", "policy_value"]},
                     "formula": {"type": "string"}}},
    "diseno_identificacion": {
      "type": "object", "required": ["tipo", "metodo"],
      "properties": {"tipo": {"enum": ["RCT", "cuasi", "observacional"]},
                     "metodo": {"type": "string"}}},
    "supuestos": {
      "type": "array", "minItems": 1,
      "items": {
        "type": "object", "required": ["nombre", "clase"],
        "properties": {
          "nombre": {"type": "string"},
          "clase": {"enum": ["observable", "no_observable"]},
          "covariables": {"type": "array", "items": {"type": "string"}},
          "umbral": {
            "type": "object", "required": ["metrica", "operador", "valor", "calibracion"],
            "properties": {
              "metrica": {"type": "string"},
              "operador": {"enum": ["<", "<=", ">", ">="]},
              "valor": {"type": "number"},
              "calibracion": {
                "type": "object", "required": ["tasa_falsas_alarmas", "fecha"],
                "properties": {"tasa_falsas_alarmas": {"type": "number", "exclusiveMinimum": 0, "maximum": 1},
                               "fecha": {"type": "string", "format": "date"}}}}},
          "ultima_verificacion": {
            "type": "object", "required": ["fecha", "valor", "paso"],
            "properties": {"fecha": {"type": "string", "format": "date"},
                           "valor": {"type": "number"},
                           "paso": {"type": "boolean"}}},
          "sensibilidad": {
            "type": "object",
            "required": ["estado", "metodo", "fecha", "revisar_antes_de"],
            "properties": {"estado": {"enum": ["cuantificada", "sin_cuantificacion_valida"]},
                           "metodo": {"type": "string"},
                           "objeto": {"type": "string"},
                           "parametro": {"type": "string"},
                           "umbral_decision": {"type": "number"},
                           "valor_critico": {"type": "number"},
                           "escala": {"type": "object"},
                           "limitacion": {"type": "string"},
                           "decision_fragil": {"type": "boolean"},
                           "fecha": {"type": "string", "format": "date"},
                           "revisar_antes_de": {"type": "string", "format": "date"}},
            "allOf": [
              {"if": {"properties": {"estado": {"const": "cuantificada"}}},
               "then": {"required": ["objeto", "parametro", "umbral_decision", "valor_critico", "escala"]}},
              {"if": {"properties": {"estado": {"const": "sin_cuantificacion_valida"}}},
               "then": {"required": ["limitacion"]}}
            ]}},
        "allOf": [
          {"if": {"properties": {"clase": {"const": "observable"}}},
           "then": {"required": ["umbral", "ultima_verificacion"]}},
          {"if": {"properties": {"clase": {"const": "no_observable"}}},
           "then": {"required": ["sensibilidad"]}}]}},
    "roles": {
      "type": "object", "required": ["tratamiento", "resultado", "covariables"],
      "properties": {"tratamiento": {"type": "string"},
                     "resultado": {"type": "string"},
                     "covariables": {"type": "array", "minItems": 1, "items": {"type": "string"}},
                     "instrumentos": {"type": "array", "items": {"type": "string"}}}},
    "poblacion": {
      "type": "object", "required": ["descripcion", "soporte"],
      "properties": {
        "descripcion": {"type": "string"},
        "fuente": {"type": "string"},
        "soporte": {
          "type": "object", "required": ["regla", "rangos"],
          "properties": {
            "regla": {"enum": ["rango_por_covariable"]},
            "rangos": {"type": "object",
                       "additionalProperties": {"type": "array", "items": {"type": "number"},
                                                "minItems": 2, "maxItems": 2}}}}}},
    "metricas": {
      "type": "object", "required": ["efecto", "ic95", "n"],
      "properties": {"efecto": {"type": "number"},
                     "ic95": {"type": "array", "items": {"type": "number"}, "minItems": 2, "maxItems": 2},
                     "n": {"type": "integer", "minimum": 1},
                     "spec": {"type": "object"}}},
    "validacion": {"type": "object"},
    "no_usar_para": {"type": "array", "minItems": 1, "items": {"type": "string"}},
    "version": {
      "type": "object", "required": ["modelo", "hash_datos_entrenamiento"],
      "properties": {"modelo": {"type": "string"},
                     "hash_datos_entrenamiento": {"type": "string", "pattern": "^sha256:[0-9a-f]{64}$"}}}
  }
}
  ```
) <lst-apG-schema>

El esquema distingue dos clases de supuestos, y esa distinción es lo que cambió. Un supuesto *observable* trae su umbral (con la tasa de falsas alarmas y la fecha con que se calibró) y su última verificación antes del registro. Un supuesto *no observable* trae un método compatible y su cuantificación, o declara que no hay una cuantificación válida disponible; en ambos casos lleva fecha y plazo de revisión. Los no observables no tienen campo de verificación, porque ningún dato los verifica y un campo así invitaría a llenarlo. La ficha guarda solo la verificación vigente al registrar. Las posteriores viven en el reporte del monitoreo (@cap-monitoreo-causal), que cita la versión de la ficha.

Y una ficha que lo cumple. Los valores numéricos son ilustrativos: no provienen de una corrida.

#figure(
  kind: raw,
  caption: [Ejemplo de ficha JSON válida contra el esquema anterior (valores ilustrativos).],
  ```json
{
  "schema_version": "causal-model-card-v2",
  "estimando": {"tipo": "ATE", "formula": "E[Y(1) - Y(0)]"},
  "diseno_identificacion": {"tipo": "observacional", "metodo": "DML con cross-fitting"},
  "supuestos": [
    {"nombre": "soporte_comun", "clase": "observable",
     "umbral": {"metrica": "ess_sobre_n", "operador": ">=", "valor": 0.6,
                "calibracion": {"tasa_falsas_alarmas": 0.05, "fecha": "2026-01-10"}},
     "ultima_verificacion": {"fecha": "2026-01-15", "valor": 0.82, "paso": true}},
    {"nombre": "no_confusion", "clase": "no_observable",
     "covariables": ["age", "black", "south", "married"],
     "sensibilidad": {"estado": "cuantificada", "metodo": "robustez_r2_lineal",
                      "objeto": "coeficiente lineal del tratamiento",
                      "parametro": "valor de robustez respecto del umbral de decision",
                      "umbral_decision": 0.05, "valor_critico": 0.13,
                      "escala": {"r2_d": 0.22, "r2_y": 0.07, "rango_efecto": [0.045, 0.097]},
                      "decision_fragil": true,
                      "fecha": "2026-01-15", "revisar_antes_de": "2026-04-15"}}
  ],
  "roles": {"tratamiento": "educ", "resultado": "lwage",
            "covariables": ["age", "black", "south", "married"], "instrumentos": []},
  "poblacion": {
    "descripcion": "Hombres de 24 a 34 anos, EE. UU., 1976",
    "fuente": "Card (1995)",
    "soporte": {"regla": "rango_por_covariable",
                "rangos": {"age": [24, 34], "black": [0, 1], "south": [0, 1], "married": [0, 1]}}
  },
  "metricas": {"efecto": 0.071, "ic95": [0.058, 0.084], "n": 3003,
               "spec": {"learner": "GBM", "K": 5, "dml_variant": "DML2"}},
  "validacion": {"placebo": {"paso": true, "fecha": "2026-01-15"}},
  "no_usar_para": ["Poblaciones fuera del rango de entrenamiento",
                   "Decisiones individuales sin considerar el intervalo"],
  "version": {"modelo": "1.2",
              "hash_datos_entrenamiento": "sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"}
}
  ```
) <lst-apG-ejemplo-json>

El CI de referencia valida tres cosas: (i) que la ficha cumple el esquema sintáctico; (ii) que el veredicto `paso` de cada supuesto observable coincide con su valor y su umbral, y que ninguno falló; y (iii) que la huella de los datos coincida con la del conjunto de referencia versionado (@cap-cicd-causal). Las dos últimas no las expresa un esquema, por lo que las comprueba código del CI. El campo `dml_variant` exige nombrar DML1 o DML2 (Nota técnica #ref(<sec-cap10_teorema_dml>, supplement: none)), lo que cierra el círculo entre la teoría y lo que el artefacto declara.
