import base64
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import grpc
from ai.docling.serve.v1 import docling_serve_pb2, docling_serve_pb2_grpc, docling_serve_types_pb2

# Match docling-serve's 2 GB server-side message limits so realistic PDFs
# don't trip the default 4 MB client receive cap.
GRPC_MAX_MESSAGE_BYTES = 2 * 1024 * 1024 * 1024 - 1
CHANNEL_OPTIONS = [
    ("grpc.max_send_message_length", GRPC_MAX_MESSAGE_BYTES),
    ("grpc.max_receive_message_length", GRPC_MAX_MESSAGE_BYTES),
]


def expected_snapshot_for_fixture(fixture: Path) -> dict:
    expected_name = fixture.stem + ".json"
    expected_path = fixture.parents[1] / "expected" / expected_name
    return json.loads(expected_path.read_text(encoding="utf-8"))


def extract_text_items(doc) -> list[str]:
    values = []
    for item in doc.texts:
        kind = item.WhichOneof("item")
        if kind == "code":
            text = item.code.text
        else:
            wrapped = getattr(item, kind)
            text = wrapped.base.text
        text = text.strip()
        if text:
            values.append(text)
    return values


def assert_structural(snapshot: dict, response) -> None:
    doc = response.response.document.doc
    texts = extract_text_items(doc)
    pages = len(doc.pages)

    if pages < int(snapshot.get("min_pages", 1)):
        raise AssertionError(f"pages={pages} below min_pages")

    if len(texts) < int(snapshot.get("min_non_empty_text_items", 1)):
        raise AssertionError("not enough non-empty text items")

    merged = "\n".join(texts).lower()
    for token in snapshot.get("required_tokens", []):
        if token.lower() not in merged:
            raise AssertionError(f"missing required token: {token}")

    if snapshot.get("ocr_required", False):
        if not any(len(t.split()) >= 3 for t in texts):
            raise AssertionError("ocr_required but no OCR-like text span found")


def run() -> int:
    if len(sys.argv) != 2:
        print("FAIL usage: main.py <fixture.pdf>")
        return 2

    fixture = Path(sys.argv[1]).resolve()
    addr = os.environ.get("DOCLING_GRPC_ADDR", "localhost:50051")

    source = docling_serve_types_pb2.Source(
        file=docling_serve_types_pb2.FileSource(
            filename=fixture.name,
            base64_string=base64.b64encode(fixture.read_bytes()).decode("ascii"),
        )
    )

    request = docling_serve_pb2.ConvertSourceRequest(
        request=docling_serve_types_pb2.ConvertDocumentRequest(sources=[source])
    )

    try:
        channel = grpc.insecure_channel(addr, options=CHANNEL_OPTIONS)
        stub = docling_serve_pb2_grpc.DoclingServeServiceStub(channel)
        response = stub.ConvertSource(request, timeout=120)
        assert_structural(expected_snapshot_for_fixture(fixture), response)
    except Exception as exc:  # noqa: BLE001
        print(f"FAIL python fixture={fixture.name} error={exc}")
        return 1

    print(f"PASS python fixture={fixture.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
