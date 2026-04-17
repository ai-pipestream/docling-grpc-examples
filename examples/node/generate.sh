#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/src/gen"
mkdir -p "$OUT_DIR"

./node_modules/.bin/grpc_tools_node_protoc \
  -I "${ROOT_DIR}/proto" \
  --js_out=import_style=commonjs,binary:"${OUT_DIR}" \
  --grpc_out=grpc_js:"${OUT_DIR}" \
  "${ROOT_DIR}/proto/ai/docling/core/v1/docling_document.proto" \
  "${ROOT_DIR}/proto/ai/docling/serve/v1/docling_serve_types.proto" \
  "${ROOT_DIR}/proto/ai/docling/serve/v1/docling_serve.proto"
