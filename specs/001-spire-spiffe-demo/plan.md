# Implementation Plan: SPIRE/SPIFFE Production-Style Demo

**Branch**: `001-spire-spiffe-demo` | **Date**: 2025-12-19 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-spire-spiffe-demo/spec.md`

## Summary

Production-style SPIRE/SPIFFE demo on kind Kubernetes cluster demonstrating workload identity with mTLS using TWO distinct integration patterns: (1) Envoy SDS for frontend-backend service-to-service communication with RBAC enforcement, and (2) spiffe-helper for backend-PostgreSQL database connections where PostgreSQL directly verifies client SPIFFE IDs. Showcases true end-to-end mTLS, automatic certificate rotation, and zero application code changes. Single-command deployment scripts for demo repeatability.

## Technical Context

**Language/Version**: Go 1.21+ (frontend and backend services)
**Primary Dependencies**:
- SPIRE Server & Agent (v1.9+)
- Envoy Proxy (v1.29+) for service-to-service mTLS/RBAC (Pattern 1: SDS)
- spiffe-helper (latest) for certificate file management (Pattern 2: file-based)
- PostgreSQL 15+ with SSL client certificate authentication
- kind (Kubernetes in Docker) for local cluster

**Storage**: PostgreSQL 15 (demo data - orders table)
**Testing**: Go testing + shell scripts for E2E validation
**Target Platform**: kind Kubernetes cluster (Linux containers on Docker/Podman)
**Project Type**: Web (frontend + backend + infrastructure)
**Performance Goals**: UI response < 2 seconds (demo context)
**Constraints**: < 8GB RAM, 4 CPU cores (developer laptop)
**Scale/Scope**: Single cluster, 3 workloads (frontend, backend, postgres), 2 Envoy sidecars (frontend + backend), 2 spiffe-helper sidecars (backend + postgres)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Status**: PASS (Constitution is template/unconfigured - no constraints active)

The project constitution is in template state with placeholder values. Since no specific constraints are defined, we proceed with standard best practices:
- Minimal complexity: Only required components
- Clear separation: Infrastructure (K8s manifests), Application (Go services), Scripts (deployment automation)
- Testable: E2E shell scripts validate demo scenarios

## Project Structure

### Documentation (this feature)

```text
specs/001-spire-spiffe-demo/
├── plan.md              # This file
├── research.md          # Phase 0: Technology decisions
├── data-model.md        # Phase 1: Data entities
├── quickstart.md        # Phase 1: Setup guide
├── contracts/           # Phase 1: API schemas
└── tasks.md             # Phase 2: Implementation tasks
```

### Source Code (repository root)

```text
# Application Services
cmd/
├── frontend/
│   └── main.go          # Frontend HTTP server (serves UI + proxies to backend)
└── backend/
    └── main.go          # Backend API server (connects to Postgres)

internal/
├── frontend/
│   ├── handlers.go      # HTTP handlers for UI and demo actions
│   ├── models.go        # Frontend data models
│   └── static/          # HTML/CSS/JS assets
└── backend/
    ├── handlers.go      # API handlers
    ├── models.go        # Backend data models
    └── db.go            # PostgreSQL connection logic

# Infrastructure
deploy/
├── kind/
│   └── cluster-config.yaml
├── namespaces.yaml
├── spire/
│   ├── server/          # SPIRE server manifests
│   │   ├── serviceaccount.yaml
│   │   ├── clusterrole.yaml
│   │   ├── clusterrolebinding.yaml
│   │   ├── configmap.yaml
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   ├── agent/           # SPIRE agent DaemonSet
│   │   ├── serviceaccount.yaml
│   │   ├── clusterrole.yaml
│   │   ├── clusterrolebinding.yaml
│   │   ├── configmap.yaml
│   │   ├── daemonset.yaml
│   │   └── kustomization.yaml
│   └── kustomization.yaml
├── apps/
│   ├── postgres/
│   │   ├── serviceaccount.yaml
│   │   ├── init-configmap.yaml          # Database init SQL
│   │   ├── spiffe-helper-configmap.yaml # Pattern 2: spiffe-helper config
│   │   ├── statefulset.yaml             # Postgres + spiffe-helper sidecar
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   ├── backend/
│   │   ├── serviceaccount.yaml
│   │   ├── envoy-configmap.yaml         # Pattern 1: Envoy SDS config (inbound from frontend)
│   │   ├── spiffe-helper-configmap.yaml # Pattern 2: spiffe-helper config (outbound to postgres)
│   │   ├── deployment.yaml              # Backend + Envoy sidecar + spiffe-helper sidecar
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   ├── frontend/
│   │   ├── serviceaccount.yaml
│   │   ├── envoy-configmap.yaml         # Pattern 1: Envoy SDS config (outbound to backend)
│   │   ├── deployment.yaml              # Frontend + Envoy sidecar
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   └── kustomization.yaml

# Automation Scripts
scripts/
├── 01-create-cluster.sh
├── 02-deploy-spire-server.sh   # SPIRE Server only
├── 03-deploy-spire-agent.sh    # SPIRE Agent only
├── 04-deploy-apps.sh            # Apps deployment (postgres, backend, frontend)
├── 05-register-entries.sh       # SPIRE registration entries
├── demo-all.sh                  # One-command full setup
└── cleanup.sh

# Container Images
docker/
├── frontend.Dockerfile
└── backend.Dockerfile
```

**Structure Decision**: Kubernetes-native demo structure separating application code (`cmd/`, `internal/`), infrastructure manifests (`deploy/`), and automation scripts (`scripts/`). Envoy and spiffe-helper configs are organized per-application as ConfigMaps within `deploy/apps/*/` directories. This enables incremental deployment, clear debugging, and demonstrates both integration patterns side-by-side.

## Complexity Tracking

> No constitution violations - proceeding with minimal viable architecture demonstrating two SPIFFE integration patterns.

| Component | Justification |
|-----------|---------------|
| Envoy sidecars (2) | Required for Pattern 1: service-to-service mTLS via SDS without app code changes (frontend ↔ backend) |
| spiffe-helper sidecars (2) | Required for Pattern 2: file-based certificate delivery for true end-to-end mTLS where PostgreSQL directly verifies SPIFFE IDs (backend → postgres) |
| SPIRE Server/Agent | Required for SVID issuance and Workload API |
| PostgreSQL | Required per spec for backend-to-db mTLS demo with direct certificate verification |
| 2 Go services | Minimal: frontend (UI) + backend (API) per spec |

**Rationale for dual patterns**: Demonstrating both Envoy SDS and spiffe-helper patterns in one demo provides comprehensive understanding of SPIFFE integration approaches: proxy-based (Envoy) for service meshes and direct application integration (spiffe-helper) for legacy databases requiring native SSL client certificates.

---

## Constitution Check: Post-Design Re-evaluation

**Status**: PASS

**Design Validation**:
- ✅ Minimal components: Only required services (frontend, backend, postgres) with necessary sidecars
- ✅ No unnecessary abstractions: Direct HTTP handlers, simple DB queries, clear sidecar patterns
- ✅ Clear separation: Infrastructure/Application/Scripts isolated, two patterns clearly delineated
- ✅ Testable: Shell scripts for E2E validation, Go tests for unit testing
- ✅ Demo-focused: No production overhead (no HA beyond SPIRE, no complex observability)

**Efficiency for Context Window**:
- Modular file structure allows focused reading
- Deployment scripts are sequential and independent
- Envoy and spiffe-helper configs are separate per service for easy modification and pattern comparison
- Two integration patterns demonstrate versatility without duplication

---

## Generated Artifacts

| Artifact | Path | Purpose |
|----------|------|---------|
| Research | `specs/001-spire-spiffe-demo/research.md` | Technology decisions and pattern justifications |
| Data Model | `specs/001-spire-spiffe-demo/data-model.md` | Entity definitions (Order) |
| Backend API | `specs/001-spire-spiffe-demo/contracts/backend-api.yaml` | OpenAPI spec |
| Frontend API | `specs/001-spire-spiffe-demo/contracts/frontend-api.yaml` | OpenAPI spec |
| Quickstart | `specs/001-spire-spiffe-demo/quickstart.md` | Deployment guide |
| Agent Context | `CLAUDE.md` | Updated with project tech stack |

---

## Implementation Order (for tasks.md)

1. **Infrastructure First**
   - kind cluster config
   - Namespaces
   - SPIRE server deployment
   - SPIRE agent DaemonSet
   - Kubernetes RBAC setup

2. **PostgreSQL Stack (Pattern 2: spiffe-helper)**
   - PostgreSQL deployment with spiffe-helper sidecar
   - PostgreSQL SSL configuration for client certificate authentication
   - spiffe-helper ConfigMap (fetches SVID, writes to files for PostgreSQL)
   - Init script for demo data (orders table)

3. **Backend Service (Both Patterns)**
   - Go backend implementation
   - Envoy sidecar ConfigMap (Pattern 1: inbound mTLS from frontend via SDS)
   - spiffe-helper ConfigMap (Pattern 2: outbound client certificates for PostgreSQL)
   - Backend Dockerfile
   - Deployment with dual sidecars (Envoy + spiffe-helper)

4. **Frontend Service (Pattern 1: Envoy SDS)**
   - Go frontend implementation
   - Static HTML/CSS/JS UI
   - Envoy sidecar ConfigMap (outbound mTLS to backend via SDS)
   - Frontend Dockerfile
   - Deployment with Envoy sidecar

5. **Registration & Scripts**
   - SPIRE entry registration script (frontend, backend, postgres SPIFFE IDs)
   - Deployment scripts (01-05)
   - demo-all.sh wrapper
   - cleanup.sh

6. **Validation**
   - E2E test scripts
   - Pattern 1 verification (Envoy logs show SDS-based mTLS)
   - Pattern 2 verification (PostgreSQL logs show client certificate verification)
   - Certificate rotation testing for both patterns

---

## Integration Pattern Details

### Pattern 1: Envoy SDS (Frontend ↔ Backend)

**Flow**: Frontend Envoy → Backend Envoy (both use SPIRE SDS API)

**Components**:
- Frontend Envoy sidecar: Outbound cluster to backend with SDS-fetched client SVID
- Backend Envoy sidecar: Inbound listener with SDS-fetched server SVID + RBAC validation
- SPIRE Agent: Provides SDS API for certificate delivery to Envoy

**Benefits**:
- Zero application code changes
- Dynamic certificate rotation handled by Envoy
- RBAC policy enforcement at proxy layer
- Standard service mesh pattern

### Pattern 2: spiffe-helper (Backend → PostgreSQL)

**Flow**: Backend reads client certs → PostgreSQL verifies client certs (both use files written by spiffe-helper)

**Components**:
- Backend spiffe-helper sidecar: Fetches backend SVID, writes to shared volume
- PostgreSQL spiffe-helper sidecar: Fetches postgres SVID, writes to shared volume
- Backend Go code: Reads client certificate files for PostgreSQL connection
- PostgreSQL: Configured with SSL client certificate authentication

**Benefits**:
- True end-to-end mTLS (database directly verifies client identity)
- Works with legacy applications requiring native SSL
- Demonstrates SPIFFE integration beyond service meshes
- Automatic certificate rotation via spiffe-helper file updates

---

## Phase 0: Research (will be generated)

Topics requiring research documentation in `research.md`:

1. **SPIRE v1.9.6 Configuration**
   - Server configuration for k8s_psat node attestation
   - Agent configuration for k8s workload attestation
   - SVID TTL settings for demo (rotation demonstration)

2. **Envoy SDS Integration**
   - Envoy v1.29+ SDS configuration with SPIRE
   - RBAC filter configuration
   - Cluster and listener setup for mTLS

3. **spiffe-helper Usage**
   - Configuration format for SPIRE Workload API
   - File rotation mechanism
   - Integration with PostgreSQL SSL configuration

4. **PostgreSQL SSL Client Certificate Authentication**
   - pg_hba.conf configuration for clientcert authentication
   - Certificate CN/SAN validation rules
   - Go PostgreSQL driver (lib/pq) SSL configuration

5. **Go SPIFFE Patterns**
   - When to use go-spiffe library vs. proxies
   - Database connection with client certificates
   - Zero-code-change demonstration approach

---

## Phase 1: Design Artifacts (will be generated)

### data-model.md

**Order Entity**:
- id (serial primary key)
- description (varchar)
- status (varchar)
- created_at (timestamp)

### contracts/backend-api.yaml

Endpoints:
- `GET /health` - Health check
- `GET /api/orders` - List all orders
- `GET /api/demo` - Trigger full demo flow (frontend→backend→db)

### contracts/frontend-api.yaml

UI Actions:
- Load index page
- "Run Demo" button triggers `/api/demo` call
- Display connection status for both patterns

### quickstart.md

Step-by-step guide:
1. Prerequisites (Docker, kubectl, kind)
2. Run `./scripts/demo-all.sh`
3. Access UI at `http://localhost:8080`
4. Click "Run Demo" to see both patterns in action
5. Verify logs for Pattern 1 (Envoy) and Pattern 2 (PostgreSQL SSL)
