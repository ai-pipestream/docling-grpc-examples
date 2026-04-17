package org.example.docling.quarkus;

import ai.docling.core.v1.BaseTextItem;
import ai.docling.core.v1.DoclingDocument;
import ai.docling.serve.v1.ConvertDocumentRequest;
import ai.docling.serve.v1.ConvertSourceRequest;
import ai.docling.serve.v1.ConvertSourceResponse;
import ai.docling.serve.v1.DoclingServeServiceGrpc;
import ai.docling.serve.v1.FileSource;
import ai.docling.serve.v1.Source;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;

public final class Main {
  private static final ObjectMapper MAPPER = new ObjectMapper();

  private Main() {}

  public static void main(String[] args) throws Exception {
    if (args.length != 1) {
      System.out.println("FAIL java-quarkus usage: Main <fixture.pdf>");
      System.exit(2);
    }

    Path fixture = Path.of(args[0]).toAbsolutePath();
    String addr = System.getenv().getOrDefault("DOCLING_GRPC_ADDR", "localhost:50051");

    String base64 = Base64.getEncoder().encodeToString(Files.readAllBytes(fixture));
    Source source = Source.newBuilder()
        .setFile(FileSource.newBuilder().setFilename(fixture.getFileName().toString()).setBase64String(base64).build())
        .build();

    ConvertSourceRequest request = ConvertSourceRequest.newBuilder()
        .setRequest(ConvertDocumentRequest.newBuilder().addSources(source).build())
        .build();

    ManagedChannel channel = ManagedChannelBuilder.forTarget(addr).usePlaintext().build();
    try {
      ConvertSourceResponse response = DoclingServeServiceGrpc.newBlockingStub(channel).convertSource(request);
      JsonNode expected = loadExpected(fixture);
      assertStructural(expected, response.getResponse().getDocument().getDoc());
      System.out.println("PASS java-quarkus fixture=" + fixture.getFileName());
    } catch (Exception ex) {
      System.out.println("FAIL java-quarkus fixture=" + fixture.getFileName() + " error=" + ex.getMessage());
      System.exit(1);
    } finally {
      channel.shutdownNow();
    }
  }

  private static JsonNode loadExpected(Path fixture) throws Exception {
    Path expected = fixture.getParent().getParent().resolve("expected").resolve(fixture.getFileName().toString().replace(".pdf", ".json"));
    return MAPPER.readTree(expected.toFile());
  }

  private static void assertStructural(JsonNode expected, DoclingDocument doc) {
    int minPages = expected.path("min_pages").asInt(1);
    int minTexts = expected.path("min_non_empty_text_items").asInt(1);
    if (doc.getPagesCount() < minPages) {
      throw new IllegalStateException("pages below threshold");
    }

    List<String> texts = extractTexts(doc.getTextsList());
    if (texts.size() < minTexts) {
      throw new IllegalStateException("text item count below threshold");
    }

    String merged = String.join("\n", texts).toLowerCase();
    for (JsonNode token : expected.path("required_tokens")) {
      String value = token.asText().toLowerCase();
      if (!value.isBlank() && !merged.contains(value)) {
        throw new IllegalStateException("missing token " + value);
      }
    }

    if (expected.path("ocr_required").asBoolean(false)) {
      boolean found = texts.stream().anyMatch(t -> t.trim().split("\\s+").length >= 3);
      if (!found) {
        throw new IllegalStateException("ocr-required text missing");
      }
    }
  }

  private static List<String> extractTexts(List<BaseTextItem> items) {
    List<String> out = new ArrayList<>();
    for (BaseTextItem item : items) {
      String text = switch (item.getItemCase()) {
        case TITLE -> item.getTitle().getBase().getText();
        case SECTION_HEADER -> item.getSectionHeader().getBase().getText();
        case LIST_ITEM -> item.getListItem().getBase().getText();
        case FORMULA -> item.getFormula().getBase().getText();
        case TEXT -> item.getText().getBase().getText();
        case FIELD_HEADING -> item.getFieldHeading().getBase().getText();
        case FIELD_VALUE -> item.getFieldValue().getBase().getText();
        case CODE -> item.getCode().getText();
        default -> "";
      };
      if (!text.isBlank()) {
        out.add(text.trim());
      }
    }
    return out;
  }
}
