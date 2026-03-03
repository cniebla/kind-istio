# ArgoCD GitOps Controller

ArgoCD v3.2.3 installation and configuration for GitOps-based deployments.

## Files

| File | Description |
|------|-------------|
| `namespace.yaml` | ArgoCD namespace definition |
| `install.yaml` | Installation info (actual manifest fetched from GitHub) |
| `apps/root-app.yaml` | Root Application (App of Apps pattern) |
| `apps/metallb-app.yaml` | MetalLB installation (Helm, sync wave 0) |
| `apps/metallb-config-app.yaml` | MetalLB IP pool configuration (sync wave 1) |
| `apps/bookinfo-app.yaml` | Bookinfo application definition |
| `apps/observability-app.yaml` | Observability stack (Prometheus, Grafana, Kiali, Jaeger) |

## Quick Start

```bash
# Initialize ArgoCD with repository credentials
./scripts/init-argocd.sh

# Get admin password
./scripts/get-argocd-password.sh

# Access UI
./scripts/port-forward.sh
# Open https://localhost:8081
```

## Installation Details

The `init-argocd.sh` script:

1. Creates the `argocd` namespace
2. Installs ArgoCD v3.2.3 from official manifest
3. Waits for all pods to be ready
4. Configures repository credentials (SSH or token)
5. Applies the root Application

### Manual Installation

```bash
# Create namespace
kubectl apply -f infrastructure/argocd/namespace.yaml

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.2.3/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

## Repository Authentication

This repository is public on HTTPS — ArgoCD can sync without credentials. Select **"Skip"** at the credentials prompt in `init-argocd.sh`.

Credentials are only needed if you switch to a private fork or SSH-based access.

### Option 1: SSH Key (Recommended)

```bash
# Using init script
./scripts/init-argocd.sh --ssh-key ~/.ssh/id_ed25519

# Or manually
kubectl create secret generic repo-creds \
  -n argocd \
  --from-file=sshPrivateKey=~/.ssh/id_ed25519 \
  --from-literal=url=git@github.com:cniebla/kind-istio.git \
  --from-literal=type=git

kubectl label secret repo-creds -n argocd \
  argocd.argoproj.io/secret-type=repository
```

### Option 2: GitHub Token

```bash
# Using init script
./scripts/init-argocd.sh --token ghp_xxxxxxxxxxxx

# Or manually
kubectl create secret generic repo-creds \
  -n argocd \
  --from-literal=url=https://github.com/cniebla/kind-istio.git \
  --from-literal=username=cniebla \
  --from-literal=password=<github-pat> \
  --from-literal=type=git

kubectl label secret repo-creds -n argocd \
  argocd.argoproj.io/secret-type=repository
```

## App of Apps Pattern

This project uses the App of Apps pattern for managing deployments:

```
root-app (infrastructure/argocd/apps/)
├── root-app.yaml           → Manages this directory (self-referential)
├── metallb-app.yaml        → Installs MetalLB via Helm (wave 0)
├── metallb-config-app.yaml → Configures IP address pool (wave 1)
├── bookinfo-app.yaml       → Deploys apps/bookinfo/
└── observability-app.yaml  → Deploys Prometheus, Grafana, Kiali, Jaeger
```

### How It Works

1. `root-app` points to `infrastructure/argocd/apps/` directory
2. Any Application YAML in that directory is automatically deployed
3. Each Application points to its own path (e.g., `apps/bookinfo/`)
4. Changes to Git automatically sync to the cluster

### Adding New Applications

1. Create manifests in `apps/<app-name>/`
2. Create `infrastructure/argocd/apps/<app-name>-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <app-name>
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: git@github.com:cniebla/kind-istio.git
    targetRevision: HEAD
    path: apps/<app-name>
  destination:
    server: https://kubernetes.default.svc
    namespace: <app-namespace>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

3. Commit and push - ArgoCD will auto-deploy!

## Accessing the UI

### Port Forward (Development)

```bash
# Using helper script
./scripts/port-forward.sh

# Or directly
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

Then open: https://localhost:8081

### Credentials

```bash
# Get initial admin password
./scripts/get-argocd-password.sh

# Or manually
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

- **Username:** `admin`
- **Password:** (from command above)

## ArgoCD CLI

```bash
# Install CLI (if not already installed)
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/v3.2.3/argocd-linux-amd64
chmod +x argocd && sudo mv argocd /usr/local/bin/

# Login (with port-forward running)
argocd login localhost:8081 --username admin --password '<password>' --insecure

# List applications
argocd app list

# Sync an application
argocd app sync bookinfo

# Get application details
argocd app get bookinfo
```

## Useful Commands

```bash
# List all applications
kubectl get applications -n argocd

# Describe an application
kubectl describe application bookinfo -n argocd

# Check sync status
kubectl get applications -n argocd -o wide

# Force refresh from Git
argocd app refresh root

# Manual sync
argocd app sync bookinfo

# View application logs
argocd app logs bookinfo
```

## Sync Policies

Applications are configured with:

| Policy | Value | Description |
|--------|-------|-------------|
| `automated.prune` | `true` | Delete resources removed from Git |
| `automated.selfHeal` | `true` | Revert manual changes to match Git |
| `CreateNamespace` | `true` | Create namespace if missing |

## Troubleshooting

### Application Not Syncing

```bash
# Check application status
kubectl describe application <app-name> -n argocd

# Check ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Verify repository connection
argocd repo list
```

### Repository Access Issues

```bash
# Check repo credentials secret
kubectl get secret repo-creds -n argocd -o yaml

# Test SSH connection (if using SSH)
ssh -T git@github.com

# Verify secret is labeled correctly
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository
```

### Pods Not Starting

```bash
# Check all ArgoCD pods
kubectl get pods -n argocd

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Check specific pod logs
kubectl logs -n argocd <pod-name>
```

## Uninstall

```bash
# Delete all applications first
kubectl delete applications --all -n argocd

# Delete ArgoCD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.2.3/manifests/install.yaml

# Delete namespace
kubectl delete namespace argocd
```
