import fs from "node:fs";
import path from "node:path";
import * as grpc from "@grpc/grpc-js";

const serveGrpc = require("./gen/ai/docling/serve/v1/docling_serve_grpc_pb.js");
const servePb = require("./gen/ai/docling/serve/v1/docling_serve_pb.js");
const typesPb = require("./gen/ai/docling/serve/v1/docling_serve_types_pb.js");
const corePb = require("./gen/ai/docling/core/v1/docling_document_pb.js");

// Match docling-serve's 2 GB server-side message limits so realistic PDFs
// don't trip the default 4 MB client receive cap.
const GRPC_MAX_MESSAGE_BYTES = 2 * 1024 * 1024 * 1024 - 1;
const CHANNEL_OPTIONS = {
  "grpc.max_receive_message_length": GRPC_MAX_MESSAGE_BYTES,
  "grpc.max_send_message_length": GRPC_MAX_MESSAGE_BYTES,
};

const ItemCase = corePb.BaseTextItem.ItemCase;

function readExpected(fixturePath: string) {
  const expectedName = path.basename(fixturePath).replace(".pdf", ".json");
  const expectedPath = path.resolve(path.dirname(path.dirname(fixturePath)), "expected", expectedName);
  return JSON.parse(fs.readFileSync(expectedPath, "utf8"));
}

function extractTexts(doc: any): string[] {
  const out: string[] = [];
  for (const item of doc.getTextsList()) {
    let text = "";
    switch (item.getItemCase()) {
      case ItemCase.TITLE:
        text = item.getTitle()?.getBase()?.getText() || "";
        break;
      case ItemCase.SECTION_HEADER:
        text = item.getSectionHeader()?.getBase()?.getText() || "";
        break;
      case ItemCase.LIST_ITEM:
        text = item.getListItem()?.getBase()?.getText() || "";
        break;
      case ItemCase.FORMULA:
        text = item.getFormula()?.getBase()?.getText() || "";
        break;
      case ItemCase.TEXT:
        text = item.getText()?.getBase()?.getText() || "";
        break;
      case ItemCase.FIELD_HEADING:
        text = item.getFieldHeading()?.getBase()?.getText() || "";
        break;
      case ItemCase.FIELD_VALUE:
        text = item.getFieldValue()?.getBase()?.getText() || "";
        break;
      case ItemCase.CODE:
        text = item.getCode()?.getText() || "";
        break;
    }
    const cleaned = text.trim();
    if (cleaned) out.push(cleaned);
  }
  return out;
}

function assertStructural(expected: any, doc: any) {
  const pages = doc.getPagesMap().getLength();
  const texts = extractTexts(doc);

  if (pages < (expected.min_pages ?? 1)) throw new Error("pages below threshold");
  if (texts.length < (expected.min_non_empty_text_items ?? 1)) throw new Error("text items below threshold");

  const merged = texts.join("\n").toLowerCase();
  for (const token of expected.required_tokens ?? []) {
    if (token && !merged.includes(String(token).toLowerCase())) {
      throw new Error(`missing token ${token}`);
    }
  }

  if (expected.ocr_required && !texts.some((t) => t.split(/\s+/).length >= 3)) {
    throw new Error("ocr-required text missing");
  }
}

async function main() {
  if (process.argv.length !== 3) {
    console.log("FAIL node usage: index.ts <fixture.pdf>");
    process.exit(2);
  }

  const fixturePath = path.resolve(process.argv[2]);
  const addr = process.env.DOCLING_GRPC_ADDR || "localhost:50051";

  const fileSource = new typesPb.FileSource();
  fileSource.setFilename(path.basename(fixturePath));
  fileSource.setBase64String(fs.readFileSync(fixturePath).toString("base64"));

  const source = new typesPb.Source();
  source.setFile(fileSource);

  const convertRequest = new typesPb.ConvertDocumentRequest();
  convertRequest.addSources(source);

  const wrapper = new servePb.ConvertSourceRequest();
  wrapper.setRequest(convertRequest);

  const client = new serveGrpc.DoclingServeServiceClient(
    addr,
    grpc.credentials.createInsecure(),
    CHANNEL_OPTIONS,
  );

  client.convertSource(wrapper, (err: Error | null, response: any) => {
    if (err) {
      console.log(`FAIL node fixture=${path.basename(fixturePath)} error=${err.message}`);
      process.exit(1);
    }
    try {
      const doc = response.getResponse().getDocument().getDoc();
      assertStructural(readExpected(fixturePath), doc);
      console.log(`PASS node fixture=${path.basename(fixturePath)}`);
      process.exit(0);
    } catch (e: any) {
      console.log(`FAIL node fixture=${path.basename(fixturePath)} error=${e.message}`);
      process.exit(1);
    }
  });
}

main();
