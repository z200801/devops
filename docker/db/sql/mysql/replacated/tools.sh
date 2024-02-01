#!/bin/bash

_env="dev"

_n_app="mysql"
_n_space="${_env}-${_n_app}"

_docker_service_search_="MySQL init process done. Ready for start up."
_docker_service_search_1line="Server socket created on IP:"
_docker_service_search_2line="mysqld: ready for connections"
function _usage(){
  echo "
Usage: ${0} [command]
[command]
  install - install Helm chart
  dry-run - only dry-run
  upgrade - upgrade Helm chart
  remove  - remove Helm chart from K8s
  list    - list Helm chart in namespace [${_n_space}]
  restart   - restart
  reinstall - remove and install
  exec [cmd]   - docker exec [cmd]
  stats     - docker stats for services
  "
}

function __docker_c_get_env(){
 _compose_file=$(ls *|grep -E "docker-compose.ya?ml") 
 if [ -z "${_compose_file}" ]; then return 1; fi

 _container_name=$(grep -Po "container_name\:\s+\K\S+" "${_compose_file}")
 _lib_dir=$(grep -Po "\S+(?=\:\/var\/lib\/mysql)" "${_compose_file}") #"
}

function __docker_c_install(){
 _sets="${1}" # such as --dry-run
 __docker_c_get_env
  if ! docker container ps -a|grep "${_container_name}"; then
   docker compose up -d ${_sets}; fi
 _d_svc=$(docker-compose ps --services)
 echo "Docker. Wait for Up services"
 for i in ${_d_svc}; do
    echo "Wait for up service [${i}]"
    __docker_wait_service "${i}"
 done
 for i in ${_d_svc}; do
  if [ -e "init_db-${i}.sh" ]; then
    echo "Copy to container [${i}] file [init_db-${i}.sh]"
    docker compose cp "init_db-${i}.sh" "${i}":/tmp
    echo "Exec in container [${i}] file [init_db-${i}.sh]"
    docker compose exec "${i}" /bin/bash "/tmp/init_db-${i}.sh"
  fi
 done
}

function __docker_c_stop(){
 if [[ "$(docker compose ls -q)" =~ ${PWD##*/} ]]; then
  docker-compose down
 fi
}

function __docker_c_rm_all(){
 if ! __docker_c_get_env; then return 1; fi
 __docker_c_stop
 # check if ${_lib_dir} contain mysql directory
 for i in ${_lib_dir}; do
  if [ -d "${i}"/mysql ]; then sudo rm -rf "${i}"/*; fi
 done
 
 _docker_volumes=$(docker volume ls -q|grep -Po "${PWD##*/}\S+") #"
 for i in ${_docker_volumes}; do docker volume rm -f "${i}"; done

 if docker container ps -a|grep "${_container_name}"; then
  docker container rm "${_container_name}"; fi
}

function __docker_exec(){
  shift
  _exec_cmd="${@}"
  echo "exec command: [${_exec_cmd}]"
  docker compose exec -it "${PWD##*/}" ${_exec_cmd}
}

function __docker_exec_mysql(){
  shift
  _exec_cmd="${@}"
  # echo "exec command: [${_exec_cmd}]"
  # docker compose exec -it "${PWD##*/}" ${_exec_cmd}
  docker compose exec -it "${PWD##*/}" /bin/bash -c 'mysql -h localhost -uroot -p${MYSQL_ROOT_PASSWORD}'
}

## Functions for wait when mysql services is up
function __docker_is_service_up(){
  _cont_name_re="${1}"
  _cont_master=$(docker compose ps --status running|grep -Po "\S+${_cont_name_re}")
  docker compose logs 2>/dev/null| \
    grep -E "${_cont_master}.*${_docker_service_search_}"
}

function __docker_wait_service () {
  _timeout=30
  _seconds=0
  _cont_name_for_wait="${1}"
  while [ ${_seconds} -lt ${_timeout} ]; do
   if __docker_is_service_up "${_cont_name_for_wait}"; then return 0; fi
   _seconds=$(( _seconds + 1 ))
   sleep 1
  done
  return 2
}


#################
case "${1}" in
 "install" ) __docker_c_install;;
 "dry-run" ) __docker_c_install "--dry-run";;
 "upgrade" ) :;;
 "remove"  ) __docker_c_rm_all;;
 "list"    ) docker compose ls; docker-compose ps --services;;
 "restart" ) docker compose restart;;
 "reinstall" ) __docker_c_rm_all && __docker_c_install;;
 "exec"    ) __docker_exec "${@}";;
 "mysql"   ) __docker_exec_mysql "${@}";;
 "stats"   ) docker stats $(docker-compose ps -q);;
 *         ) _usage;;
esac
