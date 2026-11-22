# Distribución canónica de src/: servidor MCP por stdio, sin privilegios.
FROM python:3.12-slim

RUN useradd -m -u 1000 mcp \
    && mkdir -p /workspace \
    && chown mcp:mcp /workspace

WORKDIR /app
COPY pyproject.toml README.md ./
COPY src/ src/
RUN pip install --no-cache-dir ".[mcp]"

USER mcp
ENV MCP_CAUSAL_WORKSPACE=/workspace
VOLUME ["/workspace"]

# MCP usa stdio: no se abre ningún puerto ni se simula un health check HTTP.
CMD ["mcp-causal", "serve", "--workspace", "/workspace"]
