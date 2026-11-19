#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# cleanup.sh — list or remove a removed stack's leftovers: external configs,
# secrets and the data volume. Each kind only with its flag; no flag = list.
# Usage: bash scripts/cleanup.sh       (make docker-cleanup)
#
#   CONFIGS=1  configs from CONFIG_REGISTRY + <name>__<digits> reload temps
#   SECRETS=1  secrets from SECRET_REGISTRY + temps
#   VOLUMES=1  the data volume DB_VOLUME — test stacks only (STACK_NAME and
#              DB_VOLUME must start with mariadb-test); never on production
#   CONFIRM=yes  required to remove anything (no interactive prompt)
# Flags accept 1 / y / yes / true; empty = off; anything else is an error.
#
# Exact names only — Docker's name= filter is a prefix match and could hit
# another stack. Refuses while the stack still has services.
set -euo pipefail
shopt -s inherit_errexit

# shellcheck source=configs.sh
source "${BASH_SOURCE[0]%/*}/configs.sh"

STACK=${STACK_NAME:?STACK_NAME required}
readonly STACK TEST_PREFIX="mariadb-test"

# on <FLAG> — 0 if the flag is enabled; exits on an unrecognised value so a
# typo never silently does nothing (or something else).
on() {
	local v=${!1:-}
	case "${v,,}" in
		"") return 1 ;;
		1|y|yes|true) return 0 ;;
		0|n|no|false) return 1 ;;
		*) echo "FAIL: $1='${v}' — use $1=1" >&2; exit 2 ;;
	esac
}
for f in CONFIGS SECRETS VOLUMES; do on "${f}" || true; done

# existing <kind> <registry names...> -> names that exist, plus their temps
existing() {
	local kind=$1 all n
	shift
	all=$(docker "${kind}" ls --format '{{.Name}}') || return 1
	for n in "$@"; do
		grep -xF -- "${n}" <<< "${all}" || true
		grep -xE -- "${n}__[0-9]+" <<< "${all}" || true
	done
}

mapfile -t cfg_names < <(config_names)
mapfile -t sec_names < <(secret_names)
mapfile -t configs < <(existing config "${cfg_names[@]}")
mapfile -t secrets < <(existing secret "${sec_names[@]}")
volumes=()
if [[ -n "${DB_VOLUME:-}" ]] && docker volume inspect "${DB_VOLUME}" >/dev/null 2>&1; then
	volumes=("${DB_VOLUME}")
fi

show() {  # show <title> <flag> <names...>
	local title=$1 flag=$2
	shift 2
	if (( $# == 0 )); then
		printf '%-8s none\n' "${title}"
		return 0
	fi
	printf '%-8s %d (%s=1)\n' "${title}" "$#" "${flag}"
	printf '           %s\n' "$@"
}

node=$(docker info --format '{{.Name}}')
echo "Leftovers of stack '${STACK}' on node ${node}:"
show configs CONFIGS "${configs[@]}"
show secrets SECRETS "${secrets[@]}"
show volumes VOLUMES "${volumes[@]}"

if ! on CONFIGS && ! on SECRETS && ! on VOLUMES; then
	echo "Nothing removed. Select with CONFIGS=1 SECRETS=1 VOLUMES=1, plus CONFIRM=yes."
	exit 0
fi

if on VOLUMES && { [[ "${STACK}" != "${TEST_PREFIX}"* ]] || [[ "${DB_VOLUME:-}" != "${TEST_PREFIX}"* ]]; }; then
	echo "FAIL: VOLUMES=1 only for test stacks (STACK_NAME and DB_VOLUME starting with ${TEST_PREFIX})" >&2
	exit 1
fi

stack_services=$(docker stack services "${STACK}" -q 2>/dev/null) || stack_services=""
if [[ -n "${stack_services}" ]]; then
	echo "FAIL: stack '${STACK}' still has services — run: make stack-rm" >&2
	exit 1
fi

selected=()
if on CONFIGS; then for n in "${configs[@]}"; do selected+=("config ${n}"); done; fi
if on SECRETS; then for n in "${secrets[@]}"; do selected+=("secret ${n}"); done; fi
if on VOLUMES; then for n in "${volumes[@]}"; do selected+=("volume ${n}"); done; fi

if (( ${#selected[@]} == 0 )); then
	echo "Nothing to remove for the selected kinds."
	exit 0
fi

echo "Selected ${#selected[@]} object(s):"
printf '  %s\n' "${selected[@]}"
if [[ "${CONFIRM:-}" != yes ]]; then
	echo "FAIL: add CONFIRM=yes to remove them (volume data is lost permanently)" >&2
	exit 1
fi

failed=0
for s in "${selected[@]}"; do
	read -r kind name <<< "${s}"
	if docker "${kind}" rm "${name}" >/dev/null 2>&1; then
		echo "Removed: ${kind} ${name}"
	else
		echo "FAIL: cannot remove ${kind} ${name}" >&2
		failed=1
	fi
done
exit "${failed}"
