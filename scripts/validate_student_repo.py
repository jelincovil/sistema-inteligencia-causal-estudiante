from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

forbidden_parts = {"autograder", "rubrics", "tests", "_ejecutados", "__pycache__", ".pytest_cache", "auditoria_experta", "00_guia_profesor", "08_semantica"}
forbidden_names = {"solution.ipynb", "truth.csv", "truth_train.csv", "truth_validation.csv", "truth_test.csv", "data_full.csv", "scorecard.json", "scm.json"}

try:
    tracked = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines()
    paths = [Path(x) for x in tracked if x]
except (FileNotFoundError, subprocess.CalledProcessError):
    transient = {".git", "__pycache__", ".pytest_cache", ".ipynb_checkpoints"}
    paths = [p.relative_to(ROOT) for p in ROOT.rglob("*") if p.is_file() and not transient.intersection(p.parts)]
violations = []
for p in paths:
    # 08_mcp-agentes-causales es un subproyecto MCP con su propia suite de tests;
    # no es material docente del pack del estudiante. El resto de partes prohibidas
    # (autograder, truth, solutions...) sígue aplicándose ahí.
    es_tests_mcp = p.parts[:1] == ("08_mcp-agentes-causales",) and "tests" in p.parts
    partes = tuple(x for x in p.parts if not (es_tests_mcp and x == "tests"))
    if forbidden_parts.intersection(partes) or p.name in forbidden_names:
        violations.append(str(p))

serie_a = sorted(ROOT.glob("03_notebooks_caso_estudio/notebooks/A*.ipynb"))
if len(serie_a) != 4:
    violations.append(f"se esperaban 4 notebooks Serie A y hay {len(serie_a)}")
if any(p.name == "solution.ipynb" for p in ROOT.rglob("*.ipynb")):
    violations.append("hay una solution.ipynb")

# El manifiesto delimita la distribución pública: comprobar sus hashes no
# equivale a escanear secretos ni a certificar el resto del árbol de trabajo.
manifest_path = ROOT / "MANIFEST_ESTUDIANTE.json"
manifest_entries = []
try:
    candidate_entries = json.loads(manifest_path.read_text(encoding="utf-8"))["files"]
    if not isinstance(candidate_entries, list):
        raise ValueError("'files' debe ser una lista")
    manifest_entries = candidate_entries
except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
    violations.append(f"manifiesto inválido o ilegible: {exc}")

declared_paths = set()
for index, entry in enumerate(manifest_entries):
    location = f"MANIFEST_ESTUDIANTE.json:files[{index}]"
    if not isinstance(entry, dict):
        violations.append(f"{location}: la entrada debe ser un objeto")
        continue
    relative = entry.get("path")
    expected_bytes = entry.get("bytes")
    expected_sha256 = entry.get("sha256")
    if not isinstance(relative, str) or not relative:
        violations.append(f"{location}: path inválido")
        continue
    relative_path = Path(relative)
    candidate = ROOT / relative_path
    if relative_path.is_absolute() or ".." in relative_path.parts:
        violations.append(f"{relative}: ruta fuera del repositorio")
        continue
    if relative in declared_paths:
        violations.append(f"{relative}: ruta duplicada en el manifiesto")
        continue
    declared_paths.add(relative)
    if type(expected_bytes) is not int or expected_bytes < 0:
        violations.append(f"{relative}: bytes debe ser un entero no negativo")
        continue
    if not isinstance(expected_sha256, str):
        violations.append(f"{relative}: sha256 inválido")
        continue
    if not candidate.is_file() or not candidate.resolve().is_relative_to(ROOT.resolve()):
        violations.append(f"{relative}: archivo declarado ausente o fuera del repositorio")
        continue
    try:
        data = candidate.read_bytes()
    except OSError as exc:
        violations.append(f"{relative}: no se pudo leer: {exc}")
        continue
    if len(data) != expected_bytes:
        violations.append(f"{relative}: bytes declarados {expected_bytes}, actuales {len(data)}")
    actual_sha256 = hashlib.sha256(data).hexdigest()
    if actual_sha256 != expected_sha256:
        violations.append(f"{relative}: SHA-256 declarado {expected_sha256}, actual {actual_sha256}")

if violations:
    print("\n".join(violations))
    raise SystemExit(1)
print(
    f"student repo: OK ({len(serie_a)} notebooks Serie A; sin nombres/rutas "
    f"prohibidos; {len(manifest_entries)} archivos del manifiesto con tamaño y SHA-256 verificados)"
)
