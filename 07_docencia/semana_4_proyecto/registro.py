"""registro.py — [BLOQUE 4, min 65–90] Contrato C-09 (mini): tarjeta, versión, champion.

Se completa en vivo: la tarjeta, el registro de versión y la promoción.
"""
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from rutas import DATOS, REGISTRO

CAMPOS_TARJETA = ("estimando", "poblacion", "supuestos", "umbrales",
                  "semilla", "dataset_sha256", "estimador")


def sha256_archivo(ruta: Path) -> str:
    return hashlib.sha256(ruta.read_bytes()).hexdigest()


def _escribir(ruta: Path, obj: dict) -> None:
    ruta.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def construir_tarjeta(estimacion: dict) -> dict:
    """Model card mínima, con los umbrales que el monitor usará (calibrados)."""
    # TODO-9 (la tarjeta): devolver el dict con los 7 campos de CAMPOS_TARJETA.
    # supuestos: lista de {nombre, clase: observable|no_observable, tratamiento}.
    # umbrales: {"smd_max": 0.25, "psi_alerta": 0.25, "solape_min": 0.50}.
    # estimador: "AIPW con cross-fitting K=5 (doblemente robusto); OLS solo de
    # referencia". heterogeneidad: corte "nodegree", regla pre-declarada por
    # interpretabilidad (NO seleccionada por ganancia de varianza).
    raise NotImplementedError("TODO-9 pendiente de completar")


def validar_tarjeta(tarjeta: dict) -> None:
    # TODO-10: rechazar si falta algún campo de CAMPOS_TARJETA o si alguna
    # clase de supuesto no es observable/no_observable (adenda de contratos).
    raise NotImplementedError("TODO-10 pendiente de completar")


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
    # TODO-11 (el manifiesto): manifest.json con version, dataset_sha256 (de la
    # tarjeta), puerta = estado_puerta y archivos = {nombre: sha256} de los dos
    # json recién escritos.
    raise NotImplementedError("TODO-11 pendiente de completar")


def verificar_integridad(version: str) -> bool:
    carpeta = REGISTRO / version
    m = json.loads((carpeta / "manifest.json").read_text())
    # TODO-12: recomputar el hash de cada archivo y comparar con el manifiesto.
    raise NotImplementedError("TODO-12 pendiente de completar")


def promover(version: str, aceptar_alerta: bool = False) -> None:
    """Apunta champion a version. 'falla' nunca; 'alerta' solo si se acepta."""
    # TODO-13 (la promoción): leer el manifest; rechazar si puerta == "falla";
    # rechazar "alerta" sin aceptar_alerta=True; escribir champion.tmp y
    # RENOMBRAR (tmp.replace), nunca editar in-place.
    raise NotImplementedError("TODO-13 pendiente de completar")


def champion() -> str:
    return (REGISTRO / "champion").read_text().strip()


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
