#!/bin/bash

dir1="charts"

_n_space="dev"
app_name="nginx"

function _k_create_namespace(){
 if [ -z "${1}" ]; then return 1; fi

 _ns="${1}"
 _get_ns=$(kubectl get namespaces "${_ns}" --no-headers=true)

 if [ -n "${_get_ns}" ]; then return 0; fi

 kubctl create namespace "${_ns}" || return 1
}

function _k_wait_pods_up(){
 _selector=$(kubectl -n "${_n_space}" get deployments.apps -o wide --no-headers|awk '{print $8}')
 kubectl wait -n "${_n_space}" --for=condition=ready pod -l "${_selector}"
}

helm lint "${dir1}" && \
 helm install \
  -f values-"${_n_space}".yaml  \
  --create-namespace \
  --namespace="${_n_space}" \
  "${app_name}" "${dir1}" && \
    _k_wait_pods_up && \
    _svc=$(kubectl -n "${_n_space}" get svc --no-headers=true -o name) && \
    kubectl -n "${_n_space}" port-forward services/"${_svc#*/}" 40080:80
helm -n "${_n_space}" delete "${app_name}"

