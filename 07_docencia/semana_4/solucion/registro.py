"""registro.py — Contrato C-09 (mini): tarjeta, hashes, versión inmutable, champion.

Bloque 4 de la clase: la tarjeta viaja con el estimador, la versión es
inmutable con manifiesto, el alias se escribe atómico y una versión con
puerta 'falla' no se promueve.
"""
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from rutas import DATOS, REGISTRO

CAMPOS_TARJETA = ("estimando", "poblacion", "supuestos", "umbrales",
                  "semilla", "dataset_sha256", "estimador")


# ------------------------------------------------------------------ utilidades

def sha256_archivo(ruta: Path) -> str:
    return hashlib.sha256(ruta.read_bytes()).hexdigest()


def _escribir(ruta: Path, obj: dict) -> None:
    ruta.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


# ---------------------------------------------------------------------- tarjeta

def construir_tarjeta(estimacion: dict) -> dict:
    """Model card mínima, con los umbrales que el monitor usará (calibrados)."""
    return {
        "estimando": estimacion["estimando"],
        "poblacion": f"{estimacion['n']} unidades de observed_train.csv de real/jobs",
        "estimador": "AIPW con cross-fitting K=5 (doblemente robusto); OLS solo de referencia",
        "supuestos": [
            {"nombre": "no confusión condicional", "clase": "no_observable",
             "tratamiento": "declarado; ningún dato lo verifica"},
            {"nombre": "soporte común", "clase": "observable",
             "tratamiento": "medido: rango de e y ESS en estimacion.json"},
            {"nombre": "covariables pre-tratamiento", "clase": "observable",
             "tratamiento": "declarado por identification.json del escenario"},
        ],
        "umbrales": {  # calibrados con el caso canónico del Cap. 7 del libro
            "smd_max": 0.25, "psi_alerta": 0.25, "solape_min": 0.50,
        },
        "heterogeneidad": {
            "corte": "nodegree", "n_cortes": 1,
            "regla": "pre-declarado por interpretabilidad y balance; NO seleccionado por ganancia de varianza",
        },
        "semilla": estimacion["semilla"],
        "dataset_sha256": estimacion.get("dataset_sha256", ""),
    }


def validar_tarjeta(tarjeta: dict) -> None:
    faltan = [c for c in CAMPOS_TARJETA if c not in tarjeta]
    if faltan:
        raise ValueError(f"La tarjeta no tiene: {faltan}")
    for s in tarjeta["supuestos"]:
        if s["clase"] not in ("observable", "no_observable"):
            raise ValueError(f"Clase de supuesto inválida: {s['clase']}")


# --------------------------------------------------------------------- versión

def siguiente_version() -> str:
    existentes = [int(p.name[1:]) for p in REGISTRO.glob("v*") if p.is_dir()]
    return f"v{(max(existentes) + 1 if existentes else 1):04d}"


def registrar(estimacion: dict, tarjeta: dict, estado_puerta: str = "pasa") -> str:
    """Crea vNNNN/ con estimacion.json, tarjeta.json y manifest.json (inmutable)."""
    validar_tarjeta(tarjeta)
    version = siguiente_version()
    carpeta = REGISTRO / version
    carpeta.mkdir(parents=True)
    _escribir(carpeta / "estimacion.json", estimacion)
    _escribir(carpeta / "tarjeta.json", tarjeta)
    manifiesto = {
        "version": version,
        "dataset_sha256": tarjeta["dataset_sha256"],
        "puerta": estado_puerta,
        "archivos": {n: sha256_archivo(carpeta / n)
                     for n in ("estimacion.json", "tarjeta.json")},
    }
    _escribir(carpeta / "manifest.json", manifiesto)
    return version


def verificar_integridad(version: str) -> bool:
    carpeta = REGISTRO / version
    m = json.loads((carpeta / "manifest.json").read_text())
    return all(sha256_archivo(carpeta / n) == h for n, h in m["archivos"].items())


# ------------------------------------------------------------------ promoción

def promover(version: str, aceptar_alerta: bool = False) -> None:
    """Apunta champion a version. 'falla' nunca; 'alerta' solo si se acepta."""
    carpeta = REGISTRO / version
    m = json.loads((carpeta / "manifest.json").read_text())
    if m["puerta"] == "falla":
        raise RuntimeError(f"{version} tiene puerta 'falla': no se promueve")
    if m["puerta"] == "alerta" and not aceptar_alerta:
        raise RuntimeError(f"{version} tiene puerta 'alerta': requiere aceptación explícita")
    tmp = REGISTRO / "champion.tmp"
    tmp.write_text(version)
    tmp.replace(REGISTRO / "champion")  # atómico: renombrar, nunca editar
    print(f"champion -> {version}")


def champion() -> str:
    return (REGISTRO / "champion").read_text().strip()


# ----------------------------------------------------------------------- demo

def demo_mutacion(version: str = "v0001") -> None:
    """Copia una versión, le inyecta bytes, y muestra que la integridad falla."""
    carpeta = REGISTRO / version
    copia = carpeta / "estimacion.json.mutado"
    shutil.copy(carpeta / "estimacion.json", copia)
    with open(copia, "ab") as f:
        f.write(b"\n")
    m = json.loads((carpeta / "manifest.json").read_text())
    h = sha256_archivo(copia)
    print(f"mutación detectada: {'SÍ' if h != m['archivos']['estimacion.json'] else 'NO'} "
          f"(hash distinto del manifiesto -> bloqueado)")
    copia.unlink()


if __name__ == "__main__":
    import estimacion as est

    r = est.estimar()
    r["dataset_sha256"] = sha256_archivo(DATOS / "observed_train.csv")
    tarjeta = construir_tarjeta(r)
    version = registrar(r, tarjeta, estado_puerta="pasa")
    print(f"registrada {version} | integridad: "
          f"{'OK' if verificar_integridad(version) else 'ROTA'}")
    demo_mutacion(version)
    promover(version)
    print(f"champion resuelve a: {champion()}")
