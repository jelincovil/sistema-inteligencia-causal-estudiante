# MCP Causal — Servidor de Criterios de Calidad y Contratos de Construcción

**Para agentes que construyen sistemas causales y ML productivo.**

Este MCP expone los contratos C-01…C-12 del libro *Ingeniería de Datos Causales* como herramientas verificables. Cualquier agente (Claude, Cursor, VS Code, Codex) conectado **no puede proponer un estimador, una feature o un deploy sin pasar la puerta**.

## Filosofía

> El estimando no se descubre en los datos: se declara antes de mirar.
> Un contrato no es documentación: es prueba de aceptación ejecutable.

El MCP implementa 3 capas:

1. **Criterios de calidad (Quality Gates)** — ¿el sistema puede afirmar causalidad?
2. **Contratos de construcción (Build Contracts)** — ¿cómo se construye sin romper identificación?
3. **Evals** — escenarios sintéticos con verdad conocida que no perdonan.

## Arquitectura MCP

```
08_mcp-agentes-causales/
├── criterios/           # Criterios de calidad Q-01..Q-08
├── contratos/           # Contratos C-01..C-12 como JSON Schema + prompts
├── server/              # Servidor MCP (FastMCP/TS)
├── plan-capitulos/      # Planificación capítulo a capítulo
└── evals/               # Escenarios con verdad (como tests)
```

### Tools expuestas

| Tool | Contrato origen | Qué valida |
|------|----------------|------------|
| `declarar_estimando` | Q-01 / C-01 | ATE/ATT/CATE, población, supuestos declarados antes de mirar |
| `validar_esquema_roles` | C-01 | Cada columna un solo rol (Y, D, X, Z, timestamp) |
| `auditar_validez_temporal` | C-03 | Ninguna feature mira el futuro |
| `verificar_version_linaje` | C-09 | Hash, semilla, split inmutable, alias champion |
| `verificar_particion_pared` | C-10 | Semilla, cobertura, `truth` nunca en `observed` |
| `verificar_benchmark_producto` | C-11 | DGP versionado, régimen de pared |
| `entregar_exigencias_estimador` | C-12 | Cross-fitting OOS, ESS, trimming declarado |
| `evaluar_puerta_causal` | C-06 / Q-06 | Tres señales → pasa/alerta/falla; solo pasa promueve champion |
| `abstenerse_soporte` | C-04 / Q-07 | Fuera de soporte → abstención sin número |
| `evaluar_heterogeneidad_policy` | C-12 ext / Q-04 | Qini OOS y valor IPW vs aleatorio |
| `evaluar_sensibilidad` | C-08 / Q-02 | Placebo, control negativo y Gamma* |
| `monitorear_produccion` | C-07 / Q-06 | Cuatro señales → orden de preguntas → una acción |
| `emitir_tarjeta` | C-05 / Q-02+Q-08 | Construye y valida la tarjeta causal |
| `auditar_equidad` | C-13 / Q-02+Q-04 | Compara efectos por grupo protegido y mide la brecha |
| `declarar_poblacion_excluida` | C-14 / Q-02+Q-07 | Cuantifica y declara quién queda fuera del soporte |
| `evaluar_impacto_dano` | C-15 / Q-02+Q-07 | Estima el daño si el efecto es incorrecto |

**15 tools · 15 contratos · 15 capítulos.**
| `emitir_tarjeta` | Q-08 / C-05 | Model Card computable, sin `truth` en el bundle |

Ver `server/README.md` para instalación y prueba local.

## Uso por agentes

El agente conectado **debe** llamar `declarar_estimando` como primera herramienta. Sin estimando declarado, todas las demás tools devuelven `PRECONDITION_FAILED`.

Esto replica la regla del libro: *primero el estimando, luego el dato*.
