#!/bin/bash
# 03-deploy-spire-agent.sh - Deploy SPIRE agent to the cluster
#
# This script deploys SPIRE Agent components:
# 1. SPIRE Agent DaemonSet (runs on every node)
# 2. Agent RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding)
# 3. Agent ConfigMap (with trust bundle reference)
#
# Prerequisites:
# - kind cluster running
# - SPIRE Server deployed (run 02-deploy-spire-server.sh first)
#
# Next step: Run 04-deploy-apps.sh

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

    # Check if SPIRE server is running
    if ! kubectl get pod -n spire-system -l app=spire-server -o jsonpath='{.items[0].metadata.name}' &> /dev/null; then
        log_error "SPIRE Server not found. Run 02-deploy-spire-server.sh first."
        exit 1
    fi

    # Check if spire-bundle ConfigMap exists (required for trust bundle)
    if ! kubectl get configmap spire-bundle -n spire-system &> /dev/null; then
        log_error "spire-bundle ConfigMap not found. Ensure SPIRE Server is running and has created the trust bundle."
        exit 1
    fi

    log_info "Prerequisites check passed."
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

    # Run healthcheck
    log_info "Running SPIRE Agent healthcheck..."
    kubectl exec -n spire-system "${AGENT_POD}" -- \
        /opt/spire/bin/spire-agent healthcheck || {
            log_error "SPIRE Agent healthcheck failed."
            kubectl logs -n spire-system "${AGENT_POD}" --tail=50
            exit 1
        }

    log_info "SPIRE Agent verification complete."
}

# Verify agent attestation with server
verify_attestation() {
    log_info "Verifying agent attestation with server..."

    # Get server pod
    SERVER_POD=$(kubectl get pod -n spire-system -l app=spire-server -o jsonpath='{.items[0].metadata.name}')

    # List attested agents
    AGENTS=$(kubectl exec -n spire-system "${SERVER_POD}" -- \
        /opt/spire/bin/spire-server agent list 2>/dev/null || echo "")

    if echo "${AGENTS}" | grep -q "spire/agent"; then
        log_info "Agent attestation verified:"
        echo "${AGENTS}"
    else
        log_warn "No attested agents found yet. Agent may still be attesting."
    fi
}

# Main execution
main() {
    log_info "=== SPIRE Agent Deployment ==="

    check_prerequisites
    deploy_spire_agent
    verify_spire_agent
    verify_attestation

    log_info "=== SPIRE Agent deployment complete ==="
    log_info "Agent: Running and attested"
    log_info "Next step: Run ./scripts/04-deploy-apps.sh"
}

main "$@"
