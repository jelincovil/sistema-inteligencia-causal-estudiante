# Log de decisiones autónomas (modo «aplica el plan de inicio a fin»)

Decisiones tomadas sin consultar, con su justificación. El usuario pidió: «de inicio a fin de
manera autónoma; si tienes que tomar decisiones usa d1-ultra».

## D1 — «d1-ultra» no existe en este entorno
La tabla `list_agents_and_models` solo expone Zed Agent con estos modelos:
DeepInfra/Qwen/Qwen3-VL-235B-A22B-Instruct, DeepInfra/zai-org/GLM-5.3-Flash,
DeepInfra/moonshotai/Kimi-K2.7-Code, Liquid/LFM2.5-24B-A2B,
Open Math OS/moonshotai/kimi-k3.1-pro, thinkingmachines/inkling-2-small (actual),
x_ai_subscribed/grok-4.5/4.6/4.7, x_ai_subscribed/grok-build-0.1.
**Decisión:** usar `x_ai_subscribed/grok-4.7` como árbitro externo de decisiones ambiguas
(veredictos `VERIFICAR_MANUAL`, posibles `ATRIBUCION_INCORRECTA`/`ENUNCIADO_INCORRECTO`).
Si el usuario se refería a otro modelo/producto, se re-arbitra con él.

## D2 — Alcance de ediciones
Nada de reescritura de prosa del libro. Solo: (a) correcciones de **metadatos** en
`refs.yml` con doble fuente coincidente (o DOI árbitro), (b) adición de DOIs encontrados.
Todo lo demás queda como informe + `.patch` propuesto. Revertir es trivial (git).

## D3 — Fuentes de verificación y coste
Orden fijo: Semantic Scholar (gratis, match_paper→get_paper; bulk_papers para IDs) →
OpenAlex vía `web_fetch`/`firecrawl_scrape` (gratis, cross-check; solo si S2 falla/duda) →
`doi-org` Alexandria (solo 4 DOI; billed por llamada, ~4 llamadas) →
`web_search`/`web_fetch` para libros/clásicos/editoriales (gratis) →
`firecrawl_scrape` como último recurso (presupuesto ≤ 50 créditos).
Parallel (parallel.ai) **no está conectado** en este entorno; su rol lo cubren Firecrawl +
los providers Alexandria. Se declara; si se conecta, se re-ejecuta el tramo correspondiente.

## D4 — Particionamiento
N1: 6 sub-agentes × ~25 entradas, cada uno escribe `verificacion/partes/n1_parte<N>.jsonl`.
N2-P1: 3 sub-agentes × ~12 bloques nombrados/apA. N2-P2: 3 sub-agentes × ~24 líneas prosa.
N2-P3 (definiciones/supuestos sin atribución): chequeo local por el agente principal.
N3 (constantes numéricas): 1 sub-agente, al final, solo sobre los ítems ya verificados.
Los sub-agentes tienen **prohibido** editar `refs.yml`/`*.typ`; único output: su JSONL/MD.

## D5 — Umbral de confirmación (refs)
`OK` = título equivalente + año ±1 + ≥1 autor (apellido) coincide + venue compatible.
`CORREGIR` = misma obra inequívoca con metadatos distintos (se propone fix exacto).
`OK_PARCIAL` = libro/web confirmado (autor/año/editorial) sin datos de páginas.
`VERIFICAR_MANUAL` = fuentes discrepan u obra ambigua → arbitraje grok-4.7.
`DUPLICADA` = misma obra en 2 claves. `NO_LOCALIZADA` = sin match creíble → alta severidad.

## D6 — Deliverables
`verificacion/{n0_integridad.md, seed_referencias.jsonl, partes/*.jsonl,
ledger_referencias.jsonl, ledger_teoremas.jsonl, reporte_referencias.md,
reporte_teoremas.md, resumen_ejecutivo.md, refs_corregido.patch}`.

## D7 — Aplicación de cambios
Tras N4: aplicar a `refs.yml` solo D2(a)-(b) con evidencia; recompilar Typst; reportar.
La prosa del libro **no se edita**. El patch queda además guardado para revisión.

## D8 — Correcciones aplicadas a `refs.yml` (autónomo)
Se aplicaron: (a) 80 inserciones de `doi:` de alta confianza (`refs_apply`; `plecko2024causal` ya traía DOI en `serial-number.doi` y se dejó intacto); (b) 19 correcciones sustantivas dirigidas (NEYMAN volume 5→10; autores Chernozhukov–Escanciano–Ichimura–Newey–Robins 2016; robins1995 título/issue/DOI; leeb2006 venue/vol/issue/pages/DOI; gutierrez PMLR; schuler autores/DOI; kastner autor único + 2025; crump título/issue/pages/DOI; imbens2003 venue/vol/issue/pages/DOI; leicandes venue/vol/issue/pages/DOI; lei2018 título/DOI; manski pages; stock2002 venue/vol/issue/DOI; yadlowsky arXiv id; andrews2019robust obra fantasma→AER:Economics 2019; aronow year 2019; chernozhukov2018applied obra fantasma→AER P&P 107(5) (INFERENCIA, confianza media); potscher2009confidence→JMVA 100(9); chernozhukov2020generic autores/título/Econometrica/2025/DOI con vol-issue-pages omitidos por no verificables). `.typ` NO editados; sugerencias en `sugerencias_libro.md`.

## D9 — Caída del índice web (F2 en adelante)
`web_search`/`web_fetch` devolvieron "server shut down" de forma persistente; Firecrawl sin créditos (incluye doi-org Alexandria). Se degradó la verificación a S2 + DOIs ya confirmados; 13 ítems quedaron NO_VERIFICABLE (todos por acceso, ninguno por hallazgo adverso). N2-prosa-A se re-ejecutó tras la reanudación parcial de la web: 13 FIEL / 11 NO_VERIFICABLE.

## D10 — A3 aplicado como INFERENCIA
La obra literal "Applied Causal Inference Inspired by Machine Learning" no existe (S2, OpenAlex, arXiv, Crossref). Grok 4.7 propuso AER P&P 107(5):261-265 (2017), DOI 10.1257/aer.p20171038 (autores idénticos; encaja con el uso "revisión pedagógica"). Se aplicó a refs.yml marcándolo INFERENCIA (confianza media). Reversible: restaurar entrada y cambiar 6 usos a `chernozhukov2018double` (ver sugerencias_libro.md S7).

## D11 — Error YAML detectado y corregido en la propia auditoría
La corrección A4 introdujo un título con `: ` sin comillas → Hayagriva no parseaba. Corregido (comillas) y re-verificado `typst compile` OK. Aprendizaje: `refs_apply` inserta `doi:` con comillas siempre; las ediciones manuales de títulos con «:» van entre comillas.

## D12 — Typst recompilado tras cada cambio
baseline (OK) → tras 80 DOIs (OK) → tras ediciones sustantivas + fix YAML (OK, PDF ~7.75 MB). Conteo de wikis sin cambios semánticos esperados (solo metadatos).

## D13 — Ledgers y backup
`ledger_referencias.jsonl` (146) y `ledger_teoremas.jsonl` (108) en `verificacion/`. Backup de refs.yml previa a DOIs: `verificacion/partes/refs.yml.pre-doi-backup`. Diff completo: `verificacion/refs_corregido.patch`.

## D14 — Cambios ajenos preexistentes en git
El repo arrastra modificaciones masivas en `07_docencia/…`, `.gitignore`, `README.md`, `LICENSE` (de sesiones previas; ya presente antes de esta tarea). NO se tocaron. La auditoría solo modifica `bibliografia/refs.yml` y crea `verificacion/`.

## D15 — Renombrado del libro
Título nuevo: «Contenido teórico y técnico para implementar causal AI». Aplicado en template.typ (portada + set document + cabecera), colofon.typ, main.typ y bibliografia/refs.yml encabezado. Ruta del directorio y nombre de archivo main.pdf sin cambios (estabilidad de enlaces); PDF regenerado en ambos modos (curso/comercial), ambos exit 0.

## D16 — Añadidos a refs.yml (5 entradas, todas citadas)
candes2009exact (FoCM 2009, verificada, DOI 10.1007/s10208-009-9045-5), curth2021nonparametric (AISTATS 2021, DOI 10.48550/arXiv.2101.10943, verificada en S2), vandegeer2008high (Ann. Statist. 36(2), DOI 10.1214/009053607000000929, verificada), hahn1998role (Econometrica 66(2), DOI 10.2307/2998560, verificada; páginas omitidas), kleibergen2002pivotal (Econometrica 70(5):1781-1803, DOI 10.1111/1468-0262.00353, verificada; corrige un DOI erróneo que aparecía en borradores de este log). Re-verificación de huérfanas sobre 151 entradas: 0.

## D17 — Ediciones del cuerpo (.typ)
S1, S2, S3, S4, S5, S6, S8 aplicadas literalmente según sugerencias_libro.md (con la variante S4 de conservar stock2002survey como «diagnóstico clásico» para no orfanar la obra; stock2005testing toma la atribución de las tablas). .typ del libro modificado. Reportes de auditoría conservan el estado pre-aplicación como registro histórico; estado final en APLICADO.md.
