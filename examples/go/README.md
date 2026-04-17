# Go example

## Prerequisites

- Go 1.22+
- `protoc`
- `protoc-gen-go`
- `protoc-gen-go-grpc`

## Generate stubs

```bash
go generate ./...
```

## Run

```bash
DOCLING_GRPC_ADDR=localhost:50051 go run . ../../fixtures/pdf/clean.pdf
DOCLING_GRPC_ADDR=localhost:50051 go run . ../../fixtures/pdf/scanned.pdf
```

Expected output: one line `PASS go ...` per run.
