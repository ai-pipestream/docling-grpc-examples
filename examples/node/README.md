# Node example

## Prerequisites

- Node.js 20+
- npm
- `protoc`

## Generate stubs

```bash
npm ci
npm run generate
```

## Run

```bash
DOCLING_GRPC_ADDR=localhost:50051 npm run run -- ../../fixtures/pdf/clean.pdf
DOCLING_GRPC_ADDR=localhost:50051 npm run run -- ../../fixtures/pdf/scanned.pdf
```

Expected output: one line `PASS node ...` per run.
