# Java vanilla example

## Prerequisites

- JDK 17+
- Gradle
- `protoc`

## Generate and run

```bash
./sync-proto.sh
gradle --no-daemon run --args="../../fixtures/pdf/clean.pdf"
gradle --no-daemon run --args="../../fixtures/pdf/scanned.pdf"
```

Set `DOCLING_GRPC_ADDR` to override `localhost:50051`.

Expected output: one line `PASS java-vanilla ...` per run.
