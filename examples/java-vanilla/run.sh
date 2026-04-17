#!/usr/bin/env bash
# Run the vanilla Java (Gradle + protobuf-gradle-plugin) gRPC example.
#
# Requirements: JDK 17+, gradle on PATH (or use the Gradle Wrapper if added later).
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
./sync-proto.sh >/dev/null
gradle --no-daemon -q installDist >/dev/null

status=0
for fixture in "$@"; do
  if ! DOCLING_GRPC_ADDR="${DOCLING_GRPC_ADDR:-127.0.0.1:50051}" \
       ./build/install/java-vanilla/bin/java-vanilla "$fixture"; then
    status=1
  fi
done
exit "$status"
