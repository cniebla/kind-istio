# MetalLB - Load Balancer for kind

MetalLB provides `LoadBalancer` service support for the kind cluster. Without it, services of type `LoadBalancer` stay in `<pending>` forever because kind has no cloud provider to allocate IPs.

## How It Works

MetalLB operates in **L2 mode** for this environment:
1. The **controller** watches for `LoadBalancer` services and assigns IPs from the pool
2. The **speaker** announces the assigned IP via ARP on the Docker bridge network
3. Services get a real external IP reachable from within the Docker network

## Components

| File | Description |
|------|-------------|
| `ip-address-pool.yaml` | `IPAddressPool` + `L2Advertisement` (default range: `172.18.255.200-172.18.255.250`) |
| `kustomization.yaml` | Kustomize config for ArgoCD |

## ArgoCD Applications

MetalLB is split into two ArgoCD apps to handle CRD ordering:

| App | Source | Sync Wave | Purpose |
|-----|--------|-----------|---------|
| `metallb` | Helm chart `0.14.9` | 0 | Installs controller, speaker, CRDs |
| `metallb-config` | `infrastructure/metallb/` | 1 | Applies `IPAddressPool` and `L2Advertisement` |

The sync wave ordering ensures CRDs exist before pool config is applied.

## IP Address Pool

The default pool (`172.18.255.200-172.18.255.250`) works for most kind setups where Docker uses the `172.18.0.0/16` subnet. If your Docker network uses a different subnet, run the auto-configure script:

```bash
./scripts/configure-metallb.sh
```

The script detects the `kind` Docker network subnet and applies the correct range imperatively.

### Checking Your Subnet

```bash
docker network inspect kind --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'
```

## Verifying MetalLB

```bash
# Check MetalLB pods
kubectl get pods -n metallb-system

# Check the IP pool
kubectl get ipaddresspool -n metallb-system

# Verify a LoadBalancer service gets an IP
kubectl get svc --all-namespaces | grep LoadBalancer
```

## Using LoadBalancer Services

Any service set to `type: LoadBalancer` will now get an external IP:

```yaml
spec:
  type: LoadBalancer  # Gets an IP from MetalLB pool
```

### Istio Ingress Gateway

To switch the Istio ingress gateway from `NodePort` to `LoadBalancer`, update `infrastructure/istio/istio-operator.yaml`:

```yaml
ingressGateways:
  - name: istio-ingressgateway
    k8s:
      service:
        type: LoadBalancer  # Change from NodePort
        # Remove the nodePort fields
```

Then reinstall Istio: `istioctl install -f infrastructure/istio/istio-operator.yaml -y`

> **Note for macOS**: MetalLB IPs are within the Docker bridge network. Accessing them directly from macOS requires routing into the Docker VM. Use `kubectl port-forward` or the existing kind port mappings for host access.

## Troubleshooting

```bash
# Controller logs
kubectl logs -n metallb-system -l app=metallb,component=controller

# Speaker logs
kubectl logs -n metallb-system -l app=metallb,component=speaker

# Check L2 advertisement
kubectl get l2advertisement -n metallb-system
```
