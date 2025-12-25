# Kind + Istio + ArgoCD Learning Project Plan

## Project Overview

A local Kubernetes learning environment using Kind, with Istio service mesh and ArgoCD for GitOps-based deployments. The repo serves as both the infrastructure definition and the application source for ArgoCD.

**Repository:** `github.com/cniebla/kind-istio` (private)

---

## Version Matrix (as of December 2025)

| Component | Version | Notes |
|-----------|---------|-------|
| **Kubernetes** | v1.34.3 | User requested v1.34.2; Kind has v1.34.3 available. Latest is v1.35.0 |
| **Kind** | v0.31.0 | Supports K8s 1.31 through 1.35 |
| **Istio** | 1.28.2 | Supports K8s 1.30-1.34. **Does NOT support K8s 1.35 yet** |
| **ArgoCD** | v3.2.3 | Latest stable (v3.3.0 is RC) |

### Recommended Configuration
Using **Kubernetes v1.34.3** because:
- Istio 1.28.x officially supports up to K8s 1.34 (not 1.35 yet)
- Stable and well-tested combination
- Kind node image: `kindest/node:v1.34.3@sha256:08497ee19eace7b4b5348db5c6a1591d7752b164530a36f855cb0f2bdcbadd48`

> **Alternative:** If you want the latest K8s (v1.35.0), wait for Istio 1.29 or use Istio with unsupported K8s version (may have issues).

---

## Resource Optimization (32GB RAM)

This configuration is optimized for a development machine with 32GB RAM:

| Optimization | Description |
|--------------|-------------|
| **Single worker node** | Reduced from 2 workers to 1 (sufficient for learning) |
| **Istio demo profile** | Higher observability, acceptable for 32GB |
| **Docker resource limits** | Recommend allocating 16GB to Docker |
| **No replicas** | Single replica per service for demo apps |

### Estimated Resource Usage
| Component | Memory (approx) |
|-----------|-----------------|
| Kind control-plane | ~1.5 GB |
| Kind worker node | ~1.0 GB |
| Istio (demo profile) | ~2.0 GB |
| ArgoCD | ~0.5 GB |
| Bookinfo app | ~0.5 GB |
| **Total** | **~5.5 GB** |

> With 32GB RAM, you have plenty of headroom. The single worker configuration keeps things simple while leaving resources for other applications.

---

## Directory Structure

```
kind-istio/
├── .claude/
│   ├── plan.md                    # This plan document
│   └── guidelines.md              # Development guidelines
├── .gitignore
├── README.md                      # Project overview and quick start
│
├── cluster/
│   ├── README.md                  # Cluster setup documentation
│   ├── kind-config.yaml           # Kind cluster configuration
│   ├── start.sh                   # Start/create cluster script
│   ├── stop.sh                    # Stop/delete cluster script
│   └── status.sh                  # Check cluster status
│
├── infrastructure/
│   ├── README.md                  # Infrastructure components docs
│   ├── istio/
│   │   ├── README.md              # Istio setup documentation
│   │   ├── istio-operator.yaml    # Istio installation manifest
│   │   └── gateway/
│   │       └── default-gateway.yaml
│   └── argocd/
│       ├── README.md              # ArgoCD setup documentation
│       ├── namespace.yaml
│       ├── install.yaml           # ArgoCD installation
│       ├── argocd-cm.yaml         # ArgoCD ConfigMap (repo config)
│       └── apps/
│           └── root-app.yaml      # App of Apps pattern
│
├── apps/
│   ├── README.md                  # Applications documentation
│   └── bookinfo/
│       ├── README.md              # Bookinfo app documentation
│       ├── namespace.yaml         # bookinfo namespace with istio-injection
│       ├── bookinfo.yaml          # All Bookinfo deployments & services
│       ├── gateway.yaml           # Istio Gateway for external access
│       ├── virtualservice.yaml    # Routing to productpage
│       └── destination-rules.yaml # Service versions (v1, v2, v3)
│
└── scripts/
    ├── README.md
    ├── init-argocd.sh             # Initialize ArgoCD with repo
    ├── get-argocd-password.sh     # Retrieve initial admin password
    └── port-forward.sh            # Port forwarding helper
```

---

## Implementation Phases

### Phase 1: Repository Setup [COMPLETED]
- [x] Create directory structure
- [x] Add `.gitignore` (ignore local secrets, kubeconfig, etc.)
- [x] Create root `README.md` with project overview
- [x] Create README.md files for each major directory

### Phase 2: Kind Cluster Configuration [COMPLETED]
- [x] Create `cluster/kind-config.yaml` with:
  - Optimized setup (1 control-plane, 1 worker) for 32GB RAM
  - Extra port mappings for Istio ingress (80, 443)
  - Kubernetes v1.34.3 image (`kindest/node:v1.34.3`)
- [x] Create `cluster/start.sh`:
  - Check if cluster exists
  - Create cluster with config
  - Wait for nodes to be ready
- [x] Create `cluster/stop.sh`:
  - Delete the kind cluster
  - Clean up contexts
- [x] Create `cluster/status.sh`:
  - Show cluster info and node status

### Phase 3: Istio Installation (v1.28.2) [COMPLETED]
- [x] Create Istio operator manifest (`infrastructure/istio/istio-operator.yaml`):
  - Use `demo` profile for learning
  - Enable access logging
  - Configure ingress gateway
- [x] Document installation steps in `infrastructure/istio/README.md`
- [x] Create default gateway configuration

### Phase 4: ArgoCD Setup [COMPLETED]
- [x] Create ArgoCD namespace manifest
- [x] Create ArgoCD installation manifest (v3.2.3 stable release)
- [x] Create `scripts/init-argocd.sh`:
  - Install ArgoCD
  - Wait for pods to be ready
  - Configure private repo access (SSH key or HTTPS token)
  - Apply root application
- [x] Create `scripts/get-argocd-password.sh`
- [x] Create `scripts/port-forward.sh` for ArgoCD UI access
- [x] Implement App of Apps pattern for managing all applications

### Phase 5: Bookinfo Application (Istio Demo App) [COMPLETED]
- [x] Create `apps/bookinfo/namespace.yaml` with `istio-injection: enabled` label
- [x] Create `apps/bookinfo/bookinfo.yaml` (from Istio samples, adapted for GitOps):
  - **productpage** (Python): Main UI, calls details and reviews
  - **details** (Ruby): Book details service
  - **reviews** (Java): Three versions (v1: no ratings, v2: black stars, v3: red stars)
  - **ratings** (Node.js): Star ratings service
- [x] Create `apps/bookinfo/gateway.yaml`: Istio Gateway for external access
- [x] Create `apps/bookinfo/virtualservice.yaml`: Route traffic to productpage
- [x] Create `apps/bookinfo/destination-rules.yaml`: Define service subsets (v1, v2, v3)
- [x] Create ArgoCD Application manifest for Bookinfo
- [x] Document Bookinfo architecture in `apps/bookinfo/README.md`

### Phase 6: Testing & Validation [COMPLETED]
- [x] Test cluster creation/deletion cycle
- [x] Verify Istio installation and sidecar injection
- [x] Verify ArgoCD syncs from GitHub repo
- [x] Access Bookinfo productpage via Istio ingress gateway
- [x] Verify all Bookinfo services are running (4 services, 6 pods with sidecars)
- [x] Test traffic routing between reviews versions
- [x] Created `scripts/test-setup.sh` for automated validation

---

## Key Configuration Details

### Kind Cluster Config (cluster/kind-config.yaml)
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: istio-learning
nodes:
  - role: control-plane
    image: kindest/node:v1.34.3@sha256:08497ee19eace7b4b5348db5c6a1591d7752b164530a36f855cb0f2bdcbadd48
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
  # Single worker node (optimized for 32GB RAM learning environment)
  - role: worker
    image: kindest/node:v1.34.3@sha256:08497ee19eace7b4b5348db5c6a1591d7752b164530a36f855cb0f2bdcbadd48
```

### Bookinfo Application Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    Istio Ingress Gateway                     │
│                      (port 80/443)                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   productpage   │  (Python)
                    │    v1           │  Main UI
                    └─────────────────┘
                       │           │
            ┌──────────┘           └──────────┐
            ▼                                 ▼
    ┌─────────────┐                  ┌─────────────┐
    │   details   │                  │   reviews   │
    │     v1      │                  │ v1/v2/v3    │ (Java)
    │   (Ruby)    │                  └─────────────┘
    └─────────────┘                        │
                                           ▼
                                  ┌─────────────┐
                                  │   ratings   │
                                  │     v1      │ (Node.js)
                                  └─────────────┘

Reviews versions:
  v1: No ratings (no call to ratings service)
  v2: Black star ratings ★★★★★
  v3: Red star ratings ★★★★★
```

### ArgoCD Private Repo Access
Options for GitHub private repo authentication:
1. **SSH Key** (recommended): Generate deploy key, add to GitHub, create Secret in ArgoCD
2. **HTTPS Token**: Use GitHub PAT with repo access, configure in ArgoCD

---

## Scripts Behavior

### start.sh
```
Usage: ./cluster/start.sh
- Creates Kind cluster named "istio-learning"
- Uses kind-config.yaml for configuration
- Waits for all nodes to be Ready
- Displays cluster info on success
```

### stop.sh
```
Usage: ./cluster/stop.sh
- Deletes the "istio-learning" Kind cluster
- Removes kubectl context
```

### init-argocd.sh
```
Usage: ./scripts/init-argocd.sh [--ssh-key <path>] [--token <github-token>]
- Installs ArgoCD to argocd namespace
- Waits for ArgoCD to be ready
- Configures repo credentials (interactive if not provided)
- Applies root Application
- Displays admin password and port-forward instructions
```

---

## Learning Objectives

After completing this project, you will understand:
1. **Kind**: Local Kubernetes cluster management
2. **Istio**: Service mesh concepts (traffic management, observability)
3. **ArgoCD**: GitOps principles, declarative configuration
4. **App of Apps**: Managing multiple applications with ArgoCD
5. **Best Practices**: Directory structure, documentation, automation
6. **Bookinfo Demo**: Multi-service polyglot application patterns

### Istio Concepts to Explore with Bookinfo
| Concept | How to Practice |
|---------|-----------------|
| **Traffic Shifting** | Route 80% to reviews-v1, 20% to reviews-v3 |
| **Canary Releases** | Gradually shift traffic to new versions |
| **A/B Testing** | Route based on headers (e.g., user identity) |
| **Fault Injection** | Add delays or errors to test resilience |
| **Circuit Breaking** | Limit connections to prevent cascading failures |
| **mTLS** | Verify encrypted service-to-service communication |

---

## Prerequisites (to verify before starting)

- [ ] Docker installed and running
- [ ] Kind CLI installed v0.31.0+ (`kind version`)
- [ ] kubectl installed v1.34+ (`kubectl version --client`)
- [ ] Helm installed (optional, for some installations)
- [ ] GitHub CLI or SSH key configured for private repo access
- [ ] istioctl installed v1.28.2 (`istioctl version`)

### Installation Commands (if needed)
```bash
# Kind (Linux)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# istioctl
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.28.2 sh -
sudo mv istio-1.28.2/bin/istioctl /usr/local/bin/

# ArgoCD CLI (optional)
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/v3.2.3/argocd-linux-amd64
chmod +x argocd && sudo mv argocd /usr/local/bin/
```

---

## Next Steps

1. Review and adjust this plan as needed
2. Start with Phase 1 (repository setup)
3. Progress through phases sequentially
4. Commit changes frequently to practice GitOps workflow
