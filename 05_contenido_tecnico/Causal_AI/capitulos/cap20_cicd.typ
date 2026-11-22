// Capítulo 20: CI/CD para modelos causales.
// Plantilla B. Cierra la Parte IV. Edición en capas: el contrato C-06 (capa L2) y el caso canónico son lo que
// dura; las herramientas y los listados (capa L3) van dentro de #capa-impl y no aparecen en la edición de principios.
#import "../template/template.typ": *

#chapter[CI/CD para modelos causales]
<cap-cicd-causal>

#theorem-number-reset()

#cuadrodecision[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Decisión:*], [El pipeline de CI debe correr pruebas de sanidad estadística, no solo pruebas de código],
    [*Alternativas:*], [CI genérico (solo tests de software) vs. CI con pruebas estadísticas causales integradas],
    [*Trade-off clave:*], [Tiempo de ejecución del pipeline vs. riesgo de publicar automáticamente un modelo roto],
    ..if not es-principios {([*Stack:*], [`pytest`, `jsonschema`, scripts de CI local; Docker es opcional])},
    [*Riesgo principal:*], [Que un cambio de código pase todos los tests de software y aun así rompa la validez causal],
  )
]

#if es-curso [
#monorepo[
  Script de referencia: #code[scripts/audit_repo.sh] (pytest Serie A, labs, humo B1–B4). Lab #code[L18]. Autograders: #code[grade_b1.py]…#code[grade_b4.py]. Simulaciones de este capítulo: #code[herramientas/verificaciones/verif_cap20.py] (opciones #code[--se] y #code[--sin-controles]). CI genérico de software *no basta*: el pipeline local exige humo de efecto/API/política.
]

]
#if es-comercial [#nota-repo-comercial()]
== El problema de diseño
<sec-cicd-problema>

El Capítulo 15 construyó el servicio; el Capítulo 19 registró el artefacto y su documentación localmente. Ninguno de los dos automatizó lo que ocurre *después*: cuando alguien modifica el código (agrega una covariable, cambia el _learner_ de _nuisance_, actualiza los datos de entrenamiento), ¿qué garantiza que la nueva versión no rompió algo antes de que se publique automáticamente? Un pipeline de CI/CD genérico, el que prueba por ejemplo que el servicio responde con el código de estado correcto, no detecta absolutamente nada sobre si el efecto estimado sigue siendo razonable. El problema de diseño de este capítulo es que un sistema causal necesita, además de las pruebas de software estándar, pruebas que sean sensibles a *lo que este libro entiende por "romperse"*: que un placebo deje de dar cero, que el intervalo de confianza colapse o se dispare, que el soporte común desaparezca con los nuevos datos.

== Opciones y trade-offs
<sec-cicd-opciones>

#opciones[
  - *CI genérico.* Corre únicamente pruebas de software: ¿el código importa sin error?, ¿el servicio responde?, ¿el paquete se construye? Es rápido (segundos a minutos), pero no detecta ningún problema de validez estadística: un cambio que introduce un mal control (@cap-intervencion-contrafactual) pasa este CI sin ninguna advertencia.
  - *CI con pruebas estadísticas integradas.* Además de las pruebas de software, ejecuta la prueba placebo y el chequeo de balance ya usados en capítulos anteriores (@cap-datos-entrenamiento-causales, @cap-validacion) como parte del pipeline automatizado, con umbrales que, si se violan, bloquean el registro local del artefacto. Es más lento (minutos, porque implica reentrenar o reestimar sobre datos de prueba) y requiere mantener un dataset de referencia fijo para que las pruebas sean reproducibles, pero es la única opción que previene que una regresión estadística llegue a producción sin supervisión humana.
]

== #t-decision
<sec-cicd-decision>

El pipeline de referencia de este capítulo corre en dos etapas: una etapa rápida de pruebas de software y una etapa de pruebas estadísticas (validación de la ficha, placebo repetido, estabilidad del efecto y balance, todas sobre un conjunto de referencia fijo), ambas ejecutadas automáticamente antes de registrar una actualización. Esta separación evita que cada cambio menor de código dispare un reentrenamiento costoso, sin sacrificar la garantía de que nada se registra sin pasar la prueba de sanidad estadística.

#frontera(2026)[
  En 2026 el ecosistema local de herramientas abiertas cubre bien cuatro tareas: registrar experimentos y versionar los artefactos del modelo, versionar los conjuntos de datos, validar el esquema y los rangos de los datos de entrada, y vigilar la deriva de las variables. Ninguna de esas herramientas sabe qué es un placebo, un chequeo de balance o un intervalo de confianza sobre un efecto: sus pruebas se detienen en la integridad de los datos y en la estabilidad de las métricas predictivas. El contrato de la sección siguiente describe por eso la etapa estadística y deja lo demás a lo que ofrezca el entorno. Si una herramienta nueva cubriera también esa etapa, el contrato seguiría siendo el mismo.
]

#capa-impl[
La implementación de este capítulo usa `pytest` y scripts locales por una razón puramente práctica: son herramientas abiertas y de baja fricción para un equipo sin infraestructura previa. Conviene situarla dentro del ecosistema local: *MLflow* para registrar experimentos y versionar artefactos de modelo; *DVC* en modo local para versionar el dataset de referencia; *Great Expectations* o *Pandera* para validar el esquema y los rangos de los datos de entrada; y *Evidently* para el monitoreo de _drift_ que el @cap-monitoreo-causal desarrolla. Lo que estas herramientas aportan es todo lo que no es la etapa estadística, y no conviene reimplementarlo.
]

Tres criterios de diseño de esa etapa merecen ser explícitos, porque determinan si el pipeline es útil o solo ruidoso. Primero, *el dataset de referencia debe estar congelado y versionado*: una prueba estadística sobre datos que cambian no distingue una regresión del código de un cambio en los datos. Segundo, *los umbrales deben fijarse antes y documentarse*, no ajustarse cuando la prueba falla: la tentación de relajar el umbral para desbloquear un _merge_ es exactamente el fallo que el pipeline existe para prevenir. Tercero, *un fallo estadístico no debe tratarse como un fallo de software*: el bloqueo correcto no es "arreglar el código hasta que pase" sino "un humano decide si el cambio en el efecto es legítimo"; un cambio genuino en el mundo también rompe un umbral, y esa es información valiosa, no un error.

== El contrato de la compuerta de registro
<sec-cicd-contrato>

Lo que este capítulo fija no es un conjunto de herramientas sino una compuerta: el punto único por el que un candidato pasa a ser la versión registrada. Cualquier sistema de integración continua la implementa si cumple el contrato siguiente, que usa el formato del C-04 (@sec-despliegue-contrato).

#contrato(
  "C-06",
  "Compuerta de registro",
  operaciones: [
    _verificar_: recibe un candidato y devuelve una decisión (_registra_ o _bloquea_) con el informe de cada prueba. _registrar_: copia el artefacto del candidato al registro local, y solo acepta un candidato cuya decisión _registra_ exista.
  ],
  entrada: [
    El candidato (el estimador entrenado y su ficha causal, contrato C-05 del @cap-model-card-causal). El conjunto de referencia, congelado y con su huella. Los umbrales de cada prueba, escritos y versionados antes de la corrida.
  ],
  salida: [
    La decisión y un informe que, para cada prueba, dice qué midió, qué valor obtuvo, qué umbral tenía y si pasó. Un bloqueo estadístico queda marcado como pendiente de decisión humana.
  ],
  invariantes: [
    (1) Nada llega al registro sin una decisión _registra_ del mismo candidato. (2) La etapa estadística solo corre si la de software pasó. (3) El conjunto de referencia y los umbrales se fijan antes de la corrida; cambiarlos es un cambio propio, que se revisa aparte del candidato que lo motivó. (4) Con el mismo candidato, los mismos datos y las mismas semillas, la decisión es idéntica. (5) Cada prueba declara qué clase de fallo cubre y cuál no. (6) Un bloqueo estadístico lo levanta una persona, con la justificación escrita, y nunca se levanta editando la prueba.
  ],
  fallos: [
    Datos de referencia que cambian en silencio: la prueba deja de distinguir una regresión del código de un cambio en los datos. Un umbral relajado para destrabar un cambio: el pipeline pasa a verificar lo que el equipo quiere y no lo que necesita. Un placebo único: se rechaza de vez en cuando aunque todo esté bien y bloquea por mala suerte. Cobertura aparente: hay pruebas, pero ninguna mira el fallo que ocurrió. Una ficha inválida: las pruebas posteriores no tienen sentido, y la etapa se detiene.
  ],
  aceptacion: [
    Se inyectan fallos de causa conocida sobre un caso con verdad conocida (el caso canónico de más abajo) y se comprueba la decisión. (a) El candidato sano se registra, con una tasa de falsos bloqueos que no supera la calculada. (b) Quitar un control clave bloquea, y lo bloquea la prueba de estabilidad, no el placebo. (c) Un error estándar declarado a la mitad del real bloquea en casi todas las corridas. (d) Una ficha cuya huella no coincide con la de los datos de referencia bloquea sin llegar a la etapa estadística. (e) _registrar_ sin decisión _registra_ es imposible.
  ],
)

Cada decisión del contrato responde a un fallo concreto.

*Hay un solo camino hacia el registro.* La compuerta no recomienda: decide, y la operación de registro rechaza al candidato que no tenga su decisión. Un control que depende de que alguien lo recuerde falla justo el día de más prisa, que es cuando más hace falta.

*El informe dice qué se midió, no solo si pasó.* La persona que recibe un bloqueo tiene que decidir si el cambio de efecto es legítimo, y para eso necesita el valor, el umbral y la prueba. Un "falló" sin números invita a relajar el umbral hasta que pase.

*Un bloqueo no apaga nada.* La compuerta decide si un candidato llega a ser la versión vigente. Mientras una persona lo revisa, la versión vigente sigue respondiendo, que en el vocabulario del @cap-anatomia-sistema es la acción _continuar_ (@sec-anatomia-acciones).

=== Qué mira cada prueba
<sec-cicd-pruebas>

Cada prueba de la etapa estadística mira una clase de fallo, y ninguna las mira todas. Saber cuál ve cada una evita la falsa tranquilidad de un pipeline con muchas pruebas que no miran el fallo que ocurre.

#table(
  columns: (1.2fr, 2.2fr, 2.2fr),
  align: left,
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Prueba*], [*Detecta*], [*No ve*]),
  [Validación de la ficha], [Una ficha incompleta o mal formada, un supuesto observable cuyo veredicto no sale de su valor y su umbral o que no lo supera, un supuesto no observable sin sensibilidad, datos distintos de los de referencia.], [Que lo que la ficha afirma sea cierto.],
  [Placebo repetido], [Un intervalo que no cubre lo que declara cuando el efecto es nulo, por ejemplo por un error estándar subestimado.], [Un control omitido: el tratamiento permutado no depende de nada.],
  [Estabilidad del efecto], [Un control omitido, un cambio de especificación o de datos que mueva el efecto respecto del registrado.], [Un error estándar mal calculado si el efecto puntual no se mueve.],
  [Balance y soporte], [Que los datos nuevos no tengan el solape que exige la identificación (@cap-datos-entrenamiento-causales).], [Una confusión no observada.],
)

El placebo permuta el tratamiento, así que este queda independiente de todas las covariables por construcción. Por eso no puede notar que falta un control: la omisión de una confusora solo sesga cuando el tratamiento depende de ella, y el tratamiento permutado no depende de nada. Lo que el placebo sí detecta es que el intervalo no tenga la cobertura que declara cuando el efecto es nulo. Para el control omitido hace falta otra prueba, que reestime el efecto real y lo compare con el valor registrado en la _model card_, con una tolerancia fijada antes de correrla. Y como un placebo aislado se rechaza una de cada veinte veces aunque todo esté bien, la prueba repite la permutación y tolera un número de rechazos que se calcula de antemano.

=== Los umbrales se calibran con la tasa medida
<sec-cicd-calibracion>

Si en cada permutación el placebo rechaza con probabilidad $p_0$ cuando el modelo está sano, y se repiten $R$ permutaciones con una tolerancia de $k$ rechazos, un modelo sano se bloquea con probabilidad $P(X > k)$, donde $X$ sigue una binomial con parámetros $R$ y $p_0$. El cálculo supone rechazos independientes, y las permutaciones comparten los mismos datos, de modo que es una aproximación. El valor de $p_0$ no es el nominal, y el caso canónico siguiente muestra por qué.

#caso-canonico("Lo que el placebo no ve")[
  Se simulan $n = 1 thin 500$ unidades con cuatro covariables: $X_1 tilde N(0, 1)$ y tres binarias, $X_2 tilde "Bernoulli"(0.3)$, $X_3 tilde "Bernoulli"(0.4)$ y $X_4 tilde "Bernoulli"(0.6)$. El tratamiento es continuo, $D = 12 + X_1 + 0.8 X_4 + nu$ con $nu tilde N(0, 1.5^2)$, y el resultado es $Y = 0.08 D + 0.20 X_1 + 0.15 X_4 - 0.10 X_2 + epsilon$ con $epsilon tilde N(0, 0.4^2)$. El efecto verdadero es 0,08. $X_1$ y $X_4$ confunden tratamiento y resultado, $X_2$ solo afecta al resultado y $X_3$ no afecta a nada.
]

Con los cuatro controles, el estimador recupera el efecto: entre 0,068 y 0,090 según la semilla de los datos (verdad 0,08), con un error estándar de alrededor de 0,007. El placebo, con 200 permutaciones del tratamiento y semilla fija, rechaza el 11 % de las veces y no el 5 % nominal. La causa se ve en las cifras: el estimador declara un error estándar medio de 0,0057 sobre las permutaciones, pero su estimación varía con una desviación estándar de 0,0068, de modo que el error declarado es un 16 % menor que el real.

Quitar controles no mueve el placebo. Sin la experiencia ni el estado civil (las dos confusoras), rechaza el 6,0 %; sin la experiencia, el 5,5 %; sin el estado civil, el 11 %. Ninguna cifra supera la del modelo completo. El efecto reestimado sí se mueve, y mucho. Medido en errores estándar del modelo completo, quitar las dos confusoras lo desplaza entre 8,9 y 9,8 errores estándar a lo largo de cinco semillas; quitar solo la experiencia, entre 8,4 y 9,0; quitar solo el estado civil, que confunde menos, entre 1,5 y 2,3. Una tolerancia de un error estándar detecta los tres casos, y una de tres errores estándar deja pasar el último.

La tabla traduce las tasas de rechazo en la probabilidad de que la compuerta bloquee. Las dos últimas filas simulan un error estándar declarado a dos tercios y a la mitad del real, con las mismas permutaciones.

#table(
  columns: (2.6fr, 1.1fr, 1.3fr, 1.3fr),
  align: (left, right, right, right),
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Situación*], [*Rechazo del placebo*], [*Bloqueo con 10 permutaciones y tolerancia 2*], [*Bloqueo con 20 permutaciones y tolerancia 5*]),
  [Modelo sano, tasa nominal], [5,0 %], [1,2 %], [0,03 %],
  [Modelo sano, tasa medida], [11,0 %], [8,8 %], [1,8 %],
  [Error estándar a 2/3 del real], [28,5 %], [58 %], [52 %],
  [Error estándar a 1/2 del real], [43,5 %], [88 %], [93 %],
)

Dos conclusiones. La primera es que la tolerancia se calcula con la tasa medida del modelo sano y no con la nominal. Con 10 permutaciones y tolerancia 2, que sería correcta si la tasa fuera del 5 %, el modelo sano de esta simulación se bloquearía el 8,8 % de las veces; con 20 permutaciones y tolerancia 5 baja al 1,8 %. La segunda es que el placebo es una prueba tosca contra el error estándar subestimado. Detecta con alta probabilidad una subestimación a la mitad (93 %), pero solo la mitad de las veces una subestimación a dos tercios (52 %), y las menores las deja pasar. Para esas hace falta otra evidencia, como la cobertura sobre datos con verdad conocida que pide el contrato C-04.

La regla de partida es medir $p_0$ con 200 permutaciones o más sobre el conjunto de referencia, elegir $R$ y $k$ de modo que $P(X > k)$ no supere el 2 %, y guardar $p_0$, $R$ y $k$ junto a la huella de los datos. Cuando el conjunto de referencia cambia, hay que medir $p_0$ de nuevo. La prueba de estabilidad sigue la misma lógica con otra unidad: su tolerancia se expresa en errores estándar del intervalo registrado, porque eso distingue un cambio de especificación del ruido. Con el código, los datos y las semillas congelados, reestimar da el mismo efecto y el desplazamiento es cero, de modo que cualquier tolerancia positiva es un permiso explícito para cambiar algo. Conviene empezar con un error estándar y subirla solo si una diferencia mayor no cambiaría la decisión que el efecto alimenta.

#capa-impl[
== Implementación de referencia
<sec-cicd-implementacion>

#figure(
  kind: raw,
  caption: [CI local con pruebas de software y estadísticas en etapas separadas.],
  ```bash
#!/usr/bin/env bash
# comandos locales de CI
set -euo pipefail

# Etapa rápida: software y servicio local
python -m compileall -q src tests
pytest tests/test_software.py -v
# opcional, solo si se empaqueta en contenedor:
docker build -t causal-service:local .

# Etapa estadística: no registrar artefactos si falla
python scripts/validar_schema.py
pytest tests/test_placebo.py -v --tb=short
pytest tests/test_efecto_estable.py -v --tb=short
pytest tests/test_balance.py -v --tb=short

# Registro local del bundle validado
mkdir -p artifacts/registered_model
cp model/dml_estimator.joblib model/model_card.json \
   MODEL_CARD.md artifacts/registered_model/
```
) <lst-cicd-local>

La etapa estadística empieza validando la ficha, porque una ficha inválida invalida todo lo que viene después. El script comprueba las tres cosas que el @ap-model-card-causal declara verificables por máquina: que la ficha cumple el esquema, que el veredicto de cada supuesto observable sale de su valor y su umbral y que ninguno falló, y que la huella de los datos coincide con la del conjunto de referencia versionado:

#figure(
  kind: raw,
  caption: [Validación de `model_card.json` en el CI local (Ap. G.4): esquema, supuestos observables y huella de los datos.],
  ```python
# scripts/validar_schema.py
import hashlib, json, sys
from pathlib import Path
from jsonschema import Draft202012Validator, FormatChecker

def cargar(ruta):
    return json.loads(Path(ruta).read_text(encoding="utf-8"))

card = cargar("model/model_card.json")
esquema = cargar("schemas/causal-model-card-v2.schema.json")
datos_ref = Path("data/referencia_ci.parquet")

errores = []
# (i) esquema
for e in Draft202012Validator(esquema, format_checker=FormatChecker()).iter_errors(card):
    ruta = "/".join(map(str, e.absolute_path)) or "(raiz)"
    errores.append(f"{ruta}: {e.message}")
# (ii) supuestos observables: el veredicto sale del valor y el umbral, y ninguno fallo
OPS = {"<": lambda a, b: a < b, "<=": lambda a, b: a <= b,
       ">": lambda a, b: a > b, ">=": lambda a, b: a >= b}
for sup in card.get("supuestos", []):
    u, v = sup.get("umbral"), sup.get("ultima_verificacion")
    if sup.get("clase") != "observable" or not (u and v):
        continue                      # los no observables y los incompletos ya los cubre el esquema
    if v["paso"] != OPS[u["operador"]](v["valor"], u["valor"]):
        errores.append(f"supuesto {sup['nombre']!r}: el veredicto no sale del valor y el umbral")
    elif not v["paso"]:
        errores.append(f"supuesto {sup['nombre']!r} no supera su umbral")
# (iii) huella de los datos de referencia
huella = "sha256:" + hashlib.sha256(datos_ref.read_bytes()).hexdigest()
if card.get("version", {}).get("hash_datos_entrenamiento") != huella:
    errores.append("huella distinta de la de los datos de referencia")

if errores:
    sys.exit("model_card.json no valido:\n  " + "\n  ".join(errores))
print("model_card.json valido")
```
) <lst-validar-schema>

Las dos pruebas estadísticas leen los roles de la ficha, y no una lista de columnas escrita en el código, para que no puedan divergir de lo que el servicio usa. La del placebo repite la permutación y tolera un número de rechazos calculado con la tasa medida del modelo sano:

#figure(
  kind: raw,
  caption: [Prueba estadística de humo: reestimar con el tratamiento permutado no debe dar un efecto significativo.],
  ```python
# tests/test_placebo.py
import copy, json
import joblib
import numpy as np
import pandas as pd

REPETICIONES = 20   # permutaciones del tratamiento
MAX_RECHAZOS = 5    # P(mas de 5 de 20) = 0.018 si p0 = 0.11

def test_placebo_no_significativo():
    with open("model/model_card.json", encoding="utf-8") as f:
        r = json.load(f)["roles"]
    modelo = joblib.load("model/dml_estimator.joblib")
    df = pd.read_parquet("data/referencia_ci.parquet")  # fija
    X, Y = df[r["covariables"]], df[r["resultado"]].to_numpy()
    D = df[r["tratamiento"]].to_numpy()
    rng = np.random.default_rng(0)
    rechazos = 0
    for _ in range(REPETICIONES):
        est = copy.deepcopy(modelo)          # sin estado compartido
        est.fit(Y, rng.permutation(D), X=X)  # rompe el vinculo con Y
        lb, ub = est.ate_interval(X=X, alpha=0.05)
        rechazos += not (lb <= 0 <= ub)
    assert rechazos <= MAX_RECHAZOS, (
        f"Placebo significativo en {rechazos} de {REPETICIONES} "
        "permutaciones. Revisar antes de registrar."
    )
```
) <lst-test-placebo>

La de estabilidad reestima el efecto con los datos y el código del candidato y lo compara con el que la ficha registró, en unidades del error estándar que la ficha declara. Exige que el estimador tenga las semillas fijadas, porque de lo contrario el desplazamiento no sería cero ni siquiera sin cambios:

#figure(
  kind: raw,
  caption: [Prueba de estabilidad: el efecto reestimado no se aleja del registrado más de la tolerancia, en errores estándar.],
  ```python
# tests/test_efecto_estable.py
import copy, json
import joblib
import pandas as pd

TOLERANCIA_EE = 1.0   # en errores estandar; fijar antes de correr

def test_efecto_estable():
    with open("model/model_card.json", encoding="utf-8") as f:
        ficha = json.load(f)
    r, m = ficha["roles"], ficha["metricas"]
    df = pd.read_parquet("data/referencia_ci.parquet")
    X = df[r["covariables"]]
    est = copy.deepcopy(joblib.load("model/dml_estimator.joblib"))
    est.fit(df[r["resultado"]].to_numpy(),
            df[r["tratamiento"]].to_numpy(), X=X)
    ee = (m["ic95"][1] - m["ic95"][0]) / (2 * 1.96)  # EE del IC
    desplazamiento = abs(float(est.ate(X=X)) - m["efecto"]) / ee
    assert desplazamiento <= TOLERANCIA_EE, (
        f"El efecto se aleja {desplazamiento:.1f} errores estandar "
        f"del registrado (tolerancia {TOLERANCIA_EE}). "
        "Decide una persona si el cambio es legitimo."
    )
```
) <lst-test-estable>
]

== #t-aplicacion
<sec-cicd-aplicacion>

El registro local del artefacto solo ocurre si la etapa estadística pasó. Es decir, el artefacto del Capítulo 19 queda condicionado a que el placebo, la estabilidad del efecto y el balance sigan siendo razonables, no solo a que el código compile. Esta es, en términos concretos, la implementación de la *confiabilidad* como requisito de sistema que el @cap-anatomia-sistema definió al inicio del libro: el sistema "sigue produciendo el comportamiento correcto" porque el pipeline se lo exige mecánicamente, no porque alguien se acuerde de verificarlo manualmente antes de cada registro.

La misma compuerta sirve al aprendizaje continuo. Un reentrenamiento programado produce un candidato como cualquier otro, y pasa por las mismas pruebas antes de sustituir a la versión vigente (@cap-aprendizaje-continuo). Lo que cambia es quién propone el candidato, no quién decide si se registra.

== Señales de alerta y checklist operativo
<sec-cicd-alertas>

#checklist[
  - El pipeline de CI/CD solo corre pruebas de software; ningún job verifica placebo, balance o cobertura de intervalos.
  - El dataset de referencia usado en las pruebas estadísticas no está versionado, por lo que las pruebas pueden dar resultados distintos en ejecuciones distintas sin que nadie lo note.
  - El registro del artefacto ocurre en el mismo paso que las pruebas de software, sin depender del resultado de las pruebas estadísticas.
  - Nadie revisa manualmente los resultados de las pruebas estadísticas cuando fallan; el pipeline solo las corre pero no las reporta de forma visible al equipo.
  - El pipeline tiene un placebo pero ninguna prueba que reestime el efecto, de modo que un control omitido pasaría sin que nada lo note.
  - La tolerancia del placebo se tomó de la tasa nominal del 5 % y no de la tasa medida sobre el modelo sano, o el umbral se modificó en el mismo cambio que lo hizo fallar.
]

== Ejercicios y notas bibliográficas
<sec-cicd-ejercicios>

=== Ejercicios conceptuales
<sec-cicd-ejercicios-conceptuales>

+ Explique por qué separar las pruebas de software (rápidas, en cada _push_) de las pruebas estadísticas (lentas, solo antes de publicar) es un mejor diseño que correr ambas en cada _commit_. ¿Qué se pierde con esta separación?

+ Proponga una tercera prueba estadística, además del placebo y el balance, que tenga sentido incluir en el pipeline de CI para un estimador DML-IV (Capítulo 17). Justifique qué supuesto específico protege.

+ La tasa de rechazo del placebo del modelo sano, medida con 200 permutaciones, es 0,11. Con 20 permutaciones por corrida, calcule la tolerancia mínima que mantiene los falsos bloqueos por debajo del 2 %. ¿Qué tolerancia hace falta si la tasa medida sube a 0,15 al cambiar el conjunto de referencia, y qué se pierde en la detección?

+ En el caso canónico, quitar la confusora más débil desplaza el efecto entre 1,5 y 2,3 errores estándar. Explique por qué una tolerancia de tres errores estándar no la detecta y qué se pierde al bajarla a uno. ¿De qué debería depender la elección?

#capa-impl[
=== Ejercicio de infraestructura#solo-curso[ (cierra el Notebook B2)]
<sec-cicd-ejercicios-infra>

#if es-curso [
+ Complete el Notebook de producción B2: ejecute los comandos locales del #ref(<lst-cicd-local>, supplement: [listado]) y las pruebas de los listados #ref(<lst-test-placebo>, supplement: none) y #ref(<lst-test-estable>, supplement: none) adaptadas a su modelo. Verifique que quitar una covariable de control clave hace fallar la prueba de estabilidad y que el placebo, en cambio, sigue pasando. Mida la tasa de rechazo del placebo de su modelo sano con 200 permutaciones, fije con ella el número de permutaciones y la tolerancia, y registre los tres valores en el campo `validacion` de la ficha. Explique por qué, y documente el resultado.
] else [
+ Ejecute los comandos locales del #ref(<lst-cicd-local>, supplement: [listado]) y las pruebas de los listados #ref(<lst-test-placebo>, supplement: none) y #ref(<lst-test-estable>, supplement: none) sobre un estimador causal propio (por ejemplo, el modelo registrado localmente en el Capítulo 19). Verifique que quitar una covariable de control clave hace fallar la prueba de estabilidad y que el placebo, en cambio, sigue pasando. Mida la tasa de rechazo del placebo de su modelo sano con 200 permutaciones, fije con ella el número de permutaciones y la tolerancia, y registre los tres valores en el campo `validacion` de la ficha. Explique por qué, y documente el resultado.
]
]

=== Notas bibliográficas
<sec-cicd-notas>

La práctica general de CI/CD para sistemas de ML se documenta en @huyen2022dmls y @kastner2024mlip, ya citados en capítulos anteriores; #cite(<breck2017mltestscore>, form: "prose") (citado en el @cap-anatomia-sistema) incluye explícitamente pruebas de "reproducibilidad del pipeline de entrenamiento" en su rúbrica, que este capítulo extiende con pruebas específicas de validez causal.
