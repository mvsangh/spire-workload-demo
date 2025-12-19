#!/bin/bash
# cleanup.sh - Tear down the SPIRE/SPIFFE demo environment
#
# This script deletes the kind cluster and cleans up any local resources.

set -euo pipefail

CLUSTER_NAME="spire-demo"

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

# Check if cluster exists
cluster_exists() {
    kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"
}

# Delete the cluster
delete_cluster() {
    if cluster_exists; then
        log_info "Deleting kind cluster '${CLUSTER_NAME}'..."
        kind delete cluster --name "${CLUSTER_NAME}"

        if [ $? -eq 0 ]; then
            log_info "Cluster deleted successfully."
        else
            log_error "Failed to delete cluster."
            exit 1
        fi
    else
        log_warn "Cluster '${CLUSTER_NAME}' does not exist. Nothing to delete."
    fi
}

# Clean up local Docker images (optional)
cleanup_images() {
    log_info "Checking for demo Docker images..."

    # List of images to clean up
    local images=(
        "frontend:latest"
        "backend:latest"
    )

    for image in "${images[@]}"; do
        if docker image inspect "${image}" &>/dev/null 2>&1; then
            log_info "Removing image: ${image}"
            docker rmi "${image}" 2>/dev/null || true
        fi
    done
}

# Main execution
main() {
    log_info "=== SPIRE Demo Cleanup ==="

    delete_cluster

    # Ask about image cleanup
    if command -v docker &>/dev/null; then
        read -p "Also remove local Docker images? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cleanup_images
        fi
    fi

    log_info "=== Cleanup complete ==="
}

main "$@"
