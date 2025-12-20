#!/bin/bash
set -e

# 04-deploy-apps.sh
# Deploys demo applications (PostgreSQL, Backend, Frontend)
# Pattern 2: PostgreSQL uses spiffe-helper sidecar for SPIFFE certificate management

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================"
echo "Deploying Demo Applications"
echo "========================================"
echo ""

# Check prerequisites
check_prerequisites() {
    echo "→ Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        echo "✗ kubectl not found. Please install kubectl."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        echo "✗ Cannot connect to Kubernetes cluster"
        exit 1
    fi

    # Verify SPIRE is running
    if ! kubectl get pods -n spire-system -l app=spire-server -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
        echo "✗ SPIRE server is not running. Please run 02-deploy-spire-server.sh first."
        exit 1
    fi

    if ! kubectl get pods -n spire-system -l app=spire-agent -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
        echo "✗ SPIRE agent is not running. Please run 03-deploy-spire-agent.sh first."
        exit 1
    fi

    echo "✓ Prerequisites met"
    echo ""
}

# Deploy PostgreSQL
deploy_postgres() {
    echo "→ Deploying PostgreSQL with spiffe-helper sidecar (Pattern 2)..."

    kubectl apply -k "$PROJECT_ROOT/deploy/apps/postgres/"

    echo "→ Waiting for postgres-0 pod to be ready (timeout: 180s)..."
    # Longer timeout because init container waits for certificates
    if kubectl wait --for=condition=ready pod/postgres-0 -n demo --timeout=180s; then
        echo "✓ PostgreSQL pod is ready"
    else
        echo "✗ PostgreSQL pod failed to become ready"
        echo ""
        echo "Pod status:"
        kubectl get pods -n demo -l app=postgres
        echo ""
        echo "Pod events:"
        kubectl describe pod postgres-0 -n demo | tail -20
        exit 1
    fi

    echo ""
}

# Verify PostgreSQL
verify_postgres() {
    echo "→ Verifying PostgreSQL deployment..."

    # Check PostgreSQL is ready
    if kubectl exec -n demo postgres-0 -c postgres -- pg_isready -U demouser -d demo &> /dev/null; then
        echo "✓ PostgreSQL is accepting connections"
    else
        echo "✗ PostgreSQL is not ready"
        exit 1
    fi

    # Check demo database exists
    if kubectl exec -n demo postgres-0 -c postgres -- psql -U demouser -d demo -c "SELECT 1" &> /dev/null; then
        echo "✓ Demo database is accessible"
    else
        echo "✗ Cannot access demo database"
        exit 1
    fi

    # Check orders table exists
    if kubectl exec -n demo postgres-0 -c postgres -- psql -U demouser -d demo -c "SELECT COUNT(*) FROM orders" &> /dev/null; then
        ORDER_COUNT=$(kubectl exec -n demo postgres-0 -c postgres -- psql -U demouser -d demo -t -c "SELECT COUNT(*) FROM orders" | tr -d ' ')
        echo "✓ Orders table exists with $ORDER_COUNT records"
    else
        echo "✗ Orders table not found"
        exit 1
    fi

    echo ""
}

# Verify spiffe-helper sidecar (Pattern 2)
# Note: spiffe-helper runs as a native sidecar (init container with restartPolicy: Always)
verify_postgres_spiffe_helper() {
    echo "→ Verifying PostgreSQL spiffe-helper sidecar (Pattern 2)..."

    # Check spiffe-helper native sidecar is running (it's in initContainerStatuses, not containerStatuses)
    if kubectl get pod postgres-0 -n demo -o jsonpath='{.status.initContainerStatuses[?(@.name=="spiffe-helper")].ready}' | grep -q "true"; then
        echo "✓ spiffe-helper native sidecar is running"
    else
        echo "✗ spiffe-helper sidecar is not ready"
        kubectl get pod postgres-0 -n demo -o jsonpath='{.status.initContainerStatuses}'
        exit 1
    fi

    # Check SPIFFE certificates are written (check from postgres container since spiffe-helper has minimal image)
    echo "→ Checking SPIFFE certificates..."

    if kubectl exec -n demo postgres-0 -c postgres -- test -f /spiffe-certs/svid.pem; then
        echo "✓ SVID certificate (svid.pem) exists"
    else
        echo "✗ SVID certificate not found"
        exit 1
    fi

    if kubectl exec -n demo postgres-0 -c postgres -- test -f /spiffe-certs/svid_key.pem; then
        echo "✓ SVID private key (svid_key.pem) exists"
    else
        echo "✗ SVID private key not found"
        exit 1
    fi

    if kubectl exec -n demo postgres-0 -c postgres -- test -f /spiffe-certs/svid_bundle.pem; then
        echo "✓ SVID trust bundle (svid_bundle.pem) exists"
    else
        echo "✗ SVID trust bundle not found"
        exit 1
    fi

    # Verify certificate permissions (key must be 0600 for PostgreSQL)
    echo "→ Verifying certificate permissions..."
    CERT_PERMS=$(kubectl exec -n demo postgres-0 -c postgres -- ls -la /spiffe-certs/ 2>/dev/null)
    echo "$CERT_PERMS" | grep -q "svid_key.pem" && echo "✓ Certificate files present with correct ownership"

    echo ""
}

# Verify PostgreSQL SSL configuration
verify_postgres_ssl() {
    echo "→ Verifying PostgreSQL SSL configuration..."

    # Check SSL is enabled
    SSL_STATUS=$(kubectl exec -n demo postgres-0 -c postgres -- psql -U demouser -d demo -t -c "SHOW ssl;" 2>/dev/null | tr -d ' ')
    if [ "$SSL_STATUS" = "on" ]; then
        echo "✓ PostgreSQL SSL is enabled"
    else
        echo "⚠ PostgreSQL SSL status: $SSL_STATUS (expected: on)"
    fi

    # Show SSL certificate info
    echo "→ SSL certificate details:"
    kubectl exec -n demo postgres-0 -c postgres -- psql -U demouser -d demo -c "SELECT ssl_is_used();" 2>/dev/null || echo "  (SSL usage check requires active connection)"

    echo ""
}

# Build and deploy Backend
deploy_backend() {
    echo "→ Building backend Docker image..."

    cd "$PROJECT_ROOT"
    if docker build -t backend:latest -f docker/backend.Dockerfile . ; then
        echo "✓ Backend image built successfully"
    else
        echo "✗ Failed to build backend image"
        exit 1
    fi

    echo "→ Loading backend image into kind cluster..."
    if kind load docker-image backend:latest --name spire-demo; then
        echo "✓ Backend image loaded into kind"
    else
        echo "✗ Failed to load backend image"
        exit 1
    fi

    echo "→ Deploying backend with dual sidecars (Envoy + spiffe-helper)..."
    kubectl apply -k "$PROJECT_ROOT/deploy/apps/backend/"

    echo "→ Waiting for backend pod to be ready (timeout: 180s)..."
    if kubectl wait --for=condition=ready pod -l app=backend -n demo --timeout=180s; then
        echo "✓ Backend pod is ready"
    else
        echo "✗ Backend pod failed to become ready"
        kubectl get pods -n demo -l app=backend
        kubectl describe pod -l app=backend -n demo | tail -30
        exit 1
    fi

    echo ""
}

# Verify Backend
verify_backend() {
    echo "→ Verifying backend deployment..."

    # Check backend health
    BACKEND_POD=$(kubectl get pod -n demo -l app=backend -o jsonpath='{.items[0].metadata.name}')

    if kubectl exec -n demo "$BACKEND_POD" -c backend -- wget -q -O- http://localhost:9090/health &>/dev/null; then
        echo "✓ Backend health check passed"
    else
        echo "✗ Backend health check failed"
        exit 1
    fi

    # Verify containers
    CONTAINER_COUNT=$(kubectl get pod -n demo -l app=backend -o jsonpath='{.items[0].status.containerStatuses}' | grep -o '"ready":true' | wc -l)
    if [ "$CONTAINER_COUNT" -eq 3 ]; then
        echo "✓ All 3 containers running (backend + envoy + spiffe-helper)"
    else
        echo "⚠ Expected 3 containers, found $CONTAINER_COUNT running"
    fi

    echo ""
}

# Build and deploy Frontend
deploy_frontend() {
    echo "→ Building frontend Docker image..."

    cd "$PROJECT_ROOT"
    if docker build -t frontend:latest -f docker/frontend.Dockerfile . ; then
        echo "✓ Frontend image built successfully"
    else
        echo "✗ Failed to build frontend image"
        exit 1
    fi

    echo "→ Loading frontend image into kind cluster..."
    if kind load docker-image frontend:latest --name spire-demo; then
        echo "✓ Frontend image loaded into kind"
    else
        echo "✗ Failed to load frontend image"
        exit 1
    fi

    echo "→ Deploying frontend with Envoy sidecar (Pattern 1)..."
    kubectl apply -k "$PROJECT_ROOT/deploy/apps/frontend/"

    echo "→ Waiting for frontend pod to be ready (timeout: 180s)..."
    if kubectl wait --for=condition=ready pod -l app=frontend -n demo --timeout=180s; then
        echo "✓ Frontend pod is ready"
    else
        echo "✗ Frontend pod failed to become ready"
        kubectl get pods -n demo -l app=frontend
        kubectl describe pod -l app=frontend -n demo | tail -30
        exit 1
    fi

    echo ""
}

# Verify Frontend
verify_frontend() {
    echo "→ Verifying frontend deployment..."

    # Check frontend health
    if curl -s -f http://localhost:8080/health &>/dev/null; then
        echo "✓ Frontend health check passed (http://localhost:8080/health)"
    else
        echo "✗ Frontend health check failed"
        exit 1
    fi

    # Verify containers
    CONTAINER_COUNT=$(kubectl get pod -n demo -l app=frontend -o jsonpath='{.items[0].status.containerStatuses}' | grep -o '"ready":true' | wc -l)
    if [ "$CONTAINER_COUNT" -eq 2 ]; then
        echo "✓ All 2 containers running (frontend + envoy)"
    else
        echo "⚠ Expected 2 containers, found $CONTAINER_COUNT running"
    fi

    echo ""
}

# Main execution
main() {
    check_prerequisites

    echo "========================================"
    echo "Step 1: Deploy PostgreSQL"
    echo "========================================"
    deploy_postgres
    verify_postgres
    verify_postgres_spiffe_helper
    verify_postgres_ssl

    echo "========================================"
    echo "Step 2: Deploy Backend"
    echo "========================================"
    deploy_backend
    verify_backend

    echo "========================================"
    echo "Step 3: Deploy Frontend"
    echo "========================================"
    deploy_frontend
    verify_frontend

    echo "========================================"
    echo "✓ All Applications Deployed Successfully"
    echo "========================================"
    echo ""
    echo "Deployed components:"
    echo "  ✓ PostgreSQL (Pattern 2: spiffe-helper)"
    echo "  ✓ Backend (Pattern 1 + Pattern 2: Envoy + spiffe-helper)"
    echo "  ✓ Frontend (Pattern 1: Envoy SDS)"
    echo ""
    echo "Access the demo:"
    echo "  → Open http://localhost:8080 in your browser"
    echo "  → Click 'Run Demo' to test both SPIFFE patterns"
    echo ""
    echo "Next steps:"
    echo "  → Register SPIRE entries: ./scripts/05-register-entries.sh"
    echo "  → Or run full demo: ./scripts/demo-all.sh"
    echo ""
}

main "$@"
