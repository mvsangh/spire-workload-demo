package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/example/spire-workload-demo/internal/frontend"
)

func main() {
	// Initialize structured logger
	logger := frontend.NewLogger("frontend")
	logger.Info("Starting frontend service")

	// Create handler with dependencies
	handler := frontend.NewHandler(logger)

	// Configure HTTP router
	mux := http.NewServeMux()

	// Routes
	mux.HandleFunc("/", handler.IndexHandler())
	mux.HandleFunc("/static/", handler.StaticHandler())
	mux.HandleFunc("/api/demo", handler.DemoHandler())
	mux.HandleFunc("/health", handler.HealthHandler())

	// Wrap with logging middleware
	wrappedMux := handler.LoggingMiddleware(mux)

	// Get port from environment
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Create HTTP server
	server := &http.Server{
		Addr:         fmt.Sprintf(":%s", port),
		Handler:      wrappedMux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Channel to listen for errors from the server
	serverErrors := make(chan error, 1)

	// Start HTTP server in goroutine
	go func() {
		logger.Info("Frontend HTTP server starting",
			"port", port,
			"endpoints", []string{"/", "/static/*", "/api/demo", "/health"},
		)
		serverErrors <- server.ListenAndServe()
	}()

	// Channel to listen for interrupt signals
	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	// Block until we receive a signal or server error
	select {
	case err := <-serverErrors:
		logger.Error("Server error", "error", err.Error())
		os.Exit(1)

	case sig := <-shutdown:
		logger.Info("Shutdown signal received", "signal", sig.String())

		// Create context with timeout for graceful shutdown
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		// Attempt graceful shutdown
		if err := server.Shutdown(ctx); err != nil {
			logger.Error("Graceful shutdown failed", "error", err.Error())
			if err := server.Close(); err != nil {
				logger.Error("Forced shutdown failed", "error", err.Error())
			}
			os.Exit(1)
		}

		logger.Info("Frontend service stopped gracefully")
	}
}
