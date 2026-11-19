#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# db-upgrade.sh — run mariadb-upgrade for the running server's image and
# verify the result. Part of the upgrade runbook (README.replication.md).
# Usage: STACK_NAME=<stack> [FORCE=1] bash scripts/db-upgrade.sh          (make db-upgrade)
#
# mariadb-upgrade runs in its own container of the service image (own
# --memory) on the task's network namespace, as uid 999 with the task's
# volumes (--volumes-from): without the datadir it cannot write
# mariadb_upgrade_info. It does not write the binary log (default), so each
# server of a replicated pair is upgraded on its own (replica first).
# On a replica (read_only = NO_LOCK_NO_ADMIN, which blocks root) read_only is
# ON for the run and set back afterwards.
# FORCE=1: run even if mariadb_upgrade_info already names this version.
# Env: STACK_NAME, SERVICE, FORCE, MARIADB_ROOT_PASSWORD (optional).
set -euo pipefail
shopt -s inherit_errexit

# shellcheck source=db-common.sh
source "${BASH_SOURCE[0]%/*}/db-common.sh"

db_target
root_password

args=(mariadb-upgrade --host=127.0.0.1 --port=3306 --user=root --skip-ssl-verify-server-cert)
case "${FORCE:-}" in
	1) args+=(--force) ;;
	"") ;;
	*) die "FORCE='${FORCE}' — use FORCE=1 or leave it empty" ;;
esac

ro=$(sql 'SELECT @@GLOBAL.read_only' < /dev/null) || die "cannot query read_only"
[[ "${ro}" =~ ^([A-Z_]+|0|1)$ ]] || die "unexpected read_only value '${ro}'"
restore_ro=0
case "${ro}" in
	NO_LOCK_NO_ADMIN|NO_LOCK)
		sql 'SET GLOBAL read_only = ON' < /dev/null || die "cannot set read_only = ON"
		restore_ro=1
		echo "NOTE: read_only ${ro} -> ON for mariadb-upgrade" ;;
	*) ;;
esac
cleanup() {
	if (( restore_ro )); then
		sql "SET GLOBAL read_only = ${ro}" < /dev/null || echo "FAIL: could not set read_only = ${ro} again — run: make db-cmd SQL='SET GLOBAL read_only = ${ro}'" >&2
	fi
}
trap cleanup EXIT

log=$(mktemp)
if ! docker run --rm --memory 256m --user 999:999 --volumes-from "${DB_CID}" \
	--network "container:${DB_CID}" -e MYSQL_PWD "${DB_IMG}" "${args[@]}" < /dev/null > "${log}" 2>&1; then
	tail -n 10 "${log}" >&2
	rm -f "${log}"
	die "mariadb-upgrade failed"
fi
tail -n 3 "${log}"
rm -f "${log}"

version=$(sql 'SELECT VERSION()' < /dev/null) || die "cannot query VERSION()"
info=$(docker exec "${DB_CID}" cat /var/lib/mysql/mariadb_upgrade_info) || die "mariadb_upgrade_info missing"
cols=$(sql "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'mysql' AND TABLE_NAME = 'proc'" < /dev/null) \
	|| die "cannot count mysql.proc columns"
echo "server version:       ${version}"
echo "mariadb_upgrade_info: ${info}"
echo "mysql.proc columns:   ${cols}"
[[ "${version}" == "${info}"* ]] || die "mariadb_upgrade_info (${info}) does not match the server version (${version})"
echo "OK:   upgrade state matches the server version"
