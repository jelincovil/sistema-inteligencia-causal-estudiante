from __future__ import annotations

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

if violations:
    print("\n".join(violations))
    raise SystemExit(1)
print(f"student repo: OK ({len(serie_a)} notebooks Serie A, sin secretos ni material docente)")
