# Implementation Plan: SPIRE/SPIFFE Production-Style Demo

**Branch**: `001-spire-spiffe-demo` | **Date**: 2025-12-19 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-spire-spiffe-demo/spec.md`

## Summary

Production-style SPIRE/SPIFFE demo on kind Kubernetes cluster demonstrating workload identity with mTLS between Go frontend, backend, and PostgreSQL. Envoy sidecars handle all TLS termination and RBAC enforcement, keeping application code unchanged. Single-command deployment scripts for demo repeatability.

## Technical Context

**Language/Version**: Go 1.21+ (frontend and backend services)
**Primary Dependencies**:
- SPIRE Server & Agent (v1.9+)
- Envoy Proxy (v1.29+) for sidecar mTLS/RBAC
- PostgreSQL 15+ with SSL client certificate auth
- kind (Kubernetes in Docker) for local cluster

**Storage**: PostgreSQL 15 (demo data - orders table)
**Testing**: Go testing + shell scripts for E2E validation
**Target Platform**: kind Kubernetes cluster (Linux containers on Docker/Podman)
**Project Type**: Web (frontend + backend + infrastructure)
**Performance Goals**: UI response < 2 seconds (demo context)
**Constraints**: < 8GB RAM, 4 CPU cores (developer laptop)
**Scale/Scope**: Single cluster, 3 workloads (frontend, backend, postgres), 2 Envoy sidecars

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
│   └── static/          # HTML/CSS/JS assets
└── backend/
    ├── handlers.go      # API handlers
    └── db.go            # PostgreSQL connection logic

# Infrastructure
deploy/
├── kind/
│   └── cluster-config.yaml
├── spire/
│   ├── server/          # SPIRE server manifests
│   └── agent/           # SPIRE agent DaemonSet
├── envoy/
│   ├── frontend-sidecar.yaml
│   └── backend-sidecar.yaml
├── apps/
│   ├── frontend.yaml
│   ├── backend.yaml
│   └── postgres.yaml
└── rbac/
    └── backend-policy.yaml

# Automation Scripts
scripts/
├── 01-create-cluster.sh
├── 02-deploy-spire.sh
├── 03-deploy-apps.sh
├── 04-register-entries.sh
├── demo-all.sh          # One-command full setup
└── cleanup.sh

# Container Images
docker/
├── frontend.Dockerfile
└── backend.Dockerfile
```

**Structure Decision**: Kubernetes-native demo structure separating application code (`cmd/`, `internal/`), infrastructure manifests (`deploy/`), and automation scripts (`scripts/`). This enables incremental deployment and clear debugging.

## Complexity Tracking

> No constitution violations - proceeding with minimal viable architecture.

| Component | Justification |
|-----------|---------------|
| Envoy sidecars | Required for mTLS without app code changes (core demo value) |
| SPIRE Server/Agent | Required for SVID issuance (core demo value) |
| PostgreSQL | Required per spec for backend-to-db mTLS demo |
| 2 Go services | Minimal: frontend (UI) + backend (API) per spec |

---

## Constitution Check: Post-Design Re-evaluation

**Status**: PASS

**Design Validation**:
- ✅ Minimal components: Only required services (frontend, backend, postgres)
- ✅ No unnecessary abstractions: Direct HTTP handlers, simple DB queries
- ✅ Clear separation: Infrastructure/Application/Scripts isolated
- ✅ Testable: Shell scripts for E2E, Go tests for unit testing
- ✅ Demo-focused: No production overhead (no HA, no complex observability)

**Efficiency for Context Window**:
- Modular file structure allows focused reading
- Deployment scripts are sequential and independent
- Envoy configs are separate per service for easy modification

---

## Generated Artifacts

| Artifact | Path | Purpose |
|----------|------|---------|
| Research | `specs/001-spire-spiffe-demo/research.md` | Technology decisions |
| Data Model | `specs/001-spire-spiffe-demo/data-model.md` | Entity definitions |
| Backend API | `specs/001-spire-spiffe-demo/contracts/backend-api.yaml` | OpenAPI spec |
| Frontend API | `specs/001-spire-spiffe-demo/contracts/frontend-api.yaml` | OpenAPI spec |
| Quickstart | `specs/001-spire-spiffe-demo/quickstart.md` | Deployment guide |
| Agent Context | `CLAUDE.md` | Updated with project tech stack |

---

## Implementation Order (for tasks.md)

1. **Infrastructure First**
   - kind cluster config
   - SPIRE server deployment
   - SPIRE agent DaemonSet
   - Namespace and RBAC setup

2. **PostgreSQL Stack**
   - PostgreSQL deployment
   - Envoy sidecar for Postgres
   - Init script for demo data

3. **Backend Service**
   - Go backend implementation
   - Envoy sidecar with RBAC
   - Dockerfile

4. **Frontend Service**
   - Go frontend implementation
   - Static HTML/CSS/JS
   - Envoy sidecar
   - Dockerfile

5. **Registration & Scripts**
   - SPIRE entry registration script
   - Deployment scripts (01-04)
   - demo-all.sh wrapper
   - cleanup.sh

6. **Validation**
   - E2E test scripts
   - P1/P2/P3 scenario verification
