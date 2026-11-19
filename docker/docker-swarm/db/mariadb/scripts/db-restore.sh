#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# db-restore.sh — logical restore into the running stack: dump.sql.gz, then
# the accounts from users.sql.
# Usage: STACK_NAME=<stack> FILE=<snapshot.tar.gz|dump.sql.gz> [DB=<name>] CONFIRM=yes \
#        bash scripts/db-restore.sh                                      (make db-restore)
#
#   FILE=*.tar.gz   snapshot from db-backup: dump.sql.gz + users.sql
#   FILE=*.sql.gz   a dump only (no accounts)
#   DB=<name>       restore only that database from the dump; accounts skipped
#   NO_BINLOG=yes   do not write the restore to this server's binary log
#                   (seeding a replica: its binlog must hold only replicated
#                   events, or a later failback meets unknown GTIDs)
# Tables present in the dump are dropped and recreated (DROP TABLE IF EXISTS).
#
# Accounts: root, healthcheck and mariadb.sys are skipped — the dump's
# GRANT ... IDENTIFIED BY PASSWORD would replace the target's root and
# healthcheck passwords. Every other account is loaded with
# CREATE OR REPLACE USER, i.e. made identical to the snapshot.
# Env: STACK_NAME, SERVICE, FILE, DB, CONFIRM, NO_BINLOG, MARIADB_ROOT_PASSWORD (optional).
set -euo pipefail
shopt -s inherit_errexit

# shellcheck source=db-common.sh
source "${BASH_SOURCE[0]%/*}/db-common.sh"

readonly SKIP_ACCOUNTS='root|healthcheck|mariadb\.sys'
readonly SRC=${FILE:-}

[[ -n "${SRC}" ]] || die "FILE=<snapshot.tar.gz|dump.sql.gz> required"
[[ -f "${SRC}" ]] || die "not found: ${SRC}"
[[ "${CONFIRM:-}" == yes ]] || die "overwrites databases of ${STACK_NAME:-?} — add CONFIRM=yes"

db_target
root_password

# A replica (read_only = NO_LOCK_NO_ADMIN) refuses every client write, root
# included: seed it while DB_ROLE is empty, then switch the role.
ro=$(sql 'SELECT @@GLOBAL.read_only' < /dev/null) || die "cannot query read_only"
case "${ro}" in
	OFF|0) ;;
	*) die "server is read-only (read_only=${ro}, replica role) — restore while DB_ROLE is empty, then DB_ROLE=replica + make reload-service" ;;
esac

WORK=$(mktemp -d)
readonly WORK
cleanup() { rm -rf "${WORK}"; }
trap cleanup EXIT

case "${SRC}" in
	*.tar.gz)
		tar -xzf "${SRC}" -C "${WORK}" ./dump.sql.gz ./users.sql \
			|| die "${SRC} has no dump.sql.gz / users.sql — not a db-backup snapshot?" ;;
	*.sql.gz)
		cp "${SRC}" "${WORK}/dump.sql.gz" ;;
	*)
		die "FILE must be a snapshot .tar.gz or a .sql.gz dump" ;;
esac

last=$(gzip -dc "${WORK}/dump.sql.gz" | tail -n 1)
[[ "${last}" == "-- Dump completed"* ]] || die "dump is incomplete (last line: ${last})"

# extract_db <name> — the dump's header plus the section of one database.
extract_db() {
	gzip -dc "${WORK}/dump.sql.gz" | awk -v db="-- Current Database: \`$1\`" '
		/^-- Current Database: / { seen = 1; on = ($0 == db); if (on) found = 1 }
		!seen || on { print }
		END { exit found ? 0 : 1 }'
}

load_args=(mariadb --host=127.0.0.1 --port=3306 --user=root --skip-ssl-verify-server-cert)
case "${NO_BINLOG:-}" in
	yes) load_args+=(--init-command="SET SESSION sql_log_bin = 0") ;;
	"") ;;
	*) die "NO_BINLOG='${NO_BINLOG}' — use NO_BINLOG=yes or leave it empty" ;;
esac

mysql_load() { client 512m "${load_args[@]}"; }

# 1. databases
if [[ -n "${DB:-}" ]]; then
	extract_db "${DB}" > "${WORK}/one.sql" || die "database '${DB}' is not in the dump"
	mysql_load < "${WORK}/one.sql" || die "loading database ${DB}"
	echo "OK:   database ${DB} restored"
else
	count=$(gzip -dc "${WORK}/dump.sql.gz" | grep -c '^-- Current Database: ') || count=0
	gzip -dc "${WORK}/dump.sql.gz" | mysql_load || die "loading dump.sql.gz"
	echo "OK:   ${count} databases restored"
fi

# 2. accounts
if [[ -n "${DB:-}" ]]; then
	echo "SKIP: accounts (DB= given)"
elif [[ ! -f "${WORK}/users.sql" ]]; then
	echo "SKIP: accounts (FILE is a dump only)"
else
	grep -vE "[\`'](${SKIP_ACCOUNTS})[\`']@" "${WORK}/users.sql" \
		| sed -E 's/^CREATE USER /CREATE OR REPLACE USER /' > "${WORK}/users.load.sql"
	total=$(grep -c '^CREATE USER' "${WORK}/users.sql") || total=0
	loaded=$(grep -c '^CREATE OR REPLACE USER' "${WORK}/users.load.sql") || loaded=0
	mysql_load < "${WORK}/users.load.sql" || die "loading users.sql"
	echo "OK:   ${loaded} of ${total} accounts loaded (root, healthcheck, mariadb.sys kept)"
fi

dbs=$(sql 'SHOW DATABASES' < /dev/null) || die "cannot list databases after restore"
n=$(wc -l <<< "${dbs}")
echo "OK:   server now lists ${n} databases (incl. system)"
