#!/bni/bash

_n_space="stage"

f_values="values-${_n_space}.yaml"
dir1="charts"

helm lint "${dir1}" || { echo "Error. Lint. Exited"; }
pkg_file=$(helm package "${dir1}" 2>/dev/null| grep -Po "Succes.*to:\x20+\K\S+")

if [ -r "${pkg_file}" ] && [ -r "${f_values}" ];  then
 kubectl delete namespace "${_n_space}"
 helm install \
   --create-namespace \
   --namespace="${_n_space}" \
   "${_n_space}" \
   "${pkg_file}" \
   -f "${f_values}"
fi

