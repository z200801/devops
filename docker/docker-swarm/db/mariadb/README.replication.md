# MariaDB LTS — Replication and operations runbooks

Runbooks for a primary / replica pair of the `mariadb-lts` stack, the
MariaDB upgrade and the checks after an unplanned restart. Every runbook was
executed end to end on a test host with the test pair `mariadb-test-a` /
`mariadb-test-b` ([Rehearsal](#rehearsal)). Unknown terms:
[Glossary](#glossary).

## Start here

| What happened / what you want | Runbook |
|-------------------------------|---------|
| Enable replication; the replica host still runs an old MariaDB stack | [R1-old — Replace an old replica stack](#r1-old--replace-an-old-replica-stack) |
| The primary is lost and will not be back soon | [R2 — Failover](#r2--failover-the-primary-is-lost) |
| The old primary's host is back after a failover | [R3a — Demote the returning server](#r3a--demote-the-returning-server) |
| Planned switch back to the original roles | [R3b — Failback](#r3b--failback-planned-switchover) |
| The replica was down, its volume is intact | [R4a — Replica down, volume intact](#r4a--replica-down-volume-intact) |
| The replica's volume is lost, or it was away too long (error 1236) | [R4b — Re-seed the replica](#r4b--volume-lost-or-binlog-expired-re-seed) |
| Enable replication for a primary that already has data | [R1 — Enable replication on existing data](#r1--enable-replication-on-existing-data) |
| Two new servers, no data yet | [R1-new — Two new, empty servers](#r1-new--two-new-empty-servers) |
| New MariaDB image | [MariaDB upgrade](#mariadb-upgrade) |
| The server restarted unexpectedly (OOM, crash, host reboot) | [Checks after an unplanned restart](#checks-after-an-unplanned-restart) |

Applications are moved in every runbook the same way:
[Switching applications](#switching-applications). Background and target
details: [Reference](#reference).

## Topology

| | Primary | Replica |
|-|-----------------|--------------|
| `.env` | `DB_ROLE=primary`, `SERVER_ID=1` | `DB_ROLE=replica`, `SERVER_ID=2` |
| Writes | applications write here | refused for everyone, root included (`ERROR 1290`) |
| `read_only` | `0` | [`NO_LOCK_NO_ADMIN`](#glossary) |
| `event_scheduler` | `OFF` | `DISABLED` |
| Replication | binary log `mysql-bin`, [semi-sync](#glossary) master, account `repl@<replica IP>` | replica threads from `<primary IP>:23306`, `MASTER_USE_GTID=slave_pos` |

## Rules

- **Never two writable servers.** A former primary comes back **writable**
  (`read_only OFF`; its configuration still says primary) as soon as its
  host is up — Swarm restarts the stack by itself. After a failover,
  applications use the new primary's address for good, and the old
  primary's service is scaled to 0 the moment its host is back (R3a).
- **The role is configuration.** `DB_ROLE` / `SERVER_ID` in `$ENV_FILE` +
  `make reload-service` (two short restarts, about one minute). `repl-promote`
  / `repl-demote` change the running server at once; until the `.env` change
  + `reload-service`, a restart returns the configured role — a promoted
  replica comes back read-only.
- **A replicated pair has no MariaDB events**: the replica
  needs `event_scheduler = DISABLED`, a replicated `CREATE EVENT` would stop
  its SQL thread ([1577](#glossary)). `repl-user-create` / `repl-dump`
  refuse while the primary has events.
- **Semi-sync is not synchronous.** The last transactions of a lost primary
  may be missing on the replica: compare [positions](#glossary) before
  promoting (R2) and before demoting (R3a).
- **Binlog retention** is 10 days (`expire_logs_days`). A replica that was
  away longer cannot catch up and is re-seeded (R4b).

## Before you start

- Run every command in the stack directory (`db/mariadb/lts`) of the `dev`
  checkout, on the host named in the block's first line (`# on: …`).
- Each runbook starts with a **Set first** block. Fill in the `<…>` values
  and paste it into **every new shell, on every host** the runbook uses —
  the commands use only those variables.
- `REPLICA_IP` is the source address of the replica's connection as the
  primary sees it (NAT!). Check it from the replica host: `mariadb -h
  "$PRIMARY_IP" -P "$PORT" -u root -p -e 'SELECT USER()'` shows
  `root@<REPLICA_IP>`.
- Both servers need the **same replication password** in their
  `<prefix>_repl_password` secret (`make secrets-create`). Read it on the
  primary: `docker exec "$(docker ps -q -f label=com.docker.swarm.service.name=${STACK_NAME}_db)" cat /run/secrets/repl_password`.
- `make repl-status` is the one check for everything replication: role,
  `read_only`, positions, semi-sync, `Slave_IO_Running` /
  `Slave_SQL_Running`, `Last_IO_Error` / `Last_SQL_Error`.

## Switching applications

The runbooks say "switch the applications to X". That means, for each
application that uses this database:

1. In its configuration, change the database **host:port** to X's address
   and published port (`23306` unless `DB_PORT` says otherwise).
   Nothing else changes: same users, passwords, database names.
2. Restart the application (or redeploy its stack).
3. Verify: one write through the application, then on X
   `make db-cmd SQL='SHOW PROCESSLIST'` shows its connections, and the
   written row is there.

Keep the list of applications and where their database address is set
**outside this repository** (it is site-specific). Without it the switch
under stress is guesswork.

## R1-old — Replace an old replica stack

The primary runs this stack, standalone. The replica host still runs an
older, separate MariaDB stack (other repository, stale data): it is retired
and replaced by this stack as the replica. The old data is disposable; its
volume and secrets are **kept** until the end as a fallback. Without an old
stack on the replica host, use [R1](#r1--enable-replication-on-existing-data).

Duration about 30 minutes; the primary's database is down twice for about a
minute (step 2). The replica host has no replica role until step 7.

**Set first — primary**

```bash
# on: PRIMARY — Set first, paste into every new shell
export STACK_NAME=mariadb-lts ENV=prod
ENV_FILE=~/projects/mariadb-lts/dswarm/$ENV/deploy/.env
REPLICA_IP=<IP of the replica, as the primary sees it>
```

**Set first — replica** (run everything from the stack directory of this
repository's checkout on the replica host)

```bash
# on: REPLICA — Set first, paste into every new shell
export STACK_NAME=mariadb-lts ENV=prod
export DB_PORT=<published port of the new stack on the replica, 23306>
ENV_FILE=~/projects/mariadb-lts/dswarm/$ENV/deploy/.env
PRIMARY_IP=<IP of the primary, as the replica reaches it>
PORT=<published port of the primary, 23306>
OLD_STACK=<name of the old stack on the replica host>
PRIMARY_SSH=<ssh login to the primary from the replica host, user@host>
```

### 1. Pre-checks (no downtime)

```bash
# on: PRIMARY
make stack-health                        # OK: all services converged and healthy
make healthcheck-check                   # OK: healthcheck accounts match
make repl-status                         # DB_ROLE empty, log_bin 0, events 0
```

> **STOP if** a check fails or `events` is not `0` (a replicated pair has
> no MariaDB events — see [Rules](#rules)).

```bash
# on: REPLICA
make check-swarm check-tools
docker stack ls
docker stack services "$OLD_STACK"
docker volume ls -f name="$OLD_STACK"
docker secret ls -f name="$OLD_STACK"
timeout 5 bash -c "</dev/tcp/$PRIMARY_IP/$PORT" && echo "primary reachable on $PORT"
df -h /var /home
```

Note the old stack's volume and secret names: they stay as the fallback.
Free space on the replica host: one more copy of the primary's data under
`/var` (Docker root).

> **STOP if** the primary is not reachable on `$PORT` (firewall), or the
> old stack is not the one you expect.

### 2. The primary gets the primary role

> **DANGER:** `reload-service` restarts the primary's database twice (about one
> minute each) — applications get connection errors meanwhile. Pick a
> quiet time.

```bash
# on: PRIMARY
sed -i '/^DB_ROLE=/d; /^SERVER_ID=/d' "$ENV_FILE" && printf '%s\n' 'DB_ROLE=primary' 'SERVER_ID=1' >> "$ENV_FILE"
make reload-service                      # read check OK ... --log_bin=mysql-bin ... --read_only=0
make repl-status                         # log_bin 1, read_only OFF, events 0
make repl-user-create REPLICA_HOST="$REPLICA_IP"
make repl-dump                           # prints the dump file and its GTID position
```

> **STOP if** `reload-service` does not end with `reloaded` or `log_bin` is
> not `1`. Rollback: [step 9](#9-rollback).

**Set first — primary, after the dump**

```bash
# on: PRIMARY — Set first, after repl-dump
DUMP=<path of the dump file printed by repl-dump>
```

```bash
# on: PRIMARY
sha256sum "$DUMP"
```

### 3. Copy the dump to the replica host

The file contains password hashes: copy it only between the two hosts and
delete it in step 8. Pulled from the replica host here; pushing it with `scp`
works as well.

**Set first — replica, after the dump**

```bash
# on: REPLICA — Set first, after repl-dump
DUMP_REMOTE=<path of the dump file on the primary, as printed by repl-dump>
DUMP="$HOME/${DUMP_REMOTE##*/}"
```

```bash
# on: REPLICA
scp "$PRIMARY_SSH:$DUMP_REMOTE" "$DUMP"
sha256sum "$DUMP"                        # the same as on the primary
```

> **STOP if** the checksums differ: copy again.

### 4. Passwords for the replica's new stack

The replication password must be the one of the primary's secret. Show it
on the primary, type it on the replica host **at the prompt** (not as an
argument of `read`) — it never goes into a file,
a command line or the shell history:

```bash
# on: PRIMARY
docker exec "$(docker ps -q -f label=com.docker.swarm.service.name=${STACK_NAME}_db)" cat /run/secrets/repl_password; echo
```

The replica's **root** password is its own new value: generate it in your password
manager (or `openssl rand -base64 24` on a trusted machine) and keep it
there, never in git.

```bash
# on: REPLICA
read -rs -p 'replication password (from the primary): ' MARIADB_REPL_PASSWORD; echo
read -rs -p 'new root password for the replica: ' MARIADB_ROOT_PASSWORD; echo
export MARIADB_REPL_PASSWORD MARIADB_ROOT_PASSWORD
make init
make deploy-sync
make env-init
make secrets-create
unset MARIADB_REPL_PASSWORD MARIADB_ROOT_PASSWORD
make configs-create
```

With ssh from the replica host to the primary the first `read` can be replaced by
`MARIADB_REPL_PASSWORD=$(ssh "$PRIMARY_SSH" 'docker exec "$(docker ps -q -f label=com.docker.swarm.service.name=mariadb-lts_db)" cat /run/secrets/repl_password')`.

> **STOP if** `secrets-create` does not report both secrets (`Created:` or
> `exists`).

### 5. Retire the old stack

> **DANGER:** removes the old database service. Its volume and secrets are
> kept (`docker stack rm` does not delete them) — do not remove them now.

```bash
# on: REPLICA
docker stack rm "$OLD_STACK"
until [ -z "$(docker ps -q -f label=com.docker.stack.namespace=$OLD_STACK)" ]; do sleep 2; done
docker service ls --format '{{.Name}} {{.Ports}}' | grep -- ":$DB_PORT->" || echo "port $DB_PORT not published by a service"
ss -ltn | grep ":$DB_PORT " || echo "port $DB_PORT free on the host"
docker volume ls -f name="$OLD_STACK"    # old volume still listed
```

> **STOP if** the port is still in use (the old stack publishes it through
> the Swarm ingress, which `ss` does not show — hence both checks).

### 6. New stack on the replica host (standalone)

```bash
# on: REPLICA
docker volume create "${STACK_NAME}_db_data"
make stack-deploy
timeout 300 bash -c 'until make -s stack-health >/dev/null 2>&1; do sleep 3; done'
make stack-health                        # OK: all services converged and healthy
make healthcheck-check                   # OK:
make repl-status                         # DB_ROLE empty, log_bin 0
```

> **STOP if** not healthy: `make logs`, then [step 9](#9-rollback).

### 7. Seed, turn it into the replica, connect

> **DANGER:** `db-restore` overwrites the application databases of the
> server it runs on — here the replica's new, empty stack. Check the host.

```bash
# on: REPLICA
make db-restore FILE="$DUMP" CONFIRM=yes NO_BINLOG=yes
sed -i '/^DB_ROLE=/d; /^SERVER_ID=/d' "$ENV_FILE" && printf '%s\n' 'DB_ROLE=replica' 'SERVER_ID=2' >> "$ENV_FILE"
make reload-service                      # --read_only=NO_LOCK_NO_ADMIN --event_scheduler=DISABLED
make repl-start PRIMARY_HOST="$PRIMARY_IP" PRIMARY_PORT="$PORT" FILE="$DUMP"
```

> **STOP if** not `Slave_IO_Running: Yes` / `Slave_SQL_Running: Yes`. With
> `Last_IO_Error` `Access denied for user 'repl'@'<address>'` the primary sees
> the replica as that address: on the primary `make repl-user-create
> REPLICA_HOST=<address>`, on the replica `make repl-start PRIMARY_HOST="$PRIMARY_IP" PRIMARY_PORT="$PORT"`
> again. Any other error: `Last_IO_Error` / `Last_SQL_Error`.

**Verify**

```bash
# on: REPLICA
make repl-status                         # Yes / Yes, Using_Gtid: Slave_Pos, Rpl_semi_sync_slave_status: ON
```

```bash
# on: PRIMARY
make db-cmd SQL="SHOW STATUS LIKE 'Rpl_semi_sync_master_clients'"    # 1
make db-cmd SQL="CREATE DATABASE IF NOT EXISTS repl_check; CREATE TABLE IF NOT EXISTS repl_check.t (id INT AUTO_INCREMENT PRIMARY KEY, at TIMESTAMP DEFAULT CURRENT_TIMESTAMP); INSERT INTO repl_check.t () VALUES ()"
make db-cmd SQL="SHOW STATUS LIKE 'Rpl_semi_sync_master_status'"     # ON
make db-counts | sha256sum
```

```bash
# on: REPLICA
timeout 60 bash -c 'until make -s db-cmd SQL="SELECT 1 FROM repl_check.t" >/dev/null 2>&1; do sleep 2; done'
make db-cmd SQL='SELECT * FROM repl_check.t'          # the row written on the primary
make db-cmd SQL='INSERT INTO repl_check.t () VALUES ()'   # ERROR 1290 expected
make db-counts | sha256sum                             # the same as on the primary
```

The first write after the seed can take some seconds to appear on the replica
(cold replica); the `timeout 60` line waits for it.

> **STOP if** the row is missing, the INSERT on the replica succeeds, or the
> checksums differ (repeat once: the primary may have written in between; then
> compare `make db-counts` line by line).

```bash
# on: PRIMARY
make db-cmd SQL='DROP DATABASE repl_check'            # replicates to the replica
```

### 8. Clean up

```bash
# on: PRIMARY
rm -f "$DUMP"
```

```bash
# on: REPLICA
rm -f "$DUMP"
```

After some days without problems, the old stack's leftovers (names noted in
step 1):

> **DANGER:** deletes the old data and secrets — the fallback of step 9.

```bash
# on: REPLICA — only after some days without problems
docker volume rm <old volume>
docker secret rm <old secrets>
```

### 9. Rollback

Before `repl-start` (step 7) nothing depends on the replica. The primary back
to standalone (two short restarts):

```bash
# on: PRIMARY — only for a rollback
sed -i '/^DB_ROLE=/d; /^SERVER_ID=/d' "$ENV_FILE"
make reload-service                      # --log_bin ... gone, standalone
```

The old stack again, on its kept volume:

```bash
# on: REPLICA — only for a rollback
make stack-rm
docker stack deploy -c <old stack file> "$OLD_STACK"
```

## R1 — Enable replication on existing data

The replica is [seeded](#glossary) from a dump of the primary. It must be
**standalone** (`DB_ROLE` empty) while it is seeded: as a replica it refuses
the restore. Applications keep running on the primary.

**Set first**

```bash
# on: BOTH hosts — paste into every new shell
export STACK_NAME=mariadb-lts ENV=prod
ENV_FILE=~/projects/mariadb-lts/dswarm/$ENV/deploy/.env
PRIMARY_IP=<IP of the primary, as the replica reaches it>
REPLICA_IP=<IP of the replica, as the primary sees it>
PORT=<published port of the primary, 23306>
```

**1. Primary** — switch on the binary log, create the account, dump:

```bash
# on: PRIMARY
sed -i '/^DB_ROLE=/d; /^SERVER_ID=/d' "$ENV_FILE" && printf '%s\n' 'DB_ROLE=primary' 'SERVER_ID=1' >> "$ENV_FILE"
make configs-status                      # repl_cnf CHANGED
make reload-service                      # read check OK ... --log_bin=mysql-bin ... --read_only=0
make repl-status                         # log_bin 1, events 0, Rpl_semi_sync_master_status
make repl-user-create REPLICA_HOST="$REPLICA_IP"
make repl-dump                           # prints the dump file and its GTID position
```

> **STOP if** `reload-service` does not end with `reloaded`, or
> `repl-status` shows `log_bin` not `1` or events not `0`.

Copy the dump file (`~/projects/mariadb-lts/bu/prod/mariadb-lts-repl-dump-<ts>.tar.gz`)
to the replica host. It contains password hashes; delete it after use.

**2. Replica** — load the dump, become replica, connect:

```bash
# on: REPLICA — Set first, after the copy
DUMP=<path of the copied repl-dump .tar.gz>
```

> **DANGER:** `db-restore` overwrites the application databases on this
> server. Check that the block's host is the replica.

```bash
# on: REPLICA
make db-restore FILE="$DUMP" CONFIRM=yes NO_BINLOG=yes
sed -i '/^DB_ROLE=/d; /^SERVER_ID=/d' "$ENV_FILE" && printf '%s\n' 'DB_ROLE=replica' 'SERVER_ID=2' >> "$ENV_FILE"
make reload-service                      # --read_only=NO_LOCK_NO_ADMIN --event_scheduler=DISABLED
make repl-start PRIMARY_HOST="$PRIMARY_IP" PRIMARY_PORT="$PORT" FILE="$DUMP"
```

**3. Verify**

```bash
# on: REPLICA, then PRIMARY
make repl-status
```

```bash
# on: PRIMARY
make db-cmd SQL="SHOW STATUS LIKE 'Rpl_semi_sync_master_clients'"
```

Expected — replica: `Slave_IO_Running: Yes`, `Slave_SQL_Running: Yes`,
`Using_Gtid: Slave_Pos`, `Rpl_semi_sync_slave_status: ON`; primary:
`Rpl_semi_sync_master_clients: 1`. `Rpl_semi_sync_master_status` turns `ON`
with the first write after the replica connected (earlier writes such as
`repl-user-create` timed out into async — normal).

> **STOP if** not `Yes` / `Yes`: read `Last_IO_Error` (connection,
> password, `REPLICA_IP` account) or `Last_SQL_Error` (data differs) in
> `repl-status` and fix that first.

## R1-new — Two new, empty servers

Two new servers, no application data yet. No dump: the replica replays the
primary's binary log from its first event.

**Precondition:** the primary has **no application databases** when its
binary log is switched on. Anything written while it was standalone (no
binlog) never reaches the replica — if there is any, use R1.

**Set first**

```bash
# on: BOTH hosts — paste into every new shell
export STACK_NAME=mariadb-lts ENV=prod
ENV_FILE=~/projects/mariadb-lts/dswarm/$ENV/deploy/.env
PRIMARY_IP=<IP of the primary, as the replica reaches it>
REPLICA_IP=<IP of the replica, as the primary sees it>
PORT=<published port of the primary, 23306>
```

**1. Both hosts** — from scratch, the **same** `MARIADB_REPL_PASSWORD` on
both (`repl-user-create` sets it on the primary, `repl-start` reads it from
the replica's secret):

```bash
# on: BOTH hosts
docker swarm init                        # skip if make check-swarm passes
make init
make deploy-sync
make env-init
docker volume create "${STACK_NAME}_db_data"
MARIADB_ROOT_PASSWORD='...' MARIADB_REPL_PASSWORD='...' make secrets-create
make configs-create
make stack-deploy
make stack-health
```

**2. Primary** — role change **before any application data is written**:

```bash
# on: PRIMARY
make db-cmd SQL='SHOW DATABASES'         # information_schema, mysql, performance_schema, sys only
```

> **STOP if** any other database is listed: use R1.

```bash
# on: PRIMARY
sed -i '/^DB_ROLE=/d; /^SERVER_ID=/d' "$ENV_FILE" && printf '%s\n' 'DB_ROLE=primary' 'SERVER_ID=1' >> "$ENV_FILE"
make reload-service                      # --log_bin=mysql-bin ... --read_only=0
make repl-user-create REPLICA_HOST="$REPLICA_IP"
```

**3. Replica**

```bash
# on: REPLICA
sed -i '/^DB_ROLE=/d; /^SERVER_ID=/d' "$ENV_FILE" && printf '%s\n' 'DB_ROLE=replica' 'SERVER_ID=2' >> "$ENV_FILE"
make reload-service                      # --read_only=NO_LOCK_NO_ADMIN --event_scheduler=DISABLED
make repl-start PRIMARY_HOST="$PRIMARY_IP" PRIMARY_PORT="$PORT"     # no FILE= / GTID_POS=
```

**4. Verify** as in R1 step 3 (same **STOP if**). The replication user
(`repl@<REPLICA_IP>`) also appears on the replica: `repl-user-create` wrote
it to the primary's binary log (expected, harmless — a later failover needs
it). Application databases created on the primary from now on replicate.

## R2 — Failover: the primary is lost

Use only when the primary cannot come back soon. Applications are down from
step 1 until step 4.

**Set first**

```bash
# on: REPLICA, and the OLD primary if reachable — every new shell
export STACK_NAME=mariadb-lts ENV=prod
ENV_FILE=~/projects/mariadb-lts/dswarm/$ENV/deploy/.env
```

**1. Make sure the old primary is down** — host off, or, if the host is
reachable:

```bash
# on: OLD primary — only if its host is reachable
docker service scale "${STACK_NAME}_db=0"
```

> **STOP if** the old primary still accepts connections and you cannot stop
> it: a failover now makes two writable servers.

**2. Record the replica's position** — it decides R3a later:

```bash
# on: REPLICA
make repl-status | tee ~/r2-replica-status.txt
# Slave_IO_Running: No (primary gone); compare gtid_slave_pos with the
# primary's last gtid_binlog_pos if it is known (monitoring, last status).
```

Transactions the old primary committed after the last acknowledged one
(semi-sync fallback) are **not** on the replica and are lost with this
failover.

**3. Promote**

> **DANGER:** after `repl-promote` this server is writable. Only with the
> old primary stopped (step 1).

```bash
# on: REPLICA — becomes the NEW primary
make repl-promote CONFIRM=yes            # read_only = 0, replication removed
make db-cmd SQL='SELECT @@read_only'     # OFF
```

> **STOP if** `@@read_only` is not `OFF`.

**4. Switch the applications to this host — for good**
([Switching applications](#switching-applications)). Not "while the old
primary is down": when its host comes back, Swarm restarts it writable.

**5. Persist the role** (now or in a quiet minute — two short restarts):

```bash
# on: NEW primary
sed -i '/^DB_ROLE=/d' "$ENV_FILE" && echo 'DB_ROLE=primary' >> "$ENV_FILE"
make reload-service                      # --read_only=0 --event_scheduler=OFF
```

## R3 — The old primary returns; failback

### R3a — Demote the returning server

Its configuration still says `primary`: when its host is back, Swarm
restarts the stack by itself and the server is **writable**
(`read_only OFF`).

**Set first**

```bash
# on: OLD primary and NEW primary — every new shell
export STACK_NAME=mariadb-lts ENV=prod
ENV_FILE=~/projects/mariadb-lts/dswarm/$ENV/deploy/.env
PRIMARY_IP=<IP of the NEW primary, as the old primary reaches it>
REPLICA_IP=<IP of the OLD primary, as the new primary sees it>
PORT=<published port of the NEW primary, 23306>
```

**1. First action on the returning host — stop it:**

```bash
# on: OLD primary
docker service scale "${STACK_NAME}_db=0"   # or block port 23306 in the host firewall
```

**2. Start it for the demote only**

> **DANGER:** scaled to 1, the old primary is writable until step 4. No
> application may be able to reach it (they use the new primary since R2).

```bash
# on: OLD primary
docker service scale "${STACK_NAME}_db=1"   # or make stack-deploy if the stack was removed
make stack-health
make repl-status                           # gtid_binlog_pos of the old primary, read_only OFF
```

Compare its `gtid_binlog_pos` with `gtid_slave_pos` in
`~/r2-replica-status.txt` (R2 step 2, on the new primary).

> **STOP if** the old primary has **transactions beyond the position**
> (same domain, higher sequence number from `SERVER_ID=1`): they were never
> replicated, and the demote would stop with error [1236](#glossary).
> Decide what to do with them (export by hand), scale back to 0, then
> re-seed this server from the new primary like R4b.

**3. Allow the old primary to connect** (skip if `REPLICA_IP` already has the
account):

```bash
# on: NEW primary
make repl-user-create REPLICA_HOST="$REPLICA_IP"
```

**4. Demote and persist**

```bash
# on: OLD primary
make repl-demote PRIMARY_HOST="$PRIMARY_IP" PRIMARY_PORT="$PORT" CONFIRM=yes
sed -i '/^DB_ROLE=/d' "$ENV_FILE" && echo 'DB_ROLE=replica' >> "$ENV_FILE"
make reload-service                        # read-only across restarts
make repl-status                           # Yes / Yes, Seconds_Behind_Master: 0
```

> **STOP if** not `Yes` / `Yes` or `read_only` is not `NO_LOCK_NO_ADMIN`:
> read `Last_IO_Error` / `Last_SQL_Error`; scale the service to 0 again
> until it is solved.

`repl-demote` uses `MASTER_DEMOTE_TO_SLAVE = 1`: the server's own binlog
position becomes its replication start, so it continues after its last own
transaction.

### R3b — Failback (planned switchover)

Back to the original roles. Applications are stopped from step 1 to step 4
(about two minutes: two `reload-service`).

**Set first**

```bash
# on: CURRENT primary and FUTURE primary — every new shell
export STACK_NAME=mariadb-lts ENV=prod
ENV_FILE=~/projects/mariadb-lts/dswarm/$ENV/deploy/.env
PRIMARY_IP=<IP of the FUTURE primary, as the current primary reaches it>
PORT=<published port of the FUTURE primary, 23306>
```

> **DANGER:** keep the order 1 → 2 → 3. Promoting before step 1 makes two
> writable servers.

**1. Stop writes on the current primary, note the position**

```bash
# on: CURRENT primary
make db-cmd SQL='SET GLOBAL read_only = NO_LOCK_NO_ADMIN'
make db-cmd SQL='SELECT @@gtid_binlog_pos'
```

**2. Future primary — wait until it has everything, then promote**

```bash
# on: FUTURE primary
make db-cmd SQL='SELECT @@gtid_slave_pos'    # equal to the position of step 1
```

> **STOP if** the positions differ: wait and repeat; never promote with a
> lower position.

> **DANGER:** `repl-promote` makes this server writable.

```bash
# on: FUTURE primary
make repl-promote CONFIRM=yes
sed -i '/^DB_ROLE=/d' "$ENV_FILE" && echo 'DB_ROLE=primary' >> "$ENV_FILE"
make reload-service
```

**3. The current primary becomes the replica**

```bash
# on: CURRENT primary — becomes the replica
make repl-demote PRIMARY_HOST="$PRIMARY_IP" PRIMARY_PORT="$PORT" CONFIRM=yes
sed -i '/^DB_ROLE=/d' "$ENV_FILE" && echo 'DB_ROLE=replica' >> "$ENV_FILE"
make reload-service
```

**4. Switch the applications to the future primary**
([Switching applications](#switching-applications)) and verify with
`make repl-status` on both hosts.

> **STOP if** the replica is not `Yes` / `Yes` or the primary's
> `Rpl_semi_sync_master_status` stays `OFF` after a write: `Last_IO_Error` /
> `Last_SQL_Error` on the replica.

## R4 — Replica recovery

### R4a — Replica down, volume intact

Nothing to do: when the replica's stack runs again it reconnects with its
stored GTID position and catches up.

**Set first**

```bash
# on: REPLICA — every new shell
export STACK_NAME=mariadb-lts ENV=prod
ENV_FILE=~/projects/mariadb-lts/dswarm/$ENV/deploy/.env
```

```bash
# on: REPLICA
make stack-deploy                          # only if the stack was removed
make repl-status                           # Yes / Yes, Seconds_Behind_Master -> 0
```

> **STOP if** `Last_IO_Error` shows error [1236](#glossary) ("could not
> find GTID state" / purged binary log): the replica was away longer than
> the binlog retention — R4b.

### R4b — Volume lost or binlog expired: re-seed

The replica starts again from an empty, standalone server, then continues
as R1. Its config object still carries the replica role, which would block
the initialisation, so it is recreated with `DB_ROLE` empty. The volume name
below is the default; use `DB_VOLUME` from `$ENV_FILE` if it is set there.

**Set first**

```bash
# on: REPLICA and PRIMARY — every new shell
export STACK_NAME=mariadb-lts ENV=prod
ENV_FILE=~/projects/mariadb-lts/dswarm/$ENV/deploy/.env
PRIMARY_IP=<IP of the primary, as the replica reaches it>
PORT=<published port of the primary, 23306>
```

**1. Replica — back to standalone**

```bash
# on: REPLICA
make stack-rm
sed -i '/^DB_ROLE=/d' "$ENV_FILE"
docker config rm "${STACK_NAME}_repl_cnf"
```

> **DANGER:** `docker volume rm` deletes the database files — **only on the
> replica**, never on the primary. Check the host first (`hostname`).

```bash
# on: REPLICA — only if the volume still exists
docker volume rm "${STACK_NAME}_db_data"
```

```bash
# on: REPLICA
docker volume create "${STACK_NAME}_db_data"
make configs-create                        # repl_cnf standalone again
make stack-deploy
make stack-health
```

> **STOP if** `stack-health` is not healthy.

**2. Primary — new dump** (the `repl@` account is still there):

```bash
# on: PRIMARY
make repl-dump
```

**3. Replica** — copy the file and continue with R1 step 2 (`db-restore` →
`DB_ROLE=replica` → `reload-service` → `repl-start FILE=`) and R1 step 3.

## MariaDB upgrade

New image = new pinned digest in `stack.yml` (`image:` line,
`mariadb:<version>@sha256:<index digest>`, from Docker Hub). Replica first,
then the primary; one server at a time.

**Set first**

```bash
# on: each host — every new shell
export STACK_NAME=mariadb-lts ENV=prod
```

```bash
# on: REPLICA first; then the same on PRIMARY
make db-backup                             # snapshot before the upgrade
# put the new image line into stack.yml (git), then:
make deploy-sync
make stack-deploy                          # restarts the task with the new image (stop-first)
make stack-health
make db-upgrade                            # mariadb-upgrade, datadir mounted; verifies
make repl-status                           # replica: Yes / Yes again
```

> **STOP if** `db-upgrade` ends with `FAIL:` or the replica is not
> `Yes` / `Yes`: do not upgrade the next server.

`db-upgrade` prints the server version, `mariadb_upgrade_info` and the
number of `mysql.proc` columns (22 for 12.3) and fails if the upgrade info
does not match the server. It does not write the binary log, so each server
is upgraded by its own run. `MARIADB_AUTO_UPGRADE` stays unset: an image
change never upgrades the datadir silently. Back out: `make
service-rollback` (old image) only before `db-upgrade`; afterwards restore
the snapshot (`volume-from-snapshot`).

## Checks after an unplanned restart

**Set first**

```bash
# on: the host whose server restarted — every new shell
export STACK_NAME=mariadb-lts ENV=prod
OLD_CID=<container ID of the failed task, from docker ps -a>
```

```bash
# on: the host whose server restarted
make ps                                    # task history: Failed / Shutdown with exit code
docker inspect -f '{{.State.OOMKilled}} exit={{.State.ExitCode}} {{.State.FinishedAt}}' "$OLD_CID"
docker service logs --since 2h "${STACK_NAME}_db" 2>&1 | grep -iE 'crash recovery|recovery|\[ERROR\]'
make stack-health
make healthcheck-check                     # healthcheck@ accounts match .my-healthcheck.cnf
make repl-status                           # both servers of a pair
make db-cmd SQL='XA RECOVER'                # primary/replica: empty
sudo journalctl -k --since '-2h' | grep -iE 'oom|killed process'    # sudo not needed in group adm
```

- `OOMKilled=true` or exit 137 with an OOM line in the kernel log: memory
  limit (512M) reached.
- Exit 0 after `Shutdown`: Swarm stopped an **unhealthy** container and
  `mariadbd` ended cleanly. The restart policy `any` starts a new task; a task
  in `Shutdown` / `Complete` with no running successor (service `0/1`) is no
  longer expected — check `make status`. Repeating unhealthy tasks with
  `Access denied for user 'healthcheck'` in the log: `make healthcheck-check`,
  then `make healthcheck-fix CONFIRM=yes`.
- After an unclean stop the new task logs `InnoDB: Starting crash recovery
  from checkpoint LSN=...`, with the binary log on also `Recovering after a
  crash using mysql-bin`, possibly `Transaction ... in prepared state after
  recovery` and `Crash table recovery finished.`, then `ready for
  connections`. That is the normal path: the binlog decides about prepared
  transactions, and `XA RECOVER` must be empty afterwards.

> **STOP if** `[ERROR]` lines appear, the task keeps restarting, or
> `XA RECOVER` is not empty.

- `dmesg -T` times drift behind the real clock (suspend, clock changes);
  use `journalctl -k` for exact times.
- A replica resumes by itself; a primary that restarted is still primary
  (rehearsed: `docker kill` of the primary's task → exit 137, new task
  healthy in ~10 s, replica reconnected, last row present).

## Reference

What the runbooks rely on; the targets themselves are in `make help` and
`README.md` "Make targets".

**Replication mode.** GTID (`MASTER_USE_GTID = slave_pos`) with semi-sync:
`rpl_semi_sync_master_timeout = 3000` — the primary falls back to async when
the replica does not acknowledge within 3 s.

**The role is configuration.** `DB_ROLE` / `SERVER_ID` in `$ENV_FILE` select
and render `configs/replication/*.cnf` (empty = `standalone.cnf`, no binary
log), applied with `make reload-service` and validated and read-checked like
`my.cnf`. It survives restarts and redeploys. A replica keeps its
replication state in the datadir and resumes by itself after a restart.

**`read_only = NO_LOCK_NO_ADMIN` on the replica.** Every client write fails
with `ERROR 1290`, **root included**: with `ON`, root still writes through
`READ ONLY ADMIN`, and with `gtid_strict_mode = 0` such a divergence goes
unnoticed. The replication threads still apply and `db-backup` works;
`repl-start` / `repl-demote` lift it to `ON` only for their own setup
statements, then set it back. It also blocks a root `db-restore`, hence:
**seed while the replica is still standalone, then switch its role.**

**`event_scheduler = DISABLED` on the replica.** 12.3.3 aborts at startup with
`NO_LOCK_NO_ADMIN` otherwise (`Event Scheduler: Failed to open table
mysql.event`). `DISABLED` cannot change at runtime, so a promoted replica
runs no events until `DB_ROLE=primary` + `reload-service` (`OFF`). With the
scheduler `DISABLED`, `SHOW EVENTS` fails, so `db-backup` on a replica dumps
without events (`WARN:` + `EVENTS_SKIPPED` in the snapshot; the physical
`mb/` still contains them).

**No MariaDB events in a replicated pair.** A `CREATE EVENT`
replicated from the primary would stop the replica's SQL thread with error
1577 ("event scheduler is disabled"). The pair this was built for has no events.
`repl-user-create` and `repl-dump` refuse with `FAIL:` while the primary has
any event (`mysql.event` not empty); `repl-status` shows the event count.

**Targets**

- `repl-status` — role, `read_only`, binary log, GTID positions, semi-sync,
  event count, replica threads and their errors.
- `repl-user-create REPLICA_HOST=` — creates `repl@<REPLICA_HOST>` (an IP or
  `ip/netmask`, never `%`) with the stack's replication password; refused on
  a read-only server or when the server has events.
- `repl-dump` — application databases (`--gtid --master-data=2`) + accounts +
  `GTID_POS`; needs the binary log (`DB_ROLE=primary`); refuses when there are
  no application databases (then: R1-new).
- `db-restore` — refuses a read-only server. `NO_BINLOG=yes` keeps the seed
  out of the target's binary log when it has one (a replica's binlog must hold
  only replicated events for a later failback).
- `repl-start PRIMARY_HOST= PRIMARY_PORT=` (refused on a writable server) —
  `CHANGE MASTER ... MASTER_USE_GTID = slave_pos`, with `gtid_slave_pos` from
  `FILE=` or `GTID_POS=`, or the stored position when neither is given; waits
  until both replica threads run. `repl-stop` stops them, keeping the
  configuration.
- `repl-promote CONFIRM=yes` (`read_only = 0`) / `repl-demote PRIMARY_HOST=
  CONFIRM=yes` (`read_only = NO_LOCK_NO_ADMIN`, `MASTER_DEMOTE_TO_SLAVE = 1`)
  change the running server at once and print the `DB_ROLE` change +
  `reload-service` that persist it. Until then a restart returns the
  configured role.

## Glossary

- **Primary** — the server applications write to; its binary log feeds the replica.
- **Replica** — copy of the primary that applies the primary's binary log; refuses all client writes.
- **GTID position** — `domain-server-sequence` of the last transaction: `gtid_binlog_pos` = written by this server's binlog, `gtid_slave_pos` = last one applied from the primary.
- **Semi-sync** — the primary waits up to 3 s (`rpl_semi_sync_master_timeout`) for the replica's acknowledgement, then continues **asynchronously** (`Rpl_semi_sync_master_status: OFF`) until the next acknowledged commit.
- **`read_only = NO_LOCK_NO_ADMIN`** — read-only for everyone including root (no `READ ONLY ADMIN` exception); the replica's setting.
- **Binlog retention** — binary logs older than 10 days are deleted; a replica needing older ones cannot catch up.
- **Seeding** — loading a replica with a consistent dump of the primary plus the matching GTID position.
- **Promote** — turn a replica into a writable primary (`repl-promote`).
- **Demote** — turn a server into a read-only replica of another (`repl-demote`).
- **Error 1236** — the primary no longer has (or never had) the binlog the replica asks for: re-seed (R4b).
- **Error 1290** — write refused by `read_only`; expected on the replica.
- **Error 1577** — event scheduler problem; on the replica a replicated `CREATE EVENT` stops the SQL thread (why the pair has no events).

## Rehearsal

Executed on one Swarm host (Docker 29) with two test stacks, `mariadb-test-a`
(primary, port 23307, restored from a production snapshot) and
`mariadb-test-b` (replica, port 23308): R1, R2, R3a, R3b, R4a, R4b, the
upgrade runbook (`db-upgrade` on both servers of the pair) and the unplanned
restart check (`docker kill` of the task). On one host both servers reach
each other through the host's LAN IP; the primary sees the replica as the
`docker_gwbridge` gateway address.

R1-new was executed on two fresh empty volumes. R1-old was executed against
a copy of an older MariaDB stack (ingress port, `mariadb:lts`, its own
secrets), including the rollback, and then in production between two hosts.
Not covered on one host: a firewall on 23306, a NAT source address of the
replica, network latency against `rpl_semi_sync_master_timeout`.
