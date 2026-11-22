#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# uv fijado por versión y SHA-256 (release 0.13.8 de astral-sh/uv). Si ya
# está instalado se reutiliza; si hay que instalarlo, el archivo se verifica
# antes de ejecutarlo y la instalación aborta si no coincide.
UV_VERSION="0.13.8"
UV_X64_MAC="a04c2ffeac28b2003a2c13caf538ab425fcd7def3e4a41571f4a8fb370a66af3"
UV_ARM_MAC="6b71028a6b904f2ae3340ef52e595512de807d06c0a20eaef2f692581b246558"
UV_X64_LINUX="5acfd9177cfecf0bf87578f059728215ccc884388988f55f7a65041b57387d91"
UV_ARM_LINUX="74f2f5c6024d397481db228db8fc25eed420db192243f88438c118e7e013e585"

if command -v uv >/dev/null 2>&1; then
  printf 'uv ya disponible: %s (se reutiliza)\n' "$(uv --version)"
else
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os/$arch" in
    Darwin/arm64|Darwin/aarch64)  varchivo="uv-aarch64-apple-darwin.tar.gz";       vsha="$UV_ARM_MAC" ;;
    Darwin/x86_64)                varchivo="uv-x86_64-apple-darwin.tar.gz";        vsha="$UV_X64_MAC" ;;
    Linux/aarch64|Linux/arm64)    varchivo="uv-aarch64-unknown-linux-gnu.tar.gz";  vsha="$UV_ARM_LINUX" ;;
    Linux/x86_64)                 varchivo="uv-x86_64-unknown-linux-gnu.tar.gz";   vsha="$UV_X64_LINUX" ;;
    *) printf 'Error: plataforma no soportada por este script (%s/%s). Instala uv manualmente: https://docs.astral.sh/uv\n' "$os" "$arch" >&2; exit 1 ;;
  esac
  url="https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${varchivo}"
  printf 'Instalando uv %s (%s)...\n' "$UV_VERSION" "$varchivo"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  archivo="$tmp/$varchivo"
  if command -v curl >/dev/null 2>&1; then
    curl -LsSf "$url" -o "$archivo"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$archivo"
  else
    printf 'Error: instala curl o wget y vuelve a ejecutar setup.sh.\n' >&2
    exit 1
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$archivo" | cut -d' ' -f1)"
  else
    actual="$(shasum -a 256 "$archivo" | cut -d' ' -f1)"
  fi
  if [ "$actual" != "$vsha" ]; then
    printf 'Error: SHA-256 de %s no coincide (esperado %s, obtenido %s). No se instaló nada.\n' "$varchivo" "$vsha" "$actual" >&2
    exit 1
  fi
  tar -xzf "$archivo" -C "$tmp"
  binario="$(find "$tmp" -type f -name uv | head -n 1)"
  if [ -z "$binario" ]; then
    printf 'Error: el archivo descargado no contiene el binario uv.\n' >&2
    exit 1
  fi
  bindir="$HOME/.local/bin"
  mkdir -p "$bindir"
  install -m 0755 "$binario" "$bindir/uv"
  rm -rf "$tmp"
  trap - EXIT
  export PATH="$bindir:$PATH"
fi

if ! command -v uv >/dev/null 2>&1; then
  printf 'Error: uv quedó instalado fuera de PATH. Abre otra terminal y repite el comando.\n' >&2
  exit 1
fi

uv python install 3.13
# Sin --clear: una venv existente se archiva en respaldo/ antes de crear la
# nueva (mismo patrón que el lanzador Windows). Nada se borra.
if [ -d .venv ]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p respaldo
  mv .venv "respaldo/venv-$stamp"
  printf '.venv existente archivada en respaldo/venv-%s\n' "$stamp"
fi
uv venv --python 3.13 .venv
uv pip install --python "$ROOT_DIR/.venv/bin/python" -r "$ROOT_DIR/requirements.txt"
uv pip check --python "$ROOT_DIR/.venv/bin/python"
"$ROOT_DIR/.venv/bin/python" --version

printf '\nInstalación lista. Ejecuta: bash arrancar.sh\n'
printf 'URL: http://127.0.0.1:8000\n'
printf 'Endpoints: http://127.0.0.1:8000/efecto\n'
printf '           http://127.0.0.1:8000/salud\n'
printf '           http://127.0.0.1:8000/docs\n'
