# Cluster Configuration

Kind cluster configuration and lifecycle management scripts.

## Files

| File | Description |
|------|-------------|
| `kind-config.yaml` | Kind cluster configuration (1 control-plane, 1 worker) |
| `start.sh` | Create and start the cluster |
| `stop.sh` | Delete the cluster |
| `status.sh` | Show cluster status and node info |

## Cluster Specifications

- **Name**: `istio-learning`
- **Kubernetes Version**: v1.34.3
- **Nodes**: 1 control-plane + 1 worker (optimized for 32GB RAM)
- **Port Mappings**: 8888→80, 8443→443 (host port mappings for direct container access)

## Usage

```bash
# Create cluster
./start.sh

# Check status
./status.sh

# Delete cluster
./stop.sh
```

## Port Mappings

The control-plane node has host port mappings for direct container access:

| Host Port | Container Port | Purpose |
|-----------|----------------|---------|
| 8888 | 80 | HTTP (fallback if MetalLB IP is unreachable from host) |
| 8443 | 443 | HTTPS (fallback) |

**Note**: The Istio ingress gateway uses `type: LoadBalancer`. MetalLB assigns it an IP from the Docker bridge network (e.g. `172.18.255.200`). That IP is reachable from inside the cluster and from within kind containers, but not directly from the macOS host. Use `kubectl port-forward` for host access.

## Troubleshooting

```bash
# Check if cluster exists
kind get clusters

# Export cluster logs
kind export logs --name istio-learning ./cluster-logs

# Get node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system
```
