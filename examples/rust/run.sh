#!/usr/bin/env bash
# Run the Rust (tonic + prost) gRPC example against one or more fixtures.
#
# Requirements: cargo (stable), protoc on PATH (used by tonic-build at compile
# time). On Debian/Ubuntu: `sudo apt install -y protobuf-compiler`.
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
cargo build --release --quiet

BIN="$HERE/target/release/docling-rust-example"

status=0
for fixture in "$@"; do
  if ! "$BIN" "$fixture"; then
    status=1
  fi
done
exit "$status"
