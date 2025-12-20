package backend

import (
	"context"
	"log/slog"
	"os"
)

// Pattern identifiers for SPIFFE integration patterns (FR-019)
const (
	PatternEnvoySDS     = "envoy-sds"
	PatternSpiffeHelper = "spiffe-helper"
)

// Event types for structured logging
const (
	EventConnectionAttempt = "connection_attempt"
	EventConnectionSuccess = "connection_success"
	EventConnectionFailure = "connection_failure"
	EventCertRotation      = "cert_rotation"
)

// Logger wraps slog with structured fields for pattern-aware logging
type Logger struct {
	logger    *slog.Logger
	component string
}

// NewLogger creates a new structured logger for the backend component
func NewLogger(component string) *Logger {
	// Determine log format from environment (default: JSON for FR-19)
	logFormat := os.Getenv("LOG_FORMAT")
	if logFormat == "" {
		logFormat = "json"
	}

	var handler slog.Handler
	if logFormat == "json" {
		handler = slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
			Level: slog.LevelInfo,
		})
	} else {
		handler = slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
			Level: slog.LevelInfo,
		})
	}

	return &Logger{
		logger:    slog.New(handler),
		component: component,
	}
}

// LogEvent logs a structured event with pattern identifier and SPIFFE context
func (l *Logger) LogEvent(ctx context.Context, pattern, event, spiffeID, peerSPIFFEID, message string) {
	l.logger.InfoContext(ctx,
		message,
		"component", l.component,
		"pattern", pattern,
		"event", event,
		"spiffe_id", spiffeID,
		"peer_spiffe_id", peerSPIFFEID,
	)
}

// LogConnectionAttempt logs a connection attempt event
func (l *Logger) LogConnectionAttempt(ctx context.Context, pattern, target, spiffeID string) {
	l.logger.InfoContext(ctx,
		"Attempting connection",
		"component", l.component,
		"pattern", pattern,
		"event", EventConnectionAttempt,
		"target", target,
		"spiffe_id", spiffeID,
	)
}

// LogConnectionSuccess logs a successful connection event
func (l *Logger) LogConnectionSuccess(ctx context.Context, pattern, target, spiffeID, peerSPIFFEID string) {
	l.logger.InfoContext(ctx,
		"Connection successful",
		"component", l.component,
		"pattern", pattern,
		"event", EventConnectionSuccess,
		"target", target,
		"spiffe_id", spiffeID,
		"peer_spiffe_id", peerSPIFFEID,
	)
}

// LogConnectionFailure logs a failed connection event
func (l *Logger) LogConnectionFailure(ctx context.Context, pattern, target, spiffeID string, err error) {
	l.logger.ErrorContext(ctx,
		"Connection failed",
		"component", l.component,
		"pattern", pattern,
		"event", EventConnectionFailure,
		"target", target,
		"spiffe_id", spiffeID,
		"error", err.Error(),
	)
}

// Info logs an informational message
func (l *Logger) Info(message string, args ...any) {
	l.logger.Info(message, append([]any{"component", l.component}, args...)...)
}

// Error logs an error message
func (l *Logger) Error(message string, args ...any) {
	l.logger.Error(message, append([]any{"component", l.component}, args...)...)
}
