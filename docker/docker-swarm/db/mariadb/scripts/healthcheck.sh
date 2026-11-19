#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# healthcheck.sh — do the healthcheck@ accounts match .my-healthcheck.cnf?
# Usage: STACK_NAME=<stack> [SOURCE_CONTAINER=<c>] bash scripts/healthcheck.sh check
#        ... CONFIRM=yes bash scripts/healthcheck.sh fix
#        (make healthcheck-check / make healthcheck-fix)
#
# The image's healthcheck.sh logs in with the password the entrypoint wrote
# to <datadir>/.my-healthcheck.cnf. A datadir from compose (which checked
# health with MARIADB_USER) can carry healthcheck@ accounts with another
# password: the stack's task then turns unhealthy and is stopped.
#
# check: in a client container with the datadir read-only (--volumes-from),
#        log in as healthcheck@127.0.0.1 with the file's password, and as root
#        compare the hash of healthcheck@{127.0.0.1,::1,localhost} with it.
# fix:   the entrypoint's own SQL (CREATE USER IF NOT EXISTS + SET PASSWORD +
#        GRANT USAGE for the three hosts) with sql_log_bin = 0, so each server
#        of a pair is fixed on its own; then check. On a NO_LOCK_NO_ADMIN
#        replica read_only is ON for the run and set back afterwards.
# The password is read from the file inside the client container and sent
# as SQL on stdin: never in argv, the environment or the output.
# Env: STACK_NAME, SERVICE, SOURCE_CONTAINER, CONFIRM, MARIADB_ROOT_PASSWORD (optional).
set -euo pipefail
shopt -s inherit_errexit

# shellcheck source=db-common.sh
source "${BASH_SOURCE[0]%/*}/db-common.sh"

readonly HOSTS="127.0.0.1 ::1 localhost"

# Runs in the client container (POSIX sh). $1 = check | fix. The password
# stays in shell variables; printf is a builtin, so it never reaches argv.
# shellcheck disable=SC2016  # expands inside the container
INNER=$(cat <<'SH'
set -eu
f=/var/lib/mysql/.my-healthcheck.cnf
[ -r "$f" ] || { echo "nofile"; exit 0; }
pw=$(sed -n 's/^password=//p' "$f")
[ -n "$pw" ] || { echo "nopassword"; exit 0; }
esc=$(printf '%s' "$pw" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g")
root() { mariadb --host=127.0.0.1 --port=3306 --user=root --skip-ssl-verify-server-cert --batch --skip-column-names; }
if [ "$1" = fix ]; then
	{
		echo "SET SESSION sql_log_bin = 0;"
		for h in $HOSTS; do
			printf "CREATE USER IF NOT EXISTS healthcheck@'%s' IDENTIFIED BY '%s';\n" "$h" "$esc"
			printf "SET PASSWORD FOR healthcheck@'%s' = PASSWORD('%s');\n" "$h" "$esc"
			printf "GRANT USAGE ON *.* TO healthcheck@'%s';\n" "$h"
		done
	} | root 2>&1 | sed 's/^/sql: /'
	exit 0
fi
if out=$(env -u MYSQL_PWD mariadb --defaults-file="$f" --host=127.0.0.1 --protocol=tcp \
		--skip-ssl-verify-server-cert --batch --skip-column-names -e 'SELECT CURRENT_USER()' 2>&1); then
	echo "login ok $out"
else
	echo "login failed $(printf '%s' "$out" | tail -n 1)"
fi
printf "SELECT CONCAT('account ', host, ' ', IF(authentication_string = PASSWORD('%s'), 'match', 'differs')) FROM mysql.user WHERE user = 'healthcheck' ORDER BY host;\n" "$esc" \
	| root 2>&1 || true
SH
)

# inner <check|fix> — run INNER next to the server, datadir read-only.
inner() {
	docker run --rm -i --memory 128m --network "container:${DB_CID}" --volumes-from "${DB_CID}:ro" \
		-e MYSQL_PWD -e HOSTS="${HOSTS}" "${DB_IMG}" sh -c "${INNER}" sh "$1" < /dev/null
}

cmd_check() {
	local out line host state ok=1 seen=""
	out=$(inner check) || die "client container failed"
	case "${out}" in
		nofile) die "no readable .my-healthcheck.cnf in the datadir — the image's healthcheck cannot log in" ;;
		nopassword) die ".my-healthcheck.cnf has no password= line" ;;
		*) ;;
	esac
	while IFS= read -r line; do
		case "${line}" in
			"login ok "*) echo "login:   ${line#login ok } with the password of .my-healthcheck.cnf" ;;
			"login failed "*) echo "login:   FAILED — ${line#login failed }"; ok=0 ;;
			"account "*)
				read -r _ host state <<< "${line}"
				printf 'account: healthcheck@%-10s %s\n' "'${host}'" "${state}"
				seen+=" ${host}"
				[[ "${state}" == match ]] || ok=0 ;;
			*) echo "${line}"; ok=0 ;;
		esac
	done <<< "${out}"
	for host in ${HOSTS}; do
		[[ " ${seen} " == *" ${host} "* ]] || { printf 'account: healthcheck@%-10s missing\n' "'${host}'"; ok=0; }
	done
	(( ok )) || die "healthcheck accounts do not match .my-healthcheck.cnf — run: make healthcheck-fix${SOURCE_CONTAINER:+ SOURCE_CONTAINER=${SOURCE_CONTAINER}} CONFIRM=yes"
	echo "OK:   healthcheck accounts match .my-healthcheck.cnf"
}

cmd_fix() {
	local ro out
	[[ "${CONFIRM:-}" == yes ]] || die "sets the healthcheck@ passwords to the one in .my-healthcheck.cnf — add CONFIRM=yes"
	ro=$(sql 'SELECT @@GLOBAL.read_only' < /dev/null) || die "cannot query read_only"
	case "${ro}" in
		NO_LOCK_NO_ADMIN|NO_LOCK)
			sql 'SET GLOBAL read_only = ON' < /dev/null || die "cannot set read_only = ON"
			# shellcheck disable=SC2064  # ro is fixed now
			trap "sql 'SET GLOBAL read_only = ${ro}' < /dev/null || echo 'FAIL: could not set read_only = ${ro} again' >&2" EXIT
			echo "NOTE: read_only ${ro} -> ON for the fix" ;;
		*) ;;
	esac
	out=$(inner fix) || die "client container failed"
	case "${out}" in
		nofile) die "no readable .my-healthcheck.cnf in the datadir — nothing to match" ;;
		nopassword) die ".my-healthcheck.cnf has no password= line" ;;
		"") echo "fixed:   healthcheck@{${HOSTS// /,}} (sql_log_bin = 0)" ;;
		*) echo "${out}" >&2; die "fix statements failed" ;;
	esac
	cmd_check
}

db_target
root_password
case "${1:-}" in
	check) cmd_check ;;
	fix) cmd_fix ;;
	*) die "usage: healthcheck.sh check|fix" ;;
esac
