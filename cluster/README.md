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
- **Port Mappings**: 8888/8443 (host), 30000/30001 (NodePort for Istio ingress)

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

The control-plane node exposes ports for Istio ingress gateway:

| Host Port | Container Port | Purpose |
|-----------|----------------|---------|
| 8888 | 80 | HTTP traffic (alternative to 80 if in use) |
| 8443 | 443 | HTTPS traffic (alternative to 443 if in use) |
| 30000 | 30000 | NodePort for HTTP (recommended) |
| 30001 | 30001 | NodePort for HTTPS |

**Note**: Use `http://localhost:30000` for accessing services through Istio ingress.

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
