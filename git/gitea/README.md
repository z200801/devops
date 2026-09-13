# gitea-deploy-templates

Deployment templates for [Gitea](https://gitea.com) in closed-loop
(air-gapped / private network) environments. Three orchestrator targets,
each self-contained:

| Orchestrator | Directory | README |
|--------------|-----------|--------|
| Docker Compose | `docker-compose/` | [docker-compose/README.md](docker-compose/README.md) |
| Docker Swarm | `docker-swarm/` | [docker-swarm/README.md](docker-swarm/README.md) |
| Kubernetes (Helm) | `k8s/` | [k8s/README.md](k8s/README.md) |

---

## Common architecture

```
External client
      │
      ▼
┌─────────────────────────┐
│  Host Nginx / bastion   │  (optional)
└────────┬────────────────┘
         │  HTTPS :443   SSH :2221
         ▼
┌─────────────────────────┐
│  Traefik v3             │  TLS termination · HTTP routing
│                         │  TCP passthrough for SSH
└────────┬────────────────┘
         │  HTTP :3000   SSH :22
         ▼
┌─────────────────────────┐
│  Gitea                  │  Web UI · Git · SSH · Actions API
└────────┬────────────────┘
         │  :5432
         ▼
┌─────────────────────────┐
│  PostgreSQL 14           │
└─────────────────────────┘

            ── separate host or node ──

┌─────────────────────────┐
│  Gitea Act Runner       │  polls Gitea, executes CI jobs
└─────────────────────────┘
```

All three templates deploy the same logical stack. The runner is always
deployed as a separate unit so it can be scaled or replaced independently.

---

## Global runner registration

A runner must be registered with an **instance-level** token to become
global (visible to all repositories). Tokens from a repository or
organisation page produce runners scoped to that entity only.

**How to obtain an instance-level token:**

1. Log in as a Gitea administrator.
2. Go to **Site Administration** (top-right menu → "Site Administration").
3. Navigate to **Actions → Runners**.
4. Click **Create new runner** — copy the token shown.

| Orchestrator | How to supply the token |
|--------------|------------------------|
| Docker Compose | `TOKEN=<token>` in `docker-compose/runner/.env` |
| Docker Swarm | `echo -n <token> \| docker secret create gitea_runner_token -` |
| Kubernetes | `--set runner.token=<token>` in `helm install/upgrade` |

---

## Examples

Each orchestrator directory contains an `examples/` subdirectory with a
sample Gitea Actions workflow:

```
docker-compose/examples/.gitea/workflows/demo.yaml
docker-swarm/examples/.gitea/workflows/demo.yaml
k8s/examples/.gitea/workflows/demo.yaml
```

The workflow file is identical across all three — copy it into your
repository's `.gitea/workflows/` directory to test your runner:

```bash
mkdir -p .gitea/workflows
cp <orchestrator>/examples/.gitea/workflows/demo.yaml .gitea/workflows/
git add .gitea/workflows/demo.yaml
git commit -m "add demo workflow"
git push
```

The runner picks up the job automatically and runs it on the
`ubuntu-latest` label.

---

## Choosing an orchestrator

| | Docker Compose | Docker Swarm | Kubernetes |
|-|---------------|-------------|-----------|
| Complexity | Low | Low–Medium | Medium–High |
| Secret management | `.env` file | Docker secrets | K8s Secrets |
| Multi-node | No | Yes (UDP 4789 needed) | Yes |
| Recommended for | Single host, dev/test | Single-node prod | Existing K8s cluster |
