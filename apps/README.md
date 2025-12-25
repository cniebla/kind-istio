# Applications

Application workloads deployed via ArgoCD.

## Applications

| Application | Directory | Description |
|-------------|-----------|-------------|
| Bookinfo | `bookinfo/` | Istio demo application |

## Bookinfo

The [Bookinfo](https://istio.io/latest/docs/examples/bookinfo/) sample application demonstrates Istio capabilities with a polyglot microservices architecture.

### Services

| Service | Language | Description |
|---------|----------|-------------|
| productpage | Python | Main UI, orchestrates calls to other services |
| details | Ruby | Book details (ISBN, pages, publisher) |
| reviews | Java | Book reviews, has 3 versions |
| ratings | Node.js | Star ratings for reviews |

### Reviews Versions

| Version | Behavior |
|---------|----------|
| v1 | No ratings (doesn't call ratings service) |
| v2 | Black star ratings |
| v3 | Red star ratings |

### Architecture

```
                    ┌─────────────┐
                    │ productpage │
                    └─────────────┘
                      │         │
           ┌──────────┘         └──────────┐
           ▼                               ▼
    ┌─────────────┐                ┌─────────────┐
    │   details   │                │   reviews   │
    └─────────────┘                │  v1/v2/v3   │
                                   └─────────────┘
                                         │
                                         ▼
                                  ┌─────────────┐
                                  │   ratings   │
                                  └─────────────┘
```

See [bookinfo/README.md](bookinfo/README.md) for deployment details.

## Adding New Applications

1. Create a new directory under `apps/`
2. Add Kubernetes manifests (namespace, deployments, services)
3. Add Istio resources (VirtualService, DestinationRule) if needed
4. Create an ArgoCD Application manifest in `infrastructure/argocd/apps/`
