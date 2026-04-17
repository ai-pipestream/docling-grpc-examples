#!/usr/bin/env bash
# Top-level orchestrator: bring up a docling-serve gRPC server from upstream
# source and run every detected per-language example against both fixtures.
#
# Each example also has its own examples/<lang>/run.sh which is the supported
# way to run a single language. This script is just a convenience that wires
# them all together against a freshly-built server.
#
# Sources used (override via env):
#   DOCLING_CORE_REPO   default docling-project/docling-core
#   DOCLING_CORE_REF    default pr/546                (use 'main' once merged)
#   DOCLING_SERVE_REPO  default docling-project/docling-serve
#   DOCLING_SERVE_REF   default pr/504                (use 'main' once merged)
#
# A ref of the form pr/<N> triggers `gh pr checkout <N>`. Anything else is
# passed through to `git checkout`.
#
# Server bind address (override via env):
#   DOCLING_GRPC_HOST   default 127.0.0.1
#   DOCLING_GRPC_PORT   default 50051
#
# Toolchains: only the languages whose toolchains are present on PATH are
# exercised. Missing toolchains are listed and skipped, never installed.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${ROOT_DIR}/.work"
CORE_DIR="${WORK_DIR}/docling-core"
SERVE_DIR="${WORK_DIR}/docling-serve"

DOCLING_CORE_REPO="${DOCLING_CORE_REPO:-docling-project/docling-core}"
DOCLING_CORE_REF="${DOCLING_CORE_REF:-pr/546}"
DOCLING_SERVE_REPO="${DOCLING_SERVE_REPO:-docling-project/docling-serve}"
DOCLING_SERVE_REF="${DOCLING_SERVE_REF:-pr/504}"

DOCLING_GRPC_HOST="${DOCLING_GRPC_HOST:-127.0.0.1}"
DOCLING_GRPC_PORT="${DOCLING_GRPC_PORT:-50051}"
export DOCLING_GRPC_ADDR="${DOCLING_GRPC_HOST}:${DOCLING_GRPC_PORT}"

SERVE_PID=""
cleanup() {
  if [[ -n "${SERVE_PID}" ]] && kill -0 "${SERVE_PID}" 2>/dev/null; then
    kill "${SERVE_PID}" 2>/dev/null || true
    wait "${SERVE_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

has() { command -v "$1" >/dev/null 2>&1; }

require_one_of() {
  for tool in "$@"; do
    if ! has "$tool"; then
      echo "FATAL bootstrap requires '${tool}' on PATH" >&2
      exit 1
    fi
  done
}

example_runnable() {
  case "$1" in
    python)       has python3 && has uv ;;
    go)           has go && has protoc && has protoc-gen-go && has protoc-gen-go-grpc ;;
    java-vanilla) has java && has gradle ;;
    node)         has node && has npm ;;
    *) return 1 ;;
  esac
}

checkout_ref() {
  local repo="$1"
  local ref="$2"
  local dest="$3"

  mkdir -p "$(dirname "$dest")"
  if [[ ! -d "${dest}/.git" ]]; then
    if [[ "$ref" == pr/* ]]; then
      gh repo clone "$repo" "$dest" -- --quiet
    else
      git clone --quiet "https://github.com/${repo}.git" "$dest"
    fi
  fi

  if [[ "$ref" == pr/* ]]; then
    local pr_number="${ref#pr/}"
    ( cd "$dest" && gh pr checkout "$pr_number" --repo "$repo" )
  else
    ( cd "$dest" && git fetch --quiet origin "$ref" && git checkout --quiet "$ref" )
  fi
}

wait_for_grpc() {
  local addr="$1"
  local host="${addr%:*}"
  local port="${addr##*:}"
  local waited=0
  while ((waited < 90)); do
    if (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null; then
      exec 3<&- 3>&-
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

echo "Detected toolchains:"
for tool in python3 uv go protoc protoc-gen-go protoc-gen-go-grpc java gradle node npm gh; do
  printf '  - %-22s %s\n' "$tool" "$(has "$tool" && echo present || echo missing)"
done
echo

echo "Examples that will run:"
RUNNABLE=()
for ex in python go java-vanilla node; do
  if example_runnable "$ex"; then
    RUNNABLE+=("$ex")
    echo "  - ${ex}"
  else
    echo "  - ${ex}: skipped (missing toolchain)"
  fi
done
if ((${#RUNNABLE[@]} == 0)); then
  echo "FATAL no example toolchains detected" >&2
  exit 1
fi
echo

require_one_of git gh uv
mkdir -p "$WORK_DIR"

echo "Checking out ${DOCLING_CORE_REPO}@${DOCLING_CORE_REF} into ${CORE_DIR}"
checkout_ref "$DOCLING_CORE_REPO" "$DOCLING_CORE_REF" "$CORE_DIR"

echo "Checking out ${DOCLING_SERVE_REPO}@${DOCLING_SERVE_REF} into ${SERVE_DIR}"
checkout_ref "$DOCLING_SERVE_REPO" "$DOCLING_SERVE_REF" "$SERVE_DIR"

echo "Syncing docling-serve dependencies (this can take several minutes on first run)"
( cd "$SERVE_DIR" && uv sync --no-progress )

echo "Starting docling-serve gRPC server on ${DOCLING_GRPC_ADDR}"
(
  cd "$SERVE_DIR"
  exec uv run docling-serve-grpc run --host "$DOCLING_GRPC_HOST" --port "$DOCLING_GRPC_PORT"
) &
SERVE_PID=$!

if ! wait_for_grpc "$DOCLING_GRPC_ADDR"; then
  echo "FATAL docling-serve gRPC port did not open at ${DOCLING_GRPC_ADDR}" >&2
  exit 1
fi
echo "Server is up."
echo

results=()
overall=0
for ex in "${RUNNABLE[@]}"; do
  echo "===== ${ex} ====="
  if "${ROOT_DIR}/examples/${ex}/run.sh"; then
    results+=("PASS ${ex}")
  else
    results+=("FAIL ${ex}")
    overall=1
  fi
  echo
done

echo "===== summary ====="
printf '%s\n' "${results[@]}"
exit "$overall"
