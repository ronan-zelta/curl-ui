package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/wailsapp/wails/v2/pkg/runtime"
)

func NewApp() *App {
	return &App{
		history: newHistoryOrLog(),
	}
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

func (a *App) SendRequest(req RequestPayload) (ResponsePayload, error) {
	if req.URL == "" {
		return ResponsePayload{}, fmt.Errorf("URL is required")
	}

	if !strings.HasPrefix(req.URL, "http://") && !strings.HasPrefix(req.URL, "https://") {
		req.URL = "http://" + req.URL
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

	bodyReader, contentType, err := buildBody(req)
	if err != nil {
		return ResponsePayload{}, err
	}

	httpReq, err := http.NewRequestWithContext(ctx, req.Method, req.URL, bodyReader)
	if err != nil {
		return ResponsePayload{}, fmt.Errorf("failed to create request: %w", err)
	}

	for key, value := range req.Headers {
		httpReq.Header.Set(key, value)
	}
	if _, ok := req.Headers["Content-Type"]; !ok && contentType != "" {
		httpReq.Header.Set("Content-Type", contentType)
	}

	client := &http.Client{}

	start := time.Now()
	resp, err := client.Do(httpReq)
	duration := time.Since(start)

	if err != nil {
		if errors.Is(ctx.Err(), context.Canceled) {
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

	result := ResponsePayload{
		StatusCode: resp.StatusCode,
		StatusText: resp.Status,
		Headers:    headers,
		Body:       bodyStr,
		DurationMs: duration.Milliseconds(),
	}

	if a.history != nil {
		if err = a.history.Save(req); err != nil {
			// Non-fatal — log but don't fail the request
			fmt.Printf("warning: failed to save history: %v\n", err)
		}
	}

	return result, nil
}

func (a *App) CancelRequest() {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.cancel != nil {
		a.cancel()
	}
}

func (a *App) SearchHistory(query string) ([]HistoryEntry, error) {
	if a.history == nil {
		return nil, nil
	}
	if query == "" {
		return a.history.GetRecent(100)
	}
	return a.history.Search(query)
}

func (a *App) PickFile() (string, error) {
	return runtime.OpenFileDialog(a.ctx, runtime.OpenDialogOptions{
		Title: "Select File",
	})
}
