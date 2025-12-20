package frontend

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

// Handler holds dependencies for HTTP handlers
type Handler struct {
	logger      *Logger
	backendURL  string
	spiffeID    string
	staticPath  string
}

// NewHandler creates a new handler with dependencies
func NewHandler(logger *Logger) *Handler {
	backendURL := os.Getenv("BACKEND_URL")
	if backendURL == "" {
		backendURL = "http://127.0.0.1:8001" // Default: local Envoy proxy
	}

	spiffeID := os.Getenv("SPIFFE_ID")
	if spiffeID == "" {
		spiffeID = "spiffe://example.org/ns/demo/sa/frontend"
	}

	staticPath := os.Getenv("STATIC_PATH")
	if staticPath == "" {
		staticPath = "/app/static"
	}

	return &Handler{
		logger:     logger,
		backendURL: backendURL,
		spiffeID:   spiffeID,
		staticPath: staticPath,
	}
}

// HealthHandler handles health check requests
func (h *Handler) HealthHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		health := HealthResponse{
			Component: "frontend",
			Status:    "healthy",
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(health)
	}
}

// DemoHandler handles the demo flow - calls backend via Envoy
func (h *Handler) DemoHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		// Log connection attempt to backend via Envoy (Pattern 1)
		backendTarget := h.backendURL + "/api/demo"
		h.logger.LogConnectionAttempt(ctx, PatternEnvoySDS, backendTarget, h.spiffeID)

		// Create HTTP client with timeout
		client := &http.Client{
			Timeout: 10 * time.Second,
		}

		// Call backend via Envoy proxy
		req, err := http.NewRequestWithContext(ctx, "GET", backendTarget, nil)
		if err != nil {
			h.logger.LogConnectionFailure(ctx, PatternEnvoySDS, backendTarget, h.spiffeID, err)
			http.Error(w, fmt.Sprintf("Failed to create request: %v", err), http.StatusInternalServerError)
			return
		}

		// Add correlation ID for request tracing
		correlationID := fmt.Sprintf("demo-%d", time.Now().UnixNano())
		req.Header.Set("X-Correlation-ID", correlationID)
		req.Header.Set("User-Agent", "frontend-demo-client")

		// Execute request
		resp, err := client.Do(req)
		if err != nil {
			h.logger.LogConnectionFailure(ctx, PatternEnvoySDS, backendTarget, h.spiffeID, err)
			http.Error(w, fmt.Sprintf("Backend connection failed: %v", err), http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()

		// Read response body
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			h.logger.Error("Failed to read backend response", "error", err.Error())
			http.Error(w, "Failed to read backend response", http.StatusInternalServerError)
			return
		}

		// Check if backend returned success
		if resp.StatusCode != http.StatusOK {
			h.logger.Error("Backend returned error",
				"status_code", resp.StatusCode,
				"pattern", PatternEnvoySDS,
				"correlation_id", correlationID,
			)
			http.Error(w, fmt.Sprintf("Backend error: %s", string(body)), resp.StatusCode)
			return
		}

		// Parse backend response
		var demoResult DemoResult
		if err := json.Unmarshal(body, &demoResult); err != nil {
			h.logger.Error("Failed to parse backend response", "error", err.Error())
			http.Error(w, "Failed to parse backend response", http.StatusInternalServerError)
			return
		}

		// Log successful connection to backend via Envoy
		// The peer SPIFFE ID would be the backend's ID (verified by Envoy)
		peerSPIFFEID := "spiffe://example.org/ns/demo/sa/backend"
		h.logger.LogConnectionSuccess(ctx, PatternEnvoySDS, backendTarget, h.spiffeID, peerSPIFFEID)
		h.logger.Info("Demo flow completed successfully",
			"pattern", PatternEnvoySDS,
			"correlation_id", correlationID,
			"orders_count", len(demoResult.Orders),
		)

		// Return the full demo result to the UI
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(demoResult)
	}
}

// IndexHandler serves the main UI page
func (h *Handler) IndexHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		http.ServeFile(w, r, h.staticPath+"/index.html")
	}
}

// StaticHandler serves static assets (CSS, JS)
func (h *Handler) StaticHandler() http.HandlerFunc {
	fs := http.FileServer(http.Dir(h.staticPath))
	return func(w http.ResponseWriter, r *http.Request) {
		// Strip /static/ prefix before serving
		http.StripPrefix("/static/", fs).ServeHTTP(w, r)
	}
}

// LoggingMiddleware wraps handlers with request/response logging
func (h *Handler) LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Create a custom ResponseWriter to capture status code
		lrw := &loggingResponseWriter{
			ResponseWriter: w,
			statusCode:     http.StatusOK,
		}

		// Process request
		next.ServeHTTP(lrw, r)

		// Log request details
		duration := time.Since(start)
		h.logger.LogHTTPRequest(
			r.Context(),
			r.Method,
			r.URL.Path,
			lrw.statusCode,
			duration.String(),
		)
	})
}

// loggingResponseWriter wraps http.ResponseWriter to capture status code
type loggingResponseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (lrw *loggingResponseWriter) WriteHeader(code int) {
	lrw.statusCode = code
	lrw.ResponseWriter.WriteHeader(code)
}
