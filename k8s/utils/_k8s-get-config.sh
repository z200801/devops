#!/bin/bash
# Script to get/create K8s config for users
#
# Author: z200801@gmail.com + Claude Antropic
# Date: 2025-01-25
# version: 1.0
# Description: Script to get/create K8s config for users
#
# Dependencies: kubectl, jq
#
# Usage: ./_k8s-get-config.sh [COMMANDS]
# Example: ./_k8s-get-config.sh --create --user admin1 --role admin
#

CLUSTER_NAME="production"
API_SERVER="https://127.0.0.1:6443"
EXTENDED_PRG="jq"

function _chk_extended_prg() {
  local _error=0
  for i in ${EXTENDED_PRG}; do
    if ! command -v ${i} &>/dev/null; then
      echo "${i} - not installed."
      _error=1
    fi
  done
  if [ ${_error} -eq 1 ]; then return 1; fi
}

function check_k8s_api() {
  kubectl cluster-info &>/dev/null || {
    echo "Cannot access Kubernetes API"
    return 1
  }
}

function get_k8s_api_address() {
  local API_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
  # API_SERVER=$(echo $API_URL | sed 's|https://||' | cut -d':' -f1)
  API_SERVER="${API_URL}"
  echo "Detected K8s API server: ${API_SERVER}"
}

function get_k8s_url() {
  local K8S_IP=$(ss -tunl | grep -Po "\S+(?=:6443)")
  if [ "${K8S_IP}" = "*" ]; then
    K8S_IP=$(ip -br a sh $(ip r sh default | grep -Po "\S+\s+\S+\s+\S+\s+\S+\s+\K\S+") | grep -Po "\S+\s+\S+\s+\K\S+(?=\/)")
  fi
  if [ -z "${K8S_IP}" ]; then
    echo "Error get k8s ip"
    return 1
  fi
  API_SERVER="https://${K8S_IP}:6443"
  echo "K8s API: ${API_SERVER}"
}

function get_k8s_cluster_name() {
  local CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
  [ -z "${CLUSTER_NAME}" ] && {
    echo "Error getting cluster name"
    return 1
  }
  echo ${CLUSTER_NAME}
}

function check_sa_exists() {
  local SA_NAME=$1
  kubectl get sa ${SA_NAME} -n kube-system &>/dev/null
  return $?
}

function create_user() {
  local USER=$1
  local ROLE=$2
  local CONFIG="${USER}-kubeconfig"

  if ! check_sa_exists ${USER}; then
    kubectl create serviceaccount ${USER} -n kube-system

    case "$ROLE" in
    "admin")
      kubectl create clusterrolebinding ${USER}-binding \
        --clusterrole=cluster-admin \
        --serviceaccount=kube-system:${USER}
      ;;
    "readonly")
      create_nodes_viewer_role
      kubectl create clusterrolebinding ${USER}-binding-view \
        --clusterrole=view \
        --serviceaccount=kube-system:${USER}
      kubectl create clusterrolebinding ${USER}-binding-nodes \
        --clusterrole=nodes-viewer \
        --serviceaccount=kube-system:${USER}
      ;;
    *)
      echo "Invalid role: $ROLE. Use 'admin' or 'readonly'"
      exit 1
      ;;
    esac

    CLUSTER_CA=$(get_cluster_ca)
    USER_TOKEN=$(get_token ${USER})
    generate_kubeconfig ${CONFIG} ${USER} ${USER_TOKEN}
    echo "Created user ${USER} with role ${ROLE}"
  else
    echo "User ${USER} already exists"
  fi
}

function delete_user() {
  local USER=$1
  local CONFIG="${USER}-kubeconfig"

  kubectl delete clusterrolebinding ${USER}-binding 2>/dev/null
  kubectl delete clusterrolebinding ${USER}-binding-view 2>/dev/null
  kubectl delete clusterrolebinding ${USER}-binding-nodes 2>/dev/null
  kubectl delete sa ${USER} -n kube-system 2>/dev/null
  rm -f ${CONFIG}
  echo "User ${USER} deleted"
}

function list_users() {
  echo "Custom K8s Users:"
  echo "----------------"

  local users=$(kubectl get clusterrolebinding -o json | jq -r '.items[] | 
    select(.subjects[]?.namespace == "kube-system" and .subjects[]?.kind == "ServiceAccount" and .subjects[]?.name != null) |
    {user: .subjects[]?.name, role: .roleRef.name} |
    select(.role | test("cluster-admin|view")) |
    "User: \(.user), Role: \(if .role == "cluster-admin" then "admin" else "readonly" end)"' | sort -u)

  if [ -z "$users" ]; then
    echo "No custom users found"
  else
    echo "$users"
  fi
}

function create_nodes_viewer_role() {
  kubectl create clusterrole nodes-viewer --verb=get,list,watch --resource=nodes 2>/dev/null || true
}

function get_cluster_ca() {
  kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
}

function get_token() {
  local SA_NAME=$1
  local SECRET_NAME=$(kubectl -n kube-system get sa ${SA_NAME} -o jsonpath='{.secrets[].name}')

  if [ -z "$SECRET_NAME" ]; then
    kubectl create token ${SA_NAME} -n kube-system
  else
    kubectl -n kube-system get secret ${SECRET_NAME} -o jsonpath='{.data.token}'
  fi
}

function generate_kubeconfig() {
  local CONFIG_FILE=$1
  local USER=$2
  local TOKEN=$3

  cat >${CONFIG_FILE} <<EOF
apiVersion: v1
kind: Config
preferences: {}
clusters:
 - name: ${CLUSTER_NAME}
   cluster:
     server: ${API_SERVER}
     certificate-authority-data: ${CLUSTER_CA}
users:
 - name: ${USER}
   user:
     token: ${TOKEN}
contexts:
 - name: ${CLUSTER_NAME}
   context:
     cluster: ${CLUSTER_NAME}
     user: ${USER}
current-context: ${CLUSTER_NAME}
EOF

  chmod 600 ${CONFIG_FILE}
  echo "Generated ${CONFIG_FILE}"
}

function check_user_exists() {
  local USER=$1
  kubectl get clusterrolebinding -o json | jq -r '.items[] | 
   select(.subjects[]?.namespace == "kube-system" and .subjects[]?.kind == "ServiceAccount") |
   .subjects[]?.name' | grep -q "^${USER}$"
  return $?
}

function create_config_for_user() {
  local USER=$1
  local CONFIG="${USER}-kubeconfig"

  if check_user_exists ${USER}; then
    CLUSTER_CA=$(get_cluster_ca)
    USER_TOKEN=$(get_token ${USER})
    generate_kubeconfig ${CONFIG} ${USER} ${USER_TOKEN}
  else
    echo "User ${USER} does not exist"
    return 1
  fi
}

function usage() {
  cat <<EOF
Usage: $0 [OPTIONS]
Options:
 --create --user <name> --role <admin|readonly>  Create new user with role
 --delete --user <name>                          Delete existing user
 --mkconfig --user <name>                        Generate config for existing user
 --list                                          Show configured users
EOF
}

################################################################
# Main
####

if ! _chk_extended_prg; then
  echo "Exit."
  exit 1
fi
if ! get_k8s_url; then
  echo "Exit"
  exit 1
fi
if ! check_k8s_api; then
  echo "Exit"
  exit 1
fi
if ! CLUSTER_NAME=$(get_k8s_cluster_name); then
  echo "Exit"
  exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  --create)
    CREATE=true
    shift
    ;;
  --delete)
    DELETE=true
    shift
    ;;
  --user)
    USER="$2"
    shift 2
    ;;
  --role)
    ROLE="$2"
    shift 2
    ;;
  --list)
    LIST=true
    shift
    ;;
  --mkconfig)
    MKCONFIG=true
    shift
    ;;
  *)
    echo "Unknown parameter: $1"
    usage
    exit 1
    ;;
  esac
done

# Main execution
if [[ ${CREATE} == true ]]; then
  if [[ -z ${USER} || -z ${ROLE} ]]; then
    echo "Both --user and --role are required with --create"
    exit 1
  fi
  create_user ${USER} ${ROLE}
elif [[ ${DELETE} == true ]]; then
  if [[ -z ${USER} ]]; then
    echo "--user is required with --delete"
    exit 1
  fi
  delete_user ${USER}
elif [[ ${MKCONFIG} == true ]]; then
  if [[ -z ${USER} ]]; then
    echo "--user is required with --mkconfig"
    exit 1
  fi
  create_config_for_user ${USER}
elif [[ ${LIST} == true ]]; then
  list_users
else
  usage
  exit 1
fi
