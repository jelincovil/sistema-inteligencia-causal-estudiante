# Contratos de Construcción Causal — C-01 a C-12

> En un sistema de decisión, el trabajo del dato no es llegar con calidad: es preservar la identificación.

Cada contrato tiene: `operaciones`, `entrada`, `salida`, `invariantes`, `modos de fallo`, `prueba de aceptación`.

## Índice (8 + 4 nuevos para agentes)

| Contrato | Nombre | Capítulo origen | Estado en libro |
|----------|--------|-----------------|-----------------|
| C-01 | Esquema de roles causales | 3 | ✅ escrito |
| C-02 | Comparación de poblaciones | 7 | ✅ escrito |
| C-03 | Auditoría de features temporal | 6 | ✅ escrito |
| C-04 | Servicio con abstención | 13 | ✅ escrito |
| C-05 | Tarjeta causal (Model Card) | 15 | ✅ escrito |
| C-06 | Puerta causal de registro | 12 | ✅ escrito |
| C-07 | Monitor causal | 14 | ✅ escrito |
| C-08 | Sensibilidad no observable | 11 | ✅ escrito |
| C-09 | Versionado, linaje, champion | 4 | ✅ escrito |
| C-10 | Partición y pared evaluación | 5 | ✅ escrito |
| C-11 | Benchmark como producto | 8 | ✅ escrito |
| C-12 | Exigencias del estimador | 9 | ✅ escrito |

## Esquema JSON de un contrato (para el MCP)

`contratos/schemas/contrato.schema.json` define:

```json
{
  "id": "C-03",
  "titulo": "Auditoría de features",
  "operaciones": ["auditar", "extraer"],
  "entrada": {"features": "con rol y timestamp por unidad"},
  "invariantes": ["...", "..."],
  "falos": ["..."],
  "aceptacion": ["exigencias reproducibles con semilla"]
}
```

Cada contrato en `contratos/C-0X.json` es validable y es prompt para el agente.

## Prompts de agente por contrato

El MCP no sólo valida; guía. Ejemplo `C-03`:

> Antes de añadir una feature, responde: ¿cuándo se midió? ¿Cuál es su rol causal? Si no puedes probarlo pre-tratamiento → no entra. Registra ambas especificaciones.

Ver `contratos/prompts/` para los 12 prompts.

## DoD de un contrato (para la planificación por capítulo)

Un contrato está DONE cuando:
1. Tipst del capítulo compila con su caja `contrato(...)`
2. JSON en `contratos/C-XX.json` valido contra schema
3. Tool MCP correspondiente implementada con test verde
4. Caso canónico script con semilla + cifra en el libro
5. Eval con DGP que castiga la violación
