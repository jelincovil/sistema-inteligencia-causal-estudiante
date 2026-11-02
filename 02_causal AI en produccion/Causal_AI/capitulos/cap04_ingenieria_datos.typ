// Capítulo 4: Ingeniería de datos para sistemas causales.
// Edición en capas: el contrato C-01 y el caso canónico (capas L2 y L0) son lo que dura; el listado (capa L3) va dentro de
// #capa-impl. Lo que es solo del curso va en #solo-curso o en #if es-curso.
#import "../template/template.typ": *

#chapter[Ingeniería de datos para sistemas causales]
<cap-ingenieria-datos-causales>

#theorem-number-reset()

#cuadrodecision[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Decisión:*], [Declarar los roles causales de cada columna en un esquema único que viaja con los datos, y no repetirlos en cada análisis],
    [*Alternativas:*], [Tabla ancha sin metadatos vs. esquema con roles etiquetados (tratamiento, resultado, covariable, instrumento)],
    [*Trade-off clave:*], [Velocidad de prototipado vs. prevención sistemática de errores de identificación],
    [*Contrato:*], [C-01, esquema de roles causales (@sec-datoscausales-contrato)],
    ..if not es-principios {([*Stack:*], [pandas])},
    [*Riesgo principal:*], [Que dos análisis definan $X$ de forma distinta, o que una variable posterior al tratamiento entre como covariable sin que nada lo señale],
  )
]

#if es-curso [
#monorepo[
  En el monorepo del curso (2026) los datos de práctica viven en #code[data_benchmark_causal/.../datasets/] como *CSV* + #code[metadata.json] (no Parquet obligatorio). Los roles de variables se resuelven con #code[lib.data_io.load_scenario] y el puente #code[lib.schema.CausalSchema.from_scenario("real/jobs")], que construye el esquema de este capítulo a partir de los metadatos del escenario. Labs: #code[L04]–#code[L06]. Entrega: *Notebook A1* (Jobs). Stack: #code[03_notebooks_caso_estudio/lib/].
]

]
#if es-comercial [#nota-repo-comercial()]
== El problema de diseño
<sec-datoscausales-problema>

La ingeniería de datos genérica, la que enseña #cite(<huyen2022dmls>, form: "prose") en su Capítulo 3, se pregunta qué formato de almacenamiento usar, qué modelo de datos es apropiado (relacional, documento, grafo) y cómo pasar datos entre procesos. Todas esas preguntas siguen vigentes en un sistema causal, pero hay una más, específica, que un pipeline puramente predictivo nunca tiene que responder: *¿qué rol estructural juega cada columna del conjunto de datos?* En predicción, las columnas de entrada son en principio intercambiables, porque el modelo usa todas las que ayuden a reducir el error. En un problema causal no lo son. Una es el *tratamiento* $D$, otra es el *resultado* $Y$, algunas son *covariables* $X$ que pueden controlarse legítimamente y, lo más delicado, algunas que *parecen* covariables razonables son variables posteriores al tratamiento: están en la ruta causal entre $D$ e $Y$, o son efecto común de ambos, y controlarlas sesga la estimación. El @cap-intervencion-contrafactual desarrolla esta distinción con el nombre de "buenos y malos controles".

Si el pipeline no distingue esos roles desde el origen, si todo llega como una tabla ancha sin metadatos, la tarea de no confundirlos recae en la memoria de quien escribe cada análisis. Eso falla de forma predecible a medida que el sistema crece y más personas lo tocan.

== Opciones y trade-offs
<sec-datoscausales-opciones>

#opciones[
  - *Tabla ancha sin metadatos.* Cada análisis decide, con nombres de columna escritos en su propio código, cuál es $D$, cuál es $Y$ y cuáles son $X$. Es la opción más rápida para un estudio único y exploratorio, y la que domina en la práctica académica. Su costo aparece cuando el mismo conjunto de datos se reutiliza en varios análisis o cuando el sistema en producción tiene que reconstruir las mismas columnas: nada impide que dos análisis definan $X$ de forma sutilmente distinta, uno con una variable posterior al tratamiento y otro sin ella, y produzcan estimaciones no comparables sin que nadie lo note. El caso canónico de más abajo muestra cuánto pueden diferir.
  - *Esquema con roles etiquetados.* Se declara en un único lugar qué columna es el tratamiento, cuál el resultado, cuáles son covariables que pueden controlarse y cuáles instrumentos, si los hay. Todo análisis y todo servicio consume ese esquema en lugar de escribir nombres de columna. El costo es la fricción inicial de definirlo antes de poder "simplemente correr una regresión".
]

== #t-decision
<sec-datoscausales-decision>

El libro adopta un *esquema de roles causales* explícito para todo conjunto de datos que alimente una estimación. El esquema mínimo declara cuatro cosas: el tratamiento, el resultado, las covariables y, cuando aplica, los instrumentos. Ninguna función de estimación del sistema acepta una tabla sola. Todas reciben la tabla junto con su esquema, de modo que sea imposible, por ejemplo, pasar el tratamiento como covariable por accidente.

Lo que la decisión fija es que *el esquema exista y sea la única fuente de verdad sobre los roles*, no el formato en que se guarda. Conviene que viaje con los datos, como metadato del propio archivo o como un archivo vecino versionado junto a ellos, porque el riesgo que se previene no es de eficiencia de lectura sino de *deriva semántica*: que dos partes del sistema discrepen sobre qué columna es el tratamiento o cuáles son las covariables. Ese riesgo se cierra con la unicidad del esquema, no con el formato.

Conviene también ser explícito sobre lo que el esquema declara. Etiquetar una columna como covariable no es una afirmación sobre su tipo de dato ni sobre su utilidad predictiva. Es una afirmación *causal*: que esa variable puede controlarse legítimamente, es decir, que pertenece a un conjunto que satisface el criterio de puerta trasera (@cap-intervencion-contrafactual). Por eso el esquema es un artefacto de identificación además de uno de ingeniería, y por eso el @cap-features-sin-fuga le añade una auditoría explícita en vez de dar por buena la lista de covariables. El esquema puede comprobar que los roles no se contradicen y que las columnas existen. No puede comprobar que lo declarado sea cierto.

== El contrato del esquema de roles
<sec-datoscausales-contrato>

Este es el primero de los contratos numerados del libro. Cada contrato describe una pieza de ingeniería sin atarla a una tecnología: qué operaciones ofrece, qué recibe, qué devuelve, qué debe cumplirse siempre, cómo falla y cómo se comprueba. Cualquier implementación lo cumple si pasa su prueba de aceptación.

#contrato(
  "C-01",
  "Esquema de roles causales",
  operaciones: [
    _declarar_: construye el esquema a partir de los nombres del tratamiento, el resultado, las covariables y los instrumentos. _validar_: comprueba el esquema contra una tabla de datos. _proyectar_: devuelve de la tabla la matriz de covariables, el tratamiento y el resultado, en el orden declarado. _escribir_ y _leer_: pasan el esquema a un texto legible por personas y por máquinas, y de vuelta.
  ],
  entrada: [
    Los nombres de las columnas de cada rol (un tratamiento, un resultado, al menos una covariable, cero o más instrumentos) y la tabla de datos a la que el esquema se aplica.
  ],
  salida: [
    La matriz de covariables, el tratamiento y el resultado. El texto del esquema, con los mismos campos que el apartado de roles de la ficha del modelo (contrato C-05 del @cap-model-card-causal).
  ],
  invariantes: [
    (1) Cada columna tiene un solo rol: ninguna aparece dos veces en el esquema. (2) Hay al menos una covariable. (3) Una tabla solo valida si contiene todas las columnas declaradas y si el tratamiento toma al menos dos valores distintos. (4) El orden de las covariables es parte del esquema y las proyecciones lo respetan. (5) Escribir y volver a leer devuelve un esquema igual al original. (6) El esquema no se modifica una vez creado: cambiar los roles produce otro esquema y deja intacto el que ya usan otras piezas. (7) Declarar una covariable es una afirmación causal que este contrato no verifica; la verifica la auditoría del C-03 (@cap-features-sin-fuga).
  ],
  fallos: [
    Una columna declarada que ya no está en los datos, porque cambió de nombre en el origen. El tratamiento o el resultado repetidos entre las covariables, o un instrumento incluido entre ellas. Un tratamiento constante en la muestra recibida, porque un filtro dejó una sola rama. Un esquema que se desincroniza de los datos porque viaja por separado. Una covariable posterior al tratamiento que pasa todas las comprobaciones, porque el contrato solo ve nombres.
  ],
  aceptacion: [
    (a) Cada fallo estructural de la lista se provoca a propósito y la operación correspondiente lo rechaza con un mensaje que nombra la columna. (b) Escribir y leer devuelve un esquema igual, y el texto escrito valida contra el apartado de roles del esquema de la ficha del modelo. (c) Dos análisis que consumen el mismo esquema reciben la misma matriz de covariables y obtienen la misma estimación sobre el caso canónico de más abajo. (d) Una covariable posterior al tratamiento pasa la validación; el contrato no pretende detectarla y la prueba lo deja a la vista.
  ],
)

#caso-canonico("Dos análisis, dos definiciones de X")[
  Un conjunto de datos laborales estilizado, con efecto conocido. La educación de los padres $P$ y la edad $E$ son normales estándar independientes. La escolaridad depende de los padres, $D = 0.5 P + epsilon_D$, y el salario es $Y = D + 0.8 P + 0.5 E + epsilon_Y$, de modo que el efecto de un año más de escolaridad vale exactamente 1. La tabla incluye además una columna de experiencia potencial, $S = E - D$, construida a partir de la edad y de la escolaridad. Es una práctica habitual en datos laborales: en el conjunto de datos de #cite(<card1995>, form: "prose"), tal como se distribuye públicamente, la experiencia se calcula como edad menos escolaridad menos seis.

  Dos análisis leen la misma tabla. El primero controla por $\{P, E\}$ y el segundo por $\{P, S\}$. Los nombres de ambos conjuntos existen en los datos, ninguno repite el tratamiento y los dos pasan cualquier validación estructural. Con 5 000 unidades y 200 repeticiones, el primero estima 1,00 y el segundo 1,50, con una desviación entre repeticiones de alrededor de 0,02 en los dos.

  La diferencia de 0,50 no es ruido. Como $S$ contiene a $D$, controlarla abre el camino $D -> S <- E -> Y$, y el coeficiente de $D$ absorbe el efecto de la edad: sustituyendo $E = S + D$ en el salario queda $Y = 1.5 D + 0.8 P + 0.5 S + epsilon_Y$. Con un esquema único no hay dos definiciones de $X$ que comparar, y la discusión sobre si $S$ pertenece a ella ocurre en un solo lugar y queda registrada. Lo que el esquema no decide es cuál de las dos definiciones es la correcta: eso lo hace la auditoría del @cap-features-sin-fuga, que deja $S$ fuera porque se calcula con el tratamiento.
]

Cada decisión del contrato responde a un fallo concreto.

*Un solo rol por columna.* Un instrumento incluido también como covariable es un error distinto al de repetir el tratamiento, pero igual de silencioso: el estimador corre y devuelve un número. Con la regla de que una columna ocupa un solo lugar, el esquema rechaza la contradicción antes de que haya un número que mirar.

*Validar contra los datos, no solo contra sí mismo.* Un esquema consistente consigo mismo puede describir una tabla que ya no existe. La comprobación contra la tabla recibida atrapa el cambio de nombre en el origen y el filtro que dejó sin variación al tratamiento, que de otro modo aparecen como una estimación con error estándar enorme o como un fallo lejano en el código del estimador.

*Viajar con los datos.* Un esquema que vive en la cabeza de alguien, o en un cuaderno de trabajo, se desincroniza. Escribirlo en un texto con los mismos campos que la ficha del modelo permite que el esquema con que se entrenó sea, sin traducción, el que registra la ficha y el que el servicio exige a cada consulta.

*Declarar no es verificar.* El contrato rechaza lo que puede decidir con nombres y tablas, y deja explícito lo que no puede. Una variable posterior al tratamiento pasa todas sus comprobaciones. Si el contrato pareciera garantizar lo contrario, un equipo daría por revisada la identificación cuando solo revisó la ortografía de las columnas.

#capa-impl[
== Implementación de referencia
<sec-datoscausales-implementacion>

El primer listado implementa el contrato C-01 con una clase de datos inmutable. La construcción rechaza las columnas con dos roles, la validación comprueba el esquema contra una tabla, y la escritura y la lectura usan los mismos campos que el apartado de roles de la ficha del modelo (Ap. G).

#entero[
#figure(
  kind: raw,
  caption: [Esquema de roles causales como estructura de datos explícita (contrato C-01).],
  ```python
import json
from dataclasses import dataclass
import pandas as pd


@dataclass(frozen=True)
class CausalSchema:
    treatment: str
    outcome: str
    covariates: tuple
    instruments: tuple = ()

    def __post_init__(self):
        object.__setattr__(self, "covariates", tuple(self.covariates))
        object.__setattr__(self, "instruments", tuple(self.instruments))
        if not self.covariates:
            raise ValueError("Se necesita al menos una covariable")
        cols = self.columns()
        dobles = sorted({c for c in cols if cols.count(c) > 1})
        if dobles:
            raise ValueError(f"Columnas con dos roles: {dobles}")

    def columns(self) -> list:
        return [self.treatment, self.outcome, *self.covariates, *self.instruments]

    def validate(self, df: pd.DataFrame) -> None:
        ausentes = sorted(set(self.columns()) - set(df.columns))
        if ausentes:
            raise ValueError(f"Columnas ausentes en los datos: {ausentes}")
        if df[self.treatment].nunique() < 2:
            raise ValueError("El tratamiento no varía en estos datos")

    def X(self, df): return df[list(self.covariates)]
    def D(self, df): return df[self.treatment]
    def Y(self, df): return df[self.outcome]

    def to_json(self) -> str:
        return json.dumps({"tratamiento": self.treatment, "resultado": self.outcome,
                           "covariables": list(self.covariates),
                           "instrumentos": list(self.instruments)}, ensure_ascii=False)

    @classmethod
    def from_json(cls, texto: str):
        r = json.loads(texto)
        return cls(r["tratamiento"], r["resultado"], r["covariables"], r.get("instrumentos", []))
```
) <lst-causal-schema>
]

El esquema es un objeto que no cambia tras crearse: quien necesite otra lista de covariables construye otro esquema, y el anterior sigue siendo el que describe a los modelos ya entrenados con él. La clase no intenta detectar variables posteriores al tratamiento, y lo declara en el contrato. Ese trabajo es de la auditoría del @cap-features-sin-fuga. El segundo listado la usa sobre datos sintéticos.

#entero[
#figure(
  kind: raw,
  caption: [Uso del esquema sobre datos sintéticos: validar, escribir y volver a leer.],
  ```python
import numpy as np

# Los nombres de columna recuerdan a un estudio de retornos a la educación.
g = np.random.default_rng(4)
datos = pd.DataFrame({"padres_educ": g.normal(size=200), "edad": g.normal(size=200),
                      "cerca_universidad": g.integers(0, 2, size=200)})
datos["educ"] = 0.5 * datos["padres_educ"] + g.normal(size=200)
datos["salario"] = datos["educ"] + 0.8 * datos["padres_educ"] + 0.5 * datos["edad"] + g.normal(size=200)

esquema = CausalSchema(treatment="educ", outcome="salario",
                       covariates=("padres_educ", "edad"), instruments=("cerca_universidad",))
esquema.validate(datos)   # lanza ValueError si falta una columna o si el tratamiento no varía
assert CausalSchema.from_json(esquema.to_json()) == esquema
print(esquema.to_json())
```
) <lst-causal-schema-ejemplo>
]

*Formato de almacenamiento.* Un segundo trade-off, heredado de #cite(<huyen2022dmls>, form: "prose"), es el del formato en que se guardan los datos. Los formatos orientados a fila (CSV, JSON) son más simples de inspeccionar a mano, pero más lentos cuando solo se necesita un subconjunto de columnas, que es justo lo que un pipeline de estimación causal hace una y otra vez: leer $Y$, $D$ y una parte de $X$ sin cargar el resto. Los formatos orientados a columna (Parquet) son más eficientes para ese patrón y permiten adjuntar el esquema como metadato dentro del propio archivo. Un CSV acompañado de un archivo de esquema versionado a su lado cumple el mismo contrato#solo-curso[, y es la forma que adopta el benchmark del curso (véase el recuadro de implementación al comienzo del capítulo)].
]

== #t-aplicacion
<sec-datoscausales-aplicacion>

El esquema se declara antes de correr ninguna estimación. Eso obliga a que la pregunta de identificación (@cap-causalidad-elemental, @cap-scm-pch) se convierta en un paso de ingeniería concreto y comprobable, en vez de quedar implícita en la cabeza de quien analiza los datos. Después el mismo esquema reaparece, sin cambios, a lo largo de todo el sistema: la ficha de procedencia del @cap-datos-entrenamiento-causales lo extiende con el mecanismo de asignación, la auditoría del @cap-features-sin-fuga lo contrasta con el tiempo y el grafo, la ficha del modelo lo registra como su apartado de roles (@cap-model-card-causal) y el servicio lo usa para saber qué columnas debe traer cada consulta (@cap-despliegue-servicio). Así se cierra el círculo entre el entrenamiento y el servicio desplegado.#solo-curso[ El Notebook de caso de estudio A1 (Módulo 1 del curso) exige construirlo para el conjunto de datos elegido antes de estimar nada, y el Notebook de producción B1 (Capítulo 15) lo reutiliza sin cambios.]

== Señales de alerta y checklist operativo
<sec-datoscausales-alertas>

#checklist[
  - El nombre de la columna de tratamiento está escrito a mano en más de un análisis o servicio, con riesgo de que diverja.
  - Ninguna función de carga de datos valida que el tratamiento, el resultado y los instrumentos no figuren también entre las covariables.
  - No hay forma de saber, sin leer el código que genera las variables, si alguna covariable fue medida o calculada *después* del tratamiento.
  - El esquema de roles no viaja junto con los datos y puede desincronizarse sin que nadie lo note.
  - Dos análisis del mismo conjunto de datos reportan efectos distintos y nadie ha comparado sus listas de covariables.
  - El formato de almacenamiento obliga a cargar todas las columnas para leer solo tres, y esa carga se repite en cada corrida.
]

== Ejercicios y notas bibliográficas
<sec-datoscausales-ejercicios>

=== Ejercicios conceptuales
<sec-datoscausales-ejercicios-conceptuales>

+ Para el conjunto de datos de becas del @cap-causalidad-elemental, proponga tres covariables legítimas para $X$ y una variable que, aunque esté correlacionada con el resultado, sería incorrecto incluir en $X$ por ser posterior al tratamiento. Justifique.

+ Explique por qué un esquema de roles causales explícito importa más en un sistema con varios análisis y varios colaboradores que en un estudio individual de una sola vez.

+ En el caso canónico, suponga que la edad deja de afectar al salario (el coeficiente 0,5 pasa a 0). Dibuje el grafo, diga qué estima el segundo análisis y explique por qué el sesgo desaparece. ¿Qué dos arcos hacen falta para que controlar $S$ sesgue?

#capa-impl[
=== Ejercicio de infraestructura
<sec-datoscausales-ejercicios-infra>

+ Extienda la clase `CausalSchema` del #ref(<lst-causal-schema>, supplement: [listado]) con un método `summary()` que imprima, para cada rol, el número de valores faltantes y el tipo de dato de las columnas correspondientes. Aplíquelo al conjunto de datos que elija#solo-curso[ para el Notebook A1].
]

=== Notas bibliográficas
<sec-datoscausales-notas>

#cite(<huyen2022dmls>, form: "prose"), Capítulo 3, desarrolla en profundidad los formatos y modelos de datos genéricos que este capítulo adapta al caso causal. La distinción entre controles legítimos y variables posteriores al tratamiento se formaliza en el @cap-intervencion-contrafactual con el lenguaje de grafos causales; véase también la discusión de "buenos y malos controles" en @bareinboim2025causalai. #cite(<sculley2015hiddendebt>, form: "prose") documentan cómo las dependencias de datos y la configuración sin declarar acumulan deuda técnica en los sistemas de aprendizaje automático, que es el costo de dejar los roles de las variables repartidos en el código de cada análisis. El conjunto de datos de #cite(<card1995>, form: "prose") sobre retornos a la educación se usa como ejemplo en los capítulos de estimación.
