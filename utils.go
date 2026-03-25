package main

import "strings"

func isBinaryContent(contentType string) bool {
	if contentType == "" {
		return false
	}
	ct := strings.TrimSpace(strings.ToLower(contentType))
	// Strip parameters (e.g. "; charset=utf-8")
	if idx := strings.Index(ct, ";"); idx != -1 {
		ct = strings.TrimSpace(ct[:idx])
	}
	if strings.HasPrefix(ct, "text/") {
		return false
	}
	if ct == "application/json" {
		return false
	}
	if ct == "application/xml" {
		return false
	}
	if ct == "application/javascript" {
		return false
	}
	if ct == "application/x-www-form-urlencoded" {
		return false
	}
	if strings.Contains(ct, "application/") {
		return true
	}
	if strings.HasPrefix(ct, "image/") {
		return true
	}
	if strings.HasPrefix(ct, "audio/") {
		return true
	}
	if strings.HasPrefix(ct, "video/") {
		return true
	}
	return false
}
