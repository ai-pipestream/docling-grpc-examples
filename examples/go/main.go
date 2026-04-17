package main

//go:generate ./generate.sh

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	corev1 "github.com/ai-pipestream/docling-grpc-examples/examples/go/gen/ai/docling/core/v1"
	servev1 "github.com/ai-pipestream/docling-grpc-examples/examples/go/gen/ai/docling/serve/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// Match docling-serve's 2 GB server-side message limits so realistic PDFs
// don't trip the default 4 MB client receive cap.
const grpcMaxMessageBytes = 2*1024*1024*1024 - 1

type snapshot struct {
	MinPages             int      `json:"min_pages"`
	MinNonEmptyTextItems int      `json:"min_non_empty_text_items"`
	RequiredTokens       []string `json:"required_tokens"`
	OCRRequired          bool     `json:"ocr_required"`
}

func main() {
	if len(os.Args) != 2 {
		fmt.Println("FAIL go usage: main <fixture.pdf>")
		os.Exit(2)
	}
	fixture, _ := filepath.Abs(os.Args[1])
	addr := os.Getenv("DOCLING_GRPC_ADDR")
	if addr == "" {
		addr = "localhost:50051"
	}

	if err := run(addr, fixture); err != nil {
		fmt.Printf("FAIL go fixture=%s error=%v\n", filepath.Base(fixture), err)
		os.Exit(1)
	}
	fmt.Printf("PASS go fixture=%s\n", filepath.Base(fixture))
}

func run(addr, fixture string) error {
	content, err := os.ReadFile(fixture)
	if err != nil {
		return err
	}
	expectedPath := filepath.Join(filepath.Dir(filepath.Dir(fixture)), "expected", strings.TrimSuffix(filepath.Base(fixture), ".pdf")+".json")
	expectedBytes, err := os.ReadFile(expectedPath)
	if err != nil {
		return err
	}
	var expected snapshot
	if err = json.Unmarshal(expectedBytes, &expected); err != nil {
		return err
	}

	conn, err := grpc.NewClient(addr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithDefaultCallOptions(
			grpc.MaxCallRecvMsgSize(grpcMaxMessageBytes),
			grpc.MaxCallSendMsgSize(grpcMaxMessageBytes),
		),
	)
	if err != nil {
		return err
	}
	defer conn.Close()

	client := servev1.NewDoclingServeServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	resp, err := client.ConvertSource(ctx, &servev1.ConvertSourceRequest{Request: &servev1.ConvertDocumentRequest{Sources: []*servev1.Source{{Source: &servev1.Source_File{File: &servev1.FileSource{Filename: filepath.Base(fixture), Base64String: base64.StdEncoding.EncodeToString(content)}}}}}})
	if err != nil {
		return err
	}

	return assertStructural(expected, resp.GetResponse().GetDocument().GetDoc())
}

func assertStructural(expected snapshot, doc *corev1.DoclingDocument) error {
	if len(doc.GetPages()) < max(expected.MinPages, 1) {
		return fmt.Errorf("pages below threshold")
	}
	texts := extractTexts(doc.GetTexts())
	if len(texts) < max(expected.MinNonEmptyTextItems, 1) {
		return fmt.Errorf("text items below threshold")
	}
	merged := strings.ToLower(strings.Join(texts, "\n"))
	for _, token := range expected.RequiredTokens {
		t := strings.ToLower(strings.TrimSpace(token))
		if t != "" && !strings.Contains(merged, t) {
			return fmt.Errorf("missing token %s", t)
		}
	}
	if expected.OCRRequired {
		found := false
		for _, t := range texts {
			if len(strings.Fields(t)) >= 3 {
				found = true
				break
			}
		}
		if !found {
			return fmt.Errorf("ocr-required text missing")
		}
	}
	return nil
}

func extractTexts(items []*corev1.BaseTextItem) []string {
	out := make([]string, 0, len(items))
	for _, item := range items {
		text := ""
		switch v := item.GetItem().(type) {
		case *corev1.BaseTextItem_Title:
			text = v.Title.GetBase().GetText()
		case *corev1.BaseTextItem_SectionHeader:
			text = v.SectionHeader.GetBase().GetText()
		case *corev1.BaseTextItem_ListItem:
			text = v.ListItem.GetBase().GetText()
		case *corev1.BaseTextItem_Formula:
			text = v.Formula.GetBase().GetText()
		case *corev1.BaseTextItem_Text:
			text = v.Text.GetBase().GetText()
		case *corev1.BaseTextItem_FieldHeading:
			text = v.FieldHeading.GetBase().GetText()
		case *corev1.BaseTextItem_FieldValue:
			text = v.FieldValue.GetBase().GetText()
		case *corev1.BaseTextItem_Code:
			text = v.Code.GetText()
		}
		text = strings.TrimSpace(text)
		if text != "" {
			out = append(out, text)
		}
	}
	return out
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
