# bootstrap/run.sh

`run.sh` is the top-level smoke test runner.

What it does:

1. Detects required toolchains and reports runnable examples on the current machine.
2. Clones `docling-core` and `docling-serve` into `.work/` at pinned SHAs.
3. Runs `uv sync` in both repositories.
4. Starts `docling-serve` with gRPC enabled (`DOCLING_GRPC_PORT`, default `50051`).
5. Regenerates/builds/runs each runnable example against `fixtures/pdf/clean.pdf` and `fixtures/pdf/scanned.pdf`.
6. Stops `docling-serve` on normal exit or Ctrl+C.

Before first real run, replace the placeholder SHAs in `run.sh` and replace fixture placeholders in `fixtures/pdf/`.
