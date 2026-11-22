"""8 procedimientos para sistemas causales."""
from __future__ import annotations

PROCEDIMIENTOS: dict[str, dict] = {
    "iniciar_proyecto": {
        "id": "iniciar_proyecto",
        "titulo": "Iniciar un proyecto causal",
        "descripcion": "Crear expediente y declarar estimando antes de mirar datos.",
        "precondiciones": ["Pregunta causal formulada"],
        "pasos": [
            {"accion": "crear_proyecto", "tool": "crear_proyecto", "describe": "Crear expediente aislado"},
            {"accion": "declarar_estimando", "tool": "declarar_estimando", "describe": "Tipo, tratamiento, resultado, población, supuestos"},
        ],
        "decisiones": ["Si falta supuesto no observable, el proyecto no avanza"],
        "salida": "Declaración causal válida registrada.",
        "ruta_fallo": "Corregir declaración y re-declarar.",
        "contratos": ["C-09"],
    },
    "preparar_datos": {
        "id": "preparar_datos",
        "titulo": "Preparar datos con validez temporal",
        "descripcion": "Esquema de roles, auditoría temporal y partición sin fuga.",
        "precondiciones": ["Declaración válida", "Datos brutos disponibles"],
        "pasos": [
            {"accion": "definir_esquema", "tool": "validar_esquema", "describe": "Roles Y/D/X/Z con un solo rol por columna"},
            {"accion": "auditar_temporal", "tool": "ejecutar_verificacion", "describe": "Timestamps de medición, no de ingesta"},
            {"accion": "particionar", "tool": "ejecutar_verificacion", "describe": "Semilla fija, sin solapes, con truth separado"},
        ],
        "decisiones": ["Feature sin timestamp verificable se excluye"],
        "salida": "Esquema, auditoría temporal y partición verificados.",
        "ruta_fallo": "Corregir roles o timestamps y re-verificar.",
        "contratos": ["C-01", "C-03", "C-10"],
    },
    "estimar": {
        "id": "estimar",
        "titulo": "Estimar el efecto causal",
        "descripcion": "AIPW con cross-fitting, controles de entrada y verdad separada.",
        "precondiciones": ["Datos preparados", "Supuestos de identificación declarados"],
        "pasos": [
            {"accion": "generar_estimar", "tool": "generar_y_estimar", "describe": "AIPW K-folds, preprocesamiento dentro del fold"},
            {"accion": "verificar_observabilidad", "tool": "ejecutar_verificacion", "describe": "ESS, rango de propensidad"},
        ],
        "decisiones": ["Si ESS bajo, recortar y cambiar estimando"],
        "salida": "ATE con IC, no efecto individual.",
        "ruta_fallo": "Revisar especificación o soporte y re-estimar.",
        "contratos": ["C-12", "C-02"],
    },
    "diagnosticar": {
        "id": "diagnosticar",
        "titulo": "Diagnosticar sin verdad",
        "descripcion": "Placebo, control negativo y sensibilidad; diagnósticos no prueban ausencia de confusión.",
        "precondiciones": ["Estimación disponible"],
        "pasos": [
            {"accion": "placebo", "tool": "ejecutar_verificacion", "describe": "Permutar tratamiento, ATE debe ir a 0"},
            {"accion": "control_negativo", "tool": "ejecutar_verificacion", "describe": "Outcome que no debe moverse"},
            {"accion": "sensibilidad", "tool": "ejecutar_verificacion", "describe": "Gamma de Rosenbaum (dominio ≥1)"},
        ],
        "decisiones": ["Si placebo rechaza, revisar identificación"],
        "salida": "p_placebo, ATE control negativo, Gamma con interpretación.",
        "ruta_fallo": "No usar diagnóstico como prueba de causalidad.",
        "contratos": ["C-08"],
    },
    "empaquetar": {
        "id": "empaquetar",
        "titulo": "Empaquetar resultados con trazabilidad",
        "descripcion": "Bundle versionado con hashes y tarjeta que separa declarado/calculado/verificado.",
        "precondiciones": ["Estimación y diagnósticos completos"],
        "pasos": [
            {"accion": "registrar_evidencia", "tool": "registrar_artefacto_tool", "describe": "Hash de cada artefacto"},
            {"accion": "emitir_tarjeta", "tool": "emitir_tarjeta", "describe": "Distingue informativo de aprobado"},
            {"accion": "elegibilidad", "tool": "consultar_elegibilidad", "describe": "Perfil que exige requisitos completos"},
        ],
        "decisiones": ["Tarjeta informativa vs aprobada"],
        "salida": "Bundle con tarjeta, evidencias vigentes y estado de elegibilidad.",
        "ruta_fallo": "Completar verificaciones faltantes.",
        "contratos": ["C-05", "C-09", "C-14", "C-15"],
    },
    "operar_local": {
        "id": "operar_local",
        "titulo": "Operar localmente (servicio + puerta)",
        "descripcion": "Servicio local con health y elegibilidad por perfiles versionados.",
        "precondiciones": ["Bundle aprobado"],
        "pasos": [
            {"accion": "servir", "tool": "abstenerse_soporte", "describe": "Respuesta o abstención según soporte"},
            {"accion": "puerta", "tool": "evaluar_puerta_causal", "describe": "Pasa/alerta/falla con motivo"},
        ],
        "decisiones": ["Fuera de soporte → abstención, no error"],
        "salida": "Servicio operativo con health check.",
        "ruta_fallo": "Verificar soporte y puerta.",
        "contratos": ["C-04", "C-06"],
    },
    "preparar_nube": {
        "id": "preparar_nube",
        "titulo": "Preparar nube (opcional)",
        "descripcion": "Validar Dockerfile y adapter de nube sin credenciales.",
        "precondiciones": ["Servicio local operativo"],
        "pasos": [
            {"accion": "validar_dockerfile", "tool": "generar_y_estimar", "describe": "Sintaxis Dockerfile, sin privilegios"},
            {"accion": "validar_adapter", "tool": "generar_y_estimar", "describe": "Config vars, secretos por referencia"},
        ],
        "decisiones": ["Nube no bloquea entrega local"],
        "salida": "Config validada, estado CLOUD_UNVERIFIED.",
        "ruta_fallo": "Documentar limitación.",
        "contratos": ["C-05"],
    },
    "investigar_alertas": {
        "id": "investigar_alertas",
        "titulo": "Investigar alertas",
        "descripcion": "Procedimiento ante una alerta del monitor.",
        "precondiciones": ["Alerta registrada"],
        "pasos": [
            {"accion": "consultar", "tool": "consultar_proyecto", "describe": "Revisión y evidencia de la alerta"},
            {"accion": "diagnosticar", "tool": "ejecutar_verificacion", "describe": "Placebo/control/sensibilidad"},
            {"accion": "revisar", "tool": "aceptar_advertencia", "describe": "Aceptación ligada a revisión concreta"},
        ],
        "decisiones": ["Revisión sin evidencia renovada no aplica"],
        "salida": "Alerta investigada con decisión registrada.",
        "ruta_fallo": "Re-evaluar con evidencia vigente.",
        "contratos": ["C-07", "C-08"],
    },
}

def obtener_procedimiento(pid: str) -> dict | None:
    return PROCEDIMIENTOS.get(pid)

def listar_procedimientos() -> list[str]:
    return sorted(PROCEDIMIENTOS.keys())
