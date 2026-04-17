#!/usr/bin/env bash
# Run the Python gRPC example against one or more fixtures.
#
# Requirements: python 3.11+, uv, protoc (via grpcio-tools, installed by uv sync).
# Env: DOCLING_GRPC_ADDR (default 127.0.0.1:50051).
#
# Usage:
#   ./run.sh                      # runs both bundled fixtures
#   ./run.sh /abs/path/to/x.pdf   # runs a specific fixture
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${HERE}/../.." && pwd)"

if (($# == 0)); then
  set -- "${ROOT_DIR}/fixtures/pdf/clean.pdf" "${ROOT_DIR}/fixtures/pdf/scanned.pdf"
fi

cd "$HERE"
uv sync >/dev/null
./generate.sh >/dev/null

status=0
for fixture in "$@"; do
  if ! uv run python src/docling_example/main.py "$fixture"; then
    status=1
  fi
done
exit "$status"
