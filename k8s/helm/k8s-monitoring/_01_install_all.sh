#!/bin/bash

_n_space="k8s-monitoring"

dir_grafana="grafana"

_prometheus_repo="prometheus-community/prometheus"

function _k_create_namespace(){
 if [ -z "${1}" ]; then return 1; fi
 _ns="${1}"
 _get_ns=$(kubectl get namespaces --no-headers "${_ns}" 2>/dev/null)

 if [ -z "${_get_ns}" ]; then kubectl create namespace "${_ns}"; fi
}

function _helm_package(){
 if [ -z "${1}" ]; then return 1; fi
 _dir_4_pkg="${1}"
 if [ ! -d "${_dir_4_pkg}" ] && [ ! -r "${_dir_4_pkg}" ]; then return 1; fi

 helm lint "${_dir_4_pkg}" >/dev/null 2>&1 || { echo "Error Helm lint."; return 1; }
  helm package "${_dir_4_pkg}" |grep -Po "Success.*to:\x20+\K\S+"
}
##########

_k_create_namespace "${_n_space}"

grafana_pkg_file=$(_helm_package "${dir_grafana}")

if [ -z "${grafana_pkg_file}" ]; then
 echo "Error. Helm package dir ${dir_grafana}. Exit."; exit 1; fi

# Install prometheus
helm install --namespace "${_n_space}" prometheus "${_prometheus_repo}"

# install grafana from helm charts
helm install --namespace "${_n_space}" grafana "${grafana_pkg_file}"

# portforwarding
pod_name=$(kubectl -n "${_n_space}" get pods --no-headers |grep -Po "^prometheus-server-\S+")
kubectl wait -n "${_n_space}" --for=condition=ready pod "${pod_name}"
kubectl -n "${_n_space}" port-forward services/grafana 8080:80