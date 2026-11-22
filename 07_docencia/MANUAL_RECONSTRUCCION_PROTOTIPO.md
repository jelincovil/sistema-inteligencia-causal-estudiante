# Manual de construcción paso a paso — del prototipo «Puente» base a la mejora

Objetivo: que un estudiante reconstruya a mano, sin git, las seis mejoras que
viven en la rama `demo/mejora-paso-a-paso` del prototipo. Cada paso es un
cambio pequeño, verificable y con criterios de aceptación. Al terminar, el
proyecto base queda convertido en la versión mejorada.

- *Base:* `main` del repo público (`705282b`, incluye la extensión didáctica
  DML-IV). Si prefieres, el tag `v1.0.4` también sirve: el código de los
  pasos 1–6 es idéntico entre ambos.
- *Resultado:* el mismo árbol que la rama `demo/mejora-paso-a-paso`
  (`705282b..8abd92d`, 6 commits). Este manual es el equivalente docente vía
  edición de archivos.
- *Fuera de alcance:* añadir datos nuevos, tocar la separación observables /
  evaluación reservada, o usar esto para decisiones reales.

## 0. Preparación

**0.1 Obtén la base.** Sin git: descarga el ZIP de la rama `main` desde
GitHub y descomprime; o con git: `git clone --depth 1
https://github.com/jelincovil/prototipo_ml_causal.git`. Llámala `prototipo_base/`.

**0.2 Entorno.** Python 3.13. Dentro de `prototipo_base/`:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

**0.3 Comprueba que la base pasa antes de tocar nada:**

```bash
SIC_ESCENARIO=synthetic/ihdp make verificar pruebas
```

Debe terminar con `PRUEBAS: OK`. Si no, la base está rota y el ejercicio no
tiene sentido hasta arreglarla.

**0.4 Regla de oro.** Vas de a un paso por vez y, al final de cada paso,
corres `SIC_ESCENARIO=synthetic/ihdp make pruebas`. Si falla, el paso no está
bien aunque "parezca" funcionar: el test ES la especificación aquí.

---

## Paso 1/6 — Compuerta dura de cobertura en CI (`cobertura.py`, `Makefile`, `ci.yml`)

**Problema.** `cobertura.py` produce `artifacts/cobertura.json` y nadie lo
consume: una versión mal calibrada se promueve igual.

**1.1 En `cobertura.py`, debajo de `COVARIABLES = ...`** (después de la línea
que define `COVARIABLES` y antes de `ADVERTENCIA = (`), añade:

```python
# Compuerta de promoción (convención declarada, no calibración universal):
# la promoción de una versión exige que el estimador principal (AIPW) cumpla
# cobertura IC95 dentro de [0.90, 0.99] y |sesgo| <= 0.10 (5 % del ATE
# verdadero de este DGP). Es evidencia frente a este DGP ilustrativo;
# no generaliza a otros procesos de datos.
COBERTURA_MIN = 0.90
COBERTURA_MAX = 0.99
SESGO_ABS_MAX = 0.10
```

**1.2 En `cobertura.py`, inmediatamente antes de `def _resumir_estimador(...)`**,
añade la función:

```python
def verificar_compuerta(metricas: dict) -> dict:
    """Compuerta dura sobre las métricas ya computadas (la puerta de promoción).

    Solo decide sobre ``aipw``, el estimador principal; OLS y el ingenuo quedan
    como referencia informativa. Nunca relaja resultados: un fallo se reporta
    explícitamente y la promoción queda bloqueada.
    """
    aipw = metricas["aipw"]
    problemas = []
    if not (COBERTURA_MIN <= aipw["cobertura_ic95"] <= COBERTURA_MAX):
        problemas.append(
            f"cobertura_ic95 de aipw = {aipw['cobertura_ic95']:.3f} fuera de "
            f"[{COBERTURA_MIN}, {COBERTURA_MAX}]")
    if abs(aipw["sesgo"]) > SESGO_ABS_MAX:
        problemas.append(
            f"|sesgo| de aipw = {abs(aipw['sesgo']):.4f} > {SESGO_ABS_MAX}")
    return {
        "pasa": not problemas,
        "estimador": "aipw",
        "umbrales": {
            "cobertura_ic95_min": COBERTURA_MIN,
            "cobertura_ic95_max": COBERTURA_MAX,
            "sesgo_abs_max": SESGO_ABS_MAX,
        },
        "problemas": problemas,
        "nota": (
            "Convención inicial declarada para la puerta de promoción; no es "
            "una calibración universal ni una garantía fuera de este DGP. "
            "CI ejecuta esta compuerta sobre la corrida por defecto."
        ),
    }
```

**1.3 En `ejecutar()`, después de la línea `metricas = {...}`** añade:

```python
    compuerta = verificar_compuerta(metricas)
```

y en el `return` del dict final, después de `"estimadores": metricas,`, añade:

```python
        "compuerta": compuerta,
```

**1.4 En `_metadatos()`**, después de la clave `"aipw_se_ic": (...)` y antes
del cierre `}` del diccionario devuelto, añade:

```python
        "aipw_sin_crossfit_se_ic": (
            "Misma especificación que aipw_crossfit (lineales/logística, trimming "
            "declarado), pero ajustando y prediciendo sobre las MISMAS "
            "observaciones; existe para cuantificar el coste de no usar "
            "cross-fitting. IC95 = ATE +/- 1.96*SE"
        ),
        "compuerta_promocion": {
            "criterio": "IC95 de aipw dentro de [0.90, 0.99] y |sesgo| <= 0.10",
            "naturaleza": (
                "Convención inicial para la puerta de promoción; no es una "
                "calibración universal ni una garantía fuera de este DGP."
            ),
        },
```

**1.5 En `main()` de `cobertura.py`**, después de `--semilla` añade:

```python
    parser.add_argument(
        "--compuerta", action="store_true",
        help="sale con código 1 si la compuerta de promoción no pasa",
    )
```

y después de `print(json.dumps(resultado["resumen"], ...))` añade:

```python
    print(json.dumps(resultado["compuerta"], ensure_ascii=False, indent=2, allow_nan=False))
```

y reemplaza el `return 0` final por:

```python
    if args.compuerta and not resultado["compuerta"]["pasa"]:
        print("COMPUERTA: FALLA — la promoción queda bloqueada")
        return 1
    print("COMPUERTA: PASA")
    return 0
```

**1.6 En `Makefile`**, en la línea `.PHONY` añade `cobertura-compuerta`, y
después del objetivo `cobertura:` añade:

```makefile
cobertura-compuerta:  ## misma simulación; sale con código 1 si la compuerta de promoción no pasa
	$(PYTHON) cobertura.py --compuerta
```

**1.7 En `.github/workflows/ci.yml`**, cambia
`run: make verificar pruebas demo` por
`run: make verificar pruebas cobertura-compuerta demo`.

**1.8 Test (en `pruebas_estimacion.py`, antes del bloque `# 13.`)**

```python
    # 12b. Compuerta de promoción: estructura, acuerdo y rechazo sintético.
    cob_comp = cobertura.ejecutar(n=60, repeticiones=2, semilla=20261111)
    compuerta = cob_comp["compuerta"]
    assert {"pasa", "estimador", "umbrales", "problemas", "nota"} <= set(compuerta)
    assert compuerta["estimador"] == "aipw"
    assert compuerta["pasa"] == (not compuerta["problemas"])
    assert np.isfinite(cob_comp["estimadores"]["aipw"]["cobertura_ic95"])
    umbrales = compuerta["umbrales"]
    assert (0.0 < umbrales["cobertura_ic95_min"]
            < umbrales["cobertura_ic95_max"] <= 1.0)
    assert umbrales["sesgo_abs_max"] > 0.0
    # Fallos sintéticos: la compuerta no relaja resultados.
    aipw_ok = dict(cob_comp["estimadores"]["aipw"])
    sin_cobertura = dict(aipw_ok, cobertura_ic95=0.5)
    sin_sesgo = dict(aipw_ok, sesgo=10 * cobertura.SESGO_ABS_MAX)
    for metrica, clave in ((sin_cobertura, "cobertura"), (sin_sesgo, "sesgo")):
        resultado_fallo = cobertura.verificar_compuerta(
            {**cob_comp["estimadores"], "aipw": metrica})
        assert resultado_fallo["pasa"] is False
        assert resultado_fallo["problemas"]
        assert any(clave in p for p in resultado_fallo["problemas"])
```

**Verifica.** `SIC_ESCENARIO=synthetic/ihdp make cobertura-compuerta` debe
imprimir `COMPUERTA: PASA`. `make pruebas` debe dar `PRUEBAS: OK`.

---

## Paso 2/6 — Estimando efectivo tras el trimming (`estimacion.py`, `registro.py`)

**Problema.** Tras recortar ê a [0.05, 0.95], el estimador ya no identifica
el ATE poblacional, pero la tarjeta sigue diciendo "ATE" a secas.

**2.1 En `estimacion.py`, dentro de `aipw_crossfit`**, cambia el bloque que
va desde `positividad = diagnosticos_positividad(e, D)` hasta el `return`:

```python
    positividad = diagnosticos_positividad(e, D)
    propensiones_oof = e.copy()
    recortadas = int(positividad["total"]["recortado_n"])
    fraccion_recortada = recortadas / n
    if recortadas > 0:
        estimando_efectivo = (
            "ATE en la población con solapamiento (ê recortado a [0.05, 0.95]; "
            f"{recortadas} unidades fuera de la zona de solapamiento "
            f"({fraccion_recortada:.1%})); el efecto poblacional no se "
            "identifica en las colas")
    else:
        estimando_efectivo = (
            "ATE poblacional (ê íntegramente en [0.05, 0.95]; sin recorte "
            "efectivo)")
    e = np.clip(e, 0.05, 0.95)  # trimming declarado en la tarjeta
    score = (mu1 - mu0 + D * (Y - mu1) / e - (1 - D) * (Y - mu0) / (1 - e))
    ate = float(score.mean())
    se = float(score.std(ddof=1) / np.sqrt(n))
    return {"ate": ate, "se": se, "ic": [ate - 1.96 * se, ate + 1.96 * se],
            "scores": score, "propensiones_oof": propensiones_oof,
            "diagnosticos_positividad": positividad,
            "estimando_efectivo": estimando_efectivo,
            "trimming": {
                "limite": [0.05, 0.95],
                "unidades_recortadas": recortadas,
                "fraccion_recortada": float(fraccion_recortada),
            }}
```

**2.2 En `estimar()`**, en el dict final, después de la línea
`"ate_aipw": ..., "ic_aipw": aipw["ic"],`, añade:

```python
        "estimando_efectivo": aipw["estimando_efectivo"],
        "trimming": aipw["trimming"],
```

**2.3 En `registro.py`**:
- En `CAMPOS_TARJETA`, cambia `"estimando", "poblacion", ...` por
  `"estimando", "estimando_efectivo", "poblacion", ...` (una línea, respeta
  las agrupaciones).
- En `construir_tarjeta`, después de `"estimando": estimacion["estimando"],`
  añade `"estimando_efectivo": estimacion["estimando_efectivo"],`.
- En `validar_tarjeta`, después de comprobar `faltan`, añade:

```python
    efectivo = tarjeta.get("estimando_efectivo")
    if not isinstance(efectivo, str) or not efectivo.strip():
        raise ValueError(
            "tarjeta: 'estimando_efectivo' debe ser una cadena no vacía; "
            "una versión promovida debe declarar si reporta el ATE poblacional "
            "o el ATE en la población con solapamiento tras el trimming")
```

- Cambia `"version_esquema": "1.2"` a `"1.3"` (3 ocurrencias: tarjeta y los
  dos manifiestos).

**2.4 Test (en `pruebas_estimacion.py`, igual que en 1.8)**

```python
    # 12c. La puerta exige el estimando efectivo declarado.
    import registro
    base = {c: "x" for c in registro.CAMPOS_TARJETA}
    base.update({
        "supuestos": [{"nombre": "soporte común", "clase": "observable"}],
        "puerta": {"acciones": {"continuar": "todo dentro de umbral"}},
        "sensibilidad": {}, "placebo": {}, "identificacion": {},
    })
    registro.validar_tarjeta(base)  # no debe lanzar
    sin_efectivo = {k: v for k, v in base.items() if k != "estimando_efectivo"}
    for rota in (sin_efectivo, dict(base, estimando_efectivo="   ")):
        try:
            registro.validar_tarjeta(rota)
        except ValueError:
            pass
        else:
            raise AssertionError("la tarjeta sin estimando efectivo se aceptó")
```

**Verifica.** `make pruebas` → `PRUEBAS: OK`. Una tarjeta manual sin el
campo debe ser rechazada con `ValueError`.

---

## Paso 3/6 — El brazo «sin cross-fitting» (`estimacion.py`, `cobertura.py`)

**Problema.** El benchmark no mide cuánto se degrada AIPW si ajustas y
predices sobre las mismas observaciones.

**3.1 En `estimacion.py`, después de `aipw_crossfit`**, añade:

```python
def aipw_sin_crossfit(col: dict, esquema: EsquemaCausal,
                      resultado: str | None = None) -> dict:
    """AIPW ajustando y prediciendo en LA MISMA muestra (sin cross-fitting).

    Idéntica especificación que ``aipw_crossfit`` (resultado lineal, propensión
    logística, trimming [0.05, 0.95]); la única diferencia es que los nuisance
    se ajustan y se evalúan con las mismas observaciones. Existe para medir,
    en el DGP ilustrativo de cobertura, el coste de evaluar con datos vistos;
    no es un estimador alternativo recomendable en producción.
    """
    y_key = resultado or esquema.resultado
    n = len(col[esquema.tratamiento])
    D, Y = col[esquema.tratamiento], col[y_key]
    X = np.column_stack([col[c] for c in esquema.covariables])
    b1 = _ajustar_lineal(X[D == 1], Y[D == 1])
    b0 = _ajustar_lineal(X[D == 0], Y[D == 0])
    Xf = np.column_stack([np.ones(n), X])
    mu1, mu0 = Xf @ b1, Xf @ b0
    e_crudo = _propensity_fit(X, D)(X)
    positividad = diagnosticos_positividad(e_crudo, D)
    e = np.clip(e_crudo, 0.05, 0.95)
    score = (mu1 - mu0 + D * (Y - mu1) / e
             - (1 - D) * (Y - mu0) / (1 - e))
    ate = float(score.mean())
    se = float(score.std(ddof=1) / np.sqrt(n))
    return {"ate": ate, "se": se, "ic": [ate - 1.96 * se, ate + 1.96 * se],
            "diagnosticos_positividad": positividad}
```

**3.2 En `cobertura.py`**: cambia el import a
`from estimacion import aipw_crossfit, aipw_sin_crossfit, ate_ols`; en
`ejecutar()`, cambia `resultados = {...}` para incluir
`"aipw_sin_crossfit": []`; dentro del bucle de repeticiones, añade después de
`"aipw": _validar_estimacion(...),`:

```python
                "aipw_sin_crossfit": _validar_estimacion(
                    "aipw_sin_crossfit", aipw_sin_crossfit(col, esquema)
                ),
```

y en el docstring del módulo, reemplaza "El ejercicio compara AIPW con
cross-fitting, OLS ajustado" por "El ejercicio compara AIPW con cross-fitting,
AIPW sin cross-fitting (la misma especificación ajustando y prediciendo sobre
las mismas observaciones), OLS ajustado".

**3.3 En `pruebas_estimacion.py`**, cambia
`nombres_estimadores = {"aipw", "ols_ajustado", "ingenuo"}` por
`nombres_estimadores = {"aipw", "aipw_sin_crossfit",
                       "ols_ajustado", "ingenuo"}`.

**Verifica.** `make cobertura` → `aipw_sin_crossfit` aparece en el JSON.
`make pruebas` → OK. Expectativa numérica: con nuisance bien especificados el
coste es pequeño (en la corrida de referencia: 0,97 → 0,96 de cobertura). Léelo
así; no concluyas que "el cross-fitting es opcional".

---

## Paso 4/6 — Test de los invariantes de cross-fitting (`estimacion.py`)

**Problema.** El supuesto operativo "ninguna unidad predice con un modelo
que la vio" no está verificado por tests.

**4.1 En `estimacion.py`, antes de `aipw_crossfit`**, añade:

```python
def folds_crossfit(n: int, k: int,
                   semilla_folds: int = SEMILLA) -> list[np.ndarray]:
    """Pliegues de cross-fitting: permutación con semilla repartida en k partes.

    Invariante: los pliegues son disjuntos y su unión cubre exactamente
    ``{0, ..., n-1}``. Es la condición sobre la que descansa que ningún
    nuisance ve a la unidad que predice.
    """
    if k < 2 or n < k:
        raise ValueError(f"cross-fitting inválido: n={n}, k={k}")
    g = np.random.default_rng(semilla_folds)
    return list(np.array_split(g.permutation(n), k))
```

**4.2 En `aipw_crossfit`**, reemplaza las 4 líneas

```python
    if k < 2 or n < k:
        raise ValueError(f"cross-fitting inválido: n={n}, k={k}")
    g = np.random.default_rng(semilla_folds)
    folds = np.array_split(g.permutation(n), k)
```

por `    folds = folds_crossfit(n, k, semilla_folds)`.

**4.3 Test (en `pruebas_estimacion.py`)**

```python
    # 12d. Invariantes de cross-fitting: particiones disjuntas que cubren todo.
    from estimacion import folds_crossfit
    for n_x, k_x in ((103, 5), (50, 4), (10, 2)):
        pliegues = folds_crossfit(n_x, k_x, semilla_folds=7)
        assert len(pliegues) == k_x
        np.testing.assert_array_equal(
            np.sort(np.concatenate(pliegues)), np.arange(n_x))
        for i in range(len(pliegues)):
            for j in range(i + 1, len(pliegues)):
                assert np.intersect1d(pliegues[i], pliegues[j]).size == 0
    # Reproducibilidad con la misma semilla y rechazo de n < k.
    np.testing.assert_array_equal(
        np.sort(folds_crossfit(103, 5, 7)[0]), np.sort(folds_crossfit(103, 5, 7)[0]))
    try:
        folds_crossfit(4, 5)
    except ValueError:
        pass
    else:
        raise AssertionError("folds_crossfit aceptó n < k")
```

**Verifica.** `make pruebas` → OK. Muta el test (p. ej. borra la permutación)
y observa el fallo: el test debe protestar.

---

## Paso 5/6 — Abstención por ESS en la puerta del servicio (`servicio_core.py`)

**Problema.** Aunque el monitor declare `pasa`, el servicio puede servir un
ATE respaldado por un ESS/n minúsculo.

**5.1 En `servicio_core.py`**, después de `from sensibilidad import
e_value_continuo`, añade:

```python
# Convención inicial (no calibración universal): un ESS/n bajo el piso obliga
# a abstenerse aunque el monitor declare 'pasa'. Es un piso de honestidad
# estadística: con ESS/n bajo, el IC del champion describe muy pocas unidades
# efectivas. Sensibilidad ±20 % explorable con la misma disciplina que los
# umbrales del monitor (factores 0.8, 1 y 1.2).
PISO_ESS_SOBRE_N = 0.25
```

**5.2 En `_abstencion_por_puerta`**, después del bloque
`if estado == "falla": return {...}` y antes de `return None`, añade:

```python
    tarjeta = bundle.get("tarjeta") or {}
    ess = (tarjeta.get("soporte") or {}).get("ess_sobre_n")
    if isinstance(ess, (int, float)) and not isinstance(ess, bool):
        if ess < PISO_ESS_SOBRE_N:
            return {
                "estado": "abstencion",
                "tipo": tipo,
                "motivo": (
                    f"ESS/n = {ess:.2f} bajo el piso declarado en el contrato "
                    f"({PISO_ESS_SOBRE_N:.2f}): soporte insuficiente por "
                    "declaración del contrato, no por calibración universal; "
                    "no se devuelve ningún número"),
                "estado_puerta": estado,
                "ess_sobre_n": float(ess),
                "piso_ess_sobre_n": PISO_ESS_SOBRE_N,
                "version": bundle["version"],
            }
```

**5.3 Test (en `pruebas_estimacion.py`)**

```python
    # 12e. La puerta del servicio se abstiene con ESS/n bajo el piso declarado.
    import servicio_core
    bundle_ess_bajo = {
        "integridad_valida": True,
        "tarjeta": {"soporte": {"ess_sobre_n": 0.10}},
        "monitor": None,
        "manifest": {"puerta": "pasa"},
        "estimacion": {},
        "version": "vTEST",
    }
    salida = servicio_core._abstencion_por_puerta(bundle_ess_bajo, "poblacional")
    assert salida is not None and salida["estado"] == "abstencion"
    assert "ESS/n" in salida["motivo"]
    assert salida["ess_sobre_n"] == 0.10
    bundle_ess_ok = dict(
        bundle_ess_bajo, tarjeta={"soporte": {"ess_sobre_n": 0.74}})
    assert servicio_core._abstencion_por_puerta(
        bundle_ess_ok, "poblacional") is None
    bundle_roto = {"integridad_valida": False, "motivo_carga": "x",
                   "version": "vTEST"}
    assert servicio_core._abstencion_por_puerta(
        bundle_roto, "estrato")["estado"] == "abstencion"
```

**Verifica.** `make pruebas` → OK. El champion actual (ESS/n ≈ 0.74) sigue
sirviendo; construye un bundle artificial con 0.10 y verás la abstención.

---

## Paso 6/6 — Evidencia y documentación

**6.1** Enlaza la guía del método: copia
`docs/SESION_DML_40MIN.pdf` (del repositorio del curso) en `docs/` y añade al
README, después de la sección «Cobertura Monte Carlo», una sección
«Guía del método (para el operador del modelo)» que enlace ese PDF y explique
que no sustituye la tarjeta ni la puerta (ver paso 6 en la rama de
referencia: `git show 8abd92d:README.md`).

**6.2** Regenera la evidencia:

```bash
SIC_ESCENARIO=synthetic/ihdp make evidencia PYTHON=.venv/bin/python
```

IMPORTANTE: usa el Python del `.venv` (`PYTHON=...`). Con el `python3` del
sistema puede faltar `dowhy` y `humo` falla en silencio: esta es la única
trampa conocida del flujo en local.

Esto regenera: artefactos (estimacion, cobertura, sensibilidad, placebo),
**registra una nueva versión** (`v0010` en la corrida original), promueve el
campeón, reescribe `evidencia/*` y actualiza `evidencia/SHA256SUMS`.

**6.3** En `evidencia/SHA256SUMS` todo debe verificar; en `evidencia/07_servicio.txt`
la última línea debe ser `HUMO: OK`; en `09_pruebas.txt`, `PRUEBAS: OK`.

---

## Criterios de aceptación finales

1. `make pruebas` → `PRUEBAS: OK`.
2. `make cobertura-compuerta` → `COMPUERTA: PASA`.
3. La tarjeta del campeón declara `estimando_efectivo` (ej. "ATE en la
   población con solapamiento…").
4. El README enlaza la guía del método.
5. `make evidencia` completo en verde con el `.venv`.
6. Si tienes git: `git diff main..demo/mejora-paso-a-paso` reproduce
   exactamente esta guía (los 6 commits).

## Qué no se espera de ti

- Que estos números demuestren identificación: las compuertas y pisos son
  convenciones declaradas, no calibración ni garantía fuera de este DGP.
- Que la tarjeta o la puerta "verifiquen" ignorabilidad: declaran y hacen
  visibles los problemas; no los perdonan.
- Que uses esto para decidir nada real: sigue siendo docencia y benchmark
  sintético.
