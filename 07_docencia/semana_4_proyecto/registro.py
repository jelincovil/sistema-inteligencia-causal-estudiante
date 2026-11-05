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
    # Tarjeta mínima: los siete campos de C-09, con los umbrales que el monitor usará.
    supuestos = [
        {"nombre": "no confusión condicional en las 8 covariables pre-tratamiento",
         "clase": "no_observable",
         "tratamiento": "se declara; la identificación lo exige y ningún dato lo verifica"},
        {"nombre": "soporte común (0 < e(X) < 1)",
         "clase": "observable",
         "tratamiento": "se mide: rango de e, ESS de Kish y fracción en zona de solapamiento"},
        {"nombre": "consistencia / SUTVA",
         "clase": "no_observable",
         "tratamiento": "se declara; heredado del diseño del escenario"},
        {"nombre": "covariables medidas antes del tratamiento",
         "clase": "observable",
         "tratamiento": "el benchmark lo declara; la trampa score_post muestra qué pasa si no"},
    ]
    return {
        "estimando": estimacion["estimando"],
        "poblacion": (f"los {estimacion['n']} individuos de observed_train.csv del "
                      "escenario (versión de entrenamiento, hash verificado)"),
        "supuestos": supuestos,
        "umbrales": {"smd_max": 0.25, "psi_alerta": 0.25, "solape_min": 0.50},
        "semilla": estimacion["semilla"],
        "dataset_sha256": estimacion["dataset_sha256"],
        "estimador": ("AIPW con cross-fitting K=5 (doblemente robusto); "
                      "OLS solo de referencia"),
        "heterogeneidad": {
            "corte": estimacion["estratos"]["variable"],
            "regla": estimacion["estratos"]["regla"],
            "que_cubre": "media de scores AIPW del estrato, no un CATE individual",
        },
    }


def validar_tarjeta(tarjeta: dict) -> None:
    faltan = [c for c in CAMPOS_TARJETA if c not in tarjeta]
    if faltan:
        raise ValueError(f"tarjeta incompleta: falta(n) {faltan}")
    for supuesto in tarjeta["supuestos"]:
        if supuesto.get("clase") not in ("observable", "no_observable"):
            raise ValueError(
                f"supuesto '{supuesto.get('nombre')}': clase {supuesto.get('clase')!r} "
                "no es observable ni no_observable")


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
    # Manifiesto: hashes de lo que acaba de quedar escrito.
    archivos = {nombre: sha256_archivo(carpeta / nombre)
                for nombre in ("estimacion.json", "tarjeta.json")}
    _escribir(carpeta / "manifest.json", {
        "version": version,
        "dataset_sha256": tarjeta["dataset_sha256"],
        "puerta": estado_puerta,
        "archivos": archivos,
    })
    return version


def verificar_integridad(version: str) -> bool:
    carpeta = REGISTRO / version
    m = json.loads((carpeta / "manifest.json").read_text())
    # Integridad: se recomputa, no se confía en el manifiesto.
    return all(sha256_archivo(carpeta / nombre) == hash_declarado
               for nombre, hash_declarado in m["archivos"].items())


def promover(version: str, aceptar_alerta: bool = False) -> None:
    """Apunta champion a version. 'falla' nunca; 'alerta' solo si se acepta."""
    # La promoción es atómica: se escribe el temporal y se renombra.
    manifest = json.loads((REGISTRO / version / "manifest.json").read_text())
    if manifest["puerta"] == "falla":
        raise RuntimeError(f"{version} tiene puerta 'falla': no se promueve")
    if manifest["puerta"] == "alerta" and not aceptar_alerta:
        raise PermissionError(
            f"{version} está en 'alerta': promueve con aceptar_alerta=True")
    temporal = REGISTRO / "champion.tmp"
    temporal.write_text(version + "\n")
    temporal.replace(REGISTRO / "champion")
    print(f"champion -> {version}")


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
