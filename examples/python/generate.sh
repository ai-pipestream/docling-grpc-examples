#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/src"

python3 -m grpc_tools.protoc \
  -I "${ROOT_DIR}/proto" \
  --python_out="${OUT_DIR}" \
  --grpc_python_out="${OUT_DIR}" \
  "${ROOT_DIR}/proto/ai/docling/core/v1/docling_document.proto" \
  "${ROOT_DIR}/proto/ai/docling/serve/v1/docling_serve_types.proto" \
  "${ROOT_DIR}/proto/ai/docling/serve/v1/docling_serve.proto"

find "${OUT_DIR}/ai" -type d -exec sh -c 'touch "$1/__init__.py"' _ {} \;
