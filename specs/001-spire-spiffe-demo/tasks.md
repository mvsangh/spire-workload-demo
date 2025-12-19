# Implementation Tasks: SPIRE/SPIFFE Demo

**Branch**: `001-spire-spiffe-demo`
**Generated**: 2025-12-19 (Updated with corrected dual-pattern architecture)
**Total Tasks**: 74
**Estimated Phases**: 7 phases organized by user story

**CRITICAL ARCHITECTURE UPDATE**: This implementation uses TWO SPIFFE integration patterns:
- **Pattern 1**: Envoy SDS (frontend ↔ backend)
- **Pattern 2**: spiffe-helper (backend → PostgreSQL)

---

## Task Legend

| Status | Meaning |
|--------|---------|
| `[ ]` | Not started |
| `[~]` | In progress |
| `[x]` | Completed |
| `[!]` | Needs correction (wrong architecture) |
| `[-]` | Skipped/Deprecated |

---

## Phase 1: Setup (Tasks 1-5) - COMPLETED ✅

**Purpose**: Project initialization and Go module configuration

---

### Task 1: Create kind cluster configuration file

**Status**: `[x]` Completed

**Goal**: Create the kind cluster config YAML for SPIRE demo.

**File**: `deploy/kind/cluster-config.yaml`

**Acceptance Criteria**:
- [x] File exists at specified path
- [x] Contains single control-plane node
- [x] Has extraPortMappings for port 30080 → 8080
- [x] Valid YAML syntax

---

### Task 2: Create cluster setup script

**Status**: `[x]` Completed

**Goal**: Create shell script to create kind cluster.

**File**: `scripts/01-create-cluster.sh`

**Acceptance Criteria**:
- [x] Script is executable
- [x] Uses cluster-config.yaml from deploy/kind/
- [x] Includes error handling (set -e)
- [x] Prints status messages

---

### Task 3: Create namespaces manifest

**Status**: `[x]` Completed

**Goal**: Create Kubernetes namespace definitions for spire-system and demo.

**File**: `deploy/namespaces.yaml`

**Acceptance Criteria**:
- [x] Defines namespace `spire-system`
- [x] Defines namespace `demo`
- [x] Valid YAML syntax

---

### Task 4: Create Go module initialization

**Status**: `[x]` Completed

**Goal**: Initialize Go module for the project.

**Files**: `go.mod`, `go.sum`

**Acceptance Criteria**:
- [x] go.mod exists with module path
- [x] Go version is 1.21+
- [x] Module name follows convention

---

### Task 5: Create cleanup script

**Status**: `[x]` Completed

**Goal**: Create script to tear down the entire demo environment.

**File**: `scripts/cleanup.sh`

**Acceptance Criteria**:
- [x] Script is executable
- [x] Deletes kind cluster named `spire-demo`
- [x] Handles case where cluster doesn't exist
- [x] Prints confirmation message

---

## Phase 2: Foundational - SPIRE Infrastructure (Tasks 6-23) - COMPLETED ✅

**Purpose**: Core SPIRE infrastructure that BLOCKS all user stories

---

### Group 2: SPIRE Server (Tasks 6-14) - ALL COMPLETED ✅

### Task 6: Create SPIRE server ServiceAccount

**Status**: `[x]` Completed

**File**: `deploy/spire/server/serviceaccount.yaml`

---

### Task 7: Create SPIRE server ClusterRole

**Status**: `[x]` Completed

**File**: `deploy/spire/server/clusterrole.yaml`

---

### Task 8: Create SPIRE server ClusterRoleBinding

**Status**: `[x]` Completed

**File**: `deploy/spire/server/clusterrolebinding.yaml`

---

### Task 9: Create SPIRE server ConfigMap

**Status**: `[x]` Completed

**File**: `deploy/spire/server/configmap.yaml`

---

### Task 10: Create SPIRE server StatefulSet

**Status**: `[x]` Completed

**File**: `deploy/spire/server/statefulset.yaml`

---

### Task 11: Create SPIRE server Service

**Status**: `[x]` Completed

**File**: `deploy/spire/server/service.yaml`

---

### Task 12: Create SPIRE server kustomization

**Status**: `[x]` Completed

**File**: `deploy/spire/server/kustomization.yaml`

---

### Task 13: Create SPIRE Server deployment script

**Status**: `[x]` Completed

**File**: `scripts/02-deploy-spire-server.sh`

---

### Task 14: Verify SPIRE server deployment

**Status**: `[x]` Completed

**Update**: `scripts/02-deploy-spire-server.sh` (verification embedded)

---

### Group 3: SPIRE Agent (Tasks 15-23) - ALL COMPLETED ✅

### Task 15: Create SPIRE agent ServiceAccount

**Status**: `[x]` Completed

**File**: `deploy/spire/agent/serviceaccount.yaml`

---

### Task 16: Create SPIRE agent ClusterRole

**Status**: `[x]` Completed

**File**: `deploy/spire/agent/clusterrole.yaml`

---

### Task 17: Create SPIRE agent ClusterRoleBinding

**Status**: `[x]` Completed

**File**: `deploy/spire/agent/clusterrolebinding.yaml`

---

### Task 18: Create SPIRE agent ConfigMap

**Status**: `[x]` Completed

**File**: `deploy/spire/agent/configmap.yaml`

---

### Task 19: Create SPIRE agent DaemonSet

**Status**: `[x]` Completed

**File**: `deploy/spire/agent/daemonset.yaml`

---

### Task 20: Create SPIRE agent kustomization

**Status**: `[x]` Completed

**File**: `deploy/spire/agent/kustomization.yaml`

---

### Task 21: Create SPIRE Agent deployment script

**Status**: `[x]` Completed

**File**: `scripts/03-deploy-spire-agent.sh`

---

### Task 22: Verify SPIRE agent deployment

**Status**: `[x]` Completed

**Update**: `scripts/03-deploy-spire-agent.sh` (verification embedded)

---

### Task 23: Create SPIRE root kustomization

**Status**: `[x]` Completed

**File**: `deploy/spire/kustomization.yaml`

---

## Phase 3: User Story 1 - Happy Path Demo (Priority: P1) 🎯 MVP

**Goal**: Deploy complete system demonstrating successful mTLS-secured communication through BOTH SPIFFE integration patterns

**Independent Test**: Deploy system, open UI at http://localhost:8080, click "Run Demo", verify both connections succeed

---

### Group 4: PostgreSQL Stack (Pattern 2: spiffe-helper) - NEEDS CORRECTION ⚠️

**CRITICAL**: PostgreSQL uses **spiffe-helper sidecar** (NOT Envoy) for true end-to-end mTLS

---

### Task 24: Create PostgreSQL ServiceAccount

**Status**: `[x]` Completed ✅

**Goal**: Create ServiceAccount for PostgreSQL.

**File**: `deploy/apps/postgres/serviceaccount.yaml`

**Acceptance Criteria**:
- [x] ServiceAccount named `postgres`
- [x] In namespace `demo`

---

### Task 25: Create PostgreSQL init ConfigMap

**Status**: `[x]` Completed ✅

**Goal**: Create ConfigMap with database initialization SQL.

**File**: `deploy/apps/postgres/init-configmap.yaml`

**Acceptance Criteria**:
- [x] ConfigMap named `postgres-init`
- [x] Contains `init.sql` with orders table schema
- [x] Includes seed data (5 demo orders)

---

### Task 26: ROLLBACK - Remove PostgreSQL Envoy ConfigMap

**Status**: `[x]` **COMPLETED** ✅

**Goal**: REMOVE the incorrectly implemented Envoy ConfigMap for PostgreSQL.

**File DELETED**: `deploy/apps/postgres/envoy-configmap.yaml`

**Why**: PostgreSQL should use spiffe-helper (Pattern 2), not Envoy (Pattern 1)

**Execution Log**:
```
Date: 2025-12-19
Command: rm deploy/apps/postgres/envoy-configmap.yaml
Result: ✓ File deleted successfully
```

---

### Task 27: ROLLBACK - Remove PostgreSQL StatefulSet with Envoy

**Status**: `[x]` **COMPLETED** ✅

**Goal**: REMOVE the incorrectly implemented StatefulSet with Envoy sidecar.

**File DELETED**: `deploy/apps/postgres/statefulset.yaml`

**Why**: Replaced with corrected version using spiffe-helper sidecar (Task 30)

**Execution Log**:
```
Date: 2025-12-19
Command: rm deploy/apps/postgres/statefulset.yaml
Result: ✓ File deleted successfully
```

---

### Task 28: Create PostgreSQL spiffe-helper ConfigMap (CORRECTED)

**Status**: `[x]` **COMPLETED** ✅

**Goal**: Create ConfigMap with spiffe-helper configuration for PostgreSQL.

**File**: `deploy/apps/postgres/spiffe-helper-configmap.yaml`

**Acceptance Criteria**:
- [x] ConfigMap named `postgres-spiffe-helper-config`
- [x] Contains spiffe-helper.conf with SPIRE Workload API socket path
- [x] Configures certificate output paths for PostgreSQL SSL
- [x] Certificate file names: svid.pem, svid_key.pem, svid_bundle.pem
- [x] Includes educational comments explaining configuration

**Execution Log**:
```
Date: 2025-12-19
File Created: deploy/apps/postgres/spiffe-helper-configmap.yaml
Verification: kubectl apply --dry-run=client -o yaml
Result: ✓ Valid YAML, ConfigMap created successfully

Initial Configuration (deprecated syntax):
  - agentAddress: /run/spire/agent-sockets/spire-agent.sock
  - certDir: /spiffe-certs
  - svidFileName, svidKeyFileName, svidBundleFileName

Updated Configuration (snake_case + permissions):
  - agent_address = "/run/spire/agent-sockets/spire-agent.sock"
  - cert_dir = "/spiffe-certs"
  - svid_file_name = "svid.pem"
  - svid_key_file_name = "svid_key.pem"
  - svid_bundle_file_name = "svid_bundle.pem"
  - cert_file_mode = 0644
  - key_file_mode = 0600  # CRITICAL for PostgreSQL SSL

Fix Applied: Added key_file_mode = 0600 to resolve PostgreSQL
"Permission denied" error for private key file.
```

---

### Task 29: Create PostgreSQL SSL ConfigMap (NEW)

**Status**: `[x]` **COMPLETED** ✅

**Goal**: Create ConfigMap with PostgreSQL SSL configuration for client certificate authentication.

**File**: `deploy/apps/postgres/ssl-configmap.yaml`

**Acceptance Criteria**:
- [x] ConfigMap named `postgres-ssl-config`
- [x] Contains postgresql.conf snippet enabling SSL (ssl-settings.conf)
- [x] Contains pg_hba.conf requiring client certificates (hostssl + clientcert=verify-ca)
- [x] Configures ssl_cert_file, ssl_key_file, ssl_ca_file paths matching spiffe-helper output
- [x] Includes educational comments for demo purposes

**Execution Log**:
```
Date: 2025-12-19
File Created: deploy/apps/postgres/ssl-configmap.yaml
Verification: kubectl apply --dry-run=client
Result: ✓ configmap/postgres-ssl-config created (dry run)
Contents:
  - ssl-settings.conf: SSL configuration (ssl=on, cert paths to /spiffe-certs)
  - pg_hba.conf: Client cert auth rules (hostssl with clientcert=verify-ca)
SSL Configuration:
  - ssl_cert_file = /spiffe-certs/svid.pem
  - ssl_key_file = /spiffe-certs/svid_key.pem
  - ssl_ca_file = /spiffe-certs/svid_bundle.pem
  - ssl_min_protocol_version = TLSv1.2
```

---

### Task 30: Create PostgreSQL StatefulSet with spiffe-helper (CORRECTED)

**Status**: `[x]` **COMPLETED** ✅

**Goal**: Create StatefulSet for PostgreSQL with spiffe-helper sidecar (NOT Envoy).

**File**: `deploy/apps/postgres/statefulset.yaml`

**Acceptance Criteria**:
- [x] StatefulSet named `postgres`
- [x] Uses image `postgres:15`
- [x] Has **postgres** container on port 5432
- [x] Has **spiffe-helper** sidecar (ghcr.io/spiffe/spiffe-helper:0.8.0)
- [x] Has **wait-for-certs** init container (ensures certs exist before PostgreSQL starts)
- [x] Mounts init ConfigMap at `/docker-entrypoint-initdb.d`
- [x] Mounts spiffe-helper ConfigMap at `/etc/spiffe-helper`
- [x] Mounts SSL ConfigMap for pg_hba.conf
- [x] Mounts shared volume at `/spiffe-certs` (emptyDir with Memory medium)
- [x] Mounts SPIRE agent socket hostPath (read-only)
- [x] PostgreSQL configured with SSL via command-line args
- [x] spiffe-helper runs with `-config /etc/spiffe-helper/spiffe-helper.conf`

**Execution Log**:
```
Date: 2025-12-19
File Created: deploy/apps/postgres/statefulset.yaml
Verification: kubectl apply --dry-run=client
Result: ✓ statefulset.apps/postgres created (dry run)

Final Architecture (after fixes):
  - Native Sidecar: spiffe-helper (restartPolicy: Always) - K8s 1.28+ feature
    - Runs BEFORE init containers, keeps running alongside main containers
    - securityContext: runAsUser: 999, runAsGroup: 999 (postgres user)
  - InitContainer: wait-for-certs (busybox:1.36) - waits for certificates
  - Container: postgres (postgres:15) - database with SSL enabled

Key Fixes Applied:
  1. Changed from regular sidecar to native sidecar (restartPolicy: Always)
  2. Added securityContext to run spiffe-helper as postgres user (UID 999)
     This ensures certificate files are owned by postgres:postgres

Volumes:
  - spiffe-certs: emptyDir (Memory) - shared cert storage
  - spiffe-helper-config: ConfigMap - spiffe-helper.conf
  - ssl-config: ConfigMap - pg_hba.conf
  - init-sql: ConfigMap - database init
  - spire-agent-socket: hostPath - SPIRE agent

Live Test Results (2025-12-19):
  - Pod Status: 2/2 Running ✓
  - SSL Status: SHOW ssl; → on ✓
  - Certificate Permissions:
    - svid.pem: -rw-r--r-- postgres:postgres (0644) ✓
    - svid_key.pem: -rw------- postgres:postgres (0600) ✓
    - svid_bundle.pem: -rw-r--r-- postgres:postgres (0644) ✓
  - Database: SELECT COUNT(*) FROM orders; → 5 rows ✓
```

---

### Task 31: Create PostgreSQL Service

**Status**: `[x]` Completed ✅ (No changes needed - exposes port 5432)

**File**: `deploy/apps/postgres/service.yaml`

**Note**: Existing service is correct - exposes port 5432 directly (no Envoy port needed)

---

### Task 32: Update PostgreSQL kustomization

**Status**: `[x]` **COMPLETED** ✅

**Goal**: Update kustomization to reference corrected manifests.

**File**: `deploy/apps/postgres/kustomization.yaml`

**Acceptance Criteria**:
- [x] References serviceaccount.yaml
- [x] References init-configmap.yaml
- [x] References spiffe-helper-configmap.yaml (NEW)
- [x] References ssl-configmap.yaml (NEW)
- [x] References statefulset.yaml (corrected version)
- [x] References service.yaml
- [x] Does NOT reference envoy-configmap.yaml (removed)

**Execution Log**:
```
Date: 2025-12-19
File Updated: deploy/apps/postgres/kustomization.yaml
Verification: kubectl kustomize deploy/apps/postgres/
Result: ✓ Kustomization builds successfully
Resources Generated:
  - 1 ServiceAccount
  - 3 ConfigMaps (init, spiffe-helper, ssl)
  - 1 StatefulSet (with spiffe-helper sidecar)
  - 1 Service
```

---

### Task 33: Update apps deployment script (postgres section - CORRECTED)

**Status**: `[x]` **COMPLETED** ✅

**Goal**: Update script to deploy PostgreSQL with spiffe-helper verification (NOT Envoy).

**File**: `scripts/04-deploy-apps.sh`

**Acceptance Criteria**:
- [x] Applies PostgreSQL manifests via kustomize
- [x] Waits for postgres-0 pod to be ready (180s timeout for cert init)
- [x] Verifies both containers: postgres + spiffe-helper
- [x] Checks spiffe-helper is writing certificates to /spiffe-certs
- [x] Verifies PostgreSQL SSL configuration is active
- [x] Tests database connectivity and orders table

**Execution Log**:
```
Date: 2025-12-19
File Updated: scripts/04-deploy-apps.sh
Changes Made:
  - Changed "Envoy sidecar" → "spiffe-helper sidecar (Pattern 2)"
  - Replaced verify_postgres_envoy() → verify_postgres_spiffe_helper()
  - Added verify_postgres_ssl() function
  - Updated timeout from 120s to 180s (init container waits for certs)
  - Updated connection string port 5433 → 5432 (direct PostgreSQL, not Envoy)
Functions Implemented:
  - check_prerequisites(): Verify SPIRE server/agent running
  - deploy_postgres(): Apply kustomize and wait for ready
  - verify_postgres(): Check DB, table, and orders count
  - verify_postgres_spiffe_helper(): Check container and cert files
  - verify_postgres_ssl(): Check SSL status via SHOW ssl

Live Test Execution (2025-12-19):
  Steps Performed:
    1. ./scripts/cleanup.sh - Deleted existing cluster
    2. ./scripts/01-create-cluster.sh - Created kind cluster (K8s v1.34.0)
    3. ./scripts/02-deploy-spire-server.sh - SPIRE server deployed
    4. ./scripts/03-deploy-spire-agent.sh - SPIRE agent attested
    5. Manual: kubectl exec spire-server entry create (registered postgres SPIFFE ID)
    6. kubectl apply -k deploy/apps/postgres/ - PostgreSQL deployed

  Issues Encountered & Resolved:
    - Issue 1: "PermissionDenied: no identity issued"
      Cause: Parent ID mismatch in SPIRE registration
      Fix: Re-registered entry with correct agent SPIFFE ID

    - Issue 2: "could not load private key: Permission denied"
      Cause: spiffe-helper wrote files as root, PostgreSQL runs as postgres
      Fix: Added securityContext (runAsUser: 999) + key_file_mode = 0600

  Final Result: ✓ PostgreSQL 2/2 Running with SSL enabled
```

---

### Group 5: Backend Service (Both Patterns) - NOT STARTED

**CRITICAL**: Backend has TWO sidecars - Envoy (Pattern 1: inbound from frontend) + spiffe-helper (Pattern 2: outbound to PostgreSQL)

---

### Task 34: Create backend Order model

**Status**: `[ ]` NOT STARTED

**Goal**: Create Go models for Order entity.

**File**: `internal/backend/models.go`

**Acceptance Criteria**:
- [ ] Package named `backend`
- [ ] Order struct with ID, Description, Status, CreatedAt fields
- [ ] JSON tags on all fields
- [ ] Status constants defined (pending, processing, completed, failed)

**Verification Command**:
```bash
go build ./internal/backend/...
```

---

### Task 35: Create backend database package

**Status**: `[ ]` NOT STARTED

**Goal**: Create database connection logic with PostgreSQL client certificate authentication.

**File**: `internal/backend/db.go`

**Acceptance Criteria**:
- [ ] Function to create DB connection from env vars
- [ ] Reads client certificates from `/spiffe-certs` (written by spiffe-helper)
- [ ] Configures TLS with client cert authentication
- [ ] Function to list all orders
- [ ] Function to check database health
- [ ] Uses `lib/pq` driver with sslmode=require

**Connection String Example**:
```go
connStr := fmt.Sprintf(
  "host=%s port=%s user=%s password=%s dbname=%s sslmode=require sslcert=/spiffe-certs/svid.pem sslkey=/spiffe-certs/svid_key.pem sslrootcert=/spiffe-certs/svid_bundle.pem",
  dbHost, dbPort, dbUser, dbPass, dbName,
)
```

---

### Task 36: Create backend handlers package

**Status**: `[ ]` NOT STARTED

**Goal**: Create HTTP handlers for backend API.

**File**: `internal/backend/handlers.go`

**Acceptance Criteria**:
- [ ] Handler for GET /health
- [ ] Handler for GET /api/orders
- [ ] Handler for GET /api/demo
- [ ] Returns JSON responses per contracts/backend-api.yaml
- [ ] Includes error handling

---

### Task 37: Create backend main entry point

**Status**: `[ ]` NOT STARTED

**Goal**: Create main.go for backend service.

**File**: `cmd/backend/main.go`

**Acceptance Criteria**:
- [ ] Reads config from environment variables
- [ ] Initializes database connection with client cert auth
- [ ] Registers HTTP handlers
- [ ] Starts HTTP server on port 9090
- [ ] Graceful shutdown handling

---

### Task 38: Create backend Dockerfile

**Status**: `[ ]` NOT STARTED

**Goal**: Create multi-stage Dockerfile for backend.

**File**: `docker/backend.Dockerfile`

**Acceptance Criteria**:
- [ ] Uses golang:1.21-alpine as builder
- [ ] Uses alpine:3.19 as runtime
- [ ] Copies only binary to final image
- [ ] Sets non-root user
- [ ] Exposes port 9090

---

### Task 39: Create backend ServiceAccount

**Status**: `[ ]` NOT STARTED

**File**: `deploy/apps/backend/serviceaccount.yaml`

---

### Task 40: Create backend Envoy ConfigMap (Pattern 1)

**Status**: `[ ]` NOT STARTED

**Goal**: Create Envoy config for inbound mTLS from frontend with RBAC.

**File**: `deploy/apps/backend/envoy-configmap.yaml`

**Acceptance Criteria**:
- [ ] Inbound listener on port 8080 with mTLS
- [ ] RBAC filter allowing only frontend SPIFFE ID
- [ ] SDS config for backend SVID
- [ ] Proxies to localhost:9090 (backend app)
- [ ] Does NOT handle PostgreSQL connection (that's spiffe-helper's job)

---

### Task 41: Create backend spiffe-helper ConfigMap (Pattern 2)

**Status**: `[ ]` NOT STARTED

**Goal**: Create spiffe-helper config for PostgreSQL client certificates.

**File**: `deploy/apps/backend/spiffe-helper-configmap.yaml`

**Acceptance Criteria**:
- [ ] ConfigMap named `backend-spiffe-helper-config`
- [ ] Configures certificate output to `/spiffe-certs`
- [ ] Sets SPIFFE ID: `spiffe://example.org/ns/demo/sa/backend`
- [ ] Matches PostgreSQL spiffe-helper configuration format

---

### Task 42: Create backend Deployment (with BOTH sidecars)

**Status**: `[ ]` NOT STARTED

**Goal**: Create Deployment with backend + Envoy + spiffe-helper sidecars.

**File**: `deploy/apps/backend/deployment.yaml`

**Acceptance Criteria**:
- [ ] Deployment named `backend`
- [ ] **backend** container on port 9090
- [ ] **envoy** sidecar on port 8080 (Pattern 1: inbound from frontend)
- [ ] **spiffe-helper** sidecar (Pattern 2: writes certs for PostgreSQL)
- [ ] Shared volume `/spiffe-certs` for backend + spiffe-helper
- [ ] Mounts SPIRE agent socket
- [ ] Sets DB_HOST=postgres.demo.svc.cluster.local
- [ ] Sets DB_PORT=5432

**Container Structure**:
```yaml
containers:
- name: backend
  image: backend:latest
  ports:
  - containerPort: 9090
  volumeMounts:
  - name: spiffe-certs
    mountPath: /spiffe-certs
    readOnly: true
- name: envoy
  # ... Envoy sidecar for Pattern 1
- name: spiffe-helper
  # ... spiffe-helper sidecar for Pattern 2
```

---

### Task 43: Create backend Service

**Status**: `[ ]` NOT STARTED

**File**: `deploy/apps/backend/service.yaml`

**Acceptance Criteria**:
- [ ] Exposes port 8080 (Envoy mTLS port for frontend connections)

---

### Task 44: Create backend kustomization

**Status**: `[ ]` NOT STARTED

**File**: `deploy/apps/backend/kustomization.yaml`

---

### Task 45: Create backend Dockerfile

**Status**: `[ ]` NOT STARTED

**File**: `docker/backend.Dockerfile`

---

### Group 6: Frontend Service (Pattern 1: Envoy SDS) - NOT STARTED

**CRITICAL**: Frontend uses ONLY Envoy sidecar (no spiffe-helper needed)

---

### Task 46: Create frontend models

**Status**: `[ ]` NOT STARTED

**File**: `internal/frontend/models.go`

**Acceptance Criteria**:
- [ ] DemoResult struct
- [ ] ConnectionStatus struct
- [ ] Order struct (mirrors backend)
- [ ] JSON tags per contracts/frontend-api.yaml

---

### Task 47: Create frontend handlers

**Status**: `[ ]` NOT STARTED

**File**: `internal/frontend/handlers.go`

**Acceptance Criteria**:
- [ ] Handler for / (serves index.html)
- [ ] Handler for /static/* (serves assets)
- [ ] Handler for GET /api/demo (calls backend via Envoy)
- [ ] Handler for GET /api/health
- [ ] HTTP client calls http://127.0.0.1:8001 (local Envoy proxy)

---

### Task 48: Create frontend HTML UI

**Status**: `[ ]` NOT STARTED

**File**: `internal/frontend/static/index.html`

**Acceptance Criteria**:
- [ ] "Run Demo" button
- [ ] Status display for frontend-to-backend (Pattern 1)
- [ ] Status display for backend-to-database (Pattern 2)
- [ ] Orders list display

---

### Task 49: Create frontend CSS

**Status**: `[ ]` NOT STARTED

**File**: `internal/frontend/static/styles.css`

---

### Task 50: Create frontend JavaScript

**Status**: `[ ]` NOT STARTED

**File**: `internal/frontend/static/app.js`

**Acceptance Criteria**:
- [ ] Calls /api/demo endpoint
- [ ] Updates UI with connection status for BOTH patterns
- [ ] Displays orders on success

---

### Task 51: Create frontend main entry point

**Status**: `[ ]` NOT STARTED

**File**: `cmd/frontend/main.go`

**Acceptance Criteria**:
- [ ] Starts HTTP server on port 8080
- [ ] Serves static assets
- [ ] Proxies /api/demo to backend via Envoy

---

### Task 52: Create frontend Dockerfile

**Status**: `[ ]` NOT STARTED

**File**: `docker/frontend.Dockerfile`

---

### Task 53: Create frontend ServiceAccount

**Status**: `[ ]` NOT STARTED

**File**: `deploy/apps/frontend/serviceaccount.yaml`

---

### Task 54: Create frontend Envoy ConfigMap (Pattern 1)

**Status**: `[ ]` NOT STARTED

**Goal**: Create Envoy config for outbound mTLS to backend.

**File**: `deploy/apps/frontend/envoy-configmap.yaml`

**Acceptance Criteria**:
- [ ] Outbound listener on port 8001 for backend calls
- [ ] SDS config for frontend SVID
- [ ] Upstream mTLS to backend.demo.svc.cluster.local:8080
- [ ] Validates backend SPIFFE ID

---

### Task 55: Create frontend Deployment (with Envoy sidecar)

**Status**: `[ ]` NOT STARTED

**File**: `deploy/apps/frontend/deployment.yaml`

**Acceptance Criteria**:
- [ ] **frontend** container on port 8080
- [ ] **envoy** sidecar (Pattern 1 only - no spiffe-helper needed)
- [ ] Sets BACKEND_URL=http://127.0.0.1:8001

---

### Task 56: Create frontend Service

**Status**: `[ ]` NOT STARTED

**File**: `deploy/apps/frontend/service.yaml`

**Acceptance Criteria**:
- [ ] Type: NodePort
- [ ] Port 8080, NodePort 30080

---

### Task 57: Create frontend kustomization

**Status**: `[ ]` NOT STARTED

**File**: `deploy/apps/frontend/kustomization.yaml`

---

### Group 7: SPIRE Registration & Deployment Automation

### Task 58: Create SPIRE registration script

**Status**: `[ ]` NOT STARTED

**Goal**: Register all workload SPIFFE IDs.

**File**: `scripts/05-register-entries.sh`

**Acceptance Criteria**:
- [ ] Registers frontend: `spiffe://example.org/ns/demo/sa/frontend`
- [ ] Registers backend: `spiffe://example.org/ns/demo/sa/backend`
- [ ] Registers postgres: `spiffe://example.org/ns/demo/sa/postgres`
- [ ] Uses k8s:ns:demo + k8s:sa:{name} selectors
- [ ] Includes DNS SANs

---

### Task 59: Update apps deployment script (complete)

**Status**: `[ ]` NOT STARTED

**Goal**: Complete script to deploy all apps in order.

**File**: `scripts/04-deploy-apps.sh`

**Acceptance Criteria**:
- [ ] Deploys PostgreSQL (with spiffe-helper verification)
- [ ] Builds and deploys Backend (verifies both Envoy + spiffe-helper)
- [ ] Builds and deploys Frontend (verifies Envoy)
- [ ] Sequential deployment with readiness checks

---

### Task 60: Create demo-all wrapper script

**Status**: `[ ]` NOT STARTED

**File**: `scripts/demo-all.sh`

**Acceptance Criteria**:
- [ ] Runs 01-create-cluster.sh
- [ ] Runs 02-deploy-spire-server.sh
- [ ] Runs 03-deploy-spire-agent.sh
- [ ] Runs 04-deploy-apps.sh
- [ ] Runs 05-register-entries.sh
- [ ] Prints final URL: http://localhost:8080

---

### Task 61: End-to-end demo verification

**Status**: `[ ]` NOT STARTED

**Goal**: Add E2E test to demo-all script.

**Update**: `scripts/demo-all.sh`

**Acceptance Criteria**:
- [ ] Calls /api/demo endpoint
- [ ] Verifies frontend_to_backend.success (Pattern 1: Envoy SDS)
- [ ] Verifies backend_to_database.success (Pattern 2: spiffe-helper)
- [ ] Validates PostgreSQL logs show client certificate authentication
- [ ] Validates Envoy logs show SPIFFE ID validation

---

## Phase 4: User Story 2 - RBAC Policy Denial Demo (Priority: P2)

### Task 62: Document RBAC modification procedure

**Status**: `[ ]` NOT STARTED

**File**: Update `specs/001-spire-spiffe-demo/quickstart.md`

**Acceptance Criteria**:
- [ ] Documents how to modify backend Envoy RBAC to deny frontend
- [ ] Shows expected failure behavior
- [ ] Documents restoration procedure

---

### Task 63: Test RBAC denial scenario

**Status**: `[ ]` NOT STARTED

**Acceptance Criteria**:
- [ ] Modify backend-envoy-config to deny frontend SPIFFE ID
- [ ] Restart backend
- [ ] Verify frontend-to-backend shows FAILED
- [ ] Verify backend-to-database still shows SUCCESS (unaffected)

---

## Phase 5: User Story 3 - Certificate Rotation Demo (Priority: P3)

### Task 64: Verify SVID TTL configuration

**Status**: `[ ]` NOT STARTED

**Acceptance Criteria**:
- [ ] SPIRE Server ConfigMap has short TTL (10m for demo)
- [ ] Document rotation observation procedure

---

### Task 65: Create continuous request test script

**Status**: `[ ]` NOT STARTED

**File**: `scripts/test-rotation.sh`

**Acceptance Criteria**:
- [ ] Polls /api/demo every 5 seconds
- [ ] Logs timestamps and success/failure
- [ ] Runs continuously until interrupted

---

### Task 66: Test certificate rotation for both patterns

**Status**: `[ ]` NOT STARTED

**Acceptance Criteria**:
- [ ] Run continuous requests during rotation window
- [ ] Verify Pattern 1 (Envoy SDS): Check Envoy /certs endpoint for rotation
- [ ] Verify Pattern 2 (spiffe-helper): Check /spiffe-certs file timestamps
- [ ] Verify no request failures during rotation

---

## Phase 6: User Story 4 - One-Command Setup (Priority: P4)

### Task 67: Review demo-all.sh sequencing

**Status**: `[ ]` NOT STARTED

**Acceptance Criteria**:
- [ ] Verify correct order: 01→02→03→04→05
- [ ] Add prerequisite checks (Docker, kubectl, kind, Go)
- [ ] Add progress indicators

---

### Task 68: Document prerequisites and quick deploy

**Status**: `[ ]` NOT STARTED

**File**: `README.md`

**Acceptance Criteria**:
- [ ] Lists prerequisites
- [ ] Shows one-command deployment
- [ ] Links to quickstart.md

---

## Phase 7: Polish & Cross-Cutting Concerns

### Task 69: Update quickstart.md with troubleshooting

**Status**: `[ ]` NOT STARTED

**File**: `specs/001-spire-spiffe-demo/quickstart.md`

---

### Task 70: Add architecture diagram to README

**Status**: `[ ]` NOT STARTED

**Acceptance Criteria**:
- [ ] Diagram shows both SPIFFE integration patterns
- [ ] Labels Pattern 1 (Envoy SDS) and Pattern 2 (spiffe-helper)

---

### Task 71: Create ARCHITECTURE.md

**Status**: `[ ]` NOT STARTED

**File**: `ARCHITECTURE.md`

**Acceptance Criteria**:
- [ ] Documents Pattern 1 vs Pattern 2 design decisions
- [ ] Explains when to use each pattern

---

### Task 72: Add resource limits to all Deployments

**Status**: `[ ]` NOT STARTED

**Acceptance Criteria**:
- [ ] Laptop-friendly resource usage (< 8GB RAM total)

---

### Task 73: Add comments to all ConfigMaps

**Status**: `[ ]` NOT STARTED

**Acceptance Criteria**:
- [ ] Educational comments explaining configuration choices

---

### Task 74: Run full quickstart validation

**Status**: `[ ]` NOT STARTED

**Acceptance Criteria**:
- [ ] Clean cluster → full deployment → all scenarios working
- [ ] Verify documentation accuracy

---

## Summary

**Total Tasks**: 74
**Completed**: 33 (Tasks 1-33) ✅
**Not Started**: 41 (Tasks 34-74)

**Progress**: 45% complete (33/74 tasks)

**Critical Path**:
1. ✅ Setup + SPIRE Infrastructure (T1-T23) - DONE
2. ✅ PostgreSQL with spiffe-helper (T24-T33) - DONE (Pattern 2 corrected)
3. 🔲 Backend with dual sidecars (T34-T45)
4. 🔲 Frontend with Envoy (T46-T57)
5. 🔲 Registration & E2E (T58-T61)
6. 🔲 Demo scenarios (T62-T68)
7. 🔲 Polish (T69-T74)

**Next Actions**:
1. ✅ ~~Execute Task 26: Delete `deploy/apps/postgres/envoy-configmap.yaml`~~ DONE
2. ✅ ~~Execute Task 27: Delete `deploy/apps/postgres/statefulset.yaml`~~ DONE
3. ✅ ~~Execute Tasks 28-30: Create corrected PostgreSQL manifests with spiffe-helper~~ DONE
4. ✅ ~~Execute Task 32-33: Update kustomization and deployment script~~ DONE
5. 🔲 Continue with Backend implementation (Group 5: Tasks 34-45)
6. 🔲 Implement Frontend (Group 6: Tasks 46-57)

---

## Architecture Validation (Design Checklist)

> **Note**: The ✅ marks below indicate **design decisions** (what should be built), not completion status.
> See individual task statuses above for completion tracking.

### Pattern 1: Envoy SDS (Frontend ↔ Backend) - Tasks NOT YET STARTED
- 🔲 Frontend Envoy ConfigMap with SDS outbound cluster (T54)
- 🔲 Backend Envoy ConfigMap with SDS inbound listener + RBAC (T40)
- 🔲 Both mount SPIRE agent socket (T55, T42)

### Pattern 2: spiffe-helper (Backend → PostgreSQL) - PostgreSQL COMPLETED ✅
- ✅ PostgreSQL spiffe-helper ConfigMap (T28 - COMPLETED)
- 🔲 Backend spiffe-helper ConfigMap (T41 - not started)
- ✅ PostgreSQL StatefulSet with spiffe-helper sidecar (T30 - COMPLETED)
- 🔲 Backend Deployment with spiffe-helper sidecar (T42 - not started)
- ✅ PostgreSQL SSL client certificate authentication (T29-T30 - COMPLETED)
- 🔲 Backend db.go reads client certificates from /spiffe-certs (T35 - not started)

### Critical Differences from Old Architecture
- ✅ **REMOVED**: Tasks 26-27 (PostgreSQL Envoy files deleted) - DONE
- ✅ **ADDED**: Tasks 28-30 (PostgreSQL spiffe-helper implementation) - DONE
- 🔲 **TO BE ADDED**: Task 41 (Backend spiffe-helper ConfigMap)
- ✅ **CORRECTED**: Task 33 (Script verifies spiffe-helper, not Envoy) - DONE
