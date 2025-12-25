# Bookinfo Application

Istio's sample polyglot microservices application for demonstrating service mesh capabilities.

## Architecture

```
                         ┌─────────────────────┐
                         │   Istio Ingress     │
                         │     Gateway         │
                         │  (localhost:80)     │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │    productpage      │
                         │     (Python)        │
                         │        v1           │
                         └──────────┬──────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
                    ▼               ▼               │
         ┌─────────────────┐ ┌─────────────────┐   │
         │     details     │ │     reviews     │   │
         │     (Ruby)      │ │     (Java)      │   │
         │       v1        │ │   v1 / v2 / v3  │   │
         └─────────────────┘ └────────┬────────┘   │
                                      │            │
                                      ▼            │
                             ┌─────────────────┐   │
                             │     ratings     │◄──┘
                             │    (Node.js)    │
                             │       v1        │
                             └─────────────────┘
```

## Services

| Service | Language | Port | Versions | Description |
|---------|----------|------|----------|-------------|
| productpage | Python | 9080 | v1 | Main UI, orchestrates calls |
| details | Ruby | 9080 | v1 | Book details (ISBN, pages) |
| reviews | Java | 9080 | v1, v2, v3 | Book reviews |
| ratings | Node.js | 9080 | v1 | Star ratings |

### Reviews Versions

| Version | Behavior | Visual |
|---------|----------|--------|
| v1 | No ratings | No stars displayed |
| v2 | Calls ratings service | Black stars ★★★★★ |
| v3 | Calls ratings service | Red stars ★★★★★ |

## Files

| File | Description |
|------|-------------|
| `namespace.yaml` | Namespace with `istio-injection: enabled` |
| `bookinfo.yaml` | All deployments, services, and service accounts |
| `gateway.yaml` | Istio Gateway for external access |
| `virtualservice.yaml` | VirtualServices for traffic routing |
| `destination-rules.yaml` | DestinationRules defining version subsets |

## Deployment

### Via ArgoCD (Recommended)

The application is automatically deployed by ArgoCD when you push to the repository.

```bash
# Check application status
kubectl get applications -n argocd

# Force sync if needed
argocd app sync bookinfo
```

### Manual Deployment

```bash
# Apply all manifests in order
kubectl apply -f namespace.yaml
kubectl apply -f bookinfo.yaml
kubectl apply -f destination-rules.yaml
kubectl apply -f gateway.yaml
kubectl apply -f virtualservice.yaml

# Wait for pods to be ready (2/2 indicates sidecar injected)
kubectl get pods -n bookinfo -w
```

## Accessing the Application

After deployment, access the productpage at:

```
http://localhost/productpage
```

Refresh the page multiple times to see different reviews versions (round-robin by default).

## Traffic Management Examples

### Route All Traffic to v1 (No Ratings)

Edit `virtualservice.yaml` and update the reviews VirtualService:

```yaml
spec:
  hosts:
    - reviews
  http:
    - route:
        - destination:
            host: reviews
            subset: v1
```

### 50/50 Split Between v2 and v3

```yaml
spec:
  hosts:
    - reviews
  http:
    - route:
        - destination:
            host: reviews
            subset: v2
          weight: 50
        - destination:
            host: reviews
            subset: v3
          weight: 50
```

### Canary Release (90/10 Split)

```yaml
spec:
  hosts:
    - reviews
  http:
    - route:
        - destination:
            host: reviews
            subset: v1
          weight: 90
        - destination:
            host: reviews
            subset: v3
          weight: 10
```

### A/B Testing (Route by User Header)

```yaml
spec:
  hosts:
    - reviews
  http:
    - match:
        - headers:
            end-user:
              exact: jason
      route:
        - destination:
            host: reviews
            subset: v3
    - route:
        - destination:
            host: reviews
            subset: v1
```

Test with: Login as "jason" on the productpage to see v3 (red stars).

### Fault Injection (Add Delay)

```yaml
spec:
  hosts:
    - ratings
  http:
    - fault:
        delay:
          percentage:
            value: 100
          fixedDelay: 7s
      route:
        - destination:
            host: ratings
            subset: v1
```

### Fault Injection (Return Error)

```yaml
spec:
  hosts:
    - ratings
  http:
    - fault:
        abort:
          percentage:
            value: 100
          httpStatus: 500
      route:
        - destination:
            host: ratings
            subset: v1
```

## Verification Commands

```bash
# Check all pods are running (should show 2/2 for sidecar)
kubectl get pods -n bookinfo

# Check services
kubectl get svc -n bookinfo

# Check Istio configuration
istioctl analyze -n bookinfo

# Test internal connectivity
kubectl exec -n bookinfo deploy/productpage-v1 -c productpage \
  -- curl -s http://details:9080/details/0 | head -20

# Check proxy status
istioctl proxy-status

# View Envoy routes
istioctl proxy-config routes deploy/productpage-v1 -n bookinfo
```

## Observability

### View Access Logs

```bash
# Productpage logs
kubectl logs -n bookinfo -l app=productpage -c istio-proxy -f

# Ingress gateway logs
kubectl logs -n istio-system -l app=istio-ingressgateway -f
```

### Tracing (if Jaeger is installed)

```bash
istioctl dashboard jaeger
```

### Metrics (if Prometheus/Grafana are installed)

```bash
istioctl dashboard grafana
```

## Resource Usage

Each service is configured with minimal resources for the learning environment:

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 10m | 100m |
| Memory | 64Mi | 128Mi |

Total for all 6 pods: ~60m CPU, ~384Mi memory (plus sidecar overhead)

## Cleanup

```bash
# Delete the namespace (removes everything)
kubectl delete namespace bookinfo

# Or delete via ArgoCD
argocd app delete bookinfo
```

## Troubleshooting

### Pods Stuck at 1/2 Ready

Sidecar not injecting. Check:

```bash
# Verify namespace label
kubectl get namespace bookinfo -L istio-injection

# Should show: istio-injection=enabled
# If not:
kubectl label namespace bookinfo istio-injection=enabled --overwrite
kubectl rollout restart deployment -n bookinfo
```

### 503 Service Unavailable

```bash
# Check if pods are running
kubectl get pods -n bookinfo

# Check Envoy configuration
istioctl analyze -n bookinfo

# Check destination rules exist
kubectl get destinationrules -n bookinfo
```

### Gateway Not Working

```bash
# Check gateway is created
kubectl get gateway -n bookinfo

# Check ingress gateway pods
kubectl get pods -n istio-system -l app=istio-ingressgateway

# Check gateway logs
kubectl logs -n istio-system -l app=istio-ingressgateway
```
