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
- **Port Mappings**: 80, 443 (for Istio ingress gateway)

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

The control-plane node exposes ports for Istio ingress:

| Host Port | Container Port | Purpose |
|-----------|----------------|---------|
| 80 | 80 | HTTP traffic |
| 443 | 443 | HTTPS traffic |

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
