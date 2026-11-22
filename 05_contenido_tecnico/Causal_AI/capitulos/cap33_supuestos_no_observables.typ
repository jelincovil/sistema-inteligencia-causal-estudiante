// Capítulo 33: Supuestos no observables en operación.
// Plantilla B. Contrato C-08 (capa L2); implementación de referencia en #capa-impl (capa L3).
// Completa el Cap. 30: el monitoreo vigila lo observable, y este capítulo dice qué hace un sistema con lo que no lo es.
#import "../template/template.typ": *

#chapter[Supuestos no observables en operación]
<cap-supuestos-no-observables>

#theorem-number-reset()

#cuadrodecision[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Decisión:*], [Registrar, para cada supuesto que ningún dato verifica, cuánto tendría que fallar para cambiar la decisión, y revisarlo por plazo y por eventos],
    [*Alternativas:*], [Dejarlo como una frase de fe en la ficha vs. registrar su sensibilidad respecto de la decisión, una escala de referencia, un control negativo cuando exista y un plazo de revisión],
    [*Trade-off clave:*], [Un cálculo al registrar y una revisión periódica vs. una decisión que descansa en un supuesto que nadie vuelve a mirar],
    ..if not es-principios {([*Stack:*], [Python y numpy (mínimos cuadrados), esquema JSON de la ficha])},
    [*Riesgo principal:*], [Leer un valor de robustez alto como prueba de que el supuesto vale],
  )
]

#if es-curso [
#monorepo[
  El capítulo no tiene laboratorio propio: es lectura de cierre de la Parte VIII y se ejercita en el proyecto final, en el apartado de sensibilidad (Apéndice #ref(<ap-proyecto-rubrica>, supplement: none)). Verificación de las cifras: #code[herramientas/verificaciones/verif_cap33.py].
]

]
#if es-comercial [#nota-repo-comercial()]
== El problema de diseño
<sec-snoobs-problema>

El monitoreo del @cap-monitoreo-causal vigila cuatro cosas, y las cuatro se pueden mirar en los datos: cuánto cambiaron las covariables, si el mecanismo de asignación sigue ordenando como antes, si el instrumento conserva su fuerza y si el efecto reestimado se movió. Todo lo que ese capítulo detecta es observable. El supuesto que más pesa en un estimador observacional no lo es. La no confusión condicional no puede verificarse solo con los datos observacionales disponibles; algunas consecuencias pueden contrastarse mediante controles negativos, placebos o una referencia experimental bajo supuestos adicionales. El sistema puede estar quieto en las cuatro señales y estar sesgado, y también puede encender una señal sin haber identificado la causa.

El problema de diseño es qué puede hacer un sistema con un supuesto que no puede verificar. No puede verificarlo, y fingir lo contrario es el peor camino. Puede hacer cuatro cosas más modestas, y las cuatro caben en una ficha: decir cuánto tendría que fallar el supuesto para que la decisión cambie, buscar el rastro indirecto que su falla dejaría en algún otro resultado, declarar hasta cuándo vale lo que dijo y qué hechos obligan a revisarlo, y dejar escrito quién decide cuando eso ocurre. El capítulo trata esas cuatro cosas para la no confusión condicional, el supuesto que el libro ha seguido de punta a punta. Los otros supuestos no observables, la exclusión de un instrumento y las tendencias paralelas posteriores al tratamiento, usan el mismo registro, con su propio método de sensibilidad; este capítulo no los desarrolla.

#figure(
  caption: [Clase de cada supuesto y lo que el sistema hace con él.],
  table(
    columns: (1.6fr, 1fr, 2.4fr),
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Supuesto*], [*Clase*], [*Qué hace el sistema*]),
    table.hline(stroke: 0.4pt),
    [Soporte común], [Observable], [Lo vigila con un umbral calibrado (@cap-monitoreo-causal, @cap-datos-entrenamiento-causales)],
    [Estabilidad del mecanismo de asignación], [Observable], [Lo vigila con el modelo de la referencia (señal (ii))],
    [Fuerza del instrumento], [Observable], [Lo vigila con el $F$ de la primera etapa (señal (iii))],
    [Estabilidad del efecto], [Observable], [Lo vigila con un contraste de dos estimaciones (señal (iv))],
    [No confusión condicional], [No observable], [Registra su sensibilidad y su escala, vigila un control negativo y fija una revisión (este capítulo)],
    [Exclusión del instrumento, tendencias paralelas posteriores], [No observable], [Mismo registro, con su propio método de sensibilidad (fuera del alcance de los listados de este libro)],
    table.hline(stroke: 0.8pt),
  )
) <tab-snoobs-clases>

== Opciones y trade-offs
<sec-snoobs-opciones>

#opciones[
  - *El supuesto como frase de fe.* La ficha dice "se asume no confusión condicional en estas covariables" y nada más. Cuesta una línea. Su defecto es que no cambia ninguna decisión: nadie sabe si el supuesto aguanta un confusor pequeño o uno enorme, y la frase sigue idéntica el día que el mundo cambia.
  - *Sensibilidad registrada.* La ficha guarda un valor crítico respecto de la decisión, la escala con que se lo compara, un control negativo si existe y una fecha de revisión. Cuesta un cálculo al registrar y una revisión periódica. Lo que entrega es un margen declarado, que otra persona puede discutir y que el sistema puede recalcular.
  - *Rediseñar para identificar.* Un experimento, un instrumento defendible o un diseño cuasi-experimental convierten el supuesto en otro, a veces más débil, a veces observable en parte. Es la respuesta de fondo y también la más cara. No la decide el sistema: es lo que se escala cuando el margen resulta estrecho y lo que está en juego es grande.
]

== #t-decision
<sec-snoobs-decision>

El sistema de referencia registra, para cada supuesto no observable de la ficha, el método de sensibilidad compatible, el valor crítico respecto de la *decisión* y no solo de cero, la escala de referencia con que se interpreta, y la fecha de cálculo con su plazo de revisión. Si no existe una cuantificación válida para ese supuesto y estimando, registra `sin_cuantificacion_valida`, explica la limitación y conserva la revisión humana. Cuando existe un resultado que sirva de control negativo, lo vigila como una señal más del monitoreo. La revisión se dispara por plazo y por eventos, y la hace siempre una persona.

*Sobre el valor crítico: respecto de la decisión, no de cero.* La pregunta de la literatura de sensibilidad es cuánta confusión haría falta para anular el efecto, y el @cap-validacion la desarrolla con el _E-value_ y con el $R^2$ parcial. Una decisión rara vez se juega en cero. Se trata cuando el efecto supera un costo, y lo que importa es cuánta confusión lleva el efecto hasta el costo. Sea $hat(tau)$ el efecto estimado, $hat("se")$ su error estándar, "gl" los grados de libertad y $c$ el umbral de la decisión. Se define $f_c = |hat(tau) - c| \/ (hat("se") sqrt("gl"))$ y el *valor crítico de la decisión*
$
"VC"_c = 1/2 (sqrt(f_c^4 + 4 f_c^2) - f_c^2).
$
Es la fracción de la varianza residual del tratamiento y del resultado que un confusor tendría que explicar, en ambos a la vez y en la dirección adversa, para desplazar la estimación puntual hasta $c$. Con $c = 0$ es el valor de robustez habitual. No es un intervalo de confianza y no incorpora por sí solo la incertidumbre muestral. La fórmula es la de #cite(<cinellihazlett2020>, form: "prose") en un modelo lineal, aplicada a un umbral que no es cero.

#notatecnica[
  *Cota del sesgo por omisión.* En una regresión lineal de $Y$ sobre $D$ y $X$, si se omite un confusor $U$, el sesgo del coeficiente de $D$ cumple
  $
  |"sesgo"| = hat("se") sqrt("gl") sqrt( (r_(Y dot.op U | X, D)^2 thin r_(D dot.op U | X)^2) / (1 - r_(D dot.op U | X)^2) ),
  $
  donde $r_(Y dot.op U | X, D)^2$ y $r_(D dot.op U | X)^2$ son los $R^2$ parciales de $U$ con $Y$ y con $D$. Es una identidad algebraica: si se conocieran las dos cantidades, el sesgo se conocería. No se conocen, y por eso se las reemplaza por una escala de referencia. Para estimadores con aprendizaje automático, #cite(<chernozhukov2022long>, form: "prose") extienden la idea con otras cantidades; la ficha registra qué método se usó.
]

*Sobre el alcance del método.* La fórmula anterior y el listado de este capítulo corresponden a una regresión lineal con sensibilidad por confusión omitida. No es válido insertar sin más una estimación DML y su error estándar en esa fórmula. Un estimador con aprendizaje automático requiere un análisis derivado para su funcional y sus _nuisance_, o una reducción lineal justificada. La exclusión instrumental, la ausencia de interferencia y otros supuestos no observables tampoco se transforman automáticamente en $R^2$ de confusión omitida. Cuando no haya un método compatible implementado, la ficha conserva el supuesto, declara la ausencia de cuantificación y fija una revisión humana.

*Sobre la escala: un número sin escala no se puede juzgar, y la escala es una opinión.* Un valor crítico de 0,13 no dice nada hasta que se lo compara con algo. La comparación habitual usa las covariables observadas: el $R^2$ parcial de la más fuerte con el tratamiento y con el resultado. Con esa escala se calcula el rango de efectos que daría un confusor tan fuerte como esa covariable, y la decisión se declara *frágil* si el umbral cae dentro del rango. La escala es una afirmación sobre el mundo, "ningún confusor oculto es más fuerte que esta covariable", y puede ser falsa. La ficha tiene que decir cuál usó, para que quien la lea pueda discutirla (caso 2).

*Sobre el valor de robustez: un valor alto no prueba la ausencia de confusión.* La confusión que infla el efecto estimado también infla su robustez aparente, porque el valor crítico crece con el tamaño del efecto estimado. En el caso 1 el valor de robustez pasa de 0,18 sin confusor a 0,53 con el más fuerte. Un colega que cite un valor alto como prueba de que no hay confusión está leyendo al revés una cantidad que no distingue un mundo con confusor de uno sin él. Un valor crítico bajo dice que la decisión es frágil. Uno alto no dice que sea sólida.

#caso-canonico("La cota exacta y el valor de robustez")[
  Se simulan $n = 2 thin 000$ unidades con dos covariables observadas $X_1, X_2$ y un confusor $U$ no observado, todos normales estándar. El tratamiento es $D = 0.6 X_1 + 0.3 X_2 + delta U + epsilon_D$ y el resultado es $Y = tau D + 0.5 X_1 + 0.5 X_2 + gamma U + epsilon_Y$, con $tau = 0.2$. Se estima el efecto sin $U$ (el estimador disponible) y con $U$ (el que solo existe en la simulación). Cuatro intensidades: sin confusor, débil, medio y fuerte.

  #table(
    columns: (1.1fr, 0.8fr, 0.8fr, 1fr, 0.9fr, 0.9fr, 0.9fr),
    align: (left, center, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Confusor*], [*$R^2$ con $D$*], [*$R^2$ con $Y$*], [*Efecto sin $U$*], [*Sesgo real*], [*Valor de robustez*], [*VC, $c = 0.3$*]),
    table.hline(stroke: 0.3pt),
    [Ninguno], [0,00], [0,00], [0,192], [0,000], [0,18], [0,105],
    [Débil], [0,04], [0,08], [0,252], [0,059], [0,22], [0,048],
    [Medio], [0,21], [0,23], [0,434], [0,241], [0,36], [0,127],
    [Fuerte], [0,46], [0,37], [0,689], [0,496], [0,53], [0,350],
    table.hline(stroke: 0.6pt),
  )

  La cota de la nota técnica, calculada con los $R^2$ verdaderos de $U$, coincide con el sesgo real hasta el error numérico (diferencias de $10^(-15)$). Pero esos $R^2$ solo se conocen en la simulación. Lo que sí se calcula con los datos que existen en la práctica son las dos últimas columnas, que dependen solo del efecto estimado, su error estándar y los grados de libertad. El valor de robustez crece con el sesgo: la confusión más fuerte da el valor más alto.
]

#caso-canonico("El margen de la decisión y su escala")[
  Mismo proceso, con un costo de actuar $c = 0.3$. El efecto verdadero ($0.2$) está por debajo del costo, de modo que la decisión correcta es no tratar. Se repite el ejercicio en 500 muestras por escenario. Para cada una se calcula el rango de efectos con un confusor tan fuerte como $X_1$ (la mejor covariable observada) y se marca la decisión como frágil si $c$ cae dentro del rango.

  #table(
    columns: (1.1fr, 1fr, 1fr, 1fr, 1.4fr, 1fr),
    align: (left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Confusor*], [*Efecto medio sin $U$*], [*Se trataría*], [*VC medio*], [*Rango con la escala de $X_1$*], [*Decisión frágil*]),
    table.hline(stroke: 0.3pt),
    [Ninguno], [0,200], [0 %], [0,095], [−0,04 a 0,44], [100 %],
    [Débil], [0,258], [4 %], [0,041], [0,04 a 0,48], [100 %],
    [Medio], [0,441], [100 %], [0,129], [0,30 a 0,59], [58 %],
    [Fuerte], [0,699], [100 %], [0,347], [0,64 a 0,76], [0 %],
    table.hline(stroke: 0.6pt),
  )

  Con el confusor medio el sistema trata en todas las muestras, y es un error. El margen declarado avisa en el 58 % de ellas. Con el confusor fuerte trata en todas, es un error, y el margen dice que la decisión es robusta: ningún confusor tan fuerte como $X_1$ la movería. Pero el confusor real tiene un $R^2$ parcial de 0,37 con el resultado y $X_1$ tiene 0,02. La escala era optimista. Y sin confusor alguno, el margen marca la decisión como frágil en el 100 % de las muestras: es una declaración sobre el margen, no un detector. Las cifras provienen de una simulación con semillas fijas.
]

*Sobre el control negativo: ve solo lo que comparte.* Si hay un resultado $N$ que el tratamiento no puede causar, pero que comparte con $Y$ una causa no observada, el efecto estimado de $D$ sobre $N$ debería ser cero. Si no lo es, hay evidencia de confusión por una causa que $N$ comparte con $D$, sujeta a la validez del propio control. Un control que no comparte el confusor no tiene potencia específica frente a él: puede no rechazar aunque exista sesgo y todavía puede rechazar por azar a su tasa nominal. Tampoco cuantifica el sesgo de $Y$.

#caso-canonico("Un control negativo ve lo que comparte")[
  Mismo proceso. El control negativo es $N = zeta U + epsilon_N$, que el tratamiento no causa. Se estima el efecto de $D$ sobre $N$, con las mismas covariables, y se rechaza la nulidad al 5 %. Se compara un control que comparte el confusor ($zeta = 1$) con uno que no ($zeta = 0$), en 500 muestras por escenario.

  #table(
    columns: (1.4fr, 2fr, 2fr),
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Confusor*], [*Control que comparte $U$*], [*Control que no lo comparte*]),
    table.hline(stroke: 0.3pt),
    [Ninguno], [5,6 %], [4,6 %],
    [Débil], [100 %], [4,2 %],
    [Medio], [100 %], [3,6 %],
    [Fuerte], [100 %], [4,2 %],
    table.hline(stroke: 0.6pt),
  )

  El control que comparte el confusor lo detecta en todas las muestras, incluso con el confusor débil. El que no lo comparte queda en la tasa nominal en todos los escenarios, también cuando el confusor es fuerte. Sin confusor, los dos rechazan alrededor del 5 %, que es la tasa de falsas alarmas.
]

*Sobre el plazo: la sensibilidad caduca.* El valor crítico es una propiedad de unos datos, un estimador y una población. Si cualquiera de los tres cambia, el número ya no describe lo que el sistema sirve. El registro lleva por eso una fecha de revisión, y la revisión se adelanta cuando ocurre alguno de estos hechos: cambió el mecanismo de asignación del tratamiento (la señal (ii) del @cap-monitoreo-causal), entró o salió una covariable, el sistema empezó a servir una población distinta (@cap-generalizacion-transportabilidad) o el control negativo se encendió. El plazo lo fija el equipo según cuánto cambia su mundo. La regla que sí es fija es que la revisión la hace una persona, que el resultado es renovar el cálculo, aceptar el margen con una nota o retirar el modelo, y que ningún proceso automático declara que un supuesto no observable "sigue valiendo".

== El contrato de la sensibilidad
<sec-snoobs-contrato>

El contrato completa a la ficha (C-05) y al monitoreo (C-07). La ficha dice dónde se guarda la sensibilidad, el monitoreo aporta los eventos que obligan a revisarla y este contrato fija cómo se calcula y cuándo se revisa.

#contrato(
  "C-08",
  "Sensibilidad de los supuestos no observables",
  operaciones: [
    _calcular_: recibe el estimando, el método de sensibilidad compatible, los insumos que ese método requiere, el umbral de la decisión y la escala de referencia, y devuelve el registro de sensibilidad o el estado `sin_cuantificacion_valida`. _revisar_: recibe la ficha, la fecha y los eventos del monitoreo, y devuelve los motivos por los que una persona debe revisar cada supuesto no observable, o una lista vacía.
  ],
  entrada: [
    El estimando, el procedimiento de estimación y el método de sensibilidad elegido. Para la implementación lineal de este capítulo: efecto, error estándar, grados de libertad, umbral de decisión y $R^2$ parciales de la escala de referencia. Si existe, el efecto estimado sobre un control negativo. Los eventos del monitoreo (@cap-monitoreo-causal) y la fecha.
  ],
  salida: [
    Por cada supuesto no observable, el registro de sensibilidad compatible o `sin_cuantificacion_valida` con su justificación. Cuando se cuantifica: método, objeto, umbral de la decisión, valor crítico, escala de referencia, fecha de cálculo y fecha de revisión. Y la lista de motivos de revisión. Nunca un veredicto de "verificado".
  ],
  invariantes: [
    (1) El método declara para qué estimando y modelo de sensibilidad es válido. (2) La sensibilidad se calcula con los datos y el estimador registrados, no se escribe a mano. (3) Se calcula respecto del umbral de la decisión, no solo respecto de cero. (4) El registro dice qué escala de referencia usó. (5) Un valor crítico alto nunca se informa como evidencia de que el supuesto vale. (6) Si no hay método compatible, se registra la limitación sin fabricar un número. (7) Todo evento y todo plazo vencido produce un motivo de revisión humana.
  ],
  fallos: [
    Un control negativo que no comparte el confusor: su silencio se lee como confirmación. Una escala de referencia optimista: la decisión se declara robusta frente a una perturbación mucho más débil que la plausible (caso 2). Una sensibilidad lineal aplicada mecánicamente a un estimador o supuesto incompatible. Una implementación que solo explora una parametrización simétrica y omite combinaciones plausibles de asociaciones.
  ],
  aceptacion: [
    Sobre el generador de los casos canónicos, con confusor de intensidad conocida. (a) Con los $R^2$ parciales verdaderos, la cota coincide con el sesgo real hasta el error numérico. (b) El valor crítico coincide con su forma cerrada y es idéntico para dos corridas iguales. (c) Un control negativo que comparte el confusor lo detecta en casi todas las muestras, y uno que no lo comparte no supera la tasa nominal. (d) Un plazo vencido, un cambio de regla de asignación y una covariable nueva producen cada uno su motivo; sin eventos y con plazo vigente, la lista está vacía.
  ],
)

#capa-impl[
== Implementación de referencia
<sec-snoobs-implementacion>

El cálculo es de mínimos cuadrados y cabe en numpy. El listado define las piezas del contrato y las prueba sobre el generador del caso medio: calcula el registro de sensibilidad con la escala de la mejor covariable observada, ejecuta el control negativo y decide qué eventos obligan a revisar.

#figure(
  kind: raw,
  caption: [Sensibilidad de un supuesto no observable: valor crítico de la decisión, escala de referencia, control negativo y motivos de revisión.],
  ```python
import numpy as np


def mco(y, regresores):
    """Mínimos cuadrados con constante: coeficientes, errores estándar y grados de libertad."""
    Z = np.column_stack([np.ones(len(y)), regresores])
    b = np.linalg.lstsq(Z, y, rcond=None)[0]
    e = y - Z @ b
    gl = len(y) - Z.shape[1]
    se = np.sqrt(np.diag(e @ e / gl * np.linalg.inv(Z.T @ Z)))
    return b, se, gl


def r2_parcial(y, regresores, j):
    """R2 parcial del regresor j (sin contar la constante), a partir de su estadístico t."""
    b, se, gl = mco(y, regresores)
    t = b[j + 1] / se[j + 1]
    return t ** 2 / (t ** 2 + gl)


def valor_critico(efecto, se, gl, umbral=0.0):
    """Fuerza (R2 parcial con D y con Y, iguales) que lleva el efecto hasta `umbral`."""
    f = abs(efecto - umbral) / (se * np.sqrt(gl))
    return 0.5 * (np.sqrt(f ** 4 + 4 * f ** 2) - f ** 2)


def cota_sesgo(se, gl, r2_y, r2_d):
    """|sesgo| por omitir un confusor con R2 parcial r2_y con Y y r2_d con D."""
    return se * np.sqrt(gl) * np.sqrt(r2_y * r2_d / (1 - r2_d))


def registrar_sensibilidad(efecto, se, gl, umbral_decision, escala, fecha, plazo):
    """Registro del contrato C-08 para un supuesto no observable.
    `escala` = (r2_d, r2_y) de la covariable observada más fuerte; fecha y plazo son ISO."""
    r2_d, r2_y = escala
    cota = cota_sesgo(se, gl, r2_y, r2_d)
    return {"estado": "cuantificada",
            "metodo": "robustez_r2_lineal",
            "objeto": "coeficiente lineal del tratamiento",
            "parametro": "valor de robustez respecto del umbral de decision",
            "umbral_decision": umbral_decision,
            "valor_critico": round(float(valor_critico(efecto, se, gl, umbral_decision)), 3),
            "escala": {"r2_d": round(float(r2_d), 3), "r2_y": round(float(r2_y), 3),
                       "rango_efecto": [round(float(efecto - cota), 3), round(float(efecto + cota), 3)]},
            "decision_fragil": bool(efecto - cota <= umbral_decision <= efecto + cota),
            "fecha": fecha, "revisar_antes_de": plazo}


def control_negativo(nc, d, X):
    """Efecto de D sobre un resultado que D no causa: distinto de cero indica confusión compartida."""
    b, se, gl = mco(nc, np.column_stack([d, X]))
    return b[1], se[1], bool(abs(b[1] / se[1]) > 1.96)


DISPARADORES = {"cambio_regla_asignacion", "covariable_nueva", "poblacion_nueva",
                "control_negativo_encendido"}


def motivos_revision(registro, hoy, eventos):
    """Motivos por los que una persona debe revisar el supuesto (lista vacía si ninguno).
    Las fechas ISO se comparan como texto."""
    motivos = sorted(set(eventos) & DISPARADORES)
    if hoy > registro["revisar_antes_de"]:
        motivos.append("plazo_vencido")
    return motivos


# Generador del caso medio: confusor U no observado, control negativo N que comparte U.
rng = np.random.default_rng(3)
n = 2000
X = rng.standard_normal((n, 2))
U = rng.standard_normal(n)
D = 0.6 * X[:, 0] + 0.3 * X[:, 1] + 0.5 * U + rng.standard_normal(n)
Y = 0.2 * D + 0.5 * X[:, 0] + 0.5 * X[:, 1] + 0.6 * U + rng.standard_normal(n)
N = 1.0 * U + rng.standard_normal(n)

b, se, gl = mco(Y, np.column_stack([D, X]))
escala = (r2_parcial(D, X, 0), r2_parcial(Y, np.column_stack([D, X]), 1))   # X1 con D y con Y
reg = registrar_sensibilidad(b[1], se[1], gl, 0.3, escala, "2026-01-15", "2026-04-15")
print(reg)

# La cota con los R2 verdaderos de U coincide con el sesgo real (identidad algebraica).
b_largo = mco(Y, np.column_stack([D, X, U]))[0]
r2_d_u, r2_y_u = r2_parcial(D, np.column_stack([X, U]), 2), r2_parcial(Y, np.column_stack([D, X, U]), 3)
assert abs(abs(b[1] - b_largo[1]) - cota_sesgo(se[1], gl, r2_y_u, r2_d_u)) < 1e-9
assert 0 < reg["valor_critico"] < 1 and reg["escala"]["rango_efecto"][0] < b[1] < reg["escala"]["rango_efecto"][1]
assert control_negativo(N, D, X)[2]                       # el control que comparte U se enciende
assert not control_negativo(rng.standard_normal(n), D, X)[2]   # un resultado sin relación con U no se enciende
assert motivos_revision(reg, "2026-02-01", []) == []
assert motivos_revision(reg, "2026-05-01", ["covariable_nueva"]) == ["covariable_nueva", "plazo_vencido"]
```
) <lst-sensibilidad-supuesto>

La ficha guarda `reg` como el campo `sensibilidad` del supuesto de no confusión (Apéndice #ref(<ap-model-card-causal>, supplement: none)), y el CI local lo exige con el esquema (@cap-cicd-causal). La operación de revisión la llama el monitoreo cada vez que emite un evento y cada vez que corre el plazo.
]

== #t-aplicacion
<sec-snoobs-aplicacion>

En el sistema de referencia, la ficha del estimador DML de retornos a la educación declara dos supuestos de clases distintas. El soporte común es observable: la ficha trae su umbral, calibrado con la tasa de falsas alarmas que el equipo tolera, y el monitoreo lo vuelve a medir en cada ventana. La no confusión condicional es no observable. La ficha solo puede llevar un valor crítico lineal si la reducción y el método que lo justifican están declarados; en otro caso registra `sin_cuantificacion_valida`, la evidencia indirecta disponible y una fecha de revisión. Cuando el monitoreo detecta que cambió la regla con que se asigna el tratamiento, la señal (ii) enciende una revisión con nombre y responsable, sin afirmar todavía que encontró confusión.

Lo que el libro enseña a ese sistema es una distinción y una disciplina. La distinción separa lo que se puede vigilar de lo que no. La disciplina consiste en que lo segundo no se declare verificado, se acote con un margen que otra persona pueda discutir y se vuelva a mirar cuando el mundo cambie. Un sistema así no sabe más sobre lo que no puede ver. Sabe cuánto de lo que afirma depende de ello, y lo dice.

== Señales de alerta y checklist operativo
<sec-snoobs-alertas>

#checklist[
  - Un supuesto no observable figura en la ficha como "verificado", o con una evidencia que no es un cálculo reproducible.
  - El valor de robustez se reporta sin el umbral de la decisión y sin la escala con que se interpreta.
  - Se aplicó la fórmula lineal a un estimador o a un supuesto para el que no se justificó su compatibilidad.
  - Se inventó una cuantificación en lugar de registrar `sin_cuantificacion_valida` y una revisión humana.
  - Un valor de robustez alto se cita como prueba de que no hay confusión.
  - La escala de referencia no está declarada, o se declara sin decir qué covariable la define.
  - El control negativo elegido no comparte ninguna causa con el resultado, y su silencio se presenta como confirmación.
  - La sensibilidad no se recalculó tras reentrenar con datos nuevos, cambiar de población o cambiar de especificación.
  - Nadie tiene a su cargo la revisión disparada por un evento, o la revisión termina siempre en "sigue valiendo" sin dejar nota.
]

== Ejercicios y notas bibliográficas
<sec-snoobs-ejercicios>

=== Ejercicios conceptuales
<sec-snoobs-ejercicios-conceptuales>

+ Con costo $c = 0.3$, efecto estimado $0.44$, error estándar $0.023$ y $1 thin 995$ grados de libertad, calcule el valor crítico de la decisión. Explique qué dice sobre la decisión y qué no dice.

+ Un equipo declara que "ningún confusor oculto es más fuerte que la mejor covariable observada", y con eso declara robusta la decisión. Dé dos razones por las que la declaración puede ser falsa y diga qué debe registrar la ficha para que otra persona pueda discutirla.

+ Para el estimador de retornos a la educación, proponga un resultado que sirva como control negativo (que la educación no pueda causar y que comparta una causa con el salario) y otro que no sirva. Explique por qué en cada caso.

+ Un colega cita un valor de robustez de 0,52 como prueba de que no hay confusión. Redacte en tres frases la respuesta, usando el caso 1.

+ Defina tres eventos que obliguen a revisar la sensibilidad del sistema de su organización, quién revisa y cuáles son los tres resultados posibles de la revisión.

#capa-impl[
=== Ejercicios computacionales
<sec-snoobs-ejercicios-computacionales>

+ Con las funciones del #ref(<lst-sensibilidad-supuesto>, supplement: [listado]), reproduzca la tabla del caso 1 para las cuatro intensidades y verifique que la cota coincide con el sesgo real en cada una.

+ Repita el caso 2 con costos $c = 0.1$ y $c = 0.5$. ¿Cómo cambia la fracción de decisiones frágiles y por qué?

+ Construya un control negativo que comparta solo una parte pequeña del confusor ($zeta = 0.1$) y estime su potencia para $n = 500$ y $n = 2 thin 000$.
]

=== Notas bibliográficas
<sec-snoobs-notas>

#cite(<cinellihazlett2020>, form: "prose") son la fuente de la cota y del valor de robustez en escala $R^2$, y el @cap-validacion presenta el protocolo completo con el _E-value_ de #cite(<vanderweele2017evalue>, form: "prose"). La versión para estimadores con aprendizaje automático, con otras cantidades en lugar de los $R^2$ parciales, es de #cite(<chernozhukov2022long>, form: "prose"). Los controles negativos vienen de la epidemiología: #cite(<lipsitch2010negative>, form: "prose") explican qué debe cumplir un control para detectar confusión y por qué su silencio no es una prueba. Para las tendencias paralelas, el análogo de este capítulo es el análisis de sensibilidad de #cite(<rambachan2023more>, form: "prose"), que acota cuánto puede desviarse la tendencia posterior de la observada antes del tratamiento. La idea de tratar la decisión, y no el efecto, como el objeto de la sensibilidad se apoya en el marco de decisión bajo incertidumbre del @cap-decisiones-estructurales.
