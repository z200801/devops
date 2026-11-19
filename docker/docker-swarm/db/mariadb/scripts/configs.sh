#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# configs.sh — render, create, check and compare the stack's Docker configs
# and secrets. Called by the Makefile; also sourced by reload-service.sh
# and cleanup.sh.
# Usage: bash scripts/configs.sh {render <name>|create|secrets-create|check|secrets-check|status}
#
# Registry (set by the Makefile, whitespace-separated entries):
#   CONFIG_REGISTRY  "<docker-name>|<source-file>|<envsubst vars, comma-separated>"
#   SECRET_REGISTRY  "<docker-name>|<variable holding the value>"
#   EXPLICIT_VARS    variables given on the command line / environment;
#                    only these may supply secret values for comparison.
# Secret values are read from the environment (exported by the Makefile),
# never from argv.
#
# Every object created here carries the label sha256=<sha of rendered content>.
# Configs are compared by hashing their content (Spec.Data); secrets cannot be
# read back, so they are compared by that label (no label -> UNKNOWN).
set -euo pipefail
shopt -s inherit_errexit

readonly SHA_LABEL="sha256"

# ---------- registry lookup ----------

# config_entry <docker-name> -> "<src>|<vars>" or return 1
config_entry() {
	local e
	local -a entries
	read -r -a entries <<< "${CONFIG_REGISTRY:-}"
	for e in "${entries[@]}"; do
		if [[ "${e%%|*}" == "$1" ]]; then
			printf '%s\n' "${e#*|}"
			return 0
		fi
	done
	return 1
}

# secret_var <docker-name> -> variable name or return 1
secret_var() {
	local e
	local -a entries
	read -r -a entries <<< "${SECRET_REGISTRY:-}"
	for e in "${entries[@]}"; do
		if [[ "${e%%|*}" == "$1" ]]; then
			printf '%s\n' "${e#*|}"
			return 0
		fi
	done
	return 1
}

config_names() {
	local e
	local -a entries
	read -r -a entries <<< "${CONFIG_REGISTRY:-}"
	for e in "${entries[@]}"; do printf '%s\n' "${e%%|*}"; done
}

secret_names() {
	local e
	local -a entries
	read -r -a entries <<< "${SECRET_REGISTRY:-}"
	for e in "${entries[@]}"; do printf '%s\n' "${e%%|*}"; done
}

is_explicit() { [[ " ${EXPLICIT_VARS:-} " == *" $1 "* ]]; }

# ---------- value checks ----------

# check_values — reject malformed per-host values before anything renders:
# an unknown DB_ROLE would otherwise silently select the standalone config.
check_values() {
	case "${DB_ROLE:-}" in
		""|primary|replica) ;;
		*) echo "DB_ROLE=${DB_ROLE} is invalid — use primary, replica or leave it empty" >&2; return 1 ;;
	esac
	if [[ -n "${SERVER_ID:-}" && ! "${SERVER_ID}" =~ ^[1-9][0-9]*$ ]]; then
		echo "SERVER_ID=${SERVER_ID} is invalid — use a positive integer" >&2
		return 1
	fi
}

# ---------- rendering ----------

# render_config <docker-name> — rendered content on stdout.
# envsubst only with the explicit variable list; otherwise copied verbatim.
render_config() {
	local entry src vars v fmt=""
	entry=$(config_entry "$1") || { echo "Unknown config: $1" >&2; return 1; }
	src=${entry%%|*}
	vars=${entry#*|}
	[[ -f "${src}" ]] || { echo "Missing: ${src}" >&2; return 1; }
	if [[ -z "${vars}" ]]; then
		cat "${src}"
		return 0
	fi
	for v in ${vars//,/ }; do
		[[ -n "${!v:-}" ]] || { echo "${v}= required to render $1" >&2; return 1; }
		fmt+="\${${v}} "
	done
	envsubst "${fmt}" < "${src}"
}

# secret_value <docker-name> — value on stdout, return 1 if unset/empty.
secret_value() {
	local v
	v=$(secret_var "$1") || { echo "Unknown secret: $1" >&2; return 1; }
	[[ -n "${!v:-}" ]] || { echo "${v}= required (command line or environment)" >&2; return 1; }
	printf '%s' "${!v}"
}

sha() {
	local out
	out=$(sha256sum)
	printf '%s\n' "${out%% *}"
}

# ---------- live objects ----------

config_exists() { docker config inspect "$1" >/dev/null 2>&1; }
secret_exists() { docker secret inspect "$1" >/dev/null 2>&1; }

live_config_sha() {
	local data
	data=$(docker config inspect "$1" --format '{{json .Spec.Data}}') || return 1
	data=${data//\"/}
	base64 -d <<< "${data}" | sha
}

live_secret_sha() {
	docker secret inspect "$1" --format "{{index .Spec.Labels \"${SHA_LABEL}\"}}"
}

# create_config <docker-name> <file> — create from a rendered file, labelled.
create_config() {
	local s
	s=$(sha < "$2") || return 1
	docker config create --label "${SHA_LABEL}=${s}" "$1" "$2" >/dev/null
}

# create_secret <docker-name> <value> — value goes through stdin only.
create_secret() {
	local s
	s=$(printf '%s' "$2" | sha) || return 1
	printf '%s' "$2" | docker secret create --label "${SHA_LABEL}=${s}" "$1" - >/dev/null
}

# state_config <docker-name> -> "STATE LIVE_SHA REPO_SHA"
state_config() {
	local repo live tmp
	tmp=$(mktemp)
	if ! render_config "$1" > "${tmp}" 2>/dev/null; then
		rm -f "${tmp}"
		live="-"
		if config_exists "$1"; then live=$(live_config_sha "$1"); fi
		echo "SKIPPED ${live} -"
		return 0
	fi
	repo=$(sha < "${tmp}")
	rm -f "${tmp}"
	if ! config_exists "$1"; then
		echo "MISSING - ${repo}"
		return 0
	fi
	live=$(live_config_sha "$1")
	if [[ "${live}" == "${repo}" ]]; then
		echo "OK ${live} ${repo}"
	else
		echo "CHANGED ${live} ${repo}"
	fi
}

# state_secret <docker-name> -> "STATE LIVE_SHA REPO_SHA"
state_secret() {
	local v repo live
	v=$(secret_var "$1")
	if ! secret_exists "$1"; then
		if is_explicit "${v}" && [[ -n "${!v:-}" ]]; then
			repo=$(printf '%s' "${!v}" | sha)
			echo "MISSING - ${repo}"
		else
			echo "MISSING - -"
		fi
		return 0
	fi
	live=$(live_secret_sha "$1")
	[[ "${live}" == "<no value>" ]] && live=""
	if ! is_explicit "${v}" || [[ -z "${!v:-}" ]]; then
		echo "SKIPPED ${live:--} -"
		return 0
	fi
	repo=$(printf '%s' "${!v}" | sha)
	if [[ -z "${live}" ]]; then
		echo "UNKNOWN - ${repo}"
	elif [[ "${live}" == "${repo}" ]]; then
		echo "OK ${live} ${repo}"
	else
		echo "CHANGED ${live} ${repo}"
	fi
}

# ---------- subcommands ----------

cmd_create() {
	local n tmp
	local -a names
	mapfile -t names < <(config_names)
	# Fail before creating anything if a source is missing or cannot render.
	for n in "${names[@]}"; do
		if ! config_exists "${n}"; then render_config "${n}" > /dev/null; fi
	done
	for n in "${names[@]}"; do
		if config_exists "${n}"; then
			echo "Already exists: ${n}"
			continue
		fi
		tmp=$(mktemp)
		render_config "${n}" > "${tmp}"
		create_config "${n}" "${tmp}"
		rm -f "${tmp}"
		echo "Created: ${n}"
	done
}

cmd_secrets_create() {
	local n val
	local -a names
	mapfile -t names < <(secret_names)
	for n in "${names[@]}"; do
		if secret_exists "${n}"; then
			echo "Already exists: ${n}"
			continue
		fi
		val=$(secret_value "${n}")
		create_secret "${n}" "${val}"
		echo "Created: ${n}"
	done
}

# cmd_check configs|secrets — OK/MISSING per object, exit 1 if any missing.
cmd_check() {
	local n missing=0 exists=config_exists
	local -a names
	if [[ "$1" == "secrets" ]]; then
		mapfile -t names < <(secret_names)
		exists=secret_exists
	else
		mapfile -t names < <(config_names)
	fi
	for n in "${names[@]}"; do
		if "${exists}" "${n}"; then
			echo "OK: ${n}"
		else
			echo "MISSING: ${n}"
			missing=1
		fi
	done
	return "${missing}"
}

cmd_status() {
	local n st live repo out
	local -a names
	printf '%-40s %-8s %-8s %-14s %-14s\n' NAME KIND STATE LIVE_SHA REPO_SHA
	mapfile -t names < <(config_names)
	for n in "${names[@]}"; do
		out=$(state_config "${n}")
		read -r st live repo <<< "${out}"
		printf '%-40s %-8s %-8s %-14s %-14s\n' "${n}" config "${st}" "${live:0:12}" "${repo:0:12}"
	done
	mapfile -t names < <(secret_names)
	for n in "${names[@]}"; do
		out=$(state_secret "${n}")
		read -r st live repo <<< "${out}"
		printf '%-40s %-8s %-8s %-14s %-14s\n' "${n}" secret "${st}" "${live:0:12}" "${repo:0:12}"
	done
}

main() {
	local cmd=${1:-}
	shift || true
	case "${cmd}" in
		render|create|status) check_values ;;
		*) ;;
	esac
	case "${cmd}" in
		render)         render_config "${1:?usage: configs.sh render <name>}" ;;
		create)         cmd_create ;;
		secrets-create) cmd_secrets_create ;;
		check)          cmd_check configs ;;
		secrets-check)  cmd_check secrets ;;
		status)         cmd_status ;;
		*) echo "Usage: $0 {render <name>|create|secrets-create|check|secrets-check|status}" >&2; exit 2 ;;
	esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
