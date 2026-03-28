package main

import (
	"bytes"
	"fmt"
	"io"
	"mime/multipart"
	"net/url"
	"os"
	"strings"
)

func buildBody(req RequestPayload) (io.Reader, string, error) {
	switch req.BodyType {
	case BodyTypeJSON:
		if req.Body != "" {
			return strings.NewReader(req.Body), "application/json", nil
		}
	case BodyTypeRaw:
		if req.Body != "" {
			return strings.NewReader(req.Body), "", nil
		}
	case BodyTypeFormData:
		var buf bytes.Buffer
		writer := multipart.NewWriter(&buf)
		for _, kv := range req.FormData {
			if !kv.Enabled || kv.Key == "" {
				continue
			}
			if err := writer.WriteField(kv.Key, kv.Value); err != nil {
				return nil, "", fmt.Errorf("failed to write form field: %w", err)
			}
		}
		if err := writer.Close(); err != nil {
			return nil, "", fmt.Errorf("failed to close multipart writer: %w", err)
		}
		return &buf, writer.FormDataContentType(), nil
	case BodyTypeURLEncoded:
		values := url.Values{}
		for _, kv := range req.URLEncoded {
			if !kv.Enabled || kv.Key == "" {
				continue
			}
			values.Add(kv.Key, kv.Value)
		}
		if encoded := values.Encode(); encoded != "" {
			return strings.NewReader(encoded), "application/x-www-form-urlencoded", nil
		}
	case BodyTypeBinary:
		if req.BinaryPath != "" {
			data, err := os.ReadFile(req.BinaryPath)
			if err != nil {
				return nil, "", fmt.Errorf("failed to read file: %w", err)
			}
			return bytes.NewReader(data), "application/octet-stream", nil
		}
	}
	return nil, "", nil
}

func isBinaryContent(contentType string) bool {
	if contentType == "" {
		return false
	}
	ct := strings.TrimSpace(strings.ToLower(contentType))
	if idx := strings.IndexByte(ct, ';'); idx != -1 {
		ct = strings.TrimSpace(ct[:idx])
	}
	switch {
	case strings.HasPrefix(ct, "text/"):
		return false
	case ct == "application/json",
		ct == "application/xml",
		ct == "application/javascript",
		ct == "application/x-www-form-urlencoded":
		return false
	case strings.HasPrefix(ct, "application/"),
		strings.HasPrefix(ct, "image/"),
		strings.HasPrefix(ct, "audio/"),
		strings.HasPrefix(ct, "video/"):
		return true
	}
	return false
}
