// Colofón / Página de derechos
// Dos variantes desde el mismo archivo (ver template.typ §0):
//   - modo "curso":     conserva el pie docente (monorepo, uso docente).
//   - modo "comercial": página legal de librería (copyright, ISBN, marcas).
// Las secciones legales comunes (copyright, ISBN, marcas de terceros) se
// imprimen en ambos modos: son higiene legal, no aparato de curso.
#import "../template/template.typ": *

#page(margin: (top: 6cm, bottom: 4cm, left: 3cm, right: 3cm), numbering: none)[
  #v(1fr)
  #align(center)[
    #block(width: 80%, inset: 20pt, stroke: 0.5pt + gray.lighten(40%), radius: 3pt)[
      #align(center)[
        #text(font: sans-font, size: 14pt, weight: "bold", fill: navy)[
          Sistema de Inteligencia Causal
        ]
        #v(0.3em)
        #text(font: sans-font, size: 11pt, fill: gray)[
          #if es-curso [Monografía del Curso ECO-490 / ECON-540] else [#autor-real]
        ]
        #v(0.3em)
        #text(font: sans-font, size: 10pt, fill: gray)[
          #if es-curso [Edición 2026] else [Primera edición · #anio-copyright]
        ]
      ]
    ]
  ]
  #v(2cm)
  #align(center)[
    #text(font: sans-font, size: 10pt, fill: gray)[
      © #anio-copyright #if es-curso [Curso ECO-490 / ECON-540] else [#autor-real] \
      Todos los derechos reservados. \
      \
       \
      \
      Primera edición, #anio-copyright. \
      \
      Queda prohibida la reproducción total o parcial de esta obra por cualquier \
      medio o procedimiento (incluidos la reprografía, el tratamiento informático \
      y la distribución de ejemplares mediante alquiler o préstamo públicos) sin \
      la autorización previa y por escrito del titular de los derechos. \
      \
      #if not es-principios [Compuesto con Typst 0.15.1. #linebreak()]
      Tipografía: New Computer Modern (serif), Inter (sans-serif), DejaVu Sans Mono (monoespaciada). \
      \
      #if not es-principios [
        *Marcas de terceros.* PyTorch, scikit-learn, FastAPI, Docker, #code[econml], \
        #code[DoubleML], #code[causalml] y #code[dowhy] son marcas (registradas o no) \
        de sus respectivos titulares. Su mención en esta obra es meramente descriptiva \
        y no implica patrocinio, respaldo ni afiliación alguna. \
        \
      ]
      #if es-curso [
        Implementación de referencia en el monorepo del curso (#code[data_benchmark_causal], Serie A/B). \
        Stack Python: #code[econml], #code[DoubleML], #code[causalml], #code[dowhy], #code[PyTorch]. \
        \
        Esta monografía es material de referencia para uso docente. \
        La reproducción total o parcial requiere citación adecuada.
      ] else if modo-edicion == "comercial" [
        Repositorio complementario del libro, disponible por separado.
      ] else [
        Edición de principios, independiente de cualquier herramienta. El material complementario se publica aparte.
      ]
    ]
  ]
  #v(1fr)
]
