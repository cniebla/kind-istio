# Helper Scripts

Utility scripts for cluster and application management.

## Scripts

| Script | Description |
|--------|-------------|
| `init-argocd.sh` | Install ArgoCD and configure repository credentials |
| `get-argocd-password.sh` | Retrieve ArgoCD admin password |
| `port-forward.sh` | Start port forwarding for ArgoCD UI |
| `observability-ui.sh` | Port-forward all observability UIs (Grafana, Prometheus, etc.) |
| `configure-metallb.sh` | Auto-detect Docker subnet and configure MetalLB IP address pool |
| `test-setup.sh` | Validate the entire setup (cluster, Istio, ArgoCD, Bookinfo) |

## init-argocd.sh

Installs ArgoCD and configures access to the private repository.

```bash
# Interactive mode (prompts for credentials)
./init-argocd.sh

# With SSH key
./init-argocd.sh --ssh-key ~/.ssh/id_ed25519

# With GitHub token
./init-argocd.sh --token ghp_xxxxxxxxxxxx
```

### What it does

1. Creates the `argocd` namespace
2. Installs ArgoCD v3.2.3
3. Waits for all pods to be ready
4. Configures repository credentials
5. Applies the root Application
6. Displays access instructions

## get-argocd-password.sh

Retrieves the initial ArgoCD admin password.

```bash
./get-argocd-password.sh
```

## port-forward.sh

Starts port forwarding for accessing ArgoCD and Bookinfo.

```bash
./port-forward.sh

# Access points:
# - ArgoCD UI: https://localhost:8081
# - Bookinfo: http://localhost (via Istio ingress)
```

## observability-ui.sh

Port-forwards all observability UIs for local access.

```bash
# Forward all UIs
./observability-ui.sh

# Forward specific services
./observability-ui.sh --grafana
./observability-ui.sh --prometheus
./observability-ui.sh --kiali
./observability-ui.sh --jaeger
./observability-ui.sh --loki
```

### Access Points

| Service | URL | Description |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | Dashboards & Loki logs (admin/admin) |
| Prometheus | http://localhost:9091 | Metrics queries |
| Kiali | http://localhost:20001 | Service mesh console |
| Jaeger | http://localhost:16686 | Distributed tracing |
| Loki | http://localhost:3100 | Log aggregation API |

## configure-metallb.sh

Auto-detects the kind Docker network subnet and configures MetalLB's IP address pool.

```bash
./configure-metallb.sh
```

### What it does

1. Inspects the `kind` Docker network to determine the subnet (e.g. `172.18.0.0/16`)
2. Computes a safe IP range at the top of that subnet (e.g. `172.18.255.200-172.18.255.250`)
3. Waits for the MetalLB controller to be ready
4. Applies the `IPAddressPool` and `L2Advertisement` resources

Run this once after MetalLB is deployed by ArgoCD. Required if your Docker network uses a non-default subnet.

## test-setup.sh

Validates the entire environment setup.

```bash
# Basic test (no HTTP calls)
./test-setup.sh

# Full test including HTTP access tests
./test-setup.sh --full
```

### What it tests

1. **Prerequisites**: Docker, Kind, kubectl, istioctl
2. **Cluster**: Kind cluster exists, nodes ready
3. **Istio**: Namespace, Istiod, ingress gateway, installation verification
4. **ArgoCD**: Namespace, pods, applications, sync status
5. **Bookinfo**: Namespace, pods with sidecars, services, Istio resources
6. **HTTP Access** (--full): Productpage access, internal connectivity

## Making Scripts Executable

```bash
chmod +x *.sh
```
