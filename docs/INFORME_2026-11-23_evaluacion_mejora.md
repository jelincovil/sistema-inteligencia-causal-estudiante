# Informe de evaluación y mejora — repositorio completo (2026-11-23)

Ámbito: raíz del repositorio público del estudiante (`sistema-inteligencia-causal-estudiante-main`), de extremo a extremo: manifiesto de distribución, CI, producción, notebooks, datos, docencia, MCP y el subproyecto Rust `argumentos copy/`.
Este informe **complementa** a `docs/INFORME_EVALUACION_MEJORA.md` (2026-11-22); no lo sustituye ni lo reescribe. Diferencia qué está verificado hoy, qué encontré de nuevo y qué sigue abierto.

## 0. Método y límites del método

- Auditoría de áreas disjuntas por cinco agentes de solo lectura (raíz/CI, datos/notebooks, producción/MCP, docencia/Rust) más verificación directa del motor de distribución. Ningún agente creó, editó, movió ni borró archivos.
- Mejoras directas acotadas a defectos inequívocos; todo lo que roza decisiones del propietario queda documentado, no aplicado.
- **Mem0 no estaba disponible** (`search_memories` devolvió «OAuth authorization required»; no se completó ninguna autorización). La «memoria» efectiva de este repositorio es el propio `docs/INFORME_EVALUACION_MEJORA.md` (pasadas y fallos declarados por la intervención previa) más este informe. Las buenas prácticas citadas abajo son conocimiento general de ingeniería/reproducibilidad, **no** memorias recuperadas de Mem0; cuando Mem0 esté autorizado, conviene repetir la búsqueda («best practices distribución de repo público del estudiante, honestidad de manifiesto, evidencia reproducible») y anexar las memorias específicas de la organización.
- No se hizo commit de nada (regla operativa del repositorio). El estado del índice (12 borrados de tests en staged) se encontró así y se dejó intacto deliberadamente; ver §8.1.
- No se ejecutaron demos, entrenamiento, servicios, builds cargo/Typst ni el runner de aceptación MCP; ver §9.

## 1. Arquitectura y naturaleza del tema

Monorepo educativo de un curso de *causal inference en producción*, con doble lectura:

1. **Distribución pública del estudiante**, definida por `MANIFEST_ESTUDIANTE.json` (125 entradas, `schema: sic.student-manifest.v1`): silabo, notebooks Serie A, producción, proyecto final, `data_benchmark_causal`, `scripts/`, archivos raíz. Excluye por contrato: soluciones, autograders, `truth*`, claves, credenciales y (hoy) los tests del índice.
2. **Material de autoría/teca** también trackeado: fuente Typst del libro (`02_causal AI en produccion/`, `05_contenido_tecnico/`), docencia (`07_docencia/`), servidor MCP (`08_mcp-agentes-causales/`) y el proyecto Rust `argumentos copy/` (espacio en el nombre).
3. **Áreas untracked relevantes**: `07_docencia/laboratorio_cate/` (programa Rust prerregistrado de falsificación experimental, ~7.1 GB, mayormente `target/`), `07_docencia/prototipo_paso_a_paso/` (155 archivos), `08_mcp-agentes-causales/.tmp/` (~153 MB de artefactos de test), `argumentos copy/data/real/lalonde.csv` (pin verificado por SHA-256).

Naturaleza del tema para las mejoras: sistema de **evidencia reproducible y distribución honesta** más que «mejor puntuación». El criterio rector en toda decisión fue: el manifiesto solo declara lo que el árbol realmente contiene; los tests y la evidencia no se presentan como verdes en un commit que los borra; lo que no puede verificarse se declara «no verificable», en línea con `docs/INFORME_EVALUACION_MEJORA.md` §7–§9.

## 2. Estado verificado hoy (re-ejecución)

| Comprobación | Resultado | Comando |
|---|---|---|
| Distribución pública | **OK**, 125/125 existentes, bytes+SHA-256 correctos (tras refrescar registros del manifiesto, §4 tabla #13) | `python3 scripts/validate_student_repo.py` |
| Tests de producción (04) | **54/54 OK** (20 core + 8 B1 + 11 B3 + 15 B4) | `PYTHONPATH=src:B1_servicio_dml:B3_servicio_policy:B4_monitoreo_causal .venv_ci/bin/python -m unittest discover -s <suite>` |
| Compilación de fuentes editadas | OK | `python3 -m py_compile …` |
| JSON del contrato MCP y del manifiesto | `jq empty` OK ambos | — |
| Higiene de diff | `git diff --check` y `--cached` vacíos, exit 0; 0 `__pycache__`/`.pyc` trackeados | — |
| `evidencia/10_cobertura.json` (3 prototipos) | Parsea; números autocontenidos coherentes (IHDP sintético, ilustrativo) | `jq empty` |
| Splits/hashes del benchmark (raíz) | 5 escenarios × 4 JSON OK; sumas `splits.json` ↔ CSV OK (747→448/149/150; 1722→1033/344/345; 2000→1200/400/400; 1000→600/200/200) | `jq`, `shasum -a 256` |
| LaLonde (`argumentos copy/data/real/lalonde.csv`) | 27.509 bytes, SHA-256 `a49703ca…3dd3ef` == pin de `data/real/PROVENANCE.md` | `shasum -a 256` |
| MCP: colección de tests | 94 canonical (en `tests/`) + 14 legacy (en `server/tests/`, invocación separada) | `pytest --collect-only` |

Reproducción del inventario: `03_notebooks_caso_estudio/tests/test_policy_utils.py` existe en el árbol de trabajo pero está staged-deleted del índice; las suites 04 B1/B3/B4 y `argumentos copy/crates/*/tests/` están en el mismo estado. Las suites ejecutadas hoy corren sobre el WT, no sobre el índice: un clon limpio del índice perdería toda la red de tests (§8.1).

## 3. Hallazgos nuevos (esta pasada)

### 3.1 Distribución y gobernanza

- **F-01 (major).** `scripts/validate_student_repo.py` escaneaba **todo el árbol** con `ROOT.rglob("*.ipynb")`: con `laboratorio_cate/` (32.019 archivos) y `argumentos copy/` (29.512 archivos) el check era lento y podía fallar por un `solution.ipynb` en WIP/venvs, no en lo distribuido. → **Corregido** (§4, tabla #1).
- **F-02 (major).** Si `git ls-files` fallaba, el fallback `rglob` ignoraba `.gitignore` y reportaba tests/venvs no trackeados como violaciones, **sin avisar**. → **Corregido**: sin git, el validator verifica solo el manifiesto (autocontenido) y avisa por stderr; la comprobación de rutas prohibidas se omite explícitamente (§4, tabla #1).
- **F-03 (minor).** El manifiesto no validaba `schema`, `notebooks` ni formato `sha256`; `len(serie_a)` duplicaba el declarado. → **Corregido**: `schema == sic.student-manifest.v1` obligatorio; `notebooks` (si presente) debe coincidir con los Serie A reales; SHA-256 debe ser 64-hex minúscula; mensajes de error separados para ausente / symlink roto / no-regular / fuera de raíz (§4, tabla #1).
- **F-04 (minor).** `08_mcp-agentes-causales/.tmp/` (153 MB, ~5.030 archivos: wheel-smoke-venv, mcp_test_*, legacy dist) no estaba cubierto por ninguna regla → riesgo de `git add -A` accidental. → **Corregido** en `.gitignore` (§4, tabla #2).
- **F-05 (minor).** Ningún workflow enforceaba el contrato de distribución; el único CI (`semana4-proyecto.yml`) no toca el manifiesto. → **Corregido** con contrato mínimo nuevo (§4, tabla #3).
- **F-06 (minor).** `contracts/local_v1.json` apuntaba `contract_file` a 7 archivos inexistentes (`C-01_roles.json`, …); ningún código los lee, pero el contrato es documento normativo. → **Corregido** a `contratos/C-01…C-12.json` reales.
- **F-07 (nit).** `src/mcp_causal/__init__.py` publicitaba `from mcp_causal import ProjectStore, …` (falla); docstring corregido con imports reales. Clasificador `Programming Language :: Python :: 3.12` desbordado (`requires-python >=3.10`); ahora 3.10–3.13.
- **F-08 (nit).** `contratos/README.md` referenciaba `contratos/schemas/contrato.schema.json` (real: `contratos/contrato.schema.json`) y `contratos/prompts/` (inexistente); corregido a rutas reales.
- **F-09 (minor).** `scripts/doctor_minimo.py` pasaba con instalación rota de `ipykernel` (el README exige `ipykernel install`); se añadió a REQUIRED. La línea «semilla de referencia» se re-etiquetó como informativo (no comprobaba nada).
- **F-10 (minor).** `07_docencia/semana_4_proyecto/requirements.txt` usaba scikit-learn vía dependencia transitiva no pineada; ahora `scikit-learn==1.6.1` directo (consistente con los pins de `04_produccion_causal`).
- **F-11 (nit).** Informe histórico `docs/INFORME_EVALUACION_MEJORA.md:26` enlaza `argumentos copy/IMPLEMENTATION_REPORT.md` (existe en WT, untracked y no declarado en el manifiesto): enlace muerto para la distribución pública. No se edita el informe histórico; corregir al refrescarlo: moverlo a `docs/` (declarado) o documentar el pin.

### 3.2 Producción (`04_produccion_causal/`)

- **F-12 (nit con potencial de error).** `estimador.py:123` — `np.linalg.inv(Z.T @ Z)` sin guarda: diseño singular (colinealidad, p≥n) lanzaba `LinAlgError` crudo. → **Corregido**: `ValueError` con contexto, mismo resultado en el camino feliz.
- **F-13 (nit).** `puerta.py` — doble comprobación `not isinstance(diagnosticos, Mapping)` dentro del bucle (redundante con la preparación previa); simplificado sin cambio de semántica.
- **F-14 (nit).** `registro_local.py:4` refería `infra/mlflow_adapter.py`, inexistente; docstring corregido.
- Verificado sin regresión: **20/8/11/15 OK**. `monitor.py:107` (argumento por defecto mutable, seguro por `frozen=True`) se deja como está; `causalops/__init__.py` no promete re-exports; `estimador.py` mantiene `surge`/HC0 intacto.

### 3.3 Datos, notebooks y benchmark

- **F-15 (major, decisión pendiente).** `data_benchmark_causal/.../real/ihdp` y `real/jobs` declaran `"data_origin": "SYNTHETIC - generated from scratch…"` en su `metadata.json`, pero viven bajo `real/` y el informe previo §9 afirmaba que «los archivos actuales viven bajo `synthetic/`» y que `real/ihdp` fue borrado. El árbol actual contradice esa terminología: 5 escenarios manifiestos incluyen `real/jobs` y `real/ihdp` con contenido sintético. Esto confunde procedencia justo donde el curso enseña honestidad de datos. → **Decisión pendiente** (§8.3): renombrar a `synthetic/` (rompe manifiesto/notebooks → requiere refresh coordinado) o anotar el manifiesto, el README del benchmark y el §9 del informe previo como «`real/` = nombre legado; contenido sintético». **No renombré nada**: renombrados de datos sin su visto bueno rompen el manifiesto y los notebooks.
- **F-16 (major).** Copias obsoletas `07_docencia/*/data_benchmark_causal/`: conservan solo el layout antiguo (`synthetic/ihdp|jobs`), les faltan **3 escenarios** (`synthetic/inference/ihdp_medium`, `synthetic/linear_gaussian/10_vars_10_edges`, `synthetic/edge_cases/latent_confounder`) y el árbol `real/`, y difieren en `scenario_id`. Los prototipos son snapshots congelados (hay `scenario_id: synthetic_ihdp` fijo): actualizar los datos alteraría resultados reproducidos vs. sus artefactos. → Documentado; **no sincronicé** (§8.4).
- **F-17 (minor).** `synthetic/linear_gaussian/10_vars_10_edges/splits.json` nombra `source_observed_file: "data.csv"`, inexistente (solo hay `observed_*.csv`); conteos OK (1000; 600/200/200). → Documentado (§8.5).
- **F-18 (major).** Índice vs WT: **12 borrados de tests en staged** con copias idénticas (`cmp`) en WT untracked; incluye `03_notebooks_caso_estudio/tests/test_policy_utils.py` y los 5 Rust `crates/*/tests/*.rs`. Comprometer el índice así borra toda la red de tests del repositorio público (y contradice retroactivamente el §7 del informe previo). → Documentado con remedios (§8.1).
- **F-19 (minor).** `03_notebooks_caso_estudio/lib/{cate_utils,dml_utils,metrics,plotting}.py` modificados (unstaged); el manifiesto refleja el **árbol de trabajo**, no el índice — commit o restaurar antes de cualquier regeneración futura.
- Notebooks A1–A4: **todos** los `from lib import …` resuelven contra `lib/` (incl. `RANDOM_STATE`, `SCENARIO_A1..A4`); `lib.paths.data_root()` apunta al benchmark raíz; imports de matplotlib/sklearn OK. `06_proyecto_final/` consistente (referencias existen; ponderación 70/30 cuadra con `CALENDARIO.md`). Contenido sin hallazgos bloqueantes nuevos.

### 3.4 Docencia y Rust

- **F-20 (major).** `07_docencia/laboratorio_cate/` (~7.1 GB, 32.019 archivos) untracked y sin regla: gran parte es `target/` por subcrate (cubierto por `**/target/`), el resto es WIP experimental. Es un programa **prerregistrado** (`protocol.toml` congela `cate_ihdp_multiverso_v1`; `holdout_ledger/` con resultado honestamente negativo: 12/12 CATE inelegibles; holdout no-read-only intocable). → Documentado; **no ignoré** `laboratorio_cate/` completo (que ocultaría fuentes); recomiendo `cargo clean` selectivo en v2/forensics (§8.4).
- **F-21 (major).** `07_docencia/semana_4_proyecto/` tiene 5 `artifacts/` **trackeados** pese a `07_docencia/**/artifacts/` (y ausentes del manifiesto): evidencia regenerable versionada. Igual que F-18 es cirugía de índice y no se toca sin visto bueno (§8.1).
- **F-22 (minor).** `07_docencia/prototipo_ml_causal/.git` embebido en el WT (HEAD `705282b`): el padre trackea su contenido como archivos planos. Riesgo de doble historia. → Decisión pendiente (§8.6).
- **F-23 (minor).** Los tres prototipos son (casi) copias con deriva independiente (`servicio_core.py` difiere en bytes en los tres; totales de líneas distintas s4p↔mlc 779, s4p↔pp 854, mlc↔pp 564). Es deuda estructural, no defectos puntuales; recomendar una fuente única (§8.7).
- `abrir.sh`/`arrancar.sh`/`setup.sh`: `bash -n` OK los 6; 0 secretos; `semana_4_proyecto/Makefile`: targets `verificar estimar registrar ventanas monitor servir serve humo pruebas cobertura dag evidencia cierre demo limpiar` presentes; `proyecto.ipynb` idéntico entre s4p y pp.

### 3.5 MCP (`08_mcp-agentes-causales/`)

- **F-24 (minor).** Las suites canónica y legacy de tests no pueden compartir proceso pytest (`server/tests/test_gates.py` importa `mcp_causal.gates` tras `sys.path.insert`); por eso el §7 del informe previo usó dos invocaciones. Se mantiene la separación, conviene reflejarla en CI/README (documentado; no se reforma el runner).
- **F-25 (informational).** `reports/acceptance_20261122_031723.json`: `git_commit=737e166 (dirty)` ≠ HEAD actual `3a8cad1`; `status=BLOCKED_LOCAL_V1`, 13 PASS / 3 NOT_IMPLEMENTED (V1-02/03/09). Cifrado del informe previo y del README coherente; no se toca ni se re-etiqueta. Regenerar el reporte sobre el commit final antes de cualquier afirmación de gate.
- **F-26 (minor).** `pnpm/npm`-like classifier corregido (F-07); `mcp.json` invoca `mcp-causal serve` por PATH (frágil fuera de venv; documentado).

## 4. Mejoras aplicadas (esta pasada)

| # | Archivo | Cambio |
|---|---|---|
| 1 | `scripts/validate_student_repo.py` | Reescrito: sin `rglob` masivo en modo git; fallback sin git = solo manifiesto + aviso stderr; `schema`/`notebooks`/SHA-256-hex validados; errores de ausencia/symlink/no-regular separados; Serie A sigue contada por glob acotado. |
| 2 | `.gitignore` | + `08_mcp-agentes-causales/.tmp/` |
| 3 | `.github/workflows/student-repo.yml` | **Nuevo**: ejecuta el validator en push/PR que toquen manifiesto/validators/.gitignore/requirements (contrato de distribución enforceado en CI; stdlib puro). |
| 4 | `scripts/doctor_minimo.py` | + `ipykernel` en REQUIRED; línea de semilla etiquetada informativa. |
| 5 | `07_docencia/semana_4_proyecto/requirements.txt` | + `scikit-learn==1.6.1` directo. |
| 6 | `04_produccion_causal/src/causalops/estimador.py` | `np.linalg.inv` → `ValueError` contextual ante diseño singular. |
| 7 | `04_produccion_causal/src/causalops/puerta.py` | Eliminada doble comprobación redundante (misma semántica). |
| 8 | `04_produccion_causal/src/causalops/registro_local.py` | Docstring: referencia inexistente eliminada. |
| 9 | `08_mcp-agentes-causales/contracts/local_v1.json` | `contract_file` → `contratos/C-0X.json` reales (7 entradas). |
| 10 | `08_mcp-agentes-causales/src/mcp_causal/__init__.py` | Docstring con imports verificables. |
| 11 | `08_mcp-agentes-causales/contratos/README.md` | Rutas de schema/prompts corregidas. |
| 12 | `08_mcp-agentes-causales/pyproject.toml` | Clasificadores 3.10–3.13. |
| 13 | `MANIFEST_ESTUDIANTE.json` | Refrescados **6 registros** (los 6 archivos declarados que edité: #1,#2,#4,#6,#7,#8). Nota: el diff del manifiesto vs HEAD contiene además **10 registros ya refrescados por la sesión previa** (`cate_utils`, `dml_utils`, `metrics`, `plotting`, `estimador`, `inference`, `main`, `MODEL_CARD`, `monitor`, `registro_local`) — todos van a validar juntos al commitear. `shasum -a 256` del CSV LaLonde sin cambios. |

Verificación tras los cambios (§2): validator exit 0; **54/54 tests 04 OK**; `py_compile` OK; `jq empty` OK; `git diff --check` y `--cached` vacíos.

## 5. Verificación ejecutada

Ver tabla §2. No se ejecutaron: builds cargo (`laboratorio_cate`, `argumentos copy`), MCP pytest completo (solo colección; la ejecución escribe `.tmp/`), Typst (459/449/365 páginas ya documentadas por el informe previo), Jupyter end-to-end, CI real en GitHub (el YAML del contrato nuevo no se disparó), ni `make demo`. El informe previo §7 sigue vigente como evidencia histórica; este informe re-verificó únicamente lo indicado en §2.

## 6. Contradicciones con el informe histórico (para su refresco)

- §7 "Week 4 data: Synthetic IHDP/Jobs" y §9 "los archivos actuales viven bajo `synthetic/`": ya no aplica; el árbol usa `real/ihdp`, `real/jobs` con metadata `SYNTHETIC` (F-15).
- §7 "46 policy tests": reproducible solo con el WT actual; el índice staged-deleted los borra (F-18).
- §7 "54 production tests": **re-verificado hoy sobre WT**; irreproducible desde un clon del índice actual.
- §7 cabecera de "125 archivos … SHA-256 verificados": **vigente hoy** tras el refresh (validator exit 0).

## 7. Buenas prácticas aplicadas / recomendadas (naturaleza del tema)

Conocimiento general (no Mem0):
1. **Contrato de distribución explícito y verificado en CI** (manifiesto+hashes): aplicado (§4, tabla #3). Obligatorio en cada PR que toque los declarados.
2. **El manifiesto declara lo que hay, no lo que se desea**: por eso el validator pasó tras refrescar 6 registros y por eso no se añadió/apeó nada del scope sin visto bueno.
3. **Verdad antes que comodidad**: sin git, el check descancia degradado y lo dice (F-02); el informe MCP se mantiene `BLOCKED_LOCAL_V1` (F-25).
4. **Pinned deps + lockfile/requirements directos** (scikit-learn §F-10); reproducibilidad de notebooks.
5. **Derivero de evidencia**: holdout consumido no se re-confirma; prerregistro congelado (laboratorio_cate) se respeta; el informe cita SHA-256 de LaLonde, no «datos de calidad».
6. **Un comando de verificación por afirmación** en el informe (§2); todo lo demás «no verificable».
7. **Índice y WT siempre coherentes**: el borrado staged de tests + copias idénticas sin trackear invierte esa invariante (F-18).

Pendiente de Mem0: autorización y re-ejecución de la búsqueda de memorias temáticas; anexarlas aquí como §7-bis al refrescar el informe.

## 8. Decisiones requeridas del propietario (no aplicadas)

1. **§8.1 Tests staged-deleted (12).** Si el borrado es **accidental**: `git restore --staged 03_notebooks_caso_estudio/tests/test_policy_utils.py 04_produccion_causal/tests/test_monitor.py 04_produccion_causal/tests/test_puerta.py 04_produccion_causal/B1_servicio_dml/tests/test_runtime.py 04_produccion_causal/B3_servicio_policy/tests/test_policy_service.py 04_produccion_causal/B3_servicio_policy/tests/test_runtime.py 04_produccion_causal/B4_monitoreo_causal/tests/test_monitor_core.py "argumentos copy/crates/arg-check/tests/fixtures.rs" "argumentos copy/crates/arg-check/tests/hardening.rs" "argumentos copy/crates/arg-ingest/tests/corpus.rs" "argumentos copy/crates/arg-model/tests/schema_conformance.rs" "argumentos copy/crates/causal-ml/tests/pipeline.rs"`. Si es **deliberado** (pack del estudiante sin tests): mantener staged y documentar la decisión en `07_docencia/README.md` o README raíz, y confirmar que el WT conserva copias locales ignoradas.
2. **§8.2 `02_causal AI en produccion/main.typ`** borrado unstaged; confirmar que es retiro legado del antiguo main (el vigente vive en `Causal_AI/main.typ`).
3. **§8.3 Renovación `real/` → `synthetic/`** (F-15): opción A renombrar + refresh de manifiesto + notebooks + README benchmark; opción B anotar como legado en metadata y docs. Requiere decisión explícita.
4. **§8.4 Copias obsoletas de benchmark** en `07_docencia/*/data_benchmark_causal/` (F-16): re-sincronizar (rompe snapshots congelados) o documentar como "snapshot congelado (scenario_id synthetic_ihdp)" en cada README copiado; además `cargo clean` en `busqueda_cate_v2`/`forensics_v3_report` (~1.9 GB).
5. **§8.5 `splits.json` de linear_gaussian** con `source_observed_file: data.csv` inexistente (F-17): corregir el JSON a la fuente real o publicar el archivo.
6. **§8.6 `.git` embebido en `07_docencia/prototipo_ml_causal/.git`** (F-22): eliminarlo o registrar el árbol como submodule.
7. **§8.7 Triplicación de prototipos** (F-23): fuente única (p.ej. plantilla + script de copia en `scripts/`, sin Python extra) o renombrado que codifique el rol.
8. **§8.8 Alcance del manifiesto**: ¿debe el manifiesto incluir `docs/` (informe), `.github/workflows/`, `CALENDARIO.md` (ya dentro), `LICENSE`? Hoy el manifiesto es el pack del estudiante; ampliar scope es decisión tuya.
9. **§8.9 `git rm --cached` de los 5 `artifacts/` de `semana_4_proyecto`** (F-21) y los **102 tracked en `argumentos copy/`** (tema central: espacio en nombre + JSONL ~18 MB): decidir retirada del repo público del estudiante.
10. **§8.10 LaLonde de distribución**: `lalonde.csv` untracked vs `PROVENANCE.md` trackeado — decidir track explícito (licencia MatchIt/Rdatasets pendiente de resolver) o instrucción de re-descarga+hash en PROVENANCE.
11. **§8.11 Registrar tests re-creados** tras §8.1 si se restauran en índice: ajuntar a manifiesto o mantener fuera por diseño (contrato actual los excluye — decisión coherente con "distribución sin tests", a documentar).
12. **Commit**: nada commiteado por mí. Propuesta de commit atómico: `git add MANIFEST_ESTUDIANTE.json .gitignore scripts/ .github/workflows/student-repo.yml 04_produccion_causal/src/causalops/ 07_docencia/semana_4_proyecto/requirements.txt 08_mcp-agentes-causales/` — los 10 registros de manifiesto de la sesión previa viajan juntos con sus archivos; hacer push y disparar el nuevo workflow para confirmarlo en verde.

## 9. NO VERIFICABLE (esta pasada)

- Build determinista de `laboratorio_cate` (todos sus crates) y `argumentos copy` (cargo build/test; 107 tests y 33 páginas Typst verificados solo por el informe previo).
- MCP en verde real: 94+14 solo **coleccionados** hoy (ejecución escribe `.tmp/`); acceptance sigue BLOCKED_LOCAL_V1 (V1-02/03/09 NOT_IMPLEMENTED).
- Ejecución end-to-end de notebooks A1–A4, sus exports y CI real en GitHub.
- Integridad criptográfica externa del manifiesto (sin firma/testigo): el manifiesto garantiza **bytes** de archivos declarados, no autenticidad de origen ni secretos.
- Resolución legal de la redistribución LaLonde; inferencia causal en ningún entregable (gates ≠ evidencia epidemiológica); estado de los servidores de docs externos.
- Mem0: no consultado (OAuth pendiente); las "mejores prácticas" de §7 son conocimiento general etiquetado como tal.

## 10. Riesgos residuales y próximos pasos (prioridad)

1. Decidir y cerrar §8.1 (índice con 12 borrados de tests) **antes** de cualquier commit/push a `semana4/proyecto` (riesgo de pérdida de red de pruebas y de CI rojo tras F-05).
2. Refrescar CI: matriz mínima con validators + policy-helper tests (actualmente en `03_notebooks_caso_estudio/tests/` WT) en workers limpios.
3. Disparar `student-repo.yml` tras el primer push y exigir verde antes de publicar el repositorio del estudiante.

## 11. Resumen ejecutivo

El repositorio cumple su contrato de distribución hoy (125/125 verificados) y la red de tests pasa 54/54 en producción, pero está a **una comisión de índice** de perder toda su evidencia de prueba. Se endureció el validador (F-01/02/03), se cerró la fuga de `.tmp/` (F-04), se enforceó el contrato en CI (F-05), se corrigieron defectos acotados en producción y MCP sin cambiar semántica, y se refrescó el manifiesto por los 6 archivos declarados editados. Quedan **decisiones tuyas** sobre tests staged, renombrados de datos `real/`↔`synthetic/`, sincronización de copias congeladas y alcance del manifiesto: todas documentadas con comando exacto; **nada se commiteó ni se borró**. Lo central: convertir el manifiesto en gate continuo de CI y sanear el índice antes del próximo push.
