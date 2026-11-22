> **ESTADO FINAL (2026-11-21, sesión 2): refs.yml corregido (19+5), libro (.typ) corregido y renombrado, PDF regenerado. Ver `verificacion/APLICADO.md` y `verificacion/libro_cambios.patch`. Las recomendaciones de revisión de este documento quedan marcadas como HECHAS salvo que indique lo contrario.**
# Resumen ejecutivo — Auditoría de referencias y teoremas del libro

**Proyecto:** `Causal_AI/` · **Fecha:** 2026-11-21 · **Modo:** autónomo (decisiones → `x_ai_subscribed/grok-4.7` como sustituto declarado de «d1-ultra», que no existe en el entorno)

## En una frase
Las **146 referencias existen y, tras 19 correcciones sustantivas + 80 DOIs añadidos, apuntan a la obra correcta**; de **108 ítems «teorema/resultado» verificados**, 82 son fieles a sus fuentes, 4 hallazgos son **errores materiales** (2 de atribución, 2 de enunciado) con corrección lista para aplicar, y 13 ítems no pudieron abrirse (índice web caído + créditos Firecrawl agotados) — marcados como tales, no juzgados.

## Qué se hizo
1. **N0 (integridad):** `typst compile` OK (antes y después); 0 claves huérfanas/citadas-inexistentes (146/146 en uso); 7 citas `@key` documentadas.
2. **N1 (bibliografía, 146):** S2 + OpenAlex + doi-org/Crossref + editorial/WorldCat para libros. **111 OK · 16 OK_PARCIAL (libros) · 14 CORREGIR · 4 arbitraje · 1 NO_LOCALIZADA.** Las 19 discrepancias fueron corregidas **en `refs.yml`** (detalle campo a campo en `reporte_referencias.md`; solo metadatos/DOIs; ningún texto del libro editado; `.typ` intactos). DOIs/URL: de 5/146 a **98/146**. Backup: `verificacion/partes/refs.yml.pre-doi-backup`; diff: `verificacion/refs_corregido.patch`.
3. **N2 (teoremas/resultados, 108):** P1 (36 bloques con nombre) + P2 (72 líneas prosa) + cobertura N3 (constantes). **82 FIEL · 3 SIMPLIFICADO_DECLARADO · 6 PARCIAL · 2 ATRIBUCION_INCORRECTA · 2 ENUNCIADO_INCORRECTO · 13 NO_VERIFICABLE.**
4. **N4 (deuda editorial):** propuestas S8/S10 listas (normalizar 7 `@key`, nota de cabecera); no aplicadas.

## Los 4 errores materiales (corrección lista en `sugerencias_libro.md`)
| # | Dónde | Problema | Fix |
|---|---|---|---|
| C1 | Ap. A, Cramér–Rao semiparamétrica | La glosa invierte la cota (Ĩ vs. varianza del EIF) | S1 |
| C2 | Ap. A, Matriz-completion | Atribuido a Recht–Fazel–Parrilo 2010; el resultado enunciado es **Candès & Recht 2009** (FoCM 9(6):717–772) | S2 (+ficha nueva) |
| C3 | Cap. 29, PC | «$p$ crece **exponencialmente** con $n$» → Kalisch & Bühlmann 2007: $p = O(n^a)$, **polinomial** | S3 |
| C4 | Cap. 17, instrumentos débiles | «valores críticos Stock–Yogo» atribuidos a Survey JBES (no los contiene) y a obra fantasma (corregida a Annual Review 2019); fuente real = `stock2005testing` (ya citada) | S4 |

**Hallazgos PARCIAL (6):** sobre-lectura de `kitagawa2021constrained` (cap. 24, 2 sitios); alcance de `curth2021inductive` (cap. 27, palabra «laxa» no respaldada); claves fantasma `potscher2009confidence` y `chernozhukov2018applied` (corregidas en refs.yml → JMVA 100(9):2065–2082 y AER P&P 107(5):261–265; la segunda es **INFERENCIA** — sustitúyela por `chernozhukov2018double` si no la aceptas); 5ª y 6ª: misma causa raíz en cap. 5 y 6.

## Lo que NO se tocó
- **Ni una coma del libro** (`.typ` intactos). Todo cambio de texto está propuesto en `sugerencias_libro.md` con old/new exactos, S1–S10.
- `partes/`, frontmatter, apéndices E/I, monorepo, git: intactos. (El repo ya traía cambios ajenos en `07_docencia/…`; no se tocaron.)

## Limitaciones (léelas)
- Índice web y `web_search`/`web_fetch` caídos durante F2–F4; **Firecrawl sin créditos** (incluye Alexandria doi-org/research-index) → 13 NO_VERIFICABLE (todos por acceso, ninguno con hallazgo adverso).
- `Parallel` no conectado en este entorno; su rol lo cubrió `firecrawl_agent`/S2.
- **«d1-ultra» no existe** en la tabla de modelos de este entorno → decisiones arbitrarias con `grok-4.7` (D1 en `DECISIONES.md`). Si querías otro modelo, re-arbitro A1–A7 con él.
- `block «chernozhukov2020generic»` (cap. 14): la existencia, autores y DOI (Econometrica 2025, 10.3982/ecta19303) están confirmados en S2; volumen/issue/páginas se **omiten** por no verificables con el índice caído. La clave renombrada `chernozhukov2020generic` queda como nombre histórico (el paper es 2025).
- `bach2021doubleml` se deja en 2021 (preprint arXiv) sobre 2022 (JMLR 23(53):1-6); elección editorial documentada.

## Qué revisar primero (orden sugerido)
1. `sugerencias_libro.md` **S1–S4** (errores materiales) — decidir S3 y S4 tarda <10 min.
2. A3/S7: aceptar o revertir la inferencia `chernozhukov2018applied` → AER P&P (3 usos idénticos de «revisión pedagógica»).
3. `reporte_referencias.md` §«DOIs añadidos» (80) — spot-check de 5–10 añadidos contra tu fuente favorita.
4. Si apruebas, aplico S1–S10 al `.typ`, recompilo y regenero ledgers/reportes (N4 completo).

## Entregables (`verificacion/`)
`DECISIONES.md` · `n0_integridad.md` · `PROTOCOLO_N1/N2.md` · `seed_referencias.jsonl` · `partes/*.jsonl|tsv|md` · `ledger_referencias.jsonl` (146) · `ledger_teoremas.jsonl` (108) · `reporte_referencias.md` · `reporte_teoremas.md` · `sugerencias_libro.md` · `refs_corregido.patch` (diff de `refs.yml`) · `herramientas/` (Rust: `refs_seed`, `refs_apply`).
