"""Puerta causal: decide si un estimador puede promoverse, a partir de supuestos OBSERVABLES.

Estados: "pasa" < "alerta" < "falla". El estado global es el peor de los chequeos.
Los umbrales son convenciones de trabajo; recalíbralos por caso y regístralos en la model card.

La calibración del propensity (diagnosticos.calibracion_ps_z) se calcula y se informa, pero NO entra en la
regla de decisión: con ventanas de ~1500 unidades un propensity regularizado queda levemente mal calibrado
sin que eso invalide el efecto, y como puerta producía falsas alarmas. Lo que sí decide es el balance
ponderado (SMD), que mide directamente si los pesos equilibran las covariables.

La evidencia ausente, desconocida, mal formada o no finita bloquea la promoción. La vigencia temporal es
una convención operativa local, no una garantía adicional de identificación causal.
"""

from __future__ import annotations

import math
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

ORDEN = {"pasa": 0, "alerta": 1, "falla": 2}
MAX_ANTIGUEDAD_PROMOCION = timedelta(hours=24)


@dataclass(frozen=True)
class Umbral:
    nombre: str
    clave: str
    alerta: float          # valor a partir del cual se pasa a "alerta"
    falla: float           # valor a partir del cual se pasa a "falla"
    mayor_es_peor: bool = True
    origen: str = "convención de trabajo"


UMBRALES_POR_DEFECTO = (
    Umbral("Propensity extremo (fuera de [0.05, 0.95])", "frac_ps_extremo", 0.05, 0.10),
    Umbral("Tamaño efectivo relativo (mínimo de brazos)", "ess_rel_min", 0.30, 0.15, mayor_es_peor=False),
    Umbral("SMD máximo ponderado", "smd_pond_max", 0.10, 0.25, origen="convención de balance (SMD < 0.1)"),
    Umbral("Control negativo |z|", "nc_abs_z", 3.0, 5.0, origen="z = 3 por comparaciones repetidas en el tiempo"),
)


def _numero_finito(valor) -> float:
    if isinstance(valor, (bool, str, bytes)) or valor is None:
        raise ValueError("la métrica debe ser un número, no texto, booleano o nulo")
    numero = float(valor)
    if not math.isfinite(numero):
        raise ValueError("la métrica debe ser finita")
    return numero


def _estado(valor: float, u: Umbral) -> str:
    if not math.isfinite(valor):
        return "falla"
    v = valor if u.mayor_es_peor else -valor
    a = u.alerta if u.mayor_es_peor else -u.alerta
    f = u.falla if u.mayor_es_peor else -u.falla
    if v >= f:
        return "falla"
    if v >= a:
        return "alerta"
    return "pasa"


def evaluar(diagnosticos: dict, umbrales=UMBRALES_POR_DEFECTO) -> dict:
    """Evalúa todos los diagnósticos requeridos; la evidencia inválida produce ``falla``."""
    chequeos = []
    entrada = diagnosticos if isinstance(diagnosticos, Mapping) else None
    for u in umbrales:
        base = {
            "nombre": u.nombre,
            "clave": u.clave,
            "umbral_alerta": u.alerta,
            "umbral_falla": u.falla,
            "origen_umbral": u.origen,
        }
        if entrada is None:
            chequeos.append({**base, "valor": None, "estado": "falla", "motivo": "los diagnósticos no forman un objeto"})
            continue
        if u.clave not in entrada:
            chequeos.append({**base, "valor": None, "estado": "falla", "motivo": "diagnóstico ausente"})
            continue
        bruto = entrada[u.clave]
        try:
            valor = _numero_finito(bruto)
        except (TypeError, ValueError, OverflowError) as exc:
            chequeos.append({**base, "valor": bruto, "estado": "falla", "motivo": f"diagnóstico mal formado: {exc}"})
            continue
        chequeos.append({**base, "valor": valor, "estado": _estado(valor, u)})
    estado = max((c["estado"] for c in chequeos), key=ORDEN.get, default="falla")
    motivos = [f"{c['clave']}: {c['motivo']}" for c in chequeos if "motivo" in c]
    return {"estado": estado, "chequeos": chequeos, "motivo": "; ".join(motivos) or None}


def motivos_rechazo(
    resultado: dict,
    aceptar_alerta: bool = False,
    umbrales=UMBRALES_POR_DEFECTO,
) -> list[str]:
    """Explica por qué un resultado de puerta no autoriza promoción.

    Además del estado agregado, exige todos los chequeos, valores finitos, umbrales
    vigentes y coherencia entre cada chequeo y el estado declarado.
    """
    if not isinstance(resultado, Mapping):
        return ["el resultado de la puerta no es un objeto"]
    estado = resultado.get("estado")
    if not isinstance(estado, str) or estado not in ORDEN:
        return [f"estado de puerta ausente o desconocido: {estado!r}"]
    if estado == "falla":
        return ["la puerta causal está en 'falla'"]
    if estado == "alerta" and not aceptar_alerta:
        return ["la puerta está en 'alerta'; exige aceptar_alerta=True"]

    crudos = resultado.get("chequeos")
    if not isinstance(crudos, list):
        return ["la lista de chequeos de la puerta está ausente o mal formada"]
    motivos = []
    if any(not isinstance(c, Mapping) for c in crudos):
        motivos.append("la lista de chequeos contiene entradas mal formadas")
    estados_evaluados = []
    for u in umbrales:
        encontrados = [c for c in crudos if isinstance(c, Mapping) and c.get("clave") == u.clave]
        if not encontrados:
            motivos.append(f"{u.clave}: diagnóstico requerido ausente")
            continue
        if len(encontrados) != 1:
            motivos.append(f"{u.clave}: diagnóstico duplicado o ambiguo")
            continue
        chequeo = encontrados[0]
        try:
            valor = _numero_finito(chequeo.get("valor"))
            alerta = _numero_finito(chequeo.get("umbral_alerta"))
            falla = _numero_finito(chequeo.get("umbral_falla"))
        except (TypeError, ValueError, OverflowError) as exc:
            motivos.append(f"{u.clave}: valor o umbrales mal formados ({exc})")
            continue
        if not math.isclose(alerta, u.alerta, rel_tol=0.0, abs_tol=1e-12) or not math.isclose(
            falla, u.falla, rel_tol=0.0, abs_tol=1e-12
        ):
            motivos.append(f"{u.clave}: los umbrales registrados no son los vigentes")
        esperado = _estado(valor, u)
        declarado = chequeo.get("estado")
        if not isinstance(declarado, str) or declarado not in ORDEN:
            motivos.append(f"{u.clave}: estado de chequeo ausente o desconocido: {declarado!r}")
            continue
        if declarado != esperado:
            motivos.append(f"{u.clave}: estado '{declarado}' incoherente; el valor y los umbrales implican '{esperado}'")
        estados_evaluados.append(esperado)
    if motivos:
        return motivos
    global_esperado = max(estados_evaluados, key=ORDEN.get, default="falla")
    if estado != global_esperado:
        motivos.append(f"estado global '{estado}' incoherente con los diagnósticos ('{global_esperado}')")
    return motivos


def _revisar_fecha(
    valor,
    campo: str,
    ahora: datetime,
    max_antiguedad: timedelta,
    motivos: list[str],
) -> None:
    if not isinstance(valor, str) or not valor.strip():
        motivos.append(f"{campo}: fecha de verificación ausente o mal formada")
        return
    texto = valor[:-1] + "+00:00" if valor.endswith(("Z", "z")) else valor
    try:
        fecha = datetime.fromisoformat(texto)
    except ValueError:
        motivos.append(f"{campo}: fecha ISO 8601 inválida: {valor!r}")
        return
    if fecha.tzinfo is None or fecha.utcoffset() is None:
        motivos.append(f"{campo}: la fecha debe incluir zona horaria")
        return
    fecha = fecha.astimezone(timezone.utc)
    if fecha > ahora:
        motivos.append(f"{campo}: la fecha de verificación está en el futuro")
    elif ahora - fecha > max_antiguedad:
        motivos.append(
            f"{campo}: evidencia obsoleta ({ahora - fecha} > {max_antiguedad}); vuelva a ejecutar los diagnósticos"
        )


def motivos_rechazo_evidencia(
    tarjeta: dict,
    *,
    estado_manifiesto: str | None = None,
    aceptar_alerta: bool = False,
    ahora: datetime | None = None,
    max_antiguedad: timedelta = MAX_ANTIGUEDAD_PROMOCION,
) -> list[str]:
    """Valida la evidencia persistida, su coherencia con el manifiesto y su vigencia."""
    if not isinstance(tarjeta, Mapping):
        return ["la tarjeta de evidencia no es un objeto"]
    if not isinstance(max_antiguedad, timedelta) or max_antiguedad < timedelta(0):
        raise ValueError("max_antiguedad debe ser un timedelta no negativo")
    instante = ahora or datetime.now(timezone.utc)
    if instante.tzinfo is None or instante.utcoffset() is None:
        raise ValueError("ahora debe incluir zona horaria")
    instante = instante.astimezone(timezone.utc)

    motivos = []
    puerta_card = tarjeta.get("puerta")
    if not isinstance(puerta_card, Mapping):
        motivos.append("la tarjeta no contiene un resultado de puerta válido")
        estado_card = None
    else:
        estado_card = puerta_card.get("estado")
    if estado_manifiesto is not None and estado_manifiesto != estado_card:
        motivos.append(
            f"el manifiesto declara puerta {estado_manifiesto!r}, pero la tarjeta declara {estado_card!r}"
        )

    supuestos = tarjeta.get("supuestos")
    observables = supuestos.get("observables") if isinstance(supuestos, Mapping) else None
    if not isinstance(observables, list):
        motivos.append("la evidencia de diagnósticos observables está ausente o mal formada")
        observables = []
    chequeos = []
    for observable in observables:
        if not isinstance(observable, Mapping):
            chequeos.append(observable)
            continue
        chequeo = dict(observable)
        chequeo["clave"] = observable.get("prueba")
        chequeos.append(chequeo)
    motivos.extend(
        motivos_rechazo(
            {"estado": estado_card, "chequeos": chequeos},
            aceptar_alerta=aceptar_alerta,
        )
    )

    modelo = tarjeta.get("modelo")
    creado = modelo.get("creado") if isinstance(modelo, Mapping) else None
    _revisar_fecha(creado, "modelo.creado", instante, max_antiguedad, motivos)
    for i, observable in enumerate(observables):
        campo = observable.get("prueba", i) if isinstance(observable, Mapping) else i
        verificado = observable.get("verificado_en") if isinstance(observable, Mapping) else None
        _revisar_fecha(verificado, f"diagnóstico {campo}", instante, max_antiguedad, motivos)
    return list(dict.fromkeys(motivos))
