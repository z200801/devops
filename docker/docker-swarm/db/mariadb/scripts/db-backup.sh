#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# db-backup.sh — consistent snapshot of the running server without touching it:
# physical backup (mariadb-backup, prepared), logical dump of the application
# databases, users/grants and metadata, packed into one tar.gz + .sha256.
# Usage: STACK_NAME=<stack> BU_DIR=<dir> bash scripts/db-backup.sh       (make db-backup)
#        SOURCE_CONTAINER=<name> ...  — back up a compose container instead
#
# Snapshot layout:
#   VERSION, IMAGE_DIGEST, DATABASES, mb/ (prepared), backup.log, prepare.log,
#   dump.sql.gz (--databases <app dbs>), users.sql (--system=users)
# Needs: docker; no sudo — root-owned backup files are packed and removed by
# a throwaway container. Exits non-zero with FAIL: on any failed check.
# The snapshot contains password hashes: keep it out of git.
set -euo pipefail
shopt -s inherit_errexit

# shellcheck source=db-common.sh
source "${BASH_SOURCE[0]%/*}/db-common.sh"

readonly BASE=${BU_DIR:?BU_DIR required}
readonly SYSTEM_DBS='^(mysql|information_schema|performance_schema|sys)$'

db_target
root_password
info=$(docker inspect -f '{{.Name}} {{.RestartCount}}' "${DB_CID}")
read -r db_name rc_before <<< "${info}"
db_name=${db_name#/}

printf -v ts '%(%Y%m%d%H%M%S)T' -1
readonly NAME="${STACK_NAME:-mariadb-lts}-snapshot-${ts}"
readonly OUT="${BASE}/${NAME}"
mkdir -p "${OUT}/mb"
echo "Source: ${db_name}  Snapshot dir: ${OUT}"

# On failure remove the partial snapshot (root-owned files: via a container).
done_ok=0
cleanup() {
	if (( done_ok == 0 )) && [[ -d "${OUT}" ]]; then
		docker run --rm --network none -v "${BASE}:/base" "${DB_IMG}" rm -rf "/base/${NAME}" || true
		rm -f "${OUT}.tar.gz"
		echo "Partial snapshot removed: ${OUT}" >&2
	fi
}
trap cleanup EXIT

# fail_log <log> <message> — show the end of a step log, then fail.
fail_log() {
	tail -n 5 "$1" >&2 || true
	die "$2"
}

# 1. metadata
docker exec "${DB_CID}" mariadbd --version > "${OUT}/VERSION"
docker image inspect -f '{{json .RepoDigests}}' "${DB_IMG}" > "${OUT}/IMAGE_DIGEST"
read -r version < "${OUT}/VERSION"
echo "OK:   metadata (${version})"

# 2. physical backup + prepare (same image as the server)
if ! docker run --rm --memory=512m --volumes-from "${DB_CID}:ro" --network "container:${DB_CID}" \
	-e MYSQL_PWD -v "${OUT}/mb:/backup" "${DB_IMG}" \
	mariadb-backup --backup --host=127.0.0.1 --port=3306 --user=root --target-dir=/backup \
	> "${OUT}/backup.log" 2>&1; then
	fail_log "${OUT}/backup.log" "mariadb-backup --backup"
fi
grep -q 'completed OK!' "${OUT}/backup.log" || fail_log "${OUT}/backup.log" "backup not completed"
[[ -f "${OUT}/mb/backup-my.cnf" && -f "${OUT}/mb/mariadb_backup_checkpoints" ]] \
	|| die "backup incomplete: backup-my.cnf / mariadb_backup_checkpoints missing"
if ! docker run --rm --memory=512m --network none -v "${OUT}/mb:/backup" "${DB_IMG}" \
	mariadb-backup --prepare --target-dir=/backup > "${OUT}/prepare.log" 2>&1; then
	fail_log "${OUT}/prepare.log" "mariadb-backup --prepare"
fi
grep -q 'completed OK!' "${OUT}/prepare.log" || fail_log "${OUT}/prepare.log" "prepare not completed"
echo "OK:   physical backup prepared"

# 3. application databases
all_dbs=$(sql 'SHOW DATABASES' < /dev/null) || die "cannot list databases"
mapfile -t dbs < <(grep -Ev "${SYSTEM_DBS}" <<< "${all_dbs}" || true)
(( ${#dbs[@]} )) || die "no application databases found"
printf '%s\n' "${dbs[*]}" > "${OUT}/DATABASES"
echo "OK:   ${#dbs[@]} databases"

# 4. logical dump of the application databases (never --all-databases).
# A replica runs with event_scheduler = DISABLED (needed for read_only =
# NO_LOCK_NO_ADMIN), where SHOW EVENTS fails: dump without events then and
# say so; the physical backup mb/ still holds mysql.event.
dump_opts=(--single-transaction --routines --events --triggers)
sched=$(sql 'SELECT @@GLOBAL.event_scheduler' < /dev/null) || die "cannot query event_scheduler"
if [[ "${sched}" == DISABLED ]]; then
	dump_opts=(--single-transaction --routines --triggers)
	echo "event_scheduler is DISABLED on ${db_name}: events are not in dump.sql.gz (they are in mb/)" > "${OUT}/EVENTS_SKIPPED"
	echo "WARN: event_scheduler=DISABLED (replica) — dump.sql.gz without events, see EVENTS_SKIPPED"
fi
client 256m mariadb-dump --host=127.0.0.1 --port=3306 --user=root --skip-ssl-verify-server-cert \
	"${dump_opts[@]}" --databases "${dbs[@]}" < /dev/null \
	| gzip > "${OUT}/dump.sql.gz" || die "mariadb-dump of databases"
last=$(gzip -dc "${OUT}/dump.sql.gz" | tail -n 1)
[[ "${last}" == "-- Dump completed"* ]] || die "dump.sql.gz incomplete (last line: ${last})"
echo "OK:   dump.sql.gz"

# 5. users and grants as portable CREATE USER / GRANT
client 128m mariadb-dump --host=127.0.0.1 --port=3306 --user=root --skip-ssl-verify-server-cert \
	--system=users < /dev/null > "${OUT}/users.sql" || die "mariadb-dump --system=users"
last=$(tail -n 1 "${OUT}/users.sql")
[[ "${last}" == "-- Dump completed"* ]] || die "users.sql incomplete (last line: ${last})"
users=$(grep -c '^CREATE USER' "${OUT}/users.sql") || users=0
echo "OK:   users.sql (${users} CREATE USER)"

# 6. the server must not have restarted
info=$(docker inspect -f '{{.State.Running}} {{.RestartCount}}' "${DB_CID}") || die "${db_name} is gone"
read -r running rc_after <<< "${info}"
[[ "${running}" == true && "${rc_after}" == "${rc_before}" ]] \
	|| die "${db_name} restarted during the backup (running=${running}, RestartCount ${rc_before} -> ${rc_after})"
echo "OK:   ${db_name} not restarted (RestartCount=${rc_after})"

# 7. pack (as root in a container: backup files are root-owned), checksum, remove the dir
docker run --rm --network none -v "${BASE}:/base" "${DB_IMG}" tar -C "/base/${NAME}" -czf - . \
	> "${OUT}.tar.gz" || die "packing ${OUT}.tar.gz"
gzip -t "${OUT}.tar.gz" || die "${OUT}.tar.gz is corrupt"
sum=$(sha256sum < "${OUT}.tar.gz")
printf '%s  %s\n' "${sum%% *}" "${NAME}.tar.gz" > "${OUT}.tar.gz.sha256"
docker run --rm --network none -v "${BASE}:/base" "${DB_IMG}" rm -rf "/base/${NAME}"
done_ok=1
size=$(du -h "${OUT}.tar.gz")
echo "OK:   ${OUT}.tar.gz (${size%%$'\t'*}) — contains password hashes, keep out of git"
