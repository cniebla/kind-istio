#!/usr/bin/env bash
# Description: Create and start the Kind cluster for Istio learning
# Usage: ./start.sh

set -euo pipefail

readonly CLUSTER_NAME="istio-learning"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="${SCRIPT_DIR}/kind-config.yaml"

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

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kind &> /dev/null; then
        log_error "kind is not installed. Please install it first."
        echo "  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64"
        echo "  chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind"
        exit 1
    fi

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install it first."
        exit 1
    fi

    if ! command -v docker &> /dev/null; then
        log_error "docker is not installed. Please install it first."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi

    log_info "All prerequisites met."
}

cluster_exists() {
    kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"
}

create_cluster() {
    if cluster_exists; then
        log_warn "Cluster '${CLUSTER_NAME}' already exists."
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting existing cluster..."
            kind delete cluster --name "${CLUSTER_NAME}"
        else
            log_info "Using existing cluster."
            return 0
        fi
    fi

    log_info "Creating Kind cluster '${CLUSTER_NAME}'..."
    log_info "Using config: ${CONFIG_FILE}"

    kind create cluster --config "${CONFIG_FILE}"

    log_info "Cluster created successfully!"
}

wait_for_nodes() {
    log_info "Waiting for nodes to be ready..."

    kubectl wait --for=condition=Ready nodes --all --timeout=120s

    log_info "All nodes are ready!"
}

show_cluster_info() {
    echo ""
    log_info "Cluster Information:"
    echo "----------------------------------------"
    kubectl cluster-info
    echo ""
    echo "Nodes:"
    kubectl get nodes -o wide
    echo ""
    echo "----------------------------------------"
    log_info "Cluster '${CLUSTER_NAME}' is ready!"
    echo ""
    echo "Next steps:"
    echo "  1. Install Istio: istioctl install -f infrastructure/istio/istio-operator.yaml -y"
    echo "  2. Initialize ArgoCD: ./scripts/init-argocd.sh"
    echo ""
}

main() {
    echo "========================================"
    echo "  Kind Cluster Setup - Istio Learning"
    echo "========================================"
    echo ""

    check_prerequisites
    create_cluster
    wait_for_nodes
    show_cluster_info
}

main "$@"
