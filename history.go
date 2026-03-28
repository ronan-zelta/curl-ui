package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"github.com/google/uuid"
	_ "github.com/mattn/go-sqlite3"
)

const maxBodyBytes = 20 * 1024 // 20KB

type History struct {
	db *sql.DB
}

func NewHistory() (*History, error) {
	dir, err := historyDir()
	if err != nil {
		return nil, fmt.Errorf("could not resolve history dir: %w", err)
	}

	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("could not create history dir: %w", err)
	}

	db, err := sql.Open("sqlite3", filepath.Join(dir, "history.db"))
	if err != nil {
		return nil, fmt.Errorf("could not open history db: %w", err)
	}

	if err := migrate(db); err != nil {
		return nil, fmt.Errorf("could not migrate history db: %w", err)
	}

	return &History{db: db}, nil
}

func (h *History) Close() {
	if h.db != nil {
		h.db.Close()
	}
}

func (h *History) Save(req RequestPayload) error {
	headers, err := json.Marshal(req.Headers)
	if err != nil {
		return err
	}

	params, err := json.Marshal(req.FormData)
	if err != nil {
		return err
	}

	body := ""
	if req.BodyType != BodyTypeBinary {
		if len(req.Body) <= maxBodyBytes {
			body = req.Body
		}
	}

	_, err = h.db.Exec(
		`INSERT INTO history (id, timestamp, method, url, headers, body, body_type, params)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		uuid.New().String(),
		time.Now().UnixMilli(),
		req.Method,
		req.URL,
		string(headers),
		body,
		string(req.BodyType),
		string(params),
	)
	return err
}

func (h *History) Search(query string) ([]HistoryEntry, error) {
	q := "%" + query + "%"
	rows, err := h.db.Query(
		`SELECT id, timestamp, method, url, headers, body, body_type, params
		 FROM history
		 WHERE url LIKE ? OR method LIKE ? OR body LIKE ? OR headers LIKE ?
		 ORDER BY timestamp DESC
		 LIMIT 100`,
		q, q, q, q,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var entries []HistoryEntry
	for rows.Next() {
		var e HistoryEntry
		if err := rows.Scan(&e.ID, &e.Timestamp, &e.Method, &e.URL, &e.Headers, &e.Body, &e.BodyType, &e.Params); err != nil {
			return nil, err
		}
		entries = append(entries, e)
	}
	return entries, rows.Err()
}

func (h *History) GetRecent(limit int) ([]HistoryEntry, error) {
	rows, err := h.db.Query(
		`SELECT id, timestamp, method, url, headers, body, body_type, params
		 FROM history
		 ORDER BY timestamp DESC
		 LIMIT ?`,
		limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var entries []HistoryEntry
	for rows.Next() {
		var e HistoryEntry
		if err := rows.Scan(&e.ID, &e.Timestamp, &e.Method, &e.URL, &e.Headers, &e.Body, &e.BodyType, &e.Params); err != nil {
			return nil, err
		}
		entries = append(entries, e)
	}
	return entries, rows.Err()
}

func migrate(db *sql.DB) error {
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS history (
			id        TEXT PRIMARY KEY,
			timestamp INTEGER NOT NULL,
			method    TEXT NOT NULL,
			url       TEXT NOT NULL,
			headers   TEXT,
			body      TEXT,
			body_type TEXT NOT NULL,
			params    TEXT
		);
		CREATE INDEX IF NOT EXISTS idx_history_timestamp ON history(timestamp DESC);
		CREATE INDEX IF NOT EXISTS idx_history_method    ON history(method);
		CREATE INDEX IF NOT EXISTS idx_history_url       ON history(url);
	`)
	return err
}

func historyDir() (string, error) {
	switch runtime.GOOS {
	case "darwin":
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		return filepath.Join(home, "Library", "Application Support", "httpclient"), nil
	case "linux":
		if xdg := os.Getenv("XDG_DATA_HOME"); xdg != "" {
			return filepath.Join(xdg, "httpclient"), nil
		}
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		return filepath.Join(home, ".local", "share", "httpclient"), nil
	case "windows":
		appData := os.Getenv("APPDATA")
		if appData == "" {
			return "", fmt.Errorf("APPDATA not set")
		}
		return filepath.Join(appData, "httpclient"), nil
	default:
		return "", fmt.Errorf("unsupported OS: %s", runtime.GOOS)
	}
}

func newHistoryOrLog() *History {
	h, err := NewHistory()
	if err != nil {
		log.Printf("warning: could not initialise history: %v", err)
		return nil
	}
	return h
}
