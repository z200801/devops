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
  if [ -e ".env" ]; then for i in $(cat .env); do export ${i}; done; fi
  for i in *.{yaml,yml}; do
   if [[ ${i} =~ "configmap-val" ]]; then envsubst < "${i}" | kubectl apply -f -
   else
    kubectl apply -f ${i}
   fi
  done
}

function __k8s_remove(){
  _n_space=$(cat $(ls *.yaml *.yml 2>/dev/null|grep namespace)|grep -Po "name\:\x20+\K\S+"|uniq)
  kubectl delete namespace "${_n_space}"
  kubectl delete persistentvolumes mysql-pv  

}
##############

__select "${1}"
