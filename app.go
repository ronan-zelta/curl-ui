package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"
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

type RequestPayload struct {
	Method   string            `json:"method"`
	URL      string            `json:"url"`
	Headers  map[string]string `json:"headers"`
	Body     string            `json:"body"`
	BodyType string            `json:"bodyType"`
}

type ResponsePayload struct {
	StatusCode int               `json:"statusCode"`
	StatusText string            `json:"statusText"`
	Headers    map[string]string `json:"headers"`
	Body       string            `json:"body"`
	DurationMs int64             `json:"durationMs"`
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
	if req.BodyType != "none" && req.Body != "" {
		bodyReader = strings.NewReader(req.Body)
	}

	httpReq, err := http.NewRequestWithContext(ctx, req.Method, req.URL, bodyReader)
	if err != nil {
		return ResponsePayload{}, fmt.Errorf("failed to create request: %w", err)
	}

	for key, value := range req.Headers {
		httpReq.Header.Set(key, value)
	}

	if req.BodyType == "json" && httpReq.Header.Get("Content-Type") == "" {
		httpReq.Header.Set("Content-Type", "application/json")
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

	body, err := io.ReadAll(io.LimitReader(resp.Body, 10*1024*1024)) // 10MB limit
	if err != nil {
		return ResponsePayload{}, fmt.Errorf("failed to read response body: %w", err)
	}

	headers := make(map[string]string)
	for key := range resp.Header {
		headers[key] = resp.Header.Get(key)
	}

	contentType := resp.Header.Get("Content-Type")
	bodyStr := ""
	if isBinaryContent(contentType) {
		bodyStr = fmt.Sprintf("[Binary response: %s, %d bytes]", contentType, len(body))
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
