# Reporte Final — MCP Causal Local v1

> **Registro histórico, no aceptación actual.** Las cifras y estados de las secciones originales corresponden a ejecuciones reportadas el 2026-11-09 sobre una revisión anterior. No se reutilizan como evidencia de los cambios posteriores de seguridad, empaquetado o Docker. Cualquier validación nueva se identifica por separado con su comando y alcance.

## Validación ejecutada sobre esta revisión

Los siguientes resultados provienen de comandos ejecutados sobre el árbol de trabajo actual desde `08_mcp-agentes-causales/`. `TMPDIR` apuntó a la ruta absoluta de `.tmp/` dentro de este directorio. No se extrapolan a ningún requisito no ejecutado.

### Correcciones y pruebas

- C-09 ya no puede pasar con un `dataset_sha256` no vacío pero sin datos comprobables: exige `_ruta_datos`, un SHA-256 de exactamente 64 caracteres hexadecimales, confinamiento al workspace, archivo regular legible y recomputación coincidente antes de `PASS`. Se acepta hexadecimal en mayúsculas normalizándolo para la comparación; el servidor sigue inyectando su workspace.
- `./.venv/bin/python -m pytest tests/test_security_regressions.py tests/test_acceptance.py::TestA03Manifest tests/test_e2e_cliente.py -q` → **44 passed**. Incluye ausencia de ruta, hash malformado, archivo ausente, hash correcto y alterado, mayúsculas, rutas absolutas/traversal/symlink, inyección del workspace por el servidor y E2E MCP con datos reales.
- `./.venv/bin/python -m pytest -q` → **94 passed**.
- `PYTHONPATH=server ./.venv/bin/python -m pytest server/tests/test_gates.py -q` → **14 passed**, ejecutados por separado contra la implementación histórica `server/`.
- `./.venv/bin/python -m compileall -q src tests scripts` → exit code 0.
- `/opt/homebrew/bin/uv pip check --python .venv/bin/python` → 37 paquetes compatibles.
- `git --no-pager diff --check -- 08_mcp-agentes-causales` desde la raíz del repositorio → exit code 0.

### Empaquetado e importación aislada

- `/opt/homebrew/bin/uv build --offline --no-sources` → sdist y wheel `mcp_causal-2.0.0` construidos correctamente. Se mantuvo el aviso no bloqueante de deprecación de `project.license` como tabla TOML.
- El wheel canónico reconstruido se reinstaló sin red en el entorno aislado reutilizado mediante `/opt/homebrew/bin/uv pip install --offline --python .tmp/wheel-smoke-venv/bin/python --reinstall --no-deps 'dist/mcp_causal-2.0.0-py3-none-any.whl[test]'`: un paquete reinstalado, conservando las dependencias ya verificadas del extra `test`.
- `.tmp/wheel-smoke-venv/bin/mcp-causal --version` → `mcp-causal 2.0.0`.
- Desde `.tmp/wheel-smoke-tests/`, con los tests actuales y `contratos/` como fixtures: `../wheel-smoke-venv/bin/python -m pytest test_acceptance.py test_security_regressions.py test_mcp_handshake.py test_e2e_cliente.py -q` → **91 passed**. Esto incluye los handshakes MCP por módulo y por el entrypoint instalado y las nuevas regresiones C-09 contra el wheel, no contra el árbol editable.
- `/opt/homebrew/bin/uv pip check --python .tmp/wheel-smoke-venv/bin/python` → 37 paquetes compatibles.

### Aceptación local: no está READY

`./.venv/bin/python scripts/accept_local_v1.py`, ejecutado después de reconstruir el wheel, terminó con **exit code 1**, resultado deliberado y consistente con la cobertura real:

- **13 PASS, 0 FAIL, 3 NOT_IMPLEMENTED**.
- V1-07 ejecutó y registró los casos C-09 sin ruta, hash malformado, archivo ausente, datos y hash correctos, hash alterado y ruta fuera del workspace.
- Pendientes en este runner: **V1-02** (conocimiento desde el paquete instalado), **V1-03** (cliente MCP real) y **V1-09** (recorrido MCP completo elegible).
- Estado: **BLOCKED_LOCAL_V1**. Las pruebas pytest cubren comportamiento relacionado con V1-02/V1-03/V1-09, pero no se contabilizan automáticamente como si este runner los hubiera ejecutado.
- Evidencia generada por el propio runner: `reports/acceptance_20261122_031723.json`, con timestamp interno `2026-11-22T03:17:23.639013+00:00`.

### Límite de filesystem confiado y TOCTOU

La resolución y las comprobaciones de confinamiento son estáticas respecto del instante en que se ejecutan y asumen un filesystem de workspace no hostil. No impiden que un actor con acceso concurrente reemplace una ruta o symlink entre la validación y un uso posterior; esto no es una afirmación de resistencia a exploits. Frente a esa amenaza se requeriría confinamiento a nivel de sistema operativo y un diseño basado en descriptores de archivo ya abiertos, fuera del alcance de esta corrección.

### Docker: evidencia estática solamente

`deploy/Dockerfile` fue inspeccionado estáticamente: instala `.[mcp]`, usa un usuario no privilegiado y ejecuta `["mcp-causal", "serve", "--workspace", "/workspace"]` por stdio. `docker version` encontró el cliente 29.8.2 pero terminó con exit code 1 porque `/var/run/docker.sock` no existe y el daemon no está disponible. **No se construyó ni ejecutó la imagen; no se afirma verificación runtime de Docker.**

---

## Registro histórico original

Fecha histórica: 2026-11-09
Commit: $(git rev-parse HEAD)
Rama: main

## Verificación ejecutada

### Tests unitarios y de aceptación
```
pytest 08_mcp-agentes-causales/tests/ -> 42 passed (41 aceptación + 1 E2E)
```

### Script de aceptación v1
```
python 08_mcp-agentes-causales/scripts/accept_local_v1.py
Resultados: 14 PASS, 0 FAIL, 0 SKIPPED, 0 PENDIENTE
Estado: READY_LOCAL_V1
```

## Entregables

- **Wheel**: `08_mcp-agentes-causales/dist/mcp_causal-2.0.0-py3-none-any.whl` (build desde `src/`)
- **Código fuente**: `08_mcp-agentes-causales/src/mcp_causal/`
- **Contrato ejecutable**: `08_mcp-agentes-causales/contracts/local_v1.json`
- **Script de aceptación**: `08_mcp-agentes-causales/scripts/accept_local_v1.py`

## Instalación y uso

```bash
# Instalación base
pip install 08_mcp-agentes-causales/dist/mcp_causal-2.0.0-py3-none-any.whl

# Con soporte MCP
pip install 08_mcp-agentes-causales/dist/mcp_causal-2.0.0-py3-none-any.whl[mcp]

# Importación
from mcp_causal import __version__
from mcp_causal.models import DeclaracionCausal
from mcp_causal.knowledge import buscar_conocimiento

# Servidor MCP
mcp-causal serve --workspace .mcp_causal_workspace
```

## Qué cambió en esta iteración

- Alineación de `check_id`: validadores emiten `C-01_roles`, `C-03_temporal`, `C-09_linaje`,
  `C-10_particion`, `C-02_observabilidad`, `C-12_exigencias`, `C-06_puerta` — mismo
  namespace que `contracts/local_v1.json` y `perfiles.py`. Se añadió `C-12_exigencias`.
- Vigencia de evidencia: `guardar_declaracion` invalida verificaciones al cambiar la revisión;
  `estado_promocion` verifica `verificar_vigencia` (hash del artefacto en disco) y bloquea si
  la evidencia ya no coincide; `emitir_tarjeta_dict` refleja el estado real.
- MCP reportado en esa revisión: 17 tools + 2 resources + 2 prompts, 42 tests (incluido E2E handshake), wheel
  66 KB desde src/; `mcp.json` listo para Claude/Cursor. Son datos históricos, no una medición del árbol actual.
- Limpieza: `build/` y `dist/` fuera de tracking (artefactos regenerables), `contracts/`, `scripts/`
  y `reports/` añadidos a tracking.

## Limitaciones conocidas

- El conocimiento puede orientar proyectos destinados a nube, pero el MCP funciona solo localmente.
