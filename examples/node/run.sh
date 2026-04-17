#!/usr/bin/env bash
# Run the Node.js (TypeScript) gRPC example against one or more fixtures.
#
# Requirements: Node.js 20+, npm.
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
if [[ -f package-lock.json ]]; then
  npm ci --silent
else
  npm install --silent
fi
./generate.sh >/dev/null

status=0
for fixture in "$@"; do
  if ! npx --no-install tsx src/index.ts "$fixture"; then
    status=1
  fi
done
exit "$status"
