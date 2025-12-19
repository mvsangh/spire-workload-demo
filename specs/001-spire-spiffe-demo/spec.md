# Feature Specification: SPIRE/SPIFFE Production-Style Demo

**Feature Branch**: `001-spire-spiffe-demo`
**Created**: 2025-12-18
**Updated**: 2025-12-19
**Status**: Draft (Updated with dual SPIFFE integration patterns)
**Input**: User description: "SPIRE/SPIFFE Production-Style Demo on kind with Go Frontend UI, Backend, Envoy, Postgres, and Envoy RBAC"

## Overview

This feature creates a production-style demonstration environment showcasing SPIRE/SPIFFE workload identity on a local kind Kubernetes cluster. The demo highlights workload identity with SPIFFE IDs, mutual TLS (mTLS) between services and database, automatic certificate rotation, and policy enforcement via Envoy RBAC - showcasing TWO different SPIFFE integration patterns in a single demo.

### High-Level Goals

1. Demonstrate SPIFFE/SPIRE in a production-like manner while remaining runnable on a laptop
2. Show TWO integration patterns: Envoy SDS (frontend ↔ backend) and spiffe-helper (backend → database)
3. Demonstrate true end-to-end mTLS where PostgreSQL itself verifies client SPIFFE IDs
4. Provide a simple but clear UI showing communication status between components
5. Create a foundation for future extensions (OPA, federation, non-K8s workloads)

---

## Architecture Diagrams

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              KIND CLUSTER (spire-demo)                          │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                        NAMESPACE: spire-system                           │   │
│  │                                                                          │   │
│  │   ┌─────────────────────┐         ┌─────────────────────┐               │   │
│  │   │    SPIRE Server     │         │    SPIRE Agent      │               │   │
│  │   │    (StatefulSet)    │◄───────►│    (DaemonSet)      │               │   │
│  │   │                     │  gRPC   │                     │               │   │
│  │   │  - Issues SVIDs     │         │  - Workload API     │               │   │
│  │   │  - Registration     │         │  - Node attestation │               │   │
│  │   │  - Trust bundle     │         │  - SVID delivery    │               │   │
│  │   └─────────────────────┘         └──────────┬──────────┘               │   │
│  │                                              │                           │   │
│  └──────────────────────────────────────────────┼───────────────────────────┘   │
│                                                 │ hostPath: /run/spire/agent-sockets
│  ┌──────────────────────────────────────────────┼───────────────────────────┐   │
│  │                        NAMESPACE: demo       │                           │   │
│  │                                              ▼                           │   │
│  │   ┌───────────────┐    ┌───────────────┐    ┌───────────────┐           │   │
│  │   │   Frontend    │    │    Backend    │    │   PostgreSQL  │           │   │
│  │   │     Pod       │    │      Pod      │    │      Pod      │           │   │
│  │   │               │    │               │    │               │           │   │
│  │   │  [Go App]     │    │  [Go App]     │    │  [Postgres]   │           │   │
│  │   │  [Envoy]      │───►│  [Envoy]      │    │               │           │   │
│  │   │               │    │  [spiffe-     │───►│  [spiffe-     │           │   │
│  │   │               │    │   helper]     │    │   helper]     │           │   │
│  │   └───────────────┘    └───────────────┘    └───────────────┘           │   │
│  │                                                                          │   │
│  │        Pattern 1: Envoy SDS          Pattern 2: spiffe-helper           │   │
│  │        (Service-to-Service)          (Application-to-Database)          │   │
│  │                                                                          │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
                    │
                    │ NodePort 30080
                    ▼
              http://localhost:8080
```

### Pod Architecture (Detailed)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                 FRONTEND POD                                     │
│  ServiceAccount: frontend                                                        │
│  SPIFFE ID: spiffe://example.org/ns/demo/sa/frontend                            │
│                                                                                  │
│  ┌────────────────────────────────┐  ┌────────────────────────────────┐         │
│  │         frontend (Go)          │  │           envoy                │         │
│  │                                │  │                                │         │
│  │  - Serves UI on :8080          │  │  - Outbound proxy on :8001    │         │
│  │  - Calls backend via           │  │  - SDS for SVID certificates  │         │
│  │    http://127.0.0.1:8001       │  │  - mTLS to backend:8080       │         │
│  │                                │  │                                │         │
│  └────────────────────────────────┘  └────────────────────────────────┘         │
│                                              │                                   │
│                                              │ mounts spire-agent-socket         │
│                                              ▼                                   │
│                                       /run/spire/agent-sockets                  │
└─────────────────────────────────────────────────────────────────────────────────┘
                                               │
                                               │ Pattern 1: Envoy SDS (mTLS)
                                               │ Frontend SVID ──► Backend SVID
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                  BACKEND POD                                     │
│  ServiceAccount: backend                                                         │
│  SPIFFE ID: spiffe://example.org/ns/demo/sa/backend                             │
│                                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐       │
│  │   backend (Go)   │  │      envoy       │  │     spiffe-helper        │       │
│  │                  │  │                  │  │     (native sidecar)     │       │
│  │  - API on :9090  │  │  - Inbound :8080 │  │                          │       │
│  │  - Reads certs   │  │  - SDS for SVID  │  │  - Fetches backend SVID  │       │
│  │    from          │  │  - RBAC filter:  │  │  - Writes to:            │       │
│  │    /spiffe-certs │  │    allows only   │  │    /spiffe-certs/        │       │
│  │  - Connects to   │  │    frontend      │  │      svid.pem            │       │
│  │    PostgreSQL    │  │    SPIFFE ID     │  │      svid_key.pem        │       │
│  │    with client   │  │                  │  │      svid_bundle.pem     │       │
│  │    certs         │  │                  │  │                          │       │
│  └────────┬─────────┘  └──────────────────┘  └────────────┬─────────────┘       │
│           │                                               │                      │
│           │ reads                              writes     │                      │
│           └──────────────► /spiffe-certs ◄────────────────┘                      │
│                            (emptyDir)                                            │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
                                               │
                                               │ Pattern 2: spiffe-helper (mTLS)
                                               │ Backend client cert ──► PostgreSQL
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                POSTGRESQL POD                                    │
│  ServiceAccount: postgres                                                        │
│  SPIFFE ID: spiffe://example.org/ns/demo/sa/postgres                            │
│                                                                                  │
│  ┌────────────────────────────────────┐  ┌──────────────────────────────┐       │
│  │          postgres                  │  │       spiffe-helper          │       │
│  │                                    │  │       (native sidecar)       │       │
│  │  - Database on :5432               │  │                              │       │
│  │  - SSL enabled                     │  │  - Fetches postgres SVID     │       │
│  │  - Uses SVID as server cert:       │  │  - Writes to:                │       │
│  │    ssl_cert_file=/spiffe-certs/    │  │    /spiffe-certs/            │       │
│  │      svid.pem                      │  │      svid.pem                │       │
│  │    ssl_key_file=/spiffe-certs/     │  │      svid_key.pem            │       │
│  │      svid_key.pem                  │  │      svid_bundle.pem         │       │
│  │    ssl_ca_file=/spiffe-certs/      │  │                              │       │
│  │      svid_bundle.pem               │  │  - Runs as postgres user     │       │
│  │                                    │  │    (UID 999) for correct     │       │
│  │  - pg_hba.conf: clientcert=verify-ca    file ownership              │       │
│  │    (verifies backend SPIFFE ID)   │  │                              │       │
│  │                                    │  │                              │       │
│  └────────────────┬───────────────────┘  └──────────────┬───────────────┘       │
│                   │                                      │                       │
│                   │ reads                     writes     │                       │
│                   └──────────► /spiffe-certs ◄───────────┘                       │
│                                (emptyDir)                                        │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### mTLS Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                              mTLS COMMUNICATION FLOW                             │
└──────────────────────────────────────────────────────────────────────────────────┘

                           PATTERN 1: Envoy SDS
                     (Service-to-Service Communication)
    ┌─────────────────────────────────────────────────────────────────────┐
    │                                                                     │
    │   Frontend App                                      Backend App     │
    │       │                                                 ▲           │
    │       │ HTTP :8001                                      │           │
    │       ▼                                                 │           │
    │   ┌───────────┐                                   ┌───────────┐     │
    │   │  Envoy    │────────── mTLS (SVID) ──────────►│  Envoy    │     │
    │   │ (client)  │                                   │ (server)  │     │
    │   └─────┬─────┘                                   └─────┬─────┘     │
    │         │                                               │           │
    │         │ SDS API                                 SDS API           │
    │         ▼                                               ▼           │
    │   ┌───────────────────────────────────────────────────────────┐     │
    │   │                      SPIRE Agent                          │     │
    │   │  - Delivers SVIDs via SDS (Secret Discovery Service)      │     │
    │   │  - Auto-rotates certificates                              │     │
    │   │  - No file I/O needed                                     │     │
    │   └───────────────────────────────────────────────────────────┘     │
    │                                                                     │
    │   RBAC Enforcement:                                                 │
    │   Backend Envoy only accepts connections from:                      │
    │     spiffe://example.org/ns/demo/sa/frontend                        │
    │                                                                     │
    └─────────────────────────────────────────────────────────────────────┘


                           PATTERN 2: spiffe-helper
                     (Application-to-Database Communication)
    ┌─────────────────────────────────────────────────────────────────────┐
    │                                                                     │
    │   Backend App                                      PostgreSQL       │
    │       │                                                 ▲           │
    │       │ reads client cert                               │           │
    │       ▼                                                 │           │
    │   /spiffe-certs/                               /spiffe-certs/       │
    │     svid.pem ─────────── mTLS (SVID) ───────────► svid.pem         │
    │     svid_key.pem        (PostgreSQL SSL)          svid_key.pem      │
    │     svid_bundle.pem                               svid_bundle.pem   │
    │       ▲                                                 ▲           │
    │       │ writes                                    writes │           │
    │   ┌───────────┐                                   ┌───────────┐     │
    │   │  spiffe-  │                                   │  spiffe-  │     │
    │   │  helper   │                                   │  helper   │     │
    │   └─────┬─────┘                                   └─────┬─────┘     │
    │         │                                               │           │
    │         │ Workload API                       Workload API           │
    │         ▼                                               ▼           │
    │   ┌───────────────────────────────────────────────────────────┐     │
    │   │                      SPIRE Agent                          │     │
    │   │  - Delivers SVIDs via Workload API                        │     │
    │   │  - spiffe-helper writes to files                          │     │
    │   │  - Files auto-rotated by spiffe-helper                    │     │
    │   └───────────────────────────────────────────────────────────┘     │
    │                                                                     │
    │   Client Certificate Verification:                                  │
    │   PostgreSQL pg_hba.conf requires clientcert=verify-ca              │
    │   Validates backend SPIFFE ID in certificate SAN                    │
    │                                                                     │
    └─────────────────────────────────────────────────────────────────────┘
```

### SPIFFE ID Assignments

| Workload | Service Account | SPIFFE ID | Pattern |
|----------|-----------------|-----------|---------|
| Frontend | `frontend` | `spiffe://example.org/ns/demo/sa/frontend` | Pattern 1 (Envoy SDS) |
| Backend | `backend` | `spiffe://example.org/ns/demo/sa/backend` | Both Patterns |
| PostgreSQL | `postgres` | `spiffe://example.org/ns/demo/sa/postgres` | Pattern 2 (spiffe-helper) |

### Pattern Comparison

| Aspect | Pattern 1: Envoy SDS | Pattern 2: spiffe-helper |
|--------|---------------------|-------------------------|
| **Use Case** | Service-to-service (HTTP/gRPC) | App-to-database (native protocols) |
| **Certificate Delivery** | SDS API (in-memory) | File-based (/spiffe-certs/) |
| **Application Changes** | Zero code changes | Read cert files in connection string |
| **Protocol Support** | HTTP/1.1, HTTP/2, gRPC | Any protocol (PostgreSQL, MySQL, etc.) |
| **RBAC/Policy** | Envoy RBAC filter | Database-level (pg_hba.conf) |
| **Rotation** | Automatic via SDS | Automatic via file updates |
| **Best For** | Service mesh patterns | Legacy apps, databases |

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Happy Path Demo Flow (Priority: P1)

A demo presenter deploys the complete system and demonstrates successful mTLS-secured communication between all components through a simple web UI.

**Why this priority**: This is the core demo experience - showing that SPIRE/SPIFFE enables secure service-to-service communication transparently without application code changes. Without this working, there is no demo.

**Independent Test**: Can be fully tested by deploying the system, opening the web UI, clicking "Run Demo", and observing both Frontend-to-Backend and Backend-to-Database connections succeed.

**Acceptance Scenarios**:

1. **Given** a freshly deployed kind cluster with all components running, **When** the user opens the frontend UI and clicks "Run Demo", **Then** the UI displays "Frontend to Backend: SUCCESS" and "Backend to DB: SUCCESS"
2. **Given** the system is running, **When** the user inspects Envoy logs, **Then** mTLS handshakes are visible for frontend-to-backend showing SPIFFE IDs being validated by Envoy
3. **Given** the system is running, **When** the user inspects PostgreSQL logs, **Then** client certificate authentication is visible showing backend SPIFFE ID being validated by PostgreSQL directly
4. **Given** all SPIRE registration entries exist, **When** frontend calls backend, **Then** the backend Envoy validates the frontend's SVID certificate using SDS
5. **Given** backend connects to PostgreSQL, **When** the connection is established, **Then** PostgreSQL verifies the backend's SVID certificate written by spiffe-helper

---

### User Story 2 - RBAC Policy Denial Demo (Priority: P2)

A demo presenter modifies the Envoy RBAC policy to deny the frontend's SPIFFE ID, demonstrating that policy changes take effect without application code changes.

**Why this priority**: Demonstrates the key value proposition - security policy changes happen at the infrastructure layer without touching application code. This is essential for showing the separation of concerns.

**Independent Test**: Can be tested by changing the backend Envoy RBAC config to require a different SPIFFE ID, redeploying, and verifying the UI shows connection failure.

**Acceptance Scenarios**:

1. **Given** the system is working (P1 verified), **When** the Envoy-backend RBAC policy is changed to deny the frontend SPIFFE ID and the backend is redeployed, **Then** clicking "Run Demo" shows "Frontend to Backend: FAILED"
2. **Given** RBAC denies frontend access, **When** the user views the error message, **Then** a meaningful explanation indicates policy/RBAC denial
3. **Given** RBAC was modified to deny, **When** RBAC is restored to allow frontend, **Then** the demo succeeds again without any backend app changes

---

### User Story 3 - Certificate Rotation Demo (Priority: P3)

A demo presenter shows that SPIRE automatically rotates certificates while the application continues running without interruption.

**Why this priority**: Certificate rotation without downtime is a major operational benefit of SPIRE. However, it requires the happy path to work first and is more of an advanced demonstration.

**Independent Test**: Can be tested by setting a short SVID TTL, running continuous requests, and observing via logs that SVIDs rotate while requests continue succeeding.

**Acceptance Scenarios**:

1. **Given** SPIRE is configured with a short SVID TTL (for demo purposes), **When** continuous requests are made over a period longer than the TTL, **Then** requests continue succeeding without interruption
2. **Given** continuous requests are running, **When** SVID rotation occurs, **Then** Envoy logs or SPIRE agent logs show new certificates being issued
3. **Given** rotation occurs, **When** the user checks the UI, **Then** no errors or connection failures appear during the rotation period

---

### User Story 4 - One-Command Setup (Priority: P4)

A developer or presenter can deploy the entire demo environment with minimal manual steps using provided scripts.

**Why this priority**: Ease of setup is critical for adoption and repeated demos, but the core functionality must work first.

**Independent Test**: Can be tested by running the setup scripts on a clean machine with Docker and kind installed, verifying all pods reach Running state.

**Acceptance Scenarios**:

1. **Given** a machine with Docker and kubectl installed, **When** the user runs the kind cluster setup script, **Then** a working kind cluster is created
2. **Given** a kind cluster exists, **When** the user runs deploy scripts in sequence, **Then** all pods in spire-system and demo namespaces reach Running state within 3 minutes
3. **Given** all components are deployed, **When** the user runs the registration entry script, **Then** SPIRE entries are created for frontend and backend workloads

---

### Edge Cases

- What happens when SPIRE server is temporarily unavailable? The system should use cached SVIDs until they expire.
- What happens when a workload's service account doesn't match any registration entry? The workload should fail to obtain an SVID and connections should fail.
- What happens when Postgres is unavailable? The backend should return an appropriate error that the frontend displays.
- What happens when Envoy sidecar fails to start? The pod should not become Ready (liveness/readiness probes should detect this).
- What happens when spiffe-helper fails to write certificates? The application or database should fail to establish mTLS connections and log appropriate errors.
- What happens when certificate files are rotated while PostgreSQL is actively using them? PostgreSQL should automatically reload the new certificates without dropping existing connections.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy SPIRE server as a highly-available deployment in a dedicated namespace (spire-system)
- **FR-002**: System MUST deploy SPIRE agent as a DaemonSet to expose Workload API on all nodes
- **FR-003**: System MUST issue SPIFFE IDs in the format `spiffe://example.org/ns/demo/sa/{service-account-name}` based on Kubernetes namespace and service account selectors
- **FR-004**: Frontend service MUST communicate with backend service through Envoy sidecars using mTLS (Pattern 1: Envoy SDS)
- **FR-005**: Backend service MUST communicate with PostgreSQL using client certificate authentication where spiffe-helper writes SVID certificates to files that backend and PostgreSQL use directly (Pattern 2: spiffe-helper)
- **FR-006**: Backend Envoy MUST enforce RBAC policy allowing only the frontend SPIFFE ID to access backend endpoints
- **FR-007**: Frontend web UI MUST display connection status for both frontend-to-backend and backend-to-database links
- **FR-008**: Frontend web UI MUST provide a "Run Demo" action that triggers end-to-end communication test
- **FR-009**: System MUST support certificate rotation without requiring service restarts
- **FR-010**: All deployment manifests and scripts MUST be contained in a single repository
- **FR-011**: System MUST run on a local kind Kubernetes cluster
- **FR-012**: System MUST showcase TWO distinct SPIFFE integration patterns: Envoy SDS for service-to-service and spiffe-helper for application-to-database
- **FR-013**: PostgreSQL MUST require client certificate authentication for connections from backend and MUST directly verify the backend's SPIFFE ID from SVID certificates
- **FR-014**: System MUST provide shell scripts for cluster setup, component deployment, and SPIRE entry registration
- **FR-015**: Frontend and backend services MUST be implemented in Go
- **FR-016**: Frontend-to-backend communication MUST use HTTP/JSON protocol
- **FR-017**: PostgreSQL pod MUST include spiffe-helper sidecar that fetches SVIDs from SPIRE agent and writes certificate files to shared volume
- **FR-018**: Backend pod MUST include spiffe-helper sidecar that fetches SVIDs and writes certificate files for PostgreSQL client authentication

### Key Entities

- **SPIFFE ID**: A unique workload identifier in URI format (e.g., `spiffe://example.org/ns/demo/sa/frontend`) that represents a workload's cryptographic identity
- **SVID (SPIFFE Verifiable Identity Document)**: An X.509 certificate containing the SPIFFE ID in the SAN field, used for mTLS authentication
- **Registration Entry**: A SPIRE server configuration that maps workload selectors (namespace, service account) to SPIFFE IDs
- **Trust Bundle**: Collection of CA certificates from SPIRE used to verify SVIDs from other workloads
- **Workload**: A running service (frontend, backend, database) that receives an SVID from SPIRE via the Workload API
- **spiffe-helper**: A sidecar container that fetches SVIDs from SPIRE agent and writes them to files for consumption by applications or databases
- **Order**: Demo data entity stored in PostgreSQL with id, description, and status fields

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Demo presenter can go from clean state to working demo in under 10 minutes using provided scripts
- **SC-002**: 100% of mTLS connections use valid SVIDs issued by SPIRE (verifiable via Envoy logs for service-to-service and PostgreSQL logs for database connections)
- **SC-003**: Policy changes (RBAC modification) take effect within 60 seconds of deployment without application restarts
- **SC-004**: Certificate rotation occurs automatically without any service downtime or failed requests for both Envoy SDS and spiffe-helper patterns
- **SC-005**: UI clearly displays success/failure status for both communication paths within 2 seconds of user action
- **SC-006**: All demo scenarios (happy path, RBAC denial, cert rotation) can be demonstrated in under 15 minutes total
- **SC-007**: Demo runs successfully on machines with 8GB RAM and 4 CPU cores (typical developer laptop)
- **SC-008**: Backend correctly returns order data from PostgreSQL when all connections succeed
- **SC-009**: PostgreSQL directly verifies backend SPIFFE ID from SVID certificates (not through Envoy proxy)

## Clarifications

### Session 2025-12-18

- Q: Which container runtime is available? → A: Podman Desktop with Docker CLI installed

### Session 2025-12-19

- Q: How should PostgreSQL integrate with SPIFFE? → A: Use spiffe-helper sidecar to write SVID certificates directly for PostgreSQL to verify (not Envoy proxy)

## Assumptions

- Podman Desktop with Docker CLI is the container runtime (kind works with both Docker and Podman backends)
- kubectl is installed and accessible from the command line
- The kind CLI tool is installed
- Host machine has at least 8GB RAM and 4 CPU cores available for the demo cluster
- Network connectivity allows pulling container images from public registries
- Trust domain `example.org` is used for all SPIFFE IDs (demo purposes only)
- SQLite is acceptable for SPIRE server datastore in demo environment (not production-grade)
- Single kind cluster is sufficient for v1 (federation is a future enhancement)
- No external PKI/CA integration required for v1 (self-signed SPIRE root)

## Out of Scope (v1)

- OPA-based policy enforcement (future enhancement)
- SPIRE federation across multiple clusters (future enhancement)
- Non-Kubernetes workloads (future enhancement)
- Direct go-spiffe library usage in application code (future variant)
- Production-grade SPIRE datastore (PostgreSQL backend)
- External CA/PKI integration (Vault, enterprise CA)
- Metrics, logging aggregation, and dashboards
- gRPC protocol between services
- Multiple trust domains
