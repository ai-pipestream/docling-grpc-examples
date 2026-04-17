#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$(dirname "${BASH_SOURCE[0]}")"
mkdir -p gen

protoc -I "${ROOT_DIR}/proto" \
  --go_out=./gen \
  --go-grpc_out=./gen \
  --go_opt=paths=source_relative \
  --go-grpc_opt=paths=source_relative \
  --go_opt=Mai/docling/core/v1/docling_document.proto=github.com/ai-pipestream/docling-grpc-examples/examples/go/gen/ai/docling/core/v1 \
  --go_opt=Mai/docling/serve/v1/docling_serve_types.proto=github.com/ai-pipestream/docling-grpc-examples/examples/go/gen/ai/docling/serve/v1 \
  --go_opt=Mai/docling/serve/v1/docling_serve.proto=github.com/ai-pipestream/docling-grpc-examples/examples/go/gen/ai/docling/serve/v1 \
  --go-grpc_opt=Mai/docling/core/v1/docling_document.proto=github.com/ai-pipestream/docling-grpc-examples/examples/go/gen/ai/docling/core/v1 \
  --go-grpc_opt=Mai/docling/serve/v1/docling_serve_types.proto=github.com/ai-pipestream/docling-grpc-examples/examples/go/gen/ai/docling/serve/v1 \
  --go-grpc_opt=Mai/docling/serve/v1/docling_serve.proto=github.com/ai-pipestream/docling-grpc-examples/examples/go/gen/ai/docling/serve/v1 \
  "${ROOT_DIR}/proto/ai/docling/core/v1/docling_document.proto" \
  "${ROOT_DIR}/proto/ai/docling/serve/v1/docling_serve_types.proto" \
  "${ROOT_DIR}/proto/ai/docling/serve/v1/docling_serve.proto"
