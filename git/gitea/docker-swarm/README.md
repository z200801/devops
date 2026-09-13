# Docker Swarm — Gitea Deployment Templates

Two independent templates for a single-node Docker Swarm in a
closed-loop (air-gapped / private network) environment:

- `full/` — Gitea + PostgreSQL + Traefik, deployed as a Swarm stack on the **server host**
- `runner/` — Gitea Act Runner, deployed as a separate Swarm stack on the **runner host**

---

## Why single-node Swarm only

Multi-node Docker Swarm uses VXLAN over **UDP port 4789** for overlay
network traffic. In closed-loop environments with strict UDP filtering
(firewalls, switches with flood-guard, or SDN policies), VXLAN packets
are silently dropped and inter-node service communication fails without
a clear error.

Single-node Swarm avoids VXLAN entirely — all traffic stays on the
local bridge — while retaining the Swarm API benefits:

- **Docker secrets** — encrypted at rest, mounted as files in containers
- **`docker stack deploy`** — declarative stack management
- **Rolling updates** via `docker service update`

For multi-node setups, consider host networking or macvlan instead of
overlay networks.

---

## Architecture

```
External client
      │
      ▼
┌─────────────────────────┐
│  Host Nginx / bastion   │  (optional — handles external port forwarding
│  or firewall            │   and HTTP→HTTPS redirect before Traefik)
└────────┬────────────────┘
         │  HTTPS :443   SSH :2221
         ▼
┌─────────────────────────┐
│  Traefik v3             │  Swarm service · reads labels for routing
│  (Swarm service)        │  Docker socket on manager node
└────────┬────────────────┘
         │  HTTP :3000   SSH :22  (overlay network — single-node bridge)
         ▼
┌─────────────────────────┐
│  Gitea                  │  Swarm service · deploy labels drive Traefik
│  (Swarm service)        │
└────────┬────────────────┘
         │  PostgreSQL :5432
         ▼
┌─────────────────────────┐
│  PostgreSQL 14           │  Swarm service · password from Docker secret
│  (Swarm service)        │
└─────────────────────────┘

      ┄┄┄ overlay network ┄┄┄

Runner host (separate machine or same node)
┌─────────────────────────┐
│  Gitea Act Runner       │  Separate Swarm stack · token from Docker secret
│  (Swarm service)        │  polls Gitea over HTTPS, executes jobs
└─────────────────────────┘
```

---

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Docker Engine | ≥ 24.0 | |
| Swarm mode | active | run `docker swarm init` once |
| OpenSSL | ≥ 1.1.1 | for self-signed cert generation |

### Initialise Swarm mode

```bash
docker swarm init
# If the host has multiple IPs, specify the one to advertise:
docker swarm init --advertise-addr <host-ip>
```

Swarm mode is required even for a single node — `docker stack deploy`
and `docker secret` are only available in Swarm mode.

---

## Quick start — full/ (server host)

```bash
cd docker-swarm/full

# 1. Configure
cp .env.example .env
$EDITOR .env   # set DOMAIN, ROOT_URL, and other values

# 2. Generate a self-signed TLS certificate and create Docker configs
make traefik-cert-generate
make traefik-config-create

# 3. Create required Docker secrets (auto-generates random values)
make secrets-create

# 4. Deploy the stack
make stack-deploy

# 5. Check service health
make stack-status

# 6. Open Gitea in a browser
#    https://<DOMAIN>  (or the port set in HTTPS_PORT)
```

On first visit Gitea shows an installation wizard. Database settings
are pre-populated from the environment — do not change them.

---

## Quick start — runner/ (runner host)

The runner must be started **after** Gitea is running and you have
obtained a registration token (see
[Global runner registration](#global-runner-registration)).

```bash
cd docker-swarm/runner

# 1. Configure
cp .env.example .env
$EDITOR .env   # set GITEA_INSTANCE_URL and RUNNER_NAME

# 2. Create the token secret (paste token from Gitea UI)
echo -n "<registration-token>" | make secrets-create

# 3. Deploy the stack
make stack-deploy

# 4. Verify registration
make stack-status
# The runner appears in Gitea → Site Administration → Actions → Runners
```

---

## Global runner registration

A runner registered with an **instance-level** token becomes a **global**
runner visible to all repositories. Tokens obtained at the repository or
organisation level produce runners scoped only to that repo or org.

**How to obtain an instance-level token:**

1. Log in as a Gitea administrator.
2. Go to **Site Administration** (top-right menu → "Site Administration").
3. Navigate to **Actions → Runners**.
4. Click **Create new runner** — copy the token shown.

Set this token as the `gitea_runner_token` secret:

```bash
echo -n "<instance-level-token>" | docker secret create gitea_runner_token -
```

**Runner labels** declared at registration time determine which job
`runs-on:` values the runner accepts:

```yaml
# .gitea/workflows/demo.yaml
jobs:
  build:
    runs-on: ubuntu-latest   # matches the default runner label
```

Default labels configured in `runner/.env.example`:
- `ubuntu-latest:docker://gitea/runner-images:ubuntu-latest`
- `ubuntu-22.04:docker://gitea/runner-images:ubuntu-22.04`

---

## Secrets management

### Create all secrets (full stack)

```bash
cd docker-swarm/full
make secrets-create
#   created: gitea_db_password = a1b2c3...
#   created: gitea_admin_password = d4e5f6...
#   exists: gitea_db_password       ← skips if already present
```

### Create a single secret

```bash
echo -n "myvalue" | make secret-create NAME=db_password
# Creates: gitea_db_password  (stack prefix added automatically)
```

### List and inspect secrets

```bash
make secrets-list           # list Docker secrets belonging to this stack
make secrets-ls             # show secret names and values (reads from running container)
```

### Remove a secret

A secret in use by a running service cannot be removed directly.
Stop or update the service first, then:

```bash
make secret-rm NAME=db_password
```

### Rotate all secrets (full stack)

```bash
make secrets-rotate
#   rotated: gitea_db_password → gitea_db_password_1726234567 = ...
#   rotated: gitea_admin_password → gitea_admin_password_1726234567 = ...
#   ---
#   Redeploy to apply: make stack-deploy
```

### Rotate a single secret

```bash
make secret-rotate NAME=db_password              # auto-generates value
make secret-rotate NAME=db_password VALUE=newpass  # explicit value
```

### Rotate the runner token

```bash
cd docker-swarm/runner
echo -n "<new-token>" | make token-rotate
# or:
make token-rotate VALUE=<new-token>
# Output: Token rotated. Active secret: gitea_runner_token_<epoch>

# After verifying the runner re-registered, remove the old secret:
docker secret rm gitea_runner_token
```

---

## Configuration reference

### full/.env variables

| Variable | Example value | Description |
|----------|---------------|-------------|
| `POSTGRES_USER` | `gitea` | PostgreSQL username |
| `POSTGRES_DB` | `gitea` | PostgreSQL database name |
| `ROOT_URL` | `https://gitea.example.com` | Gitea's public URL |
| `TZ` | `UTC` | Timezone for the Gitea container |
| `USER_UID` | `1000` | UID Gitea runs as inside the container |
| `USER_GID` | `1000` | GID Gitea runs as inside the container |
| `DOMAIN` | `gitea.example.com` | Domain Traefik routes HTTPS traffic to |
| `HTTPS_PORT` | `443` | Host port for Traefik's HTTPS entrypoint |
| `SSH_PORT` | `2221` | Host port for Traefik's SSH passthrough |

> **Note:** `POSTGRES_PASSWORD` is not in `.env` — it is a Docker secret
> (`gitea_db_password`). PostgreSQL reads it via `POSTGRES_PASSWORD_FILE`.

### runner/.env variables

| Variable | Example value | Description |
|----------|---------------|-------------|
| `GITEA_INSTANCE_URL` | `https://gitea.example.com` | URL of the Gitea server |
| `RUNNER_NAME` | `gitea-swarm-runner` | Display name shown in the runner list |
| `GITEA_RUNNER_LABELS` | `ubuntu-latest:docker://...` | Comma-separated label:image pairs |

> **Note:** `TOKEN` is not in `.env` — it is a Docker secret
> (`gitea_runner_token`).

---

## Backup and restore

### Backup

```bash
cd docker-swarm/full
make gitea-backup
# Saves a dump to ~/backups/gitea/gitea-<timestamp>.tar.gz
```

The backup uses `gitea dump` and includes repositories, database,
configuration, and attachments.

### Restore

```bash
make gitea-restore BACKUP=~/backups/gitea/gitea-<timestamp>.tar.gz
```

The `gitea-restore` target:
1. Scales Gitea to 0 replicas
2. Drops and recreates the database, then imports `gitea-db.sql`
3. Scales Gitea back to 1 and copies data and repos into `/data/gitea/`
4. Regenerates Git hooks and force-updates the service

### Repository-only backup

```bash
make gitea-backup-repos                                              # archive only git repos
make gitea-restore-repos BACKUP=~/backups/gitea/gitea-repos-<ts>.tar.gz  # restore repos only
```

### Backup garbage collection

GFS (Grandfather-Father-Son) retention — keeps COUNT copies per period
(daily, weekly, monthly, yearly). COUNT must be ≥ 2.

```bash
make gitea-backup-gc                    # dry run, default COUNT=3
make gitea-backup-gc COUNT=5            # dry run, keep 5 per period
make gitea-backup-gc COUNT=3 FORCE=1    # actually delete old backups
```

---

## Makefile targets reference

### full/

| Target | Description |
|--------|-------------|
| `stack-deploy` | Deploy or update the Swarm stack |
| `stack-rm` | Remove the stack (keeps volumes and secrets) |
| `stack-status` | Show stack service status |
| `service-restart SERVICE=` | Force-restart a service (gitea, db, traefik) |
| `logs SERVICE=` | Tail service logs |
| `secrets-create` | Create all required secrets (auto-generates values) |
| `secret-create NAME=` | Create one secret with stack prefix from stdin |
| `secret-rm NAME=` | Remove a secret |
| `secrets-list` | List Docker secrets for this stack |
| `secrets-ls` | Show secret names and values (from running container) |
| `secrets-rotate` | Rotate all secrets with versioned names |
| `secret-rotate NAME= [VALUE=]` | Rotate one secret (auto-generates if no VALUE) |
| `gitea-backup-list` | List available backups |
| `gitea-backup` | Full Gitea dump to ~/backups/gitea/ |
| `gitea-restore BACKUP=` | Restore from a dump archive |
| `gitea-backup-repos` | Archive only Git repositories |
| `gitea-restore-repos BACKUP=` | Restore only repositories |
| `gitea-backup-gc [COUNT=] [FORCE=1]` | GC old backups with GFS retention |
| `traefik-cert-generate` | Generate self-signed cert+key into ./certs/ |
| `traefik-config-create` | Create Docker configs for Traefik (certs + dynamic TLS) |
| `traefik-config-ls` | List Docker configs for Traefik |
| `traefik-config-rm` | Remove all Traefik Docker configs (stack must be stopped) |
| `traefik-config-rotate` | Rotate Traefik configs (tls.yml) without stopping gitea/db |
| `traefik-cert-rotate` | Rotate TLS certs+configs: stack-rm → generate → recreate all → stack-deploy |
| `gitea-registration-enable` | Allow new user self-registration |
| `gitea-user-list` | List all Gitea users |
| `gitea-registry-enable` | Enable the package/container registry |

### runner/

| Target | Description |
|--------|-------------|
| `stack-deploy` | Deploy or update the runner stack |
| `stack-rm` | Remove the runner stack (keeps volumes and secrets) |
| `stack-status` | Show stack service status |
| `logs` | Tail runner service logs |
| `secrets-create` | Create runner token secret from stdin |
| `secrets-list` | List Docker secrets for this runner |
| `secrets-ls` | Show secret names and values (from running container) |
| `token-rotate [VALUE=]` | Rotate runner token (from stdin or VALUE=) |

---

## Runner TLS trust (self-signed certificates)

The runner connects to Gitea over HTTPS. With self-signed certificates,
these settings in `runner/stack.yml` and `runner/data/config.yaml` must
all be enabled:

| Setting | Location | What it controls |
|---------|----------|-----------------|
| `GITEA_RUNNER_INSECURE_SKIP_VERIFY=true` | `runner/stack.yml` env | Skips TLS verification for API calls (job polling, status updates) |
| `GITEA_RUNNER_REGISTRATION_SKIP_VERIFY=true` | `runner/stack.yml` env | Skips TLS verification during runner registration |
| `GITEA_CONFIG_INSECURE_SKIP_VERIFY=true` | `runner/stack.yml` env | Skips TLS verification when fetching remote configuration |
| `host.skip_verify: true` / `runner.insecure: true` | `runner/data/config.yaml` | Config-file counterparts to the env vars above |
| `container.options` with `-e` flags | `runner/data/config.yaml` | Passes `GIT_SSL_NO_VERIFY=true` and `NODE_TLS_REJECT_UNAUTHORIZED=0` into every job container via Docker `-e` flags |

The `container.options` line is critical — `container.envs` values are
**not** passed to job containers due to a
[known bug](https://github.com/go-gitea/gitea/issues/31396).
Without `container.options`, `actions/checkout` fails with
`server certificate verification failed`.

---

## Troubleshooting

### Stack services show 0/1 replicas

```bash
# Show recent task failures
docker service ps --no-trunc <stack>_<service>
# Inspect the last failed task for the exit reason
```

Common causes:
- Secret not created before deploying — verify with `docker secret ls`
- `.env` not copied from `.env.example` — `make stack-deploy` sources it
  and will error if it is missing
- Entrypoint binary path wrong in the shell wrapper — check logs for
  `exec: not found`

### Runner appears idle — jobs never picked up

1. Confirm the runner is online: `make stack-status` (in `runner/`).
2. Verify the runner is **global** (see
   [Global runner registration](#global-runner-registration)).
3. Check that the job's `runs-on:` label matches a label in
   `runner/data/config.yaml`.
4. Tail runner logs: `make logs` (in `runner/`).

### Runner is not global — only visible to one repository

The registration token was obtained from a repository or organisation
page, not from Site Administration. Fix:

```bash
cd docker-swarm/runner
# Remove the runner state so it re-registers
docker service scale gitea-runner_runner=0
docker volume rm gitea-runner_runner-data
docker service scale gitea-runner_runner=1
# Obtain a new instance-level token and rotate it
echo -n "<new-instance-token>" | make token-rotate
```

### Service fails to start: "secret not found"

The secret referenced in `stack.yml` must be created before deploying:

```bash
docker secret ls | grep gitea_
# Create any missing secrets:
make secrets-create
make stack-deploy
```

### Overlay network errors (multi-node attempt)

Single-node Swarm uses a local bridge for the overlay network — no
VXLAN traffic is generated. If you add a second node and services lose
connectivity, UDP port 4789 is likely blocked. Either open UDP 4789
between nodes or keep the deployment single-node.
