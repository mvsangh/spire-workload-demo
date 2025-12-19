#!/bin/bash
set -e

# 04-deploy-apps.sh
# Deploys demo applications (PostgreSQL, Backend, Frontend)

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
    echo "→ Deploying PostgreSQL with Envoy sidecar..."

    kubectl apply -k "$PROJECT_ROOT/deploy/apps/postgres/"

    echo "→ Waiting for postgres-0 pod to be ready (timeout: 120s)..."
    if kubectl wait --for=condition=ready pod/postgres-0 -n demo --timeout=120s; then
        echo "✓ PostgreSQL pod is ready"
    else
        echo "✗ PostgreSQL pod failed to become ready"
        kubectl get pods -n demo -l app=postgres
        kubectl describe pod postgres-0 -n demo
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

# Verify Envoy sidecar
verify_postgres_envoy() {
    echo "→ Verifying PostgreSQL Envoy sidecar..."

    # Check Envoy container is running
    if kubectl get pod postgres-0 -n demo -o jsonpath='{.status.containerStatuses[?(@.name=="envoy")].ready}' | grep -q "true"; then
        echo "✓ Envoy sidecar is running"
    else
        echo "✗ Envoy sidecar is not ready"
        kubectl get pod postgres-0 -n demo -o jsonpath='{.status.containerStatuses[?(@.name=="envoy")]}'
        exit 1
    fi

    # Check Envoy admin endpoint
    if kubectl exec -n demo postgres-0 -c envoy -- curl -s http://127.0.0.1:9901/ready | grep -q "LIVE"; then
        echo "✓ Envoy admin endpoint is responsive"
    else
        echo "⚠ Envoy admin endpoint check failed (may be normal during startup)"
    fi

    # Check Envoy clusters
    CLUSTER_STATUS=$(kubectl exec -n demo postgres-0 -c envoy -- curl -s http://127.0.0.1:9901/clusters 2>/dev/null || echo "")
    if echo "$CLUSTER_STATUS" | grep -q "spire_agent"; then
        echo "✓ Envoy SPIRE agent cluster configured"
    else
        echo "⚠ SPIRE agent cluster not found in Envoy config"
    fi

    echo ""
}

# Main execution
main() {
    check_prerequisites
    deploy_postgres
    verify_postgres
    verify_postgres_envoy

    echo "========================================"
    echo "✓ PostgreSQL Deployment Complete"
    echo "========================================"
    echo ""
    echo "PostgreSQL is running with Envoy mTLS sidecar"
    echo "Connection string (internal): postgres.demo.svc.cluster.local:5433"
    echo ""
    echo "Next steps:"
    echo "  - Deploy backend: ./scripts/04-deploy-apps.sh (backend section - to be added)"
    echo "  - Check logs: kubectl logs -n demo postgres-0 -c postgres"
    echo "  - Check Envoy: kubectl logs -n demo postgres-0 -c envoy"
}

main "$@"
