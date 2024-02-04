#!/bin/bash

function __usage(){
  echo "
Usage: ${0} [command]
[command]
  install - install in K8s
  dry-run - only dry-run
  remove  - remove from K8s
  reinstall - remove and install
  "
}

function __select(){
 case "${1}" in
    "install" ) __k8s_install;;
    "dry-run" ) __k8s_install "--dry-run";;
    "remove"  ) __k8s_remove;;
    "reinstall" ) __k8s_remove && __k8s_install;;
    * ) __usage;;
    esac
}

function __k8s_install(){
  local _params=""
  if [ -n "${1}" ]; then _params="${1}"; fi
  if [ -e ".env" ]; then 
    for i in $(cat .env); do export ${i}; done
    for i in *.{yaml,yml}; do
     if [[ ${i} =~ "configmap" ]]; then envsubst < "${i}" | kubectl apply -f -
     else
      kubectl apply ${_params} -f ${i}
     fi
    done
  else
    kubectl apply ${_params} -f .
  fi
}

function __k8s_remove(){
  _n_space=$(cat $(ls *.yaml *.yml 2>/dev/null|grep namespace)|grep -Po "name\:\x20+\K\S+"|uniq)
  _pv=$(kubectl -n ${_n_space} get persistentvolumes -o name)
  _pv="${_pv##*/}"
  kubectl delete namespace "${_n_space}"
  if [ -n "${_pv}" ]; then kubectl delete persistentvolumes "${_pv}"; fi
}
##############

__select "${1}"
