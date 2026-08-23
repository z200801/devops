#!/usr/bin/env bash
# Smoke test for the rustfs stack.
#
# Prerequisites:
#   - mcli (MinIO client) on PATH (installed as mcli, not mc)
#   - .env present at the project root with S3_HOST, WEBSECURE_PORT
#   - S3_HOST resolves to the Swarm node (DNS or /etc/hosts entry)
#   - Credentials passed via env: RUSTFS_ACCESS_KEY, RUSTFS_SECRET_KEY
#     (use 'make test' — it reads them from Docker secrets automatically)
#
# Usage (from project root):
#   make test                           # full test including redeploy check
#   bash test/smoke.sh --skip-redeploy  # upload/download only, no redeploy
#     (pass RUSTFS_ACCESS_KEY/RUSTFS_SECRET_KEY when invoking directly)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ROOT}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: ${ENV_FILE} not found — copy .env.example to .env and fill in." >&2
  exit 1
fi

# Preserve credentials passed via env (make test reads from Docker secrets)
_save_ak="${RUSTFS_ACCESS_KEY:-}"
_save_sk="${RUSTFS_SECRET_KEY:-}"

set -a; . "${ENV_FILE}"; set +a

# Restore — env vars from caller take precedence over .env
[ -n "${_save_ak}" ] && RUSTFS_ACCESS_KEY="${_save_ak}"
[ -n "${_save_sk}" ] && RUSTFS_SECRET_KEY="${_save_sk}"

: "${RUSTFS_ACCESS_KEY:?RUSTFS_ACCESS_KEY not set — run via 'make test' or pass as env var}"
: "${RUSTFS_SECRET_KEY:?RUSTFS_SECRET_KEY not set — run via 'make test' or pass as env var}"
: "${S3_HOST:?S3_HOST not set in .env}"
: "${WEBSECURE_PORT:=19001}"

SKIP_REDEPLOY=0
for arg in "$@"; do
  [[ "${arg}" == "--skip-redeploy" ]] && SKIP_REDEPLOY=1
done

ALIAS=rustfs-smoke
BUCKET=smoke-test
OBJ_KEY=smoke.txt
OBJ_CONTENT="hello-rustfs-$(date -u +%s)"
TMP_PUT="$(mktemp)"
TMP_GET="$(mktemp)"
ALIAS_URL="https://${S3_HOST}:${WEBSECURE_PORT}"

cleanup() {
  rm -f "${TMP_PUT}" "${TMP_GET}"
  mcli alias remove "${ALIAS}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> alias ${ALIAS} -> ${ALIAS_URL}"
mcli alias set "${ALIAS}" "${ALIAS_URL}" \
  "${RUSTFS_ACCESS_KEY}" "${RUSTFS_SECRET_KEY}" \
  --insecure --api S3v4 >/dev/null

echo "==> mb ${BUCKET}"
mcli mb --insecure --ignore-existing "${ALIAS}/${BUCKET}"

printf '%s\n' "${OBJ_CONTENT}" > "${TMP_PUT}"

echo "==> cp up"
mcli cp --insecure "${TMP_PUT}" "${ALIAS}/${BUCKET}/${OBJ_KEY}"

echo "==> cp down + diff"
mcli cp --insecure "${ALIAS}/${BUCKET}/${OBJ_KEY}" "${TMP_GET}"
diff "${TMP_PUT}" "${TMP_GET}"
echo "PASS: upload/download match"

if [[ "${SKIP_REDEPLOY}" -eq 0 ]]; then
  echo "==> make deploy (persistence check)"
  make -C "${ROOT}" deploy

  echo "==> waiting for rustfs to become ready after redeploy"
  deadline=$((SECONDS + 90))
  until [ "$(curl -sk --max-time 5 -o /dev/null -w '%{http_code}' \
            "https://${S3_HOST}:${WEBSECURE_PORT}/health")" = "200" ]; do
    if [ "${SECONDS}" -ge "${deadline}" ]; then
      echo "ERROR: rustfs not ready within 90s after redeploy" >&2
      exit 1
    fi
    sleep 3
  done

  echo "==> cp down after redeploy + diff"
  mcli cp --insecure "${ALIAS}/${BUCKET}/${OBJ_KEY}" "${TMP_GET}"
  diff "${TMP_PUT}" "${TMP_GET}"
  echo "PASS: object survived redeploy"
fi

echo "==> smoke OK"
