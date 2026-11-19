#!/usr/bin/env bash
# stack-health.sh — is the stack healthy *now*?
# Usage: STACK_NAME=<stack> bash scripts/stack-health.sh      (make stack-health)
#
# Fails when a service runs fewer tasks than desired (replicas "0/1"), a task
# that should be running is not Running, or a running container's healthcheck
# is not "healthy". Task history (Shutdown after updates / reloads) is ignored.
set -euo pipefail
shopt -s inherit_errexit

STACK=${STACK_NAME:?STACK_NAME required}
readonly STACK

services=$(docker stack services "${STACK}" --format '{{.Name}} {{.Replicas}}' 2>/dev/null) || services=""
[[ -n "${services}" ]] || { echo "FAIL: stack '${STACK}' is not deployed" >&2; exit 1; }

failed=0
while read -r name replicas _; do
	running=${replicas%%/*}
	desired=${replicas#*/}
	if [[ "${running}" != "${desired}" ]]; then
		echo "NOT CONVERGED: ${name} ${running}/${desired}"
		failed=1
	fi
done <<< "${services}"

if ! tasks=$(docker stack ps "${STACK}" --filter desired-state=running \
	--format '{{.Name}}|{{.CurrentState}}|{{.Error}}'); then
	echo "FAIL: cannot list tasks of '${STACK}'" >&2
	exit 1
fi
bad=$(grep -v '|Running ' <<< "${tasks}" || true)
if [[ -n "${bad}" ]]; then
	echo "TASKS NOT RUNNING:"
	while IFS='|' read -r n st err; do
		printf '  %-50s %-30s %s\n' "${n}" "${st}" "${err}"
	done <<< "${bad}"
	failed=1
fi

mapfile -t cids < <(docker ps -q -f "label=com.docker.stack.namespace=${STACK}")
for c in "${cids[@]}"; do
	info=$(docker inspect -f '{{.Name}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${c}")
	read -r cname health <<< "${info}"
	case "${health}" in
		healthy|none) ;;
		*) echo "NOT HEALTHY: ${cname#/} ${health}"; failed=1 ;;
	esac
done

if (( failed == 0 )); then
	count=$(wc -l <<< "${services}")
	echo "OK: all services converged and healthy (${count} services)"
fi
exit "${failed}"
