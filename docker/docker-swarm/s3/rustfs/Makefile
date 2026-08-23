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

MINIO_CLI_NAME  ?= mcli
MINIO_CLI       ?= /usr/local/bin/$(MINIO_CLI_NAME)
MCLI            ?= $(MINIO_CLI)
RUSTFS_CLI_NAME ?= rcli
RUSTFS_CLI      ?= /usr/local/bin/$(RUSTFS_CLI_NAME)
RCLI            ?= $(RUSTFS_CLI)
INSECURE        ?= --insecure

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
# ALIAS and SERVER can be overridden on the command line (e.g. ALIAS=rustfs-alice)
# because _source_env uses ${ALIAS:-default} — command-line vars are already in
# the environment before .env is sourced, and .env does not set ALIAS/SERVER.
# USERNAME and PASSWORD are NOT defaulted here — targets that need creds
# must set their own defaults or require explicit values via _chk_var.
define _source_env
	[ -f ./.env ] || { echo "ERROR: .env not found — cp .env.example .env" >&2; exit 1; }; \
	set -a; . ./.env; set +a; \
	: "$${S3_HOST:?S3_HOST not set in .env}"; \
	: "$${WEBSECURE_PORT:=19001}"; \
	ALIAS=$${ALIAS:-$$(cat .active_alias 2>/dev/null || echo rustfs)}; \
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
test:  ## run smoke test (requires running stack and rcli on PATH)
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
	@echo "  1. make alias-set              (reconfigure rcli alias)"
	@echo "  2. Update all S3 clients with the new credentials"

##@ CLI — S3-level (RustFS)

.PHONY: install-rcli
install-rcli:  ## download and install rcli (RustFS native CLI) to /usr/local/bin
	@_arch=$$(lscpu | grep -Po '^Architecture:\s+\K\S+' | sed 's/x86_64/amd64/; s/aarch64/arm64/') && \
	_ver=v0.1.31 && \
	_tar="rustfs-cli-linux-$${_arch}-$${_ver}.tar.gz" && \
	curl -fLO "https://github.com/rustfs/cli/releases/download/$${_ver}/$${_tar}" && \
	tar -xzf "$$_tar" rc && \
	sudo install -m 0755 rc /usr/local/bin/$(RUSTFS_CLI_NAME) && \
	rm -f rc "$$_tar" && \
	$(RCLI) --version

.PHONY: install-mcli
install-mcli:  ## download and install mcli (MinIO client, legacy fallback) to /usr/local/bin
	@_arch=$$(lscpu | grep -Po '^Architecture:\s+\K\S+' | sed 's/x86_64/amd64/; s/aarch64/arm64/') && \
	curl https://dl.min.io/client/mc/release/linux-$${_arch}/mc \
	  --create-dirs -o $${HOME}/minio-binaries/$(MINIO_CLI_NAME) && \
	chmod +x $${HOME}/minio-binaries/$(MINIO_CLI_NAME) && \
	sudo install $${HOME}/minio-binaries/$(MINIO_CLI_NAME) /usr/local/bin && \
	rm -rf $${HOME}/minio-binaries && \
	$(MCLI) --version

.PHONY: alias-create
ifneq (command line,$(origin ALIAS))
alias-create:
	@echo "ERROR: ALIAS= required (e.g. make alias-create ALIAS=alice ACCESS_KEY=alice SECRET_KEY=alice123)" >&2; exit 1
else
alias-create:  ## register a named alias  ALIAS=<name> ACCESS_KEY=<key> SECRET_KEY=<secret>  (does NOT change active alias)
	@$(call _source_env); \
	: "$${ACCESS_KEY:?ACCESS_KEY= required}"; \
	: "$${SECRET_KEY:?SECRET_KEY= required}"; \
	$(RCLI) alias set $${ALIAS} $${SERVER} $${ACCESS_KEY} $${SECRET_KEY} $(INSECURE) && \
	echo "Alias '$$ALIAS' registered (active alias unchanged)."
endif

.PHONY: alias-set
ifeq (command line,$(origin ALIAS))
# ALIAS= given on command line: switch active alias (alias must already exist via alias-create)
alias-set:  ## set active alias — no ALIAS=: recreate root 'rustfs' from Docker secrets + activate; ALIAS=<name>: activate existing alias
	@printf '%s' '$(ALIAS)' > .active_alias; \
	echo "Active alias switched to '$(ALIAS)'."
else
# No ALIAS= on command line: create/update root alias from Docker secrets + activate
alias-set:
	@$(call _source_env); \
	ALIAS=rustfs; \
	$(call _read_secrets); \
	_u=$${USERNAME:-$$_ak}; \
	_p=$${PASSWORD:-$$_sk}; \
	$(RCLI) alias set $${ALIAS} $${SERVER} $${_u} $${_p} $(INSECURE); \
	printf '%s' "$$ALIAS" > .active_alias; \
	echo "Alias '$$ALIAS' configured and set as active."
endif

.PHONY: alias-rm
ifneq (command line,$(origin ALIAS))
alias-rm:
	@echo "ERROR: ALIAS= required (e.g. make alias-rm ALIAS=alice)" >&2; exit 1
else
alias-rm:  ## remove a named alias  ALIAS=<name>  (must differ from active alias)
	@$(call _source_env); \
	_active=$$(cat .active_alias 2>/dev/null || echo rustfs); \
	if [ "$$ALIAS" = "$$_active" ]; then \
		echo "ERROR: cannot remove active alias '$$ALIAS' — switch first with: make alias-set" >&2; exit 1; \
	fi; \
	$(RCLI) alias remove $${ALIAS} && echo "Alias '$$ALIAS' removed."
endif

.PHONY: alias-info
alias-info:  ## show info for an alias  [ALIAS=<name>]  (defaults to active alias)
	@$(call _source_env); \
	$(RCLI) alias list | grep "^$${ALIAS}[[:space:]]" || { echo "Alias '$$ALIAS' not found."; exit 1; }

.PHONY: alias-list
alias-list:  ## list all configured rcli aliases  (* marks active)
	@_active=$$(cat .active_alias 2>/dev/null || echo rustfs); \
	$(RCLI) alias list | awk -v a="$$_active" '{ printf "%s %s\n", ($$1==a?"*":" "), $$0 }'

.PHONY: bucket-create
bucket-create:  ## create bucket (BUCKET=<name> [USER=<owner>] [FLAGS=...])
	@$(call _source_env); \
	$(call _chk_var,BUCKET); \
	_user='$(if $(filter command line,$(origin USER)),$(USER),)'; \
	_name="$${_user:+$${_user}-}$(BUCKET)"; \
	$(RCLI) mb $${FLAGS} $${ALIAS}/$$_name

.PHONY: bucket-list
bucket-list:  ## list buckets, or objects if BUCKET is set (BUCKET=<name>)
	@$(call _source_env); \
	$(RCLI) ls $${ALIAS}/$${BUCKET}

.PHONY: bucket-remove
bucket-remove:  ## remove bucket (BUCKET=<name>; FORCE=1 to remove a non-empty bucket)
	@$(call _source_env); \
	$(call _chk_var,BUCKET); \
	$(RCLI) rb $${FORCE:+--force} $${ALIAS}/$${BUCKET}

.PHONY: bucket-anonymous-download
bucket-anonymous-download:  ## set anonymous download policy on bucket (BUCKET=<name>)
	@$(call _source_env); \
	$(call _chk_var,BUCKET); \
	$(RCLI) anonymous set download $${ALIAS}/$${BUCKET}

##@ User provisioning

.PHONY: user-create
user-create:  ## create user + own-buckets RW policy (USER=<name> [PASSWORD=<...>])
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<name> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	pw="$${PASSWORD:-$$(openssl rand -hex 24)}"; \
	pol=$$(mktemp); sed 's/__USER__/$(USER)/g' policies/user-rw.json.tpl > "$$pol"; \
	$(RCLI) admin policy detach $${ALIAS} $(USER)-rw --user $(USER) 2>/dev/null || true; \
	$(RCLI) admin policy remove $${ALIAS} $(USER)-rw 2>/dev/null || true; \
	$(RCLI) admin policy create $${ALIAS} $(USER)-rw "$$pol"; \
	$(RCLI) admin user remove $${ALIAS} $(USER) 2>/dev/null || true; \
	$(RCLI) admin user add $${ALIAS} $(USER) "$$pw"; \
	$(RCLI) admin policy attach $${ALIAS} $(USER)-rw --user $(USER); \
	rm -f "$$pol"; \
	echo "created: USER=$(USER) PASSWORD=$$pw POLICY=$(USER)-rw"

.PHONY: user-delete
user-delete:  ## delete user + policy (USER=<name>; DELETE_BUCKETS=1 removes <name>-* buckets; FORCE=1 also non-empty)
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<name> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(RCLI) admin policy detach $${ALIAS} $(USER)-rw --user $(USER) 2>/dev/null || true; \
	$(RCLI) admin user remove $${ALIAS} $(USER) 2>/dev/null || true; \
	$(RCLI) admin policy remove $${ALIAS} $(USER)-rw 2>/dev/null || true; \
	if [ -n "$(DELETE_BUCKETS)" ]; then \
	  for b in $$($(RCLI) ls $${ALIAS}/ | awk '{print $$NF}' | sed 's#/##' | grep '^$(USER)-'); do \
	    $(RCLI) rb $${FORCE:+--force} $${ALIAS}/$$b; done; \
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
	$(RCLI) ls $${ALIAS}/ 2>/dev/null \
	  | grep ' $(USER)-' || echo "(no buckets)"; \
	echo ""; \
	echo "=== Service accounts ==="; \
	$(RCLI) admin service-account ls $${ALIAS} --user $(USER) 2>/dev/null \
	  || echo "(none or user not found)"

##@ Admin — RustFS admin API

.PHONY: user-add
user-add:  ## add user (USER=<access-key> PASSWORD=<secret-key>)
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<name> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(call _chk_var,PASSWORD); \
	$(RCLI) admin user add $${ALIAS} $(USER) $${PASSWORD}

.PHONY: user-remove
user-remove:  ## remove user (USER=<access-key>)
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<name> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(RCLI) admin user remove $${ALIAS} $(USER)

.PHONY: user-list
user-list:  ## list users
	@$(call _source_env); \
	$(RCLI) admin user list $${ALIAS}

.PHONY: user-disable
user-disable:  ## disable user (USER=<access-key>)
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<name> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(RCLI) admin user disable $${ALIAS} $(USER)

.PHONY: user-enable
user-enable:  ## enable user (USER=<access-key>)
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<name> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(RCLI) admin user enable $${ALIAS} $(USER)

.PHONY: admin-info
admin-info:  ## get server info
	@$(call _source_env); \
	$(RCLI) admin info cluster $${ALIAS}

.PHONY: admin-policy-create
admin-policy-create:  ## create policy (POLICY=<name> FILE=<path>)
	@$(call _source_env); \
	$(call _chk_vars,"POLICY FILE"); \
	$(RCLI) admin policy create $${ALIAS} $${POLICY} $${FILE}

.PHONY: admin-policy-remove
admin-policy-remove:  ## remove policy (POLICY=<name>)
	@$(call _source_env); \
	$(call _chk_var,POLICY); \
	$(RCLI) admin policy remove $${ALIAS} $${POLICY}

.PHONY: admin-policy-list
admin-policy-list:  ## list policies
	@$(call _source_env); \
	$(RCLI) admin policy list $${ALIAS}

.PHONY: admin-policy-info
admin-policy-info:  ## get policy info (POLICY=<name>)
	@$(call _source_env); \
	$(call _chk_var,POLICY); \
	$(RCLI) admin policy info $${ALIAS} $${POLICY}

.PHONY: admin-policy-entities
admin-policy-entities:  ## list entities attached to policy (POLICY=<name> [FLAGS='--user <key>'])
	@$(call _source_env); \
	$(call _chk_var,POLICY); \
	$(RCLI) admin policy entities $${ALIAS} $${POLICY} $${FLAGS}

.PHONY: admin-policy-attach
admin-policy-attach:  ## attach policy to user or group (POLICY=<name> FLAGS='--user <key>' | FLAGS='--group <name>')
	@$(call _source_env); \
	$(call _chk_vars,"POLICY FLAGS"); \
	$(RCLI) admin policy attach $${ALIAS} $${POLICY} $${FLAGS}

.PHONY: admin-policy-detach
admin-policy-detach:  ## detach policy from user or group (POLICY=<name> FLAGS='--user <key>' | FLAGS='--group <name>')
	@$(call _source_env); \
	$(call _chk_vars,"POLICY FLAGS"); \
	$(RCLI) admin policy detach $${ALIAS} $${POLICY} $${FLAGS}

##@ Health

.PHONY: ping
ping:  ## check if RustFS service is reachable
	@$(call _source_env); \
	$(RCLI) ping $${ALIAS}

.PHONY: ready
ready:  ## check if RustFS dependencies are ready
	@$(call _source_env); \
	$(RCLI) ready $${ALIAS}

##@ Service accounts

# Service accounts are sub-credentials created under the alias's authenticated
# user (always the alias's authenticated user — rcli does not support specifying
# a different parent; use ALIAS=<user-alias> for per-user SAs).
# They inherit that user's policy and their secret key can be rotated online.
# rcli positional: <ALIAS> <NEW_SA_ACCESS_KEY> <NEW_SA_SECRET_KEY>

.PHONY: svcacct-create
svcacct-create:  ## create service account  [ALIAS=<alias>] [SERVICE_ACCOUNT=<new-access-key>] [PASSWORD=<new-secret-key>] [EXPIRY=<ISO8601>]
	@$(call _source_env); \
	_sa='$(if $(filter command line,$(origin SERVICE_ACCOUNT)),$(SERVICE_ACCOUNT),)'; \
	_sa="$${_sa:-SA$$(openssl rand -hex 9 | tr 'a-f' 'A-F')}"; \
	_pw=$${PASSWORD:-$$(openssl rand -hex 16)}; \
	_expiry='$(if $(filter command line,$(origin EXPIRY)),--expiry $(EXPIRY),)'; \
	$(RCLI) --json admin service-account create $${ALIAS} "$$_sa" "$$_pw" $$_expiry \
	  || { echo "ERROR: svcacct-create failed" >&2; exit 1; }; \
	echo "SERVICE_ACCOUNT=$$_sa PASSWORD=$$_pw"

.PHONY: svcacct-rotate
svcacct-rotate:  ## rotate service account secret key online (SERVICE_ACCOUNT=<access-key> [PASSWORD=<new-secret>])
	@[ "$(origin SERVICE_ACCOUNT)" = "command line" ] || { echo "ERROR: pass SERVICE_ACCOUNT=<access-key> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	_pw='$(if $(filter command line,$(origin PASSWORD)),$(PASSWORD),)'; \
	_pw="$${_pw:-$$(openssl rand -hex 24)}"; \
	$(RCLI) admin service-account update $${ALIAS} $(SERVICE_ACCOUNT) \
	  --secret-key "$$_pw"; \
	echo "rotated: SERVICE_ACCOUNT=$(SERVICE_ACCOUNT) PASSWORD=$$_pw"

.PHONY: svcacct-list
svcacct-list:  ## list service accounts  USER=<username> (e.g. root, alice)  [ALIAS=<alias>]
	@[ "$(origin USER)" = "command line" ] || { echo "ERROR: pass USER=<username> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(RCLI) admin service-account ls $${ALIAS} --user $(USER)

.PHONY: svcacct-info
svcacct-info:  ## show info for service account (SERVICE_ACCOUNT=<access-key>)
	@[ "$(origin SERVICE_ACCOUNT)" = "command line" ] || { echo "ERROR: pass SERVICE_ACCOUNT=<access-key> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(RCLI) admin service-account info $${ALIAS} $(SERVICE_ACCOUNT)

.PHONY: svcacct-remove
svcacct-remove:  ## remove service account (SERVICE_ACCOUNT=<access-key>)
	@[ "$(origin SERVICE_ACCOUNT)" = "command line" ] || { echo "ERROR: pass SERVICE_ACCOUNT=<access-key> on the command line" >&2; exit 1; }
	@$(call _source_env); \
	$(RCLI) admin service-account rm $${ALIAS} $(SERVICE_ACCOUNT); \
	echo "removed: SERVICE_ACCOUNT=$(SERVICE_ACCOUNT)"
