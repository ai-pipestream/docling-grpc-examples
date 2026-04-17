#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${ROOT_DIR}/.work"
CORE_DIR="${WORK_DIR}/docling-core"
SERVE_DIR="${WORK_DIR}/docling-serve"
DOCLING_GRPC_ADDR="${DOCLING_GRPC_ADDR:-localhost:50051}"
DOCLING_GRPC_PORT="${DOCLING_GRPC_PORT:-50051}"
CORE_SHA="${CORE_SHA:-REPLACE_WITH_DOCLING_CORE_SHA}"
SERVE_SHA="${SERVE_SHA:-REPLACE_WITH_DOCLING_SERVE_SHA}"
SERVE_PID=""

cleanup() {
  if [[ -n "${SERVE_PID}" ]] && kill -0 "${SERVE_PID}" 2>/dev/null; then
    kill "${SERVE_PID}" 2>/dev/null || true
    wait "${SERVE_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

has() {
  command -v "$1" >/dev/null 2>&1
}

wait_for_port() {
  local addr="$1"
  local host="${addr%:*}"
  local port="${addr##*:}"
  local max_wait=60
  local waited=0
  while (( waited < max_wait )); do
    if python3 - "$host" "$port" <<'PY'
import socket, sys
host = sys.argv[1]
port = int(sys.argv[2])
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(1)
try:
    s.connect((host, port))
    print("ready")
    sys.exit(0)
except OSError:
    sys.exit(1)
finally:
    s.close()
PY
    then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

example_runnable() {
  local name="$1"
  case "$name" in
    python) has python3 && has uv && has protoc ;;
    java-quarkus) has java && has mvn && has protoc ;;
    java-vanilla) has java && has gradle && has protoc ;;
    go) has go && has protoc ;;
    node) has node && has npm && has protoc ;;
    *) return 1 ;;
  esac
}

echo "Detected toolchains:"
for tool in python3 uv java mvn gradle go node npm protoc; do
  if has "$tool"; then
    echo "  - ${tool}: yes"
  else
    echo "  - ${tool}: no"
  fi
done

echo
for example in python java-quarkus java-vanilla go node; do
  if example_runnable "$example"; then
    echo "example ${example}: runnable"
  else
    echo "example ${example}: skipped (missing toolchain)"
  fi
done

if [[ "${CORE_SHA}" == REPLACE_WITH_* ]] || [[ "${SERVE_SHA}" == REPLACE_WITH_* ]]; then
  echo "Set CORE_SHA and SERVE_SHA in bootstrap/run.sh (or export env vars) before running integration bootstrap."
  echo "Use pinned commits from docling-project/docling-core and docling-project/docling-serve."
  exit 1
fi

mkdir -p "$WORK_DIR"
if [[ ! -d "${CORE_DIR}/.git" ]]; then
  git clone https://github.com/docling-project/docling-core.git "$CORE_DIR"
fi
if [[ ! -d "${SERVE_DIR}/.git" ]]; then
  git clone https://github.com/docling-project/docling-serve.git "$SERVE_DIR"
fi

git -C "$CORE_DIR" fetch origin "$CORE_SHA"
git -C "$CORE_DIR" checkout "$CORE_SHA"
git -C "$SERVE_DIR" fetch origin "$SERVE_SHA"
git -C "$SERVE_DIR" checkout "$SERVE_SHA"

( cd "$CORE_DIR" && uv sync )
( cd "$SERVE_DIR" && uv sync )

(
  cd "$SERVE_DIR"
  DOCLING_GRPC_ENABLED=1 DOCLING_GRPC_PORT="$DOCLING_GRPC_PORT" uv run python -m docling_serve.main
) &
SERVE_PID="$!"

if ! wait_for_port "$DOCLING_GRPC_ADDR"; then
  echo "docling-serve gRPC port did not open at ${DOCLING_GRPC_ADDR}" >&2
  exit 1
fi

run_example() {
  local example="$1"
  local fixture="$2"
  local fixture_path="${ROOT_DIR}/fixtures/pdf/${fixture}"
  local pass_line="PASS ${example} ${fixture}"
  local fail_line="FAIL ${example} ${fixture}"

  case "$example" in
    python)
      (cd "${ROOT_DIR}/examples/python" && ./generate.sh && uv sync && DOCLING_GRPC_ADDR="$DOCLING_GRPC_ADDR" uv run python src/docling_example/main.py "$fixture_path") && echo "$pass_line" || { echo "$fail_line"; return 1; }
      ;;
    java-quarkus)
      (cd "${ROOT_DIR}/examples/java-quarkus" && ./sync-proto.sh && mvn -q -DskipTests package && DOCLING_GRPC_ADDR="$DOCLING_GRPC_ADDR" mvn -q -Dexec.mainClass=org.example.docling.quarkus.Main -Dexec.args="$fixture_path" exec:java) && echo "$pass_line" || { echo "$fail_line"; return 1; }
      ;;
    java-vanilla)
      (cd "${ROOT_DIR}/examples/java-vanilla" && ./sync-proto.sh && gradle --no-daemon run --args="$fixture_path") && echo "$pass_line" || { echo "$fail_line"; return 1; }
      ;;
    go)
      (cd "${ROOT_DIR}/examples/go" && ./generate.sh && DOCLING_GRPC_ADDR="$DOCLING_GRPC_ADDR" go run . "$fixture_path") && echo "$pass_line" || { echo "$fail_line"; return 1; }
      ;;
    node)
      (cd "${ROOT_DIR}/examples/node" && ./generate.sh && npm ci && DOCLING_GRPC_ADDR="$DOCLING_GRPC_ADDR" npm run run -- "$fixture_path") && echo "$pass_line" || { echo "$fail_line"; return 1; }
      ;;
  esac
}

for example in python java-quarkus java-vanilla go node; do
  if example_runnable "$example"; then
    run_example "$example" clean.pdf
    run_example "$example" scanned.pdf
  fi
done
