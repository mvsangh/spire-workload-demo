package frontend

import "time"

// Order represents a demo order entity (mirrors backend structure)
type Order struct {
	ID          int       `json:"id"`
	Description string    `json:"description"`
	Status      string    `json:"status"`
	CreatedAt   time.Time `json:"created_at"`
}

// ConnectionStatus represents the status of a connection attempt
type ConnectionStatus struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Pattern string `json:"pattern"` // "envoy-sds" or "spiffe-helper"
}

// DemoResult represents the result of the full demo flow
// This mirrors the backend DemoResult structure
type DemoResult struct {
	FrontendToBackend ConnectionStatus `json:"frontend_to_backend"`
	BackendToDatabase ConnectionStatus `json:"backend_to_database"`
	Orders            []Order          `json:"orders,omitempty"`
	Timestamp         time.Time        `json:"timestamp"`
}

// HealthResponse represents the health check response
type HealthResponse struct {
	Component string `json:"component"`
	Status    string `json:"status"`
}
