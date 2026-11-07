# CHECKPOINT — mcp-v2

**Fecha:** 2026-11-07
**Rama:** `mcp-v2`
**Commit base:** `e4682ef` (main)
**Estado:** P0–P5 completados, P6 parcial, P7 pendiente

## Completado

- [x] P0: Descubrimiento (rama creada, inventario, baseline)
- [x] P1: Núcleo (models.py tipado, projects.py SQLite, aislamiento, persistencia, path security A19)
- [x] P2: Contratos (validators.py con validación real, NaN/inf no pass, Gamma dominio >=1)
- [x] P3: Conocimiento (24 fichas, búsqueda léxica, contar/listar)
- [x] P4: MCP (server.py con 11 tools, 2 resources, 2 prompts)
- [x] P5: Referencia (estimators.py AIPW+DGP, e2e_reference.py)
- [ ] P6: Producción (Dockerfile y cloud_adapter.md creados, falta probar Docker)
- [ ] P7: Cierre (falta docs finales, commit, limpieza ZIP)

## Tests

```
40 passed en 0.77s (tests/test_acceptance.py)
```

## Estructura creada

```
08_mcp-agentes-causales/
├── src/mcp_causal/
│   ├── __init__.py     (v2.0.0)
│   ├── models.py       (tipos: DeclaracionCausal, Supuesto, ResultadoVerificacion, etc.)
│   ├── projects.py     (SQLite: ProjectStore, aislamiento, invalidación, path security)
│   ├── validators.py   (C-01..C-15: validadores reales)
│   ├── knowledge.py    (24 fichas, búsqueda léxica)
│   ├── estimators.py   (AIPW cross-fitting, DGP sintético)
│   ├── cli.py          (buscar, ficha, listar, proyecto, serve)
│   └── server.py       (MCP: 11 tools, 2 resources, 2 prompts)
├── tests/
│   └── test_acceptance.py (A01-A24: 40 tests)
├── examples/
│   └── e2e_reference.py
├── deploy/
│   ├── Dockerfile
│   └── cloud_adapter.md
├── pyproject.toml      (instalable con pip install -e .)
└── (docs/development/ pendiente)
```

## Próxima acción si se corta

1. `cd 08_mcp-agentes-causales && python3 -m pytest tests/test_acceptance.py -v`
2. Completar P7: crear `docs/development/FINAL_REPORT.md`
3. Commit de la rama mcp-v2
4. Verificar y borrar el ZIP según 07_CIERRE.md

## Comandos para reanudar

```bash
cd 08_mcp-agentes-causales
pip install -e ".[test]"
python3 -m pytest tests/test_acceptance.py -v
python3 examples/e2e_reference.py
python3 -m mcp_causal.cli --help
python3 -m mcp_causal.cli buscar "estimando"
```

## Limitaciones conocidas

- Docker no probado en esta VM (A21: marcar como limitación, no simular)
- Despliegue en nube no verificado (A22: CLOUD_UNVERIFIED)
- Cliente MCP real vía stdio no probado con proceso hijo (A15 parcial)
- Solo ATE implementado; ATT/CATE/IV/DiD/RD como fichas de conocimiento sin estimador
