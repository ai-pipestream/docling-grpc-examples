# docling-grpc-examples

Minimal multi-language gRPC examples for `docling-serve` using only `.proto` IDL from this repository.

## Prerequisites

- `protoc`
- Python 3.11+ and `uv`
- JDK 17+, Maven, Gradle
- Go 1.22+
- Node.js 20+ and npm

## Quickstart

```bash
./bootstrap/run.sh
```

The bootstrap script starts a local `docling-serve` gRPC server, regenerates stubs, and runs each available example against both fixtures.

## Upstream references

- `docling-project/docling-core#546`
- `docling-project/docling-serve#504`

## Design rationale

`docling-core` Pydantic models are the source of truth, and these proto files are the wire contract for non-Python clients. Each example regenerates stubs directly from `proto/` at build time so schema drift is caught by runtime validation and compile-time type checks in each language.

## Examples

| Example | Build tool | Status |
| --- | --- | --- |
| `examples/python` | `uv` | ConvertSource client |
| `examples/java-quarkus` | Maven (Quarkus gRPC extension) | ConvertSource client |
| `examples/java-vanilla` | Gradle + protobuf plugin | ConvertSource client |
| `examples/go` | `go generate` + `go run` | ConvertSource client |
| `examples/node` | npm + grpc-tools | ConvertSource client |
