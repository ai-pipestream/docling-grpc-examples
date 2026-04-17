# Fixtures and snapshots

The files in `fixtures/pdf/` and `fixtures/expected/` are placeholders. Replace them with license-clean fixture PDFs and refreshed expected snapshots before publishing benchmark or compatibility results.

## Snapshot contract

Each `fixtures/expected/*.json` file defines structural assertions used by every example:

- minimum page count
- minimum count of non-empty text items
- optional token checks for expected text content
- `ocr_required` flag for scanned/OCR fixtures

Assertions are structural, not byte-for-byte protobuf or JSON equality.

## Refreshing snapshots

1. Replace fixture PDFs.
2. Run a known-good client against `ConvertSource`.
3. Inspect the response and update `fixtures/expected/*.json` threshold values.
4. Re-run `./bootstrap/run.sh` and confirm every example passes.
