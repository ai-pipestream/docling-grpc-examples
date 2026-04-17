use anyhow::{anyhow, Context, Result};
use base64::Engine;
use serde::Deserialize;
use std::env;
use std::path::{Path, PathBuf};
use tokio::fs;
use tonic::transport::Channel;

// The proto packages reference each other (serve.v1 has fields of type
// core.v1.DoclingDocument). tonic-build emits `super::super::core::v1::...`
// for those, so the Rust module hierarchy here must mirror the protobuf
// package path exactly.
pub mod ai {
    pub mod docling {
        pub mod core {
            pub mod v1 {
                tonic::include_proto!("ai.docling.core.v1");
            }
        }
        pub mod serve {
            pub mod v1 {
                tonic::include_proto!("ai.docling.serve.v1");
            }
        }
    }
}

use ai::docling::core::v1::{base_text_item, BaseTextItem, DoclingDocument};
use ai::docling::serve::v1::docling_serve_service_client::DoclingServeServiceClient;
use ai::docling::serve::v1::{
    source, ConvertDocumentRequest, ConvertSourceRequest, FileSource, Source,
};

// Match docling-serve's 2 GB server-side message limits so realistic PDFs
// don't trip the default 4 MB client receive cap.
const GRPC_MAX_MESSAGE_BYTES: usize = 2 * 1024 * 1024 * 1024 - 1;

#[derive(Debug, Deserialize, Default)]
struct Snapshot {
    #[serde(default = "default_min")]
    min_pages: i64,
    #[serde(default = "default_min")]
    min_non_empty_text_items: i64,
    #[serde(default)]
    required_tokens: Vec<String>,
    #[serde(default)]
    ocr_required: bool,
}

fn default_min() -> i64 {
    1
}

#[tokio::main]
async fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        eprintln!("FAIL rust usage: docling-rust-example <fixture.pdf>");
        std::process::exit(2);
    }

    let fixture = match PathBuf::from(&args[1]).canonicalize() {
        Ok(p) => p,
        Err(e) => {
            println!("FAIL rust fixture={} error=cannot resolve path: {e}", &args[1]);
            std::process::exit(1);
        }
    };
    let fixture_name = fixture
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("?")
        .to_owned();

    let addr = env::var("DOCLING_GRPC_ADDR").unwrap_or_else(|_| "127.0.0.1:50051".into());
    let endpoint = format!("http://{addr}");

    match run(&endpoint, &fixture).await {
        Ok(()) => println!("PASS rust fixture={fixture_name}"),
        Err(e) => {
            println!("FAIL rust fixture={fixture_name} error={e:#}");
            std::process::exit(1);
        }
    }
}

async fn run(endpoint: &str, fixture: &Path) -> Result<()> {
    let bytes = fs::read(fixture)
        .await
        .with_context(|| format!("reading fixture {}", fixture.display()))?;
    let snapshot = expected_snapshot(fixture).await?;
    let filename = fixture
        .file_name()
        .ok_or_else(|| anyhow!("fixture has no filename"))?
        .to_string_lossy()
        .into_owned();

    let request = ConvertSourceRequest {
        request: Some(ConvertDocumentRequest {
            sources: vec![Source {
                source: Some(source::Source::File(FileSource {
                    base64_string: base64::engine::general_purpose::STANDARD.encode(&bytes),
                    filename,
                })),
            }],
            options: None,
            target: None,
        }),
    };

    let channel = Channel::from_shared(endpoint.to_string())?
        .connect()
        .await
        .context("connecting to gRPC server")?;

    let mut client = DoclingServeServiceClient::new(channel)
        .max_decoding_message_size(GRPC_MAX_MESSAGE_BYTES)
        .max_encoding_message_size(GRPC_MAX_MESSAGE_BYTES);

    let response = client.convert_source(request).await?;
    let doc = response
        .into_inner()
        .response
        .and_then(|r| r.document)
        .and_then(|d| d.doc)
        .ok_or_else(|| anyhow!("response did not include a doc"))?;

    assert_structural(&snapshot, &doc)
}

async fn expected_snapshot(fixture: &Path) -> Result<Snapshot> {
    let stem = fixture
        .file_stem()
        .ok_or_else(|| anyhow!("fixture has no stem"))?
        .to_string_lossy();
    let expected_path = fixture
        .parent()
        .and_then(|p| p.parent())
        .ok_or_else(|| anyhow!("fixture has no grandparent dir"))?
        .join("expected")
        .join(format!("{stem}.json"));
    let bytes = fs::read(&expected_path)
        .await
        .with_context(|| format!("reading {}", expected_path.display()))?;
    Ok(serde_json::from_slice(&bytes)?)
}

fn extract_texts(items: &[BaseTextItem]) -> Vec<String> {
    items
        .iter()
        .filter_map(|item| {
            let raw = match item.item.as_ref()? {
                base_text_item::Item::Title(v) => v.base.as_ref().map(|b| b.text.clone()),
                base_text_item::Item::SectionHeader(v) => v.base.as_ref().map(|b| b.text.clone()),
                base_text_item::Item::ListItem(v) => v.base.as_ref().map(|b| b.text.clone()),
                base_text_item::Item::Code(v) => Some(v.text.clone()),
                base_text_item::Item::Formula(v) => v.base.as_ref().map(|b| b.text.clone()),
                base_text_item::Item::Text(v) => v.base.as_ref().map(|b| b.text.clone()),
                base_text_item::Item::FieldHeading(v) => v.base.as_ref().map(|b| b.text.clone()),
                base_text_item::Item::FieldValue(v) => v.base.as_ref().map(|b| b.text.clone()),
            };
            let trimmed = raw?.trim().to_owned();
            if trimmed.is_empty() {
                None
            } else {
                Some(trimmed)
            }
        })
        .collect()
}

fn assert_structural(snapshot: &Snapshot, doc: &DoclingDocument) -> Result<()> {
    let pages = doc.pages.len() as i64;
    if pages < snapshot.min_pages {
        return Err(anyhow!(
            "pages={pages} below min_pages={}",
            snapshot.min_pages
        ));
    }

    let texts = extract_texts(&doc.texts);
    if (texts.len() as i64) < snapshot.min_non_empty_text_items {
        return Err(anyhow!(
            "text items={} below threshold={}",
            texts.len(),
            snapshot.min_non_empty_text_items
        ));
    }

    let merged = texts.join("\n").to_lowercase();
    for token in &snapshot.required_tokens {
        if !merged.contains(&token.to_lowercase()) {
            return Err(anyhow!("missing required token: {token}"));
        }
    }

    if snapshot.ocr_required && !texts.iter().any(|t| t.split_whitespace().count() >= 3) {
        return Err(anyhow!("ocr_required but no OCR-like text span found"));
    }

    Ok(())
}
