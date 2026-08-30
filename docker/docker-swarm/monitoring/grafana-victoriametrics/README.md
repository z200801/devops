# Monitoring Stack — Docker Swarm

Grafana + VictoriaMetrics + Loki + Alertmanager + Promtail

## Stack

| Service | Mode | Port | Purpose |
|---|---|---|---|
| node-exporter | global | 9100 | Host CPU / RAM / disk / network per node |
| cadvisor | global | 8080 | Container metrics per node |
| promtail | global | — | Log shipping per node |
| swarm-exporter | replicated / manager | 9000 | Swarm stacks / services / overlay metrics |
| victoriametrics | replicated / manager | 8428 | TSDB + scraper |
| loki | replicated / manager | — | Log aggregation (internal) |
| alertmanager | replicated / manager | — | Alert routing → Discord (internal) |
| grafana | replicated / manager | 3000 | Dashboards + UI |

## File Structure

```
.
├── Makefile
├── stack.yml
└── configs/
    ├── victoriametrics/
    │   └── scrape.yml
    ├── loki/
    │   └── loki.yml
    ├── promtail/
    │   └── promtail.yml
    ├── alertmanager/
    │   └── alertmanager.yml
    └── grafana/
        ├── datasources.yml
        └── dashboards.yml
```

## Prerequisites

### 1. Docker Swarm

```bash
docker swarm init
```

### 2. Docker daemon metrics on every manager node

`/etc/docker/daemon.json`:
```json
{
  "metrics-addr": "172.18.0.1:9323",
  "experimental": true
}
```

```bash
systemctl restart docker
```

### 3. Tools

```bash
apt install gettext-base rsync
```

`gettext-base` provides `envsubst` — used to substitute Discord webhook URL into alertmanager config.

## Deploy

### 1. Initialize

```bash
make init
make env-init
```

Edit `$(DEPLOY_DIR)/.env`:
```bash
GRAFANA_ROOT_URL=http://<manager-ip>:3000
```

### 2. Copy files from repository

```bash
make copy-deploy-files \
  GIT_REPO_DIR=/path/to/repo \
  PROJECT_NAME=monitoring
```

Or copy files manually to `DEPLOY_DIR`:
```bash
DEPLOY_DIR=$HOME/projects/monitoring/dswarm/prod/deploy
mkdir -p $DEPLOY_DIR
cp -r stack.yml configs/ $DEPLOY_DIR/
```

### 3. Create secrets

```bash
make secrets-create \
  GRAFANA_ADMIN_USER=admin \
  GRAFANA_ADMIN_PASSWORD=your_password
```

### 4. Create configs

```bash
make configs-create \
  DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/ID/TOKEN
```

> **No Discord yet?** `DISCORD_WEBHOOK_URL` must be a **well-formed URL**,
> but it does not have to be live. Use a placeholder to bring the stack up:
>
> ```bash
> make configs-create \
>   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/000000/DUMMY
> ```
>
> An **empty or malformed** value makes Alertmanager exit on start with
> `error loading configuration file: unsupported scheme "" for URL`.
> Swap in the real webhook later with `make configs-rotate` (see
> [Rotate Discord webhook](#rotate-discord-webhook)).
>
> Note: `configs-create` skips a config that already exists ("Already
> exists"), so if the first run used a bad value, only `configs-rotate`
> will replace it.

### 5. Deploy

```bash
make stack-deploy
```

### 6. Verify

```bash
make status
make stack-health
```

## Grafana Dashboards

### Metrics — import by ID

Grafana UI → Dashboards → Import → enter ID → datasource: VictoriaMetrics

| ID | Dashboard | Purpose |
|---|---|---|
| 1860 | Node Exporter Full | Host CPU / RAM / disk / network per node |
| 17023 | Docker Swarm Service and Container Metrics | Container CPU / RAM / network / disk per swarm service |
| 19792 | cAdvisor Dashboard | Full cAdvisor metrics per container |
| 10229 | VictoriaMetrics | Self-monitoring VM |
| 9578 | Alertmanager | Alert groups / notification status |

### Logs — Loki

Grafana UI → Explore → datasource: Loki → Label filters:

| Label | Operator | Value | Purpose |
|---|---|---|---|
| `service` | `=~` | `.+` | Logs from all services |
| `service` | `=` | `mon2_grafana` | Logs from specific service |
| `stack` | `=` | `mon2` | Logs from entire stack |
| `container` | `=~` | `.+` | Logs by container |

## Operations

### Service logs

```bash
make logs SERVICE=grafana
make logs SERVICE=victoriametrics
make logs SERVICE=promtail
```

### Service rollback

```bash
make service-rollback SERVICE=grafana
```

### Force update service

```bash
make service-update SERVICE=victoriametrics
```

### Stack task status

```bash
make ps
```

### Resource usage

```bash
make stats
```

### Shell inside container

```bash
make exec SERVICE=grafana
```

## Rotate secrets / configs

### Rotate Grafana credentials

```bash
make secrets-rotate \
  GRAFANA_ADMIN_USER=admin \
  GRAFANA_ADMIN_PASSWORD=new_password
make configs-create DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/ID/TOKEN
make stack-deploy
```

### Rotate Discord webhook

```bash
make configs-rotate \
  DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/NEW_ID/NEW_TOKEN
make stack-deploy
```

### Rotate everything

```bash
make secrets-rotate \
  GRAFANA_ADMIN_USER=admin \
  GRAFANA_ADMIN_PASSWORD=new_password
make configs-rotate \
  DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/ID/TOKEN
make stack-deploy
```

## Backup

```bash
make stack-backup
```

Saves `stack.yml` and service list to `BU_DIR`.

## Teardown

```bash
make stop
```

Data volumes are preserved after stack removal — VictoriaMetrics, Loki, Grafana, Alertmanager data is not lost.

To remove volumes:
```bash
docker volume rm monitoring_victoriametrics_data \
                 monitoring_grafana_data \
                 monitoring_loki_data \
                 monitoring_alertmanager_data \
                 monitoring_promtail_positions
```

## Makefile variables

| Variable | Default | Description |
|---|---|---|
| `PROJECT_NAME` | `monitoring` | Project name |
| `ENV` | `prod` | Environment |
| `STACK_NAME` | `monitoring` | Docker stack name |
| `PROJECTS_DIR` | `~/projects` | Base projects directory |
| `GIT_REPO_DIR` | `~/projects/repo/h2-dswarm` | Git repository path |
| `GIT_BRANCH_DEVOPS` | `main` | Git branch |
| `GRAFANA_ADMIN_USER` | — | Grafana admin username |
| `GRAFANA_ADMIN_PASSWORD` | — | Grafana admin password |
| `DISCORD_WEBHOOK_URL` | — | Discord webhook URL |
