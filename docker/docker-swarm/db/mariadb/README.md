# MariaDB LTS Stack — Docker Swarm

MariaDB 12.3.3 as a single-replica Swarm stack, operated only through `make`.

## Stack

| Service | Mode | Port | Purpose |
|---|---|---|---|
| db | replicated 1 / manager | `DB_PORT` (default 23306), `mode: host` | MariaDB server; overlay network `<STACK_NAME>_mariadb` (attachable) for stacks inside Swarm |

Image: `mariadb:12.3.3@sha256:4ebbcf10…` (multi-arch index, amd64 + arm64).
`MARIADB_AUTO_UPGRADE` is not set: a new image never upgrades the datadir by
itself.

## File Structure

```
.
├── Makefile                 # the only supported interface — see "Make targets"
├── stack.yml
├── configs/
│   ├── my.cnf               # server config → Docker config <CONFIG_PREFIX>_my_cnf
│   └── replication/         # → <CONFIG_PREFIX>_repl_cnf, chosen by DB_ROLE
│       ├── standalone.cnf   #   DB_ROLE empty: no binlog
│       └── replication.cnf  #   DB_ROLE=primary|replica: GTID, semi-sync, read_only
├── scripts/                 # called by the Makefile (bash script.sh)
│   ├── configs.sh           # render / create / check / status (config registry)
│   ├── reload-service.sh    # apply a changed my.cnf / secret to the service
│   ├── cnf-check.sh         # my.cnf read check (validator, one-off servers)
│   ├── cleanup.sh           # docker-cleanup
│   ├── stack-health.sh      # stack-health
│   ├── db-common.sh         # client-container helpers for the db-* scripts
│   ├── db-cmd.sh            # db-cmd
│   ├── db-counts.sh         # db-counts
│   ├── db-backup.sh         # db-backup
│   ├── db-restore.sh        # db-restore
│   ├── repl.sh              # repl-* targets
│   ├── db-upgrade.sh        # db-upgrade
│   ├── healthcheck.sh       # healthcheck-check / healthcheck-fix
│   └── volume-from-snapshot.sh
├── README.replication.md    # replication, failover, upgrade, restart runbooks
└── LICENSE                  # MIT
```

## Architecture

- **Data volume** `DB_VOLUME` (default `<STACK_NAME>_db_data`) is `external` and is **never created by the stack**.
  Swarm would auto-create a missing volume (even an external one) and the
  entrypoint would initialise an empty database on it, so `stack.yml` also
  bind-mounts the volume's directory under `DOCKER_ROOT_DIR` read-only: when
  the volume does not exist the task is **rejected** instead. `stack-deploy`
  checks the volume first (`check-volume`).
- **Updates** are `stop-first` (one datadir); a failed update **pauses**
  (`failure_action: pause`), it does not roll back by itself.
- **Restart policy `any`**: a task that ends for any reason is replaced,
  including a clean exit 0 — which is how `mariadbd` ends when Swarm stops an
  unhealthy container. With `on-failure` the service would stay at 0/1. Only `docker service scale …=0` / `stack-rm` stop it for good.
- **Healthcheck** (`healthcheck.sh --connect`) logs in as `healthcheck@`
  with the password in `<datadir>/.my-healthcheck.cnf`. A datadir from
  compose may carry accounts with another password (compose checked health
  with `MARIADB_USER`): `make healthcheck-check` / `healthcheck-fix`.
- **Memory**: limit 512M, reservation 256M. With 256M `mariadbd` was
  OOM-killed during a full dump; a full `db-backup` peaked at ~237M on a
  ~0.5 GB dataset.
- **No client ever runs inside the db container** (it would share its memory
  limit). `db-cmd`, `db-counts`, `db-backup`, `db-restore` and
  `healthcheck-check` / `-fix` start a
  throwaway container of the same image with its own `--memory` on the db
  task's network namespace and connect as `root@'%'` over `127.0.0.1`. The
  root password is read from the task's secret (or the compose container's
  environment) and passed only as `MYSQL_PWD`.

Per-host settings never live in the repo; they stay in `$(DEPLOY_DIR)/.env`
and survive `make deploy-sync`:

| Key | Default | Purpose |
|---|---|---|
| `DB_PORT` | `23306` | published host port |
| `DB_VOLUME` | `<STACK_NAME>_db_data` | existing data volume |
| `DB_ROLE` | empty (standalone) | `primary` or `replica` — selects the replication config |
| `SERVER_ID` | `1` | `server_id`, unique within a replication pair |

`DOCKER_ROOT_DIR` is detected (`docker info`) and needs no setting.
Precedence: command line > environment > `$(DEPLOY_DIR)/.env` > default.

## Prerequisites

1. Docker Swarm active on the host (`make check-swarm`).
2. Tools: `docker`, `make`, `rsync`, `envsubst` (`make check-tools`).
3. The data volume exists (local driver): the production volume, a volume
   filled by `make volume-from-snapshot`, or — test stacks only —
   `make volume-create`.

## First deploy

Run from the stack directory of the git checkout (the one with this README):

```bash
make init
make deploy-sync DRY_RUN=1          # preview
make deploy-sync                    # copy to $(DEPLOY_DIR)
make env-init                       # then edit $(DEPLOY_DIR)/.env if needed
MARIADB_ROOT_PASSWORD='...' MARIADB_REPL_PASSWORD='...' make secrets-create
make configs-create
make stack-deploy
make stack-health
```

`MARIADB_REPL_PASSWORD` is the password of the replication account
(`make repl-user-create`); both servers of a pair need the same value. The
secret is mounted even on a standalone server, so it must exist before the
first deploy.

`MARIADB_ROOT_PASSWORD` has no default and is used only when given explicitly
(environment or command line). It is the password of the **existing** root
accounts of the datadir: on a non-empty volume the secret does not change
any account. On an empty volume (test stacks) the entrypoint initialises the
database with it.

`deploy-sync` rsyncs this directory to `DEPLOY_DIR` **without `--delete`** and
never copies `.git`, the top-level `.env` or `deploy.log`. Extra patterns:
`DEPLOY_EXCLUDES='README.md README.replication.md'`.

## Migration from docker compose

Takes over a running compose project **in place**: same data volume, same
port, same accounts and passwords. Downtime is `compose down` →
`stack-health` healthy (rehearsed with a ~0.5 GB dataset: ~9 s plus the
volume copy). Run every block on the database host from the stack directory
of the git checkout. The example assumes compose project `mariadb-lts`,
container `mariadb-lts-db-1` and volume `mariadb-lts_db_data`; set
`STACK_NAME` / `DB_VOLUME` in `.env` if yours differ.

> **Never run the compose project and the stack on the same volume at the
> same time** — two servers on one datadir corrupt it. After step 5 do not
> `docker compose up` in the old project directory except for the rollback
> below.

### 0. Variables

```bash
C=mariadb-lts-db-1                         # compose container
OLD=mariadb-lts_db_data                    # data volume the stack takes over
COPY=mariadb-lts_db_data_pre_swarm         # untouched copy for the rollback
CHECK=~/projects/mariadb-lts/bu/prod/migration
IMG=mariadb:12.3.3@sha256:4ebbcf100a3ba320766dfa0e1af008df12261301db6ef72798c7650f70794aed
COMPOSE_NET=<compose network of the db container, e.g. mariadb-lts_default>
COMPOSE_DIR=$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' "$C")
mkdir -p "$CHECK"
```

### 1. Pre-checks (no downtime)

```bash
docker inspect -f '{{.State.Health.Status}} {{.Config.Image}}' "$C"   # healthy
docker exec "$C" mariadbd --version                                    # 12.3.3
docker volume inspect -f '{{.Driver}} {{.Mountpoint}}' "$OLD"          # local <DockerRootDir>/volumes/...
docker info --format '{{.DockerRootDir}} swarm={{.Swarm.LocalNodeState}}'
docker exec "$C" sha256sum /var/lib/mysql/.my-healthcheck.cnf | tee "$CHECK/healthcheck.before"
docker network inspect "$COMPOSE_NET" -f '{{range .Containers}}{{.Name}} {{end}}'
make db-cmd SOURCE_CONTAINER="$C" SQL="SELECT USER, SUBSTRING_INDEX(HOST, ':', 1) AS client, COUNT(*) AS conns FROM information_schema.PROCESSLIST GROUP BY 1, 2" | tee "$CHECK/clients.before"
make healthcheck-check SOURCE_CONTAINER="$C"
df -h /var /home
```

- `healthcheck-check` must end with `OK:`. On `FAIL:` (the `healthcheck@`
  accounts do not match `.my-healthcheck.cnf` — happens when compose
  checked health with `MARIADB_USER`) fix them on
  the running compose server **before step 4**, or the stack's task turns
  unhealthy and is stopped right after the deploy:

  ```bash
  make healthcheck-fix SOURCE_CONTAINER="$C" CONFIRM=yes   # ends with healthcheck-check OK:
  ```

- The compose network must list only the db container. Any other container
  there reaches the db by the name `db` and loses it after `compose down` —
  switch it to `<host>:23306` (or the overlay `mariadb-lts_mariadb`) first.
- Free space: one more copy of the volume under `/var` (Docker root), a
  snapshot under `/home`.

### 2. Memory headroom, backup, reference counts (no downtime)

If the compose container has a small memory limit (256M), a full backup can
get `mariadbd` OOM-killed. Raise the limit of the
running container first (no restart; lost with `compose down`, the stack has
512M):

```bash
docker update --memory 512m --memory-swap 1g "$C"
make db-backup SOURCE_CONTAINER="$C"
make db-counts SOURCE_CONTAINER="$C" > "$CHECK/counts.before"
wc -l "$CHECK/counts.before"
```

`db-backup` must end with `OK: ... .tar.gz`; any `FAIL:` stops the migration.

### 3. Prepare the stack (no downtime)

The secret gets the root password of the running server, read from the
compose container (no password typed):

```bash
make init deploy-sync env-init
MARIADB_ROOT_PASSWORD="$(docker exec "$C" printenv MARIADB_ROOT_PASSWORD)" \
  MARIADB_REPL_PASSWORD="$(openssl rand -base64 24)" make secrets-create
make configs-create
make configs-status                 # my_cnf OK, repl_cnf OK (standalone)
```

`DB_ROLE` stays empty: the migration keeps the current settings (no binary
log). Replication is enabled later (`README.replication.md`, R1). The generated replication
password can be read back from the running task when the replica is set up:
`docker exec <task> cat /run/secrets/repl_password`.

### 4. Stop compose (downtime starts)

```bash
docker compose -p mariadb-lts down          # NEVER -v: it deletes the data volume
docker ps -a --filter name="$C" -q          # empty
```

### 5. Untouched copy of the volume

Cold copy (the server is stopped), then a file-by-file checksum comparison:

```bash
docker volume create "$COPY"
docker run --rm --network none -v "$OLD":/from:ro -v "$COPY":/to --entrypoint cp "$IMG" -a /from/. /to/
docker run --rm --network none -v "$OLD":/from:ro -v "$COPY":/to:ro --entrypoint bash "$IMG" -c \
  'sum() { cd "$1" && find . -type f -exec sha256sum {} + | sort -k2; }; cmp <(sum /from) <(sum /to) && echo "copy identical"'
```

### 6. Deploy the stack

```bash
make stack-deploy                   # checks secret, config, volume $OLD
timeout 300 bash -c 'until make -s stack-health >/dev/null 2>&1; do sleep 3; done'
make stack-health                   # OK: all services converged and healthy
```

Unhealthy, and the log shows `Access denied for user 'healthcheck'`: the
accounts do not match `.my-healthcheck.cnf`. While a task is running (the
policy `any` keeps replacing it; each has a 120 s start period):

```bash
make healthcheck-fix CONFIRM=yes    # then make stack-health
```

### 7. Data checks (downtime ends when these pass)

```bash
make db-counts > "$CHECK/counts.after"
diff "$CHECK/counts.before" "$CHECK/counts.after" && echo "row counts unchanged"
make db-cmd SQL="SELECT VERSION(), CURRENT_USER()"            # root password from the secret works
docker exec "$(docker ps -q -f label=com.docker.swarm.service.name=mariadb-lts_db)" \
  sha256sum /var/lib/mysql/.my-healthcheck.cnf | diff "$CHECK/healthcheck.before" - && echo "healthcheck.cnf unchanged"
docker service logs mariadb-lts_db 2>&1 | grep -iE 'crash recovery|\[ERROR\]'   # nothing
```

### 8. Clients

Applications keep connecting to `<host>:23306`. Restart or reconnect them
and compare with the list from step 1:

```bash
make db-cmd SQL="SELECT USER, SUBSTRING_INDEX(HOST, ':', 1) AS client, COUNT(*) AS conns FROM information_schema.PROCESSLIST GROUP BY 1, 2"
```

### 9. Rollback (if step 6–8 fails)

Back to compose on the **untouched copy** (writes made on the stack after
step 6 are not in it):

```bash
make stack-rm
cd "$COMPOSE_DIR"
cat > rollback.override.yml <<'EOF'
volumes:
  db_data: !override
    external: true
    name: mariadb-lts_db_data_pre_swarm
EOF
docker compose -p mariadb-lts -f docker-compose.yml -f rollback.override.yml up -d --pull never
docker inspect -f '{{.State.Health.Status}}' mariadb-lts-db-1
```

Rehearsed: healthy on the copy, row counts equal to step 2. To keep
the stack's writes instead, run compose on `$OLD` (`docker compose -p
mariadb-lts up -d --pull never` in `$COMPOSE_DIR`) — only after `make
stack-rm` has finished.

### 10. After a successful migration

- Keep `$COPY` and the snapshot until the stack has run without problems,
  then `docker volume rm "$COPY"` and delete the snapshot (it holds password
  hashes).

## Operations

```bash
make status                         # service replicas
make ps                             # task history
make stack-health                   # converged + healthy now
make logs                           # follow the server log
make stats                          # CPU / memory
make db-cmd SQL='SHOW DATABASES'    # SQL as root in a client container (DB= optional)
make db-counts                      # exact row count per table
make service-update                 # restart the task (stop-first)
make exec                           # shell in the db container — no DB clients there
```

A `$` in `SQL=` must be written `$$` (the Makefile expands `$`).

## Replication

A pair of two servers running this stack: the **primary** takes all
writes, the **replica** follows it with GTID replication and semi-sync
and refuses every client write, root included. The role is configuration
(`DB_ROLE` / `SERVER_ID` in `$(DEPLOY_DIR)/.env` + `make reload-service`), so
it survives restarts; without `DB_ROLE` a server is standalone (no binary
log) — the state after a compose migration.

Everything about replication — setting it up, failover, failback, replica
recovery, background and the `repl-*` targets — is in
[`README.replication.md`](README.replication.md). Start there with the
"Start here" table.

## Applying config changes

Edit `configs/my.cnf` (or `configs/replication/*.cnf`), `make deploy-sync`, then:

```bash
make configs-status                 # my_cnf / repl_cnf CHANGED
make reload-service DRY_RUN=1       # compare + validate only
make reload-service                 # validate, then swap the config
```

- **Validation** runs `mariadbd --help --verbose` with the service image and
  the new file; an unknown option or a bad value stops the reload
  (`[ERROR] mariadbd: unknown variable ...`, service not changed). A read
  check first proves the file is actually read (`my_print_defaults`), so an
  unreadable file fails instead of passing as "valid".
- The swap keeps the canonical config name (temp object, then back), so the
  service **restarts twice** (stop-first; ~60 s in total on an empty test
  datadir — longer with more data).
- `MARIADB_ROOT_PASSWORD=` makes `configs-status` / `reload-service` compare
  the root secret too. Changing the secret does **not** change the server's
  root password — that is `ALTER USER` in SQL.

| State | Meaning |
|---|---|
| `OK` | live object equals the repo source |
| `CHANGED` | differs — `reload-service` applies it |
| `MISSING` | object does not exist — `configs-create` / `secrets-create` |
| `SKIPPED` | secret not compared (value not given) |
| `UNKNOWN` | secret without `sha256` label — use `FORCE=1` |

**An update ended `paused`** (tasks exit non-zero after a reload or a
deploy): `make service-rollback` returns to the previous spec — rehearsed
after a bad `my.cnf`: `rollback_completed`, healthy. Remove a leftover
`<name>__<timestamp>` config afterwards (`make docker-cleanup` lists it).

## Backup and restore

```bash
make db-backup                                          # snapshot of the running stack
make db-backup SOURCE_CONTAINER=<compose container>     # of a compose container
make db-restore FILE=<snapshot.tar.gz> CONFIRM=yes      # logical, into the running stack
make db-restore FILE=<snapshot.tar.gz> DB=<name> CONFIRM=yes   # one database
make volume-from-snapshot SNAPSHOT=<snapshot.tar.gz> CONFIRM=yes   # physical, into DB_VOLUME
```

**`db-backup`** writes `BU_DIR/<STACK_NAME>-snapshot-<timestamp>.tar.gz` +
`.sha256`: `mb/` (prepared `mariadb-backup`), `dump.sql.gz` (application
databases, `--routines --events --triggers`, never `--all-databases`),
`users.sql` (`--system=users`), `DATABASES`, `VERSION`, `IMAGE_DIGEST`, logs.
On a replica (`event_scheduler = DISABLED`) `dump.sql.gz` has no events and
the snapshot contains `EVENTS_SKIPPED`. Every step is validated
(`completed OK!`, `-- Dump completed`, non-empty
database list, server not restarted); any failure prints `FAIL:`, removes the
partial snapshot and exits non-zero. Snapshots contain password hashes —
never commit or share them.

**`db-restore`** loads `dump.sql.gz` (tables in the dump are dropped and
recreated), then the accounts from `users.sql` with `CREATE OR REPLACE USER`
— except `root`, `healthcheck` and `mariadb.sys`, whose `GRANT ... IDENTIFIED
BY PASSWORD` lines would replace the target's own passwords. `DB=` restores
one database and skips accounts; a bare `dump.sql.gz` restores no accounts.

**`volume-from-snapshot`** needs an empty volume that no container uses
(created if missing; run `make stack-rm` first). It verifies the `.sha256`,
moves `mb/` into the volume (`--move-back`, `chown mysql`), then starts a
one-off server with `MARIADB_AUTO_UPGRADE=1` so the entrypoint recreates the
healthcheck user and `.my-healthcheck.cnf`, which a physical backup does not
contain. `RESET_ROOT=yes` (test stacks `mariadb-test*` only, with
`MARIADB_ROOT_PASSWORD` equal to the stack's secret) sets `root@localhost`
and `root@'%'` to the secret's password. Then `make stack-deploy`.

## Teardown

```bash
make stack-rm                       # data volume, secret and config stay
make docker-cleanup                 # list leftovers, changes nothing
make docker-cleanup CONFIGS=1 SECRETS=1 CONFIRM=yes
```

`VOLUMES=1` removes the data volume and is refused unless `STACK_NAME` and
`DB_VOLUME` start with `mariadb-test`. `docker-cleanup` refuses while the
stack still has services. Flags accept `1`, `y`, `yes`, `true`.

## Make targets

`make help` prints the same list.

| Group | Target | Purpose |
|---|---|---|
| Setup | `init`, `env-init`, `deploy-sync` | `DEPLOY_DIR`, its `.env`, copy from the checkout (`DRY_RUN=1`) |
| | `check-swarm`, `check-env`, `check-tools`, `check-volume` | pre-flight checks (run by `stack-deploy`) |
| Secrets | `secrets-create`, `secrets-check`, `secrets-list` | root and replication password secrets |
| Configs | `configs-create`, `configs-check`, `configs-list`, `configs-status` | my.cnf and replication configs |
| | `reload-service` | apply a changed config / secret (`DRY_RUN=1`, `FORCE=1`) |
| Stack | `stack-deploy`, `stack-rm`, `stack-health`, `status`, `ps`, `stats` | deploy / remove / state |
| | `docker-cleanup` | remove leftovers (`CONFIGS=1 SECRETS=1 VOLUMES=1 CONFIRM=yes`) |
| Service | `logs`, `exec`, `service-update`, `service-rollback` | `SERVICE=db` |
| Database | `db-cmd`, `db-counts` | SQL / row counts in a client container |
| | `db-upgrade` | `mariadb-upgrade` after an image change (`FORCE=1`); see `README.replication.md` |
| | `healthcheck-check`, `healthcheck-fix` | `healthcheck@` accounts vs `.my-healthcheck.cnf`; fix without binlog (`CONFIRM=yes`, `SOURCE_CONTAINER=`) |
| Backup | `db-backup`, `db-restore`, `volume-from-snapshot` | snapshot, logical and physical restore |
| Replication | `repl-status`, `repl-user-create`, `repl-dump`, `repl-start`, `repl-stop`, `repl-promote`, `repl-demote` | GTID / semi-sync, both roles |
| Test | `volume-create` | empty volume, `mariadb-test*` stacks only |

## Makefile variables

| Variable | Default | Description |
|---|---|---|
| `PROJECT_NAME` | `mariadb-lts` | Project name |
| `ENV` | `prod` | Environment (part of `DEPLOY_DIR`, `BU_DIR`) |
| `STACK_NAME` | `mariadb-lts` | Docker stack name |
| `PROJECTS_DIR` | `~/projects` | Base directory |
| `DEPLOY_DIR` | `$(PROJECTS_DIR)/$(PROJECT_NAME)/dswarm/$(ENV)/deploy` | Deployed files and host `.env` |
| `DB_PORT` | `.env`, else `23306` | Published port |
| `DB_VOLUME` | `.env`, else `$(STACK_NAME)_db_data` | Data volume |
| `DOCKER_ROOT_DIR` | `docker info` | Volume guard path |
| `CONFIG_PREFIX` / `SECRET_PREFIX` | `$(STACK_NAME)` | Prefix of Docker config / secret names |
| `MARIADB_ROOT_PASSWORD` | — | Root password (explicit only; secret value, `RESET_ROOT`, client override) |
| `MARIADB_REPL_PASSWORD` | — | Replication password (explicit only; secret value, override for `repl-*`) |
| `DB_ROLE` / `SERVER_ID` | `.env`, else empty / `1` | Replication role and server id |
| `PRIMARY_HOST` / `PRIMARY_PORT` | — / `23306` | `repl-start`, `repl-demote` |
| `REPLICA_HOST` / `REPL_USER` | — / `repl` | `repl-user-create` |
| `GTID_POS` | — | `repl-start` position (instead of `FILE=`) |
| `NO_BINLOG` | — | `yes`: `db-restore` without writing the binary log |
| `SERVICE` | `db` | Service name without stack prefix |
| `SQL` / `DB` | — | `db-cmd`; `DB` also for `db-restore` |
| `BU_DIR` | `$(PROJECTS_DIR)/$(PROJECT_NAME)/bu/$(ENV)` | `db-backup` destination |
| `SOURCE_CONTAINER` | — | Compose container for `db-backup`, `db-counts`, `db-cmd` |
| `FILE` / `SNAPSHOT` | — | `db-restore`, `repl-start` / `volume-from-snapshot` input |
| `RESET_ROOT` | — | `yes`: `volume-from-snapshot` sets root to the secret (test stacks) |
| `CONFIRM` | — | `yes` for `db-restore`, `volume-from-snapshot`, `docker-cleanup` |
| `DB_IMAGE` | `image:` of `stack.yml` | Image for backup/restore containers |
| `DRY_RUN` / `FORCE` | — | `reload-service`, `deploy-sync` |
| `RELOAD_TIMEOUT` | `300` | Seconds per rolling update in `reload-service` |
| `DEPLOY_EXCLUDES` | — | Extra rsync excludes for `deploy-sync` |

## License

MIT — see [`LICENSE`](LICENSE).
