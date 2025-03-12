#!/bin/bash
#
_pr_name="keys_tracker"
_db_name="db_keys"

if [ -n "${1}" ]; then _pr_name="${1}"; _bu_fl="${2}"; fi

if ! docker compose ls -q --filter name=^${_pr_name}$; then
 echo "Error. Docker compose project [${_pr_name}] not found. Exit"
 exit 1
fi

#
if [ -z "${_bu_fl}" ] || [ ! -r "${_bu_fl}" ]; then echo "Error read backup file [${_bu_fl}]. Exit"; exit 1; fi

echo "Restore backup file [${_pr_fl}] to docker compose project [${_pr_name}]"

docker compose \
  -p ${_pr_name} \
  exec -Tit \
  backend sh -c 'PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST}  -U ${DB_USER} -d ${DB_NAME}' < "${_bu_fl}"
