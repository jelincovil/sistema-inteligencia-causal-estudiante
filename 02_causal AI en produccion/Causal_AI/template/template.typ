// template.typ: plantilla consolidada de la monografía
// Sistema de Inteligencia Causal, edición 2026

// ============================================================
// 0. Modo de edición (curso ↔ comercial ↔ principios)
// ============================================================
// "curso":      edición académica. Conserva el aparato docente: callouts del
//               monorepo, referencias a sesiones/labs/autograders, apéndice de
//               proyecto final y guía para instructores. Muestra todas las capas.
// "comercial":  edición de librería con implementación. Sustituye el aparato
//               docente por notas genéricas y excluye los apéndices de uso
//               exclusivamente educativo. Muestra las capas L0 a L3.
// "principios": edición independiente de la implementación. Hereda el modo
//               comercial y además retira la capa L3 (listados, comandos,
//               nombres de herramientas): solo teoría, métodos en pseudocódigo,
//               principios y contratos. Es el modo previsto para el libro
//               comercial (decisión D4 en DECISIONES_ALCANCE.md).
// El contenido de las capas L0 a L2 es idéntico en los tres modos: solo cambia
// el envoltorio editorial y la presencia de la capa de implementación.
//
// Selección del modo (sin editar ningún archivo):
//   typst compile main.typ main-curso.pdf
//   typst compile --input modo=comercial main.typ main-comercial.pdf
//   typst compile --input modo=principios main.typ main-principios.pdf
#let modo-edicion = {
  let m = sys.inputs.at("modo", default: "curso")
  if m in ("curso", "comercial", "principios") { m } else { "curso" }
}
#let es-curso = modo-edicion == "curso"
// "Familia comercial": todo lo que no es el curso. El modo "principios" hereda
// los envoltorios editoriales del modo comercial (notas genéricas, sin sílabo)
// y además retira la capa de implementación (ver §0b).
#let es-comercial = modo-edicion in ("comercial", "principios")
#let es-principios = modo-edicion == "principios"

// --- Datos de autoría y edición ---
#let autor-real = "Jaime Lincovil"
#let anio-copyright = 2026

// Helpers para condicionar fragmentos: #solo-curso[...] se imprime
// únicamente en la edición de curso; #solo-comercial[...], solo en la comercial.
#let solo-curso(body) = if es-curso { body }
#let solo-comercial(body) = if es-comercial { body }
#let solo-principios(body) = if es-principios { body }
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

// ------------------------------------------------------------
// 0b. Capas de contenido por vida media
// ------------------------------------------------------------
// L0 teoría · L1 métodos en pseudocódigo · L2 principios, contratos y reglas de
// decisión · L3 implementación (código, librerías, versiones, comandos, formatos
// de archivo, salidas de una corrida). Las capas L0 a L2 no llevan macro: son el
// texto normal. La capa L3 se marca con #capa-impl y desaparece en el modo
// "principios". Todo lo que solo tiene sentido en el curso se marca con
// #capa-curso (equivale a #solo-curso).
//
// Atención con las referencias: si un listado va dentro de #capa-impl, toda
// referencia a él debe ir también dentro de #capa-impl, por ejemplo
// #capa-impl[@lst-servicio]; de lo contrario el modo "principios" no compila.
#let capa-impl(body) = if not es-principios { body }
#let capa-curso(body) = if es-curso { body }

// Nombres del aparato editorial que cambian según el modo. Se declaran una sola
// vez para que el título de una caja y la prosa que la describe no se
// desincronicen (se usan en template.typ y en frontmatter/).
#let repo-corto = if es-curso { "monorepo del curso" } else { "repositorio complementario" }
#let titulo-monorepo = if es-curso { "Implementación en el monorepo del curso (2026)" } else { "Código de referencia del capítulo" }
#let titulo-decisionref = if es-curso { "Decisión de referencia para el curso" } else { "Decisión de referencia del libro" }

// Vocabulario de los encabezados que repiten los nueve capítulos de Plantilla B
// (ingeniería y producción). Se declara una sola vez: cambiar el marco editorial
// de esos encabezados se hace aquí y no en cada capítulo.
#let t-decision = titulo-decisionref
#let t-aplicacion = if es-curso { "Aplicación al sistema causal del curso" } else { "Aplicación al sistema causal de referencia" }
#let t-esqueleto = if es-curso { "Implementación de referencia: el esqueleto del proyecto del curso" } else if es-principios { "Las piezas mínimas de un sistema causal" } else { "Implementación de referencia: el esqueleto del proyecto" }

// Reserva la letra de un apéndice que no se imprime en esta edición (p. ej. el
// Apéndice E, de uso educativo, en la edición comercial). Al consumir los dos
// contadores que numeran los apéndices (`counter("chapter")`, que imprime el
// encabezado visible, y `counter(heading)`, que numera el índice general), los
// apéndices siguientes conservan su letra y las referencias ya escritas en el
// texto y en los listados de código ("Ap. G.4") siguen siendo válidas en ambos
// modos. La letra del apéndice omitido queda ausente de la edición, pero la
// correspondencia entre letras, texto y código se mantiene.
#let apendice-reservado() = {
  counter(heading).step()
  counter("chapter").step()
}

// ============================================================
// 1. Paleta cromática (refinada: navy profundo, accent teal técnico)
// ============================================================
#let navy    = rgb("#0D1B2E")   // navy profundo y serio
#let crimson = rgb("#A61E2B")   // crimson sobrio (menos saturado)
#let gray    = rgb("#475569")   // slate-600: gris limpio y técnico
#let light   = rgb("#F8FAFC")   // slate-50: fondo limpio
#let accent  = rgb("#0E7490")   // teal técnico moderno (cyan-700)
#let green   = rgb("#15803D")   // green-700
#let orange  = rgb("#B45309")   // amber-700 sobrio

// ============================================================
// 2. Fuentes
// ============================================================
#let serif-font = "New Computer Modern"
// Sans: Inter está instalada en el entorno de compilación y es la opción más
// robusta del brief. Para cambiar a Source Sans 3 o Helvetica Neue, basta con
// sustituir el string. (Se evita cadena de fallback con familias ausentes:
// Typst emitía un warning por cada llamada text(font: sans-font).)
#let sans-font  = "Inter"
// Mono: JetBrains Mono o Fira Code si se instalan; por defecto DejaVu Sans
// Mono, ampliamente disponible en sistemas Linux.
#let mono-font  = "DejaVu Sans Mono"

// ============================================================
// 2b. Contador de teoremas (definido temprano, antes de project)
// ============================================================
#let theorem-number = counter("theorem-counter")

#let theorem-number-reset() = {
  theorem-number.update(0)
}

// ============================================================
// 3. Configuración global
// ============================================================
#let project(body) = {
  // Documento
  set document(
    title: "Sistema de Inteligencia Causal",
    author: if es-curso { "Curso ECO-490 / ECON-540" } else { autor-real },
    date: datetime(year: 2026, month: 1, day: 1),
    keywords: "causal inference, machine learning, MLOps local, DML, econml",
  )

  // Página
  set page(
    paper: "a4",
    margin: (left: 2.6cm, right: 2.6cm, top: 3.5cm, bottom: 3.5cm),
    header: context {
      let page-num = here().page()
      let n = state("frontmatter-mode").at(here())
      if page-num <= 1 { return }
      let chapter-title = state("chapter-title").at(here())
      let part-title = state("part-title").at(here())
      let header-text = if chapter-title != none { chapter-title } else if part-title != none { part-title } else { "" }
      let even = calc.even(page-num)
      // Header ligero: menos peso visual, solo una línea sutil debajo
      let title-el = text(font: sans-font, size: 8.5pt, fill: gray.lighten(10%))[#header-text]
      let num-el = text(font: sans-font, size: 8.5pt, fill: gray.lighten(10%))[#page-num]
      // Título siempre al margen exterior, folio siempre al margen interior;
      // h(1fr) fuerza la separación entre ambos en vez de un grid de dos
      // columnas independientes (que los pegaba en el borde compartido y
      // producía la colisión título/folio en páginas impares).
      if even {
        title-el; h(1fr); num-el
      } else {
        num-el; h(1fr); title-el
      }
      v(-6pt)
      line(length: 100%, stroke: 0.3pt + gray.lighten(65%))
    },
    numbering: "1",
  )

  // Texto
  set text(
    font: serif-font,
    size: 11pt,
    lang: "es",
    region: "ES",
    hyphenate: true,
    fill: black,
  )
  // En las ediciones sin aparato docente, "curso" se lee "libro": misma concordancia
  // (masculino singular) y mismo sentido en frases como "todo el curso", "este curso".
  // El aparato que no existe en esas ediciones (series de notebooks, proyecto final)
  // se condiciona aparte con #solo-curso.
  show regex("\\b[Cc]urso\\b"): it => if es-comercial {
    if it.text == "Curso" [Libro] else [libro]
  } else { it }
  set par(
    justify: true,
    leading: 0.72em,
    first-line-indent: (amount: 1.2em, all: false),
    spacing: 1em,
  )

  // Heading numbering: por defecto desactivado para frontmatter.
  // Se reactiva con set heading(numbering: "1.1.1") en mainmatter.
  set heading(numbering: none)
  // Referencias a encabezados. El suplemento depende del nivel y de si el encabezado
  // es de capítulo o de apéndice, algo que un `set heading(supplement: …)` no puede
  // saber, así que se resuelve aquí: @cap-x se lee «Capítulo 11», @ap-x «Apéndice B»
  // y @sec-x «Sección 11.2». Si el texto ya trae la palabra delante (capítulo, Nota
  // técnica…), se escribe #ref(<cap-x>, supplement: none) y sale solo el número.
  set heading(supplement: none)
  show ref: it => {
    let el = it.element
    if el == none or el.func() != heading or it.supplement != auto { return it }
    context {
      let loc = el.location()
      let kind = state("chapter-kind").at(loc)
      let num = numbering(el.numbering, ..counter(heading).at(loc))
      let palabra = if el.level > 1 { "Sección" } else if kind == "appendix" { "Apéndice" } else { "Capítulo" }
      link(loc, [#palabra #num])
    }
  }

  // Heading styles (level 1 = chapter)
  // Apertura de capítulo: numeral fantasma muy grande anclado arriba a la
  // derecha (place, no empuja el flujo), kicker "CAPÍTULO X / APÉNDICE X",
  // filete superior fino, título en navy y línea corta gruesa de accent.
  // La lógica de contadores y estados es idéntica a la anterior.
  show heading.where(level: 1): it => {
    let kind = state("chapter-kind").at(here())
    if kind == "frontmatter" {
      // Unnumbered chapter (frontmatter): no chapter counter step, no number displayed
      state("chapter-title").update(it.body)
      state("part-title").update(none)
      pagebreak(weak: true)
      v(2.2em)
      block(width: 100%)[
        #text(font: sans-font, fill: navy, size: 24pt, weight: "bold", hyphenate: false)[#it.body]
        #v(0.45em)
        #line(length: 45%, stroke: 1pt + accent)
        #v(1em)
      ]
      v(1.2em)
    } else {
      // Numbered chapter (mainmatter or appendix)
      pagebreak(weak: true)
      counter("chapter").step()
      counter("section").update(0)
      counter("subsection").update(0)
      // Reset figure/table/listing counters at the start of each chapter
      // (algorithms keep global numbering as in the LaTeX original)
      counter(figure.where(kind: image)).update(0)
      counter(figure.where(kind: table)).update(0)
      counter(figure.where(kind: raw)).update(0)
      counter(math.equation).update(0)   // las ecuaciones se numeran por capítulo: (N.1), (N.2), ...
      counter("equation-counter").update(0)
      theorem-number.update(0)
      state("chapter-title").update(it.body)
      state("part-title").update(none)
      v(1.6em)
      block(width: 100%)[
        // Numeral fantasma: ~96 pt, navy casi transparente (transparentize 89 %
        // ≈ 89 % de transparencia), anclado arriba a la derecha con place y un
        // desplazamiento negativo pequeño para que se sienta anclado.
        #place(top + right, dx: -0.5em, dy: -0.6em)[
          #text(font: sans-font, fill: navy.transparentize(89%), size: 96pt, weight: "bold", hyphenate: false)[
            #context {
              let num = counter("chapter").at(here()).first()
              if kind == "appendix" { numbering("A", num) } else { numbering("1", num) }
            }
          ]
        ]
        // Kicker con tracking amplio
        #text(font: sans-font, fill: accent, size: 10.5pt, weight: "bold", tracking: 0.24em)[
          #context {
            let num = counter("chapter").at(here()).first()
            if kind == "appendix" [APÉNDICE #numbering("A", num)] else [CAPÍTULO #numbering("1", num)]
          }
        ]
        #v(0.55em)
        // Filete superior fino (línea larga)
        #line(length: 100%, stroke: 0.5pt + navy)
        #v(0.7em)
        #text(font: sans-font, fill: navy, size: 26pt, weight: "bold", hyphenate: false, tracking: -0.015em)[#it.body]
        #v(0.75em)
        // Línea corta de accent: 32 % del ancho, 2.25 pt
        #line(length: 32%, stroke: 2.25pt + accent)
        #v(1em)
      ]
      v(1.2em)
    }
  }

  // Level 2: section; uses chapter.counter + section.counter as numbering parent
  show heading.where(level: 2): it => {
    let kind = state("chapter-kind").at(here())
    counter("section").step()
    counter("subsection").update(0)
    v(0.8em)
    block(width: 100%)[
      #text(font: sans-font, fill: navy, size: 16pt, weight: "bold")[
        #if kind == "frontmatter" [
          #it.body
        ] else if kind == "appendix" [
          #context {
            let ch = counter("chapter").at(here()).first()
            let s = counter("section").at(here()).first()
            numbering("A.1", ch, s)
          }
          #h(0.5em)
          #it.body
        ] else [
          #context {
            let ch = counter("chapter").at(here()).first()
            let s = counter("section").at(here()).first()
            numbering("1.1", ch, s)
          }
          #h(0.5em)
          #it.body
        ]
      ]
    ]
    v(0.4em)
  }

  show heading.where(level: 3): it => {
    counter("subsection").step()
    v(0.5em)
    block(width: 100%)[
      #text(font: sans-font, fill: accent, size: 13pt, weight: "bold")[
        #context {
          let kind = state("chapter-kind").at(here())
          let ch = counter("chapter").at(here()).first()
          let s = counter("section").at(here()).first()
          let ss = counter("subsection").at(here()).first()
          if kind == "appendix" {
            numbering("A.1.1", ch, s, ss)
          } else {
            numbering("1.1.1", ch, s, ss)
          }
        }
        #h(0.4em)
        #it.body
      ]
    ]
    v(0.3em)
  }

  show heading.where(level: 4): it => {
    v(0.3em)
    text(font: sans-font, fill: gray, size: 11pt, style: "italic")[
      #it.body
    ]
  }

  show heading.where(level: 5): it => {
    v(0.2em)
    text(font: sans-font, fill: gray, size: 10pt, weight: "bold")[
      #it.body
    ]
  }

  // Math equation numbering per chapter: (1.1), (1.2), ...
  // Numeración por capítulo. En los apéndices el primer componente es la letra
  // del apéndice ("B.1", "G.2"), para que no choque con la de los capítulos
  // (el Listado 3.1 del Cap. 3 y el del Apéndice C eran ambos "3.1").
  let _num-cap(n) = {
    let c = counter("chapter").at(here()).first()
    if state("chapter-kind").at(here()) == "appendix" { numbering("A.1", c, n) } else { numbering("1.1", c, n) }
  }

  // Activate numbering globally and customize the format per chapter
  set math.equation(numbering: (n) => "(" + _num-cap(n) + ")", supplement: none)

  // Figure numbering per chapter using a numbering function
  // Typst's figure() uses an internal counter; we provide a function
  // that takes the figure's own number and prepends the chapter number.
  show figure.where(kind: image): set figure(
    supplement: [Figura],
    numbering: (n) => _num-cap(n),
    placement: auto,
  )
  // Las celdas de tabla son estrechas: justificadas abren huecos enormes entre palabras.
  show table: set par(justify: false)
  show figure.where(kind: table): set figure(
    supplement: [Tabla],
    numbering: (n) => _num-cap(n)
  )
  // Las tablas altas (más de unos 170 pt) se dividen entre páginas con la cabecera repetida, en lugar de
  // desbordar el pie o dejar medio folio en blanco; las bajas siguen indivisibles. Una fila nunca se parte.
  // El ancho de medida es el de la caja de texto (A4 menos márgenes de 2.6 cm).
  set table.cell(breakable: false)
  show figure.where(kind: table): it => context {
    if measure(width: 447.9pt, it).height > 170pt [
      #set block(breakable: true)
      #it
    ] else { it }
  }
  // Los teoremas altos (más de unos 200 pt) pueden partirse entre páginas; los cortos se mantienen enteros.
  show figure.where(kind: "theorem-block"): it => context {
    if measure(width: 447.9pt, it).height > 200pt [
      #set block(breakable: true)
      #it
    ] else { it }
  }
  show figure.where(kind: raw): set figure(
    supplement: [Listado],
    numbering: (n) => _num-cap(n)
  )
  show figure.where(kind: "algorithm"): set figure(
    supplement: [Algoritmo],
    numbering: "1."
  )
  // El número del algoritmo ya lleva punto ("Algoritmo 3."): el pie no añade dos puntos.
  show figure.where(kind: "algorithm"): set figure.caption(separator: [ ])

  // Lists
  set list(indent: 1.5em, body-indent: 0.5em, marker: ([•], [◦], [▪]))
  set enum(indent: 1.5em, body-indent: 0.5em, numbering: "1.")

  // Bloques de código (raw): fondo ligeramente frío y borde sutil
  show raw.where(block: true): it => {
    set align(left)
    set text(font: mono-font, size: 9pt)
    block(
      fill: rgb("#F4F7F9"),
      stroke: 0.3pt + gray.lighten(70%),
      inset: (x: 9pt, y: 8pt),
      radius: 3pt,
      width: 100%,
    )[
      #it.text
    ]
  }

  // Alineación a la izquierda y título alineado para figuras tipo código/listado
  // Los listados largos deben poder partirse entre páginas. Por defecto una
  // figura no se parte, y Typst recorta en silencio lo que no cabe en una página
  // (el Listado 30.1 perdía `estabilidad_efecto` y `reporte_monitoreo`).
  show figure.where(kind: raw): it => {
    set align(left)
    set block(breakable: true)
    it
  }

  body
}

// ============================================================
// 4. Estructura del documento
// ============================================================

#let frontmatter(body) = {
  state("frontmatter-mode").update(true)
  state("chapter-kind").update("frontmatter")
  set page(numbering: "i")
  counter("page").update(1)
  set heading(numbering: none)
  body
}

#let mainmatter(body) = {
  state("frontmatter-mode").update(false)
  state("chapter-kind").update("chapter")
  set page(numbering: "1")
  counter("chapter").update(0)
  counter("section").update(0)
  counter("subsection").update(0)
  counter("part").update(0)
  counter("figure-counter").update(0)
  counter("table-counter").update(0)
  counter("listing-counter").update(0)
  counter("equation-counter").update(0)
  theorem-number.update(0)
  set heading(numbering: "1.1.1")
  body
}

#let appendix-mode(body) = {
  state("chapter-kind").update("appendix")
  counter("chapter").update(0)
  counter("section").update(0)
  counter("subsection").update(0)
  // Numeración nativa de Typst (usada por #outline()) debe reiniciarse y
  // usar letras para que el índice general coincida con el encabezado
  // visual de cada apéndice ("Apéndice A", "Apéndice B", ...), en vez de
  // continuar la numeración arábiga secuencial de los capítulos (33, 34...).
  counter(heading).update(0)
  set heading(numbering: "A.1.1")
  body
}

// Apertura de parte: kicker con tracking amplio, título mayor y línea de
// acento corta, con el mismo lenguaje visual que la apertura de capítulo.
#let part(title) = {
  state("chapter-title").update(none)
  state("part-title").update(title)
  pagebreak(weak: true)
  counter("part").step()
  v(32%)
  align(center)[
    #text(font: sans-font, fill: accent, size: 13pt, weight: "bold", tracking: 0.3em)[
      PARTE #context {
        // La Introducción es la Parte 0 (como en «Cómo usar este libro» y en
        // las referencias del texto); el contador arranca en 1 al abrirla.
        let p = counter("part").at(here()).first() - 1
        if p == 0 { "0" } else { numbering("I", p) }
      }
    ]
    #v(0.9em)
    #text(font: sans-font, fill: navy, size: 36pt, weight: "bold", hyphenate: false, tracking: -0.01em)[#title]
    #v(0.7em)
    #line(length: 14%, stroke: 1.2pt + accent)
  ]
  pagebreak(weak: true)
}

#let chapter(title) = heading(level: 1, title)
#let section(title) = heading(level: 2, title)
#let subsection(title) = heading(level: 3, title)

// ============================================================
// 6. Bloques de teoremas (contador compartido, por capítulo)
// ============================================================
#let _theorem-block(kind-name, kind-color, body, name: none) = {
  theorem-number.step()
  figure(
    kind: "theorem-block",
    numbering: "1.1",
    supplement: kind-name,
    {
      // Forzamos alineación a la izquierda para evitar que la figura centre la cabecera
      set align(left)
      set par(leading: 0.6em)
      
      block(width: 100%, spacing: 1em, breakable: true)[
        #block(width: 100%)[
          #box(
            fill: kind-color,
            inset: (x: 6pt, y: 3pt),
            radius: 2pt,
          )[
            #text(font: sans-font, fill: white, weight: "bold", size: 10.5pt)[
              #kind-name #context {
                let ch = counter("chapter").at(here()).first()
                let th = theorem-number.at(here()).first()
                numbering("1.1", ch, th)
              }
            ]
          ]
          #if name != none [
            #h(6pt)
            // Aumentamos tamaño (11.5pt) y aseguramos estilo en negrita/cursiva a la izquierda
            #text(font: sans-font, size: 11.5pt, style: "italic", weight: "bold", fill: navy.darken(20%))[
              (#name)
            ]
          ]
        ]
        #v(0.4em)
        #block(inset: (left: 0em, right: 0em))[#body]
      ]
    }
  )
}

// Hide the default figure caption for theorem-block figures
#show figure.where(kind: "theorem-block"): it => it.body

// Accept either `#theorem[body]` or LaTeX-style `#theorem[body][Name]`.
#let _named-theorem(kind-name, kind-color, body, name: none, ..rest) = {
  let n = name
  let pos = rest.pos()
  if pos.len() > 0 {
    n = pos.at(0)
  }
  _theorem-block(kind-name, kind-color, body, name: n)
}

#let theorem(body, name: none, ..rest) = _named-theorem("Teorema", navy, body, name: name, ..rest)
#let proposition(body, name: none, ..rest) = _named-theorem("Proposición", accent, body, name: name, ..rest)
#let lemma(body, name: none, ..rest) = _named-theorem("Lema", accent, body, name: name, ..rest)
#let corollary(body, name: none, ..rest) = _named-theorem("Corolario", accent, body, name: name, ..rest)
#let definition(body, name: none, ..rest) = _named-theorem("Definición", green, body, name: name, ..rest)
#let assumption(body, name: none, ..rest) = _named-theorem("Supuesto", orange, body, name: name, ..rest)
#let example(body, name: none, ..rest) = _named-theorem("Ejemplo", orange, body, name: name, ..rest)
#let remark(body, name: none, ..rest) = _named-theorem("Observación", gray, body, name: name, ..rest)

#let proof(body, kind: "full") = block(width: 100%, spacing: 1em)[
  #text(font: sans-font, style: "italic", weight: "bold")[
    #if kind == "sketch" [Demostración (esquema).] else [Demostración.]
  ]
  #h(4pt)
  #body
  #h(1fr)
  $#sym.square.small$
]

// Alias en español
#let teorema = theorem
#let definicion = definition

// ============================================================
// 6. Cajas tcolorbox equivalentes
// ============================================================
// Caja base: borde izquierdo como ancla cromática; el resto de los bordes
// apenas se insinúan (0.3pt, lighten 78%) para lograr "menos caja, más
// estructura". Título con tracking ligero y filete separador sutil.
#let _tbox(title, frame-color, body, fill-color: light, breakable: true) = block(
  breakable: breakable,
  fill: fill-color,
  stroke: (left: 2.5pt + frame-color,
           top: 0.3pt + frame-color.lighten(78%),
           bottom: 0.3pt + frame-color.lighten(78%),
           right: 0.3pt + frame-color.lighten(78%)),
  inset: (left: 12pt, right: 10pt, top: 8pt, bottom: 8pt),
  radius: 3pt,
  width: 100%,
  spacing: 1em,
)[
  // El encabezado es "sticky": no queda huérfano al pie de una página con el cuerpo en la siguiente.
  #block(sticky: true, above: 0pt, below: 0.4em)[
    #text(font: sans-font, fill: frame-color, weight: "bold", size: 10.5pt, tracking: 0.06em, hyphenate: false)[#title]
    #v(0.25em)
    #line(length: 100%, stroke: 0.3pt + frame-color.lighten(55%))
  ]
  #body
]

// Fondos refinados: tintes ligeramente teal para los boxes de accent y tintes
// más suaves (lighten más alto) para el resto. Mismo lenguaje por tipo de caja.
#let cuadrosinoptico(body) = _tbox("Cuadro sinóptico del capítulo", accent, body, fill-color: rgb("#EEF4F8"))
// --- Plantilla B: capítulos de ingeniería y producción (estilo DMLS) ---
#let cuadrodecision(body) = _tbox("Cuadro de decisión del capítulo", accent, body, fill-color: rgb("#EEF4F8"))
#let disenio(body) = _tbox("El problema de diseño", navy, body, fill-color: rgb("#ECF1F6"))
#let opciones(body) = _tbox("Opciones y trade-offs", accent, body, fill-color: rgb("#EEF4F8"))
#let decisionref(body) = _tbox(
  titulo-decisionref,
  green, body, fill-color: green.lighten(88%),
)
#let supuestos(body) = _tbox("Supuestos del capítulo", gray.darken(20%), body, fill-color: gray.lighten(88%))
#let diagnosticos(body) = _tbox("Diagnósticos recomendados", green, body, fill-color: green.lighten(88%))
#let riesgos(body) = _tbox("Riesgos, límites y mitigación", crimson, body, fill-color: crimson.lighten(90%))
#let notatecnica(body) = _tbox("Nota técnica", orange, body, fill-color: orange.lighten(88%))
#let intuicion(body) = _tbox("Intuición", green, body)
#let advertencia(body) = _tbox("Atención", orange, body)

// --- Capas L2 y L0: contratos, casos canónicos y fronteras ---
// Contrato: la forma en que el libro describe una interfaz de ingeniería sin
// citar código. Cada contrato tiene un identificador estable (C-01, C-02, ...)
// que el repositorio complementario usa para declarar qué contratos implementa.
// Los campos son opcionales: se imprimen solo los que se pasan.
#let contrato(id, titulo, operaciones: none, entrada: none, salida: none, invariantes: none, fallos: none, aceptacion: none) = {
  let fila(etiqueta, cuerpo) = if cuerpo != none {
    (text(font: sans-font, weight: "bold", size: 9.5pt, fill: navy)[#etiqueta], cuerpo)
  } else { () }
  let celdas = (
    ..fila("Operaciones", operaciones),
    ..fila("Entrada", entrada),
    ..fila("Salida", salida),
    ..fila("Invariantes", invariantes),
    ..fila("Modos de fallo", fallos),
    ..fila("Prueba de aceptación", aceptacion),
  )
  _tbox(
    [Contrato #id · #titulo],
    navy,
    grid(columns: (4cm, 1fr), column-gutter: 10pt, row-gutter: 7pt, ..celdas),
    fill-color: rgb("#ECF1F6"),
  )
}

// Caso canónico: un proceso generador de datos estilizado, con verdad conocida,
// descrito con ecuaciones y en prosa. Sustituye a los listados de simulación en
// la edición de principios; la corrida concreta vive en el material complementario.
// Bloque que se mantiene entero si es bajo (se lee de un vistazo) y se deja partir si pasa de un tercio de página,
// para no dejar medio folio en blanco. Sustituye a block(breakable: false) en capítulos y apéndices.
#let entero(body) = context {
  let h = measure(width: 447.9pt, block(breakable: false, body)).height
  block(breakable: h > 235pt, body)
}

// Caja que se mide antes de colocarla: si cabe en un tercio de página se mantiene entera (se lee de un vistazo);
// si es más alta, se deja partir entre páginas para no dejar medio folio en blanco. El ancho es el de la
// caja de texto (A4 menos márgenes de 2.6 cm); si cambian los márgenes, hay que actualizarlo aquí.
#let _tbox-medida(title, frame-color, body, fill-color: light, umbral: 235pt) = context {
  let h = measure(width: 447.9pt, _tbox(title, frame-color, body, fill-color: fill-color, breakable: false)).height
  _tbox(title, frame-color, body, fill-color: fill-color, breakable: h > umbral)
}

#let caso-canonico(titulo, body) = _tbox-medida(
  [Caso canónico · #titulo], accent, body, fill-color: rgb("#EEF4F8"),
)

// Frontera: contenido que puede quedar viejo (estado del arte, prácticas
// emergentes). Lleva siempre el año de redacción y se revisa en cada edición.
#let frontera(anio, body) = _tbox-medida(
  [Frontera · #anio], gray.darken(20%), body, fill-color: gray.lighten(88%),
)

// Callout de implementación en el monorepo del curso (integración libro ↔ código).
// En modo comercial el callout no se elimina: se sustituye por una nota genérica
// que apunta al repositorio complementario del libro, de modo que el lector
// profesional conserva la referencia al código sin el aparato docente.
#let monorepo(body) = if es-principios { none } else { _tbox(
  titulo-monorepo,
  accent,
  if es-curso {
    body
  } else {
    [El código de referencia de este capítulo está disponible en el repositorio complementario del libro.]
  },
  fill-color: rgb("#E9F4F8"),
) }

// ============================================================
// 7. Algoritmos (estilo algorithm2e ruled)
// ============================================================
#let algorithm(title, body) = figure(
  kind: "algorithm",
  caption: title,
  supplement: [Algoritmo],
  numbering: "1.",
  placement: top,
  {
    // Forzamos alineación a la izquierda en todo el contenido de la figura
    set align(left)
    block(
      stroke: (top: 0.8pt + black, bottom: 0.8pt + black),
      width: 100%,
      spacing: 1em,
    )[
      #block(
        stroke: (bottom: 0.4pt + black),
        inset: (top: 4pt, bottom: 4pt, left: 0pt, right: 0pt),
        width: 100%,
      )[
        #text(font: sans-font, weight: "bold", size: 11pt)[Algoritmo]
      ]
      #v(2pt)
      #set text(size: 10pt)
      #set par(leading: 0.5em, first-line-indent: 0em)
      #block(inset: (left: 0pt, right: 0pt, bottom: 4pt))[#body]
    ]
  }
)

#let kwin(label, body) = {
  text(weight: "bold")[#label:]
  h(2pt)
  body
  linebreak()
}

#let kwout(label, body) = {
  text(weight: "bold")[#label:]
  h(2pt)
  body
  linebreak()
}

#let for-loop(var, from, to, body) = {
  text(weight: "bold")[for]
  h(2pt)
  var
  h(2pt)
  text(weight: "bold")[=]
  h(2pt)
  [#from]
  h(2pt)
  text(weight: "bold")[to]
  h(2pt)
  [#to]
  h(2pt)
  text(weight: "bold")[do]
  linebreak()
  block(inset: (left: 1.5em))[#body]
  linebreak()
  text(weight: "bold")[end for]
  linebreak()
}

#let if-then(cond, body) = {
  text(weight: "bold")[if]
  h(2pt)
  cond
  h(2pt)
  text(weight: "bold")[then]
  linebreak()
  block(inset: (left: 1.5em))[#body]
  linebreak()
  text(weight: "bold")[end if]
  linebreak()
}

#let return-stmt(body) = {
  text(weight: "bold")[return]
  h(2pt)
  body
  linebreak()
}

// ============================================================
// 8. Checklist (con ☐)
// ============================================================
#let checklist(body) = {
  // Una casilla por elemento. (Antes se envolvía el cuerpo en list(), lo que dejaba
  // una sola viñeta para toda la lista y las casillas en línea.)
  set list(marker: text(fill: navy)[☐], indent: 0.3em, body-indent: 0.6em)
  body
}

// ============================================================
// 9. Comandos abreviados de notación (equivalente a macros.tex)
// ============================================================
#let code(body) = text(font: mono-font, size: 9.5pt, fill: accent)[#body]

// ============================================================
// 10. Helpers de portada y frontmatter
// ============================================================
// Portada rediseñada: kicker con tracking, título mayor, línea de acento corta
// y dos cajas con el lenguaje de borde izquierdo de _tbox (más elegancia,
// menos "caja pesada").
#let portada() = page(margin: (top: 3.2cm, bottom: 3.2cm, left: 2.8cm, right: 2.8cm), numbering: none)[
  #v(1.4cm)
  #align(center)[
    #text(font: sans-font, fill: accent, size: 11pt, weight: "bold", tracking: 0.28em)[
      #if es-curso [MONOGRAFÍA DEL CURSO] else [INFERENCIA CAUSAL APLICADA]
    ]
    #v(1em)
    #text(font: sans-font, fill: navy, size: 44pt, weight: "bold", hyphenate: false, tracking: -0.01em)[
      Sistema de
      #linebreak()
      Inteligencia Causal
    ]
    #v(0.8em)
    #line(length: 12%, stroke: 1.2pt + accent)
    #v(1em)
    #text(font: sans-font, fill: gray, size: 14.5pt, style: "italic")[
      #if es-curso [
        De la identificación al despliegue: estimar *efectos*, no solo predicciones, \
        y poner políticas causales en producción local
      ] else [
        De la identificación al despliegue: estimar *efectos*, \
        no solo predicciones, y llevar políticas causales a producción
      ]
    ]
    #v(2.6cm)
    #block(
      fill: light,
      stroke: (left: 2.5pt + accent, top: 0.3pt + accent.lighten(75%), bottom: 0.3pt + accent.lighten(75%), right: 0.3pt + accent.lighten(75%)),
      radius: 3pt,
      width: 88%,
      inset: (left: 16pt, right: 14pt, top: 12pt, bottom: 12pt),
    )[
      #par(leading: 1.5em)[
        #text(font: sans-font, size: 11pt)[
          #if es-curso [
            *Curso ECO-490 / ECON-540* \
            Profesionales y posgrado aplicado (data / ML / product / analytics) \
            Modalidad online/asíncrona · 32 sesiones · 33 capítulos \
            Edición 2026
          ] else [
            *#autor-real* \
            Profesionales y posgrado aplicado (data / ML / product / analytics) \
            33 capítulos en 9 partes \
            #anio-copyright
          ]
        ]
      ]
    ]
    #v(1.1em)
    #block(
      fill: crimson.lighten(94%),
      stroke: (left: 2.5pt + crimson, top: 0.3pt + crimson.lighten(80%), bottom: 0.3pt + crimson.lighten(80%), right: 0.3pt + crimson.lighten(80%)),
      radius: 3pt,
      width: 88%,
      inset: (left: 16pt, right: 14pt, top: 11pt, bottom: 11pt),
    )[
      #par(leading: 1.45em)[
        #text(font: sans-font, size: 10pt)[
          *Promesa.* Deja de priorizar con scores que confunden correlación con impacto.
          Estima efectos, documenta supuestos y despliega localmente, con monitoreo
          de señales que obligan a revisar su validez.
        ]
      ]
    ]
    #v(1fr)
    #if not es-principios [
      #text(font: sans-font, fill: gray, size: 9pt)[
        #if es-curso [
          Monorepo del curso: labs L01–L28 · Serie A (casos) · Serie B (local) · benchmark de datos \
          Stack: #code[econml] / #code[sklearn] · #code[FastAPI] · #code[Docker]
        ] else [
          Repositorio complementario del libro, disponible por separado. \\
          Stack: #code[econml] / #code[sklearn] · #code[FastAPI] · #code[Docker]
        ]
      ]
    ]
  ]
]

// ============================================================
// 11. Heading helpers para secciones de frontmatter no numeradas
// ============================================================
#let frontmatter-section(title) = heading(level: 2, title)
#let frontmatter-subsection(title) = heading(level: 3, title)

#let nota-repo-comercial() = if es-principios { none } else [El código de referencia de este capítulo está disponible en el repositorio complementario del libro.]
