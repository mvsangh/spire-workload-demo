# Data Model: SPIRE/SPIFFE Demo

**Date**: 2025-12-19
**Branch**: `001-spire-spiffe-demo`

## Overview

This demo has a minimal data model focused on demonstrating mTLS communication. The `Order` entity provides meaningful data for the backend-to-database connection demo.

---

## Entities

### Order

Demo data entity representing a simple order stored in PostgreSQL.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | `integer` | PRIMARY KEY, AUTO INCREMENT | Unique order identifier |
| `description` | `varchar(255)` | NOT NULL | Order description text |
| `status` | `varchar(50)` | NOT NULL, DEFAULT 'pending' | Order status |
| `created_at` | `timestamp` | NOT NULL, DEFAULT NOW() | Creation timestamp |

**Valid Status Values**: `pending`, `processing`, `completed`, `failed`

**SQL Schema**:
```sql
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    description VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Seed data for demo
INSERT INTO orders (description, status) VALUES
    ('Demo Order 1 - Widget', 'completed'),
    ('Demo Order 2 - Gadget', 'processing'),
    ('Demo Order 3 - Service', 'pending');
```

---

## Identity Entities (SPIFFE/SPIRE)

These are not stored in PostgreSQL but are critical to the demo architecture.

### SPIFFE ID

URI-based workload identity.

| Field | Format | Example |
|-------|--------|---------|
| Trust Domain | `spiffe://<domain>/` | `spiffe://example.org/` |
| Path | `ns/<namespace>/sa/<service-account>` | `ns/demo/sa/frontend` |
| Full ID | Combined | `spiffe://example.org/ns/demo/sa/frontend` |

**Workload Identities**:

| Workload | SPIFFE ID | Service Account |
|----------|-----------|-----------------|
| Frontend | `spiffe://example.org/ns/demo/sa/frontend` | `frontend` |
| Backend | `spiffe://example.org/ns/demo/sa/backend` | `backend` |
| PostgreSQL | `spiffe://example.org/ns/demo/sa/postgres` | `postgres` |

### SPIRE Registration Entry

Maps Kubernetes selectors to SPIFFE IDs.

| Field | Description |
|-------|-------------|
| `spiffeID` | The SPIFFE ID to issue |
| `parentID` | SPIRE agent's SPIFFE ID |
| `selectors` | Kubernetes attestation selectors |
| `dns` | Optional DNS SAN to include |

**Example Entry**:
```json
{
  "spiffeID": "spiffe://example.org/ns/demo/sa/backend",
  "parentID": "spiffe://example.org/spire/agent/k8s_psat/demo-cluster/node/spire-demo-control-plane",
  "selectors": [
    "k8s:ns:demo",
    "k8s:sa:backend"
  ],
  "dns": ["backend.demo.svc.cluster.local"]
}
```

---

## Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                        SPIRE Server                             │
│                   (issues SVIDs via entries)                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        SPIRE Agent                              │
│                (Workload API on each node)                      │
└─────────────────────────────────────────────────────────────────┘
          │                   │                   │
          ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│    Frontend     │ │    Backend      │ │   PostgreSQL    │
│                 │ │                 │ │                 │
│ SPIFFE ID:      │ │ SPIFFE ID:      │ │ SPIFFE ID:      │
│ .../sa/frontend │ │ .../sa/backend  │ │ .../sa/postgres │
│                 │ │                 │ │                 │
│    [Envoy]      │ │    [Envoy]      │ │    [Envoy]      │
└─────────────────┘ └─────────────────┘ └─────────────────┘
          │                   │                   │
          │    mTLS           │    mTLS           │
          └───────────────────┼───────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Orders Table   │
                    │  (PostgreSQL)   │
                    └─────────────────┘
```

---

## State Transitions

### Order Status

```
┌─────────┐
│ pending │ ──────────────────────────────────────────┐
└────┬────┘                                           │
     │ (start processing)                             │
     ▼                                                │
┌────────────┐                                        │
│ processing │                                        │
└────┬───────┘                                        │
     │                                                │
     ├──(success)──► completed                        │
     │                                                │
     └──(error)────► failed ◄─────────────────────────┘
                              (timeout/error)
```

---

## Validation Rules

### Order Entity
- `description`: 1-255 characters, required
- `status`: Must be one of valid status values
- `created_at`: Auto-generated, immutable

### SPIFFE ID
- Must start with `spiffe://`
- Trust domain must be `example.org` (demo constraint)
- Path must follow `ns/<namespace>/sa/<service-account>` format

---

## Go Struct Definitions

```go
// internal/backend/models.go
package backend

import "time"

// Order represents a demo order in the database
type Order struct {
    ID          int       `json:"id"`
    Description string    `json:"description"`
    Status      string    `json:"status"`
    CreatedAt   time.Time `json:"created_at"`
}

// OrderStatus constants
const (
    StatusPending    = "pending"
    StatusProcessing = "processing"
    StatusCompleted  = "completed"
    StatusFailed     = "failed"
)
```

```go
// internal/frontend/models.go
package frontend

// DemoResult represents the result of a demo run
type DemoResult struct {
    FrontendToBackend ConnectionStatus `json:"frontend_to_backend"`
    BackendToDatabase ConnectionStatus `json:"backend_to_database"`
    Orders            []Order          `json:"orders,omitempty"`
    Error             string           `json:"error,omitempty"`
}

// ConnectionStatus represents the status of a connection test
type ConnectionStatus struct {
    Success bool   `json:"success"`
    Message string `json:"message"`
    Latency string `json:"latency,omitempty"`
}

// Order is the frontend representation (same as backend)
type Order struct {
    ID          int    `json:"id"`
    Description string `json:"description"`
    Status      string `json:"status"`
    CreatedAt   string `json:"created_at"`
}
```

---

## Database Initialization

PostgreSQL init script for demo data:

```sql
-- deploy/apps/postgres-init.sql

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    description VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Insert demo data
INSERT INTO orders (description, status, created_at) VALUES
    ('Widget Assembly Kit', 'completed', NOW() - INTERVAL '2 days'),
    ('Premium Gadget Pro', 'processing', NOW() - INTERVAL '1 day'),
    ('Enterprise Service Plan', 'pending', NOW()),
    ('Developer Toolkit', 'completed', NOW() - INTERVAL '3 days'),
    ('Cloud Integration Bundle', 'processing', NOW() - INTERVAL '4 hours')
ON CONFLICT DO NOTHING;
```
