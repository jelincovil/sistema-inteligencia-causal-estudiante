# Casos canónicos del libro — edición de ingeniería de datos

Cada script regenera una tabla o cifra que aparece en un capítulo de
`main_de.typ`. Todos son deterministas: la semilla está declarada en el
propio script y en el capítulo que cita la cifra.

Ejecutar desde la raíz del repositorio:

```bash
python3 "02_causal AI en produccion/Causal_AI/scripts/cap01_simpson.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap02_traza.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap03_dos_definiciones.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap03_contrato.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap04_linaje.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap05_splits.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap06_fuga.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap07_calidad.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap08_benchmark.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap09_exigencias.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap10_heterogeneidad.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap11_diagnostico.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap12_puerta.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap13_servicio.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap14_monitor.py"
python3 "02_causal AI en produccion/Causal_AI/scripts/cap15_tarjeta.py"
```

| Script | Capítulo | Tabla que regenera |
|---|---|---|
| `cap01_simpson.py` | 1 | Reversión de Simpson (éxito agregado vs estratificado) |
| `cap02_traza.py` | 2 | Traza del escenario `real/jobs` a través del sistema |
| `cap03_dos_definiciones.py` | 3 | Dos análisis, dos definiciones de X (1,00 vs 1,50) |
| `cap03_contrato.py` | 3 | Validación del contrato C-01 (pasa / falla) |
| `cap04_linaje.py` | 4 | Registro, hashes y promoción `champion` |
| `cap05_splits.py` | 5 | Particiones sembradas y fuga por selección en test |
| `cap06_fuga.py` | 6 | Cuatro tipos de feature y una verdad conocida |
| `cap07_calidad.py` | 7 | Balance (t-test vs Holm), PSI/KS sobre edad real, faltantes diferenciales |
| `cap08_benchmark.py` | 8 | Los cinco escenarios declarados del benchmark |
| `cap09_exigencias.py` | 9 | Fuga entre folds (DGP canónico), ESS/trimming, doble robustez |
| `cap10_heterogeneidad.py` | 10 | Heterogeneidad S/T, Qini y valor IPW OOS |
| `cap11_diagnostico.py` | 11 | Placebo 500 perms, control negativo, sensibilidad Gamma |
| `cap12_puerta.py` | 12 | Tres versiones → pasa / alerta / falla |
| `cap13_servicio.py` | 13 | Respuesta dentro del soporte, abstención fuera, determinismo |
| `cap14_monitor.py` | 14 | Cuatro señales del monitoreo: cada cambio enciende la suya |
| `cap15_tarjeta.py` | 15 | Traza end-to-end: pregunta → esquema → … → champion → servicio |

Dependencias: `numpy` y biblioteca estándar. Sin `pandas`, sin `sklearn`.
