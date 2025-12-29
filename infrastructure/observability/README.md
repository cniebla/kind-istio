# Observability Stack

Resource-constrained observability addons for the Istio learning environment.

## Components

| Component | Purpose | Memory Limit | Retention |
|-----------|---------|--------------|-----------|
| Prometheus | Metrics collection | 1Gi | 1 day / 1GB |
| Grafana | Dashboards & visualization | 256Mi | N/A |
| Kiali | Service mesh console | 512Mi | N/A |
| Jaeger | Distributed tracing | 512Mi | 24 hours |
| Loki | Log aggregation | 1Gi | 24 hours |
| Promtail | Log collector (DaemonSet) | 128Mi per node | N/A |

## Resource Summary

Total memory limits: ~3.5Gi (+ 128Mi per node for Promtail)

## Quick Start

Use the convenience script to port-forward all UIs:

```bash
./scripts/observability-ui.sh
```

Or forward individual services:

```bash
./scripts/observability-ui.sh --grafana
./scripts/observability-ui.sh --prometheus
./scripts/observability-ui.sh --kiali
./scripts/observability-ui.sh --jaeger
./scripts/observability-ui.sh --loki
```

## URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | admin/admin |
| Prometheus | http://localhost:9091 | N/A |
| Kiali | http://localhost:20001 | N/A |
| Jaeger | http://localhost:16686 | N/A |
| Loki | http://localhost:3100 | N/A |

## Grafana Dashboards

Pre-configured Istio dashboards (under "istio" folder):
- **Mesh Dashboard** - Overview of all services in the mesh
- **Service Dashboard** - Per-service metrics breakdown
- **Workload Dashboard** - Per-workload metrics
- **Performance Dashboard** - Resource usage monitoring
- **Control Plane Dashboard** - Istiod health and performance

## Querying Logs with Loki

In Grafana, go to **Explore** and select **Loki** as the datasource.

### Example LogQL Queries

```logql
# All logs from bookinfo namespace
{namespace="bookinfo"}

# Productpage container logs
{namespace="bookinfo", container="productpage"}

# Istio sidecar proxy logs
{namespace="bookinfo", container="istio-proxy"}

# Filter for errors (case insensitive)
{namespace="bookinfo"} |~ "(?i)error"

# Istiod control plane logs
{namespace="istio-system", pod=~"istiod.*"}

# All logs containing a specific trace ID
{namespace="bookinfo"} |= "trace_id_here"

# Rate of log lines per minute
rate({namespace="bookinfo"}[1m])
```

### Available Labels

| Label | Description |
|-------|-------------|
| `namespace` | Kubernetes namespace |
| `pod` | Pod name |
| `container` | Container name |
| `job` | Either "pods" or "varlogs" |

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Promtail   │────▶│    Loki     │◀────│   Grafana   │
│ (DaemonSet) │     │  (storage)  │     │   (query)   │
└─────────────┘     └─────────────┘     └─────────────┘
       │                                       │
       ▼                                       ▼
  /var/log/pods                          Dashboards
```

## Modifications from Upstream

These manifests are based on `istio-1.28.2/samples/addons/` with:

1. **Resource limits added** - Prevents unbounded memory consumption
2. **Reduced retention** - 1 day for Prometheus, 24h for Jaeger/Loki
3. **Reduced trace storage** - Jaeger max traces reduced from 50k to 10k
4. **Reduced Loki storage** - PVC reduced from 10Gi to 2Gi
5. **Removed pod anti-affinity** - For single-node Kind cluster compatibility
6. **Removed Loki sidecar** - Rules sidecar not needed for basic logging
7. **Added Promtail** - Log collector to ship logs to Loki

## Customization

Edit manifest files and push to git. ArgoCD will automatically sync changes.

### Adjusting Retention

- **Prometheus**: Edit `--storage.tsdb.retention.time` in `prometheus.yaml`
- **Loki**: Edit `retention_period` in `loki.yaml` ConfigMap
- **Jaeger**: Edit `BADGER_SPAN_STORE_TTL` in `jaeger.yaml`

### Adjusting Resources

Modify the `resources.limits` and `resources.requests` sections in each manifest.
