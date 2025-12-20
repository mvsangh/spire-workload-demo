package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/example/spire-workload-demo/internal/backend"
)

func main() {
	// Initialize structured logger
	logger := backend.NewLogger("backend")
	logger.Info("Starting backend service")

	// Load database configuration from environment
	dbConfig := backend.NewDBConfigFromEnv()
	
	// Log configuration (without sensitive data)
	logger.Info("Database configuration loaded",
		"host", dbConfig.Host,
		"port", dbConfig.Port,
		"dbname", dbConfig.DBName,
		"max_open_conns", dbConfig.MaxOpenConns,
		"max_idle_conns", dbConfig.MaxIdleConns,
		"conn_max_lifetime", dbConfig.ConnMaxLifetime,
		"ssl_cert", dbConfig.SSLCert,
		"ssl_key", dbConfig.SSLKey,
		"ssl_root_ca", dbConfig.SSLRootCA,
	)

	// Connect to database with Pattern 2 (spiffe-helper client certificates)
	ctx := context.Background()
	db, err := backend.NewDB(ctx, dbConfig, logger)
	if err != nil {
		logger.Error("Failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	logger.Info("Database connection established successfully",
		"pattern", backend.PatternSpiffeHelper,
	)

	// Create HTTP handlers
	handler := backend.NewHandler(db, logger)

	// Setup HTTP router with logging middleware
	mux := http.NewServeMux()
	mux.HandleFunc("/health", handler.HealthHandler)
	mux.HandleFunc("/api/orders", handler.OrdersHandler)
	mux.HandleFunc("/api/demo", handler.DemoHandler)

	// Wrap with logging middleware
	httpHandler := handler.LoggingMiddleware(mux)

	// Configure HTTP server
	port := getEnv("PORT", "9090")
	server := &http.Server{
		Addr:         fmt.Sprintf(":%s", port),
		Handler:      httpHandler,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in a goroutine
	serverErrors := make(chan error, 1)
	go func() {
		logger.Info("Backend HTTP server starting",
			"port", port,
			"endpoints", []string{"/health", "/api/orders", "/api/demo"},
		)
		serverErrors <- server.ListenAndServe()
	}()

	// Wait for interrupt signal for graceful shutdown
	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	select {
	case err := <-serverErrors:
		logger.Error("Server error", "error", err)
		os.Exit(1)

	case sig := <-shutdown:
		logger.Info("Shutdown signal received", "signal", sig)

		// Give outstanding requests a deadline for completion
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := server.Shutdown(ctx); err != nil {
			logger.Error("Graceful shutdown failed", "error", err)
			if err := server.Close(); err != nil {
				logger.Error("Force close failed", "error", err)
			}
		}

		logger.Info("Backend service stopped gracefully")
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
