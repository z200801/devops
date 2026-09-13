# Docker Compose — Gitea Deployment Templates

Two independent templates for a closed-loop (air-gapped / private network) environment:

- `full/` — Gitea + PostgreSQL + Traefik, deployed on the **server host**
- `runner/` — Gitea Act Runner, deployed on a **separate runner host**

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
│  Traefik v3             │  TLS termination · HTTP→Gitea routing
│  (Docker container)     │  TCP passthrough for SSH
└────────┬────────────────┘
         │  HTTP :3000   SSH :22  (internal Docker network)
         ▼
┌─────────────────────────┐
│  Gitea                  │  Web UI · Git · SSH · Actions API
│  (Docker container)     │
└────────┬────────────────┘
         │  PostgreSQL :5432
         ▼
┌─────────────────────────┐
│  PostgreSQL 14           │
│  (Docker container)     │
└─────────────────────────┘

            ┄┄┄ network ┄┄┄

Runner host (separate machine)
┌─────────────────────────┐
│  Gitea Act Runner       │  polls Gitea over HTTPS, executes jobs
│  (Docker container)     │
└─────────────────────────┘
```

---

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Docker Engine | ≥ 24.0 |
| Docker Compose plugin | v2 |
| OpenSSL | ≥ 1.1.1 (for `cert-generate`) |

---

## Quick start — full/ (server host)

```bash
cd docker-compose/full

# 1. Configure
cp .env.example .env
$EDITOR .env          # set DOMAIN, POSTGRES_PASSWORD, and other values

# 2. Generate a self-signed TLS certificate
make traefik-cert-generate

# 3. Start the stack
make up

# 4. Open Gitea in a browser
#    https://gitea.example.com  (or whatever DOMAIN you set)
```

On first visit Gitea shows an installation wizard. Database settings are
pre-populated from the environment — do not change them.

---

## Quick start — runner/ (runner host)

The runner must be started **after** Gitea is running and you have obtained
a registration token (see [Global runner registration](#global-runner-registration)).

```bash
cd docker-compose/runner

# 1. Configure
cp .env.example .env
$EDITOR .env   # set TOKEN, GITEA_INSTANCE_URL, RUNNER_NAME

# 2. Start the runner
make up

# 3. Verify registration
make status
# The runner appears in Gitea → Site Administration → Actions → Runners
```

---

## Global runner registration

A runner registered with an **instance-level** token becomes a **global** runner
visible to all repositories. Tokens obtained at the repository or organisation level
produce runners scoped only to that repo or org — those runners will appear idle
for workflows in other repositories.

**How to obtain an instance-level token:**

1. Log in as a Gitea administrator.
2. Go to **Site Administration** (top-right menu → "Site Administration").
3. Navigate to **Actions → Runners**.
4. Click **Create new runner** — copy the token shown.

Set this token as `TOKEN` in `docker-compose/runner/.env`.

**Runner labels** declared at registration time determine which job `runs-on:`
values the runner accepts:

```yaml
# .gitea/workflows/demo.yaml
jobs:
  build:
    runs-on: ubuntu-latest   # matches the runner label
```

The default labels configured in `runner/.env.example` are:
- `ubuntu-latest:docker://gitea/runner-images:ubuntu-latest`
- `ubuntu-22.04:docker://gitea/runner-images:ubuntu-22.04`

---

## Self-signed TLS certificates

### Generating a certificate

```bash
cd docker-compose/full
make traefik-cert-generate
# Creates: ./certs/cert.pem  ./certs/key.pem
```

The target runs `openssl req -x509` with CN and SAN both set to `DOMAIN`.
The `certs/` directory is gitignored — certificate files are never committed.

### How Traefik uses the certificate

On `make up`, Docker Compose bind-mounts the cert files into the Traefik
container (paths from `.env`):

```
TLS_CERT_PATH=./certs/cert.pem  →  /certs/cert.pem  (inside Traefik)
TLS_KEY_PATH=./certs/key.pem   →  /certs/key.pem
```

`traefik/dynamic/gitea.yml` declares these paths under `tls.certificates`,
making Traefik serve the cert for all HTTPS connections to `DOMAIN`.

### Zero-config fallback (no cert files)

`traefik/traefik.yml` contains a `tls.stores.default.defaultGeneratedCert`
block. When no matching certificate is found for a request, Traefik falls
back to its internal self-signed certificate automatically. This lets the
stack start and be reachable over HTTPS even before `cert-generate` is run,
at the cost of a browser warning.

### Runner TLS trust

The runner connects to Gitea over HTTPS using a self-signed certificate
that no public CA has signed. Six settings must all be enabled for a
closed-loop setup:

| Setting | Location | What it controls |
|---------|----------|-----------------|
| `GITEA_RUNNER_INSECURE_SKIP_VERIFY=true` | `runner/docker-compose.yml` env | Skips TLS verification for the runner's ongoing API calls to Gitea (job polling, status updates) |
| `GITEA_RUNNER_REGISTRATION_SKIP_VERIFY=true` | `runner/docker-compose.yml` env | Skips TLS verification during the initial runner registration request |
| `GITEA_CONFIG_INSECURE_SKIP_VERIFY=true` | `runner/docker-compose.yml` env | Skips TLS verification when the runner fetches its remote configuration |
| `host.skip_verify: true` and `runner.insecure: true` | `runner/data/config.yaml` | Runtime counterparts to the env vars above — apply after the runner process reads its config file, covering API calls not controlled by the env vars |
| `GIT_SSL_NO_VERIFY: "true"` | `runner/data/config.yaml` under `container.envs` | Intended to inject into job containers for `git clone` / `git fetch`. **Note:** due to a [known bug](https://github.com/go-gitea/gitea/issues/31396), `container.envs` values are not passed to job containers |
| `container.options` with `-e` flags | `runner/data/config.yaml` | Workaround for the `container.envs` bug: passes `GIT_SSL_NO_VERIFY=true` and `NODE_TLS_REJECT_UNAUTHORIZED=0` directly via Docker `-e` flags into every job container |

The `container.options` line in `runner/data/config.yaml` is the critical
workaround — without it, `actions/checkout` fails with
`server certificate verification failed` even though all other settings
are correct. The `NODE_TLS_REJECT_UNAUTHORIZED=0` flag is required
because `actions/checkout` is a Node.js action.

Removing any of these can cause silent failures: registration succeeds
but job clones fail, or polling works but config fetch errors out.

---

## Configuration reference

### full/.env variables

| Variable | Example value | Description |
|----------|---------------|-------------|
| `POSTGRES_USER` | `gitea` | PostgreSQL username |
| `POSTGRES_PASSWORD` | `changeme` | PostgreSQL password — **change this** |
| `POSTGRES_DB` | `gitea` | PostgreSQL database name |
| `ROOT_URL` | `https://gitea.example.com` | Gitea's public URL (must match DOMAIN) |
| `TZ` | `UTC` | Timezone for the Gitea container |
| `USER_UID` | `1000` | UID Gitea runs as inside the container |
| `USER_GID` | `1000` | GID Gitea runs as inside the container |
| `DOMAIN` | `gitea.example.com` | Domain Traefik routes HTTPS traffic to |
| `HTTPS_PORT` | `443` | Host port mapped to Traefik's HTTPS entrypoint |
| `SSH_PORT` | `2221` | Host port mapped to Traefik's SSH passthrough |
| `TLS_CERT_PATH` | `./certs/cert.pem` | Host path to TLS certificate |
| `TLS_KEY_PATH` | `./certs/key.pem` | Host path to TLS private key |

### runner/.env variables

| Variable | Example value | Description |
|----------|---------------|-------------|
| `TOKEN` | `<registration-token>` | Instance-level registration token from Gitea |
| `GITEA_INSTANCE_URL` | `https://gitea.example.com` | URL of the Gitea server |
| `RUNNER_NAME` | `gitea-runner` | Display name shown in the Gitea runner list |
| `GITEA_RUNNER_LABELS` | `ubuntu-latest:docker://...` | Comma-separated label:image pairs |

---

## Token rotation

When the runner token must be replaced without full redeployment:

```bash
cd docker-compose/runner

# Obtain a new token from Gitea Site Administration → Actions → Runners
make token-rotate TOKEN=<new-token>
```

`token-rotate` updates `TOKEN` in `.env` and force-recreates the runner
container. The runner re-registers with the new token on startup.

---

## Backup and restore

### Backup

```bash
cd docker-compose/full
make gitea-backup
# Saves a dump to ~/backups/gitea/gitea-<timestamp>.tar.gz
```

The backup uses `gitea dump` and includes repositories, database,
configuration, and attachments.

### Restore

```bash
cd docker-compose/full

make gitea-restore BACKUP=~/backups/gitea/gitea-<timestamp>.tar.gz
```

The `gitea-restore` target:
1. Stops the stack and starts only the database container
2. Drops and recreates the database, then imports `gitea-db.sql`
3. Starts the full stack and copies repos and data back
4. Regenerates Git hooks and restarts Gitea

After restore, verify with:

```bash
docker compose -p gitea exec --user 1000 gitea gitea doctor check
```

---

## Troubleshooting

### Runner appears idle — jobs never picked up

1. Check the runner is running: `make status` (in `runner/`).
2. Confirm the runner registered successfully:
   Gitea → Site Administration → Actions → Runners — the runner must be **Online**.
3. Verify the job's `runs-on:` label matches one of the runner's labels.
   Default labels: `ubuntu-latest`, `ubuntu-22.04`.
4. Check runner logs: `make logs` (in `runner/`).

### Runner is not global — only visible to one repository

The registration token was obtained from a repository or organisation page,
not from Site Administration. Global runners require an **instance-level** token.

Steps to fix:

1. Stop the runner: `make down` (in `runner/`).
2. Remove the runner state so it re-registers on next start:
   ```bash
   docker volume rm gitea-runner_runner-data
   ```
3. Obtain a new instance-level token from
   **Site Administration → Actions → Runners**.
4. Update `.env`: set `TOKEN=<new-instance-level-token>`.
5. Start the runner: `make up`.

### Runner TLS errors — connection refused or certificate errors

Symptom: runner logs show `x509: certificate signed by unknown authority`,
`tls: failed to verify certificate`, or registration fails immediately.

All five TLS trust settings must be present (see
[Runner TLS trust](#runner-tls-trust)). Check each location:

```bash
# Check env vars in the running container
docker inspect gitea-runner-gitea-runner-1 \
  | grep -E 'SKIP_VERIFY|INSECURE'

# Check config.yaml values
grep -E 'skip_verify|insecure|GIT_SSL' docker-compose/runner/data/config.yaml
```

If any setting is missing, add it and recreate the container:

```bash
cd docker-compose/runner
make down && make up
```

If git clone inside a job still fails with a TLS error, confirm
`GIT_SSL_NO_VERIFY: "true"` is present under `container.envs` in
`data/config.yaml` and that the config file is correctly bind-mounted
(check: `docker inspect` → `Mounts` → path `/data/config.yaml`).
