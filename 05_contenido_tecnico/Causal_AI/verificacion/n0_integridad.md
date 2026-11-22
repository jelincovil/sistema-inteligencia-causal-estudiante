# N0 — Integridad interna (automático)

**Fecha:** 2026-11-21 · **Alcance:** `bibliografia/refs.yml`, citas en `.typ`, compilación Typst.

## Resultados

| Chequeo | Resultado |
|---|---|
| `typst compile main.typ` (baseline) | ✔ compila, sin errores ni warnings |
| Entradas en `refs.yml` | 146 (129 article, 14 book, 2 chapter, 1 web) |
| Claves duplicadas en `refs.yml` | 0 (parseo por clave; `refs_seed` ok) |
| Campos obligatorios Hayagriva (`type`, `title`, `date`, `author`) | 146/146 presentes |
| Claves citadas usadas en el texto | 146/146 (0 huérfanas) — `#cite` 286 usos / 139 claves únicas + 7 citas `@key` (angrist1991, aronow2017, berger1985statistical, freyaldenhoven2021local, kish1965, robins1994estimation, zou2005elasticnet) |
| Claves citadas ausentes de `refs.yml` | 0 ✔ |
| Tokens `@…` totales en `.typ` | 196 → 189 son etiquetas internas de Typst (`@cap-*`, `@sec-*`, verificadas por el compilador), 7 son citas `@key` |
| DOIs en `refs.yml` | 4 (`kastner2024mlip` es `type: web` con URL, no DOI) — verificación por DOI cubre solo el 2.7 % |
| URLs en `refs.yml` | 1 (`kastner2024mlip` → https://mlip-cmu.github.io/book/) |
| Entornos formales | 73 = 28 `#theorem` + 11 `#proposition` + 24 `#definition` + 8 `#assumption` + 2 `#example` |
| …con atribución explícita en `name:` | 24 (→ N2-P1) |
| Líneas prosa con palabra de resultado + `#cite` | 72 (→ N2-P2) |
| Apéndice A con teoremas clásicos enumerados | 11 bloques (→ N2-P1) |
| `refs_seed` (Rust, std-only) | `verificacion/seed_referencias.jsonl` (146 líneas) |

## Consecuencias para N1–N4

1. La verificación bibliográfica depende de **matching por título/autores/año**, no de DOIs: prioridad a Semantic Scholar (match_paper/get_paper) y OpenAlex como cross-check; `doi-org` solo para los 4 DOI.
2. Los libros (14) se verifican contra editoriales/WorldCat/Google Books vía `web_search`/`web_fetch` (sin coste), no contra S2 (cobertura pobre de libros).
3. Las 7 citas `@key` se normalizarán a `#cite(<key>)` como parte de N4 **solo si el usuario lo aprueba** (parche propuesto, no aplicado por defecto).
4. El comentario de cabecera de `refs.yml` afirma "0 huérfanas": **verificado, es correcto**.
