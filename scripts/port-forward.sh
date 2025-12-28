#!/usr/bin/env bash
# Description: Start port forwarding for ArgoCD UI and optionally Bookinfo
# Usage: ./port-forward.sh [--all]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FORWARD_ALL=false

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all     Forward all services (ArgoCD + Bookinfo)"
    echo "  --help    Show this help message"
    echo ""
    echo "Services:"
    echo "  ArgoCD:   https://localhost:8081"
    echo "  Bookinfo: http://localhost/productpage (via Istio ingress)"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                FORWARD_ALL=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

check_namespace() {
    local ns="$1"
    kubectl get namespace "${ns}" &> /dev/null
}

forward_argocd() {
    if ! check_namespace "argocd"; then
        log_error "ArgoCD namespace not found"
        log_error "Run ./scripts/init-argocd.sh first"
        return 1
    fi

    log_info "Starting ArgoCD port-forward..."
    log_info "ArgoCD UI: https://localhost:8081"
    echo ""
    log_warn "Press Ctrl+C to stop"
    echo ""

    kubectl port-forward svc/argocd-server -n argocd 8081:443
}

forward_all() {
    if ! check_namespace "argocd"; then
        log_error "ArgoCD namespace not found"
        return 1
    fi

    log_info "Starting port-forwards..."
    echo ""
    echo "Services available:"
    echo "  - ArgoCD UI:   https://localhost:8081"
    echo "  - Bookinfo:    http://localhost/productpage (via Istio ingress on port 80)"
    echo ""
    log_warn "Press Ctrl+C to stop all"
    echo ""

    # Start ArgoCD port-forward in background
    kubectl port-forward svc/argocd-server -n argocd 8081:443 &
    local argocd_pid=$!

    # Trap to cleanup on exit
    trap "kill ${argocd_pid} 2>/dev/null || true" EXIT

    # Wait for user interrupt
    wait ${argocd_pid}
}

main() {
    echo "========================================"
    echo "  Port Forwarding"
    echo "========================================"
    echo ""

    parse_args "$@"

    if [[ "${FORWARD_ALL}" == "true" ]]; then
        forward_all
    else
        forward_argocd
    fi
}

main "$@"
