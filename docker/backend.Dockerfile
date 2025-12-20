# Build stage
FROM golang:1.25-alpine AS builder

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY cmd/backend/ ./cmd/backend/
COPY internal/backend/ ./internal/backend/

# Build the backend binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o backend ./cmd/backend

# Runtime stage
FROM alpine:3.19

# Install ca-certificates for HTTPS connections
RUN apk --no-cache add ca-certificates

WORKDIR /app

# Create non-root user
RUN addgroup -g 1000 backend && \
    adduser -D -u 1000 -G backend backend

# Copy binary from builder
COPY --from=builder /build/backend .

# Change ownership to non-root user
RUN chown -R backend:backend /app

# Switch to non-root user
USER backend

# Expose backend API port (accessed via Envoy on 8080)
EXPOSE 9090

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:9090/health || exit 1

# Run the backend service
CMD ["./backend"]
