package backend

import (
	"encoding/json"
	"net/http"
	"time"
)

// Handler provides HTTP handlers for the backend API
type Handler struct {
	db     *DB
	logger *Logger
}

// NewHandler creates a new HTTP handler
func NewHandler(db *DB, logger *Logger) *Handler {
	return &Handler{
		db:     db,
		logger: logger,
	}
}

// HealthHandler handles GET /health requests
func (h *Handler) HealthHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Check database health
	if err := h.db.HealthCheck(ctx); err != nil {
		h.logger.Error("Health check failed", "error", err)
		http.Error(w, "Database unhealthy", http.StatusServiceUnavailable)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
		"component": "backend",
	})
}

// OrdersHandler handles GET /api/orders requests
func (h *Handler) OrdersHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Retrieve orders from database (Pattern 2: spiffe-helper)
	orders, err := h.db.GetAllOrders(ctx)
	if err != nil {
		h.logger.Error("Failed to retrieve orders", "error", err)
		http.Error(w, "Failed to retrieve orders", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(orders)
}

// DemoHandler handles GET /api/demo requests - full demo flow
func (h *Handler) DemoHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	spiffeID := getEnv("SPIFFE_ID", "spiffe://example.org/ns/demo/sa/backend")

	result := DemoResult{
		Timestamp: time.Now(),
	}

	// Pattern 1: Frontend-to-Backend already verified by Envoy RBAC
	// The fact that we reached this handler means the frontend's SVID was validated
	frontendSPIFFEID := "spiffe://example.org/ns/demo/sa/frontend"
	h.logger.LogEvent(ctx, PatternEnvoySDS, EventConnectionSuccess, spiffeID, frontendSPIFFEID, 
		"Frontend-to-backend connection validated by Envoy RBAC")
	
	result.FrontendToBackend = ConnectionStatus{
		Success: true,
		Message: "Envoy validated frontend SPIFFE ID via SDS",
		Pattern: PatternEnvoySDS,
	}

	// Pattern 2: Backend-to-Database with spiffe-helper client certificates
	orders, err := h.db.GetAllOrders(ctx)
	if err != nil {
		h.logger.Error("Backend-to-database connection failed", "error", err, "pattern", PatternSpiffeHelper)
		result.BackendToDatabase = ConnectionStatus{
			Success: false,
			Message: "Failed to connect to PostgreSQL: " + err.Error(),
			Pattern: PatternSpiffeHelper,
		}
	} else {
		postgresSPIFFEID := "spiffe://example.org/ns/demo/sa/postgres"
		h.logger.LogEvent(ctx, PatternSpiffeHelper, EventConnectionSuccess, spiffeID, postgresSPIFFEID,
			"Backend-to-database connection successful with client certificate authentication")
		
		result.BackendToDatabase = ConnectionStatus{
			Success: true,
			Message: "PostgreSQL verified backend SPIFFE ID from client certificate",
			Pattern: PatternSpiffeHelper,
		}
		result.Orders = orders
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// LoggingMiddleware logs HTTP requests with structured logging
func (h *Handler) LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		
		h.logger.Info("HTTP request",
			"method", r.Method,
			"path", r.URL.Path,
			"remote_addr", r.RemoteAddr,
		)

		next.ServeHTTP(w, r)

		h.logger.Info("HTTP response",
			"method", r.Method,
			"path", r.URL.Path,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	})
}
