# Kind + Istio + ArgoCD Learning Environment

A local Kubernetes learning environment using Kind, with Istio service mesh and ArgoCD for GitOps-based deployments.

## Version Matrix

| Component | Version |
|-----------|---------|
| Kubernetes | v1.34.3 |
| Kind | v0.31.0 |
| Istio | 1.28.2 |
| ArgoCD | v3.2.3 |
| MetalLB | 0.14.9 |

## Prerequisites

- Docker installed and running
- [Kind](https://kind.sigs.k8s.io/) v0.31.0+
- [kubectl](https://kubernetes.io/docs/tasks/tools/) v1.34+
- [istioctl](https://istio.io/latest/docs/setup/getting-started/#download) v1.28.2

## Quick Start

```bash
# 1. Create the Kind cluster
./cluster/start.sh

# 2. Install Istio (gateway uses LoadBalancer type)
istioctl install -f infrastructure/istio/istio-operator.yaml -y

# 3. Initialize ArgoCD (select "Skip" at credentials prompt — public HTTPS repo)
./scripts/init-argocd.sh
# ArgoCD auto-deploys: MetalLB, bookinfo, observability

# 4. Configure MetalLB IP pool (run once after ArgoCD deploys MetalLB)
./scripts/configure-metallb.sh

# 5. Get the ingress gateway external IP
kubectl get svc istio-ingressgateway -n istio-system

# 6. Access bookinfo
# http://<EXTERNAL-IP>/productpage

# 7. Access ArgoCD UI
./scripts/port-forward.sh
# Open https://localhost:8081
```

## Project Structure

```
kind-istio/
├── cluster/          # Kind cluster configuration and lifecycle scripts
├── infrastructure/   # Platform components
│   ├── istio/        # Istio installation and gateway config
│   ├── argocd/       # ArgoCD installation and app definitions
│   ├── metallb/      # MetalLB IP pool configuration
│   └── observability/# Prometheus, Grafana, Kiali, Jaeger, Loki
├── apps/             # Application workloads
│   └── bookinfo/     # Istio Bookinfo demo application
└── scripts/          # Helper scripts
```

## Cluster Management

```bash
# Start/create cluster
./cluster/start.sh

# Check cluster status
./cluster/status.sh

# Stop/delete cluster
./cluster/stop.sh
```

## Bookinfo Demo Application

The [Bookinfo](https://istio.io/latest/docs/examples/bookinfo/) application demonstrates Istio features:

- **productpage**: Main UI (Python)
- **details**: Book information (Ruby)
- **reviews**: Book reviews with 3 versions (Java)
- **ratings**: Star ratings (Node.js)

Access after deployment:
```bash
export GW=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# http://$GW/productpage
```

## Learning Resources

- [Istio Documentation](https://istio.io/latest/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kind Documentation](https://kind.sigs.k8s.io/)
