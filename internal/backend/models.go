package backend

import "time"

// Order represents a demo order entity in the database
type Order struct {
	ID          int       `json:"id" db:"id"`
	Description string    `json:"description" db:"description"`
	Status      string    `json:"status" db:"status"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// Order status constants
const (
	StatusPending    = "pending"
	StatusProcessing = "processing"
	StatusCompleted  = "completed"
	StatusFailed     = "failed"
)

// ConnectionStatus represents the status of a connection attempt
type ConnectionStatus struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Pattern string `json:"pattern"` // "envoy-sds" or "spiffe-helper"
}

// DemoResult represents the result of the full demo flow
type DemoResult struct {
	FrontendToBackend ConnectionStatus `json:"frontend_to_backend"`
	BackendToDatabase ConnectionStatus `json:"backend_to_database"`
	Orders            []Order          `json:"orders,omitempty"`
	Timestamp         time.Time        `json:"timestamp"`
}
