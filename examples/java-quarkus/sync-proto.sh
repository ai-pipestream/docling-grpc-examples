#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/src/main/proto"
rm -rf "${TARGET_DIR}/ai"
mkdir -p "${TARGET_DIR}"
cp -R "${ROOT_DIR}/proto/ai" "${TARGET_DIR}/"
