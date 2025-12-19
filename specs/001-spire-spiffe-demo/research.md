# Research: SPIRE/SPIFFE Demo Implementation

**Date**: 2025-12-19
**Branch**: `001-spire-spiffe-demo`
**Purpose**: Resolve technical unknowns for demo implementation

## Executive Summary

All technical unknowns have been resolved. The demo will use:
- **SPIRE 1.9.x** with k8s_psat node attestation
- **Envoy 1.29+** sidecars with SDS for SVID fetching
- **PostgreSQL 15** with Envoy mTLS proxy (not native SPIFFE)
- **kind cluster** with hostPath socket sharing

---

## Decision 1: Envoy SDS Integration with SPIRE

**Decision**: Use SPIRE agent's Workload API via Unix domain socket for Envoy SDS.

**Rationale**:
- SPIRE agent exposes Workload API at `/run/spire/agent-sockets/spire-agent.sock`
- Envoy connects via gRPC cluster pointing to Unix socket
- Automatic SVID rotation without config changes

**Configuration Pattern**:
```yaml
# Envoy cluster for SPIRE agent
clusters:
- name: spire_agent
  type: STATIC
  http2_protocol_options: {}
  load_assignment:
    endpoints:
    - lb_endpoints:
      - endpoint:
          address:
            pipe:
              path: /run/spire/agent-sockets/spire-agent.sock

# SDS config for fetching SVID
tls_certificate_sds_secret_configs:
- name: "spiffe://example.org/ns/demo/sa/backend"
  sds_config:
    api_config_source:
      api_type: GRPC
      grpc_services:
      - envoy_grpc:
          cluster_name: spire_agent
```

**Alternatives Rejected**:
- File-based certificates: Requires manual rotation handling
- Istio integration: Adds complexity beyond demo scope

---

## Decision 2: PostgreSQL mTLS Architecture

**Decision**: Use Envoy-to-Envoy mTLS between backend and PostgreSQL, not native PostgreSQL SSL.

**Rationale**:
- PostgreSQL doesn't natively understand SPIFFE URI SANs
- Envoy sidecar on PostgreSQL pod terminates mTLS and connects locally
- Backend app connects to localhost:5432 (plain), Envoy handles mTLS upstream

**Architecture**:
```
Backend App (localhost:5432)
  → Backend Envoy (TCP proxy with mTLS client)
  → PostgreSQL Envoy (mTLS server, localhost to Postgres)
  → PostgreSQL (localhost:5432, no SSL)
```

**Alternatives Rejected**:
- Native PostgreSQL client cert auth: Requires CN-to-user mapping, doesn't work with SPIFFE URI SANs
- go-spiffe library in backend: Violates FR-012 (no SPIFFE libraries in app code)

---

## Decision 3: kind Cluster Configuration

**Decision**: Single control-plane node with hostPath socket sharing.

**Rationale**:
- Simplest setup for demo, runs on laptop
- hostPath volumes share SPIRE agent socket with workload pods
- No CSI driver complexity

**Configuration**:
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: spire-demo
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 8080
```

**Alternatives Rejected**:
- Multi-node cluster: Unnecessary for demo, increases resource usage
- CSI driver: Adds complexity for socket mounting

---

## Decision 4: SPIRE Server Deployment

**Decision**: StatefulSet with SQLite datastore.

**Rationale**:
- Stable pod name (`spire-server-0`) for registration scripts
- SQLite sufficient for demo (no production persistence needed)
- PVC ensures data survives pod restarts

**Alternatives Rejected**:
- Deployment: Random pod names complicate scripting
- PostgreSQL datastore: Overkill for demo, adds dependency

---

## Decision 5: Node Attestation

**Decision**: k8s_psat (Projected Service Account Token) attestation.

**Rationale**:
- Modern, secure method for Kubernetes
- Works with `skip_kubelet_verification=true` for kind
- Standard parent ID format: `spiffe://example.org/spire/agent/k8s_psat/demo-cluster/node/<node-name>`

**Alternatives Rejected**:
- k8s_sat: Older method, less secure
- join_token: Requires manual token management

---

## Decision 6: Workload Registration Selectors

**Decision**: Use namespace + service account selectors.

**Rationale**:
- `k8s:ns:demo` + `k8s:sa:frontend` uniquely identifies workload
- Survives pod restarts (unlike pod name selectors)
- Standard Kubernetes-native approach

**Registration Format**:
```bash
spire-server entry create \
  -spiffeID spiffe://example.org/ns/demo/sa/frontend \
  -parentID spiffe://example.org/spire/agent/k8s_psat/demo-cluster/node/<node> \
  -selector k8s:ns:demo \
  -selector k8s:sa:frontend
```

---

## Decision 7: Envoy RBAC Configuration

**Decision**: HTTP RBAC filter on backend inbound listener validating frontend SPIFFE ID.

**Rationale**:
- Clean separation: mTLS for transport, RBAC for authorization
- Easy to modify for P2 demo (deny frontend access)
- Logs authentication decisions for debugging

**Configuration**:
```yaml
http_filters:
- name: envoy.filters.http.rbac
  typed_config:
    "@type": type.googleapis.com/envoy.extensions.filters.http.rbac.v3.RBAC
    rules:
      action: ALLOW
      policies:
        "allow-frontend":
          permissions:
          - any: true
          principals:
          - authenticated:
              principal_name:
                exact: "spiffe://example.org/ns/demo/sa/frontend"
```

---

## Decision 8: Certificate Rotation

**Decision**: Default 1-hour SVID TTL with Envoy SDS automatic refresh.

**Rationale**:
- Envoy SDS automatically fetches new certificates before expiry
- 1-hour TTL is short enough to demonstrate rotation in demo
- No application code changes needed

**For P3 Demo**: Can set shorter TTL (10m) in SPIRE server config to show rotation quickly.

---

## Technology Versions

| Component | Version | Notes |
|-----------|---------|-------|
| SPIRE Server/Agent | 1.9.6 | Latest stable |
| Envoy | 1.29-latest | SDS v3 API support |
| PostgreSQL | 15 | Standard version |
| Go | 1.21+ | For frontend/backend services |
| kind | 0.20+ | Kubernetes 1.28+ |

---

## SPIFFE ID Schema

| Workload | SPIFFE ID |
|----------|-----------|
| Frontend | `spiffe://example.org/ns/demo/sa/frontend` |
| Backend | `spiffe://example.org/ns/demo/sa/backend` |
| PostgreSQL | `spiffe://example.org/ns/demo/sa/postgres` |

---

## Next Steps

All unknowns resolved. Proceed to Phase 1:
1. Generate data-model.md (Order entity)
2. Generate API contracts (frontend-to-backend, backend-to-db)
3. Generate quickstart.md (deployment guide)
