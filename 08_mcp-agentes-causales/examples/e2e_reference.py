#!/usr/bin/env python3
"""E2E — Referencia completa: DGP → AIPW → evidencia → puerta → servicio.

Ejemplo ejecutable de punta a punta que ejercita todos los módulos
del MCP causal. Usar como referencia de integración.

Uso: python3 examples/e2e_reference.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

# Asegurar que el paquete es importable
sys.path.insert(0, str(Path(__file__).parents[1] / "src"))

from mcp_causal.models import (
    Accion, ClaimLevel, ClaseSupuesto, DeclaracionCausal,
    ResultadoVerificacion, Status, Supuesto, TipoEstimando,
)
from mcp_causal.projects import ProjectStore
from mcp_causal.estimators import DGPSintetico, estimar_aipw
from mcp_causal.validators import evaluar_puerta, validar_abstencion


def main() -> int:
    print("=" * 60)
    print("E2E: DGP → AIPW → Evidencia → Puerta → Servicio")
    print("=" * 60)

    # 1. Crear proyecto
    workspace = Path(".scratch/e2e_workspace")
    store = ProjectStore(workspace)
    store.crear_proyecto("e2e_demo", "Demostración E2E")
    print(f"\n[1] Proyecto creado: e2e_demo")

    # 2. Declarar estimando
    decl = DeclaracionCausal(
        estimando=TipoEstimando.ATE,
        tratamiento="D",
        resultado="Y",
        poblacion="unidades del DGP sintético (n=2000)",
        supuestos=(
            Supuesto(
                nombre="no confusión condicional",
                clase=ClaseSupuesto.NO_OBSERVABLE,
                justificacion="Las 4 covariables del DGP capturan toda la confusión por diseño",
                criterio_revision="revisar si placebo o control negativo fallan",
            ),
            Supuesto(
                nombre="soporte común",
                clase=ClaseSupuesto.OBSERVABLE,
            ),
        ),
    )
    store.guardar_declaracion("e2e_demo", decl)
    print(f"[2] Estimando declarado: ATE de D sobre Y (id: {decl.id_estable})")

    # 3. Generar datos del DGP
    dgp = DGPSintetico(n=2000, tau=0.5, semilla=20260701)
    X, D, Y = dgp.generar()
    print(f"[3] DGP: n={len(D)}, tratados={int(D.sum())}, tau verdadero=0.5")

    # 4. Estimar ATE por AIPW
    resultado = estimar_aipw(X, D, Y, k_folds=5, semilla=4242)
    print(f"[4] AIPW: ATE={resultado.ate:.3f} SE={resultado.se:.3f} "
          f"IC=[{resultado.ic[0]:.3f}, {resultado.ic[1]:.3f}]")
    print(f"    ESS/n={resultado.ess_sobre_n:.2f} rango_e=[{resultado.rango_propensidad[0]:.3f}, "
          f"{resultado.rango_propensidad[1]:.3f}]")

    # Guardar verificación
    verif = ResultadoVerificacion(
        check_id="ate_aipw",
        status=Status.PASS if resultado.ess_sobre_n > 0.1 else Status.WARN,
        claim_level=ClaimLevel.COMPUTED,
        recommended_action=Accion.CONTINUAR,
        mensaje_humano=f"ATE={resultado.ate:.3f}",
    )
    store.guardar_verificacion("e2e_demo", verif)

    # 5. Evaluar puerta en tres ventanas
    umbrales = {"solape_min": 0.5, "psi_alerta": 0.25, "smd_max": 0.25}
    print(f"\n[5] Puerta (umbrales: {umbrales})")

    for nombre, kwargs in [
        ("sana", {}),
        ("deriva", {"drift": 1.0}),
        ("regla_cambiada", {"regla_cambio": True}),
    ]:
        Xw, Dw, Yw = dgp.generar_ventana(400, **kwargs)
        # Calcular señales simplificadas
        e_w = 1 / (1 + __import__("numpy").exp(-(Xw @ dgp.beta)))
        solape = float(((e_w > 0.05) & (e_w < 0.95)).mean())
        # PSI simplificado
        e_ref = 1 / (1 + __import__("numpy").exp(-(X @ dgp.beta)))
        psi = abs(float(Xw[:, 2].mean() - X[:, 2].mean())) * 2  # proxy
        senales = {"solape": solape, "psi": psi, "smd_max": 0.15}
        r_puerta = evaluar_puerta(senales, umbrales)
        print(f"    {nombre:15s}: estado={r_puerta.status.value:6s} "
              f"acción={r_puerta.recommended_action.value}")
        if r_puerta.mensaje_humano:
            print(f"                     {r_puerta.mensaje_humano}")

    # 6. Servicio: consulta dentro y fuera del soporte
    print(f"\n[6] Servicio:")
    soporte = {"x0": (float(X[:, 0].min()), float(X[:, 0].max()))}
    dentro = {"x0": float(X[:, 0].mean())}
    fuera = {"x0": 99.0}
    r_dentro = validar_abstencion(dentro, soporte)
    r_fuera = validar_abstencion(fuera, soporte)
    print(f"    Dentro: {r_dentro.status.value} → {r_dentro.recommended_action.value}")
    print(f"    Fuera (x0=99): {r_fuera.status.value} → {r_fuera.recommended_action.value} "
          f"({r_fuera.mensaje_humano})")

    # 7. Estado de promoción
    estado = store.estado_promocion("e2e_demo")
    print(f"\n[7] Estado de promoción: {estado['estado']} ({estado['motivo']})")

    # 8. Resumen
    proyecto = store.consultar_proyecto("e2e_demo")
    print(f"\n[8] Resumen del proyecto:")
    print(f"    Verificaciones: {len(proyecto['verificaciones'])}")
    for v in proyecto["verificaciones"]:
        print(f"      {v['check_id']}: {v['status']} ({v['checked_at'][:19]})")

    print("\n" + "=" * 60)
    print("E2E: COMPLETADO")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
