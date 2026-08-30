#!/usr/bin/env bash
set -uo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────────────────────
STACK_NAME=registry_test
SERVICE=registry
SECRET=registry_http_secret_test
TEST_PORT=5001
REGISTRY="127.0.0.1:${TEST_PORT}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MK_DIR="${SCRIPT_DIR}/.."
DEPLOY_DIR="$(mktemp -d)"

PASS=0
FAIL=0

# ──────────────────────────────────────────────────────────────────────────────
# Precondition
# ──────────────────────────────────────────────────────────────────────────────
swarm_state="$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || true)"
if [ "$swarm_state" != "active" ]; then
  echo "ERROR: swarm not active (state='${swarm_state}'). Run: docker swarm init"
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# Teardown — runs even on failure
# ──────────────────────────────────────────────────────────────────────────────
teardown() {
  echo ""
  echo "--- teardown ---"
  docker stack rm "${STACK_NAME}" 2>/dev/null || true
  sleep 8
  docker volume rm "${STACK_NAME}_registry-test-data" 2>/dev/null || true
  docker secret rm "${SECRET}" 2>/dev/null || true
  local tag
  for tag in v0.0.{1..10}; do
    docker image rm -f "${REGISTRY}/selftest:${tag}" 2>/dev/null || true
  done
  docker image rm -f \
    "${REGISTRY}/selftest2:v0.0.1" \
    "${REGISTRY}/selftest3:v0.0.1" \
    "${REGISTRY}/selftest4:v0.0.1" 2>/dev/null || true
  rm -rf "${DEPLOY_DIR}"
}
trap teardown EXIT

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────
mk() {
  make -C "$MK_DIR" \
    STACK_NAME="$STACK_NAME" \
    SERVICE="$SERVICE" \
    REGISTRY_HOST=127.0.0.1 \
    REGISTRY_PORT="$TEST_PORT" \
    DEPLOY_DIR="$DEPLOY_DIR" \
    "$@"
}

assert() {
  local name="$1" expected="$2"
  shift 2
  local output exit_code=0
  output="$("$@" 2>&1)" || exit_code=$?
  if [ "$exit_code" -ne 0 ] || ! printf '%s' "$output" | grep -qF "$expected"; then
    echo "FAIL [$name]  exit=$exit_code  expected substring: '$expected'"
    printf '%s\n' "$output" | head -5 | sed 's/^/  /'
    FAIL=$((FAIL + 1))
  else
    echo "PASS [$name]"
    PASS=$((PASS + 1))
  fi
}

assert_exit0() {
  local name="$1"; shift
  local exit_code=0
  "$@" >/dev/null 2>&1 || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo "FAIL [$name]  exit=$exit_code"
    FAIL=$((FAIL + 1))
  else
    echo "PASS [$name]"
    PASS=$((PASS + 1))
  fi
}

wait_registry() {
  local i
  for i in $(seq 1 30); do
    if curl -sf --max-time 2 "http://${REGISTRY}/v2/" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "ERROR: registry at ${REGISTRY} did not become ready"
  return 1
}

# ──────────────────────────────────────────────────────────────────────────────
# Setup
# ──────────────────────────────────────────────────────────────────────────────
echo "=== Setup ==="

printf 'testonly' | docker secret create "${SECRET}" - >/dev/null

cp "${SCRIPT_DIR}/stack.test.yml" "${DEPLOY_DIR}/stack.yml"

mk init >/dev/null
mk stack-deploy

echo "Waiting for ${REGISTRY} ..."
wait_registry
echo "Registry ready."

docker pull registry:2 >/dev/null
# Build 10 images with distinct labels so each has a unique manifest digest.
# Necessary because registry DELETE removes by digest — a shared digest would
# wipe all 10 tags at once, breaking the registry-remove-old KEEP=3 assertion.
for i in $(seq 1 10); do
  tag="v0.0.${i}"
  docker build -q -t "${REGISTRY}/selftest:${tag}" - <<EOF >/dev/null
FROM registry:2
LABEL selftest.version="${tag}"
EOF
  docker push "${REGISTRY}/selftest:${tag}" >/dev/null
done
echo "Pushed selftest v0.0.1..v0.0.10."
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Assertions
# ──────────────────────────────────────────────────────────────────────────────
echo "=== Assertions ==="

# Read-only targets
assert_exit0 "help"                      mk help
assert_exit0 "stack-ls"                  mk stack-ls
assert_exit0 "service-ls"                mk service-ls
assert       "registry-info"             "Total repositories"       mk registry-info
assert       "registry-list"             "selftest"                 mk registry-list
assert       "registry-list-all"         "selftest"                 mk registry-list-all
assert       "registry-tags"             "v0.0.1"                   mk registry-tags IMAGE=selftest
assert       "registry-verify-manifest"  "Manifest exists"          mk registry-verify-manifest IMAGE=selftest TAG=v0.0.1
assert       "registry-check-manifest"   "Docker-Content-Digest"    mk registry-check-manifest IMAGE=selftest TAG=v0.0.1

# Lifecycle
assert_exit0 "init"            mk init
assert_exit0 "service-deploy"  mk service-deploy

# Streaming — timeout 3 fires normally (exit 124); any other non-zero is failure
# timeout cannot invoke a shell function, so the make call is inlined here
log_exit=0
timeout 3 make -C "$MK_DIR" \
  STACK_NAME="$STACK_NAME" SERVICE="$SERVICE" \
  REGISTRY_HOST=127.0.0.1 REGISTRY_PORT="$TEST_PORT" \
  DEPLOY_DIR="$DEPLOY_DIR" logs >/dev/null 2>&1 || log_exit=$?
if [ "$log_exit" -eq 0 ] || [ "$log_exit" -eq 124 ]; then
  echo "PASS [logs]"
  PASS=$((PASS + 1))
else
  echo "FAIL [logs]  exit=$log_exit"
  FAIL=$((FAIL + 1))
fi

# Destructive targets on test data

# registry-remove-tag: remove v0.0.1, then GC
assert "registry-remove-tag" "marked for deletion" \
  mk registry-remove-tag IMAGE=selftest TAG=v0.0.1
mk registry-gc >/dev/null 2>&1 || true
wait_registry

# registry-remove-old KEEP=3: v0.0.2..v0.0.10 remain; keeps v0.0.10, v0.0.9, v0.0.8
assert "registry-remove-old KEEP=3" "marked for deletion" \
  mk registry-remove-old IMAGE=selftest KEEP=3
mk registry-gc >/dev/null 2>&1 || true
wait_registry

# Verify the three kept tags are exactly v0.0.10, v0.0.9, v0.0.8 (guards sort -Vr fix)
kept="$(mk registry-tags IMAGE=selftest 2>/dev/null \
  | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sort -Vr | tr '\n' ' ' | sed 's/ $//')"
if [ "$kept" = "v0.0.10 v0.0.9 v0.0.8" ]; then
  echo "PASS [registry-remove-old: kept=v0.0.10,v0.0.9,v0.0.8]"
  PASS=$((PASS + 1))
else
  echo "FAIL [registry-remove-old: kept]  got: '$kept'"
  FAIL=$((FAIL + 1))
fi

# registry-remove-image: push selftest2, then remove it via API
docker tag registry:2 "${REGISTRY}/selftest2:v0.0.1"
docker push "${REGISTRY}/selftest2:v0.0.1" >/dev/null
assert "registry-remove-image" "Tags deleted via API" \
  mk registry-remove-image IMAGE=selftest2
mk registry-gc >/dev/null 2>&1 || true
wait_registry

# registry-cleanup-orphaned FORCE=y: push selftest3, delete tags from filesystem
docker tag registry:2 "${REGISTRY}/selftest3:v0.0.1"
docker push "${REGISTRY}/selftest3:v0.0.1" >/dev/null
assert "registry-cleanup-orphaned FORCE=y" "Tags removed from filesystem" \
  mk registry-cleanup-orphaned IMAGE=selftest3 FORCE=y
mk registry-gc >/dev/null 2>&1 || true
wait_registry

# registry-cleanup-repo FORCE=y: push selftest4, remove entire repo from filesystem
docker tag registry:2 "${REGISTRY}/selftest4:v0.0.1"
docker push "${REGISTRY}/selftest4:v0.0.1" >/dev/null
assert "registry-cleanup-repo FORCE=y" "Repository removed from filesystem" \
  mk registry-cleanup-repo IMAGE=selftest4 FORCE=y

# stack-rm (lifecycle — removes the test stack; teardown handles any residue)
assert_exit0 "stack-rm" mk stack-rm

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Results: ${PASS} passed / ${FAIL} failed ==="
[ "$FAIL" -eq 0 ]
