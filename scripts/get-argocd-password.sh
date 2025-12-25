#!/usr/bin/env bash
# Description: Retrieve the ArgoCD initial admin password
# Usage: ./get-argocd-password.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

main() {
    # Check if ArgoCD namespace exists
    if ! kubectl get namespace argocd &> /dev/null; then
        log_error "ArgoCD namespace not found"
        echo "Run ./scripts/init-argocd.sh first"
        exit 1
    fi

    # Check if secret exists
    if ! kubectl get secret argocd-initial-admin-secret -n argocd &> /dev/null; then
        log_error "ArgoCD admin secret not found"
        echo "ArgoCD may still be initializing, or the password was already changed"
        exit 1
    fi

    # Get and decode the password
    local password
    password=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" | base64 -d)

    echo ""
    log_info "ArgoCD Admin Credentials"
    echo "========================="
    echo "Username: admin"
    echo "Password: ${password}"
    echo ""
    echo "Access UI: https://localhost:8080"
    echo "(Run ./scripts/port-forward.sh first)"
    echo ""
}

main "$@"
