# Monitoring Stack — Docker Swarm

Grafana + VictoriaMetrics + Loki + Alertmanager + Promtail

## Stack

| Service | Mode | Port | Purpose |
|---|---|---|---|
| node-exporter | global | 9100 | Host CPU / RAM / disk / network per node |
| cadvisor | global | 8080 | Container metrics per node |
| promtail | global | — | Log shipping per node |
| swarm-exporter | replicated / manager | 8888 | Swarm stacks / services / overlay metrics |
| victoriametrics | replicated / manager | 8428 | TSDB + scraper |
| loki | replicated / manager | — | Log aggregation (internal) |
| alertmanager | replicated / manager | — | Alert routing → Discord (internal) |
| vmalert | replicated / manager | — | Alerting rule evaluation → Alertmanager (internal) |
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
    ├── vmalert/
    │   └── rules/
    │       └── alerts.yml
    └── grafana/
        ├── datasources.yml
        └── dashboards.yml
```

## Architecture

The stack is multi-arch (amd64 + arm64). The `mode: global` services
(`node-exporter`, `cadvisor`, `promtail`) run on every node regardless of
architecture; the manager-pinned services (`victoriametrics`, `loki`,
`alertmanager`, `grafana`, `swarm-exporter`) follow the manager's
architecture. All images carry both amd64 and arm64 variants.

The swarm exporter is `ghcr.io/leinardi/swarm-scheduler-exporter` (port
8888, metrics at `/metrics`). It replaced `neuroforgede/docker-swarm-exporter`
(amd64-only) to support mixed-architecture Swarm nodes. It exposes `swarm_*`
metric names (e.g. `swarm_service_desired_replicas`,
`swarm_service_running_replicas`). It must run on a manager node and reads the
Docker socket at `/var/run/docker.sock` (bind-mounted read-only).

## Prerequisites

### 1. Docker Swarm

```bash
docker swarm init
```

### 2. Docker daemon metrics on every manager node

`/etc/docker/daemon.json` — set `metrics-addr` to the IP of the **internal
docker bridge** on that host (the address where dockerd actually listens for
metrics, not the LAN or public address):

```json
{
  "metrics-addr": "172.17.0.1:9323",
  "experimental": true
}
```

```bash
systemctl restart docker
```

The bridge IP differs per host (`172.17.0.1` for `docker0`, `172.18.0.1` for
`docker_gwbridge`, etc.). Check which bridge the daemon is reachable on:

```bash
ss -tunlp | grep 9323
```

> **Security note:** `metrics-addr` must bind to an **internal** bridge
> address, not `0.0.0.0`. Exposing engine metrics on a routable interface is
> a security risk. Firewall port `9323` as defence-in-depth regardless.

The scrape target is set per host via `DOCKER_METRICS_ADDR` (default
`172.17.0.1:9323`), baked into the scrape config at `configs-create`/
`configs-rotate` time. Override it when creating configs for a host whose
daemon listens on a different bridge:

```bash
make configs-rotate \
  DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/ID/TOKEN \
  DOCKER_METRICS_ADDR=172.18.0.1:9323
make stack-deploy
```

Verify the scrape is working after deploy:

```bash
curl -sG 'http://127.0.0.1:8428/api/v1/query' \
  --data-urlencode 'query=up{job="docker-daemon"}'
```

### 3. Tools

```bash
apt install gettext-base rsync
```

`gettext-base` provides `envsubst` — used to substitute Discord webhook URL into alertmanager config.

### 4. fail2ban node label

The `fail2ban-exporter` service is `mode: global` but constrained to
`node.labels.fail2ban == true` (`stack.yml`). Without the label it is not
scheduled on any node, and the `fail2ban-mivek-exporter` dashboard stays
empty.

Label every node that runs fail2ban:
```bash
docker node update --label-add fail2ban=true <node>
```

Verify:
```bash
docker node inspect --format '{{ .Spec.Labels }}' <node>
docker service ps monitoring_fail2ban-exporter
```

Remove the label to stop the exporter on a node:
```bash
docker node update --label-rm fail2ban <node>
```

The exporter bind-mounts the host socket `/var/run/fail2ban` (read-only), so
fail2ban must be running on the labeled node — otherwise the container keeps
restarting. Once at least one node is labeled and the exporter is up,
VictoriaMetrics discovers the task via Swarm SD and scrapes it on port 9921
(`configs/victoriametrics/scrape.yml`); no extra scrape config is needed.

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

### Import from repo JSON

Some dashboards ship as JSON files in `dashboards/` and are imported manually
(they are **not** file-provisioned — nothing populates `/var/lib/grafana/dashboards`
automatically).

Grafana UI → Dashboards → New → Import → **Upload JSON file** → select the file
→ datasource: VictoriaMetrics → Import.

| File | Dashboard | Purpose |
|---|---|---|
| `dashboards/swarm-scheduler-exporter.json` | Swarm Scheduler Exporter | Desired vs running replicas, task states, node states, update/rollback progress, exporter health. Requires the `leinardi/swarm-scheduler-exporter` (this multiarch variant — **not** `grafana-vm-x86/`). |
| `dashboards/fail2ban-mivek-exporter.json` | fail2ban (mivek) | Host fail2ban jail metrics per node |
| `dashboards/nginx-analytics.json` | Nginx Analytics | nginx access log analytics via Loki |

### Logs — Loki

Grafana UI → Explore → datasource: Loki → Label filters:

| Label | Operator | Value | Purpose |
|---|---|---|---|
| `service` | `=~` | `.+` | Logs from all services |
| `service` | `=` | `mon2_grafana` | Logs from specific service |
| `stack` | `=` | `mon2` | Logs from entire stack |
| `container` | `=~` | `.+` | Logs by container |

## Alerting

`vmalert` evaluates the rule files in `configs/vmalert/rules/` against
VictoriaMetrics (`:8428`) on a 30-second interval and forwards firing alerts
to Alertmanager (`:9093`), which delivers them to Discord.

### Routing

Alertmanager routes by `severity` label:
- `severity: critical` → `#discord-critical` channel
- `severity: warning` → `#discord` channel

Every rule must set `severity` to exactly `critical` or `warning`. Rules that
read node-exporter or swarm-exporter metrics must preserve the `node` or
`service` label so Alertmanager can group and inhibit correctly.

### Current ruleset (`configs/vmalert/rules/alerts.yml`)

| Group | Alert | Condition | Severity |
|---|---|---|---|
| targets | CoreServiceDown | `up == 0` for 5m (victoriametrics / alertmanager / loki / grafana / vmalert) | critical |
| targets | ServiceDown | `up == 0` for 5m (all other scraped targets) | warning |
| node | NodeDiskAlmostFull | filesystem free < 10% for 10m | warning |
| node | NodeDiskCritical | filesystem free < 5% for 10m | critical |
| node | NodeMemoryPressure | memory used > 90% for 10m | warning |
| node | NodeCPUSaturation | CPU busy > 90% (5m avg) for 15m | warning |
| swarm | SwarmServiceNotAtDesired | `swarm_service_at_desired == 0` for 10m | warning |

### Managing rules — add / edit / delete

#### Where rules live

All rules are in `configs/vmalert/rules/alerts.yml`, shipped as the
`mon2_vmalert_rules` Docker config (mounted read-only at
`/etc/vmalert/rules/alerts.yml`). Docker configs are immutable — the running
config cannot be patched in place. Every change follows the same sequence:
edit the file → validate → re-create the config → redeploy.

#### Rule shape and contract

Minimal rule skeleton:

```yaml
- alert: MyAlertName
  expr: <MetricsQL expression that evaluates to a non-empty result set when firing>
  for: 5m
  labels:
    severity: warning      # must be exactly "critical" or "warning"
  annotations:
    summary: "Short title — {{ $labels.node }}"
    description: "Longer description. Value: {{ $value }}."
```

Non-negotiables:
- `severity` must be exactly `critical` or `warning`; any other value is not
  routed by Alertmanager.
- A rule reading a `node`- or `service`-labelled metric must preserve that
  label in the result (do not `avg without(node)` or `sum by(job)` it away);
  Alertmanager uses those labels for grouping and inhibition.
- Annotations support Go template syntax: `{{ $labels.<name> }}` expands a
  label value, `{{ $value }}` expands the numeric sample value.

#### Add a rule

Append a new `- alert:` block to an existing group's `rules:` list:

```yaml
# example: add NodeNetworkErrors to the existing "node" group
- alert: NodeNetworkErrors
  expr: rate(node_network_transmit_errs_total[5m]) > 10
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High network errors on {{ $labels.node }}"
    description: "Interface {{ $labels.device }} on {{ $labels.node }} is seeing > 10 tx errors/s."
```

To start a new group, add a `- name:` block at the bottom of
`alerts.yml`:

```yaml
- name: mygroup
  rules:
    - alert: MyNewAlert
      ...
```

#### Edit / fix a rule

Change the `expr`, `for`, threshold, or annotation text in place. Example —
tighten the disk threshold:

```yaml
# before
expr: node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.10
# after
expr: node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.15
```

#### Delete a rule

Remove the rule's `- alert:` block (including all its child keys). If the
group's `rules:` list becomes empty after removal, delete the entire
`- name:` block as well. Keep the remaining YAML valid.

#### Validate before applying

Catches YAML syntax errors and bad MetricsQL expressions without touching the
running stack:

```bash
docker run --rm \
  -v "$PWD/configs/vmalert/rules":/r \
  victoriametrics/vmalert:latest \
  -rule='/r/*.yml' -rule.validateExpressions -dryRun
```

Exit 0 means the rules parse correctly.

#### Apply

Rules are delivered as a Docker config, so applying a change is a full config
rotation:

```bash
make configs-rotate DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/ID/TOKEN
make stack-deploy
```

`configs-rotate` depends on `stack-rm`, so this briefly brings the entire
monitoring stack down and back up — acceptable for a non-user-facing stack.

> A single-config hot-reload for `mon2_vmalert_rules` without full downtime (analogous
> to `make alertmanager-reload`) is not yet implemented. It is a possible later
> step.

#### Confirm rules loaded

vmalert `:8880` is on the overlay network only — `curl` from the host
fails. Query via an overlay-attached container, or through the published
VictoriaMetrics port:

```bash
# list groups and rules (overlay curl)
docker run --rm --network mon2_monitoring curlimages/curl -s \
  http://vmalert:8880/api/v1/rules

# currently firing alerts (via published VM :8428)
curl -sG 'http://127.0.0.1:8428/api/v1/query' \
  --data-urlencode 'query=ALERTS'
```

#### Testing alerts (Discord delivery)

A healthy stack fires no alerts, so delivery must be tested deliberately.
Three tiers, from least to most invasive:

**1. Pipeline health — no side effects**

Verify vmalert is being scraped and is not dropping notifications, using the
published VictoriaMetrics port:

```bash
# 1 = vmalert is scraped by VM
curl -sG 'http://127.0.0.1:8428/api/v1/query' \
  --data-urlencode 'query=up{service="vmalert"}'

# empty result or 0 = no send errors
curl -sG 'http://127.0.0.1:8428/api/v1/query' \
  --data-urlencode 'query=vmalert_alerts_send_errors_total'
```

**2. Direct Discord test — inject into Alertmanager**

Tests the Alertmanager → Discord path without touching any rule file.
Alertmanager `:9093` is overlay-internal; inject via an overlay curl
container. `severity=critical` routes to `#discord-critical`;
`severity=warning` routes to `#discord`. The alert auto-resolves after
`resolve_timeout` (~5 min):

```bash
docker run --rm --network mon2_monitoring curlimages/curl -s -XPOST \
  http://alertmanager:9093/api/v2/alerts \
  -H 'Content-Type: application/json' \
  -d '[{
    "labels":{"alertname":"TestDiscord","severity":"critical","node":"test"},
    "annotations":{"summary":"manual test","description":"delivery check"},
    "startsAt":"'"$(date -u +%FT%TZ)"'"
  }]'
```

**3. End-to-end through a real rule**

Force `SwarmServiceNotAtDesired` by creating an unschedulable service. Hold
it for at least 10 minutes (`for: 10m`), then clean up:

```bash
docker service create --name testfail --replicas 1 \
  --constraint 'node.labels.nonexistent==true' alpine sleep 1d
# wait ~10 min → warning "SwarmServiceNotAtDesired" arrives in #discord
docker service rm testfail
```

### Webhook requirement

`DISCORD_WEBHOOK_URL` must be a real, well-formed URL for alerts to reach
Discord. The default in `configs/alertmanager/alertmanager.yml` is a
`DUMMY` placeholder — alerts will silently fail to deliver until a real URL
is substituted via `make configs-rotate`.

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

### Config and secret namespacing

All external Docker configs and secrets are namespaced with a stack-name
prefix to avoid collisions with other stacks on the same swarm.

**Configs** — `${CONFIG_PREFIX}_<name>`, where `CONFIG_PREFIX` defaults to
`$(STACK_NAME)` (`mon2`):

| Config key | Docker config name |
|---|---|
| scrape_config | `mon2_scrape_config` |
| loki_config | `mon2_loki_config` |
| promtail_config | `mon2_promtail_config` |
| alertmanager_config | `mon2_alertmanager_config` |
| grafana_datasources | `mon2_grafana_datasources` |
| grafana_dashboards_provider | `mon2_grafana_dashboards_provider` |
| vmalert_rules | `mon2_vmalert_rules` |

Override with `CONFIG_PREFIX=<value>` on any `make` invocation.

**Secrets** — `${SECRET_PREFIX}_<name>`, where `SECRET_PREFIX` defaults to
`$(STACK_NAME)` (`mon2`):

| Secret key | Docker secret name |
|---|---|
| grafana_admin_user | `mon2_grafana_admin_user` |
| grafana_admin_password | `mon2_grafana_admin_password` |

Override with `SECRET_PREFIX=<value>` on any `make` invocation.

`stack-deploy` exports both `CONFIG_PREFIX` and `SECRET_PREFIX` so `stack.yml`
interpolation matches overridden values.

**One-time migration — configs** (for a stack already running with the old
unprefixed names `scrape_config`, `alertmanager_config`, etc.):

```bash
# 1. Create the new prefixed configs alongside the old ones
make configs-create DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/ID/TOKEN

# 2. Redeploy — services repoint to the new names via stack.yml's name: field
make stack-deploy

# 3. Drop the old unprefixed configs (no longer referenced)
docker config rm scrape_config loki_config promtail_config \
  alertmanager_config grafana_datasources grafana_dashboards_provider \
  vmalert_rules
```

**One-time migration — secrets** (for a stack already running with the old
unprefixed names `grafana_admin_user`, `grafana_admin_password`):

```bash
# 1. Recreate with the CURRENT admin credentials (pass the actual values in use)
make secrets-create \
  GRAFANA_ADMIN_USER=<current-admin-user> \
  GRAFANA_ADMIN_PASSWORD=<current-admin-password>

# 2. Redeploy — Grafana repoints to the new names via stack.yml's name: field
make stack-deploy

# 3. Drop the old unprefixed secrets (no longer referenced)
docker secret rm grafana_admin_user grafana_admin_password
```

> **Credentials caveat.** Pass the **current** admin credentials during
> migration so the recreated secret content is identical to what is in use.
> Grafana persists the admin password in its database after first init, so an
> already-running instance will not change its login on redeploy — but using
> the correct values keeps the secret authoritative and avoids surprises on a
> fresh volume.

Docker configs and secrets are immutable — both migrations are
create-new → repoint → drop-old, not in-place renames.

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

### Hot-reload Alertmanager (webhook change, no downtime)

Use this when you only need to update the Discord webhook (or any other field
in `alertmanager.yml`) on a **running** stack and cannot afford to bring down
VictoriaMetrics, Grafana, Loki or vmalert.

```bash
make alertmanager-reload \
  DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/NEW_ID/NEW_TOKEN
```

What it does: renders `configs/alertmanager/alertmanager.yml` through
`envsubst`, performs a canonical-preserving double config swap via
`docker service update --config-rm`/`--config-add`, and restarts **only**
`$(STACK_NAME)_alertmanager`. `stack.yml` is not modified. Two brief rolling
restarts of Alertmanager; all other service tasks keep running.

Use `make configs-rotate` instead when you want to rebuild **all** configs
(scrape, Loki, Promtail, Alertmanager, Grafana, vmalert rules) — it depends
on `stack-rm` and takes the whole monitoring stack down temporarily.

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
