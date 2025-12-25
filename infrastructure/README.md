# Infrastructure Components

Platform-level components that provide the foundation for application workloads.

## Components

| Component | Directory | Description |
|-----------|-----------|-------------|
| Istio | `istio/` | Service mesh for traffic management and observability |
| ArgoCD | `argocd/` | GitOps continuous delivery |

## Installation Order

1. **Istio** - Install first (provides ingress gateway and service mesh)
2. **ArgoCD** - Install second (manages application deployments)

## Istio

Service mesh providing:
- Traffic management (routing, load balancing)
- Security (mTLS, authorization policies)
- Observability (metrics, tracing, logging)

See [istio/README.md](istio/README.md) for details.

## ArgoCD

GitOps controller providing:
- Declarative application deployment
- Automated sync from Git repository
- Application health monitoring
- Rollback capabilities

See [argocd/README.md](argocd/README.md) for details.

## Namespace Layout

| Namespace | Purpose |
|-----------|---------|
| `istio-system` | Istio control plane components |
| `argocd` | ArgoCD server and controllers |
| `bookinfo` | Demo application (Istio sidecar injection enabled) |
