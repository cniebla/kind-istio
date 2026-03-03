# Istio Service Mesh

Istio v1.28.2 installation and configuration for Kind cluster.

## Files

| File | Description |
|------|-------------|
| `istio-operator.yaml` | IstioOperator manifest (demo profile) |

## Prerequisites

Ensure istioctl is installed:

```bash
# Check version
istioctl version

# If not installed:
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.28.2 sh -
sudo mv istio-1.28.2/bin/istioctl /usr/local/bin/
```

## Installation

```bash
# 1. Install Istio using the operator manifest
istioctl install -f infrastructure/istio/istio-operator.yaml -y

# 2. Verify control plane is responding
istioctl proxy-status

# 3. Check Istio pods are running
kubectl get pods -n istio-system

# 4. Analyze configuration (optional)
istioctl analyze -n istio-system
```

### Expected Pods

After installation, you should see:

```
NAME                                    READY   STATUS
istio-egressgateway-xxxxxxxxx-xxxxx     1/1     Running
istio-ingressgateway-xxxxxxxxx-xxxxx    1/1     Running
istiod-xxxxxxxxx-xxxxx                  1/1     Running
```

## Profile: Demo

Using the `demo` profile optimized for learning:

| Component | Purpose | Resource Limits |
|-----------|---------|-----------------|
| Istiod | Control plane | 500m CPU, 512Mi memory |
| Ingress Gateway | External traffic entry | 500m CPU, 256Mi memory |
| Egress Gateway | External traffic exit | 200m CPU, 256Mi memory |
| Sidecar Proxy | Per-pod proxy | 200m CPU, 256Mi memory |

### Features Enabled

- Access logging to stdout (all requests logged)
- 100% trace sampling (for learning/debugging)
- Outbound traffic: ALLOW_ANY mode

## Enable Sidecar Injection

Label namespaces for automatic sidecar injection:

```bash
# Enable for a namespace
kubectl label namespace <namespace> istio-injection=enabled

# Verify label
kubectl get namespace -L istio-injection
```

## Accessing Services via Ingress

The ingress gateway uses `type: LoadBalancer`. MetalLB assigns it an external IP from the Docker bridge network.

```bash
# Get the external IP
kubectl get svc istio-ingressgateway -n istio-system

# Example output:
# NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)
# istio-ingressgateway   LoadBalancer   10.96.x.x       172.18.255.200   80.../443...
```

Traffic flow: `client -> MetalLB IP (L2 ARP) -> IngressGateway pod -> service mesh`

**macOS note**: The MetalLB IP lives on the Docker bridge network inside the Linux VM. It is reachable from within kind containers but not directly from the macOS host. Use `kubectl port-forward` for local browser access:

```bash
kubectl port-forward svc/istio-ingressgateway -n istio-system 8888:80
# Then open: http://localhost:8888/productpage
```

## Configuration Details

### istio-operator.yaml

Key configurations:

```yaml
# Access logging format
accessLogFile: /dev/stdout

# Full tracing for learning
tracing:
  sampling: 100.0

# Ingress gateway: LoadBalancer type (MetalLB assigns external IP)
service:
  type: LoadBalancer
```

## Useful Commands

```bash
# Check proxy status (all sidecars)
istioctl proxy-status

# Analyze configuration issues
istioctl analyze

# Analyze specific namespace
istioctl analyze -n bookinfo

# View Envoy routes for a pod
istioctl proxy-config routes deploy/productpage-v1 -n bookinfo

# View Envoy clusters
istioctl proxy-config clusters deploy/productpage-v1 -n bookinfo

# View Envoy listeners
istioctl proxy-config listeners deploy/productpage-v1 -n bookinfo

# Debug sidecar injection
istioctl analyze -n <namespace>
```

## Observability Dashboards

Istio demo profile includes addons. To access:

```bash
# Kiali (service mesh dashboard)
istioctl dashboard kiali

# Jaeger (distributed tracing)
istioctl dashboard jaeger

# Grafana (metrics)
istioctl dashboard grafana

# Prometheus (metrics database)
istioctl dashboard prometheus
```

## Troubleshooting

```bash
# Check ingress gateway logs
kubectl logs -n istio-system -l app=istio-ingressgateway -f

# Check istiod logs
kubectl logs -n istio-system -l app=istiod -f

# Verify mTLS is working
istioctl authn tls-check <pod-name>.<namespace>

# Check if sidecar is injected (should show 2/2)
kubectl get pods -n <namespace>

# Force sidecar injection restart
kubectl rollout restart deployment -n <namespace>
```

## Uninstall

```bash
# Remove Istio
istioctl uninstall --purge -y

# Remove namespace
kubectl delete namespace istio-system
```
