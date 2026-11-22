"""Tests de gates — 1 por tool, con cifras de los casos canónicos del libro."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))
from mcp_causal import gates


def test_declarar_estimando():
    r = gates.declarar_estimando("ATE de D sobre Y", "train real/jobs", [])
    assert r["estado"] == "pasa"
    assert r["criterio"] == "Q-01"


def test_precondition():
    gates.ESTIMANDO.clear()
    r = gates.validar_esquema_roles({"tratamiento": "D", "resultado": "Y", "covariables": ["X"]})
    assert r.get("error") == "PRECONDITION_FAILED"


def test_validar_esquema_roles_doble():
    gates.declarar_estimando("ATE", "pob", [])
    r = gates.validar_esquema_roles({"tratamiento": "D", "resultado": "Y", "covariables": ["D"]})
    assert r["estado"] == "falla" and "doble rol" in r["motivo"]


def test_puerta_tres_estados():
    gates.declarar_estimando("ATE", "pob", [])
    u = {"smd_max": 0.25, "psi_alerta": 0.25, "solape_min": 0.50}
    # v0001 sana (semilla 20260712): pasa
    r1 = gates.evaluar_puerta_causal({"solape": 1.0, "psi": 0.011, "smd_max": 0.22}, u)
    assert r1["estado"] == "pasa" and r1["promueve_champion"]
    # v0002 deriva: alerta
    r2 = gates.evaluar_puerta_causal({"solape": 1.0, "psi": 1.347, "smd_max": 0.19}, u)
    assert r2["estado"] == "alerta" and not r2["promueve_champion"]
    # v0003 positividad: falla
    r3 = gates.evaluar_puerta_causal({"solape": 0.0, "psi": 3.237, "smd_max": 5.24}, u)
    assert r3["estado"] == "falla" and not r3["promueve_champion"]


def test_abstencion_soporte():
    gates.declarar_estimando("ATE", "pob", [])
    soporte = {"age": (18.0, 54.0), "educ": (1.0, 18.0)}
    dentro = gates.abstenerse_soporte({"age": 30, "educ": 10}, soporte)
    assert dentro["estado"] == "respuesta"
    fuera = gates.abstenerse_soporte({"age": 99, "educ": 10}, soporte)
    assert fuera["estado"] == "abstencion"
    assert "age=99" in fuera["motivo"] and fuera["numero"] is None


def test_sensibilidad_gamma():
    gates.declarar_estimando("ATE", "pob", [])
    r = gates.evaluar_sensibilidad(p_placebo=0.64, p_nc=0.64, gamma_star=0.8, umbrales={})
    assert r["estado"] == "pasa"


def test_monitorear_cuatro_senales():
    gates.declarar_estimando("ATE", "pob", [])
    # sin cambio → continuar
    r0 = gates.monitorear_produccion({})
    assert r0["accion"] == "continuar"
    # drift marginal → alertar
    r1 = gates.monitorear_produccion({"drift_marginal": True})
    assert r1["accion"] == "alertar"
    # cambio de regla → revisar identificación
    r2 = gates.monitorear_produccion({"mecanismo_cambio": True, "drift_marginal": True})
    assert r2["accion"] == "revisar_identificacion"
    # sin soporte → abstenerse (va primero)
    r3 = gates.monitorear_produccion({"soporte": False, "mecanismo_cambio": True})
    assert r3["accion"] == "abstenerse"
    # cambio de efecto → reentrenar
    r4 = gates.monitorear_produccion({"efecto_cambio": True})
    assert r4["accion"] == "reentrenar"


def test_emitir_tarjeta_valida():
    gates.declarar_estimando("ATE", "pob", [])
    pregunta = {
        "estimando": "ATE de D sobre Y", "poblacion": "train",
        "supuestos": [
            {"nombre": "soporte", "clase": "observable"},
            {"nombre": "no confusión", "clase": "no_observable"},
        ],
    }
    estimacion = {"efecto": 1596.0, "se": 301.6, "ic": [1004.8, 2187.3],
                  "semilla": 20260715, "dataset_sha256": "abc123"}
    puerta = {"umbrales": {"smd_max": 0.25, "psi_alerta": 0.25, "solape_min": 0.50}}
    sensibilidad = {"no confusión": {"metodo": "pendiente", "estado": "sin_cuantificar"}}
    r = gates.emitir_tarjeta(pregunta, estimacion, puerta, sensibilidad)
    assert r["estado"] == "pasa" and "tarjeta" in r


def test_emitir_tarjeta_rechaza_sin_no_observables():
    gates.declarar_estimando("ATE", "pob", [])
    pregunta = {
        "estimando": "ATE", "poblacion": "train",
        "supuestos": [{"nombre": "soporte", "clase": "observable"}],
    }
    r = gates.emitir_tarjeta(pregunta, {"efecto": 1, "se": 0.1, "ic": [0, 2], "semilla": 1, "dataset_sha256": "x"},
                              {"umbrales": {}}, {})
    assert r["estado"] == "falla" and "no observables" in r["motivo"]


def test_auditar_equidad_brecha():
    gates.declarar_estimando("ATE", "pob", [])
    efectos = {"grupo_a": {"efecto": 1060.0, "se": 421.0},
               "grupo_b": {"efecto": 2345.0, "se": 504.0}}
    r = gates.auditar_equidad(efectos, "nodegree", umbral_brecha=0.10)
    assert r["contrato"] == "C-13"
    assert r["brecha"] == 1285.0


def test_auditar_equidad_sin_grupos():
    gates.declarar_estimando("ATE", "pob", [])
    r = gates.auditar_equidad({}, "raza")
    assert r["estado"] == "falla"


def test_declarar_excluidos():
    gates.declarar_estimando("ATE", "pob", [])
    est = {"poblacion": "train", "n_total": 3000, "n_soporte": 1274}
    r = gates.declarar_poblacion_excluida(est, {}, motivo="trimming por soporte insuficiente")
    assert r["estado"] == "alerta"  # 57.5% excluido
    assert r["n_excluidos"] == 1726
    assert r["fraccion_excluida"] == 0.575


def test_declarar_excluidos_rechaza_ganancia():
    gates.declarar_estimando("ATE", "pob", [])
    est = {"poblacion": "train", "n_total": 100, "n_soporte": 80}
    r = gates.declarar_poblacion_excluida(est, {}, motivo="por ganancia de varianza")
    assert r["estado"] == "falla"


def test_evaluar_dano():
    gates.declarar_estimando("ATE", "pob", [])
    efecto = {"efecto": 1596.0, "se": 301.6}
    r = gates.evaluar_impacto_dano(efecto, margen_aceptable=1000.0)
    assert r["estado"] == "alerta" and r["accion"] == "abstenerse"
    r2 = gates.evaluar_impacto_dano(efecto, margen_aceptable=3000.0)
    assert r2["estado"] == "pasa"


def run_all():
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for t in tests:
        t()
        print(f"  {t.__name__}: OK")
    print(f"\n{len(tests)} tests verdes")


if __name__ == "__main__":
    run_all()
