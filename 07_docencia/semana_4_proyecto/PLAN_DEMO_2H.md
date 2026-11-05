# Plan de demostración — 2 horas (calibración y ensayo)

Objetivo: que el prototipo **se pueda mostrar en 10 minutos y se pueda auditar en 2 horas**,
sin que el tiempo se vaya en arreglar cosas que ya funcionan.

Hecho medido antes de planificar: el pipeline completo
(`make limpiar && SIC_ESCENARIO=real/ihdp make demo`) tarda **2,0 s**. Por tanto, el
presupuesto de 2 h no es de cómputo: es de ensayo, guion y recorte de alcance.

---

## 1. Protocolos aplicados (origen: mem0, `user_id=memo_enrique`)

| ID | Regla operativa | Aplicación aquí |
|---|---|---|
| **D06** | Condiciones de continuar / pivotar / detener definidas **antes**; revisar un umbral solo con justificación previa al desenlace | Puertas por bloque (§3) y regla de umbrales (§4) |
| **D02** | Separar **vetos** de compensaciones | Vetos: reproducibilidad, solape, integridad de hash. Compensables: estética, Docker, gráfico |
| **AC01** | Alcance, exclusiones y distinción actividad/resultado | §6 (fuera de alcance) |
| **AC03** | Un cambio se acuerda antes de ejecutarse | Cambiar tarjeta ⇒ versión nueva con hash (C-09), nunca edición en sitio |
| **R02 / E04** | Auditar enunciado, supuestos, casos límite; falsación severa | Los 5 checkpoints son la falsación: números esperados o no está terminado |
| **E03** | Fuentes copiadas no son evidencia independiente | Umbrales validados en ≥3 fuentes distintas (§5) |
| **DL04** | Ante prisa, reducir alcance antes que comprimir comprensión | Se recorta el acto 3 del guion, no la explicación del IC |
| **DoD** | Distinguir cierre de **auditoría** del cierre de **envío** | §7 |

---

## 2. Estado de partida (medido, no supuesto)

| Ítem | Estado |
|---|---|
| `make demo` (jobs) | 5/5 checkpoints idénticos a la salida esperada del notebook |
| `SIC_ESCENARIO=real/ihdp make demo` | verde: `pasa / alerta / falla`, `/efecto` 5,2, abstención 200 |
| Artefactos `ihdp` | `v0001` + `champion`; manifiesto recomputado `OK` |
| Notebook | ejecutado, 0 errores, 19 salidas, gráfico embebido |
| TODOs | 0 pendientes en los 8 módulos |
| Docker | CLI presente, **daemon colima caído** → no validado |
| Kernel `sic-estudiante` | **no registrado** en el entorno del usuario |

---

## 3. Agenda con puertas de salida

| Bloque | Min | Acción | Puerta (si falla) |
|---|---|---|---|
| **0. Congelar** | 0–10 | `make limpiar && SIC_ESCENARIO=real/ihdp make demo`; `shasum -c` del manifiesto | **STOP**: sin reproducibilidad no hay demo |
| **1. Ensayo A — `jobs`** | 10–30 | Los 5 checkpoints contra la salida esperada | Diferencia numérica ⇒ se documenta, no se "arregla" a ciegas |
| **2. Ensayo B — `ihdp`** | 30–50 | Mismo flujo con `SIC_ESCENARIO`; tres ventanas | Sin `falla` en positividad ⇒ revisar ventana, no el umbral |
| **3. Calibrar umbrales** | 50–70 | Clasificar cada umbral: convención vs decisión local | Sin justificación previa ⇒ se deja el valor actual |
| **4. Servicio** | 70–90 | `/efecto`, `/consulta` dentro/fuera, determinismo | Número en abstención ⇒ veto |
| **5. Guion 10 min** | 90–105 | Ensayo de los 4 actos (§8) | >12 min ⇒ recortar acto 3 |
| **6. Cierre** | 105–120 | Ensayo final desde limpio + tag + bitácora | — |

### Reglas de parada (D06)

- **30 min** sin reproducir ⇒ se cancela el resto del plan.
- **60 min** con un umbral sin justificar ⇒ se declara «no calibrado en esta sesión».
- **Docker**: solo si quedan ≥20 min y colima arranca en <3 min; si no, fuera de alcance.
- **Prohibido** ajustar un umbral después de ver la ventana que debería dispararlo.

---

## 4. Cómo se decide un umbral (en este prototipo)

1. **¿Es convención?** PSI ≥ 0,25 sí (con matiz: es punto de partida). SMD < 0,10 sí.
2. **¿Es decisión local?** `smd_max = 0,50` en `ihdp` **no** tiene literatura: se deriva de
   EE(SMD) ≈ √(1/191 + 1/257) ≈ 0,096 con 25 covariables; el máximo observado fue 0,43 y una
   ruptura real da 5,16. Se declara como decisión, nunca se cita como estándar.
3. **¿Se mueve?** Solo con motivo escrito **antes** del ensayo siguiente, y queda en la bitácora.

---

## 5. Validación externa de los criterios

| Afirmación | Fuentes | Veredicto |
|---|---|---|
| PSI: <0,1 estable · 0,1–0,25 moderado · ≥0,25 significativo | Coralogix; Fiddler; Arize («starting points, not universal law; calibrate the false positive rate») | Soportado con matiz: **es convención** |
| SMD < 0,10 (Austin); 0,25 como techo | PMC *Balance diagnostics* (Austin 2009); medRxiv; MetricGate | Soportado |
| Model card = uso previsto + limitaciones | Mitchell et al. 2019, arXiv 1810.03993 | Soportado |
| Timebox fijo, «artefacto = done» antes de empezar, cortar lo que pase de 2 h | Hackathon Playbook; Agile Alliance; simpliaxis | Soportado |
| `smd_max = 0,50` en `ihdp` | — | **Inferencia local**, no convención |

Referencias: coralogix.com/ai-blog (PSI) · fiddler.ai/blog · arize.com/glossary/population-stability-index-psi ·
pmc.ncbi.nlm.nih.gov/articles/PMC3472075 · arxiv.org/abs/1810.03993 · agilealliance.org (Definition of Done).

---

## 6. Fuera de alcance de la demo (declarado, no olvidado)

- Docker/despliegue (daemon caído; empaquetar no demuestra el argumento causal).
- Learners no lineales y repeated cross-fitting (proyecto final).
- Autenticación, persistencia, monitorización en vivo.
- CATE continuo o políticas: el corte es de dos hojas, y se dice en voz alta.
- `interventions.json` (contiene `ate`/`att`): no se abre en vivo; es el hueco de la pared.

---

## 7. Dos cierres distintos

| DoD **demo** | DoD **entrega** |
|---|---|
| 5 checkpoints en vivo · guion ≤12 min · abstención visible · 3 ventanas | Notebook ejecutado · 22 TODOs · artefactos `v0001` con manifiesto · `BITACORA.md` · tags |

---

## 8. Guion de 10 minutos

| Acto | Min | Se muestra | Se declara |
|---|---|---|---|
| 1. Pregunta y pared | 1 | `pregunta_ihdp.md`; `truth_*.csv` ausente | Qué NO afirma el prototipo |
| 2. Efecto con incertidumbre | 3 | AIPW 5,2 [3,9; 6,4] vs OLS 4,8; trampa −0,1 | El IC cubre el ATE, no un niño |
| 3. Puerta causal | 3 | sana `pasa`, deriva `alerta` (PSI `bw` 0,88), positividad `falla` (solape 0 %) | Alerta ≠ reentrenar ya |
| 4. Abstención y bundle | 3 | `/consulta` fuera de rango → 200 sin número; `champion → v0001` con hash | «No sé» es respuesta de primera clase |

---

## 9. Riesgos y mitigación en sesión

| Riesgo | Mitigación |
|---|---|
| Kernel `sic-estudiante` inexistente | Registrarlo antes del bloque 5 (1 min) |
| `SIC_ESCENARIO` ≠ artefactos en disco | Un escenario por ensayo; `make limpiar` al cambiar |
| `requirements.txt` incompleto para notebook | Ya corregido (matplotlib + ipykernel) |
| Docker | Colima caído ⇒ fuera de alcance, declarado |
| Tiempo | Puertas de 10 min por bloque; el recorte es de alcance, no de claridad |
