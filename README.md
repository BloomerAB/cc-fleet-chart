# CC Fleet Helm Chart

Deploy [CC Fleet](https://github.com/BloomerAB/cc-fleet-manager) — a platform for running Claude Code sessions across multiple repositories via a web dashboard.

## Quick Start

```bash
helm install cc-fleet ./cc-fleet-chart \
  --namespace cc-fleet --create-namespace \
  --set github.clientId=YOUR_GITHUB_CLIENT_ID \
  --set github.clientSecret=YOUR_GITHUB_CLIENT_SECRET \
  --set anthropic.apiKey=sk-ant-YOUR_KEY \
  --set ingress.enabled=true \
  --set ingress.host=fleet.example.com
```

This deploys everything — including a single-node ScyllaDB instance.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.x
- A [GitHub OAuth App](https://github.com/settings/applications/new):
  - Homepage URL: `https://fleet.example.com`
  - Callback URL: `https://fleet.example.com/api/auth/callback`
- An [Anthropic API key](https://console.anthropic.com/)

## What Gets Deployed

| Component | Description |
|-----------|-------------|
| **cc-fleet-manager** | Fastify server — API, WebSocket, dashboard SPA, Claude SDK execution |
| **ScyllaDB** | Single-node database (optional, can use external) |
| **Schema init job** | Helm hook that creates the keyspace and tables |

## Configuration

### Required Values

| Parameter | Description |
|-----------|-------------|
| `github.clientId` | GitHub OAuth App client ID |
| `github.clientSecret` | GitHub OAuth App client secret |
| `anthropic.apiKey` | Anthropic API key for Claude |

### Optional Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `sessionManager.replicas` | `1` | Number of replicas |
| `sessionManager.image.tag` | `latest` | Image tag |
| `scylla.enabled` | `true` | Deploy built-in ScyllaDB |
| `scylla.host` | auto | External ScyllaDB host (when `scylla.enabled=false`) |
| `scylla.keyspace` | `cc_fleet` | ScyllaDB keyspace name |
| `scylla.persistence.size` | `10Gi` | ScyllaDB storage size |
| `tasks.maxConcurrent` | `5` | Max concurrent Claude sessions |
| `allowedRepos` | `[]` | Repo allowlist (glob patterns, empty = all allowed) |
| `ingress.enabled` | `false` | Enable Kubernetes Ingress |
| `ingress.host` | `fleet.example.com` | Hostname |
| `ingressRoute.enabled` | `false` | Enable Traefik IngressRoute |
| `jwtSecret` | auto-generated | JWT signing secret |

### Using External ScyllaDB

```bash
helm install cc-fleet ./cc-fleet-chart \
  --set scylla.enabled=false \
  --set scylla.host=scylla.my-namespace.svc.cluster.local \
  --set scylla.keyspace=cc_fleet \
  ...
```

### Repo Allowlist

Restrict which repositories users can clone:

```yaml
allowedRepos:
  - "github.com/MyOrg/*"
  - "github.com/other-org/specific-repo"
```

Empty list (default) allows all repositories.

## Architecture

```
                 ┌──────────────────────┐
  Browser ───── │  cc-fleet-manager     │
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

- [cc-fleet-manager](https://github.com/BloomerAB/cc-fleet-manager) — Platform server
- [cc-fleet-ui](https://github.com/BloomerAB/cc-fleet-ui) — React dashboard (built into manager image)
- [cc-fleet-types](https://github.com/BloomerAB/cc-fleet-types) — Shared TypeScript types
