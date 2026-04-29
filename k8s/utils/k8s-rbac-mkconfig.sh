#!/bin/bash
# Script to get/create K8s config for users
#
# Author: z200801@gmail.com + Claude Anthropic
# Date: 2026-04-29
# Version: 2.1
# Description: Manage K8s ServiceAccount-based user access (RBAC) and kubeconfig generation.
#              Tested on Kubernetes 1.34+.
#
# Dependencies: kubectl, jq, base64
#
# Usage: ./k8s-get-config.sh [COMMANDS]
# Examples:
#   ./k8s-get-config.sh --create   --user alice --role admin
#   ./k8s-get-config.sh --create   --user bob   --role readonly --ttl 24h
#   ./k8s-get-config.sh --create   --user ci    --role admin    --ttl 0
#   ./k8s-get-config.sh --mkconfig --user alice
#   ./k8s-get-config.sh --mkconfig --user bob   --ttl 8h
#   ./k8s-get-config.sh --delete   --user alice
#   ./k8s-get-config.sh --list
#   ./k8s-get-config.sh --list --json

set -o pipefail

# ----- Configuration -----------------------------------------------------------
USERS_NAMESPACE="${K8S_USERS_NS:-kube-users}"
LEGACY_NAMESPACE="kube-system"
EXTENDED_PRG="jq base64 kubectl"

CLUSTER_NAME=""
API_SERVER=""
CLUSTER_CA=""

CREATE=false
DELETE=false
MKCONFIG=false
LIST=false
JSON_OUT=false
TARGET_USER=""
ROLE=""
TTL=""

# ----- Helpers -----------------------------------------------------------------
function _err()  { echo "ERROR: $*" >&2; }
function _warn() { echo "WARN:  $*" >&2; }
function _info() { echo "INFO:  $*"; }

function _chk_extended_prg() {
  local _error=0
  for i in ${EXTENDED_PRG}; do
    if ! command -v "${i}" &>/dev/null; then
      _err "${i} - not installed."
      _error=1
    fi
  done
  [ ${_error} -eq 0 ]
}

function check_k8s_api() {
  kubectl cluster-info &>/dev/null || {
    _err "Cannot access Kubernetes API"
    return 1
  }
}

function get_k8s_api_url() {
  local url
  url=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
  if [ -z "${url}" ]; then
    _err "Cannot detect K8s API server URL from current context"
    return 1
  fi
  printf '%s' "${url}"
}

function get_k8s_cluster_name() {
  local name
  name=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
  if [ -z "${name}" ]; then
    _err "Cannot detect cluster name from current context"
    return 1
  fi
  printf '%s' "${name}"
}

function get_cluster_ca() {
  local ca
  ca=$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
  if [ -n "${ca}" ]; then
    printf '%s' "${ca}"
    return 0
  fi
  local ca_file
  ca_file=$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority}')
  if [ -n "${ca_file}" ] && [ -r "${ca_file}" ]; then
    base64 -w0 < "${ca_file}"
    return 0
  fi
  _err "Cannot obtain cluster CA data"
  return 1
}

function ensure_namespace() {
  local ns=$1
  if ! kubectl get ns "${ns}" &>/dev/null; then
    _info "Creating namespace ${ns}"
    kubectl create namespace "${ns}" >/dev/null
  fi
}

function check_sa_exists() {
  kubectl get sa "$1" -n "$2" &>/dev/null
}

# ----- JWT helpers -------------------------------------------------------------
function _jwt_decode_payload() {
  local token=$1 payload mod
  payload=$(printf '%s' "${token}" | cut -d'.' -f2)
  [ -z "${payload}" ] && return 1
  mod=$(( ${#payload} % 4 ))
  if [ ${mod} -ne 0 ]; then
    payload="${payload}$(printf '%*s' $((4 - mod)) '' | tr ' ' '=')"
  fi
  payload=$(printf '%s' "${payload}" | tr '_-' '/+' | base64 -d 2>/dev/null) || return 1
  [ -z "${payload}" ] && return 1
  printf '%s' "${payload}"
}

function _jwt_exp() {
  local token=$1 payload
  payload=$(_jwt_decode_payload "${token}") || return 1
  printf '%s' "${payload}" | jq -r '.exp // empty'
}

function _fmt_ts() {
  local ts=$1
  date -u -d "@${ts}" '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null
}

function _humanize_remaining() {
  local exp_ts=$1 now diff days hours mins
  now=$(date +%s)
  diff=$(( exp_ts - now ))
  if [ ${diff} -le 0 ]; then
    printf 'expired'
    return 0
  fi
  days=$(( diff / 86400 ))
  hours=$(( (diff % 86400) / 3600 ))
  mins=$(( (diff % 3600) / 60 ))
  if [ ${days} -gt 0 ]; then
    printf 'in %dd%dh' "${days}" "${hours}"
  elif [ ${hours} -gt 0 ]; then
    printf 'in %dh%dm' "${hours}" "${mins}"
  else
    printf 'in %dm' "${mins}"
  fi
}

function _extract_token_from_kubeconfig() {
  local file=$1 user=$2 token
  [ -r "${file}" ] || return 1
  token=$(kubectl --kubeconfig="${file}" config view --raw \
    -o jsonpath="{.users[?(@.name=='${user}')].user.token}" 2>/dev/null)
  [ -z "${token}" ] && return 1
  printf '%s' "${token}"
}

# ----- Roles -------------------------------------------------------------------
function ensure_nodes_viewer_role() {
  if kubectl get clusterrole nodes-viewer &>/dev/null; then
    return 0
  fi
  _info "Creating ClusterRole nodes-viewer"
  kubectl create clusterrole nodes-viewer \
    --verb=get,list,watch \
    --resource=nodes >/dev/null
}

function bind_cluster_role() {
  local binding=$1 role=$2 sa=$3 ns=$4
  kubectl apply -f - >/dev/null <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${binding}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ${role}
subjects:
  - kind: ServiceAccount
    name: ${sa}
    namespace: ${ns}
EOF
}

# ----- Tokens ------------------------------------------------------------------
function create_longlived_secret() {
  local sa=$1 ns=$2
  local secret_name="${sa}-token"
  kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${secret_name}
  namespace: ${ns}
  annotations:
    kubernetes.io/service-account.name: ${sa}
type: kubernetes.io/service-account-token
EOF
  local i token
  for i in 1 2 3 4 5 6 7 8 9 10; do
    token=$(kubectl get secret "${secret_name}" -n "${ns}" -o jsonpath='{.data.token}' 2>/dev/null)
    if [ -n "${token}" ]; then
      printf '%s' "${token}" | base64 -d
      return 0
    fi
    sleep 1
  done
  _err "Timeout waiting for token in secret ${ns}/${secret_name}"
  return 1
}

function get_longlived_token_if_exists() {
  local sa=$1 ns=$2
  local secret_name="${sa}-token"
  local token
  token=$(kubectl get secret "${secret_name}" -n "${ns}" -o jsonpath='{.data.token}' 2>/dev/null) || return 1
  [ -n "${token}" ] || return 1
  printf '%s' "${token}" | base64 -d
}

function _has_longlived_secret() {
  local sa=$1 ns=$2
  kubectl get secret "${sa}-token" -n "${ns}" &>/dev/null
}

function get_short_token() {
  local sa=$1 ns=$2 dur=$3
  local token
  token=$(kubectl create token "${sa}" -n "${ns}" --duration="${dur}") || return 1

  local exp_ts now_ts requested_secs actual_secs
  exp_ts=$(_jwt_exp "${token}")
  now_ts=$(date +%s)
  if [ -n "${exp_ts}" ]; then
    actual_secs=$(( exp_ts - now_ts ))
    requested_secs=$(_duration_to_seconds "${dur}") || requested_secs=0
    if [ "${requested_secs}" -gt 0 ] && [ "${actual_secs}" -lt $(( requested_secs - 60 )) ]; then
      _warn "Requested TTL ${dur} (~${requested_secs}s) was truncated by API server to ~${actual_secs}s."
      _warn "Cluster limit is set via kube-apiserver --service-account-max-token-expiration."
    fi
  fi

  printf '%s' "${token}"
}

function _duration_to_seconds() {
  local d=$1 total=0 num unit rest
  rest="${d}"
  while [ -n "${rest}" ]; do
    num=$(printf '%s' "${rest}" | grep -oE '^[0-9]+')
    [ -z "${num}" ] && return 1
    rest="${rest#"${num}"}"
    unit=$(printf '%s' "${rest}" | grep -oE '^[smhd]')
    [ -z "${unit}" ] && return 1
    rest="${rest#"${unit}"}"
    case "${unit}" in
      s) total=$(( total + num )) ;;
      m) total=$(( total + num * 60 )) ;;
      h) total=$(( total + num * 3600 )) ;;
      d) total=$(( total + num * 86400 )) ;;
    esac
  done
  printf '%s' "${total}"
}

# ----- Kubeconfig generation ---------------------------------------------------
function generate_kubeconfig() {
  local config_file=$1 user=$2 token=$3
  cat >"${config_file}" <<EOF
apiVersion: v1
kind: Config
preferences: {}
clusters:
  - name: ${CLUSTER_NAME}
    cluster:
      server: ${API_SERVER}
      certificate-authority-data: ${CLUSTER_CA}
users:
  - name: ${user}
    user:
      token: ${token}
contexts:
  - name: ${CLUSTER_NAME}
    context:
      cluster: ${CLUSTER_NAME}
      user: ${user}
current-context: ${CLUSTER_NAME}
EOF
  chmod 600 "${config_file}"
  _info "Generated ${config_file}"
}

# ----- User existence ----------------------------------------------------------
function find_user_namespace() {
  local user=$1
  if check_sa_exists "${user}" "${USERS_NAMESPACE}"; then
    printf '%s' "${USERS_NAMESPACE}"
    return 0
  fi
  if check_sa_exists "${user}" "${LEGACY_NAMESPACE}"; then
    printf '%s' "${LEGACY_NAMESPACE}"
    return 0
  fi
  return 1
}

# ----- Commands ----------------------------------------------------------------
function cmd_create() {
  local user=$1 role=$2 ttl=$3
  local config="${user}-kubeconfig"

  case "${role}" in
    admin|readonly) ;;
    *) _err "Invalid role: ${role}. Use 'admin' or 'readonly'"; return 1 ;;
  esac

  ensure_namespace "${USERS_NAMESPACE}"

  if check_sa_exists "${user}" "${USERS_NAMESPACE}"; then
    _err "User ${user} already exists in ${USERS_NAMESPACE}"
    return 1
  fi
  if check_sa_exists "${user}" "${LEGACY_NAMESPACE}"; then
    _err "User ${user} already exists in legacy namespace ${LEGACY_NAMESPACE}. Delete it first with --delete."
    return 1
  fi

  _info "Creating ServiceAccount ${USERS_NAMESPACE}/${user}"
  kubectl create serviceaccount "${user}" -n "${USERS_NAMESPACE}" >/dev/null

  case "${role}" in
    admin)
      bind_cluster_role "${user}-binding" cluster-admin "${user}" "${USERS_NAMESPACE}"
      ;;
    readonly)
      ensure_nodes_viewer_role
      bind_cluster_role "${user}-binding-view"  view         "${user}" "${USERS_NAMESPACE}"
      bind_cluster_role "${user}-binding-nodes" nodes-viewer "${user}" "${USERS_NAMESPACE}"
      ;;
  esac

  local token
  if [ -z "${ttl}" ] || [ "${ttl}" = "0" ]; then
    _info "Issuing long-lived token via manual Secret"
    token=$(create_longlived_secret "${user}" "${USERS_NAMESPACE}") || return 1
  else
    _info "Issuing short-lived token (TTL=${ttl})"
    token=$(get_short_token "${user}" "${USERS_NAMESPACE}" "${ttl}") || return 1
  fi

  generate_kubeconfig "${config}" "${user}" "${token}"
  _info "Created user ${user} (role=${role}, ns=${USERS_NAMESPACE})"
}

function cmd_delete() {
  local user=$1
  local config="${user}-kubeconfig"

  local ns
  if ! ns=$(find_user_namespace "${user}"); then
    _err "User ${user} not found in ${USERS_NAMESPACE} or ${LEGACY_NAMESPACE}"
    return 1
  fi

  _info "Deleting user ${user} from namespace ${ns}"

  for b in "${user}-binding" "${user}-binding-view" "${user}-binding-nodes"; do
    kubectl delete clusterrolebinding "${b}" --ignore-not-found >/dev/null
  done

  kubectl delete secret "${user}-token" -n "${ns}" --ignore-not-found >/dev/null
  kubectl delete sa "${user}" -n "${ns}" --ignore-not-found >/dev/null
  rm -f "${config}"

  _info "User ${user} deleted"
}

function cmd_mkconfig() {
  local user=$1 ttl=$2
  local config="${user}-kubeconfig"

  local ns
  if ! ns=$(find_user_namespace "${user}"); then
    _err "User ${user} not found in ${USERS_NAMESPACE} or ${LEGACY_NAMESPACE}"
    return 1
  fi

  local token
  if [ -z "${ttl}" ]; then
    if token=$(get_longlived_token_if_exists "${user}" "${ns}"); then
      _info "Using existing long-lived token from secret ${ns}/${user}-token"
    else
      _err "No long-lived secret found for ${user} in ${ns}. Specify --ttl <duration> or --ttl 0 to create a long-lived token."
      return 1
    fi
  elif [ "${ttl}" = "0" ]; then
    _info "Creating new long-lived token via manual Secret"
    token=$(create_longlived_secret "${user}" "${ns}") || return 1
  else
    _info "Issuing short-lived token (TTL=${ttl})"
    token=$(get_short_token "${user}" "${ns}" "${ttl}") || return 1
  fi

  generate_kubeconfig "${config}" "${user}" "${token}"
}

# ----- Listing -----------------------------------------------------------------
# Determine TTL/expiry info for a single (user, ns) entry.
# Sets globals: _RES_TTL, _RES_EXPIRES, _RES_REMAINING, _RES_NOTE, _RES_EXP_TS
function _resolve_token_info() {
  local user=$1 ns=$2
  local config_file="./${user}-kubeconfig"
  _RES_TTL=""
  _RES_EXPIRES=""
  _RES_REMAINING=""
  _RES_NOTE=""
  _RES_EXP_TS=""

  # Variant B: try local kubeconfig first (most accurate)
  local token exp_ts
  if token=$(_extract_token_from_kubeconfig "${config_file}" "${user}"); then
    exp_ts=$(_jwt_exp "${token}")
    if [ -n "${exp_ts}" ]; then
      _RES_TTL="short-lived"
      _RES_EXPIRES=$(_fmt_ts "${exp_ts}")
      _RES_REMAINING=$(_humanize_remaining "${exp_ts}")
      _RES_EXP_TS="${exp_ts}"
      _RES_NOTE="from kubeconfig"
      return 0
    else
      _RES_TTL="never"
      _RES_EXPIRES="-"
      _RES_REMAINING="-"
      _RES_NOTE="from kubeconfig"
      return 0
    fi
  fi

  # Variant A fallback: check long-lived Secret in cluster
  if _has_longlived_secret "${user}" "${ns}"; then
    _RES_TTL="never"
    _RES_EXPIRES="-"
    _RES_REMAINING="-"
    _RES_NOTE="long-lived secret"
    return 0
  fi

  # Nothing locally, no long-lived Secret
  _RES_TTL="short-lived"
  _RES_EXPIRES="unknown"
  _RES_REMAINING="unknown"
  _RES_NOTE="kubeconfig not found"
}

function _collect_users_tsv() {
  kubectl get clusterrolebinding -o json | jq -r --arg uns "${USERS_NAMESPACE}" --arg lns "${LEGACY_NAMESPACE}" '
    .items[]
    | select(.metadata.name | test("-binding(-view|-nodes)?$"))
    | . as $crb
    | (.subjects // [])[]
    | select(.kind == "ServiceAccount")
    | select(.namespace == $uns or .namespace == $lns)
    | "\(.name)\t\(.namespace)\t\($crb.roleRef.name)"
  ' | sort -u
}

function _aggregate_roles() {
  awk -F'\t' '
    {
      key = $1 "\t" $2
      roles[key] = (roles[key] ? roles[key] "," : "") $3
    }
    END {
      for (k in roles) {
        split(k, a, "\t")
        r = roles[k]
        if (r ~ /cluster-admin/)            label = "admin"
        else if (r ~ /view/ && r ~ /nodes/) label = "readonly"
        else                                label = "custom(" r ")"
        print a[1] "\t" a[2] "\t" label
      }
    }
  ' | sort
}

function cmd_list_table() {
  local raw aggregated
  raw=$(_collect_users_tsv)
  if [ -z "${raw}" ]; then
    echo "No custom users found"
    return 0
  fi
  aggregated=$(printf '%s\n' "${raw}" | _aggregate_roles)

  printf '%-20s  %-10s  %-12s  %-12s  %-22s  %-12s  %s\n' \
    "USER" "ROLE" "NS" "TTL" "EXPIRES" "REMAINING" "NOTE"
  printf '%s\n' "----------------------------------------------------------------------------------------------------------------"

  local user ns label legacy_tag
  while IFS=$'\t' read -r user ns label; do
    [ -z "${user}" ] && continue
    _resolve_token_info "${user}" "${ns}"
    legacy_tag=""
    [ "${ns}" = "${LEGACY_NAMESPACE}" ] && legacy_tag=" [legacy]"
    printf '%-20s  %-10s  %-12s  %-12s  %-22s  %-12s  %s%s\n' \
      "${user}" "${label}" "${ns}" "${_RES_TTL}" "${_RES_EXPIRES}" "${_RES_REMAINING}" "${_RES_NOTE}" "${legacy_tag}"
  done <<< "${aggregated}"
}

function cmd_list_json() {
  local raw aggregated
  raw=$(_collect_users_tsv)
  if [ -z "${raw}" ]; then
    echo "[]"
    return 0
  fi
  aggregated=$(printf '%s\n' "${raw}" | _aggregate_roles)

  local user ns label legacy entries=""
  while IFS=$'\t' read -r user ns label; do
    [ -z "${user}" ] && continue
    _resolve_token_info "${user}" "${ns}"
    legacy=false
    [ "${ns}" = "${LEGACY_NAMESPACE}" ] && legacy=true
    local entry
    entry=$(jq -n \
      --arg user "${user}" \
      --arg role "${label}" \
      --arg ns "${ns}" \
      --arg ttl "${_RES_TTL}" \
      --arg expires "${_RES_EXPIRES}" \
      --arg remaining "${_RES_REMAINING}" \
      --arg note "${_RES_NOTE}" \
      --arg exp_ts "${_RES_EXP_TS}" \
      --argjson legacy "${legacy}" \
      '{
        user: $user,
        role: $role,
        namespace: $ns,
        ttl: $ttl,
        expires: (if $expires == "" or $expires == "-" or $expires == "unknown" then null else $expires end),
        expires_unix: (if $exp_ts == "" then null else ($exp_ts | tonumber) end),
        remaining: (if $remaining == "" or $remaining == "-" or $remaining == "unknown" then null else $remaining end),
        note: $note,
        legacy: $legacy
      }')
    if [ -z "${entries}" ]; then
      entries="${entry}"
    else
      entries="${entries},${entry}"
    fi
  done <<< "${aggregated}"

  printf '[%s]' "${entries}" | jq '.'
}

function cmd_list() {
  if [ "${JSON_OUT}" = true ]; then
    cmd_list_json
  else
    cmd_list_table
  fi
}

# ----- Usage -------------------------------------------------------------------
function usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --create   --user <name> --role <admin|readonly> [--ttl <duration>]
                                      Create new user with role.
                                      --ttl omitted or 0 -> long-lived token.
                                      --ttl <Go duration: 1h, 24h, 30m> -> short-lived.

  --delete   --user <name>            Delete user (SA, bindings, secret, kubeconfig).
                                      Searches in ${USERS_NAMESPACE} and ${LEGACY_NAMESPACE}.

  --mkconfig --user <name> [--ttl <duration>]
                                      Regenerate kubeconfig for existing user.
                                      Without --ttl: reuses existing long-lived secret.
                                      With --ttl 0: creates new long-lived secret.
                                      With --ttl <duration>: issues short-lived token.

  --list [--json]                     Show all custom users.
                                      Default: human-readable table with TTL/expiry.
                                      --json: machine-readable JSON output.

Environment:
  K8S_USERS_NS   Override users namespace (default: kube-users)

Notes:
  --list reads local kubeconfig files (./{user}-kubeconfig) to determine
  expiry of short-lived tokens. If no kubeconfig is present in CWD, the
  expiry is reported as 'unknown' for short-lived tokens.
EOF
}

# ----- Main --------------------------------------------------------------------
function main() {
  if ! _chk_extended_prg; then
    exit 1
  fi
  if ! check_k8s_api; then
    exit 1
  fi

  CLUSTER_NAME=$(get_k8s_cluster_name) || exit 1
  API_SERVER=$(get_k8s_api_url)        || exit 1
  CLUSTER_CA=$(get_cluster_ca)         || exit 1

  _info "Cluster: ${CLUSTER_NAME}  API: ${API_SERVER}"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --create)   CREATE=true;   shift ;;
      --delete)   DELETE=true;   shift ;;
      --mkconfig) MKCONFIG=true; shift ;;
      --list)     LIST=true;     shift ;;
      --json)     JSON_OUT=true; shift ;;
      --user)     TARGET_USER="$2"; shift 2 ;;
      --role)     ROLE="$2";        shift 2 ;;
      --ttl)      TTL="$2";         shift 2 ;;
      -h|--help)  usage; exit 0 ;;
      *) _err "Unknown parameter: $1"; usage; exit 1 ;;
    esac
  done

  if [[ ${CREATE} == true ]]; then
    [[ -z ${TARGET_USER} || -z ${ROLE} ]] && { _err "Both --user and --role are required with --create"; exit 1; }
    cmd_create "${TARGET_USER}" "${ROLE}" "${TTL}"
  elif [[ ${DELETE} == true ]]; then
    [[ -z ${TARGET_USER} ]] && { _err "--user is required with --delete"; exit 1; }
    cmd_delete "${TARGET_USER}"
  elif [[ ${MKCONFIG} == true ]]; then
    [[ -z ${TARGET_USER} ]] && { _err "--user is required with --mkconfig"; exit 1; }
    cmd_mkconfig "${TARGET_USER}" "${TTL}"
  elif [[ ${LIST} == true ]]; then
    cmd_list
  else
    usage
    exit 1
  fi
}

main "$@"
