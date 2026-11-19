#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# reload-service.sh <service> — apply changed configs/secrets to one service
# without touching the rest of the stack.
# Usage: bash scripts/reload-service.sh <service>     (make reload-service)
#
# 1. Discover the service's configs/secrets (docker service inspect).
# 2. Compare each with the repo (configs.sh): nothing changed -> exit 0.
# 3. Refuse if a changed object is also mounted by another service.
# 4. Validate new content with the service's own image.
# 5. Double swap, batched:
#      phase 1: temp objects <name>__<ts>   -> one service update
#      phase 2: recreate canonical <name>   -> one service update, drop temps
#    so canonical names in stack.yml stay valid and nothing is left behind.
#    With update_config order stop-first each phase restarts the task once.
#
# docker service update exits 0 even when Swarm rolled the update back, so
# the outcome is read from .UpdateStatus.State.
#
# Env: registry vars (see configs.sh), STACK_NAME, CONFIG_VALIDATORS
#      ("<docker-name>|mariadbd ..."), DRY_RUN=1, FORCE=1, RELOAD_TIMEOUT.
set -euo pipefail
shopt -s inherit_errexit

# shellcheck source=configs.sh
source "${BASH_SOURCE[0]%/*}/configs.sh"
# shellcheck source=cnf-check.sh
source "${BASH_SOURCE[0]%/*}/cnf-check.sh"

check_values
SERVICE=${1:?usage: reload-service.sh <service>}
SVC="${STACK_NAME:?STACK_NAME required}_${SERVICE}"
printf -v TS '%(%Y%m%d%H%M%S)T' -1
WORK=$(mktemp -d)
readonly SERVICE SVC TS WORK

cleanup() { rm -rf "${WORK}"; }
trap cleanup EXIT

log()  { echo "[${SVC}] $*"; }
fail() { echo "[${SVC}] FAIL: $*" >&2; exit 1; }

docker service inspect "${SVC}" >/dev/null 2>&1 || fail "service not found — run: make stack-deploy"

# ---------- discover ----------
# lines: <kind> <name> <target> <uid> <gid> <mode-octal>
mounts=$(docker service inspect "${SVC}" --format \
'{{range .Spec.TaskTemplate.ContainerSpec.Configs}}config {{.ConfigName}} {{.File.Name}} {{.File.UID}} {{.File.GID}} {{printf "%o" .File.Mode}}{{"\n"}}{{end}}{{range .Spec.TaskTemplate.ContainerSpec.Secrets}}secret {{.SecretName}} {{.File.Name}} {{.File.UID}} {{.File.GID}} {{printf "%o" .File.Mode}}{{"\n"}}{{end}}')
image=$(docker service inspect "${SVC}" --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}')

# ---------- compare ----------
changed=()   # entries "<kind> <name> <target> <uid> <gid> <mode>"
while read -r kind name target uid gid mode; do
	[[ -n "${kind:-}" ]] || continue
	if [[ "${name}" == *__[0-9]* ]]; then
		fail "${name} is a temporary object from an interrupted reload — remount the canonical name with docker service update --${kind}-rm/--${kind}-add"
	fi
	if [[ "${kind}" == config ]]; then
		if ! config_entry "${name}" >/dev/null; then log "skip ${name} (not in registry)"; continue; fi
		out=$(state_config "${name}")
	else
		if ! secret_var "${name}" >/dev/null; then log "skip ${name} (not in registry)"; continue; fi
		out=$(state_secret "${name}")
	fi
	read -r st _ _ <<< "${out}"
	case "${st}" in
		OK)      log "${name}: up to date" ;;
		CHANGED) log "${name}: CHANGED"; changed+=("${kind} ${name} ${target} ${uid} ${gid} ${mode}") ;;
		SKIPPED) log "${name}: SKIPPED (value/variable not given — not compared)" ;;
		UNKNOWN)
			if [[ "${FORCE:-}" == 1 ]]; then
				log "${name}: UNKNOWN (no sha label) — replacing, FORCE=1"
				changed+=("${kind} ${name} ${target} ${uid} ${gid} ${mode}")
			else
				log "${name}: UNKNOWN (no sha label) — not replaced; use FORCE=1"
			fi ;;
		*) fail "${name}: unexpected state ${st}" ;;
	esac
done <<< "${mounts}"

if (( ${#changed[@]} == 0 )); then
	log "up to date — not restarted"
	exit 0
fi

# ---------- shared objects ----------
mapfile -t all_ids < <(docker service ls -q)
users=$(docker service inspect "${all_ids[@]}" --format \
'{{.Spec.Name}}{{range .Spec.TaskTemplate.ContainerSpec.Configs}} {{.ConfigName}}{{end}}{{range .Spec.TaskTemplate.ContainerSpec.Secrets}} {{.SecretName}}{{end}}')
for c in "${changed[@]}"; do
	read -r _ name _ <<< "${c}"
	others=$(awk -v n="${name}" -v me="${SVC}" '$1 != me { for (i = 2; i <= NF; i++) if ($i == n) print $1 }' <<< "${users}")
	[[ -z "${others}" ]] || fail "${name} is also used by: ${others//$'\n'/ } — reload refused"
done

# ---------- render + validate ----------
validator_for() {
	local e
	local -a entries
	read -r -a entries <<< "${CONFIG_VALIDATORS:-}"
	for e in "${entries[@]}"; do
		if [[ "${e%%|*}" == "$1" ]]; then
			printf '%s\n' "${e#*|}"
			return 0
		fi
	done
	echo none
}

# validate <validator> <file> <target> — output on stdout, non-zero if invalid.
# mariadbd parses every option file and exits non-zero on unknown options or
# bad values; --help --verbose stops before touching any datadir. It skips an
# unreadable file silently, so a 0644 copy is mounted and the read check
# (cnf-check.sh) fails closed unless my_print_defaults sees every option.
validate() {
	local copy expected
	case "$1" in
		mariadbd)
			copy="$2.validate"
			cnf_copy "$2" "${copy}" || { echo "[ERROR] cannot copy $2"; return 1; }
			expected=$(cnf_expected "${copy}") || { echo "[ERROR] cannot parse $2"; return 1; }
			EXPECTED=${expected} docker run --rm --network none --memory 256m --user 999:999 \
				-e EXPECTED -v "${copy}:$3:ro" --entrypoint bash "${image}" \
				-c "${CNF_READ_CHECK}" _ mariadbd --help --verbose 2>&1 ;;
		none) return 0 ;;
		*) echo "unknown validator '$1'"; return 1 ;;
	esac
}

for c in "${changed[@]}"; do
	read -r kind name target _ <<< "${c}"
	if [[ "${kind}" == config ]]; then
		render_config "${name}" > "${WORK}/${name}"
		v=$(validator_for "${name}")
		if [[ "${v}" == none ]]; then
			log "${name}: no validator (Swarm rollback is the safety net)"
		elif out=$(validate "${v}" "${WORK}/${name}" "${target}"); then
			note=$(grep -m1 'read check OK' <<< "${out}") || note=""
			log "${name}: ${note#*\[Note\] }"
			log "${name}: valid (${v})"
		else
			# Server errors only: --help --verbose later lists variables whose
			# value is literally ERROR (system-versioning-alter-history).
			grep -m3 '\[ERROR\]' <<< "${out}" >&2 || true
			fail "${name}: validation failed — service not changed"
		fi
	else
		secret_value "${name}" > "${WORK}/${name}"
	fi
done

if [[ "${DRY_RUN:-}" == 1 ]]; then
	summary=""
	for c in "${changed[@]}"; do read -r _ n _ <<< "${c}"; summary+="${n} "; done
	log "DRY_RUN=1 — would update: ${summary}"
	exit 0
fi

# ---------- swap helpers ----------
LAST_STATE=""

# update_service <args...> — returns 0 only if Swarm reports state "completed".
# The CLI can return while UpdateStatus is still "updating" (update_config
# delay/monitor), so poll until a terminal state or RELOAD_TIMEOUT seconds.
# shellcheck disable=SC2154  # EPOCHSECONDS: bash 5 built-in
update_service() {
	local end
	docker service update --detach=false --quiet "$@" "${SVC}" >/dev/null 2>&1 || true
	end=$(( EPOCHSECONDS + ${RELOAD_TIMEOUT:-300} ))
	while :; do
		LAST_STATE=$(docker service inspect "${SVC}" --format '{{if .UpdateStatus}}{{.UpdateStatus.State}}{{end}}') || LAST_STATE="?"
		case "${LAST_STATE}" in
			updating|rollback_started|"?")
				if (( EPOCHSECONDS >= end )); then
					log "update still '${LAST_STATE}' after ${RELOAD_TIMEOUT:-300}s"
					return 1
				fi
				sleep 2 ;;
			completed) return 0 ;;
			*) log "update state: ${LAST_STATE:-unknown}"; return 1 ;;
		esac
	done
}

# swap_args <from-suffix> <to-suffix> -> rm/add flag pairs for the changed objects
swap_args() {
	local c kind name target uid gid mode
	for c in "${changed[@]}"; do
		read -r kind name target uid gid mode <<< "${c}"
		printf -- '--%s-rm\n%s\n--%s-add\nsource=%s,target=%s,uid=%s,gid=%s,mode=0%s\n' \
			"${kind}" "${name}$1" "${kind}" "${name}$2" "${target}" "${uid}" "${gid}" "${mode}"
	done
}

is_changed() {
	local c n
	for c in "${changed[@]}"; do
		read -r _ n _ <<< "${c}"
		if [[ "${n}" == "$1" ]]; then return 0; fi
	done
	return 1
}

# restore_args — remount ALL objects of the service, sorted by name.
# rm/add appends, so a plain swap would move the changed object to the end;
# stack deploy orders configs/secrets by name, so a reordered list would make
# the next deploy restart the service.
restore_args() {
	local kind name target uid gid mode cur
	local -a rms=() adds=()
	while read -r kind name target uid gid mode; do
		[[ -n "${kind:-}" ]] || continue
		cur=${name}
		if is_changed "${name}"; then cur="${name}__${TS}"; fi
		rms+=("--${kind}-rm" "${cur}")
		adds+=("--${kind}-add" "source=${name},target=${target},uid=${uid},gid=${gid},mode=0${mode}")
	done < <(sort -k1,1 -k2,2 <<< "${mounts}")
	printf '%s\n' "${rms[@]}" "${adds[@]}"
}

create_obj() {  # create_obj <kind> <name> <file>
	local val
	if [[ "$1" == config ]]; then
		create_config "$2" "$3"
	else
		val=$(< "$3")
		create_secret "$2" "${val}"
	fi
}

rm_obj() { docker "$1" rm "$2" >/dev/null 2>&1; }

remove_temps() {
	local c kind name
	for c in "${changed[@]}"; do
		read -r kind name _ <<< "${c}"
		rm_obj "${kind}" "${name}__${TS}" || true
	done
}

# ---------- phase 1: point the service at temp objects ----------
for c in "${changed[@]}"; do
	read -r kind name _ <<< "${c}"
	create_obj "${kind}" "${name}__${TS}" "${WORK}/${name}"
done
mapfile -t args < <(swap_args "" "__${TS}")
log "phase 1/2: switching to new content (${#changed[@]} object(s))"
if ! update_service "${args[@]}"; then
	if [[ "${LAST_STATE}" == rollback_completed ]]; then
		remove_temps
		fail "new content rejected by Swarm (rolled back) — service still on the old objects"
	fi
	fail "phase 1 ended in state '${LAST_STATE:-unknown}'; temp objects *__${TS} kept. Check: docker service ps ${SVC}"
fi

# ---------- phase 2: recreate canonical names, switch back ----------
for c in "${changed[@]}"; do
	read -r kind name _ <<< "${c}"
	rm_obj "${kind}" "${name}" || fail "cannot remove ${kind} ${name}; service runs on ${name}__${TS} — rerun after fixing"
	create_obj "${kind}" "${name}" "${WORK}/${name}" \
		|| fail "cannot recreate ${kind} ${name}; service runs on ${name}__${TS}. Recover: make configs-create / secrets-create, then make reload-service SERVICE=${SERVICE}"
done
mapfile -t args < <(restore_args)
log "phase 2/2: switching back to canonical names (original mount order)"
update_service "${args[@]}" \
	|| fail "switch back to canonical names failed; service runs on *__${TS} objects. Recover: docker service update with --config-rm/--config-add"
remove_temps
summary=""
for c in "${changed[@]}"; do read -r _ n _ <<< "${c}"; summary+="${n} "; done
log "reloaded: ${summary}"
