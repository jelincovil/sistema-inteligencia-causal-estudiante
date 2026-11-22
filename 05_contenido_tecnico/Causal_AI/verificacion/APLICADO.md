# APLICADO — Cambios ejecutados en el libro (sesión 2, 2026-11-21)

Tras la aprobación del usuario («apply the changes that are possible and more. Also, change the title»), se aplicaron **todas** las correcciones propuestas y el cambio de título.

## 1. Correcciones críticas (antes C1–C4)

| # | Archivo | Aplicación |
|---|---|---|
| C1 | `apendices/apA_notacion_fundamentos.typ:105` | Ley de Cramér–Rao semiparamétrica reescrita: cota = varianza del EIF, $tilde(I)_theta = E[tilde(S)tilde(S)^top]$ |
| C2 | `apendices/apA_notacion_fundamentos.typ:142` | Atribución corregida a **Candès y Recht, 2009**; bloque cita `#cite(<candes2009exact>)` |
| C3 | `capitulos/cap29_descubrimiento_grafos.typ:64` | «$p$ crece exponencialmente» → «polinomialmente ($p = O(n^a)$, $a>0$ arbitrario), nunca de forma exponencial» |
| C4 | `capitulos/cap17_panel_dmliv.typ:133` | Tablas Stock–Yogo → `stock2005testing`; Kleibergen y Paap → `kleibergen2002pivotal` (Econometrica 70(5), DOI 10.1111/1468-0262.00353, verificado); `stock2002survey` conserva uso como «diagnóstico clásico» |

## 2. PARCIAL corregidos

- `cap24_etica_interpretabilidad.typ` (dos sitios): alcance de `kitagawa2021constrained` precisado (garantías específicas por clase de restricción; costo en welfare «asociado a la restricción elegida/impuesta»).
- `cap27_deep_causal.typ:310`: palabra «*laxa*» respaldada con cita directa a `curth2021nonparametric` (AISTATS 2021, DOI 10.48550/arXiv.2101.10943, verificado en S2).

## 3. Normalización de citas `@key` → `#cite` (S8)

`cap25:299` (Berger), `cap06:73` (Elastic Net), `cap11:86/:157/:328` (Robins, Kish, Angrist), `cap05:370` (Aronow), `cap17:372` (Freyaldenhoven). Después: **0 claves citadas vía `@key`** (consistencia total `#cite`).

## 4. Referencias nuevas añadidas a `refs.yml` (todas citadas; 0 huérfanas)

| Clave | Obra | Verificación |
|---|---|---|
| `candes2009exact` | Candès & Recht, FoCM 9(6):717–772, 2009 | S2 (6503 citas) |
| `curth2021nonparametric` | Curth & van der Schaar, AISTATS 2021 | S2 |
| `vandegeer2008high` | van de Geer, Ann. Statist. 36(2):614–645, 2008 | S2 (791 citas, OA en Project Euclid) |
| `hahn1998role` | Hahn, Econometrica 66(2):315–331 (páginas a confirmar), 1998 | S2 (DOI 10.2307/2998560) |
| `kleibergen2002pivotal` | Kleibergen, Econometrica 70(5):1781–1803, 2002 | S2 (DOI 10.1111/1468-0262.00353) |

Claves nuevas cableadas en el texto: S1/S6/cap06/cap11/cap17 (ver ledger en el propio `.typ`).

## 5. Renombrado del libro
**Título nuevo:** «Contenido teórico y técnico para implementar causal AI»
- `template/template.typ`: portada (4 líneas, 44 pt), `set document(title: …)`, comentario de cabecera.
- `frontmatter/colofon.typ`, `main.typ` (comentarios), `bibliografia/refs.yml` (comentario de encabezado).
- **No** se renombró `main.pdf` ni la ruta `Causal_AI/` (estabilidad de enlaces); PDF regenerado con el título nuevo (compila limpio en modo curso y comercial).
- `verificacion/*.md` conservan el nombre anterior en referencias históricas al libro.

## 6. Validación
- `typst compile main.typ` → exit 0 (modo curso, 7.77 MB) · `typst compile --input modo=comercial` → exit 0 (7.62 MB).
- `refs_seed`: 151 entradas, 103 con DOI, 1 con URL, 0 claves huérfanas (verificado por script sobre todos los `.typ`).
- Patch del delta completo (sin PDF): `verificacion/libro_cambios.patch` (1172 líneas, reverse-check OK).

## 7. Resaltado
- Cuerpo del libro (`.typ`): **modificado** (por primera vez en la auditoría). Docs de auditoría actualizadas: `DECISIONES.md` D15–D17, este archivo; señal en `sugerencias_libro.md`.
- La inferencia **A3** (`chernozhukov2018applied` → AER P&P 107(5):261-265, 2017) quedó aplicada desde la sesión 1 y no se ha tocado; sigue marcada INFERENCIA confianza media — sustituible por `chernozhukov2018double` si el autor la rechaza.
- No verificado (se mantiene): 13 ítems NO_VERIFICABLE (índice web caído + créditos Firecrawl agotados).
- Páginas de `hahn1998role` no confirmadas (S2 no las muestra); el resto de metadatos de las 5 entradas nuevas están verificados.
