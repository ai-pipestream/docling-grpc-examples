# docling-grpc-examples

Multi-language gRPC client examples for [`docling-serve`](https://github.com/docling-project/docling-serve), driven entirely from the `.proto` IDL in this repository. The point of this repo is to make it obvious that adding a gRPC interface to docling-serve is not a Python-only feature: every language that has a gRPC stack gets a first-class client for free, with the Pydantic models in `docling-core` remaining the single source of truth.

The examples are intentionally **not** part of any CI in the upstream `docling-core` / `docling-serve` PRs. They live here so reviewers (and curious users) can run them locally without dragging multi-language toolchains into the upstream maintenance burden.

## Tracked PRs

These examples target the in-flight gRPC PRs:

- [`docling-project/docling-core#546`](https://github.com/docling-project/docling-core/pull/546)
- [`docling-project/docling-serve#504`](https://github.com/docling-project/docling-serve/pull/504)

Until those merge, the bootstrap script defaults to `pr/546` and `pr/504`. After they merge, set `DOCLING_CORE_REF=main` and `DOCLING_SERVE_REF=main` (or pin a tag).

## Repository layout

```
proto/                              # vendored copy of the upstream .proto IDL
fixtures/
  pdf/clean.pdf                     # text-native PDF (DocLayNet paper)
  pdf/scanned.pdf                   # same content rendered to images for OCR
  expected/{clean,scanned}.json     # structural assertions per fixture
bootstrap/
  run.sh                            # orchestrator: brings up server + runs all detected examples
examples/
  python/                           # uv + grpcio
  go/                               # protoc-gen-go + grpc-go
  java-vanilla/                     # Gradle + protobuf-gradle-plugin + grpc-java
  node/                             # @grpc/grpc-js + grpc-tools (TypeScript via tsx)
  rust/                             # tonic + prost (compile-time stub gen via tonic-build)
```

Each language directory ships a `run.sh` that handles its own stub generation, dependency install, and execution against both fixtures. You only need the toolchains for the languages you care about.

## Quickstart

You need at least `git`, `gh`, and `uv` to bring up the server. Install only the toolchains for the languages you want to exercise.

```bash
./bootstrap/run.sh
```

That script:

1. Detects which language toolchains are present and prints a runnable list.
2. Checks out [`docling-project/docling-core`](https://github.com/docling-project/docling-core) and [`docling-project/docling-serve`](https://github.com/docling-project/docling-serve) into `.work/` at the configured refs (PR refs by default).
3. Runs `uv sync` in the docling-serve checkout.
4. Starts the gRPC server via `uv run docling-serve-grpc run --host ... --port ...`.
5. Runs every detected `examples/<lang>/run.sh` against both fixtures.
6. Tears the server down on exit.

### Run a single language directly

If you already have a docling-serve gRPC server running, you can skip the orchestrator entirely:

```bash
export DOCLING_GRPC_ADDR=127.0.0.1:50051
examples/python/run.sh
examples/go/run.sh
examples/java-vanilla/run.sh
examples/node/run.sh
examples/rust/run.sh
```

Each `run.sh` accepts optional fixture paths; with no args it runs both bundled PDFs.

## Toolchain matrix

| Example | Toolchain | Notes |
| --- | --- | --- |
| `examples/python` | Python 3.11+, `uv` | Stubs generated via `grpcio-tools` (no system `protoc` needed). |
| `examples/go` | Go 1.22+, `protoc`, `protoc-gen-go`, `protoc-gen-go-grpc` | Install the gen plugins with `go install google.golang.org/protobuf/cmd/protoc-gen-go@latest` and `go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest`. |
| `examples/java-vanilla` | JDK 17+, Gradle | Uses the protobuf Gradle plugin; bundles its own `protoc` artifact. |
| `examples/node` | Node.js 20+, npm | Uses `grpc-tools` (bundled `protoc`) via `npx`. |
| `examples/rust` | Rust stable (1.74+), `protoc` | `tonic-build` runs `protoc` at compile time and emits stubs into `target/`; nothing is committed. |

`gh` and `git` are used by the bootstrap orchestrator to fetch upstream PR refs; they are not required by the individual `run.sh` scripts.

## Fixtures and assertions

Both fixtures are derived from the [DocLayNet paper](https://arxiv.org/abs/2206.01062) (`2206.01062v1.pdf`). `clean.pdf` is the original text-native PDF; `scanned.pdf` is the same paper rasterised to 150 DPI JPEGs and re-stitched, forcing the server's OCR pipeline.

The structural assertions per fixture (`fixtures/expected/<fixture>.json`) are deliberately conservative so they keep passing across model upgrades:

- `min_pages` — must have at least N pages in the response.
- `min_non_empty_text_items` — must yield at least N non-empty `BaseTextItem` entries after walking the `texts` `oneof`.
- `required_tokens` — substrings (case-insensitive) that must appear in the merged text.
- `ocr_required` — at least one extracted text span must contain three or more whitespace-separated tokens, used as a sanity check that OCR is actually producing prose.

Every example performs the same checks, so a passing run in one language is a fair proxy for the others.

## Design notes

- **Pydantic remains the source of truth.** The proto files in `proto/` are the wire contract for non-Python clients only. The upstream gRPC server validates parity at startup so any drift between Pydantic and proto produces a server-side warning rather than a silent client incompatibility.
- **No `buf`, no per-language CI here.** Stub generation in each example uses either the language's native toolchain (`grpc_tools`, `grpc-tools`, `protoc-gen-go-*`, `protobuf-gradle-plugin`) or vendored `protoc`. The upstream PRs use `protoc` only.
- **2 GB message ceiling.** All four examples raise client message size limits to match the server (default gRPC client cap of 4 MB is too small for realistic `DoclingDocument` responses).
- **Quarkus.** A naive Quarkus example was prototyped here and removed because it didn't use any Quarkus-idiomatic constructs (`@GrpcClient`, dev services, native image hints). A proper Quarkus extension belongs in its own repo and will likely live under [`quarkiverse/quarkus-docling`](https://github.com/quarkiverse/quarkus-docling) once the gRPC API is upstream.

## Contributing a new language

The bar to add a language is intentionally low:

1. Create `examples/<lang>/` with a `generate.sh` (or equivalent) that emits stubs from `proto/` into a gitignored output directory.
2. Add a `run.sh` that takes optional fixture paths and prints `PASS <lang> fixture=<name>` or `FAIL <lang> fixture=<name> error=<msg>` per fixture.
3. Mirror the structural checks in `assert_structural` from `examples/python/src/docling_example/main.py`.
4. Add `<lang>` to the loop in `bootstrap/run.sh` and update the toolchain matrix above.

Generated artefacts must be gitignored. The repository never commits stubs.
