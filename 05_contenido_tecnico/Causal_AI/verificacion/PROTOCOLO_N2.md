# PROTOCOLO N2 — Verificación de teoremas y resultados (sub-agentes)

Contexto: libro «Sistema de Inteligencia Causal» (Typst). Debes verificar si los
**enunciados** de los teoremas/proposiciones del libro son fieles a las fuentes primarias
que el libro cita, y si la **atribución** (autor/obra) es correcta.

## Archivos que debes leer primero

1. `verificacion/semilla_enunciados_p<N>.md` — la lista de tus ítems (archivo:línea y nombre).
2. `verificacion/seed_referencias.jsonl` — metadatos originales de refs.yml.
3. `verificacion/partes/n1_parte00.jsonl` … `n1_parte05.jsonl` — **veredictos N1 ya auditados**.
   Para cualquier fuente que N1 haya corregido (p. ej. `leeb2006can` ahora = *Annals of Statistics*
   34(5):2554-2591, DOI 10.1214/009053606000000821; `robins1995semiparametric` ahora = JASA 90(429):122-129,
   DOI 10.1080/01621459.1995.10476494), usa **los datos verificados por N1**, no los de refs.yml.
4. El `.typ` indicado en cada ítem (lee el bloque completo y su párrafo circundante).

## Procedimiento por ítem

1. Extrae el enunciado exacto (condiciones + tesis + tasas/constantes).
2. Identifica la fuente: cite keys dentro del bloque o en el mismo párrafo/sección.
3. Localiza la fuente primaria:
   - `semantic_scholar_get_paper` (con el DOI o paperId de N1) → abstract + externalIds.
   - Si es arXiv / PubMed-indexado: `firecrawl_research_search_papers` + `firecrawl_research_read_paper`
     (pergunta dirigida: «What are the conditions and rate/bound of <theorem name>?») o
     `semantic_scholar_snippet_search(query=...)`.
   - Econ journals: `web_search`/`web_fetch` sobre manuscripts (NBER, CEMMA, university sites),
     paginas de la editorial, o `archive.org` para libros.
   - Libros (Imbens–Rubin, Hernán–Robins, Bickel et al., Pearl): verifica el enunciado contra la
     edición citada vía Google Books/WorldCat/extracto del editor; si no hay acceso, verifica la
     atribución con ≥2 fuentes secundarias autoritativas (p. ej. surveys por los propios autores) y
     marca `NO_VERIFICABLE_ENUNCIADO` (la atribución sí puede quedar FIEL).
   - Resultados clásicos sin cite (LGN, TCL, Slutsky): cualquier texto serio de estadística
     asintótica sirve; confirma que el enunciado del libro no contradice la teoría.
4. Emite veredicto (uno por ítem):
   - `FIEL` — enunciado correcto y completo respecto a la fuente (o el libro declara simplificación
     y es honesto en lo que omite).
   - `SIMPLIFICADO_DECLARADO` — el libro dice explícitamente «esquema/versión simplificada» y la
     omisión de hipótesis es razonable para el público.
   - `PARCIAL` — omite hipótesis/tasas esenciales y NO lo declara, o diluye la tesis.
   - `ATRIBUCION_INCORRECTA` — el resultado se debe a otra obra/autor que la citada.
   - `ENUNCIADO_INCORRECTO` — condiciones, tesis, tasa o constante mal transcritas (error material).
   - `NO_VERIFICABLE` — sin acceso suficiente a la fuente para juzgar (paywall total, libro sin extracto).
5. Sé estricto con tasas y constantes (p. ej. O_p(n^{-1/2}), cotas VC, dimensión de cubierta,
   velocidades (log n)^{...}, constantes de EIF). Si el libro difiere de la fuente en una tasa, es
   `ENUNCIADO_INCORRECTO` o `PARCIAL` según magnitud, y lo explicas.

## Salida

Escribe `verificacion/partes/n2_parte<N>.jsonl`: una línea JSON por ítem:

```json
{"item":"<archivo:línea>","name":"<nombre del bloque>","source_key":"<cite_key o 'clasico'>","verdict":"FIEL|SIMPLIFICADO_DECLARADO|PARCIAL|ATRIBUCION_INCORRECTA|ENUNCIADO_INCORRECTO|NO_VERIFICABLE",
 "issue":"<qué se omite/deforma o ''>","correct":"<enunciado correcto según la fuente o ''>",
 "evidence":["<url o doi o s2_paperId>", "..."],"confidence":"alta|media|baja","notes":"<2 frases máx>"}
```

## Prohibido

- Editar archivos del repo que no sean tu `n2_parte<N>.jsonl`.
- Dar `FIEL` sin haber abierto al menos el abstract (o el pasaje full-text) de la fuente.
- Rellenar huecos con tu memoria: si no lo encontraste, `NO_VERIFICABLE`.
- Inventar URLs en `evidence`.

## Al terminar

Resumen ≤10 líneas: ítems procesados, conteo por veredicto, y los juicios delicados
(cualquier ATRIBUCION_INCORRECTA / ENUNCIADO_INCORRECTO / PARCIAL) con una línea de por qué.
