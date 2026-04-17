use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let proto_root = manifest_dir
        .parent()
        .and_then(|p| p.parent())
        .expect("examples/rust/.. must resolve to repository root")
        .join("proto");

    let protos = [
        "ai/docling/core/v1/docling_document.proto",
        "ai/docling/serve/v1/docling_serve_types.proto",
        "ai/docling/serve/v1/docling_serve.proto",
    ];

    for rel in &protos {
        println!("cargo:rerun-if-changed={}", proto_root.join(rel).display());
    }

    let proto_paths: Vec<PathBuf> = protos.iter().map(|p| proto_root.join(p)).collect();

    tonic_build::configure()
        .build_server(false)
        .compile_protos(&proto_paths, &[proto_root])?;

    Ok(())
}
