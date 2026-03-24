# CC Fleet

Run Claude Code sessions across multiple repositories from a web dashboard.

## What is CC Fleet?

CC Fleet is a self-hosted platform that lets you:
- Run Claude Code tasks against one or more git repos simultaneously
- Monitor sessions in real-time via WebSocket streaming
- Answer Claude's questions through the dashboard
- Manage multiple concurrent sessions
- Restrict access to specific repos via allowlists
- Login with GitHub (OAuth) — the same credentials are used for git access
- Each user brings their own Anthropic API key (or use a shared platform key)

## Prerequisites

- Kubernetes cluster with an ingress controller (nginx-ingress, Traefik, etc.)
- Helm 3
- A domain name with DNS you control
- A GitHub account (for creating the OAuth App)

## Setup

### 1. GitHub OAuth App

Create a GitHub OAuth App at [github.com/settings/applications/new](https://github.com/settings/applications/new):

- **Homepage URL**: `https://<your-domain>`
- **Authorization callback URL**: `https://<your-domain>/api/auth/callback`

Note the **Client ID** and generate a **Client Secret**.

### 2. Create a values file

```yaml
# values-production.yaml

github:
  clientId: "<your-github-client-id>"
  clientSecret: "<your-github-client-secret>"

# Optional: platform-wide Anthropic key
# If omitted, each user sets their own key in the dashboard Settings page.
# anthropic:
#   apiKey: "sk-ant-..."

# Choose one ingress method:

# Option A: Standard Kubernetes Ingress
ingress:
  enabled: true
  host: "<your-domain>"
  tls:
    enabled: true
    secretName: cc-fleet-tls
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod

# Option B: Traefik IngressRoute
# ingressRoute:
#   enabled: true
#   host: "<your-domain>"
#   tls:
#     enabled: true
#     secretName: cc-fleet-tls
#     certIssuer: letsencrypt-prod

# Optional: restrict which repos can be cloned
# allowedRepos:
#   - "github.com/my-org/*"
```

### 3. Install

```bash
git clone https://github.com/BloomerAB/cc-fleet-chart.git
cd cc-fleet-chart

helm install cc-fleet . -n cc-fleet --create-namespace -f values-production.yaml
```

### 4. DNS

Create an A/CNAME record pointing `<your-domain>` to your ingress controller's external IP.

### 5. Verify

```bash
kubectl get pods -n cc-fleet
# Wait for both pods to be Running:
#   cc-fleet-session-manager-...   1/1  Running
#   cc-fleet-scylla-0              1/1  Running

kubectl get jobs -n cc-fleet
# Schema init job should show 1/1 Completions
```

Open `https://<your-domain>` — you should see the login page. Sign in with GitHub.

If no platform-wide Anthropic key was set, go to **Settings** and enter your `sk-ant-...` key before creating tasks.

### Upgrade

```bash
helm upgrade cc-fleet . -n cc-fleet -f values-production.yaml
```

### Uninstall

```bash
helm uninstall cc-fleet -n cc-fleet
# ScyllaDB PVC is retained — delete manually if you want to remove data:
kubectl delete pvc -n cc-fleet -l app.kubernetes.io/name=scylla
```

## What Gets Deployed

| Resource | Description |
|----------|-------------|
| Deployment | `cc-fleet-session-manager` — API, WebSocket, web dashboard, Claude SDK execution |
| StatefulSet | `cc-fleet-scylla` — single-node ScyllaDB with persistent storage |
| Job (hook) | `cc-fleet-schema-init` — creates keyspace and tables on install/upgrade |
| Service | ClusterIP for session-manager (port 3000) and ScyllaDB (port 9042) |
| Secret | JWT secret (auto-generated), GitHub OAuth credentials, Anthropic key |
| ConfigMap | Non-secret configuration (ScyllaDB host, task limits, CORS origin) |
| Ingress/IngressRoute | Based on your ingress configuration |

## Configuration Reference

### Required

| Parameter | Description |
|-----------|-------------|
| `github.clientId` | GitHub OAuth App client ID |
| `github.clientSecret` | GitHub OAuth App client secret |
| Ingress | At least one of `ingress.enabled` or `ingressRoute.enabled` must be `true` |

### Anthropic

| Parameter | Default | Description |
|-----------|---------|-------------|
| `anthropic.apiKey` | `""` | Platform-wide key. Optional — users can set their own in Settings |

### Session Manager

| Parameter | Default | Description |
|-----------|---------|-------------|
| `sessionManager.replicas` | `1` | Replicas |
| `sessionManager.image.repository` | `ghcr.io/bloomerab/cc-fleet-manager` | Image |
| `sessionManager.image.tag` | `latest` | Tag |
| `sessionManager.resources.limits.cpu` | `2` | CPU limit |
| `sessionManager.resources.limits.memory` | `2Gi` | Memory limit |

### ScyllaDB

| Parameter | Default | Description |
|-----------|---------|-------------|
| `scylla.enabled` | `true` | Deploy built-in single-node ScyllaDB |
| `scylla.host` | auto | External ScyllaDB host (when `enabled=false`) |
| `scylla.keyspace` | `cc_fleet` | Keyspace name |
| `scylla.persistence.size` | `10Gi` | Storage size |
| `scylla.persistence.storageClass` | `""` | Storage class |

### Tasks

| Parameter | Default | Description |
|-----------|---------|-------------|
| `tasks.maxConcurrent` | `5` | Max parallel Claude sessions |
| `tasks.workspaceDir` | `/tmp/cc-fleet-workspaces` | Temp workspace directory |
| `allowedRepos` | `[]` | Glob patterns for allowed repos (empty = all) |

### Ingress

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ingress.enabled` | `false` | Standard K8s Ingress |
| `ingress.host` | `fleet.example.com` | Hostname |
| `ingress.className` | `""` | Ingress class |
| `ingress.tls.enabled` | `false` | TLS |
| `ingress.tls.secretName` | `cc-fleet-tls` | TLS secret |
| `ingressRoute.enabled` | `false` | Traefik IngressRoute |
| `ingressRoute.host` | `fleet.example.com` | Hostname |
| `ingressRoute.tls.certIssuer` | `letsencrypt-prod` | cert-manager ClusterIssuer |

### Other

| Parameter | Default | Description |
|-----------|---------|-------------|
| `jwtSecret` | auto-generated | JWT signing secret (persists across upgrades) |
| `github.scopes` | `read:user,repo` | GitHub OAuth scopes |
| `corsOrigin` | auto | CORS origin (derived from ingress host) |
| `imagePullSecrets` | `[]` | Image pull secrets |

## External ScyllaDB

To use an existing ScyllaDB instead of the built-in one:

```yaml
scylla:
  enabled: false
  host: scylla-client.my-namespace.svc.cluster.local
```

Create the schema manually: [cc-fleet-manager/src/db/schema.cql](https://github.com/BloomerAB/cc-fleet-manager/blob/main/src/db/schema.cql)

## Flux GitOps

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: cc-fleet-chart
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/BloomerAB/cc-fleet-chart.git
  ref:
    branch: main
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cc-fleet
  namespace: cc-fleet
spec:
  chart:
    spec:
      chart: .
      sourceRef:
        kind: GitRepository
        name: cc-fleet-chart
        namespace: flux-system
  valuesFrom:
    - kind: Secret
      name: cc-fleet-secrets
      targetPath: github.clientId
      valuesKey: GITHUB_CLIENT_ID
    - kind: Secret
      name: cc-fleet-secrets
      targetPath: github.clientSecret
      valuesKey: GITHUB_CLIENT_SECRET
  values:
    ingressRoute:
      enabled: true
      host: fleet.example.com
      tls:
        enabled: true
```

## Troubleshooting

| Problem | Check |
|---------|-------|
| Pods not starting | `kubectl describe pod -n cc-fleet -l app.kubernetes.io/name=session-manager` |
| ScyllaDB not ready | Takes 30-60s. Schema init job retries automatically. |
| Login redirect fails | GitHub OAuth callback URL must match exactly: `https://<your-domain>/api/auth/callback` |
| "No Anthropic API key" | Set `anthropic.apiKey` in values, or sign in → Settings → enter key |
| Can't clone repos | User must have access to the repo on GitHub. Check `allowedRepos` if set. |
| TLS not working | Check cert-manager logs: `kubectl logs -n cert-manager deploy/cert-manager` |

## Architecture

```
Browser → Ingress → cc-fleet-manager (port 3000)
                     ├── /          Web dashboard
                     ├── /api/*     REST API
                     ├── /ws/*      WebSocket (real-time output)
                     └── Claude Agent SDK (in-process)
                              │
                         ScyllaDB (port 9042)
```

## Related Repos

| Repo | Description |
|------|-------------|
| [cc-fleet-manager](https://github.com/BloomerAB/cc-fleet-manager) | Platform server |
| [cc-fleet-ui](https://github.com/BloomerAB/cc-fleet-ui) | React dashboard |
| [cc-fleet-types](https://github.com/BloomerAB/cc-fleet-types) | Shared TypeScript types |
