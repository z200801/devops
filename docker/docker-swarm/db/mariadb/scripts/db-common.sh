#!/usr/bin/env bash
# db-common.sh — helpers shared by the db-* scripts; sourced, not run.
# Usage: source "${BASH_SOURCE[0]%/*}/db-common.sh"
#
# Clients never run inside the db container (they would share its memory
# limit and got mariadbd OOM-killed): every client is a throwaway container
# of the server image with its own --memory, on the db's network namespace.
# Env: STACK_NAME, SERVICE (default db), SOURCE_CONTAINER (compose container
#      instead of the swarm task), MARIADB_ROOT_PASSWORD (optional override).

die() { echo "FAIL: $*" >&2; exit 1; }

# db_target — set DB_CID (full id) and DB_IMG of the running server:
# SOURCE_CONTAINER if given, else the single running task of the service.
db_target() {
	local svc out
	if [[ -n "${SOURCE_CONTAINER:-}" ]]; then
		out=$(docker inspect -f '{{.Id}} {{.Image}} {{.State.Running}}' "${SOURCE_CONTAINER}" 2>/dev/null) \
			|| die "container not found: ${SOURCE_CONTAINER}"
		read -r DB_CID DB_IMG out <<< "${out}"
		[[ "${out}" == true ]] || die "container not running: ${SOURCE_CONTAINER}"
		return 0
	fi
	svc="${STACK_NAME:?STACK_NAME required}_${SERVICE:-db}"
	DB_IMG=$(docker service inspect "${svc}" --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null) \
		|| die "service ${svc} not found — run: make stack-deploy"
	DB_CID=$(docker ps -q --no-trunc -f "label=com.docker.swarm.service.name=${svc}")
	[[ -n "${DB_CID}" && "${DB_CID}" != *$'\n'* ]] || die "expected one running task container of ${svc}, got: ${DB_CID:-none}"
}

# root_password — export MYSQL_PWD (read by every client; never in argv):
# MARIADB_ROOT_PASSWORD if given, else the secret file in the db container,
# else its MARIADB_ROOT_PASSWORD environment (compose).
root_password() {
	local pw=${MARIADB_ROOT_PASSWORD:-}
	if [[ -z "${pw}" ]]; then
		# shellcheck disable=SC2016  # expands inside the container
		pw=$(docker exec "${DB_CID}" sh -c 'cat /run/secrets/root_password 2>/dev/null || printenv MARIADB_ROOT_PASSWORD') \
			|| die "cannot read the root password from the db container"
	fi
	[[ -n "${pw}" ]] || die "root password is empty"
	MYSQL_PWD=${pw}
	export MYSQL_PWD
}

# client <memory> <command...> — run a client in a throwaway container on the
# db's network namespace; stdin is passed through.
client() {
	local mem=$1
	shift
	docker run --rm -i --memory="${mem}" --network "container:${DB_CID}" -e MYSQL_PWD "${DB_IMG}" "$@"
}

# sql <statements> — run SQL as root@'%' over 127.0.0.1, tab-separated, no header.
sql() {
	client 128m mariadb --host=127.0.0.1 --port=3306 --user=root \
		--skip-ssl-verify-server-cert --batch --skip-column-names --execute="$1"
}

# sql_in — run SQL statements read from stdin (statements with passwords:
# never in argv), tab-separated, no header.
sql_in() {
	client 128m mariadb --host=127.0.0.1 --port=3306 --user=root \
		--skip-ssl-verify-server-cert --batch --skip-column-names
}

# sqlv <statements> — like sql, vertical output ("   Field: value").
sqlv() {
	client 128m mariadb --host=127.0.0.1 --port=3306 --user=root \
		--skip-ssl-verify-server-cert --vertical --execute="$1" < /dev/null
}
