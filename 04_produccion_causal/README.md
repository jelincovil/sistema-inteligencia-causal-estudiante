# Producción causal local

Serie B convierte los artefactos de Serie A en un flujo local: estimador/servicio B1, tarjeta y esquema B2, política B3 y monitor B4. Todo corre sin nube y sin credenciales.

## Orden de trabajo

1. Ejecuta A2 y A4 o construye artefactos equivalentes con datos observados.
2. Valida el esquema y la tarjeta causal en B2.
3. Levanta el servicio local de B1 o B3 con los artefactos que hayas generado.
4. Ejecuta B4 para separar señal de hipótesis y registrar una acción de revisión.

Los directorios `artifacts/` y `reports/` son puntos de salida; los artefactos precalculados y los autograders docentes se excluyen. La disponibilidad de un endpoint no demuestra identificación causal: declara estimando, población, incertidumbre y supuestos en tu tarjeta.

Usa Python 3.11 o superior, igual que declara `pyproject.toml`: NumPy 2.4.2 y SciPy 1.17.0 también exigen Python 3.11 o superior, y la imagen de B1 usa Python 3.11. En un entorno con varios intérpretes, indica explícitamente cuál usar con `PY=/ruta/a/python`.

Desde `04_produccion_causal/` puedes comprobar la ruta pública:

```bash
make test    # pruebas ejecutables de puertas, abstención y monitoreo
make validate
make test PY=/ruta/a/python  # alternativa para seleccionar Python >= 3.11
make demo     # genera artefactos locales ignorados y prueba pasa/bloquea/abstención
make monitor  # genera ventanas de monitoreo en B4/reports/
```

| Componente | Entrada del estudiante | Salida |
|---|---|---|
| B1 | estimador A2 y contrato de datos | respuesta ATE/IC o abstención |
| B2 | tarjeta causal y esquema | validación estructural |
| B3 | scores CATE/política A4 | decisión bajo presupuesto |
| B4 | ventanas observadas | señal, hipótesis y acción de revisión |

Consulta el README de cada subdirectorio para sus comandos locales. No uses `truth` para entrenar, servir o decidir.
