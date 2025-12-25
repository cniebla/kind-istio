#!/usr/bin/env bash
# Description: Stop and delete the Kind cluster
# Usage: ./stop.sh

set -euo pipefail

readonly CLUSTER_NAME="istio-learning"

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

cluster_exists() {
    kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"
}

delete_cluster() {
    if ! cluster_exists; then
        log_warn "Cluster '${CLUSTER_NAME}' does not exist."
        return 0
    fi

    log_info "Deleting Kind cluster '${CLUSTER_NAME}'..."

    kind delete cluster --name "${CLUSTER_NAME}"

    log_info "Cluster deleted successfully!"
}

cleanup_context() {
    # Remove the kubectl context if it still exists
    if kubectl config get-contexts "kind-${CLUSTER_NAME}" &> /dev/null; then
        log_info "Removing kubectl context..."
        kubectl config delete-context "kind-${CLUSTER_NAME}" 2>/dev/null || true
    fi
}

main() {
    echo "========================================"
    echo "  Kind Cluster Cleanup"
    echo "========================================"
    echo ""

    if cluster_exists; then
        read -p "Are you sure you want to delete cluster '${CLUSTER_NAME}'? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled."
            exit 0
        fi
    fi

    delete_cluster
    cleanup_context

    echo ""
    log_info "Cleanup complete!"
    echo ""
    echo "To recreate the cluster, run: ./cluster/start.sh"
}

main "$@"
