#!/bin/bash
# Script to get/create K8s config for users
#
# Author: z200801@gmail.com + Claude Anthropic
# Date: 2026-04-29
# Version: 3.0
# Description: Manage K8s ServiceAccount-based user access (RBAC) and kubeconfig generation.
#              Supports cluster-scoped and namespace-scoped roles, custom ClusterRoles,
#              and token rotation. Tested on Kubernetes 1.34+.
#
# Dependencies: kubectl, jq, base64
#
# Usage: ./k8s-get-config.sh [OPTIONS]
# See --help for full reference.

set -o pipefail

# ----- Configuration -----------------------------------------------------------
USERS_NAMESPACE="${K8S_USERS_NS:-kube-users}"
LEGACY_NAMESPACE="kube-system"
EXTENDED_PRG="jq base64 kubectl"
DNS1123_MAX=63

CLUSTER_NAME=""
API_SERVER=""
CLUSTER_CA=""

CMD_CREATE=false
CMD_DELETE=false
CMD_UPDATE=false
CMD_MKCONFIG=false
CMD_LIST=false
CMD_ROTATE=false
JSON_OUT=false
ROTATE_ALL=false
ASSUME_YES=false
TARGET_USER=""
ROLE=""
CLUSTER_ROLE=""
NAMESPACE=""
TTL=""

# Default TTL when rotation cannot determine original TTL from kubeconfig
ROTATE_DEFAULT_TTL="24h"

# ----- Helpers -----------------------------------------------------------------
function _err()  { echo "ERROR: $*" >&2; }
function _warn() { echo "WARN:  $*" >&2; }
function _info() { echo "INFO:  $*" >&2; }

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

function check_namespace_exists() {
  kubectl get ns "$1" &>/dev/null
}

function check_sa_exists() {
  kubectl get sa "$1" -n "$2" &>/dev/null
}

function check_clusterrole_exists() {
  kubectl get clusterrole "$1" &>/dev/null
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

function _jwt_iat() {
  local token=$1 payload
  payload=$(_jwt_decode_payload "${token}") || return 1
  printf '%s' "${payload}" | jq -r '.iat // empty'
}

# Detect original TTL of an existing token by inspecting local kubeconfig.
# Returns to stdout one of:
#   - "long-lived" if JWT has no exp claim
#   - Go duration like "24h0m0s" if exp - iat is meaningful
#   - empty string + return 1 if unknown
function _detect_original_ttl_from_kubeconfig() {
  local user=$1
  local config_file="./${user}-kubeconfig"
  local token exp iat secs

  token=$(_extract_token_from_kubeconfig "${config_file}" "${user}") || return 1
  exp=$(_jwt_exp "${token}")
  if [ -z "${exp}" ]; then
    printf 'long-lived'
    return 0
  fi
  iat=$(_jwt_iat "${token}")
  if [ -n "${iat}" ]; then
    secs=$(( exp - iat ))
  else
    # No iat -> approximate from now (degrades, but works for fresh tokens)
    secs=$(( exp - $(date +%s) ))
  fi
  if [ "${secs}" -le 0 ]; then
    return 1
  fi
  # Format as Go duration that kubectl create token accepts
  printf '%ds' "${secs}"
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

# ----- Naming ------------------------------------------------------------------
# Cluster-scope binding names
function _crb_admin()    { printf '%s-binding'       "$1"; }
function _crb_view()     { printf '%s-binding-view'  "$1"; }
function _crb_nodes()    { printf '%s-binding-nodes' "$1"; }
function _crb_custom()   { printf '%s-binding-custom-%s' "$1" "$2"; }

# Namespace-scope binding names
function _rb_edit()      { printf '%s-rb-edit'   "$1"; }
function _rb_view()      { printf '%s-rb-view'   "$1"; }
function _rb_custom()    { printf '%s-rb-custom-%s' "$1" "$2"; }

function _validate_name_length() {
  local name=$1 ctx=$2
  if [ ${#name} -gt ${DNS1123_MAX} ]; then
    _err "Generated name '${name}' exceeds ${DNS1123_MAX} chars (${ctx}). Use a shorter user or ClusterRole name."
    return 1
  fi
}

# ----- Built-in roles ----------------------------------------------------------
function ensure_nodes_viewer_role() {
  if kubectl get clusterrole nodes-viewer &>/dev/null; then
    return 0
  fi
  _info "Creating ClusterRole nodes-viewer"
  kubectl create clusterrole nodes-viewer \
    --verb=get,list,watch \
    --resource=nodes >/dev/null
}

# ----- Bindings ----------------------------------------------------------------
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

function bind_namespace_role() {
  local binding=$1 role=$2 sa=$3 sa_ns=$4 target_ns=$5
  kubectl apply -f - >/dev/null <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${binding}
  namespace: ${target_ns}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ${role}
subjects:
  - kind: ServiceAccount
    name: ${sa}
    namespace: ${sa_ns}
EOF
}

# Returns 0 if ANY rolebinding for this user exists in the given namespace.
function _has_any_rb_for_user() {
  local user=$1 ns=$2
  kubectl get rolebinding -n "${ns}" -o json 2>/dev/null | jq -e --arg u "${user}" '
    .items[] | select(.metadata.name | startswith($u + "-rb-")) | .metadata.name
  ' &>/dev/null
}

# Removes ALL existing RoleBindings in target ns that belong to this user.
# Used when "raising" the role (variant B) — single RB per (user, ns).
function _remove_user_rbs_in_ns() {
  local user=$1 ns=$2
  local names
  names=$(kubectl get rolebinding -n "${ns}" -o json 2>/dev/null | jq -r --arg u "${user}" '
    .items[] | select(.metadata.name | startswith($u + "-rb-")) | .metadata.name
  ')
  local n
  while IFS= read -r n; do
    [ -z "${n}" ] && continue
    _info "Removing existing RoleBinding ${ns}/${n}"
    kubectl delete rolebinding "${n}" -n "${ns}" --ignore-not-found >/dev/null
  done <<< "${names}"
}

# Check if a SPECIFIC binding name exists (used to detect duplicate add)
function _rb_exists() {
  local name=$1 ns=$2
  kubectl get rolebinding "${name}" -n "${ns}" &>/dev/null
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

function delete_longlived_secret_if_exists() {
  local sa=$1 ns=$2
  if _has_longlived_secret "${sa}" "${ns}"; then
    _info "Deleting long-lived secret ${ns}/${sa}-token"
    kubectl delete secret "${sa}-token" -n "${ns}" --ignore-not-found >/dev/null
  fi
}

# Rotate a long-lived Secret: delete the existing one and create a fresh one.
# This invalidates the old token. Returns new plaintext token to stdout.
function rotate_longlived_secret() {
  local sa=$1 ns=$2
  delete_longlived_secret_if_exists "${sa}" "${ns}"
  # Wait briefly for delete to propagate before recreate
  local i
  for i in 1 2 3 4 5; do
    if ! _has_longlived_secret "${sa}" "${ns}"; then break; fi
    sleep 1
  done
  create_longlived_secret "${sa}" "${ns}"
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

# Issue token according to TTL semantics; returns plaintext token to stdout.
# If switching strategies (long->short or short->long), cleans up old long-lived Secret.
# update_mode=true means we explicitly close any security gap (delete old long-lived).
function issue_token() {
  local sa=$1 ns=$2 ttl=$3 update_mode=${4:-false}
  local token

  if [ -z "${ttl}" ] || [ "${ttl}" = "0" ]; then
    # Want long-lived
    if _has_longlived_secret "${sa}" "${ns}"; then
      _info "Reusing existing long-lived secret ${ns}/${sa}-token"
      get_longlived_token_if_exists "${sa}" "${ns}" || return 1
    else
      _info "Issuing long-lived token via manual Secret"
      create_longlived_secret "${sa}" "${ns}" || return 1
    fi
    return 0
  fi

  # Want short-lived
  if [ "${update_mode}" = "true" ] && _has_longlived_secret "${sa}" "${ns}"; then
    _warn "Switching from long-lived to short-lived: deleting old Secret to close access"
    delete_longlived_secret_if_exists "${sa}" "${ns}"
  fi
  _info "Issuing short-lived token (TTL=${ttl})"
  token=$(get_short_token "${sa}" "${ns}" "${ttl}") || return 1
  printf '%s' "${token}"
}

# Same but for "fresh" mode (--update --ttl 0 from short -> long).
# We have no old short Secret to remove (short tokens aren't stored).
# Just create the new long-lived Secret.
function issue_token_update() {
  issue_token "$1" "$2" "$3" "true"
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

# ----- Validation --------------------------------------------------------------
# Validates --role / --cluster-role / --namespace combination.
# Sets globals: _EFFECTIVE_ROLE_KIND ("builtin"|"custom"), _EFFECTIVE_ROLE_NAME, _EFFECTIVE_SCOPE ("cluster"|"namespace")
function validate_role_args() {
  local role=$1 cluster_role=$2 namespace=$3

  if [ -n "${role}" ] && [ -n "${cluster_role}" ]; then
    _err "--role and --cluster-role are mutually exclusive"
    return 1
  fi

  if [ -z "${role}" ] && [ -z "${cluster_role}" ]; then
    _err "Either --role or --cluster-role is required"
    return 1
  fi

  if [ -n "${cluster_role}" ]; then
    if ! check_clusterrole_exists "${cluster_role}"; then
      _err "ClusterRole '${cluster_role}' does not exist"
      return 1
    fi
    _EFFECTIVE_ROLE_KIND="custom"
    _EFFECTIVE_ROLE_NAME="${cluster_role}"
    if [ -n "${namespace}" ]; then
      _EFFECTIVE_SCOPE="namespace"
    else
      _EFFECTIVE_SCOPE="cluster"
    fi
    return 0
  fi

  # Built-in role path
  if [ -n "${namespace}" ]; then
    case "${role}" in
      editor|view) ;;
      *)
        _err "With --namespace, --role must be 'editor' or 'view' (got: '${role}'). For cluster-scope use admin/readonly without --namespace."
        return 1
        ;;
    esac
    _EFFECTIVE_SCOPE="namespace"
  else
    case "${role}" in
      admin|readonly) ;;
      *)
        _err "Without --namespace, --role must be 'admin' or 'readonly' (got: '${role}'). For namespace-scope use editor/view with --namespace."
        return 1
        ;;
    esac
    _EFFECTIVE_SCOPE="cluster"
  fi
  _EFFECTIVE_ROLE_KIND="builtin"
  _EFFECTIVE_ROLE_NAME="${role}"
}

# ----- Apply RBAC --------------------------------------------------------------
# Apply role bindings according to validated role args.
# Caller must have run validate_role_args.
# apply_rbac <user> [--replace-ns]
# --replace-ns: for namespace scope, remove existing user-RBs in target ns first (variant B)
function apply_rbac() {
  local user=$1 replace=${2:-}
  local ns="${USERS_NAMESPACE}"

  if [ "${_EFFECTIVE_SCOPE}" = "cluster" ]; then
    if [ "${_EFFECTIVE_ROLE_KIND}" = "builtin" ]; then
      case "${_EFFECTIVE_ROLE_NAME}" in
        admin)
          local b; b=$(_crb_admin "${user}")
          _validate_name_length "${b}" "ClusterRoleBinding" || return 1
          bind_cluster_role "${b}" cluster-admin "${user}" "${ns}"
          ;;
        readonly)
          ensure_nodes_viewer_role
          local bv bn
          bv=$(_crb_view "${user}");  _validate_name_length "${bv}" "ClusterRoleBinding view"  || return 1
          bn=$(_crb_nodes "${user}"); _validate_name_length "${bn}" "ClusterRoleBinding nodes" || return 1
          bind_cluster_role "${bv}" view         "${user}" "${ns}"
          bind_cluster_role "${bn}" nodes-viewer "${user}" "${ns}"
          ;;
      esac
    else
      local bc; bc=$(_crb_custom "${user}" "${_EFFECTIVE_ROLE_NAME}")
      _validate_name_length "${bc}" "ClusterRoleBinding custom" || return 1
      bind_cluster_role "${bc}" "${_EFFECTIVE_ROLE_NAME}" "${user}" "${ns}"
    fi
    return 0
  fi

  # Namespace scope
  local target_ns="${NAMESPACE}"
  if ! check_namespace_exists "${target_ns}"; then
    _err "Target namespace '${target_ns}' does not exist"
    return 1
  fi

  # Determine target binding name
  local target_binding target_role
  if [ "${_EFFECTIVE_ROLE_KIND}" = "builtin" ]; then
    case "${_EFFECTIVE_ROLE_NAME}" in
      editor) target_binding=$(_rb_edit "${user}"); target_role="edit" ;;
      view)   target_binding=$(_rb_view "${user}"); target_role="view" ;;
    esac
  else
    target_binding=$(_rb_custom "${user}" "${_EFFECTIVE_ROLE_NAME}")
    target_role="${_EFFECTIVE_ROLE_NAME}"
  fi
  _validate_name_length "${target_binding}" "RoleBinding" || return 1

  # Duplicate check (rule c): if exact same binding already exists, no-op + warn
  if _rb_exists "${target_binding}" "${target_ns}"; then
    _warn "RoleBinding ${target_ns}/${target_binding} already exists, no changes made"
    return 0
  fi

  # Replace mode (rule b): role raise (view -> editor) — remove all user-RBs in target ns
  if [ "${replace}" = "--replace-ns" ]; then
    if _has_any_rb_for_user "${user}" "${target_ns}"; then
      _info "Replacing existing role for ${user} in ${target_ns}"
      _remove_user_rbs_in_ns "${user}" "${target_ns}"
    fi
  fi

  bind_namespace_role "${target_binding}" "${target_role}" "${user}" "${ns}" "${target_ns}"
  _info "Bound ${user} -> ${target_role} in ${target_ns}"
}

# ----- Commands ----------------------------------------------------------------
function cmd_create() {
  local user=$1
  local config="${user}-kubeconfig"

  validate_role_args "${ROLE}" "${CLUSTER_ROLE}" "${NAMESPACE}" || return 1

  ensure_namespace "${USERS_NAMESPACE}"

  if check_sa_exists "${user}" "${USERS_NAMESPACE}"; then
    _err "User ${user} already exists in ${USERS_NAMESPACE}. Use --update to add namespace access or rotate token."
    return 1
  fi
  if check_sa_exists "${user}" "${LEGACY_NAMESPACE}"; then
    _err "User ${user} already exists in legacy namespace ${LEGACY_NAMESPACE}. Delete it first with --delete."
    return 1
  fi

  _info "Creating ServiceAccount ${USERS_NAMESPACE}/${user}"
  kubectl create serviceaccount "${user}" -n "${USERS_NAMESPACE}" >/dev/null

  apply_rbac "${user}" || {
    _err "RBAC application failed; rolling back SA"
    kubectl delete sa "${user}" -n "${USERS_NAMESPACE}" --ignore-not-found >/dev/null
    return 1
  }

  local token
  token=$(issue_token "${user}" "${USERS_NAMESPACE}" "${TTL}") || return 1
  generate_kubeconfig "${config}" "${user}" "${token}"

  if [ "${_EFFECTIVE_SCOPE}" = "cluster" ]; then
    _info "Created user ${user} (scope=cluster, role=${_EFFECTIVE_ROLE_NAME})"
  else
    _info "Created user ${user} (scope=ns:${NAMESPACE}, role=${_EFFECTIVE_ROLE_NAME})"
  fi
}

function cmd_update() {
  local user=$1

  if ! find_user_namespace "${user}" >/dev/null; then
    _err "User ${user} not found. Use --create first."
    return 1
  fi
  local sa_ns; sa_ns=$(find_user_namespace "${user}")

  local has_role_change=false has_ttl_change=false
  if [ -n "${ROLE}" ] || [ -n "${CLUSTER_ROLE}" ]; then
    has_role_change=true
  fi
  if [ -n "${TTL}" ]; then
    has_ttl_change=true
  fi

  if [ "${has_role_change}" = false ] && [ "${has_ttl_change}" = false ]; then
    _err "--update requires at least one of: --ttl, --role/--cluster-role + --namespace"
    return 1
  fi

  # Role change: must specify --namespace (cluster-scope role changes require recreate)
  if [ "${has_role_change}" = true ]; then
    if [ -z "${NAMESPACE}" ]; then
      _err "Role changes via --update require --namespace. For cluster-scope role changes, use --delete + --create."
      return 1
    fi
    validate_role_args "${ROLE}" "${CLUSTER_ROLE}" "${NAMESPACE}" || return 1
    apply_rbac "${user}" --replace-ns || return 1
  fi

  # TTL change: rotate token, kubeconfig regen
  if [ "${has_ttl_change}" = true ]; then
    local config="${user}-kubeconfig"
    local token
    token=$(issue_token_update "${user}" "${sa_ns}" "${TTL}") || return 1
    generate_kubeconfig "${config}" "${user}" "${token}"
  fi

  _info "Updated user ${user}"
}

function cmd_delete() {
  local user=$1
  local config="${user}-kubeconfig"

  local ns
  if ! ns=$(find_user_namespace "${user}"); then
    _err "User ${user} not found in ${USERS_NAMESPACE} or ${LEGACY_NAMESPACE}"
    return 1
  fi

  # Partial delete: --namespace specified, remove only RBs in that ns
  if [ -n "${NAMESPACE}" ]; then
    if ! check_namespace_exists "${NAMESPACE}"; then
      _err "Target namespace '${NAMESPACE}' does not exist"
      return 1
    fi
    if ! _has_any_rb_for_user "${user}" "${NAMESPACE}"; then
      _err "User ${user} has no RoleBindings in namespace ${NAMESPACE}"
      return 1
    fi
    _info "Removing namespace access for ${user} in ${NAMESPACE}"
    _remove_user_rbs_in_ns "${user}" "${NAMESPACE}"
    _info "User ${user} access to ${NAMESPACE} revoked. SA and other access preserved."
    return 0
  fi

  # Full delete
  _info "Deleting user ${user} from namespace ${ns}"

  # All ClusterRoleBindings (built-in + any custom matching pattern)
  local crbs
  crbs=$(kubectl get clusterrolebinding -o json | jq -r --arg u "${user}" '
    .items[] | select(.metadata.name == ($u + "-binding")
                   or .metadata.name == ($u + "-binding-view")
                   or .metadata.name == ($u + "-binding-nodes")
                   or (.metadata.name | startswith($u + "-binding-custom-")))
    | .metadata.name')
  local cb
  while IFS= read -r cb; do
    [ -z "${cb}" ] && continue
    kubectl delete clusterrolebinding "${cb}" --ignore-not-found >/dev/null
  done <<< "${crbs}"

  # All RoleBindings across all namespaces
  local rbs
  rbs=$(kubectl get rolebinding --all-namespaces -o json | jq -r --arg u "${user}" '
    .items[] | select(.metadata.name | startswith($u + "-rb-"))
    | "\(.metadata.namespace)\t\(.metadata.name)"')
  local rb_ns rb_name
  while IFS=$'\t' read -r rb_ns rb_name; do
    [ -z "${rb_name}" ] && continue
    kubectl delete rolebinding "${rb_name}" -n "${rb_ns}" --ignore-not-found >/dev/null
  done <<< "${rbs}"

  kubectl delete secret "${user}-token" -n "${ns}" --ignore-not-found >/dev/null
  kubectl delete sa "${user}" -n "${ns}" --ignore-not-found >/dev/null
  rm -f "${config}"

  _info "User ${user} deleted"
}

function cmd_mkconfig() {
  local user=$1
  local config="${user}-kubeconfig"

  if [ -n "${TTL}" ]; then
    _err "--mkconfig does not accept --ttl. Use --update --user ${user} --ttl ${TTL} to rotate the token."
    return 1
  fi

  local ns
  if ! ns=$(find_user_namespace "${user}"); then
    _err "User ${user} not found in ${USERS_NAMESPACE} or ${LEGACY_NAMESPACE}"
    return 1
  fi

  local token
  if token=$(get_longlived_token_if_exists "${user}" "${ns}"); then
    _info "Using existing long-lived token from secret ${ns}/${user}-token"
  else
    _err "No long-lived secret found for ${user} in ${ns}. Use --update --ttl 0 (long-lived) or --update --ttl <duration> (short-lived) to issue a new token."
    return 1
  fi

  generate_kubeconfig "${config}" "${user}" "${token}"
}

# ----- Rotation ----------------------------------------------------------------
# Rotate a single user's token. Sets globals _ROT_RESULT ("ok"|"err") and _ROT_MSG.
# explicit_ttl: if non-empty, force this TTL; if "0", force long-lived.
function _rotate_one() {
  local user=$1 explicit_ttl=$2
  _ROT_RESULT="err"
  _ROT_MSG=""

  local sa_ns
  if ! sa_ns=$(find_user_namespace "${user}"); then
    _ROT_MSG="user not found"
    return 1
  fi

  local effective_ttl=""
  if [ -n "${explicit_ttl}" ]; then
    # Caller forced a TTL (including "0" for long-lived)
    effective_ttl="${explicit_ttl}"
  else
    # Detect from local kubeconfig
    local detected
    if detected=$(_detect_original_ttl_from_kubeconfig "${user}"); then
      if [ "${detected}" = "long-lived" ]; then
        effective_ttl="0"
      else
        effective_ttl="${detected}"
      fi
    else
      # No kubeconfig — check if a long-lived Secret exists
      if _has_longlived_secret "${user}" "${sa_ns}"; then
        effective_ttl="0"
      else
        _warn "Cannot determine original TTL for ${user}; using default ${ROTATE_DEFAULT_TTL}"
        effective_ttl="${ROTATE_DEFAULT_TTL}"
      fi
    fi
  fi

  local token config="${user}-kubeconfig"

  if [ "${effective_ttl}" = "0" ]; then
    # Long-lived rotation: delete old Secret, create new one (new token)
    if ! token=$(rotate_longlived_secret "${user}" "${sa_ns}"); then
      _ROT_MSG="failed to rotate long-lived secret"
      return 1
    fi
  else
    # Short-lived: if user currently has long-lived Secret, delete it (close gap)
    if _has_longlived_secret "${user}" "${sa_ns}"; then
      _warn "User ${user} had long-lived Secret; deleting it before issuing short-lived token"
      delete_longlived_secret_if_exists "${user}" "${sa_ns}"
    fi
    if ! token=$(get_short_token "${user}" "${sa_ns}" "${effective_ttl}"); then
      _ROT_MSG="failed to issue short-lived token (TTL=${effective_ttl})"
      return 1
    fi
  fi

  if ! generate_kubeconfig "${config}" "${user}" "${token}"; then
    _ROT_MSG="failed to write kubeconfig"
    return 1
  fi

  _ROT_RESULT="ok"
  if [ "${effective_ttl}" = "0" ]; then
    _ROT_MSG="long-lived"
  else
    _ROT_MSG="ttl=${effective_ttl}"
  fi
  return 0
}

# Build list of rotatable users (SA in USERS_NAMESPACE only — skip legacy).
# Output: TSV "user\tns" lines.
function _list_rotatable_users() {
  kubectl get sa -n "${USERS_NAMESPACE}" -o json 2>/dev/null | jq -r --arg uns "${USERS_NAMESPACE}" '
    .items[] | select(.metadata.name != "default")
    | "\(.metadata.name)\t\($uns)"
  '
}

function _confirm_rotate_all() {
  local users_count=$1
  if [ "${ASSUME_YES}" = "true" ]; then
    return 0
  fi
  echo "" >&2
  echo "About to rotate tokens for ${users_count} user(s) in ${USERS_NAMESPACE}." >&2
  echo "This will invalidate existing kubeconfigs that use long-lived secrets." >&2
  echo "Short-lived tokens already issued will remain valid until their expiry." >&2
  echo "" >&2
  printf 'Continue? [y/N]: ' >&2
  local ans
  read -r ans
  case "${ans}" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

function cmd_rotate() {
  if [ "${ROTATE_ALL}" = "true" ] && [ -n "${TARGET_USER}" ]; then
    _err "--user and --all are mutually exclusive"
    return 1
  fi
  if [ "${ROTATE_ALL}" != "true" ] && [ -z "${TARGET_USER}" ]; then
    _err "--rotate requires either --user <name> or --all"
    return 1
  fi

  # Single user
  if [ -n "${TARGET_USER}" ]; then
    _rotate_one "${TARGET_USER}" "${TTL}"
    if [ "${_ROT_RESULT}" = "ok" ]; then
      _info "Rotated ${TARGET_USER} (${_ROT_MSG})"
      return 0
    else
      _err "Rotation failed for ${TARGET_USER}: ${_ROT_MSG}"
      return 1
    fi
  fi

  # --all
  local users_tsv
  users_tsv=$(_list_rotatable_users)
  if [ -z "${users_tsv}" ]; then
    _info "No users found in ${USERS_NAMESPACE}"
    return 0
  fi

  # Filter out users that have no bindings at all (orphan SAs from failed creates)
  local user_list=()
  local u ns
  while IFS=$'\t' read -r u ns; do
    [ -z "${u}" ] && continue
    user_list+=("${u}")
  done <<< "${users_tsv}"

  local total=${#user_list[@]}

  if ! _confirm_rotate_all "${total}"; then
    _info "Rotation cancelled"
    return 0
  fi

  local idx=0 ok_count=0 err_count=0
  local -a failures=()
  for u in "${user_list[@]}"; do
    idx=$((idx + 1))
    _info "[${idx}/${total}] rotating ${u}..."
    if _rotate_one "${u}" "${TTL}"; then
      ok_count=$((ok_count + 1))
      _info "[${idx}/${total}] ${u} -> ${_ROT_MSG}"
    else
      err_count=$((err_count + 1))
      failures+=("${u}: ${_ROT_MSG}")
      _warn "[${idx}/${total}] ${u} FAILED: ${_ROT_MSG}"
    fi
  done

  echo "" >&2
  _info "Rotation complete: ${ok_count} ok, ${err_count} failed (total ${total})"
  if [ ${err_count} -gt 0 ]; then
    echo "" >&2
    echo "Failed users:" >&2
    for f in "${failures[@]}"; do
      echo "  - ${f}" >&2
    done
    return 1
  fi
  return 0
}

# ----- Listing -----------------------------------------------------------------
function _resolve_token_info() {
  local user=$1 ns=$2
  local config_file="./${user}-kubeconfig"
  _RES_TTL=""
  _RES_EXPIRES=""
  _RES_REMAINING=""
  _RES_NOTE=""
  _RES_EXP_TS=""

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

  if _has_longlived_secret "${user}" "${ns}"; then
    _RES_TTL="never"
    _RES_EXPIRES="-"
    _RES_REMAINING="-"
    _RES_NOTE="long-lived secret"
    return 0
  fi

  _RES_TTL="short-lived"
  _RES_EXPIRES="unknown"
  _RES_REMAINING="unknown"
  _RES_NOTE="kubeconfig not found"
}

# Collect cluster-scope bindings: user, sa_ns, role
function _collect_cluster_bindings() {
  kubectl get clusterrolebinding -o json | jq -r --arg uns "${USERS_NAMESPACE}" --arg lns "${LEGACY_NAMESPACE}" '
    .items[]
    | select(
        .metadata.name | test("-binding(-view|-nodes|-custom-.+)?$")
      )
    | . as $crb
    | (.subjects // [])[]
    | select(.kind == "ServiceAccount")
    | select(.namespace == $uns or .namespace == $lns)
    | "\(.name)\t\(.namespace)\t\($crb.roleRef.name)"
  ' | sort -u
}

# Collect namespace-scope bindings: user, sa_ns, target_ns, role
function _collect_namespace_bindings() {
  kubectl get rolebinding --all-namespaces -o json | jq -r --arg uns "${USERS_NAMESPACE}" --arg lns "${LEGACY_NAMESPACE}" '
    .items[]
    | select(.metadata.name | test("-rb-(edit|view|custom-.+)$"))
    | . as $rb
    | (.subjects // [])[]
    | select(.kind == "ServiceAccount")
    | select(.namespace == $uns or .namespace == $lns)
    | "\(.name)\t\(.namespace)\t\($rb.metadata.namespace)\t\($rb.roleRef.name)"
  ' | sort -u
}

# Aggregate into per-user records.
# Output JSON array of objects: {user, sa_ns, scope, role_label, namespaces[]}
function _build_user_records() {
  local cluster_lines ns_lines
  cluster_lines=$(_collect_cluster_bindings)
  ns_lines=$(_collect_namespace_bindings)

  jq -n \
    --rawfile cluster <(printf '%s' "${cluster_lines}") \
    --rawfile nsb     <(printf '%s' "${ns_lines}") \
  '
    def parse_cluster:
      ($cluster | split("\n") | map(select(length>0) | split("\t")
        | {user:.[0], sa_ns:.[1], role:.[2]}));
    def parse_ns:
      ($nsb | split("\n") | map(select(length>0) | split("\t")
        | {user:.[0], sa_ns:.[1], target_ns:.[2], role:.[3]}));

    def cluster_label(roles):
      if (roles | index("cluster-admin")) then "admin"
      elif (roles | index("view")) and (roles | index("nodes-viewer")) then "readonly"
      else "custom:" + (roles | sort | join(","))
      end;

    def ns_label(role):
      if role == "edit" then "editor"
      elif role == "view" then "view"
      else "custom:" + role
      end;

    # Group cluster bindings by (user, sa_ns)
    (parse_cluster
      | group_by(.user + "\u0000" + .sa_ns)
      | map({
          user: .[0].user,
          sa_ns: .[0].sa_ns,
          scope: "cluster",
          role: cluster_label([.[].role]),
          namespaces: []
        })
    ) as $cluster_users |

    # Group ns bindings by (user, sa_ns, target_ns) - one entry per ns binding
    (parse_ns
      | map({
          user: .user,
          sa_ns: .sa_ns,
          scope: "namespace",
          role: ns_label(.role),
          target_ns: .target_ns
        })
      # Group by (user, sa_ns, role) so multiple ns with same role collapse into one row
      | group_by(.user + "\u0000" + .sa_ns + "\u0000" + .role)
      | map({
          user: .[0].user,
          sa_ns: .[0].sa_ns,
          scope: "namespace",
          role: .[0].role,
          namespaces: ([.[].target_ns] | sort | unique)
        })
    ) as $ns_users |

    $cluster_users + $ns_users
  '
}

function cmd_list_table() {
  local records
  records=$(_build_user_records)
  local count
  count=$(printf '%s' "${records}" | jq 'length')
  if [ "${count}" -eq 0 ]; then
    echo "No custom users found"
    return 0
  fi

  # Collect all rows first, compute per-column widths, then render.
  # Row format (TAB-separated): user role scope ttl expires remaining note
  local rows="" w_user=4 w_role=4 w_scope=5 w_ttl=3 w_exp=7 w_rem=9 w_note=4
  local user role sa_ns scope namespaces scope_str legacy_tag note_full

  while IFS=$'\t' read -r user role sa_ns scope namespaces; do
    [ -z "${user}" ] && continue
    if [ "${scope}" = "cluster" ]; then
      scope_str="cluster"
    else
      scope_str="ns:${namespaces}"
    fi
    _resolve_token_info "${user}" "${sa_ns}"
    legacy_tag=""
    [ "${sa_ns}" = "${LEGACY_NAMESPACE}" ] && legacy_tag=" [legacy]"
    note_full="${_RES_NOTE}${legacy_tag}"

    [ ${#user}        -gt "${w_user}"  ] && w_user=${#user}
    [ ${#role}        -gt "${w_role}"  ] && w_role=${#role}
    [ ${#scope_str}   -gt "${w_scope}" ] && w_scope=${#scope_str}
    [ ${#_RES_TTL}    -gt "${w_ttl}"   ] && w_ttl=${#_RES_TTL}
    [ ${#_RES_EXPIRES} -gt "${w_exp}"  ] && w_exp=${#_RES_EXPIRES}
    [ ${#_RES_REMAINING} -gt "${w_rem}" ] && w_rem=${#_RES_REMAINING}
    [ ${#note_full}   -gt "${w_note}"  ] && w_note=${#note_full}

    rows+="${user}"$'\t'"${role}"$'\t'"${scope_str}"$'\t'"${_RES_TTL}"$'\t'"${_RES_EXPIRES}"$'\t'"${_RES_REMAINING}"$'\t'"${note_full}"$'\n'
  done < <(printf '%s' "${records}" | jq -r '.[] | [
      .user, .role, .sa_ns, .scope, ((.namespaces // []) | join(","))
    ] | @tsv' | sort)

  local fmt="%-${w_user}s  %-${w_role}s  %-${w_scope}s  %-${w_ttl}s  %-${w_exp}s  %-${w_rem}s  %s\n"
  # shellcheck disable=SC2059
  printf "${fmt}" "USER" "ROLE" "SCOPE" "TTL" "EXPIRES" "REMAINING" "NOTE"

  # Separator: sum of widths + 6 gaps × 2 spaces = 12
  local total=$(( w_user + w_role + w_scope + w_ttl + w_exp + w_rem + w_note + 12 ))
  printf '%*s\n' "${total}" '' | tr ' ' '-'

  local r_user r_role r_scope r_ttl r_exp r_rem r_note
  while IFS=$'\t' read -r r_user r_role r_scope r_ttl r_exp r_rem r_note; do
    [ -z "${r_user}" ] && continue
    # shellcheck disable=SC2059
    printf "${fmt}" "${r_user}" "${r_role}" "${r_scope}" "${r_ttl}" "${r_exp}" "${r_rem}" "${r_note}"
  done <<< "${rows}"
}

function cmd_list_json() {
  local records
  records=$(_build_user_records)
  local count
  count=$(printf '%s' "${records}" | jq 'length')
  if [ "${count}" -eq 0 ]; then
    echo "[]"
    return 0
  fi

  # Enrich each record with resolved token info
  local entries=""
  local user role sa_ns scope namespaces
  while IFS=$'\t' read -r user role sa_ns scope namespaces; do
    [ -z "${user}" ] && continue
    _resolve_token_info "${user}" "${sa_ns}"
    local legacy=false
    [ "${sa_ns}" = "${LEGACY_NAMESPACE}" ] && legacy=true
    local ns_array="[]"
    if [ -n "${namespaces}" ]; then
      ns_array=$(printf '%s' "${namespaces}" | jq -R 'split(",")')
    fi
    local entry
    entry=$(jq -n \
      --arg user "${user}" \
      --arg role "${role}" \
      --arg sa_ns "${sa_ns}" \
      --arg scope "${scope}" \
      --argjson namespaces "${ns_array}" \
      --arg ttl "${_RES_TTL}" \
      --arg expires "${_RES_EXPIRES}" \
      --arg remaining "${_RES_REMAINING}" \
      --arg note "${_RES_NOTE}" \
      --arg exp_ts "${_RES_EXP_TS}" \
      --argjson legacy "${legacy}" \
      '{
        user: $user,
        role: $role,
        sa_namespace: $sa_ns,
        scope: $scope,
        namespaces: $namespaces,
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
  done < <(printf '%s' "${records}" | jq -r '.[] | [
      .user, .role, .sa_ns, .scope, ((.namespaces // []) | join(","))
    ] | @tsv' | sort)

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

Commands:
  --create   --user <name> [role-spec] [--ttl <duration>]
                Create new user. role-spec defines RBAC.

  --update   --user <name> [role-spec] [--ttl <duration>]
                Modify existing user: rotate token and/or add namespace access.
                At least one of --ttl, --role/--cluster-role+--namespace required.

  --delete   --user <name> [--namespace <ns>]
                Without --namespace: full delete (SA, all bindings, secret, kubeconfig).
                With --namespace: revoke only RoleBindings in that namespace.

  --mkconfig --user <name>
                Regenerate kubeconfig from existing long-lived secret.
                Does NOT issue new tokens. Use --update for token rotation.

  --list [--json]
                List all custom users with TTL/expiry and scope.

  --rotate   (--user <name> | --all) [--ttl <duration>] [--yes]
                Rotate token(s). For long-lived: deletes old Secret and creates
                new one (invalidates old token). For short-lived: issues new
                token (old continues until its expiry).
                Without --ttl: detect from local kubeconfig; fall back to ${ROTATE_DEFAULT_TTL}.
                --all: rotate all users in ${USERS_NAMESPACE} (legacy users skipped).
                --yes / -y: skip confirmation prompt for --all.

Role specifications:
  Cluster-scope:
    --role admin                    cluster-admin
    --role readonly                 view + nodes-viewer
    --cluster-role <name>           custom existing ClusterRole, cluster-wide

  Namespace-scope (requires --namespace):
    --role editor   --namespace NS  edit ClusterRole, scoped to NS
    --role view     --namespace NS  view ClusterRole, scoped to NS
    --cluster-role <name> --namespace NS   custom ClusterRole, scoped to NS

TTL:
  --ttl 0 or omitted       Long-lived token via manual Secret
  --ttl <Go duration>      Short-lived token (e.g. 30m, 24h, 720h)

Environment:
  K8S_USERS_NS    Namespace for user ServiceAccounts (default: kube-users)

Examples:
  $0 --create --user alice --role admin
  $0 --create --user dev1  --role editor --namespace myapp --ttl 24h
  $0 --create --user audit --cluster-role my-auditor --namespace prod
  $0 --update --user dev1  --role view --namespace staging
  $0 --update --user alice --ttl 8h
  $0 --rotate --user alice
  $0 --rotate --user alice --ttl 48h
  $0 --rotate --all --yes
  $0 --delete --user dev1  --namespace myapp
  $0 --delete --user alice
  $0 --list --json
EOF
}

# ----- Main --------------------------------------------------------------------
function main() {
  if ! _chk_extended_prg; then exit 1; fi
  if ! check_k8s_api; then exit 1; fi

  CLUSTER_NAME=$(get_k8s_cluster_name) || exit 1
  API_SERVER=$(get_k8s_api_url)        || exit 1
  CLUSTER_CA=$(get_cluster_ca)         || exit 1

  _info "Cluster: ${CLUSTER_NAME}  API: ${API_SERVER}"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --create)       CMD_CREATE=true;   shift ;;
      --update)       CMD_UPDATE=true;   shift ;;
      --delete)       CMD_DELETE=true;   shift ;;
      --mkconfig)     CMD_MKCONFIG=true; shift ;;
      --list)         CMD_LIST=true;     shift ;;
      --rotate)       CMD_ROTATE=true;   shift ;;
      --all)          ROTATE_ALL=true;   shift ;;
      --yes|-y)       ASSUME_YES=true;   shift ;;
      --json)         JSON_OUT=true;     shift ;;
      --user)         TARGET_USER="$2";  shift 2 ;;
      --role)         ROLE="$2";         shift 2 ;;
      --cluster-role) CLUSTER_ROLE="$2"; shift 2 ;;
      --namespace)    NAMESPACE="$2";    shift 2 ;;
      --ttl)          TTL="$2";          shift 2 ;;
      -h|--help)      usage; exit 0 ;;
      *) _err "Unknown parameter: $1"; usage; exit 1 ;;
    esac
  done

  # Exactly one command must be selected
  local cmd_count=0
  for v in "${CMD_CREATE}" "${CMD_UPDATE}" "${CMD_DELETE}" "${CMD_MKCONFIG}" "${CMD_LIST}" "${CMD_ROTATE}"; do
    [ "${v}" = "true" ] && cmd_count=$((cmd_count + 1))
  done
  if [ ${cmd_count} -eq 0 ]; then
    usage; exit 1
  fi
  if [ ${cmd_count} -gt 1 ]; then
    _err "Only one command (--create, --update, --delete, --mkconfig, --list, --rotate) allowed at a time"
    exit 1
  fi

  if [[ ${CMD_CREATE} == true ]]; then
    [[ -z ${TARGET_USER} ]] && { _err "--user is required with --create"; exit 1; }
    cmd_create "${TARGET_USER}"
  elif [[ ${CMD_UPDATE} == true ]]; then
    [[ -z ${TARGET_USER} ]] && { _err "--user is required with --update"; exit 1; }
    cmd_update "${TARGET_USER}"
  elif [[ ${CMD_DELETE} == true ]]; then
    [[ -z ${TARGET_USER} ]] && { _err "--user is required with --delete"; exit 1; }
    cmd_delete "${TARGET_USER}"
  elif [[ ${CMD_MKCONFIG} == true ]]; then
    [[ -z ${TARGET_USER} ]] && { _err "--user is required with --mkconfig"; exit 1; }
    cmd_mkconfig "${TARGET_USER}"
  elif [[ ${CMD_LIST} == true ]]; then
    cmd_list
  elif [[ ${CMD_ROTATE} == true ]]; then
    cmd_rotate
  fi
}

main "$@"
