# Java Quarkus example

This example is the reference for replacing a Quarkus-specific docling plugin with a thin gRPC client generated from IDL. It keeps Quarkus in the stack while removing bespoke plugin protocol code.

## Prerequisites

- JDK 17+
- Maven
- `protoc`

## Generate stubs and build

```bash
./sync-proto.sh
mvn package
```

## Run

```bash
DOCLING_GRPC_ADDR=localhost:50051 mvn -q -Dexec.mainClass=org.example.docling.quarkus.Main -Dexec.args="../../fixtures/pdf/clean.pdf" exec:java
DOCLING_GRPC_ADDR=localhost:50051 mvn -q -Dexec.mainClass=org.example.docling.quarkus.Main -Dexec.args="../../fixtures/pdf/scanned.pdf" exec:java
```

Expected output: one-line `PASS java-quarkus ...` on success.
