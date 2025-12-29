#!/usr/bin/env bash
# Description: Test and validate the Kind + Istio + ArgoCD setup
# Usage: ./test-setup.sh [--full]

set -uo pipefail
# Note: Not using -e as we want to continue testing even when some checks fail

readonly CLUSTER_NAME="istio-learning"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
SKIPPED=0

FULL_TEST=false

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

test_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASSED++))
}

test_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((FAILED++))
}

test_skip() {
    echo -e "  ${YELLOW}○${NC} $1 (skipped)"
    ((SKIPPED++))
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --full    Run full test including Bookinfo HTTP tests"
    echo "  --help    Show this help message"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --full)
                FULL_TEST=true
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

# Test: Prerequisites
test_prerequisites() {
    log_section "Prerequisites"

    if command -v docker &> /dev/null; then
        test_pass "Docker installed: $(docker --version | head -1)"
    else
        test_fail "Docker not installed"
    fi

    if command -v kind &> /dev/null; then
        test_pass "Kind installed: $(kind version)"
    else
        test_fail "Kind not installed"
    fi

    if command -v kubectl &> /dev/null; then
        test_pass "kubectl installed: $(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion": "[^"]*"' | head -1)"
    else
        test_fail "kubectl not installed"
    fi

    if command -v istioctl &> /dev/null; then
        test_pass "istioctl installed: $(istioctl version --remote=false 2>/dev/null || echo 'version check failed')"
    else
        test_fail "istioctl not installed"
    fi
}

# Test: Kind Cluster
test_cluster() {
    log_section "Kind Cluster"

    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        test_pass "Cluster '${CLUSTER_NAME}' exists"
    else
        test_fail "Cluster '${CLUSTER_NAME}' does not exist"
        log_info "Run: ./cluster/start.sh"
        return 1
    fi

    if kubectl cluster-info &> /dev/null; then
        test_pass "kubectl can connect to cluster"
    else
        test_fail "kubectl cannot connect to cluster"
        return 1
    fi

    local nodes_ready
    nodes_ready=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || echo "0")
    if [[ "${nodes_ready}" -ge 2 ]]; then
        test_pass "All nodes ready (${nodes_ready} nodes)"
    else
        test_fail "Not all nodes ready (${nodes_ready} ready)"
    fi
}

# Test: Istio
test_istio() {
    log_section "Istio Service Mesh"

    if kubectl get namespace istio-system &> /dev/null; then
        test_pass "istio-system namespace exists"
    else
        test_fail "istio-system namespace does not exist"
        log_info "Run: istioctl install -f infrastructure/istio/istio-operator.yaml -y"
        return 1
    fi

    local istiod_ready
    istiod_ready=$(kubectl get pods -n istio-system -l app=istiod --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [[ "${istiod_ready}" -ge 1 ]]; then
        test_pass "Istiod is running"
    else
        test_fail "Istiod is not running"
    fi

    local ingress_ready
    ingress_ready=$(kubectl get pods -n istio-system -l app=istio-ingressgateway --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [[ "${ingress_ready}" -ge 1 ]]; then
        test_pass "Ingress gateway is running"
    else
        test_fail "Ingress gateway is not running"
    fi

    # Check istiod is responding (verify-install removed in 1.28+)
    if istioctl proxy-status &> /dev/null; then
        test_pass "Istio control plane responding"
    else
        test_fail "Istio control plane not responding"
    fi
}

# Test: ArgoCD
test_argocd() {
    log_section "ArgoCD"

    if kubectl get namespace argocd &> /dev/null; then
        test_pass "argocd namespace exists"
    else
        test_fail "argocd namespace does not exist"
        log_info "Run: ./scripts/init-argocd.sh"
        return 1
    fi

    local argocd_pods
    argocd_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [[ "${argocd_pods}" -ge 4 ]]; then
        test_pass "ArgoCD pods running (${argocd_pods} pods)"
    else
        test_fail "Not enough ArgoCD pods running (${argocd_pods} pods)"
    fi

    if kubectl get secret argocd-initial-admin-secret -n argocd &> /dev/null; then
        test_pass "ArgoCD admin secret exists"
    else
        test_warn "ArgoCD admin secret not found (may have been deleted)"
    fi

    local apps
    apps=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
    if [[ "${apps}" -ge 1 ]]; then
        test_pass "ArgoCD applications found (${apps} apps)"
        kubectl get applications -n argocd --no-headers 2>/dev/null | while read -r line; do
            local name status
            name=$(echo "$line" | awk '{print $1}')
            status=$(echo "$line" | awk '{print $2}')
            if [[ "${status}" == "Synced" ]]; then
                echo -e "    ${GREEN}↳${NC} ${name}: ${status}"
            else
                echo -e "    ${YELLOW}↳${NC} ${name}: ${status}"
            fi
        done
    else
        test_skip "No ArgoCD applications found"
    fi
}

# Test: Bookinfo
test_bookinfo() {
    log_section "Bookinfo Application"

    if kubectl get namespace bookinfo &> /dev/null; then
        test_pass "bookinfo namespace exists"
    else
        test_skip "bookinfo namespace does not exist"
        return 0
    fi

    local injection
    injection=$(kubectl get namespace bookinfo -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || echo "")
    if [[ "${injection}" == "enabled" ]]; then
        test_pass "Istio injection enabled on namespace"
    else
        test_fail "Istio injection not enabled on namespace"
    fi

    local pods_total
    local pods_ready
    pods_total=$(kubectl get pods -n bookinfo --no-headers 2>/dev/null | wc -l || echo "0")
    pods_ready=$(kubectl get pods -n bookinfo --no-headers 2>/dev/null | grep -c "2/2.*Running" || echo "0")

    if [[ "${pods_ready}" -eq 6 ]]; then
        test_pass "All Bookinfo pods ready with sidecars (${pods_ready}/6)"
    elif [[ "${pods_ready}" -gt 0 ]]; then
        test_warn "Some Bookinfo pods ready (${pods_ready}/${pods_total})"
    else
        test_fail "No Bookinfo pods ready"
    fi

    # Check services
    local services
    services=$(kubectl get svc -n bookinfo --no-headers 2>/dev/null | wc -l || echo "0")
    if [[ "${services}" -ge 4 ]]; then
        test_pass "Bookinfo services created (${services} services)"
    else
        test_fail "Missing Bookinfo services (${services}/4)"
    fi

    # Check Istio resources
    if kubectl get gateway bookinfo-gateway -n bookinfo &> /dev/null; then
        test_pass "Bookinfo Gateway exists"
    else
        test_fail "Bookinfo Gateway not found"
    fi

    if kubectl get virtualservice bookinfo -n bookinfo &> /dev/null; then
        test_pass "Bookinfo VirtualService exists"
    else
        test_fail "Bookinfo VirtualService not found"
    fi

    local dest_rules
    dest_rules=$(kubectl get destinationrules -n bookinfo --no-headers 2>/dev/null | wc -l || echo "0")
    if [[ "${dest_rules}" -ge 4 ]]; then
        test_pass "DestinationRules created (${dest_rules} rules)"
    else
        test_fail "Missing DestinationRules (${dest_rules}/4)"
    fi
}

# Test: HTTP Access (full test only)
test_http_access() {
    if [[ "${FULL_TEST}" != "true" ]]; then
        return 0
    fi

    log_section "HTTP Access Tests"

    # Test productpage
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:30000/productpage 2>/dev/null || echo "000")

    if [[ "${http_code}" == "200" ]]; then
        test_pass "Productpage accessible (HTTP ${http_code})"
    else
        test_fail "Productpage not accessible (HTTP ${http_code})"
        log_info "Make sure Istio ingress gateway is properly configured"
    fi

    # Test internal connectivity via istio-proxy sidecar
    if kubectl exec -n bookinfo deploy/productpage-v1 -c istio-proxy -- \
        curl -s --max-time 5 http://details:9080/details/0 &> /dev/null; then
        test_pass "Internal service connectivity works"
    else
        test_fail "Internal service connectivity failed"
    fi
}

# Summary
show_summary() {
    log_section "Test Summary"

    local total=$((PASSED + FAILED + SKIPPED))

    echo ""
    echo -e "  ${GREEN}Passed:${NC}  ${PASSED}"
    echo -e "  ${RED}Failed:${NC}  ${FAILED}"
    echo -e "  ${YELLOW}Skipped:${NC} ${SKIPPED}"
    echo -e "  Total:   ${total}"
    echo ""

    if [[ "${FAILED}" -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        echo ""
        echo "Your environment is ready. Access:"
        echo "  - Bookinfo: http://localhost:30000/productpage"
        echo "  - ArgoCD:   https://localhost:8081 (run ./scripts/port-forward.sh)"
    else
        echo -e "${RED}Some tests failed.${NC}"
        echo ""
        echo "Review the failures above and run the suggested commands."
    fi
    echo ""
}

main() {
    echo "========================================"
    echo "  Kind + Istio + ArgoCD Test Suite"
    echo "========================================"

    parse_args "$@"

    test_prerequisites
    test_cluster || true
    test_istio || true
    test_argocd || true
    test_bookinfo || true
    test_http_access || true

    show_summary

    # Exit with failure if any tests failed
    [[ "${FAILED}" -eq 0 ]]
}

main "$@"
