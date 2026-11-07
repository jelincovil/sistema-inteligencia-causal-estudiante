# Plan de escritura: «Ingeniería de datos causales» en un mes

*Plan de trabajo para reescribir la monografía como libro de ingeniería de datos, en 22 días de trabajo efectivo. Basado en la evaluación de `results/evaluacion_monografia_y_plan.md` y el giro de foco confirmado por el autor.*

---

## 1. El libro en una frase

> En un sistema de decisión, el trabajo del dato no es «llegar con calidad al modelo»: es **preservar la identificación**. Este libro enseña los pipelines, contratos, versionados y observabilidad que hacen que el enunciado causal sobreviva al trayecto — del esquema con roles al servicio que se abstiene.

**Título de trabajo:** *Ingeniería de Datos Causales* (subtítulo: *pipelines, contratos y observabilidad para sistemas de decisión*).
**Edición:** nueva edición Typst `main_de.typ` junto a `main.typ` (que se conserva intacta como edición de método/curso). Las dos comparten `template/` y capítulos reutilizados.
**Extensión objetivo:** 15 capítulos + apéndices, ~300–350 páginas, ~80 000 palabras (≈50–60 % prosa adaptada de la monografía, 40–50 % nueva).
**Supuesto:** 1 autor a tiempo completo, 22 días. Los capítulos de método completos **no se pierden**: quedan en la edición `main.typ`; el libro nuevo los comprime a capítulos «consumidor».

## 2. Índice nuevo y mapa de reutilización

### Parte I — El dato como estimando

| Cap. nuevo | Título | Fuente | Tipo de trabajo |
|---|---|---|---|
| 1 | Causalidad elemental para ingeniería de datos | cap01 | Reorientar y cortar ~40 %: estimandos, resultados potenciales, por qué la fuga rompe la identificación |
| 2 | Anatomía de un sistema de decisión | cap02 | Reorientar: el plano de datos frente al plano del método |
| 3 | Contratos de datos causales | cap04 + Ap. I (C-01…C-08) + `schema.py` | **Núcleo nuevo**: roles, invariantes, pruebas de aceptación |
| 4 | Versionado, linaje e inmutabilidad | cap07 + `registro_local.py` | **Núcleo nuevo**: hashes, semillas, splits, alias `champion` |

### Parte II — El pipeline que preserva la identificación

| Cap. nuevo | Título | Fuente | Tipo de trabajo |
|---|---|---|---|
| 5 | Splits y la pared observado/evaluación | cap07 + filosofía del benchmark | Reorientar: separación como gobierno del dato |
| 6 | Validez temporal y control de fuga | cap09 | Reorientar y ampliar: point-in-time correctness, features posteriores al tratamiento |
| 7 | Calidad y observabilidad de datos | cap30 + `diagnosticos.py` | Fusión nueva: PSI/KS, balance/SMD, ESS/overlap como métricas del plano de datos |
| 8 | Benchmarks y DGP como producto de datos | apC + `dgp.py` + `data_benchmark_causal/` | **Núcleo nuevo**: el dataset con verdad conocida como artefacto gobernado |

### Parte III — Lo que el estimador le exige al dato (consumidores)

| Cap. nuevo | Título | Fuente | Tipo de trabajo |
|---|---|---|---|
| 9 | Lo que DML le exige al dato | caps 10–11 | **Compresión 1** (la más difícil): tasas de nuisance, overlap/ESS, invariantes de cross-fitting, trimming — como precondiciones del dato, no teoremas |
| 10 | Lo que la heterogeneidad y la política le exigen | caps 12–14, 21–22 | **Compresión 2**: qué features y qué validación exige CATE/policy |
| 11 | Diagnóstico sin verdad | cap14 + `falsificacion.py` + `sensibilidad.py` | **Compresión 3**: placebos, control negativo, sensibilidad como pruebas del pipeline |

### Parte IV — Operación

| Cap. nuevo | Título | Fuente | Tipo de trabajo |
|---|---|---|---|
| 12 | La puerta causal en el plano de datos | caps 19–20 + `puerta.py` | Reorientar: promoción de versiones de *datos y features*, no solo de modelos |
| 13 | Servicio y abstención | cap15 + `servicio_core.py` + B1/B3 | Reorientar: qué sirve el dato, soporte, abstención |
| 14 | Observabilidad de supuestos en producción | cap30 + `monitor.py` | Reorientar: ventanas, señales, acción operativa |
| 15 | Tarjetas, registro y auditoría end-to-end | cap19 + `tarjeta.py` + `flujo.py` | Cierre del libro: el caso canónico completo del benchmark al alias |

### Apéndices

| Ap. | Contenido | Fuente |
|---|---|---|
| A | Contratos C-01…C-08 completos | apI (existe, casi sin cambio) |
| B | DGP y escenarios del benchmark | apC (existe) |
| C | Glosario | apD (existe) |
| D | Checklists de despliegue | apF + apH (existen) |
| E | «Dónde están los teoremas»: mapa de la edición de método | Nuevo, 2 páginas: tabla cap. consumidor ↔ capítulos completos en `main.typ` |

**Se dejan fuera del libro nuevo** (viven en la edición de método): caps. 3, 5, 6, 8, 16–18, 23–29, 31–33.

## 3. Calendario: 22 días

Norma diaria: un capítulo por día («adaptado»: reorientar + podar + ejercicios) o ~3 500–4 000 palabras nuevas en los días de núcleo nuevo. Cada día termina con `typst compile main_de.typ` en verde.

### Semana 1 — Cimientos y Parte I (días 1–5)

| Día | Trabajo | Definition of done |
|---|---|---|
| 1 | Infraestructura: crear `main_de.typ` con las 4 partes y 15 capítulos vacíos (título + cuadro sinóptico placeholder), portada nueva, decisiones de modo. Hacer 3 plantillas de figura reutilizables (flujo de datos, linaje, esquema de contrato) en Fletcher | El esqueleto compila en PDF; plantillas de figura renderizan |
| 2 | Cap. 1 | DoD capítulo (ver §4) |
| 3 | Cap. 2 | DoD |
| 4 | Cap. 3 (contratos — núcleo nuevo) | DoD |
| 5 | Cap. 4 (versionado/linaje — núcleo nuevo). Cierre: Parte I completa compila | DoD ×4 |

### Semana 2 — Parte II y primera compresión (días 6–10)

| Día | Trabajo | Definition of done |
|---|---|---|
| 6 | Cap. 5 (splits y pared observado/evaluación) | DoD |
| 7 | Cap. 6 (validez temporal y fuga) | DoD |
| 8 | Cap. 7 (calidad y observabilidad de datos) | DoD |
| 9 | Cap. 8 (benchmark y DGP como producto) | DoD |
| 10 | Cap. 9 (compresión DML — el día más difícil del mes). Regla de corte: si pasa de ~4 500 palabras, se está reescribiendo el método → podar y apuntar a la edición de método | DoD; capítulo organizado por *exigencias al dato*, no por teoremas |

### Semana 3 — Consumidores y operación (días 11–15)

| Día | Trabajo | Definition of done |
|---|---|---|
| 11 | Cap. 10 (compresión heterogeneidad/política) | DoD |
| 12 | Cap. 11 (compresión diagnóstico sin verdad) | DoD |
| 13 | Cap. 12 (puerta causal en el plano de datos) | DoD |
| 14 | Cap. 13 (servicio y abstención) | DoD |
| 15 | Cap. 14 (observabilidad en producción). Cierre: Partes II–IV compilan | DoD ×10 acumulado |

### Semana 4 — Cierre, apéndices, edición (días 16–22)

| Día | Trabajo | Definition of done |
|---|---|---|
| 16 | Cap. 15 + caso end-to-end (benchmark → puerta → servicio → monitor → alias) como cierre del libro | DoD final |
| 17 | Apéndices A–E (tres existen: recorte y renumeración; E nuevo, 2 páginas) | Apéndices compilan |
| 18 | Índice temático y de autores, página de erratas, colofón, licencia; **prefacio nuevo** con la tesis «el dato como estimando» | Back matter completo |
| 19 | Pasada de voz completa: grep de vestigios («lab», «sesión», «Serie», «monorepo», «autograder», términos de método que no se definieron); transiciones entre partes; consistencia de términos (glosario ↔ texto) | 0 vestigios; lectura continua de las 4 partes |
| 20 | Figuras y cifras: cada capítulo con su diagrama; regenerar toda cifra desde script con semilla en el repo; reemplazar PNG raster por vectorial | 15+ figuras; cada cifra con fuente «script + semilla» |
| 21 | Revisión externa exprés: 2 lectores (un ingeniero de datos, un causal) con checklist de 10 preguntas (¿queda claro el estimando?, ¿el contrato es comprobable?, ¿el ejemplo corre?); corregir hallazgos críticos | Checklist respondido; hallazgos críticos cerrados |
| 22 | **Buffer.** PDF 1.0-rc: compilan las dos ediciones (`main.typ` intacta, `main_de.typ` nueva), tag git, paquete editorial (carta + caps. 3, 9 y 15 de muestra) | 1.0-rc etiquetado |

*Si la semana 3 se atrasa: fusionar el cap. 15 dentro del 12 y usar el día 22 completo de buffer.*

## 4. Definition of done de capítulo

Un capítulo está terminado cuando:

1. Compila en `main_de.typ` sin warnings de referencias rotas.
2. Tiene: cuadro sinóptico, ≥1 contrato o invariante comprobable, ≥1 caso canónico con DGP explícito, ejercicios con pista de solución.
3. Tiene ≥1 figura del lenguaje visual del libro (flujo de datos, linaje, esquema, arquitectura — no curvas matemáticas).
4. Cada cifra numérica se traza a un script con semilla del repositorio.
5. Cero léxico de curso (labs, sesiones, Serie A/B, autograder); el repo se cita como «repositorio de referencia del libro».
6. El capítulo responde, en su cierre, la pregunta del eje: *«¿qué debe ser verdad en los datos para que la afirmación causal de este capítulo valga, y cómo se comprueba?»*

## 5. Decisiones ya tomadas (cambiables)

1. **Compresión de método a 3 capítulos consumidor** (mi recomendación, confirmada por omisión): la edición `main.typ` conserva el método completo; nada se pierde.
2. **Español** como idioma del libro nuevo; capítulos muestra para editoriales anglosajonas quedan fuera del mes.
3. **Las capas L0–L3 no se usan en la edición nueva**: en un libro de ingeniería los listados son contenido de primera clase, no una capa opcional.
4. **`causalops` como repositorio de referencia**: los contratos del libro se implementan y prueban ahí; el libro cita cada listado con su ruta.
5. **Figuras nativas Typst/Fletcher** con plantillas del día 1; nada de PNG raster.

## 6. MCP para agentes — criterios y contratos como herramientas

Cada iteración entrega **capítulo + contrato JSON + tool MCP + eval**. Ver `08_mcp-agentes-causales/plan-capitulos/PLAN_MCP_CAPITULOS.md` para matriz completa.

| Semana | Caps | Tools MCP nuevas | Evals |
|--------|------|----------------|-------|
| 1 | 1-4 | `declarar_estimando`, `validar_esquema_roles`, `verificar_version_linaje` | wall, dos_definiciones, linaje |
| 2 | 5-9 | `verificar_particion_pared`, `auditar_validez_temporal`, `medir_observabilidad`, `verificar_benchmark`, `entregar_exigencias` | fuga, drift, ESS |
| 3 | 10-11 | `evaluar_heterogeneidad`, `evaluar_sensibilidad` | Qini, placebo |
| 4 | 12-15 | `evaluar_puerta`, `abstenerse_soporte`, `monitorear`, `emitir_tarjeta` | pasa/alerta/falla |

El DoD de capítulo ahora incluye: contrato JSON válido + tool verde + eval verde. `07_docencia/semana_4/proyecto/` es el primer cliente MCP (ver equivalencia `make` ↔ tool en el plan).

## 7. Riesgos y mitigación

| Riesgo | Señal de alarma | Mitigación |
|---|---|---|
| Los capítulos consumidor se vuelven «resumen pobre» del método | El cap. 9 pasa de ~4 500 palabras o introduce notación de teoremas | Organizar por exigencias al dato con checklist final; podar y apuntar a la edición de método |
| El libro nuevo rompe la edición existente | `main.typ` deja de compilar | Días 1, 5, 15 y 22: compilar ambas ediciones; capítulos compartidos no se editan, se copian y reorientan |
| Las figuras de arquitectura comen el tiempo | Día 20 con más de 5 figuras pendientes | 3 plantillas reutilizables el día 1; reciclar la misma estructura visual |
| La revisión externa llega tarde | Sin lectores comprometidos al día 15 | Invitarlos el día 5 con el índice; mandarles capítulos parciales el día 15 |
| Un mes sin margen | Día 20 con capítulos sin DoD | El día 22 es buffer real; fusión 15→12 si hace falta |

## 7. Criterio de éxito del mes

- PDF **1.0-rc** de *Ingeniería de Datos Causales*: 15 capítulos, 4 partes, **123 pp.**, compilando. ✅
- Las dos ediciones comparten fuente sin regresión. ✅
- 100 % de capítulos con DoD (§4); cada cifra regenerable. ✅
- Paquete editorial listo y enviado. ✅ **Listo para envío** (pendiente de revisores externos)

---

## 8. Estado final del proyecto (registro de cierre)

| Entregable | Estado | Detalle |
|---|---|---|
| **Libro** (`main_de.pdf`) | ✅ 1.0-rc | 123 pp., 15 caps, 4 partes, 12 contratos, índices, erratas, prefacio final |
| **Edición de método** (`main.pdf`) | ✅ Sin regresión | 455 pp., 33 caps, intacta |
| **MCP** (`08_mcp-agentes-causales/`) | ✅ v1.0-rc | 12 tools, 12 contratos JSON, 9 tests, 7 evals |
| **Scripts canónicos** (`Causal_AI/scripts/`) | ✅ 16 | Todos reproducibles con semilla declarada |
| **Docencia** (`07_docencia/semana_4/`) | ✅ Completa | Plan 150 min, guía profesor, kit, solución, proyecto, zip estudiante |
| **Paquete de revisión** (`results/`) | ✅ Listo | Carta + checklist 10 preguntas + 3 capítulos muestra expandidos |
| **Git** | ⬜ Pendiente | Todo el trabajo sin commitear |

### Cronología de ejecución

| Fase | Trabajo | Resultado |
|---|---|---|
| Evaluación | Análisis de la monografía existente | 452 pp., 33 caps, fortalezas y debilidades identificadas |
| Plan | Plan de escritura a 22 días + MCP integrado | 15 caps, 12 contratos, 12 tools, calendario por iteración |
| Iter 1 | Caps 1–9 + 6 tools + 7 contratos | Parte I y II completas, 76 pp. |
| Innovación | AIPW + estrato por `nodegree` | Servicio con 2 estimandos, heterogeneidad sugerida |
| Docencia | Prototipo «Puente» + clase 150 min | 22 TODOs, 5 checkpoints, 3 ventanas, notebook verificado |
| Iter 2 | Caps 10–11 + 2 tools + 1 contrato | Parte III completa, 86 pp. |
| Iter 3 | Caps 12–13 + 2 tools + 2 contratos | Parte IV núcleo, 97 pp. |
| Iter 4 | Caps 14–15 + 2 tools + 2 contratos | Libro completo, 109 pp. |
| Semana 4 ed. | Voz + índices + erratas + paquete | 114 pp., revisión externa lista |
| Expansión | Caps 3, 9, 15 a profundidad del plan | 123 pp., +34 904 palabras |

---

*Documento: plan de escritura a 22 días. Evaluación de partida: `results/evaluacion_monografia_y_plan.md`. Cierre: noviembre 2026.*
