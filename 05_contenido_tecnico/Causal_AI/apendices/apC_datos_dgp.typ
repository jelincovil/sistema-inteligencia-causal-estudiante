// Apéndice C: Datos de referencia y procesos generadores
// Los nombres de los conjuntos de datos del repositorio (identificadores) y la estructura de archivos
// van en la capa de implementación; la edición de principios describe los datos y no su empaquetado.
#import "../template/template.typ": *

#chapter[Datos, DGP y benchmarks]
<ap-datos-dgp>

#theorem-number-reset()

Los capítulos usan dos familias de datos, y cada una responde una pregunta distinta. Los *conjuntos reales* permiten contrastar un método con resultados publicados y con diseños que otros han estudiado, pero la verdad del efecto casi nunca se conoce. Los *procesos generadores sintéticos* (DGP, por _data generating process_) se construyen con un efecto verdadero conocido, y por eso permiten medir sesgo, cobertura y potencia de un estimador. Un método se acepta cuando funciona en ambos: en los sintéticos, porque acierta; en los reales, porque su respuesta es plausible y sus diagnósticos no la desmienten.

== Conjuntos reales
<sec-apC_reales>

#figure(
  caption: [Conjuntos de datos reales de referencia y capítulos donde se usan.],
  table(
    columns: (1.7fr, 0.8fr, 1.0fr, 0.9fr, 1.7fr),
    align: (left, left, left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Conjunto*], [*Diseño*], [*Estimando*], [*Caps.*], [*Qué permite contrastar*]),
    table.hline(stroke: 0.4pt),
    [Programa NSW de capacitación (Lalonde, 1986)#capa-impl[ \ #code[nsw_mixtape]]], [Experimento y comparación observacional], [ATE, CATE], [5, 10–13, 21, 24], [Un resultado experimental conocido (cerca de 1~800 USD) frente a estimadores observacionales],
    [Educación y salario, cercanía a una universidad (Card, 1995)#capa-impl[ \ #code[close_college]]], [IV], [LATE], [5, 10, 11, 13, 16, 17, 29], [Un instrumento binario con primera etapa de tamaño moderado],
    [Muestra de comparación de la CPS#capa-impl[ \ #code[cps_mixtape]]], [Observacional], [ATE], [11, 13, 14, 16], [Grupo de comparación grande, con diferencias de base marcadas],
    [Dejar de fumar y aumento de peso, NHEFS#capa-impl[ \ #code[nhefs]]], [Observacional], [ATE, CATE], [6, 11, 16, 24], [Selección entre muchas covariables],
    [Transferencias públicas#capa-impl[ \ #code[gov_transfers]]], [Observacional], [ATE, CATE], [12, 21, 24], [Covariables reales para procesos con efecto simulado],
    [Expansión carcelaria de Texas en 1993#capa-impl[ \ #code[texas]]], [Control sintético], [ATT], [28], [Un panel con una sola unidad tratada y muchas candidatas a donante],
    [Legalización del aborto#capa-impl[ \ #code[abortion]]], [Adopción escalonada], [ATT], [28], [Un panel con varias cohortes de adopción],
    [Doctrina del castillo (Cheng y Hoekstra, 2013)#capa-impl[ \ #code[castle]]], [DiD escalonado], [ATT], [complementario], [Efectos por cohorte y tendencias previas],
    [Pruebas de VIH con incentivos (Thornton, 2008)#capa-impl[ \ #code[thornton_hiv]]], [Experimento], [ATE, CATE], [14, 22], [Efectos de un incentivo asignado al azar y su heterogeneidad],
    [Elecciones reñidas de la Cámara de Representantes (Lee, Moretti y Butler, 2004)#capa-impl[ \ #code[close_elections_lmb]]], [RDD], [LATE], [complementario], [Continuidad en el umbral y sensibilidad al ancho de banda],
    [Donación de órganos#capa-impl[ \ #code[organ_donations]]], [DiD], [ATT], [complementario], [Tendencias paralelas en un cambio de regla],
    [Hipotecas#capa-impl[ \ #code[mortgages]]], [Observacional], [ATE], [complementario], [Ejercicios adicionales de ajuste por observables],
    table.hline(stroke: 0.8pt),
  )
) <tab-apC-reales>

Los capítulos señalados son aquellos donde el conjunto aparece en un ejemplo o en un ejercicio. Los marcados como complementarios no se usan en el texto y sirven para ejercicios adicionales.

== Procesos generadores sintéticos
<sec-apC_sinteticos>

Cada proceso sintético aísla una dificultad: se genera con un efecto verdadero conocido y con el defecto que se quiere estudiar, y no con todos a la vez. Esa disciplina permite saber qué rompió a un estimador cuando falla.

#figure(
  caption: [Procesos generadores sintéticos con efecto verdadero conocido.],
  table(
    columns: (1.8fr, 0.9fr, 0.9fr, 0.8fr, 1.8fr),
    align: (left, left, left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Proceso*], [*Diseño*], [*Estimando*], [*Caps.*], [*Dificultad que aísla*]),
    table.hline(stroke: 0.4pt),
    [Panel con efecto fijo dinámico#capa-impl[ \ #code[panel_fe_dynamic]]], [Panel], [ATE], [complementario], [Efecto individual conocido y heterogéneo],
    [DiD con tendencias paralelas#capa-impl[ \ #code[did_parallel_ok]]], [DiD], [ATT], [complementario], [Caso base donde el supuesto se cumple],
    [DiD con tendencias no paralelas#capa-impl[ \ #code[did_parallel_violation]]], [DiD], [ATT], [complementario], [Sesgo cuando el supuesto falla],
    [DiD escalonado con sesgo de TWFE#capa-impl[ \ #code[staggered_twfe_bias]]], [DiD escalonado], [ATT], [complementario], [Pesos negativos del estimador de dos vías],
    [IV con cumplimiento heterogéneo#capa-impl[ \ #code[iv_noncompliance]]], [IV], [LATE], [27], [Efecto solo para quienes cumplen],
    [IV con exclusión violada#capa-impl[ \ #code[iv_invalid_exclusion]]], [IV], [LATE], [complementario], [Sesgo cuando el instrumento afecta el resultado por otra vía],
    [Emparejamiento con confusor oculto#capa-impl[ \ #code[matching_hidden_conf]]], [Emparejamiento], [ATE], [complementario], [Sesgo que el emparejamiento no corrige],
    [Mediación con sesgo postratamiento#capa-impl[ \ #code[mediation_post_treatment]]], [Mediación], [Efecto directo], [complementario], [Sesgo por condicionar en un mediador],
    [Experimento con desgaste#capa-impl[ \ #code[rct_attrition]]], [Experimento], [ATE], [complementario], [Pérdida de unidades que depende del tratamiento],
    [RDD nítido con elección de ancho de banda#capa-impl[ \ #code[rdd_sharp_bandwidth]]], [RDD], [LATE], [complementario], [Compromiso entre sesgo y varianza],
    [RDD difuso con manipulación#capa-impl[ \ #code[rdd_fuzzy_manipulation]]], [RDD], [LATE], [complementario], [Acumulación de unidades en el umbral],
    [Control sintético con placebos#capa-impl[ \ #code[scm_placebo]]], [Control sintético], [ATT], [complementario], [Inferencia por permutación],
    table.hline(stroke: 0.8pt),
  )
) <tab-apC-sinteticos>

== Recomendaciones de uso por capítulo
<sec-apC_recomendaciones>

- *Caps. 5 y 6 (predicción y causalidad, regularización):* el programa NSW y la cercanía a la universidad para motivar la diferencia entre predecir y estimar; dejar de fumar para la selección con muchas covariables; un proceso sintético para ilustrar el sesgo.
- *Caps. 10 y 11 (ortogonalidad y DML):* el programa NSW como aplicación y un proceso sintético con efecto conocido para verificar la cobertura del intervalo.
- *Caps. 12 y 13 (meta-learners y bosques causales):* un proceso sintético con efecto heterogéneo conocido, y el programa NSW como aplicación.
- *Cap. 14 (validación):* un proceso sintético con verdad conocida, y las pruebas de VIH para ejercicios con placebos.
- *Cap. 16 (selección en alta dimensión):* dejar de fumar y la cercanía a la universidad.
- *Cap. 17 (panel):* un panel sintético con efectos fijos.
- *Caps. 21 y 22 (políticas y uplift):* las transferencias públicas y las pruebas de VIH.
- *Cap. 27 (aprendizaje profundo causal):* un proceso sintético con estructura conocida.
- *Cap. 28 (control sintético y matrix completion):* el panel de Texas y los procesos con factores latentes.
- *Cap. 29 (descubrimiento de grafos):* un proceso sintético con estructura causal conocida.

== Datos complementarios sugeridos
<sec-apC_complementarios>

#figure(
  caption: [Datos complementarios sugeridos.],
  table(
    columns: (1.4fr, 1.0fr, 1.4fr, 1.2fr),
    align: (left, left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Conjunto sugerido*], [*Diseño causal*], [*Uso en el libro*], [*Fuente*]),
    table.hline(stroke: 0.4pt),
    [Progresa/Oportunidades], [RDD], [Cap. 18 (mapa de decisión)], [Evaluación de impacto],
    [Panel de salario mínimo], [DiD], [Cap. 17 (panel)], [Literatura de salario mínimo],
    [Bono de reempleo], [Experimento], [Caps. 5 y 11], [Literatura de seguro de desempleo],
    [Brecha salarial en la CPS], [Doble lasso], [Caps. 6 y 16], [Datos de la CPS],
    [Convergencia del crecimiento], [Selección y DML], [Cap. 16], [Literatura de crecimiento],
    [Proceso tipo IHDP], [Referencia de CATE], [Cap. 27], [Literatura de aprendizaje profundo causal],
    [Texto e _embeddings_ de producto], [CATE con texto], [Caps. 22 a 27], [Procesamiento de lenguaje],
    table.hline(stroke: 0.8pt),
  )
) <tab-apC-complementarios>

Algunos de estos conjuntos pueden no estar disponibles. En ese caso se recomienda un proceso sintético que emule las mismas características: un confusor de la fuerza que importa, un efecto verdadero conocido y el defecto que se quiere estudiar.

== Verdad conocida e integridad
<sec-apC_checksums>

Un proceso sintético se entrega en dos partes: los datos que ve quien estima, sin la verdad, y los valores verdaderos (los efectos individuales $tau_i$, el parámetro $theta$, los efectos directos e indirectos) que conserva quien evalúa. Esa separación permite medir la precisión de una estimación sin revelar la respuesta de antemano.

Todo conjunto, real o sintético, se acompaña de una suma de verificación SHA-256 por archivo, calculada al publicarlo. La suma garantiza que la evaluación se hace sobre la versión exacta del conjunto prevista, y que un archivo modificado o dañado se detecta antes de usarlo y no después de reportar un resultado.

#capa-impl[
  == Estructura de archivos
  <sec-apC_estructura>

  Cada conjunto real tiene:

  - #code[data.csv]: datos en formato _tidy_.
  - #code[source_metadata.json]: fuente, licencia, año y diccionario de variables.
  - #code[checksums.sha256.json]: integridad verificable.

  Cada conjunto sintético tiene:

  - #code[student.csv]: datos visibles para quien estima, sin la verdad.
  - #code[truth_instructor_only.csv]: la verdad ($tau_i$, $theta$, etc.), para quien evalúa.
  - #code[checksums.sha256.json].

  Para verificar la integridad de un conjunto descargado:

  #figure(
    kind: raw,
    caption: [Verificación de integridad de un conjunto con sumas SHA-256.],
    ```python
import hashlib, json, pathlib

carpeta = pathlib.Path("ruta/del/conjunto")
# se supone que el archivo asigna a cada nombre de archivo su suma SHA-256
esperadas = json.loads((carpeta / "checksums.sha256.json").read_text())
for nombre, suma in esperadas.items():
    real = hashlib.sha256((carpeta / nombre).read_bytes()).hexdigest()
    print(nombre, "OK" if real == suma else "DISTINTO")
```
  ) <lst-apC-checksums>

  Si todos los archivos coinciden, la salida muestra #code[OK] para cada uno. Un resultado #code[DISTINTO] indica que el archivo fue modificado o está dañado, y se recomienda descargarlo de nuevo del repositorio oficial.
]
