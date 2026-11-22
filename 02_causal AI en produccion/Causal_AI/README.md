# Compilación de las ediciones

Requiere Typst 0.15.1 o una versión compatible. Desde este directorio, compile sin sobrescribir los PDF versionados:

```sh
typst compile --root . main.typ /tmp/Causal_AI-curso.pdf
typst compile --root . --input modo=comercial main.typ /tmp/Causal_AI-comercial.pdf
typst compile --root . --input modo=principios main.typ /tmp/Causal_AI-principios.pdf
```

- `curso` (predeterminado): conserva el aparato docente, los apéndices E y J y la capa de implementación L3.
- `comercial`: sustituye los callouts del monorepo por notas genéricas y excluye los apéndices docentes E y J; conserva L3.
- `principios`: aplica las exclusiones de `comercial` y además excluye el apéndice B y toda la capa L3. Mantiene la teoría, los métodos y los contratos compartidos.

Un valor distinto de `modo` produce un error de compilación; no se sustituye silenciosamente por `curso`. Por ejemplo, este comando debe fallar:

```sh
typst compile --root . --input modo=invalido main.typ /tmp/Causal_AI-invalido.pdf
```

La primera compilación puede necesitar descargar paquetes de Typst declarados por la plantilla.
