SHELL := /bin/bash
.DEFAULT_GOAL := help

# ============================================================
# Stack variables
# ============================================================

STACK ?= rustfs

# Overridable at the make command line:
#   make deploy S3_HOST=s3.example.com WEB_PORT=18000 WEBSECURE_PORT=18001
S3_HOST        ?=
CONSOLE_HOST   ?=
WEB_PORT       ?=
WEBSECURE_PORT ?=

TRAEFIK_STATIC   := traefik_static_$(shell md5sum traefik_config/traefik.yml | cut -c1-8)
export TRAEFIK_STATIC
TRAEFIK_FAIL2BAN := traefik_fail2ban_$(shell md5sum traefik_config/dynamic/fail2ban.yml | cut -c1-8)
export TRAEFIK_FAIL2BAN

# Expands to zero or more "export VAR='value';" statements for any variable
# that was set on the make command line — these override values sourced from .env.
_OVERRIDES = \
  $(if $(S3_HOST),        export S3_HOST='$(S3_HOST)';        ) \
  $(if $(CONSOLE_HOST),   export CONSOLE_HOST='$(CONSOLE_HOST)';   ) \
  $(if $(WEB_PORT),       export WEB_PORT='$(WEB_PORT)';       ) \
  $(if $(WEBSECURE_PORT), export WEBSECURE_PORT='$(WEBSECURE_PORT)'; )

# ============================================================
# CLI variables (defaults sourced from .env at runtime)
# ============================================================

MINIO_CLI_NAME ?= mcli
MINIO_CLI      ?= /usr/local/bin/$(MINIO_CLI_NAME)
MCLI           ?= $(MINIO_CLI)
INSECURE       ?= --insecure

# These default to .env values at runtime; override on the command line if needed.
ALIAS    ?=
SERVER   ?=
PASSWORD ?=
BUCKET   ?=
POLICY   ?=
FILE     ?=
FLAGS    ?=
SERVICE  ?=
FORCE    ?=

# ============================================================
# Functions
# ============================================================

define _chk_var
	if ! env | grep -Poq "^$1=\K\S+"; then echo "Error. Not set variable [$1]"; exit 1; fi
endef

define _chk_vars
	_vars=$1; \
	for i in $${_vars}; do $(call _chk_var,$${i}); done
endef

# Sources .env, validates required stack vars, and resolves ALIAS/SERVER.
# USERNAME and PASSWORD are NOT defaulted here — targets that need creds
# must set their own defaults or require explicit values via _chk_var.
define _source_env
	[ -f ./.env ] || { echo "ERROR: .env not found — cp .env.example .env" >&2; exit 1; }; \
	set -a; . ./.env; set +a; \
	: "$${S3_HOST:?S3_HOST not set in .env}"; \
	: "$${WEBSECURE_PORT:=19001}"; \
	ALIAS=$${ALIAS:-rustfs}; \
	SERVER=$${SERVER:-https://$${S3_HOST}:$${WEBSECURE_PORT}}; \
	export ALIAS SERVER
endef

# Reads root credentials from the running rustfs container's mounted secrets.
# Sets _ak (access key) and _sk (secret key). Requires the stack to be running.
define _read_secrets
	_ctid=$$(docker ps -q -f name=$(STACK)_rustfs | head -1); \
	[ -n "$$_ctid" ] || { echo "ERROR: cannot read credentials — is rustfs_rustfs running?" >&2; exit 1; }; \
	_ak=$$(docker exec $$_ctid cat /run/secrets/rustfs_access_key 2>/dev/null); \
	_sk=$$(docker exec $$_ctid cat /run/secrets/rustfs_secret_key 2>/dev/null); \
	[ -n "$$_ak" ] || { echo "ERROR: /run/secrets/rustfs_access_key not readable in container" >&2; exit 1; }
endef

# ============================================================
# Targets
# ============================================================

.PHONY: help
help:  ## show this help
	@awk 'BEGIN {FS = ":.*##"} \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next } \
	  /^[a-zA-Z0-9_-]+:.*##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2 }' \
	  $(MAKEFILE_LIST)

##@ Stack

.PHONY: config
config:  ## create docker configs if missing (idempotent)
	@docker config inspect $(TRAEFIK_STATIC) >/dev/null 2>&1 \
	  || docker config create $(TRAEFIK_STATIC) traefik_config/traefik.yml
	@docker config inspect $(TRAEFIK_FAIL2BAN) >/dev/null 2>&1 \
	  || docker config create $(TRAEFIK_FAIL2BAN) traefik_config/dynamic/fail2ban.yml

.PHONY: deploy
deploy: config  ## source .env, apply overrides, deploy stack (S3_HOST/CONSOLE_HOST/WEB_PORT/WEBSECURE_PORT)
	@docker secret inspect rustfs_access_key >/dev/null 2>&1 \
	  || { echo "ERROR: docker secret 'rustfs_access_key' not found. Run: make secret-create ACCESS_KEY=... SECRET_KEY=..." >&2; exit 1; }
	@docker secret inspect rustfs_secret_key >/dev/null 2>&1 \
	  || { echo "ERROR: docker secret 'rustfs_secret_key' not found. Run: make secret-create ACCESS_KEY=... SECRET_KEY=..." >&2; exit 1; }
	set -a; . ./.env; set +a; \
	$(_OVERRIDES) \
	docker stack deploy -c stack.yml $(STACK)

.PHONY: redeploy
redeploy: deploy  ## deploy + force-restart all services (use after :latest image update)
	docker service update --force $(STACK)_traefik
	docker service update --force $(STACK)_rustfs

.PHONY: test
test:  ## run mcli smoke test (requires running stack and mcli on PATH)
	@$(call _source_env); \
	$(call _read_secrets); \
	RUSTFS_ACCESS_KEY="$$_ak" RUSTFS_SECRET_KEY="$$_sk" bash test/smoke.sh

.PHONY: logs
logs:  ## show last 50 log lines for a service (SERVICE=traefik|rustfs)
	@$(call _chk_var,SERVICE)
	@docker service logs --tail 50 $(STACK)_$${SERVICE}

.PHONY: down
down:  ## remove the stack (named volumes are preserved)
	docker stack rm $(STACK)

.PHONY: config-prune
config-prune:  ## remove orphaned traefik docker config objects (keeps current versions)
	@docker config ls --format '{{.Name}}' \
	  | grep -E '^(traefik_static|traefik_fail2ban)_' \
	  | grep -v "^$(TRAEFIK_STATIC)$$" \
	  | grep -v "^$(TRAEFIK_FAIL2BAN)$$" \
	  | xargs -r docker config rm && echo "config-prune: done" || true

##@ Secrets

.PHONY: secret-create
secret-create:  ## create docker secrets for RustFS credentials (ACCESS_KEY=... SECRET_KEY=...)
	@[ "$(origin ACCESS_KEY)" = "command line" ] || { echo "ERROR: pass ACCESS_KEY=<value> on the command line" >&2; exit 1; }
	@[ "$(origin SECRET_KEY)" = "command line" ] || { echo "ERROR: pass SECRET_KEY=<value> on the command line" >&2; exit 1; }
	@printf '%s' '$(ACCESS_KEY)' | docker secret create rustfs_access_key - 2>/dev/null \
	  && echo "created: rustfs_access_key" \
	  || echo "exists:  rustfs_access_key (unchanged)"
	@printf '%s' '$(SECRET_KEY)' | docker secret create rustfs_secret_key - 2>/dev/null \
	  && echo "created: rustfs_secret_key" \
	  || echo "exists:  rustfs_secret_key (unchanged)"

.PHONY: secret-remove
secret-remove:  ## remove docker secrets (requires make down first if stack is running)
	@docker secret rm rustfs_access_key 2>/dev/null \
	  && echo "removed: rustfs_access_key" || echo "not found: rustfs_access_key"
	@docker secret rm rustfs_secret_key 2>/dev/null \
	  && echo "removed: rustfs_secret_key" || echo "not found: rustfs_secret_key"

.PHONY: secret-rotate
secret-rotate:  ## rotate root credentials (ACCESS_KEY=... SECRET_KEY=...; causes ~30-60s downtime)
	@[ "$(origin ACCESS_KEY)" = "command line" ] || { echo "ERROR: pass ACCESS_KEY=<value> on the command line" >&2; exit 1; }
	@[ "$(origin SECRET_KEY)" = "command line" ] || { echo "ERROR: pass SECRET_KEY=<value> on the command line" >&2; exit 1; }
	@echo "WARNING: this will stop the stack, rotate credentials, and redeploy."
	@echo "         Buckets, objects, and users are preserved (data volume untouched)."
	@echo "         Downtime: ~30-60 seconds."
	@echo ""
	@read -p "Continue? [y/N] " _confirm; \
	[ "$$_confirm" = "y" ] || [ "$$_confirm" = "Y" ] || { echo "Aborted."; exit 1; }
	docker stack rm $(STACK)
	@echo "Waiting for stack removal..."
	@sleep 10
	@docker secret rm rustfs_access_key 2>/dev/null || true
	@docker secret rm rustfs_secret_key 2>/dev/null || true
	@printf '%s' '$(ACCESS_KEY)' | docker secret create rustfs_access_key -
	@printf '%s' '$(SECRET_KEY)' | docker secret create rustfs_secret_key -
	@echo "Secrets rotated. Redeploying..."
	@$(MAKE) deploy
	@echo ""
	@echo "Rotation complete. New credentials:"
	@echo "  ACCESS_KEY=$(ACCESS_KEY)"
	@echo "  SECRET_KEY=$(SECRET_KEY)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. make alias-set              (reconfigure mcli)"
	@echo "  2. Update all S3 clients with the new credentials"

##@ CLI — S3-level (RustFS)

.PHONY: install
install:  ## download and install mcli to /usr/local/bin
	@_arch=$$(lscpu | grep -Po '^Architecture:\s+\K\S+' | sed 's/x86_64/amd64/; s/aarch64/arm64/') && \
	curl https://dl.min.io/client/mc/release/linux-$${_arch}/mc \
	  --create-dirs -o $${HOME}/minio-binaries/$(MINIO_CLI_NAME) && \
	chmod +x $${HOME}/minio-binaries/$(MINIO_CLI_NAME) && \
	sudo install $${HOME}/minio-binaries/$(MINIO_CLI_NAME) /usr/local/bin && \
	rm -rf $${HOME}/minio-binaries && \
	$(MCLI) --version

.PHONY: alias-set
alias-set:  ## configure mcli alias (reads credentials from Docker secrets; override with USERNAME/PASSWORD)
	@$(call _source_env); \
	$(call _read_secrets); \
	_u=$${USERNAME:-$$_ak}; \
	_p=$${PASSWORD:-$$_sk}; \
	$(MCLI) $(INSECURE) alias set $${ALIAS} $${SERVER} $${_u} $${_p}

.PHONY: alias-remove
alias-remove:  ## remove mcli alias (ALIAS=rustfs)
	@$(call _source_env); \
	$(MCLI) $(INSECURE) alias remove $${ALIAS}

.PHONY: alias-list
alias-list:  ## list all configured mcli aliases
	@$(MCLI) alias list

.PHONY: bucket-create
bucket-create:  ## create bucket (BUCKET=<name> [USER=<owner>] [FLAGS=...])
	@$(call _source_env); \
	$(call _chk_var,BUCKET); \
	_user='$(if $(filter command line,$(origin USER)),$(USER),)'; \
	_name="$${_user:+$${_user}-}$(BUCKET)"; \
	$(MCLI) $(INSECURE) mb $${FLAGS} $${ALIAS}/$$_name

.PHONY: bucket-list
bucket-list:  ## list buckets, or objects if BUCKET is set (BUCKET=<name>)
	@$(call _source_env); \
	$(MCLI) $(INSECURE) ls $${ALIAS}/$${BUCKET}

.PHONY: bucket-remove
bucket-remove:  ## remove bucket (BUCKET=<name>; FORCE=1 to remove a non-empty bucket)
	@$(call _source_env); \
	$(call _chk_var,BUCKET); \
	$(MCLI) $(INSECURE) rb $${FORCE:+--force} $${ALIAS}/$${BUCKET}

.PHONY: bucket-anonymous-download
bucket-anonymous-download:  ## set anonymous download policy on bucket (BUCKET=<name>)
	@$(call _source_env); \
	$(call _chk_var,BUCKET); \
	$(MCLI) $(INSECURE) anonymous set download $${ALIAS}/$${BUCKET}

##@ User provisioning

.PHONY: user-create
user-create:  ## create user + own-buckets RW policy (USER=<name> [PASSWORD=<...>])
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<name> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	pw="$${PASSWORD:-$$(openssl rand -hex 24)}"; \
	pol=$$(mktemp); sed 's/__USER__/$(USER)/g' policies/user-rw.json.tpl > "$$pol"; \
	$(MCLI) $(INSECURE) admin policy detach $${ALIAS} $(USER)-rw --user $(USER) 2>/dev/null || true; \
	$(MCLI) $(INSECURE) admin policy remove $${ALIAS} $(USER)-rw 2>/dev/null || true; \
	$(MCLI) $(INSECURE) admin policy create $${ALIAS} $(USER)-rw "$$pol"; \
	$(MCLI) $(INSECURE) admin user remove $${ALIAS} $(USER) 2>/dev/null || true; \
	$(MCLI) $(INSECURE) admin user add $${ALIAS} $(USER) "$$pw"; \
	$(MCLI) $(INSECURE) admin policy attach $${ALIAS} $(USER)-rw --user $(USER); \
	rm -f "$$pol"; \
	echo "created: USER=$(USER) PASSWORD=$$pw POLICY=$(USER)-rw"

.PHONY: user-delete
user-delete:  ## delete user + policy (USER=<name>; DELETE_BUCKETS=1 removes <name>-* buckets; FORCE=1 also non-empty)
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<name> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(MCLI) $(INSECURE) admin policy detach $${ALIAS} $(USER)-rw --user $(USER) 2>/dev/null || true; \
	$(MCLI) $(INSECURE) admin user remove $${ALIAS} $(USER) 2>/dev/null || true; \
	$(MCLI) $(INSECURE) admin policy remove $${ALIAS} $(USER)-rw 2>/dev/null || true; \
	if [ -n "$(DELETE_BUCKETS)" ]; then \
	  for b in $$($(MCLI) $(INSECURE) ls $${ALIAS}/ | awk '{print $$NF}' | sed 's#/##' | grep '^$(USER)-'); do \
	    $(MCLI) $(INSECURE) rb $${FORCE:+--force} $${ALIAS}/$$b; done; \
	fi; \
	echo "deleted: USER=$(USER)"

.PHONY: user-info
user-info:  ## show user info: policy name, buckets, service accounts (USER=<name>)
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<name> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	echo "=== Policy ==="; \
	echo "$(USER)-rw"; \
	echo ""; \
	echo "=== Buckets: $(USER)-* ==="; \
	$(MCLI) $(INSECURE) ls $${ALIAS}/ 2>/dev/null \
	  | grep ' $(USER)-' || echo "(no buckets)"; \
	echo ""; \
	echo "=== Service accounts ==="; \
	$(MCLI) $(INSECURE) admin user svcacct ls $${ALIAS} $(USER) 2>/dev/null \
	  || echo "(none or user not found)"

##@ Admin — MinIO admin API (provisioning works; admin-info returns 500, rustfs#1571)

.PHONY: user-add
user-add:  ## add user (USER=<access-key> PASSWORD=<secret-key>)
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<name> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(call _chk_var,PASSWORD); \
	$(MCLI) $(INSECURE) admin user add $${ALIAS} $(USER) $${PASSWORD}

.PHONY: user-remove
user-remove:  ## remove user (USER=<access-key>)
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<name> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(MCLI) $(INSECURE) admin user remove $${ALIAS} $(USER)

.PHONY: user-list
user-list:  ## list users
	@$(call _source_env); \
	$(MCLI) $(INSECURE) admin user list $${ALIAS}

.PHONY: user-disable
user-disable:  ## disable user (USER=<access-key>)
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<name> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(MCLI) $(INSECURE) admin user disable $${ALIAS} $(USER)

.PHONY: user-enable
user-enable:  ## enable user (USER=<access-key>)
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<name> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(MCLI) $(INSECURE) admin user enable $${ALIAS} $(USER)

.PHONY: admin-info
admin-info:  ## get server info
	@$(call _source_env); \
	$(MCLI) $(INSECURE) admin info $${ALIAS}

.PHONY: admin-policy-create
admin-policy-create:  ## create policy (POLICY=<name> FILE=<path>)
	@$(call _source_env); \
	$(call _chk_vars,"POLICY FILE"); \
	$(MCLI) $(INSECURE) admin policy create $${ALIAS} $${POLICY} $${FILE}

.PHONY: admin-policy-remove
admin-policy-remove:  ## remove policy (POLICY=<name>)
	@$(call _source_env); \
	$(call _chk_var,POLICY); \
	$(MCLI) $(INSECURE) admin policy remove $${ALIAS} $${POLICY}

.PHONY: admin-policy-list
admin-policy-list:  ## list policies
	@$(call _source_env); \
	$(MCLI) $(INSECURE) admin policy list $${ALIAS}

.PHONY: admin-policy-info
admin-policy-info:  ## get policy info (POLICY=<name>)
	@$(call _source_env); \
	$(call _chk_var,POLICY); \
	$(MCLI) $(INSECURE) admin policy info $${ALIAS} $${POLICY}

.PHONY: admin-policy-entities
admin-policy-entities:  ## list entities attached to policy (POLICY=<name> [FLAGS='--user <key>'])
	@$(call _source_env); \
	$(call _chk_var,POLICY); \
	$(MCLI) $(INSECURE) admin policy entities $${ALIAS} $${POLICY} $${FLAGS}

.PHONY: admin-policy-attach
admin-policy-attach:  ## attach policy to user or group (POLICY=<name> FLAGS='--user <key>' | FLAGS='--group <name>')
	@$(call _source_env); \
	$(call _chk_vars,"POLICY FLAGS"); \
	$(MCLI) $(INSECURE) admin policy attach $${ALIAS} $${POLICY} $${FLAGS}

.PHONY: admin-policy-detach
admin-policy-detach:  ## detach policy from user or group (POLICY=<name> FLAGS='--user <key>' | FLAGS='--group <name>')
	@$(call _source_env); \
	$(call _chk_vars,"POLICY FLAGS"); \
	$(MCLI) $(INSECURE) admin policy detach $${ALIAS} $${POLICY} $${FLAGS}

##@ Service accounts

# Service accounts are sub-credentials created under a parent user.
# They inherit the parent's policy and their secret key can be rotated
# online (no service restart needed).  Create under the root admin with
# USER=<parent-access-key> (defaults to access key read from Docker secrets).

.PHONY: svcacct-create
svcacct-create:  ## create service account under USER (USER=<parent>; defaults to root from Docker secrets; EXPIRY=YYYY-MM-DDThh:mm:ssZ)
	@$(call _source_env); \
	$(call _read_secrets); \
	_parent='$(if $(filter command line,$(origin USER)),$(USER),)'; \
	_parent="$${_parent:-$$_ak}"; \
	_pw=$${PASSWORD:-$$(openssl rand -hex 16)}; \
	_sa='$(if $(filter command line,$(origin SERVICE_ACCOUNT)),$(SERVICE_ACCOUNT),)'; \
	_expiry='$(if $(filter command line,$(origin EXPIRY)),--expiry $(EXPIRY),)'; \
	_out=$$($(MCLI) $(INSECURE) --json admin user svcacct add $${ALIAS} $$_parent \
	  $${_sa:+--access-key $$_sa} --secret-key "$$_pw" $$_expiry 2>&1); \
	printf '%s\n' "$$_out"; \
	echo "$$_out" | grep -q '"status":"success"' \
	  || { echo "ERROR: svcacct-create failed" >&2; exit 1; }; \
	echo "svcacct created under parent=$$_parent PASSWORD=$$_pw"

.PHONY: svcacct-rotate
svcacct-rotate:  ## rotate service account secret key online (SERVICE_ACCOUNT=<access-key> [PASSWORD=<new-secret>])
	@[ "$(origin SERVICE_ACCOUNT)" = "command line" ] || { echo "ERROR: pass SERVICE_ACCOUNT=<access-key> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	_pw='$(if $(filter command line,$(origin PASSWORD)),$(PASSWORD),)'; \
	_pw="$${_pw:-$$(openssl rand -hex 24)}"; \
	$(MCLI) $(INSECURE) admin user svcacct edit $${ALIAS} $(SERVICE_ACCOUNT) \
	  --secret-key "$$_pw"; \
	echo "rotated: SERVICE_ACCOUNT=$(SERVICE_ACCOUNT) PASSWORD=$$_pw"

.PHONY: svcacct-list
svcacct-list:  ## list service accounts for USER (USER=<parent-access-key>)
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<parent-access-key> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(MCLI) $(INSECURE) admin user svcacct ls $${ALIAS} $(USER)

.PHONY: svcacct-info
svcacct-info:  ## show info for service account (SERVICE_ACCOUNT=<access-key>)
	@[ "$(origin SERVICE_ACCOUNT)" = "command line" ] || { echo "ERROR: pass SERVICE_ACCOUNT=<access-key> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(MCLI) $(INSECURE) admin user svcacct info $${ALIAS} $(SERVICE_ACCOUNT)

.PHONY: svcacct-remove
svcacct-remove:  ## remove service account (SERVICE_ACCOUNT=<access-key>)
	@[ "$(origin SERVICE_ACCOUNT)" = "command line" ] || { echo "ERROR: pass SERVICE_ACCOUNT=<access-key> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(MCLI) $(INSECURE) admin user svcacct rm $${ALIAS} $(SERVICE_ACCOUNT); \
	echo "removed: SERVICE_ACCOUNT=$(SERVICE_ACCOUNT)"
