# Roadmap MCP ↔ Libro — entrega incremental

Este archivo es la única fuente de verdad de qué tool corresponde a qué capítulo y qué semana.

```
Iter 1 (caps 1-9)  : 6 tools + 7 contratos JSON → mcp-causal v0.1 ✅ hecho
Iter 2 (caps 10-11): +2 tools + 1 contrato (C-08) → mcp-causal v0.2 ✅ hecho
Iter 3 (caps 12-13): +2 tools + 2 contratos (C-06, C-04) → mcp-causal v0.3 ✅ hecho
Iter 4 (caps 14-15): +2 tools + 2 contratos (C-07, C-05) → mcp-causal v1.0-rc ✅ hecho
Iter 5 (ética)     : +3 tools + 3 contratos (C-13, C-14, C-15) → mcp-causal v1.1 ✅ hecho
```

**15 contratos · 15 tools · 15 capítulos · 14 tests.**

Regla: **no se publica tool sin capítulo verde**. El capítulo es la especificación; el JSON es el contrato; la tool es la implementación.

## Estado final (v1.0-rc)

- [x] 15 capítulos compilando (109 pp.)
- [x] 12 contratos JSON válidos contra schema
- [x] 12 tools MCP con 9 tests verdes
- [x] 15 scripts canónicos reproducibles con semilla
- [x] 7 evals con DGP que castiga violaciones
- [x] Semana 4 de docencia como primer cliente del MCP

## Próximos pasos (post-1.0-rc)

- [ ] Pasada editorial de voz (día 19 del plan)
- [ ] Índice temático y de autores (día 18)
- [ ] Revisión externa: 2 lectores + 2 agentes (día 21)
- [ ] Paquete editorial (día 22)
- [ ] Publicar mcp-causal en catálogo MCP

## Cómo contribuir (agentes externos)

1. Lee `criterios/Q-criterios.md` y `contratos/README.md`
2. Elige un contrato sin JSON o sin tool
3. PR debe incluir: JSON válido + tool + test con DGP con verdad + cifra del libro
