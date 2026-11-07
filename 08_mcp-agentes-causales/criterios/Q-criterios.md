# Criterios de Calidad Causal — Q-01 a Q-08

Criterios transversales. Cada capítulo del libro añade criterios; el MCP los hace ejecutables como `quality_gate`.

Los 8 criterios base (alineados con rúbrica del proyecto final):

| ID | Criterio | Pregunta que hace el agente | Falla si |
|----|----------|-----------------------------|----------|
| Q-01 | **Estimando declarado** | ¿Qué compara? ¿ATE, ATT, CATE? ¿Población? | El agente propone modelo sin decir `estimando` y `poblacion` |
| Q-02 | **Supuestos clasificados** | ¿Observable vs no_observable? | `no_observable` figura como verificado |
| Q-03 | **Validez temporal** | ¿Cada X es pre-tratamiento verificable? | Feature sin timestamp o post-tratamiento entra |
| Q-04 | **Soporte y overlap** | ¿Hay con quién comparar? | ESS/n < umbral o `e_hat` en [0,05,0,95] < 50% sin trimming declarado |
| Q-05 | **Partición honesta** | ¿El estimando se evaluó sin mirar la prueba? | Selección sobre test, wall violada |
| Q-06 | **Puerta causal** | ¿Pasa/Alerta/Falla con motivo? | Deploy con `Falla` o `Alerta` sin aceptación explícita |
| Q-07 | **Abstención** | ¿El servicio sabe no responder? | Fuera de soporte devuelve número |
| Q-08 | **Linaje y reproducibilidad** | ¿Puedo reconstruir el resultado? | Sin hash, semilla, versión, manifest |

## Mapeo a contratos

```
Q-01 ← C-01 + C-05
Q-02 ← C-05 + C-08
Q-03 ← C-03
Q-04 ← C-02 + C-12
Q-05 ← C-10
Q-06 ← C-06 + C-07
Q-07 ← C-04
Q-08 ← C-09
```

## Implementación MCP

Cada criterio es un `tool` que devuelve:

```json
{
  "criterio": "Q-04",
  "estado": "falla",
  "motivo": "ESS/n=0.03, trimming requerido pero no declarado",
  "accion": "abstenerse",
  "evidencia": {"ESS": 85, "trimming": null}
}
```

Todos los estados mapean a las 5 acciones del sistema: `continuar | alertar | revisar_identificacion | abstenerse | reentrenar`.

## Evolución por capítulos

- Cap 1-2: Q-01, Q-08 embrionarios
- Cap 3-4: Q-01 + Q-08 completos
- Cap 5-6: + Q-03, Q-05
- Cap 7-8: + Q-04
- Cap 9-11: + Q-02, Q-06
- Cap 12-15: todos Q-01..Q-08 operativos + monitor continuo
