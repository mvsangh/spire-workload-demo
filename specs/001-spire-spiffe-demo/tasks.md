# Implementation Tasks: SPIRE/SPIFFE Demo

**Branch**: `001-spire-spiffe-demo`
**Generated**: 2025-12-19
**Total Tasks**: 58
**Estimated Phases**: 6 groups with strict dependency ordering

---

## Task Legend

| Status | Meaning |
|--------|---------|
| `[ ]` | Not started |
| `[~]` | In progress |
| `[x]` | Completed |
| `[!]` | Blocked |
| `[-]` | Skipped |

---

## Group 1: Infrastructure Foundation (Tasks 1-5)

These tasks have no dependencies and establish the base infrastructure.

---

### Task 1: Create kind cluster configuration file

**Goal**: Create the kind cluster config YAML for SPIRE demo.

**Dependencies**: None

**File**: `deploy/kind/cluster-config.yaml`

**Acceptance Criteria**:
- [x] File exists at specified path
- [x] Contains single control-plane node
- [x] Has extraPortMappings for port 30080 → 8080
- [x] Valid YAML syntax

**Verification Command**:
```bash
cat deploy/kind/cluster-config.yaml && kind create cluster --config deploy/kind/cluster-config.yaml --dry-run
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[x]` Completed |
| **Commands Run** | `mkdir -p deploy/kind`, Write cluster-config.yaml, YAML validation via Python |
| **Files Changed** | `deploy/kind/cluster-config.yaml` (created) |
| **Issues Encountered** | None |
| **Notes** | Config includes extraPortMappings 30080→8080 and node labels for SPIRE agent |

---

### Task 2: Create cluster setup script

**Goal**: Create shell script to create kind cluster.

**Dependencies**: Task 1

**File**: `scripts/01-create-cluster.sh`

**Acceptance Criteria**:
- [x] Script is executable
- [x] Uses cluster-config.yaml from deploy/kind/
- [x] Includes error handling (set -e)
- [x] Prints status messages

**Verification Command**:
```bash
chmod +x scripts/01-create-cluster.sh && head -20 scripts/01-create-cluster.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[x]` Completed |
| **Commands Run** | Write script, `chmod +x`, `bash -n` syntax check |
| **Files Changed** | `scripts/01-create-cluster.sh` (created) |
| **Issues Encountered** | None |
| **Notes** | Script includes prerequisite checks, existing cluster handling, and verification steps |

---

### Task 3: Create namespaces manifest

**Goal**: Create Kubernetes namespace definitions for spire-system and demo.

**Dependencies**: None

**File**: `deploy/namespaces.yaml`

**Acceptance Criteria**:
- [x] Defines namespace `spire-system`
- [x] Defines namespace `demo`
- [x] Valid YAML syntax

**Verification Command**:
```bash
kubectl apply -f deploy/namespaces.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[x]` Completed |
| **Commands Run** | Write namespaces.yaml, `kubectl apply --dry-run=client --validate=false` |
| **Files Changed** | `deploy/namespaces.yaml` (created) |
| **Issues Encountered** | None |
| **Notes** | Both namespaces include app.kubernetes.io labels for identification |

---

### Task 4: Create Go module initialization

**Goal**: Initialize Go module for the project.

**Dependencies**: None

**Files**: `go.mod`, `go.sum`

**Acceptance Criteria**:
- [x] go.mod exists with module path
- [x] Go version is 1.21+
- [x] Module name follows convention (e.g., `github.com/example/spire-workload-demo`)

**Verification Command**:
```bash
cat go.mod && go mod verify
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[x]` Completed |
| **Commands Run** | `go mod init github.com/example/spire-workload-demo`, `go mod verify` |
| **Files Changed** | `go.mod` (created) |
| **Issues Encountered** | None |
| **Notes** | Using Go 1.25.5 (latest installed version) |

---

### Task 5: Create cleanup script

**Goal**: Create script to tear down the entire demo environment.

**Dependencies**: None

**File**: `scripts/cleanup.sh`

**Acceptance Criteria**:
- [x] Script is executable
- [x] Deletes kind cluster named `spire-demo`
- [x] Handles case where cluster doesn't exist
- [x] Prints confirmation message

**Verification Command**:
```bash
chmod +x scripts/cleanup.sh && bash -n scripts/cleanup.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[x]` Completed |
| **Commands Run** | Write script, `chmod +x`, `bash -n` syntax check |
| **Files Changed** | `scripts/cleanup.sh` (created) |
| **Issues Encountered** | None |
| **Notes** | Script includes optional Docker image cleanup with user prompt |

---

## Group 2: SPIRE Server (Tasks 6-14)

SPIRE server must be fully deployed before agent or workloads.

---

### Task 6: Create SPIRE server ServiceAccount

**Goal**: Create ServiceAccount for SPIRE server.

**Dependencies**: Task 3 (namespaces)

**File**: `deploy/spire/server/serviceaccount.yaml`

**Acceptance Criteria**:
- [ ] ServiceAccount named `spire-server`
- [ ] In namespace `spire-system`

**Verification Command**:
```bash
kubectl apply -f deploy/spire/server/serviceaccount.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 7: Create SPIRE server ClusterRole

**Goal**: Create ClusterRole with permissions for SPIRE server.

**Dependencies**: None

**File**: `deploy/spire/server/clusterrole.yaml`

**Acceptance Criteria**:
- [ ] ClusterRole named `spire-server-cluster-role`
- [ ] Includes `nodes` get/list permissions
- [ ] Includes `tokenreviews` create permission

**Verification Command**:
```bash
kubectl apply -f deploy/spire/server/clusterrole.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 8: Create SPIRE server ClusterRoleBinding

**Goal**: Bind ClusterRole to SPIRE server ServiceAccount.

**Dependencies**: Task 6, Task 7

**File**: `deploy/spire/server/clusterrolebinding.yaml`

**Acceptance Criteria**:
- [ ] Binds `spire-server-cluster-role` to `spire-server` SA
- [ ] References correct namespace `spire-system`

**Verification Command**:
```bash
kubectl apply -f deploy/spire/server/clusterrolebinding.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 9: Create SPIRE server ConfigMap

**Goal**: Create ConfigMap with SPIRE server configuration (server.conf).

**Dependencies**: Task 3 (namespaces)

**File**: `deploy/spire/server/configmap.yaml`

**Acceptance Criteria**:
- [ ] ConfigMap named `spire-server-config`
- [ ] Contains `server.conf` with trust_domain `example.org`
- [ ] Uses SQLite datastore
- [ ] Configures k8s_psat node attestor
- [ ] Sets log_level to DEBUG

**Verification Command**:
```bash
kubectl apply -f deploy/spire/server/configmap.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 10: Create SPIRE server StatefulSet

**Goal**: Create StatefulSet for SPIRE server deployment.

**Dependencies**: Task 6, Task 9

**File**: `deploy/spire/server/statefulset.yaml`

**Acceptance Criteria**:
- [ ] StatefulSet named `spire-server`
- [ ] Uses image `ghcr.io/spiffe/spire-server:1.9.6`
- [ ] Mounts ConfigMap at `/run/spire/config`
- [ ] Has liveness and readiness probes
- [ ] Includes PVC for data persistence

**Verification Command**:
```bash
kubectl apply -f deploy/spire/server/statefulset.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 11: Create SPIRE server Service

**Goal**: Create ClusterIP Service for SPIRE server.

**Dependencies**: Task 10

**File**: `deploy/spire/server/service.yaml`

**Acceptance Criteria**:
- [ ] Service named `spire-server`
- [ ] Type ClusterIP
- [ ] Exposes port 8081 (gRPC)
- [ ] Selector matches `app: spire-server`

**Verification Command**:
```bash
kubectl apply -f deploy/spire/server/service.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 12: Create SPIRE server kustomization

**Goal**: Create kustomization.yaml to bundle all SPIRE server resources.

**Dependencies**: Tasks 6-11

**File**: `deploy/spire/server/kustomization.yaml`

**Acceptance Criteria**:
- [ ] Lists all server YAML files as resources
- [ ] Valid kustomization syntax

**Verification Command**:
```bash
kubectl kustomize deploy/spire/server/
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 13: Create SPIRE deployment script (server portion)

**Goal**: Create script section to deploy SPIRE server.

**Dependencies**: Tasks 6-12

**File**: `scripts/02-deploy-spire.sh` (server section)

**Acceptance Criteria**:
- [ ] Script is executable
- [ ] Applies namespaces first
- [ ] Applies SPIRE server manifests
- [ ] Waits for spire-server-0 to be ready
- [ ] Includes timeout (120s)

**Verification Command**:
```bash
chmod +x scripts/02-deploy-spire.sh && bash -n scripts/02-deploy-spire.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 14: Verify SPIRE server deployment

**Goal**: Add verification commands to deployment script.

**Dependencies**: Task 13

**Update**: `scripts/02-deploy-spire.sh`

**Acceptance Criteria**:
- [ ] Script verifies pod is Running
- [ ] Script runs `spire-server healthcheck` command
- [ ] Fails with clear error if unhealthy

**Verification Command**:
```bash
grep -A5 "healthcheck" scripts/02-deploy-spire.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

## Group 3: SPIRE Agent (Tasks 15-23)

SPIRE agent depends on server being available.

---

### Task 15: Create SPIRE agent ServiceAccount

**Goal**: Create ServiceAccount for SPIRE agent.

**Dependencies**: Task 3 (namespaces)

**File**: `deploy/spire/agent/serviceaccount.yaml`

**Acceptance Criteria**:
- [ ] ServiceAccount named `spire-agent`
- [ ] In namespace `spire-system`

**Verification Command**:
```bash
kubectl apply -f deploy/spire/agent/serviceaccount.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 16: Create SPIRE agent ClusterRole

**Goal**: Create ClusterRole with permissions for SPIRE agent.

**Dependencies**: None

**File**: `deploy/spire/agent/clusterrole.yaml`

**Acceptance Criteria**:
- [ ] ClusterRole named `spire-agent-cluster-role`
- [ ] Includes `pods` and `nodes` get/list permissions

**Verification Command**:
```bash
kubectl apply -f deploy/spire/agent/clusterrole.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 17: Create SPIRE agent ClusterRoleBinding

**Goal**: Bind ClusterRole to SPIRE agent ServiceAccount.

**Dependencies**: Task 15, Task 16

**File**: `deploy/spire/agent/clusterrolebinding.yaml`

**Acceptance Criteria**:
- [ ] Binds `spire-agent-cluster-role` to `spire-agent` SA
- [ ] References correct namespace `spire-system`

**Verification Command**:
```bash
kubectl apply -f deploy/spire/agent/clusterrolebinding.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 18: Create SPIRE agent ConfigMap

**Goal**: Create ConfigMap with SPIRE agent configuration (agent.conf).

**Dependencies**: Task 3 (namespaces)

**File**: `deploy/spire/agent/configmap.yaml`

**Acceptance Criteria**:
- [ ] ConfigMap named `spire-agent-config`
- [ ] Contains `agent.conf` with trust_domain `example.org`
- [ ] Socket path is `/run/spire/agent-sockets/spire-agent.sock`
- [ ] Server address is `spire-server:8081`
- [ ] Configures k8s_psat node attestor
- [ ] Configures k8s workload attestor

**Verification Command**:
```bash
kubectl apply -f deploy/spire/agent/configmap.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 19: Create SPIRE agent DaemonSet

**Goal**: Create DaemonSet for SPIRE agent deployment.

**Dependencies**: Task 15, Task 18

**File**: `deploy/spire/agent/daemonset.yaml`

**Acceptance Criteria**:
- [ ] DaemonSet named `spire-agent`
- [ ] Uses image `ghcr.io/spiffe/spire-agent:1.9.6`
- [ ] Has `hostPID: true` and `hostNetwork: true`
- [ ] Mounts ConfigMap at `/run/spire/config`
- [ ] Mounts hostPath `/run/spire/agent-sockets` for Workload API
- [ ] Mounts projected ServiceAccountToken
- [ ] Mounts `/sys/fs/cgroup` and `/proc` for workload attestation
- [ ] Has init container to create socket directory
- [ ] Has liveness and readiness probes

**Verification Command**:
```bash
kubectl apply -f deploy/spire/agent/daemonset.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 20: Create SPIRE agent kustomization

**Goal**: Create kustomization.yaml to bundle all SPIRE agent resources.

**Dependencies**: Tasks 15-19

**File**: `deploy/spire/agent/kustomization.yaml`

**Acceptance Criteria**:
- [ ] Lists all agent YAML files as resources
- [ ] Valid kustomization syntax

**Verification Command**:
```bash
kubectl kustomize deploy/spire/agent/
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 21: Update SPIRE deployment script (agent portion)

**Goal**: Add SPIRE agent deployment to script.

**Dependencies**: Task 14, Tasks 15-20

**Update**: `scripts/02-deploy-spire.sh`

**Acceptance Criteria**:
- [ ] Applies SPIRE agent manifests after server is ready
- [ ] Waits for agent pod to be ready
- [ ] Includes timeout (120s)

**Verification Command**:
```bash
grep -A10 "agent" scripts/02-deploy-spire.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 22: Verify SPIRE agent deployment

**Goal**: Add agent verification to deployment script.

**Dependencies**: Task 21

**Update**: `scripts/02-deploy-spire.sh`

**Acceptance Criteria**:
- [ ] Script verifies agent pod is Running
- [ ] Script runs `spire-agent healthcheck` command
- [ ] Verifies socket file exists at expected path

**Verification Command**:
```bash
grep -A5 "agent.*healthcheck" scripts/02-deploy-spire.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 23: Create SPIRE root kustomization

**Goal**: Create root kustomization for entire SPIRE deployment.

**Dependencies**: Task 12, Task 20

**File**: `deploy/spire/kustomization.yaml`

**Acceptance Criteria**:
- [ ] References `server/` and `agent/` as bases
- [ ] Valid kustomization syntax

**Verification Command**:
```bash
kubectl kustomize deploy/spire/
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

## Group 4: PostgreSQL Stack (Tasks 24-32)

PostgreSQL must be deployed before backend can connect.

---

### Task 24: Create PostgreSQL ServiceAccount

**Goal**: Create ServiceAccount for PostgreSQL.

**Dependencies**: Task 3 (namespaces)

**File**: `deploy/apps/postgres/serviceaccount.yaml`

**Acceptance Criteria**:
- [ ] ServiceAccount named `postgres`
- [ ] In namespace `demo`

**Verification Command**:
```bash
kubectl apply -f deploy/apps/postgres/serviceaccount.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 25: Create PostgreSQL init ConfigMap

**Goal**: Create ConfigMap with database initialization SQL.

**Dependencies**: Task 3 (namespaces)

**File**: `deploy/apps/postgres/init-configmap.yaml`

**Acceptance Criteria**:
- [ ] ConfigMap named `postgres-init`
- [ ] Contains `init.sql` with orders table schema
- [ ] Includes seed data (5 demo orders)

**Verification Command**:
```bash
kubectl apply -f deploy/apps/postgres/init-configmap.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 26: Create PostgreSQL Envoy ConfigMap

**Goal**: Create ConfigMap with Envoy sidecar config for PostgreSQL.

**Dependencies**: Task 3 (namespaces)

**File**: `deploy/apps/postgres/envoy-configmap.yaml`

**Acceptance Criteria**:
- [ ] ConfigMap named `postgres-envoy-config`
- [ ] Contains `envoy.yaml` with inbound TCP listener on port 5433
- [ ] Configures SDS for SPIFFE ID `spiffe://example.org/ns/demo/sa/postgres`
- [ ] Validates backend SPIFFE ID for client auth
- [ ] Proxies to localhost:5432

**Verification Command**:
```bash
kubectl apply -f deploy/apps/postgres/envoy-configmap.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 27: Create PostgreSQL StatefulSet

**Goal**: Create StatefulSet for PostgreSQL with Envoy sidecar.

**Dependencies**: Task 24, Task 25, Task 26

**File**: `deploy/apps/postgres/statefulset.yaml`

**Acceptance Criteria**:
- [ ] StatefulSet named `postgres`
- [ ] Uses image `postgres:15`
- [ ] Has postgres container on port 5432
- [ ] Has envoy sidecar on port 5433
- [ ] Mounts init ConfigMap at `/docker-entrypoint-initdb.d`
- [ ] Mounts envoy ConfigMap at `/etc/envoy`
- [ ] Mounts SPIRE agent socket hostPath
- [ ] Sets POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD env vars

**Verification Command**:
```bash
kubectl apply -f deploy/apps/postgres/statefulset.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 28: Create PostgreSQL Service

**Goal**: Create headless Service for PostgreSQL.

**Dependencies**: Task 27

**File**: `deploy/apps/postgres/service.yaml`

**Acceptance Criteria**:
- [ ] Service named `postgres`
- [ ] ClusterIP: None (headless)
- [ ] Exposes port 5433 (Envoy mTLS port)
- [ ] Selector matches `app: postgres`

**Verification Command**:
```bash
kubectl apply -f deploy/apps/postgres/service.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 29: Create PostgreSQL kustomization

**Goal**: Create kustomization.yaml to bundle PostgreSQL resources.

**Dependencies**: Tasks 24-28

**File**: `deploy/apps/postgres/kustomization.yaml`

**Acceptance Criteria**:
- [ ] Lists all postgres YAML files as resources
- [ ] Valid kustomization syntax

**Verification Command**:
```bash
kubectl kustomize deploy/apps/postgres/
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 30: Create apps deployment script (postgres section)

**Goal**: Create script to deploy demo applications starting with PostgreSQL.

**Dependencies**: Task 29

**File**: `scripts/03-deploy-apps.sh` (postgres section)

**Acceptance Criteria**:
- [ ] Script is executable
- [ ] Applies PostgreSQL manifests
- [ ] Waits for postgres-0 to be ready
- [ ] Includes timeout (120s)

**Verification Command**:
```bash
chmod +x scripts/03-deploy-apps.sh && bash -n scripts/03-deploy-apps.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 31: Verify PostgreSQL deployment

**Goal**: Add PostgreSQL verification to deployment script.

**Dependencies**: Task 30

**Update**: `scripts/03-deploy-apps.sh`

**Acceptance Criteria**:
- [ ] Verifies postgres pod is Running
- [ ] Runs `pg_isready` command in postgres container
- [ ] Verifies demo database exists

**Verification Command**:
```bash
grep -A5 "pg_isready" scripts/03-deploy-apps.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 32: Verify PostgreSQL Envoy sidecar

**Goal**: Add Envoy sidecar verification for PostgreSQL.

**Dependencies**: Task 31

**Update**: `scripts/03-deploy-apps.sh`

**Acceptance Criteria**:
- [ ] Verifies envoy container is running
- [ ] Checks envoy admin endpoint responds
- [ ] Verifies SDS cluster is connected

**Verification Command**:
```bash
grep -A5 "envoy" scripts/03-deploy-apps.sh | grep -i "admin\|cluster"
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

## Group 5: Backend Service (Tasks 33-44)

Backend must be deployed before frontend can call it.

---

### Task 33: Create backend models package

**Goal**: Create Go models for Order entity.

**Dependencies**: Task 4 (go.mod)

**File**: `internal/backend/models.go`

**Acceptance Criteria**:
- [ ] Package named `backend`
- [ ] Order struct with ID, Description, Status, CreatedAt fields
- [ ] JSON tags on all fields
- [ ] Status constants defined

**Verification Command**:
```bash
go build ./internal/backend/...
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 34: Create backend database package

**Goal**: Create database connection and query logic.

**Dependencies**: Task 33

**File**: `internal/backend/db.go`

**Acceptance Criteria**:
- [ ] Function to create DB connection from env vars
- [ ] Function to list all orders
- [ ] Function to check database health
- [ ] Uses `lib/pq` driver

**Verification Command**:
```bash
go build ./internal/backend/...
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 35: Create backend handlers package

**Goal**: Create HTTP handlers for backend API.

**Dependencies**: Task 34

**File**: `internal/backend/handlers.go`

**Acceptance Criteria**:
- [ ] Handler for GET /health
- [ ] Handler for GET /api/orders
- [ ] Handler for GET /api/demo
- [ ] Returns JSON responses
- [ ] Includes error handling

**Verification Command**:
```bash
go build ./internal/backend/...
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 36: Create backend main entry point

**Goal**: Create main.go for backend service.

**Dependencies**: Task 35

**File**: `cmd/backend/main.go`

**Acceptance Criteria**:
- [ ] Reads config from environment variables
- [ ] Initializes database connection
- [ ] Registers HTTP handlers
- [ ] Starts HTTP server on configurable port (default 9090)
- [ ] Graceful shutdown handling

**Verification Command**:
```bash
go build -o /dev/null ./cmd/backend/...
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 37: Create backend Dockerfile

**Goal**: Create multi-stage Dockerfile for backend.

**Dependencies**: Task 36

**File**: `docker/backend.Dockerfile`

**Acceptance Criteria**:
- [ ] Uses golang:1.21-alpine as builder
- [ ] Uses alpine:3.19 as runtime
- [ ] Copies only binary to final image
- [ ] Sets non-root user
- [ ] Exposes port 9090

**Verification Command**:
```bash
docker build -f docker/backend.Dockerfile -t backend:test . --dry-run 2>/dev/null || cat docker/backend.Dockerfile
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 38: Create backend ServiceAccount

**Goal**: Create ServiceAccount for backend workload.

**Dependencies**: Task 3 (namespaces)

**File**: `deploy/apps/backend/serviceaccount.yaml`

**Acceptance Criteria**:
- [ ] ServiceAccount named `backend`
- [ ] In namespace `demo`

**Verification Command**:
```bash
kubectl apply -f deploy/apps/backend/serviceaccount.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 39: Create backend Envoy ConfigMap

**Goal**: Create ConfigMap with Envoy sidecar config for backend.

**Dependencies**: Task 3 (namespaces)

**File**: `deploy/apps/backend/envoy-configmap.yaml`

**Acceptance Criteria**:
- [ ] ConfigMap named `backend-envoy-config`
- [ ] Inbound listener on port 8080 with mTLS
- [ ] RBAC filter allowing only frontend SPIFFE ID
- [ ] Outbound listener on port 5432 for PostgreSQL
- [ ] SDS config for `spiffe://example.org/ns/demo/sa/backend`
- [ ] Upstream mTLS to PostgreSQL Envoy

**Verification Command**:
```bash
kubectl apply -f deploy/apps/backend/envoy-configmap.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 40: Create backend Deployment

**Goal**: Create Deployment for backend with Envoy sidecar.

**Dependencies**: Task 37, Task 38, Task 39

**File**: `deploy/apps/backend/deployment.yaml`

**Acceptance Criteria**:
- [ ] Deployment named `backend`
- [ ] Uses locally built backend image
- [ ] Has backend container on port 9090
- [ ] Has envoy sidecar on port 8080
- [ ] Mounts envoy ConfigMap
- [ ] Mounts SPIRE agent socket hostPath
- [ ] Sets DB_HOST=127.0.0.1 (via Envoy)
- [ ] Sets DB_PORT=5432

**Verification Command**:
```bash
kubectl apply -f deploy/apps/backend/deployment.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 41: Create backend Service

**Goal**: Create Service for backend.

**Dependencies**: Task 40

**File**: `deploy/apps/backend/service.yaml`

**Acceptance Criteria**:
- [ ] Service named `backend`
- [ ] Type ClusterIP
- [ ] Exposes port 8080 (Envoy mTLS)
- [ ] Selector matches `app: backend`

**Verification Command**:
```bash
kubectl apply -f deploy/apps/backend/service.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 42: Create backend kustomization

**Goal**: Create kustomization.yaml to bundle backend resources.

**Dependencies**: Tasks 38-41

**File**: `deploy/apps/backend/kustomization.yaml`

**Acceptance Criteria**:
- [ ] Lists all backend YAML files as resources
- [ ] Valid kustomization syntax

**Verification Command**:
```bash
kubectl kustomize deploy/apps/backend/
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 43: Update apps deployment script (backend section)

**Goal**: Add backend deployment to script.

**Dependencies**: Task 31, Task 42

**Update**: `scripts/03-deploy-apps.sh`

**Acceptance Criteria**:
- [ ] Builds backend Docker image
- [ ] Loads image into kind cluster
- [ ] Applies backend manifests
- [ ] Waits for backend pod to be ready

**Verification Command**:
```bash
grep -A10 "backend" scripts/03-deploy-apps.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 44: Verify backend deployment

**Goal**: Add backend verification to deployment script.

**Dependencies**: Task 43

**Update**: `scripts/03-deploy-apps.sh`

**Acceptance Criteria**:
- [ ] Verifies backend pod is Running
- [ ] Checks envoy admin endpoint responds
- [ ] Verifies SVID is loaded (via envoy /certs)

**Verification Command**:
```bash
grep -A5 "backend.*verify" scripts/03-deploy-apps.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

## Group 6: Frontend Service (Tasks 45-56)

Frontend is the final workload in the chain.

---

### Task 45: Create frontend models package

**Goal**: Create Go models for frontend API responses.

**Dependencies**: Task 4 (go.mod)

**File**: `internal/frontend/models.go`

**Acceptance Criteria**:
- [ ] Package named `frontend`
- [ ] DemoResult struct
- [ ] ConnectionStatus struct
- [ ] Order struct (mirrors backend)
- [ ] JSON tags on all fields

**Verification Command**:
```bash
go build ./internal/frontend/...
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 46: Create frontend handlers package

**Goal**: Create HTTP handlers for frontend.

**Dependencies**: Task 45

**File**: `internal/frontend/handlers.go`

**Acceptance Criteria**:
- [ ] Handler to serve index.html at /
- [ ] Handler to serve static files at /static/
- [ ] Handler for GET /api/demo (calls backend)
- [ ] Handler for GET /api/health
- [ ] HTTP client for backend calls (via localhost Envoy)

**Verification Command**:
```bash
go build ./internal/frontend/...
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 47: Create frontend HTML template

**Goal**: Create main HTML page for demo UI.

**Dependencies**: None

**File**: `internal/frontend/static/index.html`

**Acceptance Criteria**:
- [ ] Clean, simple HTML structure
- [ ] "Run Demo" button
- [ ] Status display area for frontend-to-backend
- [ ] Status display area for backend-to-database
- [ ] Orders list display area
- [ ] Basic styling (inline or linked CSS)

**Verification Command**:
```bash
cat internal/frontend/static/index.html | head -30
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 48: Create frontend CSS styles

**Goal**: Create CSS for demo UI styling.

**Dependencies**: Task 47

**File**: `internal/frontend/static/styles.css`

**Acceptance Criteria**:
- [ ] Clean, readable layout
- [ ] Success state styling (green)
- [ ] Failure state styling (red)
- [ ] Loading state styling
- [ ] Responsive design (works on laptop)

**Verification Command**:
```bash
cat internal/frontend/static/styles.css
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 49: Create frontend JavaScript

**Goal**: Create JavaScript for demo interaction.

**Dependencies**: Task 47

**File**: `internal/frontend/static/app.js`

**Acceptance Criteria**:
- [ ] Function to call /api/demo endpoint
- [ ] Updates UI with success/failure status
- [ ] Displays orders list on success
- [ ] Shows error message on failure
- [ ] Loading indicator during request

**Verification Command**:
```bash
cat internal/frontend/static/app.js
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 50: Create frontend main entry point

**Goal**: Create main.go for frontend service.

**Dependencies**: Task 46

**File**: `cmd/frontend/main.go`

**Acceptance Criteria**:
- [ ] Reads config from environment variables
- [ ] Configures backend URL (default localhost:8001)
- [ ] Registers HTTP handlers
- [ ] Embeds static files using embed.FS
- [ ] Starts HTTP server on configurable port (default 8080)
- [ ] Graceful shutdown handling

**Verification Command**:
```bash
go build -o /dev/null ./cmd/frontend/...
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 51: Create frontend Dockerfile

**Goal**: Create multi-stage Dockerfile for frontend.

**Dependencies**: Task 50

**File**: `docker/frontend.Dockerfile`

**Acceptance Criteria**:
- [ ] Uses golang:1.21-alpine as builder
- [ ] Uses alpine:3.19 as runtime
- [ ] Copies only binary to final image
- [ ] Sets non-root user
- [ ] Exposes port 8080

**Verification Command**:
```bash
cat docker/frontend.Dockerfile
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 52: Create frontend ServiceAccount

**Goal**: Create ServiceAccount for frontend workload.

**Dependencies**: Task 3 (namespaces)

**File**: `deploy/apps/frontend/serviceaccount.yaml`

**Acceptance Criteria**:
- [ ] ServiceAccount named `frontend`
- [ ] In namespace `demo`

**Verification Command**:
```bash
kubectl apply -f deploy/apps/frontend/serviceaccount.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 53: Create frontend Envoy ConfigMap

**Goal**: Create ConfigMap with Envoy sidecar config for frontend.

**Dependencies**: Task 3 (namespaces)

**File**: `deploy/apps/frontend/envoy-configmap.yaml`

**Acceptance Criteria**:
- [ ] ConfigMap named `frontend-envoy-config`
- [ ] Outbound listener on port 8001 for backend calls
- [ ] SDS config for `spiffe://example.org/ns/demo/sa/frontend`
- [ ] Upstream mTLS to backend.demo.svc.cluster.local:8080
- [ ] Validates backend SPIFFE ID

**Verification Command**:
```bash
kubectl apply -f deploy/apps/frontend/envoy-configmap.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 54: Create frontend Deployment

**Goal**: Create Deployment for frontend with Envoy sidecar.

**Dependencies**: Task 51, Task 52, Task 53

**File**: `deploy/apps/frontend/deployment.yaml`

**Acceptance Criteria**:
- [ ] Deployment named `frontend`
- [ ] Uses locally built frontend image
- [ ] Has frontend container on port 8080
- [ ] Has envoy sidecar
- [ ] Mounts envoy ConfigMap
- [ ] Mounts SPIRE agent socket hostPath
- [ ] Sets BACKEND_URL=http://127.0.0.1:8001

**Verification Command**:
```bash
kubectl apply -f deploy/apps/frontend/deployment.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 55: Create frontend Service

**Goal**: Create NodePort Service for frontend.

**Dependencies**: Task 54

**File**: `deploy/apps/frontend/service.yaml`

**Acceptance Criteria**:
- [ ] Service named `frontend`
- [ ] Type NodePort
- [ ] Port 8080, NodePort 30080
- [ ] Selector matches `app: frontend`

**Verification Command**:
```bash
kubectl apply -f deploy/apps/frontend/service.yaml --dry-run=client
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 56: Create frontend kustomization

**Goal**: Create kustomization.yaml to bundle frontend resources.

**Dependencies**: Tasks 52-55

**File**: `deploy/apps/frontend/kustomization.yaml`

**Acceptance Criteria**:
- [ ] Lists all frontend YAML files as resources
- [ ] Valid kustomization syntax

**Verification Command**:
```bash
kubectl kustomize deploy/apps/frontend/
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

## Group 7: Registration & Final Scripts (Tasks 57-62)

SPIRE registration entries must be created after all workloads exist.

---

### Task 57: Update apps deployment script (frontend section)

**Goal**: Add frontend deployment to script.

**Dependencies**: Task 44, Task 56

**Update**: `scripts/03-deploy-apps.sh`

**Acceptance Criteria**:
- [ ] Builds frontend Docker image
- [ ] Loads image into kind cluster
- [ ] Applies frontend manifests
- [ ] Waits for frontend pod to be ready

**Verification Command**:
```bash
grep -A10 "frontend" scripts/03-deploy-apps.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 58: Create apps root kustomization

**Goal**: Create root kustomization for all demo apps.

**Dependencies**: Task 29, Task 42, Task 56

**File**: `deploy/apps/kustomization.yaml`

**Acceptance Criteria**:
- [ ] References `postgres/`, `backend/`, `frontend/` as bases
- [ ] Valid kustomization syntax

**Verification Command**:
```bash
kubectl kustomize deploy/apps/
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 59: Create SPIRE registration script

**Goal**: Create script to register all workload entries in SPIRE.

**Dependencies**: Task 22 (SPIRE agent running)

**File**: `scripts/04-register-entries.sh`

**Acceptance Criteria**:
- [ ] Script is executable
- [ ] Dynamically discovers node name for parent ID
- [ ] Registers frontend SPIFFE ID with k8s:ns:demo, k8s:sa:frontend selectors
- [ ] Registers backend SPIFFE ID with k8s:ns:demo, k8s:sa:backend selectors
- [ ] Registers postgres SPIFFE ID with k8s:ns:demo, k8s:sa:postgres selectors
- [ ] Includes DNS SANs for each entry
- [ ] Verifies entries were created

**Verification Command**:
```bash
chmod +x scripts/04-register-entries.sh && bash -n scripts/04-register-entries.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 60: Create demo-all wrapper script

**Goal**: Create one-command script to deploy entire demo.

**Dependencies**: Task 2, Task 14, Task 22, Task 57, Task 59

**File**: `scripts/demo-all.sh`

**Acceptance Criteria**:
- [ ] Script is executable
- [ ] Calls scripts in order: 01, 02, 03, 04
- [ ] Includes overall status checks between scripts
- [ ] Prints final access URL (http://localhost:8080)
- [ ] Handles failures gracefully with clear error messages

**Verification Command**:
```bash
chmod +x scripts/demo-all.sh && bash -n scripts/demo-all.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 61: Verify frontend deployment and access

**Goal**: Add final verification to demo-all script.

**Dependencies**: Task 60

**Update**: `scripts/demo-all.sh`

**Acceptance Criteria**:
- [ ] Verifies frontend pod is Running
- [ ] Verifies NodePort service is accessible
- [ ] Curls http://localhost:8080/api/health
- [ ] Prints success message with URL

**Verification Command**:
```bash
grep -A10 "localhost:8080" scripts/demo-all.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

### Task 62: End-to-end demo verification

**Goal**: Add E2E test to demo-all script.

**Dependencies**: Task 61

**Update**: `scripts/demo-all.sh`

**Acceptance Criteria**:
- [ ] Calls /api/demo endpoint
- [ ] Verifies frontend_to_backend.success is true
- [ ] Verifies backend_to_database.success is true
- [ ] Prints orders count
- [ ] Overall pass/fail status

**Verification Command**:
```bash
grep -A15 "api/demo" scripts/demo-all.sh
```

#### Execution Log

| Field | Value |
|-------|-------|
| **Status** | `[ ]` Not Started |
| **Commands Run** | |
| **Files Changed** | |
| **Issues Encountered** | |
| **Notes** | |

---

## Dependency Graph Summary

```
Group 1 (Foundation)
├── Task 1: kind config
├── Task 2: cluster script ──► Task 1
├── Task 3: namespaces
├── Task 4: go.mod
└── Task 5: cleanup script

Group 2 (SPIRE Server) ──► Task 3
├── Tasks 6-8: RBAC
├── Task 9: ConfigMap
├── Task 10: StatefulSet ──► Task 6, 9
├── Task 11: Service ──► Task 10
├── Task 12: kustomization ──► Tasks 6-11
├── Task 13: deploy script ──► Task 12
└── Task 14: verify ──► Task 13

Group 3 (SPIRE Agent) ──► Task 14
├── Tasks 15-17: RBAC
├── Task 18: ConfigMap
├── Task 19: DaemonSet ──► Task 15, 18
├── Task 20: kustomization ──► Tasks 15-19
├── Task 21: deploy script ──► Task 20
├── Task 22: verify ──► Task 21
└── Task 23: root kustomization ──► Task 12, 20

Group 4 (PostgreSQL) ──► Task 3
├── Task 24: ServiceAccount
├── Task 25: init ConfigMap
├── Task 26: Envoy ConfigMap
├── Task 27: StatefulSet ──► Tasks 24-26
├── Task 28: Service ──► Task 27
├── Task 29: kustomization ──► Tasks 24-28
├── Task 30: deploy script ──► Task 29
├── Task 31: verify ──► Task 30
└── Task 32: verify envoy ──► Task 31

Group 5 (Backend) ──► Task 4, Task 32
├── Task 33: models
├── Task 34: db ──► Task 33
├── Task 35: handlers ──► Task 34
├── Task 36: main ──► Task 35
├── Task 37: Dockerfile ──► Task 36
├── Task 38: ServiceAccount
├── Task 39: Envoy ConfigMap
├── Task 40: Deployment ──► Tasks 37-39
├── Task 41: Service ──► Task 40
├── Task 42: kustomization ──► Tasks 38-41
├── Task 43: deploy script ──► Task 42
└── Task 44: verify ──► Task 43

Group 6 (Frontend) ──► Task 4, Task 44
├── Task 45: models
├── Task 46: handlers ──► Task 45
├── Task 47: HTML
├── Task 48: CSS ──► Task 47
├── Task 49: JS ──► Task 47
├── Task 50: main ──► Task 46
├── Task 51: Dockerfile ──► Task 50
├── Task 52: ServiceAccount
├── Task 53: Envoy ConfigMap
├── Task 54: Deployment ──► Tasks 51-53
├── Task 55: Service ──► Task 54
└── Task 56: kustomization ──► Tasks 52-55

Group 7 (Registration & Scripts) ──► All Groups
├── Task 57: deploy script frontend ──► Task 56
├── Task 58: apps kustomization ──► Tasks 29, 42, 56
├── Task 59: registration script ──► Task 22
├── Task 60: demo-all script ──► Tasks 2, 14, 22, 57, 59
├── Task 61: verify frontend ──► Task 60
└── Task 62: E2E verification ──► Task 61
```

---

## Execution Notes

1. **Groups can be worked in parallel where dependencies allow**:
   - Group 1 tasks 1, 3, 4, 5 have no dependencies
   - Go code (Tasks 33-36, 45-50) can be developed while infra is built
   - Static assets (Tasks 47-49) have no Go dependencies

2. **Critical path**: Tasks 1 → 3 → 6-14 → 15-22 → 24-32 → 40-44 → 54-57 → 59-62

3. **Build before deploy**: Docker images must be built and loaded into kind before applying Deployments

4. **Registration timing**: SPIRE entries should be created after SPIRE agent is running but can be done before or after workloads deploy (entries just need to exist when workload requests SVID)
