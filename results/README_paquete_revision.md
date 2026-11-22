# Paquete de revisión externa — *Ingeniería de Datos Causales* 1.0-rc

## Contenido del paquete

| Archivo | Qué es |
|---|---|
| [carta_presentacion.md](carta_presentacion.md) | Posicionamiento y solicitud al revisor |
| [checklist_revision_externa.md](checklist_revision_externa.md) | 10 preguntas, ~90 min, sobre los capítulos muestra |
| [capitulos_muestra/cap03_contratos_datos_causales.pdf](capitulos_muestra/cap03_contratos_datos_causales.pdf) | Cap. 3 — el primer contrato (C-01) con su prueba de aceptación |
| [capitulos_muestra/cap09_lo_que_dml_exige.pdf](capitulos_muestra/cap09_lo_que_dml_exige.pdf) | Cap. 9 — la compresión de DML a exigencias del dato |
| [capitulos_muestra/cap15_tarjeta_end_to_end.pdf](capitulos_muestra/cap15_tarjeta_end_to_end.pdf) | Cap. 15 — la corrida end-to-end de 9 pasos auditables |
| `../02_causal AI en produccion/Causal_AI/main_de.pdf` | El libro completo (114 pp., 15 caps, 4 partes) |
| `../02_causal AI en produccion/Causal_AI/scripts/` | Los 16 scripts canónicos reproducibles con semilla |
| `../08_mcp-agentes-causales/` | El servidor MCP con 12 tools y 12 contratos |

## Cómo usar el paquete

1. **Lea la carta** (5 min) — posicionamiento y qué se pide.
2. **Haga el checklist** (90 min) — las 10 preguntas sobre los tres capítulos muestra.
3. **Si quiere ampliar** — el PDF completo está en `main_de.pdf` y los scripts se ejecutan con `python3 scripts/capXX_*.py`.

## Qué se pide del revisor

- **Honestidad:** si algo no convence, decirlo.
- **Concreción:** señalar dónde exactamente (página, sección, cifra).
- **Accionabilidad:** qué cambiaría antes de publicar.

## Estado del libro

- 15 capítulos compilando, 114 páginas, 0 errores.
- 12 contratos JSON válidos contra schema.
- 12 tools MCP con 9 tests verdes.
- 16 scripts canónicos reproducibles con semilla.
- 7 evals con DGP que castiga violaciones.
- Validador del repo estudiantil en verde.
