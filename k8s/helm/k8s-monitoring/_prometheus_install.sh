#!/bin/bash

_n_space="k8s-monitoring"

#_prometheus_repo="bitnami/kube-prometheus"
#_prometheus_repo="prometheus-community/kube-prometheus-stack"
_prometheus_repo="prometheus-community/prometheus"

function _k_create_namespace(){
 if [ -z "${1}" ]; then return 1; fi
 _ns="${1}"
 _get_ns=$(kubectl get namespaces --no-headers "${_ns}" 2>/dev/null)

 if [ -z "${_get_ns}" ]; then kubectl create namespace "${_ns}"; fi
}


_k_create_namespace "${_n_space}"

# Install prometheus
helm install --namespace "${_n_space}" prometheus "${_prometheus_repo}"
