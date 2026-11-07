// Capítulo 9: Lo que DML le exige al dato (compresión de consumo).
// Edición de ingeniería de datos (main_de.typ). Casos canónicos: scripts/cap09_exigencias.py;
// el caso canónico del cross-fitting se cita de la edición de método (Cap. 11, mismo DGP, semilla declarada).
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Lo que DML le exige al dato]
<de-cap-dml>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Tesis:*], [Un estimador DML es un consumidor con exigencias al dato: si no se hacen, el estimador no falla con error claro: el resultado sale mal sin que nada lo anuncie],
    [*Cuatro exigencias:*], [nuisance con tasa suficiente · partición *out-of-sample* (cross-fitting) · soporte común y ESS · estimando declarado ante un posible trimming],
    [*Pieza contratada:*], [El contrato C-12 (entrega de exigencias del estimador), el puente entre el plano de datos y el DML],
    [*Casos canónicos:*], [Cross-fitting: OLS 1,41 / sin CF 0,86 / con CF 0,95 (mismo DGP que la edición de método); ESS 85 de 3 000; plug-in vs doble robustez],
    [*Los teoremas completos:*], [Edición de método de este libro (Caps. 10–11); acá solo la receta que el pipeline tiene que garantizar],
  )
]

== Este capítulo es de consumo, no de método
<sec-de-09-consumo>

La teoría del DML — ortogonalidad de Neyman, modelos PLR/IRM/PLIV como estimandos distintos, la doble robustez como propiedad estadística del *score* — no la repite este libro, porque está escrita completa y con sus condiciones en la edición de método (Caps. 10 y 11). Lo que este capítulo hace es la traducción que esa teoría le pide al plano de datos: *un estimador DML es un consumidor del pipeline*, y cuatro de sus exigencias solo pueden entregarse ahí abajo. No son detalles de implementación: cada una es una condición sin la cual el resultado del estimador sale mal **sin que el estimador lo sepa**. El riesgo particular de DML es exactamente ése: una casa de buen diseño levantada sobre un sumidero.

El formato es deliberado: cada sección dice qué promesa estadística hay detrás (una oración de menor técnica, con la remisión al teorema que la prueba), qué forma toma en el pipeline, y qué verificación del plano de datos la hace cumplir — junto al caso canónico con cifras reales, y su cierre con el contrato C-12, la pieza que formaliza el trabajo.

== Exigencia 1: la partición out-of-sample (cross-fitting)
<sec-de-09-cf>

*Lo que dice la teoría (edición de método, Cap. 10):* si los _nuisance_ — $hat(ell)(X)$ y $hat(m)(X)$ en el PLR — se estiman sobre las mismas unidades cuyo residuo alimenta la ecuación del parámetro, el error de sobreajuste entra en $hat(theta)$ forzado a ser covariante con lo que el modelo acaba de memorizar. El cross-fitting — los folds $k$ se ajustan fuera y predicen dentro — convierte esa covariancia en error que promedia a cero, y el estimador recupera su sesgo bajo y su normalidad asintótica.

*La exigencia al plano de datos:* que *ninguna unidad sea predicha por un modelo que la vio*, y que ningún preprocesamiento se ajuste sobre datos fuera del fold de entrenamiento. Cuatro invariantes, no uno:

+ Las particiones de prueba cubren cada unidad exactamente una vez, y ninguna figura a la vez en el entrenamiento y en la prueba del mismo fold.
+ Predicción de la unidad $i$ con modelos que no la vieron — una versión por fold, no un solo modelo.
+ Todo preprocesamiento (escalado, imputación, selección de variables) dentro del ajuste de cada fold, no global antes de partir.
+ Dadas la partición y la semilla, la estimación reproduce; si cambia la semilla, la diferencia es parte de la estimación, no decoración.

#caso-canonico("La fuga entre folds, cantada por cifras conocidas")[
  Reusemos el caso canónico de la edición de método (Cap. 11, DGP declarado): $X_i ∈ [-1,1]^5$ uniformes, $h(X) = sin(3x_0)+x_1^2$, $D = h(X)+epsilon_D$, $Y = 1 dot.c D + 2 h(X)+epsilon_Y$, con 2 000 unidades y 20 repeticiones, verdad de efecto 1. Sus cifras son el mejor contraste de este capítulo: OLS con los cinco controles lineales — *1,41* (la confusión no lineal queda entera); DML con boosting *sin* cross-fitting — *0,86* (el modelo memoriza las unidades y subestima la confusora); DML con boosting *con* cross-fitting $K=5$ — *0,95* (el sesgo baja a ~0,05, el residuo de tamaño muestral). El camino de 0,86 a 0,95 no es una mejora del estimador: es el *mismo* estimador sobre dos planos de datos distintos — el que fuga y el que no.
]

#repo-ref[
  El script #code[Causal_AI/scripts/cap09_exigencias.py] (semilla 20260701) corre sobre el mismo DGP y datos reales del ESS y la doble robustez, con las cifras propias de este capítulo. Las cifras del cross-fitting citadas arriba (1,41 / 0,86 / 0,95) son las del caso canónico publicado en la edición de método (Cap. 11), con su seed y su DGP declarados; reproducibles en el material complementario de esa edición.
]

== Exigencia 2: soporte común y ESS de Kish
<sec-de-09-ess>

*La promesa:* el estimador compara tratados y controles en las covariables $X$; si en algunas zonas el propensity $e(X) = E[D|X]$ cae a ~0 o sube a ~1, la comparación se acerca a un solo brazo y la ponderación IPW explota — la varianza crece y la inferencia cruza de estimable a deseable. La condición es *soporte común*: $0 < e(X) < 1$ con margen real, no solo por definición.

*La exigencia al plano de datos:* medir el soporte común con dos cantidades observables, nunca solo "históriamente de acuerdo". Primero, el *ESS de Kish* del brazo IPW:

$
"ESS" = ((sum_i w_i)^2) \/ (sum_i w_i^2), quad w_i = D_i \/ hat(e)(X_i) + (1 - D_i) \/ (1 - hat(e)(X_i)),
$

y el cociente $"ESS"/n$ como regla operativa: un $"ESS"/n << 1$, aunque el histograma "se vea bien", dice que unas pocas unidades con $hat(e)$ extremo dominan la estimación. Segundo, el rango de $hat(e)$: reportar cuántas unidades caen en $hat(e) ∉ [0,05, 0,95]$.

#caso-canonico("El ESS es 85 sobre 3 000")[
  Con propensity $e = sigma(4x_0)$, n = 3 000 (semilla 20260701 del script), el ESS de Kish del brazo IPW es *85*: con ESS/n = 0,03, casi todo el peso recae en muy pocas unidades. Trimming de @crump2009dealing con $alpha = 0,1$: conserva solo el *42 %* de la muestra (1 274 unidades) y sube el ESS/n recortado de 0,03 a 0,67 — a cambio de excluir el *57,5 %* de la población. La moraleja es la del contrato: cuando el soporte común se corta, el estimando cambia — ya no es el ATE de la población completa sino el de quienes quedan en el support —, y declararlo es una *obligación del registro*, no una nota al pie: la ficha y el servicio de la Parte IV lo documentan, cuánto y dónde.
]

== Exigencia 3: el nuisance no es decoración
<sec-de-09-nuisance>

*La promesa:* en el score ortogonal, los errores de los _nuisance_ estudian de segunda — $sqrt(n) a_n^2 -> 0$ es la condición de tasa que guarda la distribución asintótica —, y la doble robustez mantiene la consistencia si *uno* de los dos (outcome o propensity) es correcto. Lo que la promesa no promete: si ambos fallan, la ortogonalidad no recompone.

*La exigencia al plano de datos:* medir el desempeño de los _nuisance_ fuera de muestra (el $R^2$ y su cobertura por covariable), documentado, junto a la comparación de learners — LASSO + boosting/dense —, no una tabla de celebración. Si el outcome está mal especificado de manera estructural — un lineal que pasa por encima de una forma no lineal pronunciada — y el propensity solo se estima chuzo, el efecto lo paga.

#caso-canonico("Sesgo de especificación y doble robustez en acción")[
  Con outcome $mu(d, x) = 0.3 d + 0.7 x_0 + 1.3 sin(2.8 x_1)$ (efecto constante 0,3), propensity correcto por diseño, y el outcome estimado con el modelo lineal equivocado (semilla 20260701), el estimador plug-in cae justo sobre el verdadero (*0,30*) en *este* ejemplo — y eso es exactamente la advertencia: con un efecto pequeño y una no linealidad fuerte, la mala especificación pudo haber destapado un número distinto sin anunciarlo. El estimador doblemente robusto cubre la misma mala especificación con su segunda pierna: estima $mu$ pobre pero compensa con $hat(e)$ correcto y sigue en ~0,30. La lección del script no es que nunca se falle, sino que *la verificación es sobre datos, no sobre promesas*: medir el $R^2$ fuera de muestra del outcome y del propensity, y comparar learners, es parte del entregable del pipeline — dos cantidades que el registro conserva junto al efecto (@de-cap-versionado).
]

La regla operativa respecto de *qué learner usar* se separa con cuidado del estimando. Cada learner tiene condiciones de tasa propias (en baja dimensión suave puede aparecer $n^(-2/5)$; en LASSO esparso la condición se traduce en $s log p = o(sqrt(n))$, condiciones de aproximación y regularidad de la forma, y la edición de método las trata con su clase de learner). *La validación predictiva no prueba por sí sola las condiciones de tasa de DML*: es evidencia razonable junto a la comparación de learners, no demostración (la edición de método lo formula igual).

== El contrato C-12: entrega de exigencias del estimador
<sec-de-09-c12>

Tres documentos que el plano de datos produce y que toda estimación DML cosume, con nombre y verificación:

#contrato(
  "C-12",
  "Entrega de exigencias del estimador (DML y afines)",
  operaciones: [
    _entregar_: produce el bundle versionado que el estimador consume — esquema C-01, partición C-10, bundles de nuisance fuera-de-muestra (modelos y preprocesos por fold), documento de soporte (rango de $hat(e)$, ESS/n, regla de trimming y su decisión de estimando), ficha de desempeño de los nuisance (_$R^2$ y comparación de learners_).
  ],
  entrada: [
    El registro de versiones (C-09), la auditoría de tiempos (C-03 contra el tratamiento y el momento de decisión) y la semilla de los folds (C-10).
  ],
  salida: [
    El bundle reproducible: `estimacion.json` con las exigencias registradas y los artifactos de nuisance con hashes. El documento de soporte con trimming y su estimando declarado. La colección de validaciones por fold y learners como escribibles del C-02: sin documento, sin afirmación.
  ],
  invariantes: [
    (1) Los modelos de nuisance que predicen la unidad $i$ no la entrenaron, y el preproceso de cada fold no vio su fold de prueba. (2) La semilla del cross-fitting y de los folds es parte del registro. (3) El trimming, si lo hay, se documenta como cambio de estimando con su porcentaje y región fuera del support. (4) Si el $R^2$ del outcome o del propensity fuera de muestra es bajo, la estimación no pasa a servicio: queda bloqueada, marcada para revisión. (5) El bundle registra la comparación de al menos dos learners (por ejemplo, LASSO y uno no lineal), de forma reproducible. (6) Un bundle que incumpla el invariante de la fuga entre folds queda impugnado desde el registro: no entra al descriptor del estimador sin reparar.
  ],
  fallos: [
    Una partición de folds presentada de memoria sin su semilla (ya lo impide el inv. 2): la caida es la de antes, el comprobante es el de después. Preprocesamiento ajustado sobre la tabla completa (inv. 1): la tabla blek se ve y nadie lo cuenta. Una comparación de learners cherry-picked después de tener el resultado (inv. 5). Un trimming declarado a posteriori como si fuera la regla inicial (inv. 3).
  ],
  aceptacion: [
    (a) El caso del cross-fitting reproduce las cifras de la edición de método sobre el mismo DGP y semilla declarada. (b) El caso del ESS informa ESS/n = 0,03 y el trimming con el estimando en su nueva población declarada. (c) El caso de la doble robustez distingue el plug-in del estimador con segunda pierna, con outcome mal especificado. Las cuatro verificaciones quedan registradas en el bundle.
  ],
)

== Qué aprende el plano de datos con esto
<sec-de-09-aprender>

Los tres casos canónicos comparten una moraleja: el estimador no es el punto típico de fallo: lo son los requisitos del dato que solo el plano de datos puede garantizar. Esto no demuestra que DML sea la respuesta (esa decisión es de cómo se modela, y vive en la edición de método); lo que este capítulo asegura es que si se elige DML, sus cuatro exigencias llegan servidas y verificables. Lo que el capítulo pide de método es deliberadamente el mínimo declarado; el resto es ingeniería del plano de datos.

== Cómo diagnosticar una violación
<sec-de-09-diagnostico>

Cada exigencia tiene su síntoma cuando se viola, y saber reconocerlo es la diferencia entre corregir en minutos y descubrir en la revisión posterior. La tabla resume los cuatro diagnósticos:

#entero[
#table(
  columns: (1.6fr, 2.4fr, 2.4fr),
  align: (left, left, left),
  stroke: none,
  table.hline(stroke: 0.6pt),
  table.header([*Exigencia violada*], [*Síntoma observable*], [*Cómo confirmarlo*]),
  table.hline(stroke: 0.3pt),
  [Cross-fitting], [El efecto estimado cambia al reordenar las filas o al cambiar la semilla de los folds; la estimación no reproduce], [Correr el mismo estimador con dos semillas distintas y comparar; si difieren más que el error estándar, hay fuga],
  [Soporte común], [Los pesos IPW explotan; el intervalo de confianza es enorme; algunas ponderaciones valen miles], [Calcular ESS/n y el rango de la propensión; si ESS/n es muy bajo, el soporte está roto],
  [Nuisance mal especificado], [El plug-in difiere del doblemente robusto en más que el error estándar; al cambiar de learner el efecto se mueve], [Comparar el R² fuera de muestra del nuisance con un modelo trivial; si no supera, la especificación es deficiente],
  [Trimming silencioso], [El estimando reportado no declara la población recortada; la ficha no menciona el cambio de estimando], [Comparar la n del estimando con la n del dataset; si difieren, hubo recorte y no se declaró],
  table.hline(stroke: 0.6pt),
)
]

La lección práctica: *cada síntoma tiene una métrica que lo detecta, y ninguna de esas métricas es el error predictivo*. Un pipeline que solo monitorea la calidad del ajuste no ve ninguna de estas violaciones. Por eso el C-12 exige que el bundle registre ESS/n, rango de propensión, comparación de learners y la decisión de trimming: son los cuatro indicadores que el plano de datos puede medir y que el estimador, por sí solo, no reporta.

== El bundle como entregable
<sec-de-09-bundle>

El C-12 produce un artefacto concreto: el *bundle* que el estimador consume. No es una abstracción — es un directorio con archivos específicos:

#entero[
#table(
  columns: (1.4fr, 2.6fr, 2fr),
  align: (left, left, left),
  stroke: none,
  table.hline(stroke: 0.6pt),
  table.header([*Archivo*], [*Contenido*], [*Quién lo consume*]),
  table.hline(stroke: 0.3pt),
  [`esquema.json`], [Roles causales (C-01): tratamiento, resultado, covariables, instrumentos], [El estimador, la auditoría temporal, el registro],
  [`particion.json`], [Semilla, proporciones, índices de cada fold (C-10)], [El cross-fitting, la evaluación OOS],
  [`nuisances/`], [Modelos de outcome y propensity por fold, con hash y semilla], [El estimador DML en cada fold],
  [`soporte.json`], [Rango de propensión, ESS/n, decisión de trimming, población del estimando], [La puerta (C-06), la tarjeta (C-05), el servicio (C-04)],
  [`desempeno.json`], [R² fuera de muestra por nuisance, comparación de learners], [La puerta, la revisión de identificación],
  table.hline(stroke: 0.6pt),
)
]

El bundle es lo que hace audible la frase «el plano de datos entrega las exigencias del estimador». No es un documento que alguien lee: es un directorio que el estimador carga, que la puerta evalúa y que el registro conserva. Un bundle que falta alguno de esos archivos no es un bundle: es una tabla suelta que viola el invariante del Capítulo 2.

== El trimming como cambio de estimando
<sec-de-09-trimming>

El trimming de @crump2009dealing merece su propia discusión porque es la decisión más fácil de tomar mal. La regla — recortar las unidades con propensión fuera de $[alpha, 1-alpha]$ — es estadísticamente correcta para reducir la varianza, pero tiene una consecuencia que el pipeline no puede ignorar: *el estimando cambia*. Ya no es el ATE de la población completa sino el ATE de quienes quedan dentro del soporte.

Esa distinción no es un matiz técnico: cambia quién queda incluido en la afirmación y quién no. Si el 57,5 % de la población queda fuera (como en el caso canónico), la afirmación publicada cubre al 42,5 % restante, y reportarla como «ATE de la campaña completa» es simplemente falso. La ficha del modelo (@de-cap-versionado) y el servicio (@de-cap-servicio) documentan la población del estimando exactamente por eso: para que la abstención del Capítulo 13 sepa dónde el efecto no aplica.

La decisión correcta no es «trimming sí o no» sino: *¿qué estimando sirve a la decisión que el sistema apoya?* Si la decisión necesita el efecto sobre toda la población, el trimming rompe la pregunta. Si la decisión necesita el efecto sobre quienes tienen soporte, el trimming es la respuesta correcta y el estimando cambia. Lo que no es aceptable es recortar y no declararlo.

== El fallo que cada exigencia previene y el que no
<sec-de-09-fallos>

Cada exigencia del C-12 tiene un fallo que previene y uno que no. Distinguirlos es la diferencia entre usar el contrato y usarlo como decoración:

#entero[
#table(
  columns: (1.6fr, 2.4fr, 2.4fr),
  align: (left, left, left),
  stroke: none,
  table.hline(stroke: 0.6pt),
  table.header([*Exigencia*], [*Fallo que previene*], [*Fallo que NO previene*]),
  table.hline(stroke: 0.3pt),
  [Cross-fitting], [El estimador memoriza las unidades y subestima la confusora: 0,86 vs 0,95], [La confusión no observada que ninguna partición corrige],
  [Soporte común], [La ponderación IPW explota porque pocas unidades dominan: ESS 85 de 3 000], [Que la población recortada no sea la que la decisión necesita],
  [Nuisance con tasa], [La mala especificación estructural del outcome: plug-in vs DR en 0,30], [Que un learner gane por sobreajuste a la validación],
  [Estimando ante trimming], [Reportar el ATE recortado como si fuera el completo: 42 % vs 100 %], [Que el trimming sea la decisión correcta para la pregunta],
  table.hline(stroke: 0.6pt),
)
]

La lectura: cada exigencia cierra una puerta específica. El cross-fitting cierra la puerta de la fuga; el soporte común cierra la puerta de la ponderación explosiva; el nuisance cierra la puerta de la mala especificación; el estimando declarado cierra la puerta del recorte silencioso. Pero ninguna cierra la puerta de la confusión no observada: esa la cierra la teoría causal, no la ingeniería de datos.

== Cuándo sabes que tu DML está mintiendo
<sec-de-09-mintiendo>

Hay cinco señales que, juntas, dicen que el resultado de un DML no es confiable aunque el número parezca razonable:

+ *El efecto cambia al cambiar la semilla.* Si reordenar las filas o cambiar la semilla de los folds mueve el efecto más que el error estándar, hay fuga. El cross-fitting es la corrección; sin él, la estimación no reproduce.
+ *Los pesos IPW valen miles.* Si algunas ponderaciones $1\/hat(e)$ son órdenes de magnitud mayores que otras, unas pocas unidades dominan la estimación y el intervalo es engañosamente estrecho.
+ *El plug-in y el doblemente robusto difieren.* Si los dos estimadores — uno con nuisance lineal y otro con no lineal — dan efectos distintos fuera del error estándar, al menos uno está mal especificado. La dirección de la diferencia dice cuál.
+ *Cambiar el learner cambia el efecto.* Si pasar de LASSO a boosting mueve el efecto más que el error estándar, la especificación del nuisance no es robusta y el resultado es un artefacto del learner elegido.
+ *El estimando no declara su población.* Si la ficha no dice sobre quién vale el efecto, nadie puede saber si el recorte de soporte cambió la población de la afirmación.

Ninguna de estas señales es el error predictivo del nuisance. Un pipeline que solo monitorea $R^2$ no ve ninguna de las cinco. Por eso el C-12 exige métricas específicas: ESS/n, r2 OOS, comparación de learners, y la decisión de trimming con su población declarada.

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ Calcule la SMD y las desviaciones del caso del cross-fitting: OLS tiene sesgo ~+0,41 y sin CF ~-0,14; ¿qué distingue la naturaleza del problema en cada uno, y cuál se arregla con mejor especificación y cuál solo con mejor pipeline? _Pista:_ uno es problema de especificación del modelo (es problema del método), el otro de fuga de dados (naturaleza pipeline).

+ Con la población de la Ex. 2 (ESS = 85 sobre 3 000), describa cuánto de la muestra tiene $hat(e) < 0,05$ y diga cuál es el estimando post-trimming. ¿Es correcto reportar el mismo estimando como "ATE de la campaña completa"? _Pista:_ ni objetivo declarado sobre poblacion cambió: 42 % conservado implica que el 58 % quedó fuera por la regla de Crump, y la ficha lo documenta.

+ La comparación de learners de este capítulo añade LASSO y un no lineal. Dé las dos hipótesis sobre la esparsidad y suavidad y cómo se relacionan con la condición $sqrt(n) a_n^2 -> 0$ de la edición de método. _Pista:_ con $s$ variables verdaderas y $p$ totales (LASSO): $s log p = o(sqrt(n))$; la forma funcional no lineal exige condiciones de aproximación y regularidad propias.

+ ¿Por qué en el caso de outcome mal especificado la doble robustez no sube a exactamente 0,347 o baja a 0,28, cuando las cifras muestran que sigue en ~0,30? Explique el papel del propensity "exacto" por diseño del DGP. _Pista:_ si el propensity fuera además mala especificado, ninguna pierna de DR compensa; el control pretó la falla exclusiva al outcome.

+ Liste tres documentos que el registro espera anexos al estimador, y etiquete cada uno: ficha del estimador (Cap. #ref(<de-cap-versionado>, supplement: none)), documento de soporte (C-12) o artefacto servible (Parte IV). _Pista:_ ESS/n y el rango de $hat(e)$ comparten dos destinos; la regla de trimming va a la ficha; la partición del cross-fitting queda en el documento.

+ Su equipo corre DML y el efecto cambia de 1 500 a 1 800 al pasar la semilla de 42 a 43. Diagnostique la causa y proponga la corrección. _Pista:_ revisar la tabla de diagnósticos de la sección de este capítulo; la no-reproducibilidad ante cambio de semilla es síntoma de fuga en cross-fitting.

+ Su bundle registra ESS/n = 0,03 pero no incluye la decisión de trimming. ¿Qué invariante del C-12 se viola y qué debería pasar con la estimación? _Pista:_ (3): el trimming se documenta como cambio de estimando; sin documentación, la estimación queda impugnada (6).

+ El plug-in da 0,25 y el doblemente robusto da 0,40 con el mismo dataset. El SE es 0,05. ¿Qué le dice la diferencia, y qué verificación adicional haría antes de confiar en uno u otro? _Pista:_ la diferencia de 0,15 es tres SE: al menos un nuisance está mal especificado; comparar learners antes de decidir.

=== Notas bibliográficas

La teoría que este capítulo comprime vive entera en la edición de método: la ortogonalidad de Neyman y las condiciones de tasa con @chernozhukov2018double (Caps. 10 y 11 de esa edición). La regla de trimming con varianza asintótica es derivada por @crump2009dealing y el ESS ponderador es el de @kish1965. La contribución del capítulo es la lectura de consumo: los teoremas no se reescriben — su promesa se convierte en verificaciones con nombre propio del plano de datos (C-12), con sus cifras canónicas citadas y sus casos ejecutables en el repositorio.

#verdad-datos[
  Que ningún modelo de nuisance prediga una unidad de su propio entrenamiento, y ningún preproceso vea su fold de prueba. Que la semilla del cross-fitting quede registrada. Que el soporte común se reporte con el rango de $hat(e)$ y el ESS/n, y que un trimming, si lo hay, cambie el estimando y lo anuncie como tal. Que los nuisances entreguen su $R^2$ fuera de muestra y la comparación de al menos dos learners. Se comprueba reproduciendo los casos del capítulo — las cifras del cross-fitting citadas de la edición de método, el ESS = 85 de 3 000, la doble robustez con outcome mal especificado — con los scripts del repositorio. Lo que este capítulo certifica no es el efecto en cada dataset: es que el plano de datos entrega las cuatro condiciones para que el estimador cumpla su promesa.
]
