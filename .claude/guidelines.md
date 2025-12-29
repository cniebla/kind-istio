# Project Guidelines

## General Principles

1. **Everything as Code**: All configurations must be version-controlled
2. **GitOps First**: Changes flow through Git, ArgoCD syncs to cluster
3. **Documentation**: Every directory with YAML files needs a README.md
4. **Idempotency**: Scripts should be safe to run multiple times

---

## File Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Kubernetes manifests | kebab-case | `my-deployment.yaml` |
| Shell scripts | kebab-case | `init-argocd.sh` |
| Directories | kebab-case | `demo-app/` |
| ConfigMaps/Secrets | component-suffix | `argocd-cm.yaml` |

---

## YAML Style Guide

```yaml
# Always use explicit apiVersion
apiVersion: v1
kind: ConfigMap

# Use 2-space indentation
metadata:
  name: example
  namespace: default    # Always specify namespace
  labels:
    app.kubernetes.io/name: example
    app.kubernetes.io/part-of: kind-istio

# Add comments for non-obvious configurations
spec:
  replicas: 2  # Minimum for HA
```

### Required Labels
All resources should include:
- `app.kubernetes.io/name`: Resource name
- `app.kubernetes.io/part-of`: `kind-istio`
- `app.kubernetes.io/managed-by`: `argocd` (for ArgoCD-managed resources)

---

## Shell Script Guidelines

```bash
#!/usr/bin/env bash
# Description: Brief description of what this script does
# Usage: ./script-name.sh [options]

set -euo pipefail  # Always use strict mode

# Constants at the top
readonly CLUSTER_NAME="istio-learning"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use functions for reusable logic
check_prerequisites() {
    command -v kind >/dev/null 2>&1 || { echo "kind is required"; exit 1; }
}

# Main logic at the bottom
main() {
    check_prerequisites
    # ... rest of script
}

main "$@"
```

---

## Directory-Specific Guidelines

### `/cluster`
- Kind configuration only
- Scripts for cluster lifecycle
- No application-specific content

### `/infrastructure`
- Platform components (Istio, ArgoCD, monitoring)
- Each component in its own subdirectory
- Installation order documented in README

### `/apps`
- Application workloads only
- Each app in its own directory
- Include all K8s resources needed for the app
- ArgoCD Application manifests live in `/infrastructure/argocd/apps/`

### `/scripts`
- Helper scripts that span multiple components
- Should be executable (`chmod +x`)
- Include usage instructions in comments

---

## Git Workflow

### Commit Messages
```
<type>: <short description>

[optional body]

Types:
- feat: New feature or component
- fix: Bug fix
- docs: Documentation only
- refactor: Code change that neither fixes nor adds
- chore: Maintenance tasks
```

### Branch Strategy (optional for learning)
- `main`: Stable, ArgoCD syncs from here
- `feature/*`: Development branches

---

## ArgoCD Application Structure

### App of Apps Pattern
```
infrastructure/argocd/apps/
├── root-app.yaml          # Points to this directory
├── istio-app.yaml         # Manages Istio installation
└── demo-app.yaml          # Manages demo application
```

### Application Template
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
    path: <path-to-manifests>
  destination:
    server: https://kubernetes.default.svc
    namespace: <target-namespace>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## Istio Guidelines

### Sidecar Injection
Enable per-namespace:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  labels:
    istio-injection: enabled
```

### VirtualService Naming
- Match the service name: `my-service-vs.yaml`
- Include hosts and routing rules

---

## Security Considerations

### Never Commit
- SSH private keys
- GitHub tokens/PATs
- Passwords or secrets in plaintext
- kubeconfig files

### .gitignore Should Include
```
*.pem
*.key
kubeconfig*
.env
secrets/
```

### Secrets Management
For learning: Use Kubernetes Secrets with manual creation
For production: Consider Sealed Secrets or external secret managers

---

## Testing Checklist

Before considering a phase complete:
- [ ] All manifests apply without errors
- [ ] Resources reach Ready/Running state
- [ ] Scripts run successfully on a fresh cluster
- [ ] README accurately reflects current state
- [ ] Changes committed and pushed

---

## Troubleshooting Tips

### Kind Issues
```bash
# Check cluster exists
kind get clusters

# Get cluster logs
kind export logs --name istio-learning

# Recreate from scratch
kind delete cluster --name istio-learning
./cluster/start.sh
```

### Istio Issues
```bash
# Check proxy status (control plane verification)
istioctl proxy-status

# Analyze configuration
istioctl analyze

# Check Istio pods
kubectl get pods -n istio-system
```

### ArgoCD Issues
```bash
# Check application status
kubectl get applications -n argocd

# View sync details
kubectl describe application <name> -n argocd

# Force refresh
argocd app refresh <name>
```
