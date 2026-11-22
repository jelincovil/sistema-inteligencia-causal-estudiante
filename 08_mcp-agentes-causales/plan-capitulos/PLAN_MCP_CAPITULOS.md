# Planificación MCP Capítulo por Capítulo

**Objetivo:** cada iteración (día/capítulo) entrega **capítulo Typst + contrato JSON + tool MCP + eval**. El libro y el servidor crecen juntos. Sin capítulo verde, no hay tool.

## Matriz completa (15 capítulos + iteración 0)

| Iter | Capítulo (libro) | Contratos/Criterios que estrena | Tool MCP nueva | Eval/DGP |
|------|------------------|----------------------------------|----------------|----------|
| 0 | Infraestructura | — | `mcp init`, `health` | `wall_intact` |
| 1 | 1. Causalidad elemental | Q-01 (estimando) | `declarar_estimando` | Simpsons reversal |
| 2 | 2. Anatomía del sistema | Q-01+Q-08, 5 acciones | `resolver_accion` | pipeline trace |
| 3 | **3. Contratos de datos** | **C-01, Q-01** | `validar_esquema_roles` | `dos_definiciones` (1.00 vs 1.50) |
| 4 | **4. Versionado y linaje** | **C-09, Q-08** | `verificar_version_linaje` | hash + champion |
| 5 | **5. Splits y pared** | **C-10, Q-05** | `verificar_particion_pared` | selección en test (R² 0.0109) |
| 6 | **6. Validez temporal** | **C-03, Q-03** | `auditar_validez_temporal` | fuga 1.00→0.00 |
| 7 | **7. Calidad/observabilidad** | **C-02, Q-04** | `medir_observabilidad` (PSI/SMD/ESS) | drift + faltantes 9.6x |
| 8 | **8. Benchmark como producto** | **C-11** | `verificar_benchmark_producto` | 5 escenarios, pared 0 truth |
| 9 | **9. Lo que DML exige** | **C-12** | `entregar_exigencias_estimador` | ESS 85→trimming, cross-fit |
| 10 | 10. Heterogeneidad/política | C-12 ext, Q-04 | `evaluar_heterogeneidad_policy` | Qini/Uplift |
| 11 | 11. Diagnóstico sin verdad | C-08 | `evaluar_sensibilidad` | Rosenbaum, placebo |
| **12** | **12. Puerta causal** | **C-06, Q-06** | **`evaluar_puerta_causal`** | **pasa/alerta/falla** |
| **13** | **13. Servicio y abstención** | **C-04, Q-07** | **`abstenerse_soporte`** | **1 soporte, 0 número** |
| **14** | **14. Observabilidad en prod** | **C-07, Q-06** | **`monitorear_produccion`** | **4 señales** |
| **15** | **15. Tarjetas y auditoría** | **C-05, Q-02** | **`emitir_tarjeta`** | **traza 9 pasos** |

> **Bold** = ya escrito en `main_de.pdf` (caps 1-9). Resto integrado en el calendario revisado.

## Calendario revisado — Plan de 1 mes (22 días + MCP)

Norma: **Typst verde + JSON válido + tool verde + eval verde** cada día.

### Semana 1 — Cimientos y Parte I (días 1–5)

| Día | Cap | Entrega libro | Entrega MCP |
|-----|-----|---------------|-------------|
| 1 | Infra + 3 plantillas Fletcher | `main_de.typ` base compila | `server/` scaffold, `health`, `wall_intact` |
| 2 | 01 Causalidad | cuadro + caso Simpson | `declarar_estimando` |
| 3 | 02 Anatomía | Fig. 2 planos + 5 acciones | `resolver_accion` |
| 4 | 03 Contratos C-01 | **C-01 caja** | `validar_esquema_roles` + `contratos/C-01.json` |
| 5 | 04 Linaje C-09 | C-09 caja + linaje | `verificar_version_linaje` + `C-09.json` |

DoD S1: Parte I compila (54pp) + 4 tools con test.

### Semana 2 — Pipeline que preserva identificación (días 6–10)

| Día | Cap | Entrega libro | Entrega MCP |
|-----|-----|---------------|-------------|
| 6 | 05 Splits C-10 | C-10 + pared | `verificar_particion_pared` |
| 7 | 06 Temporal C-03 | C-03 + as-of | `auditar_validez_temporal` |
| 8 | 07 Calidad C-02 | C-02 + PSI/SMD/ESS | `medir_observabilidad` |
| 9 | 08 Benchmark C-11 | C-11 + 5 escenarios | `verificar_benchmark_producto` |
| 10 | 09 DML C-12 | C-12 + ESS/trimming | `entregar_exigencias_estimador` |

DoD S2: `main_de.pdf` 76pp + 9 tools. **El agente ya no puede desplegar sin estimando ni linaje.**

### Semana 3 — Consumers + Operación núcleo (días 11–15)

| Día | Cap | Entrega libro | Entrega MCP |
|-----|-----|---------------|-------------|
| 11 | 10 Heterogeneidad | Qini, CATE como precondición | `evaluar_heterogeneidad_policy` |
| 12 | 11 Sin verdad | Placebo, control negativo | `evaluar_sensibilidad` |
| 13 | 12 Puerta causal | C-06 mini | `evaluar_puerta_causal` |
| 14 | 13 Servicio | C-04 + abstención | `abstenerse_soporte` |
| 15 | 14 Monitor | C-07 + ventanas | `monitorear_produccion` |

DoD S3: Parte III+IV compila + puerta operativa.

### Semana 4 — Cierre y edición (días 16–22)

| Día | Cap | Entrega libro | Entrega MCP |
|-----|-----|---------------|-------------|
| 16 | 15 Tarjetas | C-05+C-08 + E2E | `emitir_tarjeta` |
| 17 | Apéndices A-E | C-01..C-12 tabla | JSONs 12/12 validados |
| 18 | Prefacio, índices | Back matter | Prompts 12/12 |
| 19 | Voz | 0 vestigios curso | Integration test E2E (agente recorre 15 caps) |
| 20 | Figuras/cifras | 15+ fletcher | Demo: agente intenta deploy sin estimando → bloqueado |
| 21 | Revisión externa | 2 lectores checklist | 2 agentes externos prueban MCP |
| 22 | Buffer | **1.0-rc** | `mcp-causal v1.0-rc` tag |

## Iteración corta (2 caps/semana acordada)

Si sólo 2 caps/semana reales, cada iteración entrega **2 caps + 2 tools**. Orden MCP preservado:

- Iter 1 (esta): caps 1-9 → tools 1-9 ✅ (hecho)
- Iter 2: caps 10-11 → sensibilidad/heterogeneidad ✅ (hecho)
- Iter 3: caps 12-13 → puerta/servicio ✅ (hecho)
- Iter 4: caps 14-15 → monitor/tarjeta + 1.0-rc ✅ (hecho — libro completo)

## Conexión con docencia (semana_4)

`07_docencia/semana_4/proyecto/` ya es el **primer cliente** del MCP: el `make` de cada bloque equivale a una tool:

```
make verificar  → validar_esquema_roles + verificar_particion_pared
make estimar    → entregar_exigencias_estimador + auditar_validez_temporal
make registrar  → verificar_version_linaje
make ventanas   → medir_observabilidad + evaluar_puerta_causal
make humo       → abstenerse_soporte
```

Próxima iteración: el notebook del proyecto llamará al MCP local vía `stdio`.
