# Claude Code Fleet

Run Claude Code sessions in Kubernetes with a web dashboard. Give your team autonomous AI agents that clone repos, write code, create PRs, and run commands — all managed through a browser UI.

## What is CC Fleet?

CC Fleet is a self-hosted platform for running [Claude Code](https://claude.com/claude-code) sessions remotely in Kubernetes pods. Instead of running Claude Code locally, you dispatch tasks through a web UI and interact with them in real time.

### Key Features

- **Interactive sessions** — Send prompts, see streaming output, send follow-ups. You decide when the session ends.
- **Multi-repo support** — Clone specific repos, filter by org pattern, or let Claude discover which repos are relevant.
- **Session sync** — Move sessions between local Claude Code and Fleet with the MCP server. Push a local session to Fleet or pull a Fleet session locally.
- **Per-user isolation** — Each user gets isolated HOME directories, API keys, and workspaces. No data leaks between users.
- **Resume & Retry** — Resume completed sessions with full conversation history, or retry with a fresh start.
- **Live cost tracking** — See accumulated API cost and turn count updated after each turn.
- **Dark developer UI** — Purpose-built dark theme with Claude brand colors.

### Architecture

```
┌─────────────┐     ┌──────────────────────┐     ┌─────────────┐
│   Browser    │────→│   Session Manager    │────→│  ScyllaDB   │
│  (Fleet UI)  │←────│  (Node.js + SDK)     │←────│  (sessions) │
└─────────────┘  WS  │                      │     └─────────────┘
                      │  ┌────────────────┐ │
                      │  │ Claude Code SDK │ │
                      │  │ (per session)   │ │
                      │  └────────────────┘ │
                      └──────────────────────┘
```

- **Fleet UI** — React SPA served by nginx. Dark theme, real-time WebSocket output.
- **Session Manager** — Node.js backend. Manages sessions, spawns Claude Code via the Agent SDK, streams output to dashboards.
- **ScyllaDB** — Stores sessions, messages, user settings. Cassandra-compatible.
- **Claude Code SDK** — One persistent process per session. Multi-turn conversations via async input queue.

### Local Integration (MCP Server)

Install the `@bloomerab/cc-fleet-mcp` package to sync sessions between local Claude Code and Fleet:

```bash
npx @bloomerab/cc-fleet-mcp
```

Add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "cc-fleet": {
      "command": "npx",
      "args": ["@bloomerab/cc-fleet-mcp"]
    }
  }
}
```

Then in Claude Code:
- **"Push this session to fleet"** — upload current session to Fleet
- **"Pull session X from fleet"** — download a Fleet session locally
- **"List fleet sessions"** — show all Fleet sessions

## Helm Chart

### Prerequisites

- Kubernetes 1.28+
- Helm 3
- ScyllaDB or Cassandra cluster
- GitHub OAuth app (for login)
- Anthropic API key (per user, configured in Settings)

### Install

```bash
helm install cc-fleet ./cc-fleet-chart \
  --namespace fleet --create-namespace \
  --set github.clientId=YOUR_CLIENT_ID \
  --set github.clientSecret=YOUR_CLIENT_SECRET \
  --set jwtSecret=YOUR_JWT_SECRET
```

### Values

| Key | Default | Description |
|-----|---------|-------------|
| `ui.image.repository` | `ghcr.io/bloomerab/cc-fleet-ui` | UI image |
| `ui.image.tag` | `latest` | UI image tag |
| `sessionManager.image.repository` | `ghcr.io/bloomerab/cc-fleet-manager` | Manager image |
| `sessionManager.image.tag` | `latest` | Manager image tag |
| `sessionManager.replicas` | `1` | Manager replicas |
| `sessionManager.resources` | See values.yaml | CPU/memory requests and limits |
| `authMode` | `apiKey` | Auth mode: `apiKey` (users provide keys) or `subscription` (Claude Pro/Max) |
| `claudeCredentials.enabled` | `false` | Enable PVC for persistent Claude session files |
| `claudeCredentials.size` | `100Mi` | PVC size for session persistence |
| `scylla.enabled` | `false` | Deploy ScyllaDB (if false, use external) |
| `scylla.host` | `scylla-client.scylla.svc.cluster.local` | ScyllaDB host |
| `scylla.port` | `9042` | ScyllaDB port |
| `scylla.keyspace` | `cc_fleet` | Keyspace name |
| `tasks.maxConcurrent` | `5` | Max concurrent sessions per pod |
| `tasks.workspaceDir` | `/tmp/cc-fleet-workspaces` | Workspace directory |
| `allowedRepos` | `[]` | Glob patterns for allowed repos (empty = all) |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.host` | `""` | Ingress hostname |
| `ingress.tls.enabled` | `false` | Enable TLS |

### Scaling

Current architecture runs all sessions in a single pod. For a small team (5-10 users):

- Increase `sessionManager.resources.limits.memory` to `4Gi`+
- Increase `tasks.maxConcurrent` to `10`-`15`
- Enable `claudeCredentials` with sufficient storage for session history

For larger deployments, pod-per-session architecture is planned.

## Repositories

| Repo | Description |
|------|-------------|
| [cc-fleet-chart](https://github.com/BloomerAB/cc-fleet-chart) | This Helm chart |
| [cc-fleet-manager](https://github.com/BloomerAB/cc-fleet-manager) | Backend + MCP server |
| [cc-fleet-ui](https://github.com/BloomerAB/cc-fleet-ui) | React frontend |

## License

Proprietary — Bloomer AB
