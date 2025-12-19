#!/bin/bash
# 02-deploy-spire.sh - Deploy SPIRE server and agent to the cluster
#
# This script deploys SPIRE components in order:
# 1. Namespaces
# 2. SPIRE Server
# 3. SPIRE Agent (to be added in Group 3)
#
# Prerequisites: kind cluster running, kubectl configured

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

    # Check health endpoint
    log_info "Checking health endpoint..."
    kubectl exec -n spire-system "${SERVER_POD}" -- \
        wget -q -O - http://localhost:8080/ready || {
            log_warn "Health endpoint check failed, but pod is running."
        }

    # Show server info
    log_info "SPIRE Server Info:"
    kubectl exec -n spire-system "${SERVER_POD}" -- \
        /opt/spire/bin/spire-server healthcheck || {
            log_warn "SPIRE healthcheck command not available via socket yet."
        }

    log_info "SPIRE Server verification complete."
}

# Deploy SPIRE Agent
deploy_spire_agent() {
    log_info "Deploying SPIRE Agent..."

    # Apply SPIRE agent manifests using kustomize
    kubectl apply -k "${PROJECT_ROOT}/deploy/spire/agent/"

    log_info "Waiting for SPIRE Agent to be ready..."

    # Wait for the DaemonSet pods to be ready
    kubectl wait --for=condition=ready pod \
        -l app=spire-agent \
        -n spire-system \
        --timeout=120s

    log_info "SPIRE Agent deployed and ready."
}

# Verify SPIRE Agent health
verify_spire_agent() {
    log_info "Verifying SPIRE Agent health..."

    # Get the agent pod name (there's one per node)
    AGENT_POD=$(kubectl get pod -n spire-system -l app=spire-agent -o jsonpath='{.items[0].metadata.name}')

    if [ -z "${AGENT_POD}" ]; then
        log_error "SPIRE Agent pod not found."
        exit 1
    fi

    log_info "SPIRE Agent pod: ${AGENT_POD}"

    # Check pod status
    POD_STATUS=$(kubectl get pod -n spire-system "${AGENT_POD}" -o jsonpath='{.status.phase}')
    if [ "${POD_STATUS}" != "Running" ]; then
        log_error "SPIRE Agent pod is not running. Status: ${POD_STATUS}"
        kubectl describe pod -n spire-system "${AGENT_POD}"
        exit 1
    fi

    # Check health endpoint
    log_info "Checking agent health endpoint..."
    kubectl exec -n spire-system "${AGENT_POD}" -- \
        wget -q -O - http://localhost:8080/ready || {
            log_warn "Health endpoint check returned non-zero, checking logs..."
        }

    # Run healthcheck
    log_info "Running SPIRE Agent healthcheck..."
    kubectl exec -n spire-system "${AGENT_POD}" -- \
        /opt/spire/bin/spire-agent healthcheck || {
            log_error "SPIRE Agent healthcheck failed."
            kubectl logs -n spire-system "${AGENT_POD}" --tail=50
            exit 1
        }

    # Verify socket file exists on the host
    log_info "Verifying workload API socket..."
    kubectl exec -n spire-system "${AGENT_POD}" -- \
        ls -la /run/spire/agent-sockets/spire-agent.sock || {
            log_error "Workload API socket not found."
            exit 1
        }

    log_info "SPIRE Agent verification complete."
}

# Main execution
main() {
    log_info "=== SPIRE Deployment ==="

    check_prerequisites
    deploy_namespaces
    deploy_spire_server
    verify_spire_server
    deploy_spire_agent
    verify_spire_agent

    log_info "=== SPIRE deployment complete ==="
    log_info "Server: Running"
    log_info "Agent: Running"
    log_info "Next step: Run ./scripts/03-deploy-apps.sh"
}

main "$@"
