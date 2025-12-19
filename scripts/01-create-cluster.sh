#!/bin/bash
# 01-create-cluster.sh - Create kind cluster for SPIRE/SPIFFE demo
#
# This script creates a kind Kubernetes cluster configured for the demo.
# Prerequisites: kind, kubectl, docker/podman

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLUSTER_NAME="spire-demo"
CLUSTER_CONFIG="${PROJECT_ROOT}/deploy/kind/cluster-config.yaml"

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

    if ! command -v kind &> /dev/null; then
        log_error "kind is not installed. Please install kind first."
        exit 1
    fi

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi

    if ! command -v docker &> /dev/null && ! command -v podman &> /dev/null; then
        log_error "Neither docker nor podman is installed. Please install a container runtime."
        exit 1
    fi

    if [ ! -f "${CLUSTER_CONFIG}" ]; then
        log_error "Cluster config not found at ${CLUSTER_CONFIG}"
        exit 1
    fi

    log_info "All prerequisites met."
}

# Check if cluster already exists
check_existing_cluster() {
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        log_warn "Cluster '${CLUSTER_NAME}' already exists."
        read -p "Delete existing cluster and recreate? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting existing cluster..."
            kind delete cluster --name "${CLUSTER_NAME}"
        else
            log_info "Using existing cluster."
            return 1
        fi
    fi
    return 0
}

# Create the cluster
create_cluster() {
    log_info "Creating kind cluster '${CLUSTER_NAME}'..."

    kind create cluster --config "${CLUSTER_CONFIG}"

    if [ $? -eq 0 ]; then
        log_info "Cluster created successfully!"
    else
        log_error "Failed to create cluster."
        exit 1
    fi
}

# Verify cluster is ready
verify_cluster() {
    log_info "Verifying cluster is ready..."

    # Wait for node to be ready
    kubectl wait --for=condition=Ready node --all --timeout=120s

    # Verify kubectl context
    CURRENT_CONTEXT=$(kubectl config current-context)
    if [[ "${CURRENT_CONTEXT}" == *"${CLUSTER_NAME}"* ]]; then
        log_info "kubectl context is correctly set to cluster."
    else
        log_warn "kubectl context may not be set correctly. Current: ${CURRENT_CONTEXT}"
    fi

    # Show cluster info
    log_info "Cluster info:"
    kubectl cluster-info

    log_info "Nodes:"
    kubectl get nodes -o wide
}

# Main execution
main() {
    log_info "=== SPIRE Demo Cluster Setup ==="

    check_prerequisites

    if check_existing_cluster; then
        create_cluster
    fi

    verify_cluster

    log_info "=== Cluster setup complete ==="
    log_info "Next step: Run ./scripts/02-deploy-spire.sh"
}

main "$@"
