# B3 — Servicio de política

Sirve una política CATE bajo un presupuesto explícito; la política no sustituye la identificación.

Ejecuta el componente desde su carpeta y usa únicamente artefactos que hayas generado a partir de datos observados. Si falta el artefacto de entrada, registra `abstención` y vuelve a la etapa anterior. Los comandos de evaluación docente y los autograders no se distribuyen en este repositorio.

Los hashes del manifiesto comprueban cambios de bytes respecto de ese manifiesto, no la procedencia ni la seguridad del contenido. La deserialización de `joblib`/pickle puede ejecutar código y actualmente puede ocurrir antes de validar el manifiesto: carga únicamente bundles procedentes de una fuente confiable y consérvalos en un sistema de archivos confiable. Un hash coincidente no vuelve seguro un artefacto no confiable ni evita cambios entre validación y uso.
