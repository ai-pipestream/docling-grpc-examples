#!/usr/bin/env bash
# Run the Go gRPC example against one or more fixtures.
#
# Requirements: go 1.22+, protoc + protoc-gen-go + protoc-gen-go-grpc on PATH.
#   Install with:
#     go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
#     go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
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
./generate.sh >/dev/null
go mod tidy >/dev/null 2>&1

status=0
for fixture in "$@"; do
  if ! go run . "$fixture"; then
    status=1
  fi
done
exit "$status"
