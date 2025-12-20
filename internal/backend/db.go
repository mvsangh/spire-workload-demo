package backend

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"strconv"
	"time"

	_ "github.com/lib/pq" // PostgreSQL driver
)

// DBConfig holds database connection configuration
type DBConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	// Connection pool settings (FR-020)
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime time.Duration
	// SPIFFE certificate paths (Pattern 2: spiffe-helper)
	SSLCert   string
	SSLKey    string
	SSLRootCA string
}

// NewDBConfigFromEnv creates database configuration from environment variables
func NewDBConfigFromEnv() *DBConfig {
	// Parse connection pool settings with defaults (FR-020)
	maxOpenConns := getEnvAsInt("DB_MAX_OPEN_CONNS", 10)
	maxIdleConns := getEnvAsInt("DB_MAX_IDLE_CONNS", 5)
	connMaxLifetime := getEnvAsDuration("DB_CONN_MAX_LIFETIME", 2*time.Minute)

	return &DBConfig{
		Host:            getEnv("DB_HOST", "postgres.demo.svc.cluster.local"),
		Port:            getEnv("DB_PORT", "5432"),
		User:            getEnv("DB_USER", "postgres"),
		Password:        getEnv("DB_PASSWORD", ""),
		DBName:          getEnv("DB_NAME", "demodb"),
		MaxOpenConns:    maxOpenConns,
		MaxIdleConns:    maxIdleConns,
		ConnMaxLifetime: connMaxLifetime,
		// SPIFFE certificates written by spiffe-helper sidecar
		SSLCert:   getEnv("SSL_CERT", "/spiffe-certs/svid.pem"),
		SSLKey:    getEnv("SSL_KEY", "/spiffe-certs/svid_key.pem"),
		SSLRootCA: getEnv("SSL_ROOT_CA", "/spiffe-certs/svid_bundle.pem"),
	}
}

// DB wraps sql.DB with structured logging
type DB struct {
	*sql.DB
	logger *Logger
	config *DBConfig
}

// NewDB creates a new database connection with client certificate authentication (Pattern 2)
func NewDB(ctx context.Context, config *DBConfig, logger *Logger) (*DB, error) {
	spiffeID := getEnv("SPIFFE_ID", "spiffe://example.org/ns/demo/sa/backend")
	
	logger.LogConnectionAttempt(ctx, PatternSpiffeHelper, config.Host, spiffeID)

	// Build connection string with SSL client certificate authentication
	connStr := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=require sslcert=%s sslkey=%s sslrootcert=%s",
		config.Host,
		config.Port,
		config.User,
		config.Password,
		config.DBName,
		config.SSLCert,
		config.SSLKey,
		config.SSLRootCA,
	)

	// Open database connection
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		logger.LogConnectionFailure(ctx, PatternSpiffeHelper, config.Host, spiffeID, err)
		return nil, fmt.Errorf("failed to open database connection: %w", err)
	}

	// Configure connection pool (FR-020)
	db.SetMaxOpenConns(config.MaxOpenConns)
	db.SetMaxIdleConns(config.MaxIdleConns)
	db.SetConnMaxLifetime(config.ConnMaxLifetime)

	logger.Info("Connection pool configured",
		"max_open_conns", config.MaxOpenConns,
		"max_idle_conns", config.MaxIdleConns,
		"conn_max_lifetime", config.ConnMaxLifetime,
	)

	// Test the connection
	if err := db.PingContext(ctx); err != nil {
		logger.LogConnectionFailure(ctx, PatternSpiffeHelper, config.Host, spiffeID, err)
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	// Log successful connection with Pattern 2 (spiffe-helper)
	peerSPIFFEID := "spiffe://example.org/ns/demo/sa/postgres"
	logger.LogConnectionSuccess(ctx, PatternSpiffeHelper, config.Host, spiffeID, peerSPIFFEID)

	return &DB{
		DB:     db,
		logger: logger,
		config: config,
	}, nil
}

// GetAllOrders retrieves all orders from the database
func (db *DB) GetAllOrders(ctx context.Context) ([]Order, error) {
	query := `SELECT id, description, status, created_at FROM orders ORDER BY created_at DESC`

	rows, err := db.QueryContext(ctx, query)
	if err != nil {
		db.logger.Error("Failed to query orders", "error", err)
		return nil, fmt.Errorf("failed to query orders: %w", err)
	}
	defer rows.Close()

	var orders []Order
	for rows.Next() {
		var order Order
		if err := rows.Scan(&order.ID, &order.Description, &order.Status, &order.CreatedAt); err != nil {
			db.logger.Error("Failed to scan order row", "error", err)
			return nil, fmt.Errorf("failed to scan order: %w", err)
		}
		orders = append(orders, order)
	}

	if err := rows.Err(); err != nil {
		db.logger.Error("Error iterating order rows", "error", err)
		return nil, fmt.Errorf("error iterating orders: %w", err)
	}

	db.logger.Info("Retrieved orders", "count", len(orders), "pattern", PatternSpiffeHelper)
	return orders, nil
}

// HealthCheck verifies database connectivity
func (db *DB) HealthCheck(ctx context.Context) error {
	if err := db.PingContext(ctx); err != nil {
		return fmt.Errorf("database health check failed: %w", err)
	}
	return nil
}

// Helper functions

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		return defaultValue
	}
	value, err := strconv.Atoi(valueStr)
	if err != nil {
		return defaultValue
	}
	return value
}

func getEnvAsDuration(key string, defaultValue time.Duration) time.Duration {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		return defaultValue
	}
	value, err := time.ParseDuration(valueStr)
	if err != nil {
		return defaultValue
	}
	return value
}
