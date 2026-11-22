# Evaluación de `02_causal AI en produccion` y plan de transformación en libro publicable

*Evaluación hecha sobre la fuente Typst y el PDF compilado (2026-11).*

---

## 1. Qué es hoy (verificado)

| Dimensión | Valor |
|---|---|
| Extensión | 452 páginas A4, ~142 000 palabras |
| Estructura | 33 capítulos en 9 partes + 10 apéndices + frontmatter completo |
| Motor | Typst 0.15.1, template propio de 893 líneas |
| Bibliografía | ~150 entradas Hayagriva, 37 de 2020 en adelante |
| Ediciones | Tres modos desde una sola fuente: `curso`, `comercial`, `principios` |
| Aparato | Teoremas/definiciones/lemas con numeración por capítulo; algoritmos estilo algorithm2e; cajas (cuadro sinóptico, decisión, riesgos, diagnósticos, nota técnica, intuición, frontera); contratos numerados C-01…C-08; casos canónicos con DGP explícito |
| Capas de contenido | L0 teoría · L1 pseudocódigo · L2 principios y contratos · L3 implementación (se retira en modo `principios`) |

El diseño editorial es inusualmente serio para una monografía de curso: separación de vida útil por capas, contratos con prueba de aceptación, control de referencias por capítulo y una plantilla con decisiones tipográficas documentadas.

## 2. Evaluación

### 2.1 Fortalezas (conservar intactas)

1. **Posicionamiento diferencial real.** El puente identificación → estimación → puerta causal → servicio → monitoreo con filosofía de abstención honesta no lo cubre ningún libro publicado: Hernán & Robins y Pearl no llegan a producción; Chernozhukov et al. no hacen MLOps; Huyen hace MLOps sin causalidad. El nicho existe y el libro ya lo ocupa.
2. **Discusión estadística de alto nivel donde importa.** El Cap. 11 no comete los pecados habituales: distingue PLR/IRM/PLIV como estimandos distintos, interpreta Card (1995) como LATE con las dos explicaciones sustantivas alternativas explícitas, cuantifica ESS de Kish y trimming de Crump, y advierte que el estimando post-trimming no es el ATE poblacional. Eso es mejor que muchos textos publicados.
3. **Aparato pedagógico-editorial reutilizable** (capas, contratos, casos canónicos, invariantes verificables del cross-fitting).
4. **Bibliografía canónica y razonablemente actual** (Neyman, Rubin, Pearl, Chernozhukov, Wager/Athey, Crump, Card, Angrist; 37 entradas ≥2020).
5. **Sistema multi-edición** que ya separa el libro del curso sin duplicar fuentes.

### 2.2 Debilidades (lo que separa hoy este texto de un libro riguroso publicado)

1. **Rigor matemático desigual.** ~9 demostraciones en 33 capítulos y 0 en apéndices. Los teoremas se enuncian sin condiciones de regularidad precisas y sin prueba ni referencia exacta. Dos ejemplos del Cap. 11:
   - *Teorema «Doble robustez + ortogonalidad»*: «si $\hat\mu$ o $\hat e$ es consistente (no necesariamente ambos), $\hat\theta$ es consistente» — verdad que requiere condiciones adicionales (consistencia *a tasa* del otro nuisance y del estimador plug-in) que el enunciado omite.
   - *Teorema «Eficiencia semiparamétrica»*: afirma eficiencia asintótica sin enunciar las condiciones bajo las que vale (regularidad del modelo, convergencia de ambos nuisance).
2. **Carencia gráfica severa.** 6 figuras PNG raster y 1 diagrama Fletcher en 452 páginas. Un libro de esta materia necesita DAGs por capítulo, geometría de la ortogonalidad, curvas Qini/uplift, arquitecturas de red (cap. 27), etc. Hoy casi todo el contenido visual son tablas de números.
3. **Números sin procedencia reproducible.** Los casos canónicos reportan cifras concretas (p. ej. Cap. 11: OLS 1,41 / DML sin cross-fitting 0,86 / DML con cross-fitting 0,95, «20 repeticiones») sin semilla ni script citado. Además, los listados apuntan a rutas del monorepo docente (`../data/datasets/real/public_causaldata/nsw_mixtape/data.csv`) que no existen en el repositorio público. En un libro riguroso, **cada número debe regenerarse desde un script versionado con semilla**.
4. **Vestigios de curso.** El modo `principios` los filtra por macro, pero no existe una auditoría publicada de que compile sin fugas; y hay referencias muertas en la propia fuente (`DECISIONES_ALCANCE.md`, `herramientas/fix_refs_autores.py`, citados en comentarios de `template.typ` y `refs.yml` pero ausentes).
5. **Aparato de libro de referencia incompleto.** Sin índice temático ni de autores (solo índices de contenido/figuras/tablas/algoritmos/listados); ejercicios sin pistas ni respuestas; sin página de erratas ni versionado.
6. **Capítulos de frontera débiles en respaldo bibliográfico** (caps. 27–29 con 5–10 referencias cada uno frente a 13–22 de los capítulos de método): requieren contraste directo con la literatura primaria (TARNet/CFR, Riesz representers, NOTEARS y sus críticas).
7. **Notación con dobles usos.** La tabla de notación define $m_0(x)=E[D\mid X]$ pero el Cap. 11 reutiliza $m_0(Z,X)$ en el modelo PLIV; conviene una pasada de unificación.
8. **Sin revisión externa.** La distancia clásica entre monografía docente y libro publicado no es de contenido sino de arbitraje; hoy el texto no lo ha pasado.

### 2.3 Veredicto

La base es mejor que la mayoría de las monografías de curso que llegan a publicarse: la arquitectura, el posicionamiento y la honestidad estadística ya están. Lo que falta es precisión formal, procedencia reproducible de los números, aparato gráfico y una edición de libro (no de curso). Es transformable en libro riguroso con un trabajo acotado y verificable, no con una reescritura.

## 3. Propuesta: el libro

**Producto.** Usar el modo `principios` (ya previsto como «edición de librería», título de portada «Inferencia Causal Aplicada») como libro impreso. El modo `curso` queda como edición interna del curso; la implementación (capa L3) migra a un *companion repo* público que implementa los contratos C-01…C-08 y regenera todas las cifras del libro.

**Idioma.** Cerrar el rigor en español primero: el mercado hispano tiene un vacío real (no existe el equivalente de Hernán–Robins orientado a producción). En paralelo preparar 2–3 capítulos muestra traducidos para explorar la ruta inglesa (Chapman & Hall/CRC encaja: causal + MLOps aplicado), donde la competencia es dura pero el hueco también existe.

**Rutas de publicación**, en orden de preferencia:
1. Editorial académica hispana de economía aplicada (p. ej. Marcial Pons, Pirámide) — encaja por audiencia (profesionales + posgrado aplicado).
2. Chapman & Hall/CRC o Springer, en inglés, tras traducción técnica.
3. Autopublicación con PDF listo para imprenta (el pipeline Typst ya lo produce) como plan B que conserva control y derechos.

**Cambios estructurales al libro:**

1. **Apéndice de demostraciones** (o sección «Condiciones y demostraciones» por capítulo): ~10 resultados centrales con prueba propia o esquema + referencia exacta (teorema y página de la fuente): ortogonalidad de Neyman, normalidad asintótica con nuisance estimado, doble robustez con tasas, honestidad de bosques causales, EIF de ATE/CATE, valor de política.
2. **Inventario de teoremas auditado**: cada teorema con (a) condiciones precisas, (b) prueba o referencia exacta, (c) alcance declarado. Corregir los dos enunciados débiles identificados del Cap. 11 y revisar los homólogos.
3. **Companion repo** con: un script por caso canónico (semilla fija), `make book` que regenera cada tabla numérica, CI, contratos implementados y probados. El libro cita cada cifra con la forma «script + semilla + commit».
4. **20–25 figuras vectoriales nuevas** (diagramas DAG en Fletcher, gráficos de simulación como SVG generados): geometría de la ortogonalidad, overlap/ESS, sesgo del cross-fitting, Qini/uplift, arquitecturas cap. 27, matrix completion cap. 28, trade-offs de trimming.
5. **Índice temático y de autores**, respuestas o pistas a ejercicios seleccionados, página de erratas, versionado semántico del libro (p. ej. 1.0 de la edición `principios`).
6. **Pasada editorial de voz** en modo `principios`: transiciones entre partes, eliminación de toda prosa residual de curso, prefacio comercial.

## 4. Plan de un mes

Supuesto: 1 persona a tiempo completo sobre esta base. El objetivo del mes es dejar el libro **apto para propuesta editorial** (y para una edición 1.0 autopublicada), no la maquetación final ni el arbitraje externo, que quedan fuera del mes.

### Semana 1 — Auditoría e infraestructura

| Tarea | Salida verificable |
|---|---|
| Inventario completo de teoremas/definiciones/lemas de los 33 capítulos + 10 apéndices: condiciones precisas (sí/no), prueba (sí/no), referencia exacta (sí/no) | Tabla `auditoria_teoremas.csv` |
| Inventario de cifras: cada número de los casos canónicos → script existente o pendiente | Tabla `auditoria_numeros.csv` |
| Compilar los tres modos y auditar fugas del modo `principios` (buscar «lab», «sesión», «L0», «Serie», «monorepo», «autograder») | Los 3 PDFs compilan; 0 fugas |
| Limpiar referencias muertas de la fuente (`DECISIONES_ALCANCE.md`, `herramientas/`) | 0 referencias rotas |
| Auditoría de notación (tabla canónica vs. usos reales, incl. $m_0$ en PLIV) | Lista de cambios de notación |

*Criterio de salida: las dos tablas de auditoría completas y los tres PDFs compilando.*

### Semana 2 — Rigor matemático (capítulos de método, 3–14 y 21)

- Para cada teorema del inventario: enunciado con condiciones de regularidad (clases de funciones, tasas, momentos), prueba propia, esquema con referencia exacta, o marca explícita «citado sin prueba» cuando sea lo honesto.
- Corregir los enunciados débiles conocidos (doble robustez y eficiencia del Cap. 11) y revisar los homólogos de los caps. 6, 10, 12, 13, 21, 25.
- Crear el apéndice de demostraciones con los ~10 resultados centrales.
- Unificar supuestos con numeración estable por capítulo (Supuesto 5.1, …) para citarlos entre capítulos.
- Repaso bibliográfico de los capítulos de frontera (17, 27–29): contrastar contra literatura primaria y ampliar referencias.

*Criterio de salida: ningún teorema sin condiciones ni referencia exacta; el apéndice de demostraciones compila.*

### Semana 3 — Reproducibilidad y figuras

- Construir el companion repo: un script por caso canónico con semilla fija; `make book` regenera cada tabla numérica del libro en CI.
- Regenerar todas las cifras del libro; donde difieran de las impresas, actualizar el libro y anotar versión.
- Producir 20–25 figuras vectoriales con la paleta del template: DAGs (Fletcher) por capítulo clave, geometría de ortogonalidad, ESS/overlap, sesgo de cross-fitting, Qini, arquitecturas, matrix completion.
- Sustituir las 6 PNG raster por versiones vectoriales.

*Criterio de salida: `make book` verde en CI; cada tabla y figura del libro tiene fuente trazable.*

### Semana 4 — Edición y salida

- Pasada editorial completa en modo `principios`: voz, transiciones, prosa residual de curso, prefacio comercial, portada.
- Índice temático y de autores; respuestas/pistas a los ejercicios seleccionados de cada capítulo de método.
- Colofón, licencia editorial, página de erratas, versionado (1.0-rc).
- Paquete editorial: carta de propuesta con posicionamiento y comparables (Hernán–Robins, Pearl, Chernozhukov et al., Knaus, Bareinboim, Huyen), 2–3 capítulos muestra en PDF (recomendados: 10, 11 y 19), y el PDF completo de la edición `principios`.

*Criterio de salida: PDF `principios` 1.0-rc completo + paquete enviado a al menos dos editoriales.*

### Riesgos del plan

- **Alcance**: el paso de rigor de la semana 2 sobre 15 capítulos es lo más caro; si falta tiempo, priorizar caps. 10–13 y 21 (el corazón metodológico) y dejar 25–26 en «citado sin prueba» explícito.
- **Regeneración de cifras**: si al regenerar salen números distintos a los impresos, el cambio es correcto pero obliga a revisar la prosa que interpreta esos números; reservar margen para eso.
- **Traducción**: fuera del mes; solo se preparan los capítulos muestra.

---

*Archivo generado a partir de la lectura de la fuente Typst (template, frontmatter, 33 capítulos muestreados, 10 apéndices), la bibliografía y el PDF compilado de 452 páginas.*
