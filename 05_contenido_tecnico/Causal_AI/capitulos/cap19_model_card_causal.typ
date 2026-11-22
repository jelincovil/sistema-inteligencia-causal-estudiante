// Capítulo 19: model cards causales y registro local de artefactos.
// Plantilla B. Abre la Parte IV. Contrato C-05 (capa L2); implementación de referencia en #capa-impl (capa L3).
#import "../template/template.typ": *

#chapter[_Model cards_ causales y registro local de artefactos]
<cap-model-card-causal>

#theorem-number-reset()

#cuadrodecision[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Decisión:*], [Documentar supuestos de identificación en la _model card_, no solo métricas de desempeño],
    [*Alternativas:*], [_Model card_ estándar (solo _accuracy_/desempeño) vs. _model card_ causal extendida],
    [*Trade-off clave:*], [Fricción de documentar más campos vs. riesgo de uso indebido del modelo por otros equipos],
    ..if not es-principios {([*Stack:*], [Python, `json`, `joblib`, repositorio local])},
    [*Riesgo principal:*], [Que un consumidor del modelo lo use fuera de su población o supuestos de validez sin saberlo],
  )
]

#if es-curso [
#monorepo[
  Plantilla de ficha causal (*model card*) del curso: #code[04_produccion_causal/B2_model_card_ci/model_card/MODEL_CARD.md] (alineada al Apéndice G). Lab #code[L17]. Bundle local: #code[04_produccion_causal/B1_servicio_dml/artifacts/] y registros de #code[04_produccion_causal/artefactos/demo/]. La card debe declarar estimando (ATE), supuestos, población del benchmark y límites (datos sintéticos; no uso clínico). El runtime valida la versión `local-0.2`; el esquema v2 del Apéndice G es el ejemplo didáctico.
]

]
#if es-comercial [#nota-repo-comercial()]
== El problema de diseño
<sec-model-card-problema>

El Capítulo 15 sirvió el estimador DML como un endpoint que cualquiera puede consultar. Pero "poder consultarlo" no es lo mismo que "poder usarlo correctamente". Una _model card_, la práctica ya estándar en la comunidad de ML de documentar un modelo junto con sus métricas, datos de entrenamiento y limitaciones @mitchell2019modelcards, resuelve ese problema para modelos predictivos. El problema de diseño de este capítulo es que la _model card_ estándar no tiene ningún campo para lo que más importa en un modelo *causal*: bajo qué supuestos de identificación es válido, para qué población se estimó el efecto, y qué covariables se controlaron. Registrar un estimador causal sin una _model card_ específica es, en la práctica, invitar a que se use fuera de su dominio de validez.

== Opciones y trade-offs
<sec-model-card-opciones>

#opciones[
  - *_Model card_ estándar.* Documenta arquitectura, métricas de desempeño (_accuracy_, F1, RMSE) y, en el mejor de los casos, algunas consideraciones éticas generales. Para un modelo causal, es *insuficiente*: no hay campo para el DAG supuesto, ni para el conjunto de covariables de puerta trasera, ni para la población sobre la que el efecto es válido.
  - *_Model card_ causal extendida.* Añade explícitamente los campos que un modelo predictivo no necesita: estimando ($tau(x)$, ATE, LATE), supuestos de identificación declarados, diseño (observacional/cuasi-experimental/experimental), población de entrenamiento y límites de validez externa. El costo es puramente de fricción, la de completar más campos antes de publicar; no hay costo técnico ni de infraestructura.
]

La decisión no es realmente una disyuntiva difícil, porque la _model card_ extendida domina a la estándar para cualquier modelo causal, pero vale la pena presentarla como *trade-off*: completar los campos causales añade fricción mínima y evita usos fuera del dominio de validez.

== #t-decision
<sec-model-card-decision>

Todo modelo causal registrado siguiendo este capítulo usa la plantilla de *model card causal* del Apéndice G, con los siguientes campos obligatorios: estimando, diseño de identificación, supuestos declarados y clasificados (con referencia al DAG cuando exista uno), roles causales, población de entrenamiento (con las variables que la delimitan y la regla de soporte), y una sección explícita de "no usar este modelo para". La ficha existe en dos formas con el mismo contenido: un documento para personas y un archivo legible por máquina, que es el que consume el servicio del @cap-despliegue-servicio.

Los supuestos de una ficha no son todos del mismo tipo, y tratarlos igual es el error más frecuente. Algunos se pueden mirar en los datos: el soporte común, el balance, la fuerza de un instrumento, la estabilidad del efecto. Para esos la ficha guarda un umbral calibrado y la última verificación, y el monitoreo del @cap-monitoreo-causal los vuelve a mirar. Otros no se pueden verificar con ningún dato: la no confusión condicional, la exclusión de un instrumento, las tendencias paralelas posteriores al tratamiento. Para esos la ficha no puede guardar una verificación, que no existe. Guarda cuánto tendría que fallar el supuesto para cambiar la decisión, hasta cuándo vale ese cálculo y qué eventos obligan a revisarlo (@cap-supuestos-no-observables). Una ficha que escribe "verificado" junto a un supuesto no observable afirma algo que nadie comprobó.

== El contrato de la ficha
<sec-model-card-contrato>

Como el servicio del @cap-despliegue-servicio lee la ficha para decidir cuándo abstenerse, la ficha deja de ser documentación y pasa a ser una interfaz. Se rige por su propio contrato.

#contrato(
  "C-05",
  "Ficha causal del modelo",
  entrada: [
    Los roles causales (@cap-ingenieria-datos-causales), los datos de entrenamiento, el estimando, el diseño de identificación, los supuestos declarados con su clase, las métricas y los resultados de validación.
  ],
  salida: [
    Un documento para personas y un archivo legible por máquina con el mismo contenido, que valida contra el esquema versionado del @ap-model-card-causal. El archivo incluye la regla de soporte y la versión del modelo con la huella de los datos con que se entrenó. Cada supuesto observable lleva su umbral (con la tasa de falsas alarmas y la fecha de calibración) y su última verificación; cada supuesto no observable lleva un método de sensibilidad compatible y su alcance, o declara `sin_cuantificacion_valida`, además de su fecha de revisión.
  ],
  invariantes: [
    (1) La ficha viaja con el artefacto y no se actualiza por separado. (2) Cada reentrenamiento produce una ficha nueva con versión y huella de datos nuevas. (3) El soporte y la huella los calcula el proceso de registro a partir de los datos, no una persona. (4) El veredicto de cada supuesto observable lo calcula el proceso de registro con el valor y el umbral, y una ficha con un observable que no pasó no se registra. (5) Un supuesto no observable nunca figura como verificado: lleva su sensibilidad, y esta se calcula de los datos y del estimador registrados, no la escribe una persona. (6) La ficha guarda la verificación vigente al registrar; las posteriores viven en el reporte del monitoreo, que cita la versión de la ficha.
  ],
  fallos: [
    Una ficha que no valida no se registra. Una ficha cuya huella no coincide con los datos de referencia bloquea el registro. Un supuesto no observable al que se le escribe a mano una verificación, o una sensibilidad que nadie recalculó tras cambiar los datos: el contrato lo detecta solo en lo que el esquema y la huella alcanzan, y por eso el @cap-supuestos-no-observables agrega su propio contrato. Un modelo registrado sin ficha, o con una ficha de otra versión, es el fallo que el contrato existe para impedir.
  ],
  aceptacion: [
    (a) La ficha valida contra el esquema. (b) La huella coincide con la del conjunto de datos de referencia versionado. (c) El servicio del @cap-despliegue-servicio carga la ficha y se abstiene fuera del soporte que ella declara. (d) Una ficha con un supuesto observable sin umbral o con un veredicto que no sale de su valor, y una con un supuesto no observable sin sensibilidad, se rechazan.
  ],
)

#capa-impl[
== Implementación de referencia
<sec-model-card-implementacion>

El documento para personas sigue una plantilla en Markdown. Los valores numéricos del ejemplo son ilustrativos: no provienen de una corrida.

#figure(
  kind: raw,
  caption: [Plantilla mínima de _model card_ causal en Markdown (valores ilustrativos).],
  ```markdown
---
license: mit
tags: [causal-inference, dml, econml]
---

# Estimador DML de retorno a la educacion

## Estimando
ATE del efecto de anios de educacion (`educ`) sobre el logaritmo del salario (`wage`).

## Diseno de identificacion
Observacional. Ver DAG en `docs/dag.png`.

## Supuestos declarados
### Observables
- Soporte comun: ESS/n >= 0.6 (falsas alarmas 5%, calibrado el 2026-01-10).
  Ultima verificacion 2026-01-15: 0.82 (paso).
### No observables
- No confusion condicional en: age, black, south, married.
  Sensibilidad: robustez R2 respecto del umbral de decision 0.05.
  Valor critico 0.13. Calculada el 2026-01-15; revisar antes del 2026-04-15.

## Poblacion de entrenamiento
Hombres, 24-34 anios, encuesta NLS 1976 (Card, 1995). n=3,003.
**No valido fuera de este rango etario ni fuera de EE.UU.**

## Metricas
ATE estimado: 0.071 (IC 95%: [0.058, 0.084])
Cross-fitting: K=5. Learner: GradientBoostingRegressor.

## No usar este modelo para
- Poblaciones fuera del rango de entrenamiento (ver @cap-generalizacion-transportabilidad).
- Decisiones individuales sin considerar el intervalo de confianza del CATE.
- Cualquier uso que reinterprete el ATE como un efecto garantizado a nivel individual.
```
) <lst-model-card-causal>

El archivo legible por máquina se construye con una función. Calcula de los datos lo que el servicio hace cumplir, el soporte y la huella, para que nadie lo escriba a mano:

#figure(
  kind: raw,
  caption: [Construcción de `model_card.json` (esquema `causal-model-card-v2`, Ap. G.4). El soporte, la huella y el veredicto de los supuestos observables salen de los datos.],
  ```python
import copy
import hashlib
import json
import operator
from pathlib import Path

OPERADORES = {"<": operator.lt, "<=": operator.le, ">": operator.gt, ">=": operator.ge}


def con_veredicto(supuesto):
    """Un supuesto observable recibe su `paso` calculado con el valor y el umbral:
    no lo escribe una persona. Un no observable no tiene veredicto."""
    sup = copy.deepcopy(supuesto)
    if sup["clase"] == "observable":
        u, v = sup["umbral"], sup["ultima_verificacion"]
        v["paso"] = bool(OPERADORES[u["operador"]](v["valor"], u["valor"]))
    return sup


def construir_model_card(schema, df, ruta_datos, *, estimando, diseno, supuestos,
                         metricas, validacion, no_usar_para, version,
                         descripcion, fuente=None):
    """Ficha causal legible por maquina. `schema` es el CausalSchema del Cap. 4;
    se guarda como datos (roles), no como objeto serializado."""
    X = schema.X(df)
    huella = hashlib.sha256(Path(ruta_datos).read_bytes()).hexdigest()
    poblacion = {"descripcion": descripcion,
                 "soporte": {"regla": "rango_por_covariable",
                             "rangos": {c: [float(X[c].min()), float(X[c].max())]
                                        for c in schema.covariates}}}
    if fuente:
        poblacion["fuente"] = fuente
    return {
        "schema_version": "causal-model-card-v2",
        "estimando": estimando,
        "diseno_identificacion": diseno,
        "supuestos": [con_veredicto(s) for s in supuestos],
        "roles": {"tratamiento": schema.treatment, "resultado": schema.outcome,
                  "covariables": list(schema.covariates),
                  "instrumentos": list(schema.instruments)},
        "poblacion": poblacion,
        "metricas": metricas,
        "validacion": validacion,
        "no_usar_para": no_usar_para,
        "version": {"modelo": version, "hash_datos_entrenamiento": "sha256:" + huella},
    }


def guardar_model_card(card, ruta="model/model_card.json"):
    with open(ruta, "w", encoding="utf-8") as f:
        json.dump(card, f, ensure_ascii=False, indent=2)
```
) <lst-construir-model-card>

Con la ficha escrita, el registro local copia el paquete completo. La ficha en JSON es parte del paquete, porque es lo que lee el servicio:

#figure(
  kind: raw,
  caption: [Registro local del modelo y su _model card_.],
  ```python
from pathlib import Path
import shutil

origen = Path("model")
destino = Path("artifacts/registered_model")
destino.mkdir(parents=True, exist_ok=True)

for nombre in ("dml_estimator.joblib", "model_card.json", "MODEL_CARD.md"):
    shutil.copy2(origen / nombre, destino / nombre)
```
) <lst-registrar-modelo-local>
]

== #t-aplicacion
<sec-model-card-aplicacion>

La sección "No usar este modelo para" de la ficha cita directamente el capítulo de generalización y transportabilidad (@cap-generalizacion-transportabilidad, más adelante en este volumen), que formaliza precisamente cuándo un efecto estimado en una población es válido en otra. Documentar la población de entrenamiento en la _model card_ no es un ejercicio de transparencia general: es la información mínima que otro analista necesitaría para aplicar, correctamente, el criterio de transportabilidad de ese capítulo antes de reutilizar el modelo, y es también la regla con la que el servicio decide cuándo abstenerse. La clasificación de los supuestos hace lo mismo con el monitoreo: lo que la ficha declara observable lo vigila el @cap-monitoreo-causal con el umbral que la ficha trae, y lo que declara no observable lo cubre la revisión del @cap-supuestos-no-observables.

== Señales de alerta y checklist operativo
<sec-model-card-alertas>

#checklist[
  - La _model card_ reporta métricas de desempeño pero no menciona el diseño de identificación ni los supuestos.
  - No existe una sección explícita de "no usar para", dejando implícito el dominio de validez.
  - El paquete registrado no incluye los roles causales (@cap-ingenieria-datos-causales) junto al modelo, obligando a cualquier consumidor a adivinar qué covariables espera. Guardarlos como datos en la ficha evita depender de un objeto serializado que solo se carga donde existe la misma clase.
  - La _model card_ no se actualizó tras reentrenar el modelo con datos nuevos (riesgo ya anticipado en el @cap-anatomia-sistema).
  - El paquete incluye solo el documento para personas, sin la ficha legible por máquina validada contra el esquema (@ap-model-card-causal).
  - El soporte o la huella de los datos de la ficha se escribieron a mano y no los calculó el proceso de registro.
  - Un supuesto no observable figura como "verificado", o su sensibilidad se escribió a mano o no se recalculó tras reentrenar o cambiar de población.
  - Todos los supuestos de la ficha están en una sola lista sin clase, de modo que nadie sabe cuáles vigila el monitoreo y cuáles solo revisa una persona.
]

== Ejercicios y notas bibliográficas
<sec-model-card-ejercicios>

=== Ejercicios conceptuales
<sec-model-card-ejercicios-conceptuales>

+ Compare la _model card_ causal de este capítulo con una ficha estándar de un modelo predictivo. Liste tres campos presentes en la causal y ausentes en la estándar, y explique por qué cada uno importa específicamente para un modelo causal.

+ @arnold2019factsheets propone una idea relacionada pero distinta a las _model cards_: las FactSheets como "declaración de conformidad del proveedor". Investigue brevemente la diferencia de enfoque y discuta si sería más o menos apropiada que una _model card_ para un estimador causal registrado por un equipo interno (no un proveedor externo).

+ Un consumidor recibe una ficha cuyo soporte declara `age` entre 24 y 34 y consulta con `age = 41`. ¿Qué debe hacer el servicio? Escriba en una frase por qué esa regla es más segura si la calcula el proceso de registro que si la escribe quien entrena el modelo.

+ Clasifique los supuestos de un estimador DML de efectos de un programa de capacitación (no confusión condicional, soporte común, estabilidad del efecto en el tiempo, estabilidad del mecanismo de asignación) en observables y no observables, y diga para cada uno qué campo de la ficha lo registra.

#capa-impl[
=== Ejercicio de infraestructura
<sec-model-card-ejercicios-infra>

#if es-curso [
+ Complete la primera mitad del Notebook de producción B2: adapte la plantilla del #ref(<lst-model-card-causal>, supplement: [listado]) al modelo de su Notebook A2, construya su `model_card.json` con el #ref(<lst-construir-model-card>, supplement: [listado]), registre el paquete local con el #ref(<lst-registrar-modelo-local>, supplement: [listado]) y verifique que ambas fichas se encuentran junto al artefacto serializado.
] else [
+ Adapte la plantilla de @lst-model-card-causal a un estimador causal propio (por ejemplo, el estimador DML servido en el @cap-despliegue-servicio), construya su `model_card.json` con el #ref(<lst-construir-model-card>, supplement: [listado]), registre el paquete local con el #ref(<lst-registrar-modelo-local>, supplement: [listado]) y verifique que ambas fichas se encuentran junto al artefacto serializado.
]
]

=== Notas bibliográficas
<sec-model-card-notas>

#cite(<mitchell2019modelcards>, form: "prose") introduce el formato de _model card_ que este capítulo extiende. #cite(<gebru2021datasheets>, form: "prose") propone la pieza complementaria y, para un sistema causal, igual de necesaria: las *datasheets for datasets*, que documentan cómo se recolectaron los datos, con qué propósito, quién los financió y qué preprocesamiento sufrieron. La documentación de datasets mediante *datasheets* (@gebru2021datasheets, Gebru et al. 2021) es análoga a las Model Cards para modelos causales (Apéndice G) y debe incluir información sobre motivación, composición, proceso de recolección, preprocesamiento, usos recomendados y consideraciones éticas. La conexión con este libro es directa y vale la pena hacerla explícita: la mitad de los campos que una datasheet exige (cómo se seleccionaron las unidades, si hubo criterios de elegibilidad, qué instancias faltan) son exactamente la *ficha de procedencia del tratamiento* del @cap-datos-entrenamiento-causales, y son la información sin la cual un consumidor externo no puede evaluar si el supuesto de identificación declarado en la _model card_ es siquiera plausible. Una _model card_ causal sin su datasheet documenta el modelo pero no lo que lo hace válido. #cite(<arnold2019factsheets>, form: "prose") propone un tercer formato, orientado a proveedores de servicios de IA, con más énfasis en cumplimiento normativo. La discusión de documentación de interfaces de inferencia en general se retoma de @kastner2024mlip, Capítulo 10; su versión legible por máquina es la operación de metadatos del servicio del @cap-despliegue-servicio.
