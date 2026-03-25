package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/wailsapp/wails/v2/pkg/runtime"
)

type App struct {
	ctx    context.Context
	mu     sync.Mutex
	cancel context.CancelFunc
}

func NewApp() *App {
	return &App{}
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

type KeyValue struct {
	Key     string `json:"key"`
	Value   string `json:"value"`
	Enabled bool   `json:"enabled"`
}

type RequestPayload struct {
	Method      string            `json:"method"`
	URL         string            `json:"url"`
	Headers     map[string]string `json:"headers"`
	Body        string            `json:"body"`
	BodyType    string            `json:"bodyType"`
	FormData    []KeyValue        `json:"formData"`
	URLEncoded  []KeyValue        `json:"urlEncoded"`
	BinaryPath  string            `json:"binaryPath"`
}

type ResponsePayload struct {
	StatusCode int               `json:"statusCode"`
	StatusText string            `json:"statusText"`
	Headers    map[string]string `json:"headers"`
	Body       string            `json:"body"`
	DurationMs int64             `json:"durationMs"`
}

func (a *App) PickFile() (string, error) {
	path, err := runtime.OpenFileDialog(a.ctx, runtime.OpenDialogOptions{
		Title: "Select File",
	})
	if err != nil {
		return "", err
	}
	return path, nil
}

func (a *App) SendRequest(req RequestPayload) (ResponsePayload, error) {
	if req.URL == "" {
		return ResponsePayload{}, fmt.Errorf("URL is required")
	}

	if !strings.HasPrefix(req.URL, "http://") && !strings.HasPrefix(req.URL, "https://") {
		req.URL = "https://" + req.URL
	}

	ctx, cancel := context.WithCancel(a.ctx)
	a.mu.Lock()
	a.cancel = cancel
	a.mu.Unlock()

	defer func() {
		a.mu.Lock()
		a.cancel = nil
		a.mu.Unlock()
	}()

	var bodyReader io.Reader
	var contentType string

	switch req.BodyType {
	case "json":
		if req.Body != "" {
			bodyReader = strings.NewReader(req.Body)
			if _, ok := req.Headers["Content-Type"]; !ok {
				contentType = "application/json"
			}
		}
	case "raw":
		if req.Body != "" {
			bodyReader = strings.NewReader(req.Body)
		}
	case "form-data":
		var buf bytes.Buffer
		writer := multipart.NewWriter(&buf)
		for _, kv := range req.FormData {
			if !kv.Enabled || kv.Key == "" {
				continue
			}
			if err := writer.WriteField(kv.Key, kv.Value); err != nil {
				return ResponsePayload{}, fmt.Errorf("failed to write form field: %w", err)
			}
		}
		if err := writer.Close(); err != nil {
			return ResponsePayload{}, fmt.Errorf("failed to close multipart writer: %w", err)
		}
		bodyReader = &buf
		if _, ok := req.Headers["Content-Type"]; !ok {
			contentType = writer.FormDataContentType()
		}
	case "urlencoded":
		values := url.Values{}
		for _, kv := range req.URLEncoded {
			if !kv.Enabled || kv.Key == "" {
				continue
			}
			values.Add(kv.Key, kv.Value)
		}
		encoded := values.Encode()
		if encoded != "" {
			bodyReader = strings.NewReader(encoded)
			if _, ok := req.Headers["Content-Type"]; !ok {
				contentType = "application/x-www-form-urlencoded"
			}
		}
	case "binary":
		if req.BinaryPath != "" {
			file, err := os.Open(req.BinaryPath)
			if err != nil {
				return ResponsePayload{}, fmt.Errorf("failed to open file: %w", err)
			}
			defer file.Close()
			data, err := io.ReadAll(file)
			if err != nil {
				return ResponsePayload{}, fmt.Errorf("failed to read file: %w", err)
			}
			bodyReader = bytes.NewReader(data)
			if _, ok := req.Headers["Content-Type"]; !ok {
				contentType = "application/octet-stream"
			}
		}
	}

	httpReq, err := http.NewRequestWithContext(ctx, req.Method, req.URL, bodyReader)
	if err != nil {
		return ResponsePayload{}, fmt.Errorf("failed to create request: %w", err)
	}

	for key, value := range req.Headers {
		httpReq.Header.Set(key, value)
	}

	if contentType != "" {
		httpReq.Header.Set("Content-Type", contentType)
	}

	client := &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: false},
		},
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 10 {
				return fmt.Errorf("too many redirects")
			}
			return nil
		},
	}

	start := time.Now()
	resp, err := client.Do(httpReq)
	duration := time.Since(start)

	if err != nil {
		if ctx.Err() == context.Canceled {
			return ResponsePayload{}, fmt.Errorf("request cancelled")
		}
		return ResponsePayload{}, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 10*1024*1024))
	if err != nil {
		return ResponsePayload{}, fmt.Errorf("failed to read response body: %w", err)
	}

	headers := make(map[string]string)
	for key := range resp.Header {
		headers[key] = resp.Header.Get(key)
	}

	respContentType := resp.Header.Get("Content-Type")
	bodyStr := ""
	if isBinaryContent(respContentType) {
		bodyStr = fmt.Sprintf("[Binary response: %s, %d bytes]", respContentType, len(body))
	} else {
		bodyStr = string(body)
	}

	return ResponsePayload{
		StatusCode: resp.StatusCode,
		StatusText: resp.Status,
		Headers:    headers,
		Body:       bodyStr,
		DurationMs: duration.Milliseconds(),
	}, nil
}

func (a *App) CancelRequest() {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.cancel != nil {
		a.cancel()
	}
}

func isBinaryContent(contentType string) bool {
	if contentType == "" {
		return false
	}
	ct := strings.ToLower(contentType)
	if strings.HasPrefix(ct, "text/") {
		return false
	}
	if strings.Contains(ct, "application/json") {
		return false
	}
	if strings.Contains(ct, "application/xml") {
		return false
	}
	if strings.Contains(ct, "application/javascript") {
		return false
	}
	if strings.Contains(ct, "application/x-www-form-urlencoded") {
		return false
	}
	if strings.Contains(ct, "application/") {
		return true
	}
	if strings.HasPrefix(ct, "image/") || strings.HasPrefix(ct, "audio/") || strings.HasPrefix(ct, "video/") {
		return true
	}
	return false
}
