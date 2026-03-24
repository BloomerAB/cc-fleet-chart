# CC Fleet

Run Claude Code sessions across multiple repositories from a web dashboard. Installable as a PWA for mobile access.

## What is CC Fleet?

CC Fleet is a self-hosted platform that lets you:
- Run Claude Code tasks against one or more git repos simultaneously
- Monitor sessions in real-time via WebSocket streaming
- Answer Claude's questions through the dashboard
- Manage multiple concurrent sessions
- Restrict access to specific repos via allowlists
- Login with GitHub (OAuth) — the same credentials are used for git access

## Setup Guide

### Step 1: Create a GitHub OAuth App

1. Go to [github.com/settings/applications/new](https://github.com/settings/applications/new)
2. Fill in:
   - **Application name**: CC Fleet (or whatever you like)
   - **Homepage URL**: `https://your-domain.com`
   - **Authorization callback URL**: `https://your-domain.com/api/auth/callback`
3. Click **Register application**
4. Copy the **Client ID**
5. Click **Generate a new client secret** and copy it

The `repo` scope is requested at login, giving Claude read/write access to repos the user has access to.

### Step 2: Get an Anthropic API Key

1. Go to [console.anthropic.com](https://console.anthropic.com/)
2. Create or copy an API key (`sk-ant-...`)

### Step 3: Install the Chart

```bash
git clone https://github.com/BloomerAB/cc-fleet-chart.git
cd cc-fleet-chart

helm install cc-fleet . \
  --namespace cc-fleet --create-namespace \
  --set github.clientId=Iv1_YOUR_CLIENT_ID \
  --set github.clientSecret=YOUR_CLIENT_SECRET \
  --set anthropic.apiKey=sk-ant-YOUR_KEY \
  --set ingress.enabled=true \
  --set ingress.host=your-domain.com
```

Or with a values file:

```yaml
# my-values.yaml
github:
  clientId: "Iv1_abc123"
  clientSecret: "your-secret"

anthropic:
  apiKey: "sk-ant-your-key"

ingress:
  enabled: true
  host: fleet.example.com
  tls:
    enabled: true
    secretName: cc-fleet-tls
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod

allowedRepos:
  - "github.com/MyOrg/*"
```

```bash
helm install cc-fleet . -n cc-fleet --create-namespace -f my-values.yaml
```

### Step 4: DNS

Point your domain to your cluster's ingress controller IP/load balancer.

### Step 5: Verify

```bash
# Check pods are running
kubectl get pods -n cc-fleet

# Expected:
# cc-fleet-session-manager-xxx   1/1  Running
# cc-fleet-scylla-0              1/1  Running

# Check the schema init job completed
kubectl get jobs -n cc-fleet

# Check logs if something is wrong
kubectl logs -n cc-fleet deploy/cc-fleet-session-manager
```

Then open `https://your-domain.com` and sign in with GitHub.

### Step 6: Install as PWA (optional)

On mobile (iOS/Android) or desktop Chrome, the dashboard is installable as a Progressive Web App:
- **iOS Safari**: Share button → Add to Home Screen
- **Android Chrome**: Menu → Add to Home Screen
- **Desktop Chrome**: Address bar install icon

## What Gets Deployed

| Component | Description |
|-----------|-------------|
| **cc-fleet-manager** | Fastify server — API, WebSocket, dashboard SPA, Claude SDK execution |
| **ScyllaDB** | Single-node StatefulSet with persistent storage |
| **Schema init job** | Helm hook that creates the keyspace and tables on install/upgrade |

## Configuration Reference

### Required

| Parameter | Description |
|-----------|-------------|
| `github.clientId` | GitHub OAuth App client ID |
| `github.clientSecret` | GitHub OAuth App client secret |
| `anthropic.apiKey` | Anthropic API key for Claude |

### Session Manager

| Parameter | Default | Description |
|-----------|---------|-------------|
| `sessionManager.replicas` | `1` | Number of replicas |
| `sessionManager.image.repository` | `ghcr.io/bloomerab/cc-fleet-manager` | Container image |
| `sessionManager.image.tag` | `latest` | Image tag |
| `sessionManager.resources.limits.cpu` | `2` | CPU limit |
| `sessionManager.resources.limits.memory` | `2Gi` | Memory limit |

### ScyllaDB

| Parameter | Default | Description |
|-----------|---------|-------------|
| `scylla.enabled` | `true` | Deploy built-in ScyllaDB |
| `scylla.host` | auto | External ScyllaDB host (when `enabled=false`) |
| `scylla.keyspace` | `cc_fleet` | Keyspace name |
| `scylla.persistence.size` | `10Gi` | Storage size |
| `scylla.persistence.storageClass` | `""` | Storage class (empty = default) |

### Tasks

| Parameter | Default | Description |
|-----------|---------|-------------|
| `tasks.maxConcurrent` | `5` | Max parallel Claude sessions |
| `tasks.workspaceDir` | `/tmp/cc-fleet-workspaces` | Temp dir for cloned repos |
| `allowedRepos` | `[]` | Glob patterns (empty = all repos allowed) |

### Ingress

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ingress.enabled` | `false` | Enable standard K8s Ingress |
| `ingress.host` | `fleet.example.com` | Hostname |
| `ingress.className` | `""` | Ingress class |
| `ingress.tls.enabled` | `false` | Enable TLS |
| `ingress.tls.secretName` | `cc-fleet-tls` | TLS secret name |
| `ingressRoute.enabled` | `false` | Enable Traefik IngressRoute |

### Other

| Parameter | Default | Description |
|-----------|---------|-------------|
| `jwtSecret` | auto-generated | JWT signing secret |
| `github.scopes` | `read:user,repo` | GitHub OAuth scopes |
| `corsOrigin` | auto from ingress host | CORS origin override |
| `imagePullSecrets` | `[]` | Pull secrets for private registries |

## Using External ScyllaDB

If you already run ScyllaDB in your cluster:

```bash
helm install cc-fleet . \
  --set scylla.enabled=false \
  --set scylla.host=scylla-client.scylla.svc.cluster.local \
  ...
```

You'll need to create the keyspace and tables manually — see the schema in [cc-fleet-manager/src/db/schema.cql](https://github.com/BloomerAB/cc-fleet-manager/blob/main/src/db/schema.cql).

## Using with Flux GitOps

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
  values:
    ingress:
      enabled: true
      host: fleet.example.com
```

## Troubleshooting

**Pods not starting?**
```bash
kubectl describe pod -n cc-fleet -l app.kubernetes.io/name=session-manager
kubectl logs -n cc-fleet -l app.kubernetes.io/name=session-manager
```

**ScyllaDB not ready?** It takes 30-60 seconds to start. The schema init job retries until ScyllaDB is healthy.

**Login redirect fails?** Check that the GitHub OAuth callback URL matches exactly: `https://your-domain.com/api/auth/callback`

**Can't clone repos?** The GitHub OAuth `repo` scope gives access to repos the logged-in user can access. If a repo is not accessible, check the user's GitHub permissions.

## Architecture

```
                 ┌──────────────────────┐
  Browser ────── │  cc-fleet-manager     │
                 │                       │
                 │  /         → React SPA│
                 │  /api/*    → REST API │
                 │  /ws/*     → WebSocket│
                 │                       │
                 │  Claude Agent SDK     │
                 │  (in-process)         │
                 └───────┬──────────────┘
                         │
                  ┌──────▼──────┐
                  │  ScyllaDB   │
                  └─────────────┘
```

## Related Repos

| Repo | Description |
|------|-------------|
| [cc-fleet-manager](https://github.com/BloomerAB/cc-fleet-manager) | Platform server (API + WS + SPA + SDK) |
| [cc-fleet-ui](https://github.com/BloomerAB/cc-fleet-ui) | React dashboard (built into manager image) |
| [cc-fleet-types](https://github.com/BloomerAB/cc-fleet-types) | Shared TypeScript types |
