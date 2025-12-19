# Quickstart: SPIRE/SPIFFE Demo

**Time to complete**: ~10 minutes
**Prerequisites**: Docker/Podman, kubectl, kind, Go 1.21+

---

## Prerequisites Check

```bash
# Verify all tools are installed
docker --version      # or podman --version
kubectl version --client
kind --version
go version
```

---

## Quick Deploy (One Command)

```bash
# From repository root
./scripts/demo-all.sh
```

This script:
1. Creates a kind cluster
2. Deploys SPIRE server and agent
3. Deploys frontend, backend, and PostgreSQL
4. Registers SPIRE entries
5. Opens the demo UI

---

## Step-by-Step Deployment

### 1. Create kind Cluster

```bash
./scripts/01-create-cluster.sh

# Or manually:
kind create cluster --name spire-demo --config deploy/kind/cluster-config.yaml
```

### 2. Deploy SPIRE

```bash
./scripts/02-deploy-spire.sh

# Wait for SPIRE to be ready
kubectl wait --for=condition=ready pod -l app=spire-server -n spire-system --timeout=120s
kubectl wait --for=condition=ready pod -l app=spire-agent -n spire-system --timeout=120s
```

### 3. Deploy Applications

```bash
./scripts/03-deploy-apps.sh

# Wait for pods
kubectl wait --for=condition=ready pod -l app=frontend -n demo --timeout=120s
kubectl wait --for=condition=ready pod -l app=backend -n demo --timeout=120s
kubectl wait --for=condition=ready pod -l app=postgres -n demo --timeout=120s
```

### 4. Register SPIRE Entries

```bash
./scripts/04-register-entries.sh

# Verify entries
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show
```

### 5. Access the Demo

```bash
# Open in browser
open http://localhost:8080

# Or verify manually
curl http://localhost:8080/api/health
```

---

## Demo Scenarios

### P1: Happy Path

1. Open http://localhost:8080
2. Click "Run Demo"
3. Verify both connections show SUCCESS:
   - Frontend → Backend: SUCCESS
   - Backend → Database: SUCCESS

### P2: RBAC Denial

1. Modify the RBAC policy to deny frontend access:
   ```bash
   # Edit backend-envoy-config ConfigMap
   kubectl edit configmap backend-envoy-config -n demo
   # Change principal_name from "spiffe://example.org/ns/demo/sa/frontend"
   # to "spiffe://example.org/ns/demo/sa/unauthorized"
   ```

2. Restart backend to apply:
   ```bash
   kubectl rollout restart deployment backend -n demo
   ```

3. Click "Run Demo" - Frontend → Backend should now show FAILED

4. Restore original policy and restart to fix

### P3: Certificate Rotation

1. Configure short SVID TTL (already set to 10m for demo)
2. Run continuous requests:
   ```bash
   while true; do curl -s http://localhost:8080/api/demo | jq .frontend_to_backend; sleep 5; done
   ```
3. Watch SPIRE agent logs for rotation:
   ```bash
   kubectl logs -n spire-system -l app=spire-agent -f | grep -i "svid\|rotat"
   ```
4. Verify requests continue succeeding during rotation

---

## Troubleshooting

### Pod not starting

```bash
# Check pod events
kubectl describe pod -l app=frontend -n demo

# Check Envoy sidecar logs
kubectl logs -n demo -l app=frontend -c envoy
```

### SPIRE agent not issuing SVIDs

```bash
# Check agent health
kubectl exec -n spire-system $(kubectl get pod -n spire-system -l app=spire-agent -o jsonpath='{.items[0].metadata.name}') -- \
  /opt/spire/bin/spire-agent healthcheck

# Check agent logs
kubectl logs -n spire-system -l app=spire-agent
```

### mTLS connection failures

```bash
# Check Envoy admin
kubectl exec -n demo -l app=backend -c envoy -- curl -s localhost:9001/certs | jq .

# Check Envoy stats
kubectl exec -n demo -l app=backend -c envoy -- curl -s localhost:9001/stats | grep ssl
```

### Database connection failures

```bash
# Check PostgreSQL is running
kubectl exec -n demo -l app=postgres -c postgres -- pg_isready

# Check backend Envoy can reach Postgres Envoy
kubectl exec -n demo -l app=backend -c envoy -- curl -s localhost:9001/clusters | grep postgres
```

---

## Cleanup

```bash
./scripts/cleanup.sh

# Or manually:
kind delete cluster --name spire-demo
```

---

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                        kind Cluster                              │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                     spire-system                           │  │
│  │  ┌─────────────────┐    ┌─────────────────────────────┐   │  │
│  │  │  SPIRE Server   │    │  SPIRE Agent (DaemonSet)    │   │  │
│  │  │  (StatefulSet)  │◄───│  /run/spire/agent-sockets   │   │  │
│  │  └─────────────────┘    └─────────────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                    │                             │
│                          Workload API Socket                     │
│                                    │                             │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                         demo                               │  │
│  │                                                            │  │
│  │  ┌──────────────┐     ┌──────────────┐    ┌────────────┐  │  │
│  │  │   Frontend   │     │   Backend    │    │  Postgres  │  │  │
│  │  │ ┌──────────┐ │     │ ┌──────────┐ │    │┌──────────┐│  │  │
│  │  │ │   App    │ │     │ │   App    │ │    ││  Server  ││  │  │
│  │  │ │  :8080   │ │     │ │  :9090   │ │    ││  :5432   ││  │  │
│  │  │ └──────────┘ │     │ └──────────┘ │    │└──────────┘│  │  │
│  │  │ ┌──────────┐ │     │ ┌──────────┐ │    │┌──────────┐│  │  │
│  │  │ │  Envoy   │─┼─mTLS┼▶│  Envoy   │─┼mTLS┼▶  Envoy   ││  │  │
│  │  │ │  :8080   │ │     │ │  :8080   │ │    ││  :5433   ││  │  │
│  │  │ └──────────┘ │     │ └──────────┘ │    │└──────────┘│  │  │
│  │  └──────────────┘     └──────────────┘    └────────────┘  │  │
│  │        │                    │                              │  │
│  │        │                    └───── RBAC: allow frontend    │  │
│  │        │                           SPIFFE ID only         │  │
│  └────────┼───────────────────────────────────────────────────┘  │
│           │                                                      │
│           └─────── NodePort :30080 ──► localhost:8080            │
└──────────────────────────────────────────────────────────────────┘
```

---

## Key Files

| File | Purpose |
|------|---------|
| `deploy/kind/cluster-config.yaml` | kind cluster configuration |
| `deploy/spire/server/` | SPIRE server manifests |
| `deploy/spire/agent/` | SPIRE agent manifests |
| `deploy/apps/frontend.yaml` | Frontend deployment + Envoy sidecar |
| `deploy/apps/backend.yaml` | Backend deployment + Envoy sidecar |
| `deploy/apps/postgres.yaml` | PostgreSQL deployment + Envoy sidecar |
| `deploy/envoy/backend-envoy.yaml` | Backend Envoy config with RBAC |
| `scripts/04-register-entries.sh` | SPIRE registration entries |
