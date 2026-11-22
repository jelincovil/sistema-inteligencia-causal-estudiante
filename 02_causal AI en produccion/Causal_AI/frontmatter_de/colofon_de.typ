// Colofón de la edición de ingeniería de datos.
#import "../template/template.typ": *
#import "../template/template_de.typ": *

#page(margin: (top: 6cm, bottom: 4cm, left: 3cm, right: 3cm), numbering: none)[
  #v(1fr)
  #align(center)[
    #block(width: 80%, inset: 20pt, stroke: 0.5pt + gray.lighten(40%), radius: 3pt)[
      #align(center)[
        #text(font: sans-font, size: 14pt, weight: "bold", fill: navy)[
          Ingeniería de Datos Causales
        ]
        #v(0.3em)
        #text(font: sans-font, size: 11pt, fill: gray)[#autor-libro-de]
        #v(0.3em)
        #text(font: sans-font, size: 10pt, fill: gray)[Primera edición · #anio-libro-de]
      ]
    ]
  ]
  #v(2cm)
  #align(center)[
    #text(font: sans-font, size: 10pt, fill: gray)[
      © #anio-libro-de #autor-libro-de \
      Todos los derechos reservados. \
      \
      Primera edición, #anio-libro-de. \
      \
      Queda prohibida la reproducción total o parcial de esta obra por cualquier \
      medio o procedimiento (incluidos la reprografía, el tratamiento informático \
      y la distribución de ejemplares mediante alquiler o préstamo públicos) sin la \
      autorización previa y por escrito del titular de los derechos. \
      \
      Compuesto con Typst 0.15.1. #linebreak() \
      Tipografía: New Computer Modern (serif), Inter (sans-serif), DejaVu Sans Mono (monoespaciada). \
      \
      *Marcas de terceros.* Python, scikit-learn, FastAPI, Docker y #code[numpy] son \
      marcas (registradas o no) de sus respectivos titulares. Su mención en esta obra \
      es meramente descriptiva y no implica patrocinio, respaldo ni afiliación alguna. \
      \
      Repositorio de referencia del libro (#code[causalops], #code[data_benchmark_causal]), \
      disponible junto a la obra. Los casos canónicos se regeneran con semilla declarada. \
      \
      Edición hermana: *Sistema de Inteligencia Causal* (edición de método, 33 capítulos), \
      del mismo autor, conserva el tratamiento teórico completo de identificación y estimación.
    ]
  ]
  #v(1fr)
]
