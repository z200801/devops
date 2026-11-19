#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# repl.sh <command> — replication (GTID, semi-sync) in both roles.
# Usage: bash scripts/repl.sh {status|user-create|dump|start|stop|promote|demote}   (make repl-*)
#
# The persistent role lives in replication.cnf (DB_ROLE / SERVER_ID in
# $(DEPLOY_DIR)/.env, applied by make reload-service): read_only, binlog,
# semi-sync survive restarts. promote / demote change the running server at
# once and print the .env change that makes it permanent; until then a
# restart falls back to the configured role (a promoted replica comes back
# read-only — safe, never a second writable primary).
# A replica is read_only = NO_LOCK_NO_ADMIN: no client writes, root included
# (with ON, READ ONLY ADMIN — root — still writes). That also blocks seeding:
# seed while DB_ROLE is empty, then DB_ROLE=replica + reload-service + start.
# Replication state (CHANGE MASTER, gtid_slave_pos) is kept in the datadir:
# a replica resumes by itself after a restart or redeploy.
#
# Every statement runs in a client container (db-common.sh); passwords are
# sent on stdin, never in argv.
# Env: STACK_NAME, SERVICE, MARIADB_ROOT_PASSWORD / MARIADB_REPL_PASSWORD
#      (optional overrides of the task's secrets), PRIMARY_HOST, PRIMARY_PORT,
#      REPLICA_HOST, REPL_USER, GTID_POS, FILE, BU_DIR, CONFIRM, DB_ROLE,
#      DEPLOY_DIR, REPL_TIMEOUT.
set -euo pipefail
shopt -s inherit_errexit

# shellcheck source=db-common.sh
source "${BASH_SOURCE[0]%/*}/db-common.sh"

readonly HOST_RE='^[A-Za-z0-9._:-]+$'
readonly GTID_RE='^[0-9]+-[0-9]+-[0-9]+(,[0-9]+-[0-9]+-[0-9]+)*$'
readonly SYSTEM_DBS='^(mysql|information_schema|performance_schema|sys)$'
readonly USER_NAME=${REPL_USER:-repl}
readonly ENV_FILE="${DEPLOY_DIR:-<DEPLOY_DIR>}/.env"

# sq <string> — the string as a SQL single-quoted literal.
sq() {
	local s=${1//\\/\\\\}
	s=${s//\'/\\\'}
	printf "'%s'" "${s}"
}

need_confirm() { [[ "${CONFIRM:-}" == yes ]] || die "$1 — add CONFIRM=yes"; }

repl_password() {
	local pw=${MARIADB_REPL_PASSWORD:-}
	if [[ -z "${pw}" ]]; then
		pw=$(docker exec "${DB_CID}" cat /run/secrets/repl_password) \
			|| die "cannot read /run/secrets/repl_password — create the secret and redeploy"
	fi
	[[ -n "${pw}" ]] || die "replication password is empty"
	printf '%s' "${pw}"
}

# var <name> — value of a global variable (internal names only).
var() { sql "SELECT @@GLOBAL.$1" < /dev/null; }

# is_read_only — 0 if the server is read-only. read_only is an enum in 12.x
# (OFF, ON, NO_LOCK, NO_LOCK_NO_ADMIN), older servers return 0/1.
is_read_only() {
	local ro
	ro=$(var read_only) || die "cannot query read_only"
	case "${ro}" in
		OFF|0) return 1 ;;
		*) return 0 ;;
	esac
}

# replica_field <field> — one field of SHOW REPLICA STATUS, empty if none.
replica_field() {
	local out
	out=$(sqlv 'SHOW REPLICA STATUS') || return 1
	awk -v f="$1" '{ k = $1; sub(/:$/, "", k) } k == f { sub(/^[^:]*: ?/, ""); print; exit }' <<< "${out}"
}

# no_events — fail when this server has MariaDB events: a
# replica runs with event_scheduler = DISABLED (required by read_only =
# NO_LOCK_NO_ADMIN), so a replicated CREATE EVENT stops its SQL thread
# with error 1577. A replicated pair has no events.
no_events() {
	local n list
	n=$(sql 'SELECT COUNT(*) FROM mysql.event' < /dev/null) || die "cannot count events"
	(( n == 0 )) && return 0
	list=$(sql "SELECT CONCAT(db, '.', name) FROM mysql.event ORDER BY 1" < /dev/null) || list="?"
	echo "Events: ${list//$'\n'/ }" >&2
	die "${n} MariaDB event(s) on this server — a replicated pair has no events: the replica runs with event_scheduler = DISABLED (needed for read_only = NO_LOCK_NO_ADMIN), so replicating CREATE EVENT would stop its SQL thread (error 1577). Drop or move the events first."
}

# primary_target — validate PRIMARY_HOST / PRIMARY_PORT.
primary_target() {
	[[ -n "${PRIMARY_HOST:-}" ]] || die "PRIMARY_HOST= required (primary's IP or name, as reachable from this server)"
	[[ "${PRIMARY_HOST}" =~ ${HOST_RE} ]] || die "PRIMARY_HOST='${PRIMARY_HOST}' is not a host name or IP"
	[[ "${PRIMARY_PORT:-}" =~ ^[0-9]+$ ]] || die "PRIMARY_PORT='${PRIMARY_PORT:-}' is not a port"
}

# change_master_sql <extra options> — STOP / CHANGE MASTER (GTID) / START on stdout.
change_master_sql() {
	local pw
	pw=$(repl_password)
	printf 'STOP REPLICA;\n'
	if [[ -n "${gtid}" ]]; then printf 'SET GLOBAL gtid_slave_pos = %s;\n' "$(sq "${gtid}")"; fi
	printf 'CHANGE MASTER TO MASTER_HOST = %s, MASTER_PORT = %s, MASTER_USER = %s, MASTER_PASSWORD = %s, MASTER_USE_GTID = slave_pos, MASTER_CONNECT_RETRY = 10%s;\n' \
		"$(sq "${PRIMARY_HOST}")" "${PRIMARY_PORT}" "$(sq "${USER_NAME}")" "$(sq "${pw}")" "$1"
	printf 'START REPLICA;\n'
}

# admin_window <sql-producing command...> — run replication setup on a
# NO_LOCK_NO_ADMIN server: NO_LOCK_NO_ADMIN blocks root too, including
# SET GLOBAL gtid_slave_pos (a write to mysql.gtid_slave_pos). read_only = ON
# for the setup (application users stay blocked), then the given final value
# is set again whether the setup succeeded or not.
admin_window() {
	local final=$1 rc=0
	shift
	[[ "${final}" =~ ^([A-Z_]+|0|1)$ ]] || die "unexpected read_only value '${final}'"
	{ printf 'SET GLOBAL read_only = ON;\n'; "$@"; } | sql_in || rc=1
	printf 'SET GLOBAL read_only = %s;\n' "${final}" | sql_in || die "could not set read_only = ${final} again — check: make repl-status"
	return "${rc}"
}

# wait_running — until both replica threads run, or fail with the last error.
# shellcheck disable=SC2154  # EPOCHSECONDS: bash 5 built-in
wait_running() {
	local end io sqlr
	end=$(( EPOCHSECONDS + ${REPL_TIMEOUT:-60} ))
	while (( EPOCHSECONDS < end )); do
		io=$(replica_field Slave_IO_Running) || io="?"
		sqlr=$(replica_field Slave_SQL_Running) || sqlr="?"
		if [[ "${io}" == Yes && "${sqlr}" == Yes ]]; then
			echo "OK:   Slave_IO_Running: Yes, Slave_SQL_Running: Yes"
			return 0
		fi
		sleep 2
	done
	echo "FAIL: replica threads IO=${io} SQL=${sqlr}" >&2
	replica_field Last_IO_Error >&2 || true
	replica_field Last_SQL_Error >&2 || true
	return 1
}

cmd_status() {
	local out
	out=$(sqlv "SELECT @@server_id AS server_id, @@log_bin AS log_bin, @@read_only AS read_only,
		@@gtid_binlog_pos AS gtid_binlog_pos, @@gtid_slave_pos AS gtid_slave_pos,
		@@gtid_current_pos AS gtid_current_pos, @@rpl_semi_sync_master_enabled AS semi_sync_master_enabled,
		@@rpl_semi_sync_slave_enabled AS semi_sync_slave_enabled") || die "cannot query ${STACK_NAME:-?}"
	echo "configured role (DB_ROLE): ${DB_ROLE:-standalone}"
	grep -E '^ *[a-z_]+:' <<< "${out}"
	out=$(sql 'SELECT COUNT(*) FROM mysql.event' < /dev/null) || out="?"
	echo "events (mysql.event): ${out} (a replicated pair must have 0)"
	out=$(sql "SHOW STATUS LIKE 'Rpl_semi_sync_%_status'" < /dev/null) || die "cannot query semi-sync status"
	awk '{ printf "%s: %s\n", $1, $2 }' <<< "${out}"
	out=$(sqlv 'SHOW REPLICA STATUS') || die "cannot query replica status"
	if [[ -z "${out}" ]]; then
		echo "replica: not configured"
	else
		grep -E '^ *(Slave_IO_State|Master_Host|Master_Port|Master_User|Slave_IO_Running|Slave_SQL_Running|Using_Gtid|Gtid_IO_Pos|Seconds_Behind_Master|Last_IO_Error|Last_SQL_Error):' <<< "${out}"
	fi
}

cmd_user_create() {
	local host pw
	host=${REPLICA_HOST:-}
	[[ -n "${host}" ]] || die "REPLICA_HOST= required (replica's IP as the primary sees it, or ip/netmask)"
	[[ "${host}" != *%* ]] || die "REPLICA_HOST must name the replica, not a wildcard (%)"
	[[ "${host}" =~ ^[A-Za-z0-9._:-]+(/[0-9.]+)?$ ]] || die "REPLICA_HOST='${host}' is not an IP, host name or ip/netmask"
	if is_read_only; then die "this server is read-only — create the replication user on the primary"; fi
	no_events
	pw=$(repl_password)
	{
		printf 'CREATE USER IF NOT EXISTS %s@%s IDENTIFIED BY %s;\n' "$(sq "${USER_NAME}")" "$(sq "${host}")" "$(sq "${pw}")"
		printf 'ALTER USER %s@%s IDENTIFIED BY %s;\n' "$(sq "${USER_NAME}")" "$(sq "${host}")" "$(sq "${pw}")"
		printf 'GRANT REPLICATION SLAVE ON *.* TO %s@%s;\n' "$(sq "${USER_NAME}")" "$(sq "${host}")"
	} | sql_in || die "creating ${USER_NAME}@'${host}'"
	sql "SHOW GRANTS FOR $(sq "${USER_NAME}")@$(sq "${host}")" < /dev/null | sed -E "s/PASSWORD '[^']*'/PASSWORD '<hash>'/"
	echo "OK:   ${USER_NAME}@'${host}' with the stack's replication password"
}

# dump_cleanup — on failure remove the partial dump (dir and archive).
dump_dir=""
dump_ok=0
dump_cleanup() {
	if (( dump_ok == 0 )) && [[ -n "${dump_dir}" ]]; then
		rm -rf "${dump_dir}" "${dump_dir}.tar.gz"
		echo "Partial dump removed: ${dump_dir}" >&2
	fi
}

cmd_dump() {
	local base=${BU_DIR:?BU_DIR required} ts name out all_dbs last gtid sum lb
	local -a dbs
	lb=$(var log_bin) || die "cannot query log_bin"
	[[ "${lb}" == 1 ]] || die "binary log is off — set DB_ROLE=primary in ${ENV_FILE}, then make reload-service"
	no_events
	printf -v ts '%(%Y%m%d%H%M%S)T' -1
	name="${STACK_NAME:-mariadb-lts}-repl-dump-${ts}"
	out="${base}/${name}"
	dump_dir=${out}
	trap dump_cleanup EXIT
	mkdir -p "${out}"
	all_dbs=$(sql 'SHOW DATABASES' < /dev/null) || die "cannot list databases"
	mapfile -t dbs < <(grep -Ev "${SYSTEM_DBS}" <<< "${all_dbs}" || true)
	(( ${#dbs[@]} )) || die "no application databases found — a new empty pair needs no dump: see R1-new in README.replication.md"
	printf '%s\n' "${dbs[*]}" > "${out}/DATABASES"
	client 128m mariadb-dump --host=127.0.0.1 --port=3306 --user=root --skip-ssl-verify-server-cert \
		--system=users < /dev/null > "${out}/users.sql" || die "mariadb-dump --system=users"
	client 256m mariadb-dump --host=127.0.0.1 --port=3306 --user=root --skip-ssl-verify-server-cert \
		--single-transaction --gtid --master-data=2 --routines --events --triggers \
		--databases "${dbs[@]}" < /dev/null | gzip > "${out}/dump.sql.gz" || die "mariadb-dump of databases"
	last=$(gzip -dc "${out}/dump.sql.gz" | tail -n 1)
	[[ "${last}" == "-- Dump completed"* ]] || die "dump.sql.gz incomplete (last line: ${last})"
	last=$(tail -n 1 "${out}/users.sql")
	[[ "${last}" == "-- Dump completed"* ]] || die "users.sql incomplete (last line: ${last})"
	# whole stream, no early exit: head / grep -m would SIGPIPE gzip under pipefail
	gtid=$(gzip -dc "${out}/dump.sql.gz" | sed -n "s/^-- SET GLOBAL gtid_slave_pos='\(.*\)';$/\1/p")
	gtid=${gtid%%$'\n'*}
	[[ -z "${gtid}" || "${gtid}" =~ ${GTID_RE} ]] || die "unexpected GTID position in the dump: '${gtid}'"
	printf '%s\n' "${gtid}" > "${out}/GTID_POS"
	tar -C "${out}" -czf "${out}.tar.gz" ./DATABASES ./users.sql ./dump.sql.gz ./GTID_POS
	sum=$(sha256sum < "${out}.tar.gz")
	printf '%s  %s\n' "${sum%% *}" "${name}.tar.gz" > "${out}.tar.gz.sha256"
	rm -rf "${out}"
	dump_ok=1
	echo "OK:   ${#dbs[@]} databases, GTID position '${gtid}'"
	echo "OK:   ${out}.tar.gz — contains password hashes, keep out of git"
	echo "On the replica (DB_ROLE still empty — a read-only replica refuses the restore):"
	echo "  make db-restore FILE=${out}.tar.gz CONFIRM=yes NO_BINLOG=yes"
	echo "  set DB_ROLE=replica + SERVER_ID in .env; make reload-service"
	echo "  make repl-start PRIMARY_HOST=<this host> PRIMARY_PORT=<port> FILE=${out}.tar.gz"
}

cmd_start() {
	local ro
	primary_target
	is_read_only || die "this server is writable — seed it first if needed (db-restore), then set DB_ROLE=replica in ${ENV_FILE} and make reload-service"
	gtid=""
	if [[ -n "${FILE:-}" && -n "${GTID_POS:-}" ]]; then
		die "give FILE= or GTID_POS=, not both"
	elif [[ -n "${FILE:-}" ]]; then
		[[ -f "${FILE}" ]] || die "not found: ${FILE}"
		gtid=$(tar -xzOf "${FILE}" ./GTID_POS 2>/dev/null) || die "${FILE} has no GTID_POS — not a repl-dump file"
		[[ -n "${gtid}" ]] || echo "NOTE: empty GTID position — replicating from the primary's first binlog event"
	elif [[ -n "${GTID_POS:-}" ]]; then
		gtid=${GTID_POS}
	fi
	[[ -z "${gtid}" || "${gtid}" =~ ${GTID_RE} ]] || die "GTID position '${gtid}' is malformed"
	ro=$(var read_only) || die "cannot query read_only"
	admin_window "${ro}" change_master_sql "" || die "CHANGE MASTER / START REPLICA"
	wait_running || die "replication did not start"
	cmd_status
}

cmd_stop() {
	sql 'STOP REPLICA' < /dev/null || die "STOP REPLICA"
	echo "OK:   replica threads stopped (configuration kept; make repl-start to resume)"
}

cmd_promote() {
	local out
	need_confirm "makes this server a writable primary"
	out=$(sqlv "SELECT @@gtid_slave_pos AS gtid_slave_pos, @@gtid_current_pos AS gtid_current_pos") || die "cannot query"
	grep -E '^ *[a-z_]+:' <<< "${out}"
	out=$(replica_field Seconds_Behind_Master) || out="?"
	echo "Seconds_Behind_Master before promote: ${out:-not a replica}"
	printf 'STOP REPLICA;\nRESET REPLICA ALL;\nSET GLOBAL read_only = 0;\n' | sql_in || die "promote"
	echo "OK:   replication removed, read_only=0 — this server accepts writes now"
	echo "Persist: set DB_ROLE=primary in ${ENV_FILE}, then make reload-service"
	echo "         (until then a restart brings it back read-only)"
}

cmd_demote() {
	need_confirm "makes this server a read-only replica of ${PRIMARY_HOST:-?}"
	primary_target
	gtid=""
	admin_window NO_LOCK_NO_ADMIN change_master_sql ", MASTER_DEMOTE_TO_SLAVE = 1" || die "demote"
	wait_running || die "replication did not start"
	echo "Persist: set DB_ROLE=replica in ${ENV_FILE}, then make reload-service"
	cmd_status
}

db_target
root_password
gtid=""
case "${1:-}" in
	status)      cmd_status ;;
	user-create) cmd_user_create ;;
	dump)        cmd_dump ;;
	start)       cmd_start ;;
	stop)        cmd_stop ;;
	promote)     cmd_promote ;;
	demote)      cmd_demote ;;
	*) echo "Usage: $0 {status|user-create|dump|start|stop|promote|demote}" >&2; exit 2 ;;
esac
