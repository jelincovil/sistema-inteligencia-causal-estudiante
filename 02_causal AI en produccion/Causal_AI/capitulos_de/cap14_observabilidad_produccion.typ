// Capítulo 14: Observabilidad de supuestos en producción.
// Edición de ingeniería de datos (main_de.typ). Caso canónico: scripts/cap14_monitor.py (semilla 20260714).
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Observabilidad de supuestos en producción]
<de-cap-monitor>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [El servicio puede seguir respondiendo con normalidad mientras los supuestos que sostienen el efecto dejan de valer],
    [*Decisión:*], [Cuatro señales causal-aware, no solo drift de inputs: marginal, mecanismo de asignación, instrumento y estabilidad del efecto],
    [*Pieza contratada:*], [Contrato C-07 (monitoreo causal): ventanas, señales, umbrales calibrados y una sola acción],
    [*Casos canónicos:*], [Cada cambio inyectado enciende su señal y casi ninguna otra: shift 100 %/(i), regla 100 %/(ii), instrumento 100 %/(iii), efecto 95 %/(iv) (semilla 20260714)],
    [*Conecta:*], [Las señales son las del C-02; la acción es una de las cinco del Capítulo 2; la puerta C-06 decide la promoción],
  )
]

== El monitoreo genérico no basta
<sec-de-14-problema>

El monitoreo estándar de ML vigila si la distribución de las entradas o de las predicciones se aleja de la de entrenamiento. Ese monitoreo es necesario y no suficiente para un sistema causal: el servicio del Capítulo 13 puede seguir respondiendo con total normalidad mientras aparecen señales que obligan a revisar el efecto servido. Ninguna señal aislada identifica automáticamente su causa; lo que hacen es indicar que la evidencia usada para describir el sistema ya no representa la ventana reciente.

La diferencia con el monitoreo genérico es de objeto: no se vigila solo la distribución de $X$ y de $hat(Y)$, sino la *relación* entre covariables y tratamiento, la fuerza del instrumento cuando el diseño lo usa, y la estabilidad del efecto reestimado. Eso exige mantener disponible el pipeline de estimación completo, no solo el modelo servido.

== Las cuatro señales
<sec-de-14-senales>

#definition(name: [Las cuatro señales del monitoreo causal])[
  (i) _Drift marginal_ de covariables: PSI y ASMD por variable, con la referencia fija. (ii) _Drift del mecanismo de asignación_: el propensity aprendido en la referencia se puntúa sobre la ventana y su AUC se compara con el de validación. (iii) _Fuerza del instrumento_: el F de la primera etapa para el instrumento excluido, no el F global del modelo. (iv) _Estabilidad del efecto_: el efecto se reestima en la ventana y se contrasta formalmente con el de referencia, propagando ambos errores estándar.
]

Cada señal responde una pregunta distinta, y su diseño evita una trampa específica:

+ *La (i) no usa p-valores.* Con ventanas grandes el KS rechaza ante diferencias irrelevantes; con pequeñas, no detecta las materiales. Se reporta tamaño de efecto (PSI, ASMD) con umbrales calibrados.
+ *La (ii) no reajusta el propensity en la ventana.* Si la regla pasa a depender de otra covariable con fuerza similar, el propensity reajustado es tan predecible como el viejo y el AUC no se mueve. Puntuar el modelo de referencia sí lo detecta.
+ *La (iii) no usa el F global.* El F del modelo mide el ajuste conjunto de todos los regresores; el del instrumento excluido mide su aporte específico.
+ *La (iv) no compara un punto contra un intervalo.* El contraste correcto es entre dos estimaciones, cada una con su error estándar: el contraste z divide la diferencia de efectos por la raíz de la suma de las dos varianzas.

#figure(
  diagram(
    node-stroke: 0.6pt + gray.lighten(40%),
    node-fill: light,
    node-outset: 4pt,
    node-corner-radius: 3pt,
    spacing: (5mm, 7mm),
    edge-stroke: 0.8pt + accent,
    node((0, 0), [(i) drift#linebreak()marginal]),
    node((0, 1.2), [(ii) drift#linebreak()mecanismo]),
    node((0, 2.4), [(iii) fuerza#linebreak()instrumento]),
    node((0, 3.6), [(iv) estabilidad#linebreak()efecto]),
    node((3.0, 1.8), [orden de#linebreak()preguntas], fill: rgb("EEF4F8")),
    node((5.8, 2.6), [abstenerse]),
    node((5.8, 1.8), [revisar ident.]),
    node((5.8, 1.0), [alertar]),
    node((5.8, 0.2), [reentrenar]),
    edge((0.9, 0), (2.2, 1.6), "-|>"),
    edge((0.9, 1.2), (2.2, 1.8), "-|>"),
    edge((0.9, 2.4), (2.2, 2.0), "-|>"),
    edge((0.9, 3.6), (2.2, 2.2), "-|>"),
    edge((3.8, 2.2), (5.2, 2.6), "-|>"),
    edge((3.8, 2.0), (5.2, 1.8), "-|>"),
    edge((3.8, 1.8), (5.2, 1.0), "-|>"),
    edge((3.8, 1.6), (5.2, 0.2), "-|>"),
  ),
  caption: [Las cuatro señales convergen en un orden de preguntas cuya primera falla decide la acción. Abstenerse va primero: sin soporte no hay estimador que juzgar. Revisar identificación va antes que alertar: un supuesto roto no se arregla con un aviso.],
) <de-fig-monitor>

== El contrato C-07: monitoreo causal
<sec-de-14-contrato>

#contrato(
  "C-07",
  "Monitoreo causal",
  operaciones: [
    _evaluar_: recibe una ventana reciente y devuelve el reporte de las cuatro señales con su valor, umbral y estado, y una sola acción. _calibrar_: toma ventanas del periodo de referencia y fija los umbrales para una tasa de falsas alarmas declarada.
  ],
  entrada: [
    La referencia fija (datos de entrenamiento con su huella). Los roles causales y el efecto con su error estándar de la tarjeta (C-05). Una función que reestima el efecto con el pipeline completo. Los umbrales vigentes con su tasa de falsas alarmas y fecha de calibración.
  ],
  salida: [
    Para cada señal: valor, umbral y estado — nunca un semáforo sin número. Una sola acción, la de la primera pregunta que falla según el orden de la @de-fig-monitor.
  ],
  invariantes: [
    (1) La referencia es fija: toda comparación usa la misma. (2) Todo umbral lleva su tasa de falsas alarmas y su fecha de calibración. (3) El propensity se puntúa con el modelo de la referencia, no se reajusta. (4) El efecto se reestima, no se predice con el modelo antiguo, y el contraste propaga los dos errores estándar. (5) Con la misma ventana y los mismos umbrales, el reporte es idéntico. (6) Una ventana demasiado pequeña o con faltantes se reporta como sin evidencia, nunca como todo en orden.
  ],
  fallos: [
    Umbral heredado de otro sistema: alarmas constantes o silencio. Reajustar el propensity en cada ventana: el cambio de regla pasa inadvertido. Comparar el efecto reciente contra el intervalo antiguo en vez de contrastar dos estimaciones. Vigilar solo el efecto y reaccionar tarde, o solo las marginales y alertar sin consecuencia.
  ],
  aceptacion: [
    Sobre un generador con verdad conocida: (a) sin cambio, la tasa de ventanas con señal no supera la declarada; (b) un desplazamiento marginal enciende la (i); (c) un cambio de regla enciende la (ii) y no la (i); (d) un instrumento sin fuerza enciende la (iii); (e) un cambio de efecto enciende la (iv). Semilla 20260714.
  ],
)

== Caso canónico: cuatro cambios, cuatro señales
<sec-de-14-caso>

#caso-canonico("Cada cambio enciende su señal y casi ninguna otra")[
  DGP con verdad: $X_1, X_2, X_3 tilde N(0,1)$, $Z tilde N(0,1)$ instrumento, $D tilde "Bernoulli"(sigma(X_1 + 0,8 Z))$, $Y = 0,5 D + X_1 + 0,5 X_3 + epsilon$. Referencia de 3 000 unidades, ventanas de 400, 100 réplicas por escenario (semilla 20260714 del script). La referencia estima ATE 0,486 (SE 0,040; verdad 0,5).

  #entero[
  #table(
    columns: (2.6fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Cambio inyectado*], [*(i)*], [*(ii)*], [*(iii)*], [*(iv)*]),
    table.hline(stroke: 0.3pt),
    [Ninguno], [0 %], [0 %], [0 %], [3 %],
    [$X_3$ + 1 DE], [100 %], [0 %], [0 %], [1 %],
    [Regla $X_1$ pasa a $X_2$], [0 %], [100 %], [0 %], [3 %],
    [Instrumento sin fuerza], [0 %], [0 %], [100 %], [2 %],
    [Efecto 0,5 a 0,1], [0 %], [0 %], [0 %], [95 %],
    table.hline(stroke: 0.6pt),
  )
  ]

  Cada cambio contemplado enciende la señal diseñada para verlo y casi ninguna otra. La tercera fila es la clave del capítulo: la señal (ii) detecta una regla de asignación distinta *aunque ninguna marginal se mueva* — exactamente lo que el monitoreo genérico no ve. La última fila muestra que solo la (iv) detecta el cambio de efecto, en el 95 % de las ventanas. Sin cambio, la única señal que se enciende es la (iv) en el 3 %, por debajo del 5 % nominal.
]

#repo-ref[
  Script #code[Causal_AI/scripts/cap14_monitor.py] (semilla 20260714) reproduce la tabla completa. Las cuatro señales del repositorio de referencia: #code[04_produccion_causal/src/causalops/monitor.py] y #code[diagnosticos.py].
]

== De la señal a la acción
<sec-de-14-accion>

Un reporte con cuatro semáforos deja sin responder lo importante: qué hacer. El orden de preguntas de la @de-fig-monitor se defiende por lo que cada fallo deja sin sentido. Sin soporte, las demás señales no significan nada: *abstenerse*. Un instrumento debilitado invalida la inferencia que depende de él; un cambio de asignación abre una revisión sin anticipar su veredicto: *revisar identificación*. Una población distinta puede dar un efecto válido para otro objetivo: *alertar*. Un cambio de efecto que llega con todo lo anterior en orden sí justifica actualizar: *reentrenar*, con la puerta del Capítulo 12 decidiendo la promoción.

Las cuatro señales vigilan supuestos observables. El que más pesa — que no haya confusión que las covariables medidas no recojan — no tiene señal: el sistema puede estar quieto en las cuatro y sesgado por una causa que nadie midió. Eso no se arregla con un quinto semáforo; se declara en la tarjeta (C-05) con su margen frente a la decisión y su fecha de revisión.

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ La señal (iv) con $alpha = 0,05$ tiene una tasa nominal de falsas alarmas del 5 % por ventana. Si el sistema evalúa una ventana cada día, ¿cada cuántos días esperaría una falsa alarma? Proponga una regla para reducirla. _Pista:_ una cada veinte días; exigir dos ventanas consecutivas baja la tasa y sube la demora.

+ Explique por qué reajustar el propensity en cada ventana falla justo en el caso que importa. _Pista:_ si la regla pasa a depender de otra covariable con fuerza similar, el modelo reajustado es tan predecible como el viejo.

+ Un equipo monitorea solo la distribución de $hat(Y)$. Construya un escenario donde esa distribución permanezca estable y la identificación esté rota. _Pista:_ cambio de regla de asignación sin mover marginales (fila 3 del caso canónico).

=== Notas bibliográficas

El monitoreo genérico de drift es de @huyen2022dmls (Capítulo 8) y @kastner2024mlip. El umbral $F > 10$ para instrumentos débiles proviene de @stock2005testing. Los criterios de balance de la señal (i) son los de @rubin2001using ya usados en el Capítulo 7. La lectura como contrato C-07 con orden de preguntas y cinco acciones es la contribución de este libro.

#verdad-datos[
  Que las cuatro señales se evalúen sobre ventanas con la misma referencia fija, con umbrales calibrados y su fecha, y que el reporte termine en una sola acción — nunca cuatro semáforos sin consecuencia. Que el efecto se reestime, no se prediga. Se comprueba con la semilla 20260714: cada cambio inyectado enciende su señal y casi ninguna otra; sin cambio, la tasa de falsas alarmas no supera la declarada. Lo que el monitoreo no garantiza: que la ausencia de señales implique ausencia de confusión no medida — eso se declara en la tarjeta, no se vigila aquí.
]
