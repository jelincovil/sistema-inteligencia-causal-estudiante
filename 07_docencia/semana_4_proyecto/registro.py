"""registro.py — [BLOQUE 4, min 65–90] Contrato C-09 (mini): tarjeta, versión, champion.

Se completa en vivo: la tarjeta, el registro de versión y la promoción.
"""
from __future__ import annotations

import hashlib  # Biblioteca estándar para calcular huellas SHA-256 de archivos (integridad)
import json     # Biblioteca estándar para leer y escribir datos en formato JSON
import shutil   # Biblioteca estándar para copiar, mover o borrar archivos y carpetas

from datetime import datetime, timezone
from pathlib import Path

from rutas import ARTEFACTOS, DATOS, ESCENARIO, REGISTRO

CAMPOS_TARJETA = (
    "estimando", "poblacion", "supuestos", "umbrales",
    "semilla", "dataset_sha256", "estimador", "uso_previsto",
    "limitaciones", "soporte", "puerta", "sensibilidad",
    "placebo", "identificacion", "version_esquema",
)

# Umbrales por escenario: convenciones iniciales documentadas, no calibración
# universal. El monitor informa qué decisiones cambian al escalarse ±20 %.
UMBRALES = {
    "synthetic/jobs": {
        "smd_max": 0.25,
        "smd_ponderado_max": 0.10,
        "psi_alerta": 0.25,
        "solape_min": 0.50,
        "efecto_estabilidad": 0.20,
    },
    "synthetic/ihdp": {
        "smd_max": 0.50,
        "smd_ponderado_max": 0.25,
        "psi_alerta": 0.25,
        "solape_min": 0.30,
        "efecto_estabilidad": 0.20,
    },
}

ACCIONES_PUERTA = {
    "continuar": "todo dentro de umbral",
    "alertar": "revisar balance o estabilidad del efecto antes de reentrenar",
    "revisar_identificacion": "placebo o control negativo falla: revisar identificación",
    "reentrenar": "deriva de covariables: reentrenar con datos recientes",
    "abstenerse": "soporte insuficiente: no devolver número",
}


def sha256_archivo(ruta: Path) -> str:
    return hashlib.sha256(ruta.read_bytes()).hexdigest()


def _escribir(ruta: Path, obj: dict) -> None:
    ruta.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def construir_tarjeta(estimacion: dict) -> dict:
    """Model card mínima, con las convenciones de umbral que usará el monitor."""
    covariables = list(estimacion.get("smd_por_covariable", {}))
    n_cov = len(covariables)
    umbrales = dict(UMBRALES[ESCENARIO])
    supuestos = [
        {"nombre": (f"no confusión condicional en las {n_cov} covariables "
                    f"pre-tratamiento"),
         "clase": "no_observable",
         "tratamiento": ("se declara; la identificación lo exige y ningún dato "
                         "lo verifica")},
        {"nombre": "soporte común (0 < e(X) < 1)",
         "clase": "observable",
         "tratamiento": ("se mide: rango de e, ESS de Kish y fracción en zona "
                         "de solapamiento")},
        {"nombre": "consistencia / SUTVA",
         "clase": "no_observable",
         "tratamiento": "se declara; heredado del diseño del escenario"},
        {"nombre": "covariables medidas antes del tratamiento",
         "clase": "observable",
         "tratamiento": ("el benchmark lo declara; la trampa score_post muestra "
                         "qué pasa si no")},
    ]
    return {
        "estimando": estimacion["estimando"],
        "poblacion": (f"los {estimacion['n']} individuos de observed_train.csv del "
                      f"escenario {estimacion.get('escenario', ESCENARIO)} "
                      "(versión de entrenamiento, hash verificado)"),
        "supuestos": supuestos,
        "umbrales": umbrales,
        "semilla": estimacion["semilla"],
        "dataset_sha256": estimacion["dataset_sha256"],
        "estimador": ("AIPW con cross-fitting K=5 (doblemente robusto); "
                      "OLS solo de referencia"),
        "uso_previsto": (
            "Docencia y benchmark sintético. No usar para decisiones clínicas, "
            "laborales ni de política pública real."
        ),
        "limitaciones": [
            "Datos sintéticos: los supuestos se sostienen por diseño del DGP, "
            "no por evidencia de datos reales.",
            "Modelos de resultado y propensión lineales/logísticos; sin learners "
            "no lineales ni repeated cross-fitting.",
            "La proyección por perfil no es un efecto individual, un CATE "
            "identificado ni una recomendación personal; su R² es bajo.",
            "El placebo y el control negativo son diagnósticos de calibración, "
            "no pruebas de ignorabilidad.",
            "Los umbrales del monitor son convenciones iniciales, no leyes "
            "universales; el análisis ±20 % solo explora sensibilidad local.",
            "Los rangos y recortes de propensión no demuestran positividad "
            "poblacional ni soporte multivariable.",
            "El E-value no cubre mala especificación, falta de positividad, "
            "selección, error de medición ni violaciones de SUTVA.",
            "Rosenbaum Γ caracteriza el Wilcoxon de pares retenidos, depende del "
            "emparejamiento y no es una cota de sensibilidad del ATE AIPW.",
        ],
        "soporte": {
            "rango_propension": estimacion.get("rango_e"),
            "ess": estimacion.get("ess"),
            "ess_sobre_n": estimacion.get("ess_sobre_n"),
            "fraccion_solapamiento": estimacion.get("fraccion_solapamiento"),
            "regla_abstencion": (
                "fuera del rango observado de entrenamiento, el servicio se "
                "abstiene y no devuelve número"
            ),
        },
        "puerta": {
            "estado_registro": "desconocido",
            "umbrales": umbrales,
            "acciones": dict(ACCIONES_PUERTA),
            "nota": (
                "el monitor puede actualizar el estado; el servicio lee "
                "artifacts/monitor_estado.json y cae al manifiesto si no existe"
            ),
        },
        "sensibilidad": estimacion.get("sensibilidad", {}),
        "placebo": estimacion.get("placebo", {}),
        "identificacion": estimacion.get("identificacion", {}),
        "validacion_particiones": estimacion.get("validacion_particiones", {}),
        "heterogeneidad": {
            "corte": estimacion["estratos"]["variable"],
            "umbral": estimacion["estratos"]["umbral"],
            "regla": estimacion["estratos"]["regla"],
            "nota": estimacion["estratos"]["nota"],
            "modelo_individual": {
                "tipo": estimacion["modelo_individual"]["tipo"],
                "r2": round(estimacion["modelo_individual"]["r2"], 3),
                "que_cubre": ("heterogeneidad estimada por proyección lineal del score "
                              "AIPW para un perfil; no es un CATE individual identificado"),
            },
            "que_cubre": "media de scores AIPW del estrato, no un CATE individual",
        },
        "version_esquema": "1.2",
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
    if "acciones" not in tarjeta.get("puerta", {}):
        raise ValueError("tarjeta: falta la sección 'acciones' de la puerta")
    for campo in ("sensibilidad", "placebo", "identificacion"):
        if not isinstance(tarjeta.get(campo), dict):
            raise ValueError(f"tarjeta: '{campo}' debe ser un objeto JSON")


def siguiente_version() -> str:
    existentes = [int(p.name[1:]) for p in REGISTRO.glob("v*") if p.is_dir()]
    return f"v{(max(existentes) + 1 if existentes else 1):04d}"


def registrar(estimacion: dict, tarjeta: dict,
              estado_puerta: str = "desconocido") -> str:
    """Crea un bundle pendiente; no cambia champion ni evalúa la puerta."""
    validar_tarjeta(tarjeta)
    if not isinstance(estado_puerta, str) or not estado_puerta:
        raise ValueError("estado_puerta debe ser una cadena no vacía")
    # El manifiesto y la tarjeta de la nueva versión deben declarar la misma puerta.
    tarjeta["puerta"]["estado_registro"] = estado_puerta
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
        "schema_version": "1.2",
        "dataset_sha256": tarjeta["dataset_sha256"],
        "puerta": estado_puerta,
        "archivos": archivos,
        "estimacion_sha256": archivos["estimacion.json"],
        "tarjeta_sha256": archivos["tarjeta.json"],
        "alias_version": version,
    })
    return version


def verificar_integridad(version: str) -> bool:
    carpeta = REGISTRO / version
    m = json.loads((carpeta / "manifest.json").read_text())
    if not isinstance(m, dict) or not isinstance(m.get("archivos"), dict):
        raise ValueError("manifest malformado: 'archivos' debe ser un objeto")
    archivos = m["archivos"]
    requeridos = ("estimacion.json", "tarjeta.json")
    faltan = [nombre for nombre in requeridos
              if not isinstance(archivos.get(nombre), str) or not archivos[nombre]]
    if faltan:
        raise ValueError(f"manifest incompleto: faltan hashes obligatorios de {faltan}")
    # Integridad: se recomputa, no se confía en el manifiesto ni en un mapa vacío.
    return all(sha256_archivo(carpeta / nombre) == hash_declarado
               for nombre, hash_declarado in archivos.items())


def verificar_alias() -> bool:
    """Comprueba que el alias champion apunta a una versión íntegra."""
    ruta = ARTEFACTOS / "alias_champion.json"
    if not ruta.exists():
        return False
    alias = json.loads(ruta.read_text())
    version = alias.get("version")
    if not version or not (REGISTRO / version / "manifest.json").exists():
        return False
    manifest = REGISTRO / version / "manifest.json"
    return (alias.get("manifest_sha256") == sha256_archivo(manifest)
            and verificar_integridad(version))


def promover(version: str, aceptar_alerta: bool = False) -> None:
    """Promueve solo una puerta explícita y coherente con integridad vigente.

    ``alerta`` conserva su excepción exclusivamente con aceptación explícita.
    Todas las validaciones preceden a cualquier escritura de alias o champion.
    """
    try:
        carpeta = REGISTRO / version
        ruta_manifest = carpeta / "manifest.json"
        manifest = json.loads(ruta_manifest.read_text())
        tarjeta = json.loads((carpeta / "tarjeta.json").read_text())
        if not isinstance(manifest, dict) or not isinstance(tarjeta, dict):
            raise ValueError("manifest y tarjeta deben ser objetos JSON")
        estado = manifest.get("puerta")
        estado_tarjeta = tarjeta.get("puerta", {}).get("estado_registro")
        if not isinstance(estado, str) or not estado:
            raise RuntimeError(f"{version} tiene puerta ausente o malformada: no se promueve")
        if estado_tarjeta != estado:
            raise RuntimeError(
                f"{version} tiene puertas incoherentes entre manifest y tarjeta: "
                "no se promueve")
        if estado == "alerta" and not aceptar_alerta:
            raise PermissionError(
                f"{version} está en 'alerta': promueve con aceptar_alerta=True")
        if estado not in ("pasa", "alerta"):
            raise RuntimeError(
                f"{version} tiene puerta {estado!r}: solo 'pasa' o una alerta "
                "explícitamente aceptada pueden promoverse")
        if not verificar_integridad(version):
            raise RuntimeError(f"{version} no supera la integridad: no se promueve")
        manifest_sha256 = sha256_archivo(ruta_manifest)
    except (RuntimeError, PermissionError):
        raise
    except Exception as exc:
        raise RuntimeError(
            f"{version} no se puede validar para promoción: {exc}") from exc

    # Alias y champion no forman una transacción; ninguna escritura ocurre antes
    # de superar puerta e integridad. Solo champion usa rename atómico.
    alias = {
        "version": version,
        "manifest_sha256": manifest_sha256,
        "actualizado": datetime.now(timezone.utc).isoformat(),
    }
    _escribir(ARTEFACTOS / "alias_champion.json", alias)

    temporal = REGISTRO / "champion.tmp"
    temporal.write_text(version + "\n")
    temporal.replace(REGISTRO / "champion")
    print(f"champion -> {version} (alias_champion.json actualizado)")


def champion() -> str:
    alias = ARTEFACTOS / "alias_champion.json"
    if alias.exists():
        return json.loads(alias.read_text())["version"]
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


def _probar_promocion(version: str) -> None:
    """Prueba de bloqueo de 'falla' y aceptación explícita de 'alerta'."""
    carpeta = REGISTRO / version
    carpeta.mkdir(parents=True, exist_ok=True)
    _escribir(carpeta / "estimacion.json", {"prueba": True})
    _escribir(carpeta / "tarjeta.json", {"prueba": True})
    archivos = {n: sha256_archivo(carpeta / n)
                for n in ("estimacion.json", "tarjeta.json")}
    _escribir(carpeta / "manifest.json", {
        "version": version,
        "schema_version": "1.2",
        "dataset_sha256": "prueba",
        "puerta": "falla",
        "archivos": archivos,
        "estimacion_sha256": archivos["estimacion.json"],
        "tarjeta_sha256": archivos["tarjeta.json"],
        "alias_version": version,
    })
    try:
        promover(version)
    except RuntimeError:
        print(f"promoción bloqueada correctamente para {version} (falla)")
    else:
        raise AssertionError(f"{version} con falla se promovió")
    finally:
        shutil.rmtree(carpeta, ignore_errors=True)


if __name__ == "__main__":
    import estimacion as est

    # La cadena consume la estimación de la etapa anterior si está fresca;
    # si falta o no corresponde al escenario, se recalcula.
    ruta_est = ARTEFACTOS / "estimacion.json"
    hash_datos = sha256_archivo(DATOS / "observed_train.csv")
    r = None
    if ruta_est.exists():
        candidato = json.loads(ruta_est.read_text())
        if (candidato.get("escenario") == ESCENARIO
                and candidato.get("dataset_sha256") == hash_datos
                and "sensibilidad" in candidato
                and "placebo" in candidato
                and "diagnosticos_positividad" in candidato
                and "comparacion_estimadores" in candidato):
            r = candidato
    if r is None:
        r = est.estimar()
    r.setdefault("dataset_sha256", hash_datos)
    tarjeta = construir_tarjeta(r)
    version = registrar(r, tarjeta, estado_puerta="desconocido")
    print(f"registrada {version} en estado 'desconocido' | integridad: "
          f"{'OK' if verificar_integridad(version) else 'ROTA'}")
    print("champion sin cambios: la promoción exige evidencia de puerta coherente "
          "y una llamada explícita a promover()")
