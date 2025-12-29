# Observability Stack

Resource-constrained observability addons for the Istio learning environment.

## Components

| Component | Purpose | Memory Limit | Retention |
|-----------|---------|--------------|-----------|
| Prometheus | Metrics collection | 1Gi | 1 day / 1GB |
| Grafana | Dashboards | 256Mi | N/A |
| Kiali | Service mesh console | 512Mi | N/A |
| Jaeger | Distributed tracing | 512Mi | 24 hours |

## Resource Summary

Total memory limits: ~2.3Gi (vs ~4Gi+ for default addons)

## Accessing the UIs

After deployment, use port-forwarding to access each UI:

```bash
# Prometheus (metrics) - using 9091 to avoid conflict with local Prometheus
kubectl port-forward -n istio-system svc/prometheus 9091:9090

# Grafana (dashboards)
kubectl port-forward -n istio-system svc/grafana 3000:3000

# Kiali (service mesh console)
kubectl port-forward -n istio-system svc/kiali 20001:20001

# Jaeger (tracing)
kubectl port-forward -n istio-system svc/tracing 16686:80
```

## Grafana Dashboards

Pre-configured Istio dashboards:
- Mesh Dashboard - Overview of all services
- Service Dashboard - Per-service metrics
- Workload Dashboard - Per-workload metrics
- Performance Dashboard - Resource usage
- Control Plane Dashboard - Istiod health

## Modifications from Upstream

These manifests are based on `istio-1.28.2/samples/addons/` with:

1. **Resource limits added** - Prevents unbounded memory consumption
2. **Reduced retention** - 1 day for Prometheus, 24h for Jaeger traces
3. **Reduced trace storage** - Jaeger max traces reduced from 50k to 10k

## Customization

To adjust resources, edit the respective manifest files and push to git.
ArgoCD will automatically sync the changes.
