# Calibración de mem0 — caso de prototipo causal (semana 4)

Fecha: 2026-11-04 · Fuente: `sistema-inteligencia-causal-estudiante`, rama `semana4/proyecto`,
tag `v1.0.0` · Documentación de respaldo: `BITACORA.md` §8 y §15, `GUIA_CONSTRUCCION.md`.

**Resultado:** el prototipo se considera un **ejemplo aceptable** de artefacto causal local.
**No se modifica ninguna memoria de método**: la evidencia es de un solo proyecto. Se registra
un único **caso de éxito** que enumera las condiciones que lo hicieron aceptable.

Criterios aplicados (acordados): regla con el caso como soporte · un proyecto no modifica
memorias de método · sin cifras · sin plomería · una memoria consolidada · spec antes de
escribir en la plataforma · fidelidad al caso por encima de la generalidad.

---

## B1 · Alta — caso de éxito: prototipo causal aceptable (servicio local)

- **Antes:** (sin memoria de un prototipo causal completo y aceptable).
- **Después:** memoria de caso con las condiciones de aceptabilidad:
  estimando declarado antes de mirar los datos y pregunta alineada con él; intervalo que
  declara qué cubre; corte de heterogeneidad pre-declarado en la tarjeta y no elegido por
  ganancia; umbrales clasificados como convención o decisión local, con motivo previo;
  abstención como respuesta de primera clase, sin número; versión inmutable con manifiesto y
  promoción atómica; y proyección individual publicada con su ajuste, sin presentarse como CATE.
- **Evidencia:** `BITACORA.md` §15 (tabla de componentes y límites declarados); `v1.0.0`.
- **Estatus:** caso empírico de un proyecto. **No** asciende a `formal_result` y **no**
  modifica memorias de método.

### Texto propuesto para `mem0 add`

> Prototipo causal local aceptable (semana 4, ECO-490): servicio que estima un ATE con IC,
> publica tarjeta con supuestos clasificados, versiona artefactos con hash y se abstiene fuera
> de soporte. Se consideró aceptable porque el estimando se declara antes de mirar los datos y
> la pregunta está alineada con él; el intervalo declara qué cubre; el corte de heterogeneidad
> está pre-declarado en la tarjeta y no se eligió por ganancia; cada umbral se clasifica como
> convención o decisión local con motivo previo; la abstención es respuesta de primera clase
> sin número; la versión es inmutable con manifiesto y promoción atómica; y una proyección
> individual se publica con su ajuste, sin presentarse como CATE. Estatus: caso empírico de un
> proyecto; no modifica memorias de método.

---

## B2 · Sin cambio — memorias evaluadas y descartadas

| Memoria | Por qué no se toca |
|---|---|
| `f23cf73b` PSI | Su formulación crítica ya advierte que 0,1/0,25 no tienen fundamento teórico. La lección (el PSI no distingue deriva de colapso de soporte) queda dentro del caso B1, no en la memoria de método. |
| `321056bd` SMD / ASMD | La recalibración por escenario es una decisión del caso, no una propiedad del diagnóstico. |
| `5aa8fc92` API (FastAPI + Docker) | Plomería: contingencia del despliegue, no conocimiento causal. Vive en `GUIA_CONSTRUCCION.md` §10.2. |
| `671a10f5` Despliegue como servicio | Igual: el caso la ejemplifica, no la corrige. |
| `2e1aa70c` Model cards causales | Los campos concretos son del prototipo; la memoria ya fija el concepto. |
| `4cbe30cf` D06 umbrales y parada | El caso la **aplica**, no la reformula. |
| `aa3b0b18` E03 triangulación | El caso es un ejemplo de uso. |
| `f4c435a6` DoD auditoría ≠ envío | Sin cambio; el prototipo separó ambos cierres como la memoria indica. |

---

## B3 · Descartado explícitamente

- Cifras del proyecto (ATE, R², PSI, ESS): envejecen y no sostienen criterio. Quedan en el repo.
- Trampas de empaquetado (rutas resueltas en import, módulo no copiado, permisos, validación
  del formulario): contingencia; documentadas en `BITACORA.md` §11 y en la guía.
- Ascender cualquier entrada a `formal_result`: no hay derivación teórica, solo un caso.

---

## Aplicación (pendiente de autorización)

```sh
mem0 add "<texto de B1>" -u memo_enrique -m '{"tipo":"caso","proyecto":"semana4-causal","estatus":"empirico_caso_unico"}'
```
