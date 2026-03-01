#!/usr/bin/env bash
# Description: Configure MetalLB IP address pool based on the kind Docker network subnet
# Usage: ./configure-metallb.sh

set -euo pipefail

readonly CLUSTER_NAME="istio-learning"
readonly POOL_NAME="kind-pool"
readonly NAMESPACE="metallb-system"
readonly DOCKER_NETWORK="kind"

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

    if ! command -v docker &> /dev/null; then
        log_error "docker is not installed"
        exit 1
    fi

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_error "Make sure the cluster is running: ./cluster/start.sh"
        exit 1
    fi
}

get_kind_subnet() {
    local subnet
    subnet=$(docker network inspect "${DOCKER_NETWORK}" \
        --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null | head -1)

    if [[ -z "${subnet}" ]]; then
        log_error "Could not inspect Docker network '${DOCKER_NETWORK}'"
        log_error "Make sure the kind cluster exists: kind get clusters"
        exit 1
    fi

    echo "${subnet}"
}

compute_ip_range() {
    local subnet="$1"
    # Use the last /8 of the network for MetalLB (e.g. 172.18.0.0/16 -> 172.18.255.200-172.18.255.250)
    local base
    base=$(echo "${subnet}" | cut -d'.' -f1-2)
    echo "${base}.255.200-${base}.255.250"
}

wait_for_metallb() {
    log_info "Waiting for MetalLB controller to be ready..."

    if ! kubectl get deployment metallb-controller -n "${NAMESPACE}" &> /dev/null; then
        log_error "MetalLB controller deployment not found in namespace '${NAMESPACE}'"
        log_error "Make sure MetalLB is installed (check ArgoCD or run: kubectl get pods -n ${NAMESPACE})"
        exit 1
    fi

    kubectl wait --for=condition=Available deployment/metallb-controller \
        -n "${NAMESPACE}" --timeout=120s
}

apply_pool_config() {
    local ip_range="$1"

    log_info "Applying IP address pool: ${ip_range}"

    kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: ${POOL_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: metallb-pool
    app.kubernetes.io/part-of: kind-istio
spec:
  addresses:
    - ${ip_range}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kind-l2
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: metallb-l2-advertisement
    app.kubernetes.io/part-of: kind-istio
spec:
  ipAddressPools:
    - ${POOL_NAME}
EOF
}

main() {
    echo "========================================"
    echo "  MetalLB IP Pool Configuration"
    echo "========================================"
    echo ""

    check_prerequisites

    log_info "Detecting kind Docker network subnet..."
    local subnet
    subnet=$(get_kind_subnet)
    log_info "Detected subnet: ${subnet}"

    local ip_range
    ip_range=$(compute_ip_range "${subnet}")
    log_info "Computed IP range: ${ip_range}"

    wait_for_metallb
    apply_pool_config "${ip_range}"

    echo ""
    log_info "MetalLB configured successfully!"
    echo ""
    echo "IP range assigned: ${ip_range}"
    echo ""
    echo "Verify LoadBalancer services:"
    echo "  kubectl get svc --all-namespaces | grep LoadBalancer"
    echo ""
    echo "To use LoadBalancer on the Istio ingress gateway, update"
    echo "  infrastructure/istio/istio-operator.yaml: service.type: LoadBalancer"
    echo ""
}

main "$@"
