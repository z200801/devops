#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# db-cmd.sh — run SQL as root against the stack's db task.
# Usage: STACK_NAME=<stack> SQL='<statements>' [DB=<database>] bash scripts/db-cmd.sh   (make db-cmd)
#
# The client runs in its own container (see db-common.sh) and connects to
# 127.0.0.1:3306 as root@'%'. Password: MARIADB_ROOT_PASSWORD if given, else
# the task's /run/secrets/root_password; passed via the environment only.
# Env: STACK_NAME, SQL, DB, SERVICE (default db), CLIENT_MEMORY (default 256m).
set -euo pipefail
shopt -s inherit_errexit

# shellcheck source=db-common.sh
source "${BASH_SOURCE[0]%/*}/db-common.sh"

[[ -n "${SQL:-}" ]] || die "SQL= required, e.g. make db-cmd SQL='SHOW DATABASES'"

db_target
root_password

args=(mariadb --host=127.0.0.1 --port=3306 --user=root --skip-ssl-verify-server-cert)
if [[ -n "${DB:-}" ]]; then args+=("--database=${DB}"); fi
args+=(--execute="${SQL}")

client "${CLIENT_MEMORY:-256m}" "${args[@]}" < /dev/null
