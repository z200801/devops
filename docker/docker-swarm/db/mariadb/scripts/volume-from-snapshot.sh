#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# volume-from-snapshot.sh — physical restore of a db-backup snapshot into an
# empty, unused volume DB_VOLUME (created if missing).
# Usage: STACK_NAME=<stack> DB_VOLUME=<vol> DB_IMAGE=<image> SNAPSHOT=<tar.gz> CONFIRM=yes \
#        [RESET_ROOT=yes MARIADB_ROOT_PASSWORD=...] bash scripts/volume-from-snapshot.sh
#        (make volume-from-snapshot)
#
# 1. mb/ (prepared) is streamed into a throwaway root container and moved
#    into the volume with mariadb-backup --move-back, then chown mysql.
# 2. The physical backup lacks .my-healthcheck.cnf: a one-off server with
#    MARIADB_AUTO_UPGRADE=1 lets the image entrypoint recreate the healthcheck
#    users and the file (it does so whenever the file is missing; no
#    mariadb-upgrade runs when the versions match). Stopped once healthy.
# 3. RESET_ROOT=yes (test stacks only): a one-off server with
#    --skip-grant-tables runs an init file (FLUSH PRIVILEGES; ALTER USER) that
#    sets root@localhost and root@'%' to MARIADB_ROOT_PASSWORD, which must
#    match the stack's root secret (sha256 label) when that secret exists.
# Env: STACK_NAME, DB_VOLUME, DB_IMAGE, SNAPSHOT, CONFIRM, RESET_ROOT,
#      MARIADB_ROOT_PASSWORD, SECRET_ROOT_PASSWORD (secret name), MY_CNF
#      (stack my.cnf for the one-off servers; required), START_TIMEOUT.
set -euo pipefail
shopt -s inherit_errexit

# shellcheck source=cnf-check.sh
source "${BASH_SOURCE[0]%/*}/cnf-check.sh"

die() { echo "FAIL: $*" >&2; exit 1; }

readonly TEST_PREFIX="mariadb-test"
STACK=${STACK_NAME:?STACK_NAME required}
VOL=${DB_VOLUME:?DB_VOLUME required}
IMG=${DB_IMAGE:?DB_IMAGE required}
SNAP=${SNAPSHOT:-}
readonly STACK VOL IMG SNAP

# The stack's my.cnf for the one-off servers (same redo log / buffer pool).
CNF=${MY_CNF:?MY_CNF required (the stack my.cnf)}
readonly CNF
[[ -f "${CNF}" ]] || die "MY_CNF not found: ${CNF}"

[[ -n "${SNAP}" && -f "${SNAP}" ]] || die "SNAPSHOT=<snapshot.tar.gz> required (got '${SNAP}')"
[[ "${CONFIRM:-}" == yes ]] || die "fills volume ${VOL} from ${SNAP} — add CONFIRM=yes"

# ---------- RESET_ROOT pre-checks ----------
reset_root=0
if [[ "${RESET_ROOT:-}" == yes ]]; then
	[[ "${STACK}" == "${TEST_PREFIX}"* ]] || die "RESET_ROOT=yes is only allowed for test stacks (${TEST_PREFIX}*)"
	[[ -n "${MARIADB_ROOT_PASSWORD:-}" ]] || die "RESET_ROOT=yes needs MARIADB_ROOT_PASSWORD (the stack's root secret value)"
	if [[ -n "${SECRET_ROOT_PASSWORD:-}" ]] && docker secret inspect "${SECRET_ROOT_PASSWORD}" >/dev/null 2>&1; then
		label=$(docker secret inspect "${SECRET_ROOT_PASSWORD}" --format '{{index .Spec.Labels "sha256"}}')
		given=$(printf '%s' "${MARIADB_ROOT_PASSWORD}" | sha256sum)
		[[ "${label}" == "${given%% *}" ]] \
			|| die "MARIADB_ROOT_PASSWORD does not match secret ${SECRET_ROOT_PASSWORD}"
	fi
	reset_root=1
elif [[ -n "${RESET_ROOT:-}" ]]; then
	die "RESET_ROOT='${RESET_ROOT}' — use RESET_ROOT=yes or leave it empty"
fi

# ---------- snapshot checks ----------
if [[ -f "${SNAP}.sha256" ]]; then
	expected=$(< "${SNAP}.sha256")
	actual=$(sha256sum < "${SNAP}")
	[[ "${expected%% *}" == "${actual%% *}" ]] || die "checksum mismatch: ${SNAP}"
	echo "OK:   checksum ${SNAP##*/}"
else
	echo "WARN: no ${SNAP##*/}.sha256 — checksum not verified"
fi
tar -tzf "${SNAP}" ./mb/backup-my.cnf ./mb/mariadb_backup_checkpoints >/dev/null 2>&1 \
	|| die "${SNAP} has no prepared physical backup (mb/)"

# ---------- volume checks ----------
if docker volume inspect "${VOL}" >/dev/null 2>&1; then
	users=$(docker ps -aq --filter "volume=${VOL}")
	[[ -z "${users}" ]] || die "volume ${VOL} is used by container(s): ${users//$'\n'/ } — run: make stack-rm"
	entry=$(docker run --rm --network none -v "${VOL}:/v:ro" --entrypoint find "${IMG}" /v -mindepth 1 -maxdepth 1 -print -quit)
	[[ -z "${entry}" ]] || die "volume ${VOL} is not empty (${entry#/v/} ...) — restore needs an empty volume"
	echo "OK:   volume ${VOL} exists, empty, unused"
else
	docker volume create "${VOL}" >/dev/null
	echo "OK:   volume ${VOL} created"
fi

printf -v ts '%(%Y%m%d%H%M%S)T' -1
readonly ONEOFF="${STACK}-restore-${ts}"
WORK=$(mktemp -d)
readonly WORK
cleanup() {
	docker rm -f "${ONEOFF}" >/dev/null 2>&1 || true
	rm -rf "${WORK}"
}
trap cleanup EXIT

# 0644 copy + read check (cnf-check.sh): the one-off servers run as mysql and
# would silently ignore an unreadable my.cnf.
cnf_copy "${CNF}" "${WORK}/my.cnf"
EXPECTED=$(cnf_expected "${WORK}/my.cnf")
export EXPECTED
cnf_mount=(-e EXPECTED -v "${WORK}/my.cnf:/etc/mysql/conf.d/my.cnf:ro")
read_check=(--entrypoint bash)
read_check_args=(-c "${CNF_READ_CHECK}" _)

# ---------- 1. move-back + chown ----------
# shellcheck disable=SC2016  # runs inside the container
if ! docker run --rm -i --memory=512m --network none --user 0 --entrypoint bash \
	-v "${VOL}:/var/lib/mysql" "${IMG}" -c '
		set -euo pipefail
		mkdir -p /restore
		tar -xzf - -C /restore ./mb
		grep -qE "^backup_type = (full-prepared|log-applied)$" /restore/mb/mariadb_backup_checkpoints \
			|| { echo "mb/ is not prepared"; exit 1; }
		mariadb-backup --move-back --target-dir=/restore/mb --datadir=/var/lib/mysql
		chown -R mysql:mysql /var/lib/mysql' < "${SNAP}" > "${WORK}/move-back.log" 2>&1; then
	tail -n 5 "${WORK}/move-back.log" >&2
	die "move-back into ${VOL}"
fi
grep -q 'completed OK!' "${WORK}/move-back.log" || { tail -n 5 "${WORK}/move-back.log" >&2; die "move-back not completed"; }
echo "OK:   physical backup moved into ${VOL}"

# wait_ready <container> <condition: healthy|ready> — until the condition or
# START_TIMEOUT; the one-off server must still be running.
# shellcheck disable=SC2154  # EPOCHSECONDS: bash 5 built-in
wait_ready() {
	local end state logs
	end=$(( EPOCHSECONDS + ${START_TIMEOUT:-300} ))
	while (( EPOCHSECONDS < end )); do
		state=$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$1") || return 1
		[[ "${state}" == running* ]] || { docker logs --tail 10 "$1" >&2; return 1; }
		case "$2" in
			healthy) [[ "${state}" == "running healthy" ]] && return 0 ;;
			ready)
				logs=$(docker logs "$1" 2>&1) || return 1
				grep -q 'ready for connections' <<< "${logs}" && return 0 ;;
			*) return 1 ;;
		esac
		sleep 2
	done
	echo "timeout after ${START_TIMEOUT:-300}s" >&2
	return 1
}

# stop_oneoff — graceful stop, the server must report a clean shutdown.
stop_oneoff() {
	local logs
	docker stop -t 120 "${ONEOFF}" >/dev/null
	logs=$(docker logs "${ONEOFF}" 2>&1)
	docker rm "${ONEOFF}" >/dev/null
	grep -m1 'read check OK' <<< "${logs}" || die "one-off server did not pass the my.cnf read check"
	grep -q 'Shutdown complete' <<< "${logs}" || die "one-off server did not shut down cleanly"
	if grep -q '\[ERROR\]' <<< "${logs}"; then
		grep '\[ERROR\]' <<< "${logs}" | tail -n 5 >&2
		die "one-off server logged errors"
	fi
}

# ---------- 2. healthcheck credentials ----------
docker run -d --name "${ONEOFF}" --memory=512m --network none \
	-e MARIADB_AUTO_UPGRADE=1 -e MARIADB_DISABLE_UPGRADE_BACKUP=1 \
	--health-cmd 'healthcheck.sh --connect --innodb_initialized' --health-interval 2s \
	"${cnf_mount[@]}" -v "${VOL}:/var/lib/mysql" "${read_check[@]}" "${IMG}" \
	"${read_check_args[@]}" docker-entrypoint.sh mariadbd >/dev/null
wait_ready "${ONEOFF}" healthy || die "one-off server did not become healthy"
stop_oneoff
echo "OK:   healthcheck credentials recreated (.my-healthcheck.cnf)"

# ---------- 3. optional root password reset (test stacks) ----------
if (( reset_root )); then
	PW=${MARIADB_ROOT_PASSWORD}
	export PW
	# shellcheck disable=SC2016  # runs inside the container; PW only via env
	reset_script='
			set -euo pipefail
			q=$(printf "\x27")
			pw=${PW//\\/\\\\}
			pw=${pw//"${q}"/\\${q}}
			umask 077
			printf "FLUSH PRIVILEGES;\nALTER USER root@localhost IDENTIFIED BY ${q}%s${q};\nALTER USER root@${q}%%${q} IDENTIFIED BY ${q}%s${q};\n" \
				"${pw}" "${pw}" > /tmp/reset.sql
			chown mysql:mysql /tmp/reset.sql
			unset PW pw
			exec docker-entrypoint.sh mariadbd --skip-grant-tables --skip-networking --init-file=/tmp/reset.sql'
	docker run -d --name "${ONEOFF}" --memory=512m --network none -e PW \
		"${cnf_mount[@]}" -v "${VOL}:/var/lib/mysql" "${read_check[@]}" "${IMG}" \
		"${read_check_args[@]}" bash -c "${reset_script}" >/dev/null
	wait_ready "${ONEOFF}" ready || die "root reset server did not start"
	stop_oneoff
	echo "OK:   root@localhost and root@'%' set to the stack's root secret"
fi

echo "OK:   ${VOL} ready — run: make stack-deploy"
