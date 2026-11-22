// template_de.typ — helpers de la edición «Ingeniería de Datos Causales»
// Complementa a template.typ (no lo modifica): portada propia, cajas de esta
// edición y el vocabulario que sustituye al aparato docente del modo «curso».
#import "template.typ": *

// ------------------------------------------------------------ identificación
#let titulo-libro-de = [Ingeniería de Datos Causales]
#let subtitulo-libro-de = [Pipelines, contratos y observabilidad que preservan la identificación]
#let autor-libro-de = autor-real
#let anio-libro-de = anio-copyright

// ------------------------------------------------------------ cajas propias
// Caja «Repositorio de referencia»: el equivalente, en esta edición, del
// callout de implementación del monorepo. Mantiene el lenguaje visual de las
// demás cajas (borde izquierdo como ancla cromática).
#let _caja-de(titulo, frame-color, body, fill-color: light) = block(
  breakable: true,
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
  #block(sticky: true, above: 0pt, below: 0.4em)[
    #text(font: sans-font, fill: frame-color, weight: "bold", size: 10.5pt, tracking: 0.06em, hyphenate: false)[#titulo]
    #v(0.25em)
    #line(length: 100%, stroke: 0.3pt + frame-color.lighten(55%))
  ]
  #body
]

// Dónde vive, en el repositorio de referencia del libro, lo que el capítulo acaba de describir.
#let repo-ref(body) = _caja-de("Repositorio de referencia del libro", accent, body, fill-color: rgb("E9F4F8"))

// Caja de cierre de capítulo: la pregunta del eje del libro. Cada capítulo
// termina respondiéndola: qué debe ser verdad en los datos para que la
// afirmación causal del capítulo valga, y cómo se comprueba.
#let verdad-datos(body) = _caja-de("Qué debe ser verdad en los datos", green, body, fill-color: green.lighten(88%))

// Caja «Exigencia»: lo que una pieza del plano de método le exige al plano de
// datos. Se usa en los capítulos de consumidor (Parte III).
#let exigencia(body) = _caja-de("Lo que el estimador le exige al dato", navy, body, fill-color: rgb("ECF1F6"))

// ------------------------------------------------------------ portada
#let portada-de() = page(margin: (top: 3.2cm, bottom: 3.2cm, left: 2.8cm, right: 2.8cm), numbering: none)[
  #v(1.4cm)
  #align(center)[
    #text(font: sans-font, fill: accent, size: 11pt, weight: "bold", tracking: 0.28em)[INGENIERÍA DE DATOS]
    #v(1em)
    #text(font: sans-font, fill: navy, size: 44pt, weight: "bold", hyphenate: false, tracking: -0.01em)[
      Ingeniería de#linebreak()Datos Causales
    ]
    #v(0.8em)
    #line(length: 12%, stroke: 1.2pt + accent)
    #v(1em)
    #text(font: sans-font, fill: gray, size: 14.5pt, style: "italic")[
      Pipelines, contratos y observabilidad \
      que preservan la identificación
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
          *#autor-libro-de* \
          Ingeniería de datos, analytics y plataformas de ML \
          4 partes · 15 capítulos · 10 contratos numerados \
          #anio-libro-de
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
          *Promesa.* Un pipeline puede entregar datos limpios, puntuales y versionados,
          y aun así destruir el enunciado causal que justifica la decisión. Este libro
          enseña el plano de datos que no lo permite: contratos con roles, versionado
          con linaje, una pared entre lo observado y lo reservado, y supuestos que se
          vigilan en producción.
        ]
      ]
    ]
    #v(1fr)
    #text(font: sans-font, fill: gray, size: 9pt)[
      Repositorio de referencia: #code[causalops] · benchmark #code[data_benchmark_causal] · casos canónicos con semilla \
      Edición hermana: la edición de método de este mismo libro (33 capítulos) conserva \
      la teoría completa de identificación y estimación
    ]
  ]
]
