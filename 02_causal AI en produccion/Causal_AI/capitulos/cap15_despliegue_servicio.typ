// Capítulo 15: despliegue de un estimador causal como servicio.
// Plantilla B. Cierra la Parte II. Piloto de la edición en capas: el contrato C-04 (capa L2) es lo que dura;
// la implementación de referencia (capa L3) va dentro de #capa-impl y no aparece en la edición de principios.
#import "../template/template.typ": *

#chapter[Despliegue de un estimador causal como servicio]
<cap-despliegue-servicio>

#theorem-number-reset()

#cuadrodecision[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Decisión:*], [Servir el estimador como un servicio síncrono que puede abstenerse, no como biblioteca embebida ni como _batch_],
    [*Alternativas:*], [Biblioteca embebida vs. servicio de red vs. estimaciones _batch_ precomputadas],
    [*Trade-off clave:*], [Latencia y simplicidad de biblioteca vs. desacoplamiento y reutilización de un servicio],
    ..if not es-principios {([*Stack:*], [FastAPI y `joblib`; Docker es opcional])},
    [*Riesgo principal:*], [_Training-serving skew_, y un servicio que responde siempre, también donde el efecto no está identificado],
  )
]

#if es-curso [
#monorepo[
  Implementación de referencia: #code[04_produccion_causal/B1_servicio_dml/] (FastAPI, #code[inference.py] pura; Docker es opcional). Artefactos de entrada: #code[artifacts/dml_estimator.joblib] + #code[artifacts/model_card.json] (la ficha del modelo, con el esquema de roles del C-01: covariables, tratamiento y resultado). Labs: #code[L12], #code[L14]. Humo: #code[B1_servicio_dml/tests/test_api.py] y #code[autograder/grade_b1.py]. El endpoint local expone #code[/health], #code[/metadata] y #code[/predict].
]

]
#if es-comercial [#nota-repo-comercial()]
== El problema de diseño
<sec-despliegue-problema>

El @cap-dml produjo un estimador DML entrenado y validado según los criterios del @cap-validacion. El problema de este capítulo, que cierra la Parte II, es distinto: ¿cómo se pone ese estimador a disposición de alguien, sea un compañero de equipo, otro servicio o una aplicación, que necesita una estimación sin tener que reabrir el entrenamiento? La respuesta no es única. #cite(<huyen2022dmls>, form: "prose") (Capítulo 7) y #cite(<kastner2024mlip>, form: "prose") (Capítulo 10) describen varios patrones de _serving_ con costos y beneficios distintos, y elegir entre ellos es una decisión de diseño y no un detalle de implementación.

Para un estimador causal hay además una pregunta que un modelo predictivo no tiene. Un clasificador puede responder a cualquier entrada, y su error crece de forma gradual a medida que la entrada se aleja de lo que vio al entrenar. Un efecto causal estimado, en cambio, solo está identificado donde los datos de entrenamiento tenían variación en el tratamiento. Fuera de esa población el servicio puede devolver un número perfectamente formado, con su intervalo, y el número no significa nada. Un servicio causal responsable necesita por eso una tercera posibilidad además de acertar y de equivocarse: negarse a responder.

== Opciones y trade-offs
<sec-despliegue-opciones>

#opciones[
  - *Biblioteca embebida.* El modelo serializado se distribuye como un paquete que cualquier proceso importa directamente. Es la opción de menor latencia, porque no hay llamada de red, y la más simple de depurar. Su costo: cada consumidor necesita el mismo entorno con las mismas versiones de dependencias, y actualizar el modelo exige redistribuir el paquete a todos los consumidores.
  - *Servicio de red.* El modelo vive detrás de una interfaz de red. Los consumidores envían covariables y reciben una estimación, sin necesidad de tener instaladas las dependencias del modelo. Permite actualizar el modelo en un solo lugar y servir a consumidores escritos en cualquier lenguaje. Su costo es la latencia de red y la necesidad de operar un servicio (disponibilidad, escalado, versionado de la interfaz).
  - *_Batch_ precomputado.* Las estimaciones se calculan por adelantado para toda la población conocida y se guardan en una tabla que se consulta por clave. Es la opción de menor latencia de consulta y la más simple de auditar, porque todas las estimaciones existen antes de cualquier consulta. No sirve para unidades nuevas que no estaban al momento del cómputo, y el efecto estimado puede quedar desactualizado si las covariables de una unidad cambian entre el cómputo y la consulta.
]

Un segundo trade-off es la función de inferencia misma. #cite(<kastner2024mlip>, form: "prose") enfatiza que debe ser *pura*, sin efectos secundarios ni estado mutable entre llamadas, para que el mismo código se ejecute de forma idéntica en el entrenamiento y en el servicio y se evite el _training-serving skew_ ya anticipado en el @cap-anatomia-sistema.

== #t-decision
<sec-despliegue-decision>

El curso adopta un *servicio síncrono detrás de una interfaz de red local* como patrón de referencia#solo-curso[ para todos los notebooks de producción de la Serie B], con una regla que lo distingue de un servicio de predicción: puede abstenerse. Se prefiere sobre la biblioteca embebida porque permite consultar y actualizar el estimador sin replicar el entorno en cada consumidor, y sobre el _batch_ precomputado porque los casos de uso del curso#solo-curso[ (Notebooks A2 y A4)] requieren estimar el efecto para unidades nuevas y no solo para una población fija conocida de antemano.

#frontera(2026)[
  En 2026 lo habitual es exponer el servicio como una interfaz HTTP con mensajes JSON, y recurrir a gRPC cuando importa la latencia entre servicios. Empaquetar el servicio en un contenedor es frecuente pero no necesario. El contrato de la sección siguiente no depende del transporte ni del empaquetado, de modo que un cambio en estas costumbres no obliga a reescribir el capítulo.
]

== El contrato del servicio
<sec-despliegue-contrato>

Este libro no fija una tecnología para el servicio: fija un contrato. Cualquier implementación lo cumple, sea un servicio web, una biblioteca o una tarea programada que llena una tabla, si pasa su prueba de aceptación. Los contratos del libro se numeran (C-01 a C-07) y comparten el formato que introdujo el C-01 (@sec-datoscausales-contrato) y que usa la caja que sigue: qué operaciones ofrece, qué recibe, qué devuelve, qué debe cumplirse siempre, cómo falla y cómo se comprueba.

#contrato(
  "C-04",
  "Servicio de estimación",
  operaciones: [
    _estimar_: recibe las covariables de una unidad y responde con un efecto y su intervalo, o se abstiene. _metadatos_: devuelve la ficha causal del modelo que está respondiendo, legible por máquina. _salud_: indica que el servicio está vivo, y nada más; no dice nada sobre la validez del efecto.
  ],
  entrada: [
    Para _estimar_, las covariables de una unidad, con los nombres y tipos declarados en los roles causales del modelo (@cap-ingenieria-datos-causales). Las otras dos operaciones no reciben datos.
  ],
  salida: [
    Para _estimar_, el estado (_responde_ o _abstiene_) y la versión del modelo. Si responde, el efecto estimado y su intervalo de confianza. Si se abstiene, el motivo y las covariables que quedaron fuera de la población, y ningún número. La población de soporte y los supuestos se consultan con _metadatos_.
  ],
  invariantes: [
    (1) Nunca devuelve un número sin su intervalo y sin su estado. (2) Con la misma versión del modelo y la misma entrada, la salida es idéntica. (3) Fuera de la población declarada, se abstiene. (4) Ninguna operación modifica el modelo ni la ficha. (5) La ficha de _metadatos_ es la del artefacto que responde a _estimar_.
  ],
  fallos: [
    Una covariable ausente o de tipo inválido se rechaza como entrada inválida: ni se imputa ni se abstiene. Un valor faltante en una covariable que delimita la población cuenta como fuera de la población. Si el modelo o la ficha no se pueden cargar, el servicio no arranca, porque es preferible no responder a responder con un artefacto desconocido.
  ],
  aceptacion: [
    (a) Sobre datos con efecto conocido, la cobertura del intervalo no baja del piso calibrado más abajo. (b) Una consulta fuera de la población devuelve el estado _abstiene_ y ningún número. (c) Dos llamadas idénticas devuelven salidas idénticas. (d) Una entrada inválida se rechaza. (e) La ficha de _metadatos_ valida contra el esquema versionado del @ap-model-card-causal.
  ],
)

Cada decisión de diseño del contrato responde a un fallo concreto.

*La abstención es una respuesta, no un error.* El estado viaja dentro de la respuesta y no en un código de falla. Un consumidor que recibe un error lo trata como un problema técnico, reintenta o salta a un valor por defecto. Un consumidor que recibe _abstiene_ sabe que el servicio funciona y que el efecto no está disponible para esa unidad, y tiene que decidir qué hace sin él. Obligarlo a esa decisión es el propósito.

*La regla de soporte es explícita y viaja con el modelo.* La regla más barata de comprobar es que cada covariable esté dentro del rango observado al entrenar. Es una condición necesaria y no suficiente: una combinación de covariables puede no haberse visto nunca aunque cada valor por separado sí. Reglas más finas, como abstenerse donde la propensión estimada se acerca a 0 o a 1 (@cap-dml) o donde el tamaño efectivo de muestra local es bajo, cumplen el mismo contrato siempre que la ficha del modelo las declare. Lo que el contrato exige es que la regla exista, sea explícita y la calcule el proceso de registro a partir de los datos de entrenamiento, no una persona a mano.

*El intervalo es el del efecto condicional promedio.* Cubre el efecto medio entre las personas con esas covariables, no el efecto sobre una persona concreta. El procedimiento conforme del @cap-validacion calibra el pseudoresultado transformado y tampoco convierte este intervalo en uno para $Y_i(1)-Y_i(0)$. El servicio no promete cobertura del efecto individual.

*Las operaciones se comprueban en un orden deliberado.* La prueba de humo verifica primero _salud_, que el proceso vive; luego _metadatos_, que el artefacto cargado es el esperado (versión y huella de los datos); y solo entonces _estimar_, que la estimación es razonable. Un fallo en la segunda con éxito en la primera es el escenario silencioso que este capítulo busca hacer visible: el servicio responde, pero está sirviendo un modelo distinto del que el equipo cree.

=== La prueba de aceptación necesita datos con verdad conocida
<sec-despliegue-aceptacion>

#caso-canonico("Datos con efecto conocido")[
  Se simulan $n$ unidades con cuatro covariables independientes $X_1, dots, X_4 tilde N(0, 1)$. El tratamiento depende de la primera, $D tilde "Bernoulli"(sigma(0.5 X_1))$, y el resultado es $Y = tau D + sin(X_1) + 0.5 X_2 + epsilon$ con $epsilon tilde N(0, 1)$ y $tau = 0.5$ constante. La primera covariable es un confusor: afecta al tratamiento y al resultado, de modo que una comparación ingenua de medias no recupera $tau$ y un estimador ortogonalizado sí. Como el efecto es el mismo en toda la población, el intervalo que devuelva el servicio para cualquier unidad dentro de la población debe cubrir 0,5.
]

La prueba reajusta el estimador sobre $R$ réplicas independientes de estos datos y cuenta en cuántas el intervalo cubre 0,5. Falta decidir qué cobertura mínima se acepta, y esa cifra no puede ser una constante elegida a ojo. Si el intervalo cubre de verdad el 95 %, la cobertura observada en $R$ réplicas es una proporción con error estándar $sqrt(0.95 dot 0.05 slash R)$. La regla del libro acepta una cobertura observada no inferior a
$
0.95 - 3 sqrt(0.95 dot 0.05 / R),
$
que con $R = 200$ es 0,904. Se usan tres errores estándar porque una prueba que falla por azar una de cada veinte ejecuciones acaba ignorándose. Con $R = 200$, un servicio cuyo intervalo cubre de verdad el 95 % falla esta prueba en el 0,3 % de las ejecuciones (una de cada 370), y uno que cubre solo el 85 % la falla en el 98,5 %. Un intervalo que cubre el 90 % es más difícil de detectar: la prueba lo rechaza el 53 % de las veces, de modo que para detectar desviaciones pequeñas hay que aumentar $R$. En la simulación de verificación ($R = 200$, $n = 1 thin 000$, semilla fija) el estimador ortogonalizado cubrió el 96 % de las veces y pasó la prueba. La comparación ingenua de medias, que ignora el confusor, cubrió el 4,5 % y fue rechazada, que es lo que la prueba existe para lograr.

== #t-aplicacion
<sec-despliegue-aplicacion>

La respuesta del servicio no es solo el efecto puntual: incluye el estado, el intervalo y la versión del modelo, y la población de soporte se consulta en los metadatos. Esto no es una decisión estética. El @cap-anatomia-sistema comprometió que la interfaz debe comunicar algo más que un número, y que a veces la respuesta correcta es no dar ninguno. Aquí queda concreto: ningún consumidor puede usar el efecto estimado como válido para una población distinta de la de entrenamiento sin saberlo, porque el propio servicio se lo advierte o se niega a responder.

El servicio hace cumplir el soporte en cada consulta, pero desde una sola consulta no puede ver lo que el monitoreo sí ve en conjunto. El @cap-monitoreo-causal vigila la proporción de consultas que terminan en abstención: si crece, la población que consulta se está alejando de la de entrenamiento, y es una de las señales que activan las acciones del vocabulario del @cap-anatomia-sistema.

La operación de metadatos no es decorativa ni redundante con la _model card_ del @cap-model-card-causal. La _model card_ es documentación para personas y vive en el repositorio. Los metadatos son el mismo contrato expuesto en tiempo de ejecución y de forma legible por máquina, de modo que un consumidor automatizado puede verificar qué versión del modelo responde y bajo qué supuestos sin depender de que alguien haya leído un documento.

#capa-impl[
== Implementación de referencia
<sec-despliegue-implementacion>

La función de inferencia se separa del servicio web. Lee dos cosas empaquetadas con el modelo: el estimador serializado y la ficha del modelo en JSON (@cap-model-card-causal). La ficha trae los roles causales del @cap-ingenieria-datos-causales, es decir, el `CausalSchema` guardado como datos, y la regla de soporte. Guardar el esquema como datos y no como un objeto serializado evita un fallo clásico: un objeto de una clase definida en un notebook solo se puede cargar donde esa clase exista con el mismo nombre de módulo, y el servicio es otro proceso.

#figure(
  kind: raw,
  caption: [Función de inferencia pura, desacoplada del framework web. Implementa _estimar_ del contrato C-04.],
  ```python
# inference.py -- funcion pura, sin dependencias de FastAPI
import copy
import json
import joblib
import pandas as pd

_modelo = joblib.load("model/dml_estimator.joblib")
with open("model/model_card.json", encoding="utf-8") as f:
    _card = json.load(f)                  # contrato causal del artefacto

_COVARIABLES = _card["roles"]["covariables"]
_SOPORTE = _card["poblacion"]["soporte"]
assert _SOPORTE["regla"] == "rango_por_covariable", "regla de soporte no implementada"
assert set(_SOPORTE["rangos"]) <= set(_COVARIABLES)
_VERSION = _card["version"]["modelo"]


def estimar_efecto(covariables: dict) -> dict:
    """Funcion pura: la misma version y la misma entrada dan siempre la misma salida.
    Devuelve estado "responde" (efecto e intervalo) o "abstiene" (ningun numero)."""
    faltantes = set(_COVARIABLES) - set(covariables)
    if faltantes:
        raise ValueError(f"Faltan covariables requeridas: {sorted(faltantes)}")
    # not (lo <= v <= hi) y no (v < lo or v > hi): un valor faltante (NaN) tambien abstiene
    fuera = sorted(c for c, (lo, hi) in _SOPORTE["rangos"].items()
                   if not (lo <= covariables[c] <= hi))
    if fuera:
        return {"estado": "abstiene", "motivo": "fuera_de_poblacion",
                "covariables_fuera_de_rango": fuera, "version_modelo": _VERSION}
    X = pd.DataFrame([covariables])[_COVARIABLES]
    efecto = _modelo.effect(X)[0]
    ic_inf, ic_sup = _modelo.effect_interval(X, alpha=0.05)
    return {
        "estado": "responde",
        "efecto_estimado": float(efecto),
        "ic_95_inferior": float(ic_inf[0]),
        "ic_95_superior": float(ic_sup[0]),
        "version_modelo": _VERSION,
        # El intervalo es del efecto condicional promedio en estas covariables.
        # No cubre el efecto individual de esta persona.
    }
```
) <lst-inference-pura>

#figure(
  kind: raw,
  caption: [Servicio FastAPI que envuelve la función de inferencia. Una abstención responde con código 200: es una respuesta válida, no un error.],
  ```python
# app.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from inference import estimar_efecto, metadatos_modelo

app = FastAPI(title="Servicio de estimacion causal")

class Covariables(BaseModel):
    exper: float
    black: int
    south: int
    married: int

@app.post("/predict")
def predict(cov: Covariables):
    try:
        return estimar_efecto(cov.model_dump())
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

@app.get("/health")
def health():
    """Liveness: el proceso responde. No dice nada sobre validez causal."""
    return {"status": "ok"}

@app.get("/metadata")
def metadata():
    """Ficha causal del modelo servido: estimando, supuestos, poblacion y version.
    Permite a un consumidor decidir si el efecto es aplicable a su caso ANTES
    de llamar a /predict."""
    return metadatos_modelo()
```
) <lst-fastapi-app>

Los metadatos salen del mismo artefacto que la inferencia, de modo que lo que se declara y lo que responde no pueden divergir:

#figure(
  kind: raw,
  caption: [Metadatos del modelo, servidos desde el mismo archivo que alimenta la inferencia. Implementa _metadatos_ del contrato C-04.],
  ```python
# inference.py (continuacion del listado anterior)
def metadatos_modelo() -> dict:
    """Ficha causal legible por maquina del artefacto servido. Es el contenido de
    model_card.json, que valida contra el esquema local causal-model-card.local
    (versión local-0.2; el esquema didáctico causal-model-card-v2 del Ap. G.4
    queda como referencia conceptual); el CI lo verifica antes de registrar el
    modelo."""
    return copy.deepcopy(_card)           # copia: el llamador no puede alterar la ficha
```
) <lst-metadata-endpoint>

El empaquetado en un contenedor es opcional. Si se usa, conviene fijar las versiones de las dependencias, porque un contenedor construido con versiones libres se comporta distinto según el día en que se construya:

#figure(
  kind: raw,
  caption: [`Dockerfile` opcional para empaquetar el servicio.],
  ```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY inference.py app.py ./
COPY model/ ./model/
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```
) <lst-dockerfile>

En esta implementación, la prueba de humo pide primero `/health`, luego `/metadata` y por último `/predict`, el orden que fija el contrato.
]

== Señales de alerta y checklist operativo
<sec-despliegue-alertas>

#checklist[
  - La función de inferencia calcula las covariables con código distinto del usado durante el entrenamiento (riesgo directo de _training-serving skew_).
  - La respuesta devuelve solo el efecto puntual, sin intervalo y sin estado.
  - El servicio responde siempre un número, incluso con entradas fuera de la población de entrenamiento: no existe ninguna condición en la que se abstenga.
  - No existe una operación de salud verificable independientemente de la estimación.
  - No hay forma de saber, consultando el servicio, qué versión del modelo está respondiendo ni sobre qué datos se entrenó (metadatos ausentes, o sin versión y huella de los datos).
  - La regla de soporte la escribió una persona a mano en lugar de calcularla de los datos de entrenamiento, o no está en la ficha del modelo.
  - Las dependencias del servicio no están fijadas a versiones exactas, de modo que el servicio se comporta distinto según cuándo se construya.
]

== Ejercicios y notas bibliográficas
<sec-despliegue-ejercicios>

=== Ejercicios conceptuales
<sec-despliegue-ejercicios-conceptuales>

+ Para el caso de la política de _targeting_ del @cap-policy-learning, ¿cuál de las tres opciones de la @sec-despliegue-opciones sería más apropiada si el número de clientes a evaluar es fijo y conocido cada mes? Justifique.

+ Explique con sus propias palabras por qué separar la función de estimación de la interfaz de red facilita probar la lógica de inferencia sin necesidad de levantar el servicio. #capa-impl[(Listados #ref(<lst-inference-pura>, supplement: none) y #ref(<lst-fastapi-app>, supplement: none).)]

+ Un consumidor del servicio recibe _abstiene_ para el 12 % de sus consultas y pide que "el servicio devuelva la mejor estimación posible" en esos casos. ¿Qué responde usted? Distinga lo que el servicio puede ofrecer (por ejemplo, el rango de la población que sí conoce) de lo que no debe ofrecer, y explique qué decisión le toca tomar al consumidor.

+ La regla de soporte por rango de cada covariable es necesaria y no suficiente. Construya un ejemplo con dos covariables en el que una unidad cae dentro del rango de ambas y aun así el efecto no está identificado para ella. Proponga una regla más fina y diga qué costo tiene (por ejemplo, abstenerse en unidades donde el efecto sí estaba bien estimado).

+ Con $R = 100$ réplicas, calcule el piso de cobertura que fija la regla de la @sec-despliegue-aceptacion. ¿Qué pasa con la capacidad de la prueba para detectar un intervalo que cubre el 90 % cuando $R$ baja de 200 a 100? ¿Qué haría para recuperar potencia sin subir el costo de la prueba?

#capa-impl[
=== Ejercicio de infraestructura #solo-curso[(Lab, Notebook B1)]
<sec-despliegue-ejercicios-lab>

+ #solo-curso[Complete el Notebook de producción B1: s]#solo-comercial[S]erialice el estimador DML entrenado, genere la ficha `model_card.json` con el listado del @cap-model-card-causal, adapte los listados #ref(<lst-inference-pura>, supplement: none) y #ref(<lst-fastapi-app>, supplement: none) a su dataset y verifique con `curl` o el cliente HTTP de su elección que `/health` y `/metadata` responden, que `/predict` responde con una unidad de la población y que se abstiene con una unidad fuera de ella. Si lo desea, construya además la imagen con el #ref(<lst-dockerfile>, supplement: [listado]).
]

=== Notas bibliográficas
<sec-despliegue-notas>

#cite(<huyen2022dmls>, form: "prose"), Capítulo 7 ("Model Deployment and Prediction Service"), y #cite(<kastner2024mlip>, form: "prose"), Capítulo 10 ("Deploying a Model"), son las dos referencias principales de este capítulo. El segundo desarrolla en particular la discusión de _features_ dentro y fuera del servicio y el _training-serving skew_ retomada en la @sec-despliegue-aplicacion. La idea de que un sistema de decisión debe poder negarse a responder cuando no hay identificación se sigue de la condición de soporte común del @cap-prediccion-causalidad y de la discusión de validez externa del @cap-generalizacion-transportabilidad.
