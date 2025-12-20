# Multi-stage build for frontend service

# Stage 1: Build the Go binary
FROM golang:1.25-alpine AS builder

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY cmd/frontend/ ./cmd/frontend/
COPY internal/frontend/ ./internal/frontend/

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux go build -o frontend ./cmd/frontend

# Stage 2: Runtime image
FROM alpine:3.19

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates wget

# Create non-root user
RUN addgroup -g 1000 frontend && \
    adduser -D -u 1000 -G frontend frontend

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/frontend .

# Copy static files
COPY --chown=frontend:frontend internal/frontend/static ./static

# Set ownership
RUN chown -R frontend:frontend /app

# Switch to non-root user
USER frontend

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run the frontend binary
CMD ["./frontend"]
