#!/usr/bin/env bash
# Description: Start port forwarding for all observability UIs
# Usage: ./observability-ui.sh [--prometheus|--grafana|--kiali|--jaeger]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Port configuration
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
KIALI_PORT=20001
JAEGER_PORT=16686

# Track background PIDs
declare -a PIDS=()

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
    echo "  --prometheus  Forward only Prometheus (port ${PROMETHEUS_PORT})"
    echo "  --grafana     Forward only Grafana (port ${GRAFANA_PORT})"
    echo "  --kiali       Forward only Kiali (port ${KIALI_PORT})"
    echo "  --jaeger      Forward only Jaeger (port ${JAEGER_PORT})"
    echo "  --help        Show this help message"
    echo ""
    echo "Without options, forwards all observability UIs."
    echo ""
    echo "URLs:"
    echo "  Prometheus:  http://localhost:${PROMETHEUS_PORT}"
    echo "  Grafana:     http://localhost:${GRAFANA_PORT}"
    echo "  Kiali:       http://localhost:${KIALI_PORT}"
    echo "  Jaeger:      http://localhost:${JAEGER_PORT}"
}

cleanup() {
    log_info "Stopping port-forwards..."
    for pid in "${PIDS[@]}"; do
        kill "${pid}" 2>/dev/null || true
    done
}

check_pod_ready() {
    local label="$1"
    kubectl get pods -n istio-system -l "${label}" -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"
}

forward_prometheus() {
    if ! check_pod_ready "app.kubernetes.io/name=prometheus"; then
        log_error "Prometheus is not running"
        return 1
    fi
    log_info "Prometheus: http://localhost:${PROMETHEUS_PORT}"
    kubectl port-forward -n istio-system svc/prometheus ${PROMETHEUS_PORT}:9090 &
    PIDS+=($!)
}

forward_grafana() {
    if ! check_pod_ready "app.kubernetes.io/name=grafana"; then
        log_error "Grafana is not running"
        return 1
    fi
    log_info "Grafana:    http://localhost:${GRAFANA_PORT}"
    kubectl port-forward -n istio-system svc/grafana ${GRAFANA_PORT}:3000 &
    PIDS+=($!)
}

forward_kiali() {
    if ! check_pod_ready "app.kubernetes.io/name=kiali"; then
        log_error "Kiali is not running"
        return 1
    fi
    log_info "Kiali:      http://localhost:${KIALI_PORT}"
    kubectl port-forward -n istio-system svc/kiali ${KIALI_PORT}:20001 &
    PIDS+=($!)
}

forward_jaeger() {
    if ! check_pod_ready "app=jaeger"; then
        log_error "Jaeger is not running"
        return 1
    fi
    log_info "Jaeger:     http://localhost:${JAEGER_PORT}"
    kubectl port-forward -n istio-system svc/tracing ${JAEGER_PORT}:80 &
    PIDS+=($!)
}

forward_all() {
    log_info "Starting all observability port-forwards..."
    echo ""

    forward_prometheus || true
    forward_grafana || true
    forward_kiali || true
    forward_jaeger || true

    if [[ ${#PIDS[@]} -eq 0 ]]; then
        log_error "No observability services are running"
        log_error "Deploy observability stack first (ArgoCD should sync automatically)"
        exit 1
    fi
}

main() {
    echo "========================================"
    echo "  Observability UIs"
    echo "========================================"
    echo ""

    trap cleanup EXIT

    case "${1:-all}" in
        --prometheus)
            forward_prometheus
            ;;
        --grafana)
            forward_grafana
            ;;
        --kiali)
            forward_kiali
            ;;
        --jaeger)
            forward_jaeger
            ;;
        --help)
            usage
            exit 0
            ;;
        all|"")
            forward_all
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac

    echo ""
    log_warn "Press Ctrl+C to stop"
    echo ""

    # Wait for all background processes
    wait
}

main "$@"
