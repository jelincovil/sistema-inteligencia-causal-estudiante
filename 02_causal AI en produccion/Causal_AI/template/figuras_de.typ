// figuras_de.typ — plantillas de figura de la edición de ingeniería de datos
// Tres lenguajes visuales reutilizables: flujo (pipeline), linaje (versiones y
// artefactos) y muro (la pared observado/evaluación), más la línea temporal
// (validez de features). Todas comparten la paleta del template.
#import "template.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

// 1) Flujo lineal: etapas de un pipeline, de izquierda a derecha.
//    etiquetas: array de contenidos (una por etapa).
#let flujo-lineal(etiquetas) = diagram(
  node-stroke: 0.6pt + gray.lighten(40%),
  node-fill: light,
  node-outset: 4pt,
  node-corner-radius: 3pt,
  spacing: (5mm, 7mm),
  edge-stroke: 0.8pt + accent,
  ..etiquetas.enumerate().map(((i, e)) => node((i * 2.2, 0), e)),
  ..range(etiquetas.len() - 1).map(i => edge((i * 2.2, 0), ((i + 1) * 2.2, 0), "-|>")),
)

// 2) Cadena de linaje: una fila de orígenes (datasets), una fila de artefactos
//    y el alias champion. Los datasets alimentan a los artefactos; el alias
//    apunta al artefacto promovido.
#let cadena-linaje(datasets, artefactos, alias) = diagram(
  node-stroke: 0.6pt + gray.lighten(40%),
  node-fill: light,
  node-outset: 4pt,
  node-corner-radius: 3pt,
  spacing: (7mm, 10mm),
  edge-stroke: 0.8pt + accent,
  ..datasets.enumerate().map(((i, d)) => node((i * 2.4, 0), d)),
  ..artefactos.enumerate().map(((j, a)) => node((j * 2.4, 1.6), a, fill: rgb("EEF4F8"))),
  node((0, 3.2), alias, fill: green.lighten(85%)),
  ..datasets.enumerate().map(((i, d)) => edge((i * 2.4, 0.25), (calc.min(i, artefactos.len() - 1) * 2.4, 1.35), "-|>")),
  edge((0, 1.85), (0, 2.95), "-|>", stroke: 0.8pt + green),
)

// 3) El muro: dos grupos de tablas separados por la pared que el gobierno del
//    dato mantiene. izquierda y derecha: arrays de contenidos.
#let muro-datos(izquierda, derecha) = diagram(
  node-stroke: 0.6pt + gray.lighten(40%),
  node-fill: light,
  node-outset: 4pt,
  node-corner-radius: 3pt,
  spacing: (6mm, 6mm),
  edge-stroke: 0.8pt + accent,
  ..izquierda.enumerate().map(((i, t)) => node((-1.6, i * 1.1), t)),
  ..derecha.enumerate().map(((i, t)) => node((1.6, i * 1.1), t, stroke: 0.6pt + crimson.lighten(30%))),
  node((0, -0.7), [la pared], stroke: none, fill: none),
  edge((0, -0.3), (0, (calc.max(izquierda.len(), derecha.len()) - 1) * 1.1 + 0.7),
         stroke: (paint: crimson, thickness: 2.2pt, dash: "dashed")),
)

// 4) Línea temporal: eventos sobre un eje de tiempo. eventos: array de
//    (posición, etiqueta, ¿etiqueta arriba?).
#let linea-temporal(eventos) = diagram(
  node-stroke: 0.6pt + gray.lighten(40%),
  node-fill: light,
  node-outset: 3pt,
  node-corner-radius: 3pt,
  spacing: (4mm, 5mm),
  edge-stroke: 0.8pt + accent,
  ..eventos.map(((t, et, arriba)) => node((t, if arriba { 0.9 } else { -0.9 }), et,
      fill: if arriba { light } else { rgb("EEF4F8") })),
  edge((calc.min(..eventos.map(e => e.first())) - 0.4, 0),
         (calc.max(..eventos.map(e => e.first())) + 0.4, 0),
         stroke: 0.9pt + gray),
)
