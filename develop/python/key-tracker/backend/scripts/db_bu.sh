#!/bin/bash
#
_dt=$(date +%Y%m%d-%H%M)
_dt_year=$(date +%Y)
_dt_month=$(date +%m)
_dt_day=$(date +%d)

_pr_name=${1:-keys_tracker}
_db_name="db_keys"
_main_dir="../../"
_bu_dir="${_main_dir}/bu/${_db_name}/${_dt_year}/${_dt_month}/${_dt_day}"

if ! docker compose ls -q --filter name=^${_pr_name}$; then
 echo "Error. Docker compose project [${_pr_name}] not found. Exit"
 exit 1
fi


echo "Restore backup file [${_pr_fl}] to docker compose project [${_pr_name}]"

#
# Або з Docker
if [ ! -d ${_bu_dir} ]; then mkdir -p ${_bu_dir}; fi
docker compose \
  -p ${_pr_name} \
  exec \
  db sh -c 'PGPASSWORD=user_key_password pg_dump -h localhost -U user_key -d db_keys --clean --no-owner --no-acl' > ${_bu_dir}/${_pr_name}-${_db_name}-${_dt}.sql
