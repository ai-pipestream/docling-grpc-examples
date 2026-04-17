# Python example

## Prerequisites

- Python 3.11+
- `uv`
- `protoc`

## Generate stubs

```bash
./generate.sh
```

## Run

```bash
uv sync
DOCLING_GRPC_ADDR=localhost:50051 uv run python src/docling_example/main.py ../../fixtures/pdf/clean.pdf
DOCLING_GRPC_ADDR=localhost:50051 uv run python src/docling_example/main.py ../../fixtures/pdf/scanned.pdf
```

Expected output: one line per run, `PASS python ...` on success and `FAIL python ...` on assertion or RPC error.
