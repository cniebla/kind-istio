#!/usr/bin/env bash
# Description: Show Kind cluster status and information
# Usage: ./status.sh

set -euo pipefail

readonly CLUSTER_NAME="istio-learning"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

cluster_exists() {
    kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"
}

show_status() {
    if ! cluster_exists; then
        log_error "Cluster '${CLUSTER_NAME}' does not exist."
        echo ""
        echo "To create the cluster, run: ./cluster/start.sh"
        exit 1
    fi

    section "Cluster Info"
    kubectl cluster-info 2>/dev/null || log_warn "Cannot connect to cluster"

    section "Nodes"
    kubectl get nodes -o wide 2>/dev/null || log_warn "Cannot get nodes"

    section "Node Resources"
    kubectl top nodes 2>/dev/null || echo "(metrics-server not installed)"

    section "System Pods (kube-system)"
    kubectl get pods -n kube-system 2>/dev/null || log_warn "Cannot get system pods"

    # Check for Istio
    if kubectl get namespace istio-system &> /dev/null; then
        section "Istio Pods"
        kubectl get pods -n istio-system 2>/dev/null
    else
        section "Istio"
        echo "Not installed"
    fi

    # Check for ArgoCD
    if kubectl get namespace argocd &> /dev/null; then
        section "ArgoCD Pods"
        kubectl get pods -n argocd 2>/dev/null

        section "ArgoCD Applications"
        kubectl get applications -n argocd 2>/dev/null || echo "No applications found"
    else
        section "ArgoCD"
        echo "Not installed"
    fi

    # Check for Bookinfo
    if kubectl get namespace bookinfo &> /dev/null; then
        section "Bookinfo Pods"
        kubectl get pods -n bookinfo 2>/dev/null
    fi

    section "Port Mappings"
    echo "Host Port 80   -> Istio Ingress Gateway (HTTP)"
    echo "Host Port 443  -> Istio Ingress Gateway (HTTPS)"
    echo "Host Port 30000-30001 -> NodePort services"

    section "Quick Access"
    echo "Bookinfo:  http://localhost/productpage"
    echo "ArgoCD:    https://localhost:8080 (requires port-forward)"
    echo ""
}

main() {
    echo "========================================"
    echo "  Kind Cluster Status - ${CLUSTER_NAME}"
    echo "========================================"

    show_status
}

main "$@"
