// ============================================================
//  Ingeniería de Datos Causales — edición de ingeniería de datos
//  Edición hermana de main.typ (Sistema de Inteligencia Causal,
//  edición de método): comparten template/ y bibliografia/.
//  Capítulos 1–6 (Partes I y II). Las Partes III y IV se
//  incorporan en la continuación del plan (capítulos 7–15).
// ============================================================
#import "template/template.typ": *
#import "template/template_de.typ": *

#show: project
#set document(
  title: "Ingeniería de Datos Causales",
  author: "Jaime Lincovil",
  keywords: "data engineering, causal inference, data contracts, lineage, observability, DML",
)

// ============================
//  Frontmatter (numeración romana)
// ============================
#frontmatter[
  #include "frontmatter_de/portada_de.typ"
  #include "frontmatter_de/colofon_de.typ"
  #include "frontmatter_de/prefacio_de.typ"

  #pagebreak()
  #outline(title: [Índice general], depth: 3, indent: auto)
  #pagebreak()
  #outline(title: [Índice de figuras], target: figure.where(kind: image))
  #pagebreak()
  #outline(title: [Índice de tablas], target: figure.where(kind: table))
  #pagebreak()
  #outline(title: [Índice de listados], target: figure.where(kind: raw))
]

// ============================
//  Mainmatter (numeración arábiga, capítulos 1–6)
// ============================
#mainmatter[

  // --- Parte I: El dato como estimando ----------------------
  #include "partes_de/parte1_de.typ"
  #include "capitulos_de/cap01_causalidad_elemental_datos.typ"   // Cap. 1
  #include "capitulos_de/cap02_anatomia_sistema_decision.typ"    // Cap. 2
  #include "capitulos_de/cap03_contratos_datos_causales.typ"     // Cap. 3
  #include "capitulos_de/cap04_versionado_linaje.typ"            // Cap. 4

  // --- Parte II: El pipeline que preserva la identificación -
  #include "partes_de/parte2_de.typ"
  #include "capitulos_de/cap05_splits_pared_evaluacion.typ"       // Cap. 5
  #include "capitulos_de/cap06_validez_temporal_fuga.typ"         // Cap. 6
  #include "capitulos_de/cap07_calidad_observabilidad.typ"          // Cap. 7
  #include "capitulos_de/cap08_benchmark_dgp.typ"                    // Cap. 8

  // --- Parte III: Lo que el estimador le exige al dato --------
  #include "partes_de/parte3_de.typ"
  #include "capitulos_de/cap09_lo_que_dml_exige.typ"                    // Cap. 9
  #include "capitulos_de/cap10_heterogeneidad_politica.typ"           // Cap. 10 — Iter 2
  #include "capitulos_de/cap11_diagnostico_sin_verdad.typ"            // Cap. 11 — Iter 2

  // --- Parte IV: Operación ------------------------------------
  #include "partes_de/parte4_de.typ"
  #include "capitulos_de/cap12_puerta_causal_datos.typ"                 // Cap. 12 — Iter 3
  #include "capitulos_de/cap13_servicio_abstencion.typ"                 // Cap. 13 — Iter 3
  #include "capitulos_de/cap14_observabilidad_produccion.typ"           // Cap. 14 — Iter 4
  #include "capitulos_de/cap15_tarjeta_end_to_end.typ"                  // Cap. 15 — Iter 4
]

// ============================
//  Back matter (índices y erratas)
// ============================
#appendix-mode[
  #include "apendices_de/indice_tematico_de.typ"
  #include "apendices_de/indice_autores_de.typ"
  #include "apendices_de/erratas_de.typ"
]

// ============================
//  Bibliografía
// ============================
#state("chapter-kind").update("frontmatter")
#pagebreak()
#bibliography("bibliografia/refs.yml", title: "Bibliografía", style: "chicago-author-date")
