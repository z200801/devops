#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# db-counts.sh — exact row count of every table in the application databases,
# one "<db>.<table><TAB><count>" line per table, sorted. Diff two runs to
# prove a migration / restore kept the data.
# Usage: STACK_NAME=<stack> bash scripts/db-counts.sh                 (make db-counts)
#        SOURCE_CONTAINER=<name> ...  — count in a compose container instead
# Env: STACK_NAME, SERVICE, SOURCE_CONTAINER, MARIADB_ROOT_PASSWORD (optional).
set -euo pipefail
shopt -s inherit_errexit

# shellcheck source=db-common.sh
source "${BASH_SOURCE[0]%/*}/db-common.sh"

db_target
root_password

# One UNION ALL statement with a COUNT(*) per base table.
readonly GEN="SET SESSION group_concat_max_len = 100000000;
SELECT GROUP_CONCAT(CONCAT('SELECT ', QUOTE(CONCAT(TABLE_SCHEMA, '.', TABLE_NAME)),
  ', COUNT(*) FROM \`', REPLACE(TABLE_SCHEMA, '\`', '\`\`'), '\`.\`', REPLACE(TABLE_NAME, '\`', '\`\`'), '\`')
  ORDER BY TABLE_SCHEMA, TABLE_NAME SEPARATOR ' UNION ALL ')
FROM information_schema.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
  AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')"

query=$(sql "${GEN}" < /dev/null) || die "cannot list tables"
[[ -n "${query}" && "${query}" != NULL ]] || die "no application tables found"
counts=$(sql "${query}" < /dev/null) || die "counting rows failed"
sort <<< "${counts}"
