"""Servidor MCP causal — 10 tools (iteración 3). Lógica en gates.py, testeable sin mcp."""
from __future__ import annotations

from mcp.server.fastmcp import FastMCP

from mcp_causal import gates

mcp = FastMCP("causal")


@mcp.tool()
def declarar_estimando(estimando: str, poblacion: str, supuestos: list) -> dict:
    """Q-01: Sin esto, todo lo demás falla. Guarda estimando declarado."""
    return gates.declarar_estimando(estimando, poblacion, supuestos)


@mcp.tool()
def validar_esquema_roles(esquema: dict) -> dict:
    """C-01: valida que cada columna tenga un solo rol."""
    return gates.validar_esquema_roles(esquema)


@mcp.tool()
def verificar_version_linaje(manifest: dict) -> dict:
    """C-09: verifica hash y champion."""
    return gates.verificar_version_linaje(manifest)


@mcp.tool()
def verificar_particion_pared(splits: dict) -> dict:
    """C-10: verifica semilla, cobertura y pared."""
    return gates.verificar_particion_pared(splits)


@mcp.tool()
def auditar_validez_temporal(features: list) -> dict:
    """C-03: ninguna feature post-tratamiento."""
    return gates.auditar_validez_temporal(features)


@mcp.tool()
def medir_observabilidad(psi: float, smd_max: float, ess_n: float, umbrales: dict) -> dict:
    """C-02 / Q-04: PSI/SMD/ESS vs umbrales."""
    return gates.medir_observabilidad(psi, smd_max, ess_n, umbrales)


@mcp.tool()
def evaluar_heterogeneidad_policy(qini_oos: float, valor_ipw: dict, umbrales: dict) -> dict:
    """C-12 ext / Q-04: Qini OOS y valor IPW vs aleatorio."""
    return gates.evaluar_heterogeneidad_policy(qini_oos, valor_ipw, umbrales)


@mcp.tool()
def evaluar_sensibilidad(p_placebo: float, p_nc: float, gamma_star: float, umbrales: dict) -> dict:
    """C-08 / Q-02: placebo, control negativo y Gamma*."""
    return gates.evaluar_sensibilidad(p_placebo, p_nc, gamma_star, umbrales)


@mcp.tool()
def evaluar_puerta_causal(senales: dict, umbrales: dict) -> dict:
    """C-06 / Q-06: pasa/alerta/falla y decisión de promoción."""
    return gates.evaluar_puerta_causal(senales, umbrales)


@mcp.tool()
def abstenerse_soporte(perfil: dict, soporte: dict) -> dict:
    """C-04 / Q-07: dentro responde, fuera se abstiene sin número."""
    return gates.abstenerse_soporte(perfil, soporte)


@mcp.tool()
def auditar_equidad(efectos_por_grupo: dict, atributo_protegido: str, umbral_brecha: float = 0.10) -> dict:
    """C-13 / Q-02+Q-04: compara efectos por grupo protegido y mide la brecha."""
    return gates.auditar_equidad(efectos_por_grupo, atributo_protegido, umbral_brecha)


@mcp.tool()
def declarar_poblacion_excluida(estimando: dict, soporte: dict, motivo: str = "") -> dict:
    """C-14 / Q-02+Q-07: cuantifica y declara quién queda fuera del soporte."""
    return gates.declarar_poblacion_excluida(estimando, soporte, motivo)


@mcp.tool()
def evaluar_impacto_dano(efecto: dict, margen_aceptable: float = 0.0) -> dict:
    """C-15 / Q-02+Q-07: estima el daño si el efecto es incorrecto."""
    return gates.evaluar_impacto_dano(efecto, margen_aceptable)


@mcp.tool()
def monitorear_produccion(senales: dict) -> dict:
    """C-07 / Q-06: cuatro señales → orden de preguntas → una acción."""
    return gates.monitorear_produccion(senales)


@mcp.tool()
def emitir_tarjeta(pregunta: dict, estimacion: dict, puerta: dict, sensibilidad: dict) -> dict:
    """C-05 / Q-02+Q-08: construye y valida la tarjeta causal."""
    return gates.emitir_tarjeta(pregunta, estimacion, puerta, sensibilidad)


def main():
    mcp.run()


if __name__ == "__main__":
    main()
