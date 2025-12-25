#!/usr/bin/env bash
# Description: Install and initialize ArgoCD with repository credentials
# Usage: ./init-argocd.sh [--ssh-key <path>] [--token <github-token>]

set -euo pipefail

readonly ARGOCD_VERSION="v3.2.3"
readonly ARGOCD_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
readonly REPO_URL="git@github.com:cniebla/kind-istio.git"
readonly REPO_URL_HTTPS="https://github.com/cniebla/kind-istio.git"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Arguments
SSH_KEY_PATH=""
GITHUB_TOKEN=""

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --ssh-key <path>    Path to SSH private key for GitHub"
    echo "  --token <token>     GitHub Personal Access Token"
    echo "  --help              Show this help message"
    echo ""
    echo "If no credentials are provided, the script will prompt interactively."
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ssh-key)
                SSH_KEY_PATH="$2"
                shift 2
                ;;
            --token)
                GITHUB_TOKEN="$2"
                shift 2
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

check_prerequisites() {
    log_step "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_error "Make sure the cluster is running: ./cluster/start.sh"
        exit 1
    fi

    log_info "Prerequisites met"
}

install_argocd() {
    log_step "Installing ArgoCD ${ARGOCD_VERSION}..."

    # Create namespace
    kubectl apply -f "${PROJECT_DIR}/infrastructure/argocd/namespace.yaml"

    # Install ArgoCD
    log_info "Downloading and applying ArgoCD manifest..."
    kubectl apply -n argocd -f "${ARGOCD_MANIFEST}"

    # Apply install info configmap
    kubectl apply -f "${PROJECT_DIR}/infrastructure/argocd/install.yaml"

    log_info "ArgoCD installed"
}

wait_for_argocd() {
    log_step "Waiting for ArgoCD pods to be ready..."

    # Wait for all deployments
    kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s

    # Wait for all pods to be running
    kubectl wait --for=condition=Ready pods --all -n argocd --timeout=120s

    log_info "ArgoCD is ready"
}

configure_repo_ssh() {
    local key_path="$1"
    log_step "Configuring repository with SSH key..."

    if [[ ! -f "${key_path}" ]]; then
        log_error "SSH key not found: ${key_path}"
        exit 1
    fi

    # Create the secret
    kubectl create secret generic repo-creds \
        -n argocd \
        --from-file=sshPrivateKey="${key_path}" \
        --from-literal=url="${REPO_URL}" \
        --from-literal=type=git \
        --dry-run=client -o yaml | kubectl apply -f -

    # Label it as a repository secret
    kubectl label secret repo-creds -n argocd \
        argocd.argoproj.io/secret-type=repository \
        --overwrite

    log_info "SSH repository credentials configured"
}

configure_repo_token() {
    local token="$1"
    log_step "Configuring repository with GitHub token..."

    # Create the secret
    kubectl create secret generic repo-creds \
        -n argocd \
        --from-literal=url="${REPO_URL_HTTPS}" \
        --from-literal=username=cniebla \
        --from-literal=password="${token}" \
        --from-literal=type=git \
        --dry-run=client -o yaml | kubectl apply -f -

    # Label it as a repository secret
    kubectl label secret repo-creds -n argocd \
        argocd.argoproj.io/secret-type=repository \
        --overwrite

    log_info "Token repository credentials configured"
}

prompt_credentials() {
    echo ""
    echo "Repository credentials required for: ${REPO_URL}"
    echo ""
    echo "Choose authentication method:"
    echo "  1) SSH key (recommended)"
    echo "  2) GitHub Personal Access Token"
    echo "  3) Skip (configure later manually)"
    echo ""
    read -p "Enter choice [1-3]: " choice

    case $choice in
        1)
            read -p "Enter path to SSH private key [~/.ssh/id_ed25519]: " key_path
            key_path="${key_path:-$HOME/.ssh/id_ed25519}"
            configure_repo_ssh "${key_path}"
            ;;
        2)
            read -sp "Enter GitHub Personal Access Token: " token
            echo ""
            configure_repo_token "${token}"
            ;;
        3)
            log_warn "Skipping credential configuration"
            log_warn "You will need to configure repository access manually before syncing"
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

apply_root_application() {
    log_step "Applying root Application (App of Apps)..."

    kubectl apply -f "${PROJECT_DIR}/infrastructure/argocd/apps/root-app.yaml"

    log_info "Root application created"
}

show_access_info() {
    echo ""
    echo "========================================"
    echo "  ArgoCD Installation Complete!"
    echo "========================================"
    echo ""

    # Get admin password
    local password
    password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d) || password="<not available yet>"

    echo "Admin Credentials:"
    echo "  Username: admin"
    echo "  Password: ${password}"
    echo ""
    echo "Access the ArgoCD UI:"
    echo "  1. Run: ./scripts/port-forward.sh"
    echo "  2. Open: https://localhost:8080"
    echo ""
    echo "Or use kubectl port-forward directly:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo ""
    echo "ArgoCD CLI login:"
    echo "  argocd login localhost:8080 --username admin --password '${password}' --insecure"
    echo ""
}

main() {
    echo "========================================"
    echo "  ArgoCD Initialization"
    echo "========================================"
    echo ""

    parse_args "$@"
    check_prerequisites
    install_argocd
    wait_for_argocd

    # Configure repository credentials
    if [[ -n "${SSH_KEY_PATH}" ]]; then
        configure_repo_ssh "${SSH_KEY_PATH}"
    elif [[ -n "${GITHUB_TOKEN}" ]]; then
        configure_repo_token "${GITHUB_TOKEN}"
    else
        prompt_credentials
    fi

    apply_root_application
    show_access_info
}

main "$@"
