#!/bin/bash
# 02-deploy-spire-server.sh - Deploy SPIRE server to the cluster
#
# This script deploys SPIRE Server components:
# 1. Namespaces (spire-system, demo)
# 2. SPIRE Server (StatefulSet, Service, ConfigMaps, RBAC)
#
# Prerequisites: kind cluster running, kubectl configured
# Next step: Run 03-deploy-spire-agent.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed."
        exit 1
    fi

    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Is the cluster running?"
        exit 1
    fi

    log_info "Prerequisites check passed."
}

# Deploy namespaces
deploy_namespaces() {
    log_info "Creating namespaces..."

    kubectl apply -f "${PROJECT_ROOT}/deploy/namespaces.yaml"

    # Verify namespaces exist
    kubectl get namespace spire-system
    kubectl get namespace demo

    log_info "Namespaces created."
}

# Deploy SPIRE Server
deploy_spire_server() {
    log_info "Deploying SPIRE Server..."

    # Apply SPIRE server manifests using kustomize
    kubectl apply -k "${PROJECT_ROOT}/deploy/spire/server/"

    log_info "Waiting for SPIRE Server to be ready..."

    # Wait for the StatefulSet to be ready
    kubectl wait --for=condition=ready pod \
        -l app=spire-server \
        -n spire-system \
        --timeout=120s

    log_info "SPIRE Server deployed and ready."
}

# Verify SPIRE Server health
verify_spire_server() {
    log_info "Verifying SPIRE Server health..."

    # Get the server pod name
    SERVER_POD=$(kubectl get pod -n spire-system -l app=spire-server -o jsonpath='{.items[0].metadata.name}')

    if [ -z "${SERVER_POD}" ]; then
        log_error "SPIRE Server pod not found."
        exit 1
    fi

    log_info "SPIRE Server pod: ${SERVER_POD}"

    # Check pod status
    POD_STATUS=$(kubectl get pod -n spire-system "${SERVER_POD}" -o jsonpath='{.status.phase}')
    if [ "${POD_STATUS}" != "Running" ]; then
        log_error "SPIRE Server pod is not running. Status: ${POD_STATUS}"
        kubectl describe pod -n spire-system "${SERVER_POD}"
        exit 1
    fi

    # Run healthcheck
    log_info "Running SPIRE Server healthcheck..."
    kubectl exec -n spire-system "${SERVER_POD}" -- \
        /opt/spire/bin/spire-server healthcheck || {
            log_warn "SPIRE healthcheck command returned non-zero."
        }

    log_info "SPIRE Server verification complete."
}

# Main execution
main() {
    log_info "=== SPIRE Server Deployment ==="

    check_prerequisites
    deploy_namespaces
    deploy_spire_server
    verify_spire_server

    log_info "=== SPIRE Server deployment complete ==="
    log_info "Server: Running"
    log_info "Next step: Run ./scripts/03-deploy-spire-agent.sh"
}

main "$@"
