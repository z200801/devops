**English** | [Українська](README.uk.md)

# rustfs — Docker Swarm stack

RustFS S3-compatible object storage running as a Docker Swarm stack,
fronted by an in-stack Traefik v3 reverse proxy with fail2ban brute-force
protection. Designed as a drop-in MinIO replacement on a single-node
manager-only Swarm.

## Architecture

```
client
  └─► host nginx (public TLS, port 443)
        └─► Traefik websecure :19001 (self-signed TLS, stack-internal)
              ├─► rustfs S3 API  :9000  (Host: S3_HOST)
              └─► rustfs console :9001  (Host: CONSOLE_HOST)
```

Two services in stack `rustfs`:

| Service         | Image               | Ports published  |
|-----------------|---------------------|------------------|
| `rustfs_traefik`| `traefik:v3.7.10`   | 19000→80 (HTTP, redirect only), 19001→443 (HTTPS) |
| `rustfs_rustfs` | `rustfs/rustfs:latest` | none (internal only) |

Named volumes: `rustfs-data` (S3 objects), `rustfs-logs`.  
Overlay network: `rustfs-edge` (name pinned, attachable).

## Prerequisites

- Docker Engine with Swarm initialised (`docker swarm init` on the node)
- `make`, `bash`
- `rcli` (RustFS CLI, installed as `rcli`) for smoke tests and admin operations
- Outbound internet from the Swarm node at first deploy (Traefik downloads
  the `tomMoulard/fail2ban` plugin from the plugin catalog)

## Setup

### 1. Environment file

```bash
cp .env.example .env
$EDITOR .env
```

| Variable | Description |
|---|---|
| `S3_HOST` | Hostname routed to the S3 API (default: `s3.example.local`) |
| `CONSOLE_HOST` | Hostname routed to the console (default: `console.s3.example.local`) |
| `WEB_PORT` | Traefik HTTP port on the host (default: `19000`) |
| `WEBSECURE_PORT` | Traefik HTTPS port on the host (default: `19001`) |
| `TRUSTED_PROXY_IPS` | Docker ingress/gateway IP Traefik sees as the peer — see §Upstream proxy |

`S3_HOST` and `CONSOLE_HOST` must resolve to the Swarm node's address from
any host that runs the smoke test (DNS or `/etc/hosts`).

### 2. Create Docker secrets

RustFS credentials are stored as Docker Swarm secrets (not in `.env`).

```bash
make secret-create ACCESS_KEY=<your-access-key> SECRET_KEY=<your-secret-key>
```

Both values must be at least 8 characters. The secrets are created once and
persist across stack redeploys.

> **Root credential rotation** requires stopping the stack (causes ~30–60s
> downtime). Buckets, objects, and IAM users are preserved — the data volume
> is not touched.
>
> ```bash
> make secret-rotate ACCESS_KEY=<new-key> SECRET_KEY=<new-secret>
> ```
>
> After rotation, reconfigure rcli (`make alias-set`) and update all S3
> clients with the new credentials. For zero-downtime credential rotation,
> use service accounts instead (see [§Service accounts](#service-accounts-credential-rotation)).

> **Without Docker secrets:** uncomment `RUSTFS_ACCESS_KEY` /
> `RUSTFS_SECRET_KEY` in `.env`, replace `RUSTFS_ACCESS_KEY_FILE` /
> `RUSTFS_SECRET_KEY_FILE` with `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY`
> in `stack.yml` `environment:`, and remove the `secrets:` sections from
> `stack.yml`.

### 3. Deploy

```bash
make deploy
```

`make deploy` does four things in sequence:

1. Checks that Docker secrets `rustfs_access_key` and `rustfs_secret_key`
   exist (errors with a hint to `make secret-create` if missing).
2. Creates `docker config` objects for `traefik_config/traefik.yml` and
   `traefik_config/dynamic/fail2ban.yml` (idempotent; content-hashed names
   mean a file change automatically produces a new object on the next deploy).
3. Sources `.env` into the shell.
4. Runs `docker stack deploy -c stack.yml rustfs`.

To redeploy after changing a config file:

```bash
make deploy   # detects new hash, creates new docker config, updates the stack
```

### 4. Verify services

```bash
docker service ls
# Expected: rustfs_traefik 1/1, rustfs_rustfs 1/1

# Traefik healthcheck (ping endpoint on :8080, internal):
docker inspect --format '{{.State.Health.Status}}' \
  "$(docker ps -q -f name=rustfs_traefik)"
# Expected: healthy

# RustFS healthcheck:
docker inspect --format '{{.State.Health.Status}}' \
  "$(docker ps -q -f name=rustfs_rustfs)"
# Expected: healthy

# RustFS ports must NOT be published (only Traefik publishes):
docker service inspect rustfs_rustfs --format '{{json .Endpoint.Ports}}'
# Expected: null
```

### 5. Smoke test (rcli)

Requires `S3_HOST` to resolve to the node, `rcli` on `PATH`, and the
stack running (credentials are read from the container's Docker secrets):

```bash
make test
```

The script:
1. Configures an rcli alias pointing to `https://${S3_HOST}:${WEBSECURE_PORT}`
   (path-style, self-signed TLS, S3v4 signature).
2. Creates bucket `smoke-test`.
3. Uploads `smoke.txt`, downloads it, and verifies with `diff`.
4. Runs `make deploy` (redeploy) and polls `GET /health` through Traefik
   (up to 90 s, every 3 s) until the service is ready again.
5. Re-downloads and re-verifies the object (persistence check).

Expected output:

```
PASS: upload/download match
PASS: object survived redeploy
==> smoke OK
```

Pass `--skip-redeploy` to run only the upload/download check without redeploying.

## Console access

Open `https://${CONSOLE_HOST}` in a browser. The RustFS console login form
has two fields that map to the S3 root credentials (from Docker secrets):

| Field   | Value               |
|---------|---------------------|
| Account | `RUSTFS_ACCESS_KEY` |
| Key     | `RUSTFS_SECRET_KEY` |

RustFS has no separate console user — these are the same keys used by `rcli`.

## Access model

| Role | Console | rcli / S3 clients | Scope |
|---|---|---|---|
| **Admin** (`RUSTFS_ACCESS_KEY`) | Full access | All buckets + admin API | Unlimited |
| **User** (provisioned via `user-create`) | Not available | Own `<user>-*` buckets only | Isolated by policy |

**Admin** is the root credential (from Docker secrets). Admins authenticate
to the web console and use all `make admin-*` / `make user-*` targets.

**Users** are isolated accounts whose policy restricts S3 access to their
own `<user>-*` buckets. They connect via S3 clients or `rcli` only — **the
console is not available to non-admin users**: a scoped user is redirected
to `/rustfs/console/403` because the console currently requires `admin:*`
permissions (see [rustfs#2553](https://github.com/rustfs/rustfs/issues/2553)).
When #2553 is fixed, scoped users will gain a console view with no changes
required here.

## Policies

RustFS uses an AWS-style IAM policy model. Several built-in policies
(`readwrite`, `readonly`, `writeonly`, `diagnostics`) are always available.
Custom policies are static JSON — RustFS has no policy variables
(`${aws:username}` etc.), so per-user isolation requires a separate policy
per user with the username hard-coded (naming convention: `<user>-<suffix>`,
e.g. `alice-rw`). The `user-create` target handles this automatically via
`policies/user-rw.json.tpl`.

### Policy files

| File | Description |
|---|---|
| `policies/user-rw.json.tpl` | Per-user RW template (`__USER__`→name, used by `user-create`) |
| `policies/shared-ro.json` | Read-only access to a single shared bucket (`shared`) |
| `policies/dropbox-wo.json` | Write-only drop-box (put objects into `dropbox/`, no read) |
| `policies/team-rw.json` | Per-team RW on all `team-*` buckets |
| `policies/user_rw.aws-ref.json` | MinIO/AWS reference with policy variables — **does not work on RustFS** |

### Applying policies manually

```bash
# Upload and attach shared-ro to alice
make admin-policy-create POLICY=shared-ro FILE=policies/shared-ro.json
make admin-policy-attach POLICY=shared-ro FLAGS='--user alice'

# Upload and attach dropbox-wo to bob
make admin-policy-create POLICY=dropbox-wo FILE=policies/dropbox-wo.json
make admin-policy-attach POLICY=dropbox-wo FLAGS='--user bob'

# Upload and attach team-rw to carol
make admin-policy-create POLICY=team-rw FILE=policies/team-rw.json
make admin-policy-attach POLICY=team-rw FLAGS='--user carol'

# Inspect / list
make admin-policy-list
make admin-policy-info POLICY=shared-ro
make admin-policy-entities POLICY=shared-ro

# Detach and remove
make admin-policy-detach POLICY=shared-ro FLAGS='--user alice'
make admin-policy-remove POLICY=shared-ro
```

> `FLAGS='--user <name>'` must be quoted on the command line — unquoted,
> the shell splits `--user alice` into two words and make receives only `--user`.

> **admin-policy-\* works against RustFS.** Only `admin-info` returns HTTP 500
> (rustfs#1571). Bucket names are always visible to all authenticated users
> regardless of policy (rustfs#3279).

## Upstream proxy contract

This stack is designed to sit behind a host-level nginx that terminates
public TLS and forwards HTTPS to Traefik's `websecure` port:

```nginx
upstream upstream_s3 {
    server 127.0.0.1:19001;   # Traefik HTTPS/websecure — NOT 19000
    keepalive 16;
}
```

**Critical headers** nginx must forward:

```nginx
proxy_set_header Host              $host;   # Traefik routes by Host
proxy_set_header X-Real-IP         $remote_addr;  # fail2ban source criterion
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

**`TRUSTED_PROXY_IPS`** — must match the Docker ingress/gateway address that
Traefik sees as the TCP peer (NOT nginx's LAN IP). Measure it:

```bash
# After first deploy, send one request through nginx, then:
docker service logs rustfs_traefik 2>&1 | grep -i clientaddr | tail -5
```

Update `traefik_config/traefik.yml` `forwardedHeaders.trustedIPs` with the
measured CIDR (both `web` and `websecure` entrypoints), then run
`make deploy`. Without this, fail2ban bans the Docker ingress address
instead of the real client IP.

TLS: Traefik uses its built-in self-signed default certificate (no cert
files needed). nginx must set `proxy_ssl_verify off` when forwarding to it.

A complete example nginx config is in `nginx_config/s3.nginx.conf`.

## fail2ban

The `tomMoulard/fail2ban` plugin (v0.9.0) is loaded as a Traefik
experimental plugin and attached to both the S3 and console routers.

| Parameter | Value |
|---|---|
| `statuscode` | `401,403,429` |
| `maxretry` | 20 |
| `findtime` | 10 min |
| `bantime` | 3 h |
| Source criterion | `X-Real-IP` header |
| Allowlist | `127.0.0.1/32`, `::1/128` |

Ban parameters live in `traefik_config/dynamic/fail2ban.yml`. After editing,
run `make deploy` — the new content hash triggers a new docker config object.

`logLevel: DEBUG` is set for initial verification. Lower to `INFO` in
production by editing `traefik_config/dynamic/fail2ban.yml` and redeploying.

## CLI management

The Makefile uses `rcli` (RustFS native CLI) for all S3 and admin operations.
`rcli` must be on `PATH` (see `make install-rcli`).

### Setup

```bash
make install-rcli   # download rcli to /usr/local/bin (once per machine)
make alias-set      # create/update root 'rustfs' alias from Docker secrets + set active
```

`make alias-set` (no args) reads credentials directly from the running container's
Docker secrets and writes `rustfs` as the active alias to `.active_alias`.
All subsequent targets use the active alias by default.

### Alias management

Aliases are named connection profiles stored by `rcli`. The **active alias** is
tracked in `.active_alias` (git-ignored). All targets default to the active alias;
pass `ALIAS=<name>` on the command line to override for a single invocation.

| Target | Description |
|---|---|
| `alias-set` | Create/update root `rustfs` alias from Docker secrets + set active |
| `alias-set ALIAS=<name>` | Switch active alias to `<name>` (alias must already exist) |
| `alias-create ALIAS=<name> ACCESS_KEY=<key> SECRET_KEY=<secret>` | Register a named alias (does not change active) |
| `alias-rm ALIAS=<name>` | Remove a named alias (cannot be the active alias) |
| `alias-info [ALIAS=<name>]` | Show connection info for an alias |
| `alias-list` | List all configured aliases |

**Per-user service account workflow** (service accounts inherit the parent alias's user):

```bash
make alias-set                                           # create root alias + set active
make user-create USER=alice PASSWORD=alice123            # create user alice
make alias-create ALIAS=alice ACCESS_KEY=alice SECRET_KEY=alice123
make alias-set ALIAS=alice                               # switch to alice
make svcacct-create                                      # SA parent = alice
make svcacct-list USER=alice                             # list alice's service accounts
make alias-set                                           # switch back to root
make alias-rm ALIAS=alice                                # remove alias when done
```

`make install-mcli` installs the MinIO client as a legacy fallback (not required
for normal operation).

### Bucket operations

```bash
make bucket-create BUCKET=mybucket              # create bucket
make bucket-create BUCKET=photos USER=alice     # create bucket "alice-photos"
make bucket-list                                # list all buckets
make bucket-list BUCKET=mybucket                # list objects in bucket
make bucket-remove BUCKET=mybucket              # remove bucket
make bucket-anonymous-download BUCKET=mybucket  # set public download policy
```

When `USER=<name>` is provided, the bucket name is automatically prefixed with
`<user>-`. User `alice` already has a policy (`alice-rw`) granting `s3:*` on
`alice-*` buckets, so the bucket is immediately accessible to that user.

Users can also create their own `<user>-*` buckets directly from their own
credentials (via rcli or any S3 client) — the policy enforces the naming
convention at the S3 level. Buckets with other prefixes are denied by policy.

### User provisioning

`user-create` and `user-delete` wrap the admin API to provision isolated
per-user accounts. Each user receives a policy `<name>-rw` that restricts
access to `<name>-*` buckets only.

```bash
make user-create USER=alice                   # create user + policy, print generated password
make user-create USER=alice PASSWORD=mypass   # same with explicit password
make user-delete USER=alice                   # remove user + policy (buckets preserved)
make user-delete USER=alice DELETE_BUCKETS=1  # also remove alice-* buckets
make user-info USER=alice                     # show policy, alice-* buckets, service accounts
```

The generated password is `openssl rand -hex 24` (48-char hex, SigV4-safe).
`USER` must be passed on the `make` command line — the ambient shell `$USER`
is rejected.

Policy model (`policies/user-rw.json.tpl`, placeholder `__USER__` → name):

| Permission | Resource |
|---|---|
| `s3:ListAllMyBuckets` | `arn:aws:s3:::*` |
| `s3:ListBucket`, `s3:GetBucketLocation` | `arn:aws:s3:::alice-*` |
| `s3:*` | `arn:aws:s3:::alice-*` and `arn:aws:s3:::alice-*/*` |

> **rustfs#3279:** `s3:ListAllMyBuckets` is authorized before per-user policy
> evaluation, so any authenticated user can enumerate all bucket names regardless
> of policy. Object and bucket access is still isolated by the policy.
> Bucket-name visibility is not policy-scoped until #3279 is resolved.

### Service accounts (credential rotation)

Service accounts are sub-credentials created under a parent user. They inherit
the parent's policy and their secret key can be rotated **online** — no service
restart needed. This is the recommended zero-downtime rotation path
(root credential rotation via Docker secrets requires a stack stop — see §Create Docker secrets).

```bash
# Create a service account (under the alias's authenticated user = root admin):
make svcacct-create
# Output: SERVICE_ACCOUNT=<generated-ak> PASSWORD=<generated-sk>

# Create with an explicit access key and/or secret key:
make svcacct-create SERVICE_ACCOUNT=mykey PASSWORD=<new-secret>

# Create with an expiry (permanent if omitted; ISO 8601 datetime only):
make svcacct-create EXPIRY=2026-12-31T23:59:59Z

# Rotate the secret key (auto-generates if PASSWORD omitted; old key rejected immediately):
make svcacct-rotate SERVICE_ACCOUNT=<sa-access-key>
make svcacct-rotate SERVICE_ACCOUNT=<sa-access-key> PASSWORD=<new-secret>

# List service accounts for a user (by username, not access key):
make svcacct-list USER=root

# Show info for a specific service account:
make svcacct-info SERVICE_ACCOUNT=<sa-access-key>

# Remove a service account:
make svcacct-remove SERVICE_ACCOUNT=<sa-access-key>
```

After `svcacct-rotate`, reconfigure clients with the new secret key. The old
key is rejected immediately — no restart required.

### Health

```bash
make ping    # check if RustFS service is reachable
make ready   # check if RustFS dependencies are ready
```

### Admin API

All admin provisioning targets work against RustFS via rcli: `user-add`,
`user-remove`, `user-list`, `user-disable`, `user-enable`, `admin-policy-create`,
`admin-policy-attach`, `admin-policy-detach`, `admin-policy-list`, `admin-info`.
For day-to-day provisioning, prefer `user-create` / `user-delete` / `user-info` above.

## Teardown

Remove the stack (volumes are preserved):

```bash
docker stack rm rustfs
```

Remove data volumes (destructive — all stored objects are lost):

```bash
docker volume rm rustfs_rustfs-data rustfs_rustfs-logs
```

Remove Docker secrets (only after the stack is removed):

```bash
make secret-remove
```

Remove unused Traefik docker config objects after a config update:

```bash
docker config ls --filter name=traefik_static
docker config rm <old-name>
```
