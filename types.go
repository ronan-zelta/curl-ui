package main

import (
	"context"
	"sync"
)

type App struct {
	ctx     context.Context
	mu      sync.Mutex
	cancel  context.CancelFunc
	history *History
}

type BodyType string

const (
	BodyTypeNone       BodyType = "none"
	BodyTypeJSON       BodyType = "json"
	BodyTypeRaw        BodyType = "raw"
	BodyTypeFormData   BodyType = "form-data"
	BodyTypeURLEncoded BodyType = "urlencoded"
	BodyTypeBinary     BodyType = "binary"
)

type KeyValue struct {
	Key     string `json:"key"`
	Value   string `json:"value"`
	Enabled bool   `json:"enabled"`
}

type RequestPayload struct {
	Method     string            `json:"method"`
	URL        string            `json:"url"`
	Headers    map[string]string `json:"headers"`
	Body       string            `json:"body"`
	BodyType   BodyType          `json:"bodyType"`
	FormData   []KeyValue        `json:"formData"`
	URLEncoded []KeyValue        `json:"urlEncoded"`
	BinaryPath string            `json:"binaryPath"`
}

type HistoryEntry struct {
	ID        string `json:"id"`
	Timestamp int64  `json:"timestamp"`
	Method    string `json:"method"`
	URL       string `json:"url"`
	Headers   string `json:"headers"`
	Body      string `json:"body"`
	BodyType  string `json:"bodyType"`
	Params    string `json:"params"`
}

type ResponsePayload struct {
	StatusCode int               `json:"statusCode"`
	StatusText string            `json:"statusText"`
	Headers    map[string]string `json:"headers"`
	Body       string            `json:"body"`
	DurationMs int64             `json:"durationMs"`
}
