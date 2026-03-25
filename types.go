package main

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

type ResponsePayload struct {
	StatusCode int               `json:"statusCode"`
	StatusText string            `json:"statusText"`
	Headers    map[string]string `json:"headers"`
	Body       string            `json:"body"`
	DurationMs int64             `json:"durationMs"`
}
