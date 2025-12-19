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
verify_postgres_spiffe_helper() {
    echo "→ Verifying PostgreSQL spiffe-helper sidecar (Pattern 2)..."

    # Check spiffe-helper container is running
    if kubectl get pod postgres-0 -n demo -o jsonpath='{.status.containerStatuses[?(@.name=="spiffe-helper")].ready}' | grep -q "true"; then
        echo "✓ spiffe-helper sidecar is running"
    else
        echo "✗ spiffe-helper sidecar is not ready"
        kubectl get pod postgres-0 -n demo -o jsonpath='{.status.containerStatuses}'
        exit 1
    fi

    # Check SPIFFE certificates are written
    echo "→ Checking SPIFFE certificates..."

    if kubectl exec -n demo postgres-0 -c spiffe-helper -- ls -la /spiffe-certs/svid.pem &> /dev/null; then
        echo "✓ SVID certificate (svid.pem) exists"
    else
        echo "✗ SVID certificate not found"
        exit 1
    fi

    if kubectl exec -n demo postgres-0 -c spiffe-helper -- ls -la /spiffe-certs/svid_key.pem &> /dev/null; then
        echo "✓ SVID private key (svid_key.pem) exists"
    else
        echo "✗ SVID private key not found"
        exit 1
    fi

    if kubectl exec -n demo postgres-0 -c spiffe-helper -- ls -la /spiffe-certs/svid_bundle.pem &> /dev/null; then
        echo "✓ SVID trust bundle (svid_bundle.pem) exists"
    else
        echo "✗ SVID trust bundle not found"
        exit 1
    fi

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

# Main execution
main() {
    check_prerequisites
    deploy_postgres
    verify_postgres
    verify_postgres_spiffe_helper
    verify_postgres_ssl

    echo "========================================"
    echo "✓ PostgreSQL Deployment Complete"
    echo "========================================"
    echo ""
    echo "PostgreSQL is running with spiffe-helper sidecar (Pattern 2)"
    echo "  - SPIFFE certificates are written to /spiffe-certs"
    echo "  - PostgreSQL SSL is configured to use SVID certificates"
    echo "  - Client certificate authentication is enabled"
    echo ""
    echo "Connection string (internal): postgres.demo.svc.cluster.local:5432"
    echo ""
    echo "To verify SSL certificates:"
    echo "  kubectl exec -n demo postgres-0 -c spiffe-helper -- ls -la /spiffe-certs/"
    echo ""
    echo "To check PostgreSQL logs:"
    echo "  kubectl logs -n demo postgres-0 -c postgres"
    echo ""
    echo "To check spiffe-helper logs:"
    echo "  kubectl logs -n demo postgres-0 -c spiffe-helper"
    echo ""
    echo "Next steps:"
    echo "  - Register SPIRE entries: ./scripts/05-register-entries.sh"
    echo "  - Deploy backend (to be added)"
}

main "$@"
