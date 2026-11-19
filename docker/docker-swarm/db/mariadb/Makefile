SHELL := /bin/bash

# ---------- Global variables ----------
PROJECT_NAME         ?= mariadb-lts
ENV                  ?= prod
STACK_NAME           ?= mariadb-lts
SERVICE              ?= db
PROJECTS_DIR         ?= $(HOME)/projects
DEPLOY_DIR            = $(PROJECTS_DIR)/$(PROJECT_NAME)/dswarm/$(ENV)/deploy
COMPOSE_FILE          = $(DEPLOY_DIR)/stack.yml
LOG_FILE              = $(DEPLOY_DIR)/deploy.log
# Extra rsync exclude patterns for deploy-sync (space-separated)
DEPLOY_EXCLUDES      ?=

# Value of KEY from the host's $(DEPLOY_DIR)/.env (last match), or empty.
# Reads only that key — the file is not include'd, so $ or quotes in other
# values cannot break make.
_host_env = $(shell sed -n 's/^$(1)=//p' "$(DEPLOY_DIR)/.env" 2>/dev/null | tail -1)

# Directory holding this Makefile (the stack directory of a git checkout)
STACK_SRC_DIR        := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# ---------- Per-host settings ----------
# Precedence: command line > environment > host .env > default.
# Published host port of the db service
DB_PORT              ?= $(or $(call _host_env,DB_PORT),23306)
# Data volume; must exist before stack-deploy (stack.yml never creates it)
DB_VOLUME            ?= $(or $(call _host_env,DB_VOLUME),$(STACK_NAME)_db_data)
# Docker root dir for the volume guard in stack.yml (detected when used)
DOCKER_ROOT_DIR      ?= $(shell docker info --format '{{.DockerRootDir}}' 2>/dev/null)
# Replication role: empty = standalone (no binlog), primary or replica
DB_ROLE              ?= $(call _host_env,DB_ROLE)
# server_id, unique per server of a replication pair
SERVER_ID            ?= $(or $(call _host_env,SERVER_ID),1)
# Rendered into replication.cnf: a replica is read-only across restarts.
# NO_LOCK_NO_ADMIN: with ON, users holding READ ONLY ADMIN (root) still write.
DB_READ_ONLY          = $(if $(filter replica,$(DB_ROLE)),NO_LOCK_NO_ADMIN,0)
# 12.3.3 aborts at startup with read_only=NO_LOCK_NO_ADMIN unless the event
# scheduler is DISABLED (it cannot open mysql.event). OFF = current default.
DB_EVENT_SCHEDULER    = $(if $(filter replica,$(DB_ROLE)),DISABLED,OFF)

# Test-only targets refuse unless STACK_NAME / DB_VOLUME start with this
TEST_PREFIX          := mariadb-test

# ---------- Backup / restore ----------
# Snapshots of db-backup (contain password hashes — never in git)
BU_DIR               ?= $(PROJECTS_DIR)/$(PROJECT_NAME)/bu/$(ENV)
# Server image, from the stack file next to this Makefile (pinned by digest)
DB_IMAGE             ?= $(shell sed -n 's/^ *image: *//p' "$(STACK_SRC_DIR)stack.yml" | head -1)
# db-backup of a compose container instead of the swarm task (migration)
SOURCE_CONTAINER     ?=

# ---------- Replication ----------
REPL_USER            ?= repl
PRIMARY_PORT         ?= 23306

# ---------- Secrets ----------
# MARIADB_ROOT_PASSWORD has no default: only an explicit value (command line
# or environment) is used. It reaches the scripts through the environment
# (export below), never through a command line.
SECRET_PREFIX        ?= $(STACK_NAME)
SECRET_ROOT_PASSWORD ?= $(SECRET_PREFIX)_root_password
SECRET_REPL_PASSWORD ?= $(SECRET_PREFIX)_repl_password
export MARIADB_ROOT_PASSWORD MARIADB_REPL_PASSWORD

# ---------- Configs ----------
CONFIG_PREFIX        ?= $(STACK_NAME)
CONFIG_MY_CNF        ?= $(CONFIG_PREFIX)_my_cnf
CONFIG_REPL_CNF      ?= $(CONFIG_PREFIX)_repl_cnf

# ---------- Config source files ----------
CONFIGS_DIR           = $(DEPLOY_DIR)/configs
CONFIG_MY_CNF_SRC     = $(CONFIGS_DIR)/my.cnf
CONFIG_REPL_CNF_SRC   = $(CONFIGS_DIR)/replication/$(if $(DB_ROLE),replication.cnf,standalone.cnf)

# ---------- Reload ----------
RELOAD_TIMEOUT       ?= 300

# ---------- Config / secret registry ----------
# Single source of truth for configs-create/-check/-status, cleanup and reload.
# Config entry: <docker-name>|<source-file>|<envsubst vars, comma-separated>
#   (empty var list = copied verbatim)
CONFIG_REGISTRY = \
	$(CONFIG_MY_CNF)|$(CONFIG_MY_CNF_SRC)| \
	$(CONFIG_REPL_CNF)|$(CONFIG_REPL_CNF_SRC)|SERVER_ID,DB_READ_ONLY,DB_EVENT_SCHEDULER
# Secret entry: <docker-name>|<variable holding the value>
SECRET_REGISTRY = \
	$(SECRET_ROOT_PASSWORD)|MARIADB_ROOT_PASSWORD \
	$(SECRET_REPL_PASSWORD)|MARIADB_REPL_PASSWORD
# Variables given on the command line or in the environment. Only these may
# supply secret values for comparison — never a default.
EXPLICIT_VARS = $(foreach v,MARIADB_ROOT_PASSWORD MARIADB_REPL_PASSWORD,\
	$(if $(or $(findstring command line,$(origin $(v))),$(findstring environment,$(origin $(v)))),$(v)))

# Validation run by reload-service before swapping, with the service's own image.
# Entry: <docker-name>|mariadbd; configs not listed are not validated.
CONFIG_VALIDATORS = \
	$(CONFIG_MY_CNF)|mariadbd \
	$(CONFIG_REPL_CNF)|mariadbd

SCRIPTS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts
_SCRIPT_ENV = CONFIG_REGISTRY="$(CONFIG_REGISTRY)" SECRET_REGISTRY="$(SECRET_REGISTRY)" \
	CONFIG_VALIDATORS="$(CONFIG_VALIDATORS)" EXPLICIT_VARS="$(strip $(EXPLICIT_VARS))" \
	STACK_NAME="$(STACK_NAME)" SERVICE="$(SERVICE)" DB_VOLUME="$(DB_VOLUME)" \
	DRY_RUN="$(DRY_RUN)" FORCE="$(FORCE)" CONFIRM="$(CONFIRM)" RELOAD_TIMEOUT="$(RELOAD_TIMEOUT)" \
	DB="$(DB)" SOURCE_CONTAINER="$(SOURCE_CONTAINER)" \
	DB_ROLE="$(DB_ROLE)" SERVER_ID="$(SERVER_ID)" DB_READ_ONLY="$(DB_READ_ONLY)" \
	DB_EVENT_SCHEDULER="$(DB_EVENT_SCHEDULER)"
_CONFIGS = $(_SCRIPT_ENV) bash "$(SCRIPTS_DIR)/configs.sh"
_RELOAD  = $(_SCRIPT_ENV) bash "$(SCRIPTS_DIR)/reload-service.sh"
_CLEANUP = $(_SCRIPT_ENV) CONFIGS="$(CONFIGS)" SECRETS="$(SECRETS)" VOLUMES="$(VOLUMES)" \
	bash "$(SCRIPTS_DIR)/cleanup.sh"
_DB_CMD  = $(_SCRIPT_ENV) SQL="$$SQL" bash "$(SCRIPTS_DIR)/db-cmd.sh"
_REPL    = $(_SCRIPT_ENV) PRIMARY_HOST="$(PRIMARY_HOST)" PRIMARY_PORT="$(PRIMARY_PORT)" \
	REPLICA_HOST="$(REPLICA_HOST)" REPL_USER="$(REPL_USER)" GTID_POS="$(GTID_POS)" FILE="$(FILE)" \
	BU_DIR="$(BU_DIR)" DEPLOY_DIR="$(DEPLOY_DIR)" bash "$(SCRIPTS_DIR)/repl.sh"

# ---------- Helpers ----------
_CID = $$(docker ps -q -f label=com.docker.swarm.service.name=$(STACK_NAME)_$(SERVICE) | head -1)

.DEFAULT_GOAL := help

# ---------- Help ----------
.PHONY: help
help: ## Show this help message
	@echo "$(STACK_NAME) Stack (Docker Swarm)"
	@echo "Available commands:"
	@echo ""
	@printf "%-35s %s\n" "COMMAND" "DESCRIPTION"
	@printf "%-35s %s\n" "-------" "-----------"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "%-35s %s\n", $$1, $$2}' | sort
	@echo ""
	@echo "Examples:"
	@echo "  make init"
	@echo "  make deploy-sync"
	@echo "  make env-init"
	@echo "  MARIADB_ROOT_PASSWORD=... make secrets-create"
	@echo "  make configs-create"
	@echo "  make stack-deploy"
	@echo "  make db-cmd SQL='SHOW DATABASES'"
	@echo "  make db-backup"
	@echo "  make db-backup SOURCE_CONTAINER=mariadb-lts-db-1"
	@echo "  make db-restore FILE=<snapshot.tar.gz> CONFIRM=yes"
	@echo "  make volume-from-snapshot SNAPSHOT=<snapshot.tar.gz> CONFIRM=yes"
	@echo "  make reload-service"
	@echo "  make logs"

# ---------- Init ----------
.PHONY: init
init: ## Initialize deploy directory
	@mkdir -p "$(DEPLOY_DIR)"
	@touch "$(LOG_FILE)"
	@echo "Initialized: $(DEPLOY_DIR)"

.PHONY: env-init
env-init: ## Create $(DEPLOY_DIR)/.env with defaults (safe — skips if exists)
	@mkdir -p "$(DEPLOY_DIR)"
	@if [ -f "$(DEPLOY_DIR)/.env" ]; then \
		echo "Already exists: $(DEPLOY_DIR)/.env"; \
	else \
		printf '%s\n' "# Published host port of the db service (mode: host), default 23306" \
			"# DB_PORT=23306" \
			"# Data volume; must exist before stack-deploy, default <STACK_NAME>_db_data" \
			"# DB_VOLUME=$(STACK_NAME)_db_data" \
			"# Replication role: empty = standalone, primary or replica (then: make reload-service)" \
			"# DB_ROLE=" \
			"# server_id, unique within a replication pair, default 1" \
			"# SERVER_ID=1" > "$(DEPLOY_DIR)/.env"; \
		echo "Created: $(DEPLOY_DIR)/.env — edit before deploying"; \
	fi

.PHONY: deploy-sync
deploy-sync: ## Copy stack files from this checkout to DEPLOY_DIR (keeps host .env; DRY_RUN=1 = preview)
	@src="$(STACK_SRC_DIR)"; dst="$(DEPLOY_DIR)"; \
	[ "$$(realpath -m "$${src}")" != "$$(realpath -m "$${dst}")" ] \
		|| { echo "Source is DEPLOY_DIR itself — run make from the git checkout"; exit 1; }; \
	$(if $(filter 1 y yes true,$(DRY_RUN)),echo "DRY_RUN — nothing is copied";,mkdir -p "$${dst}";) \
	echo "Syncing $${src} -> $${dst}/"; \
	rsync -av $(if $(filter 1 y yes true,$(DRY_RUN)),--dry-run) \
		--exclude=.git --exclude=/.env --exclude=/deploy.log \
		$(foreach e,$(DEPLOY_EXCLUDES),--exclude=$(e)) \
		"$${src}" "$${dst}/"

# ---------- Checks ----------
.PHONY: check-swarm
check-swarm: ## Verify Docker Swarm is active
	@docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active" || \
		{ echo "Swarm not active. Run: docker swarm init"; exit 1; }
	@echo "Swarm: active"

.PHONY: check-env
check-env: ## Validate stack file and .env presence
	@[ -f "$(COMPOSE_FILE)" ]    || { echo "Missing stack file: $(COMPOSE_FILE) — run: make deploy-sync"; exit 1; }
	@[ -n "$(PROJECT_NAME)" ]    || { echo "PROJECT_NAME= required"; exit 1; }
	@[ -n "$(STACK_NAME)" ]      || { echo "STACK_NAME= required";   exit 1; }
	@[ -f "$(DEPLOY_DIR)/.env" ] || { echo "Missing: $(DEPLOY_DIR)/.env — run: make env-init"; exit 1; }

.PHONY: check-tools
check-tools: ## Verify required tools are installed
	@for tool in docker rsync envsubst; do \
		command -v $${tool} >/dev/null || { echo "Install $${tool}"; exit 1; }; \
	done

.PHONY: check-volume
check-volume: ## Verify the data volume DB_VOLUME exists
	@docker volume inspect "$(DB_VOLUME)" >/dev/null 2>&1 \
		&& echo "OK: volume $(DB_VOLUME)" \
		|| { echo "MISSING: volume $(DB_VOLUME) — stack-deploy never creates it (test stacks: make volume-create)" >&2; exit 1; }
	@[ -n "$(DOCKER_ROOT_DIR)" ] || { echo "Cannot detect DOCKER_ROOT_DIR (docker info)" >&2; exit 1; }
	@mp=$$(docker volume inspect -f '{{.Driver}} {{.Mountpoint}}' "$(DB_VOLUME)"); \
	[ "$${mp}" = "local $(DOCKER_ROOT_DIR)/volumes/$(DB_VOLUME)/_data" ] \
		|| { echo "Volume guard in stack.yml expects a local volume under $(DOCKER_ROOT_DIR)/volumes, got: $${mp}" >&2; exit 1; }

# ---------- Secrets ----------
.PHONY: secrets-create
secrets-create: ## Create the root / replication password secrets (MARIADB_ROOT_PASSWORD= MARIADB_REPL_PASSWORD=; skips existing)
	@$(_CONFIGS) secrets-create

.PHONY: secrets-check
secrets-check: ## Verify required secrets exist in swarm
	@$(_CONFIGS) secrets-check || { echo "Run: MARIADB_ROOT_PASSWORD=... MARIADB_REPL_PASSWORD=... make secrets-create"; exit 1; }

.PHONY: secrets-list
secrets-list: ## List Docker secrets of this stack
	@docker secret ls -f name=$(SECRET_PREFIX)_

# ---------- Configs ----------
.PHONY: configs-create
configs-create: ## Create all Docker configs (skips existing ones)
	@$(_CONFIGS) create

.PHONY: configs-check
configs-check: ## Verify required Docker configs exist
	@$(_CONFIGS) check || { echo "Run: make configs-create"; exit 1; }

.PHONY: configs-status
configs-status: ## Compare live configs/secrets with repo sources (OK/CHANGED/MISSING/UNKNOWN/SKIPPED)
	@$(_CONFIGS) status

.PHONY: configs-list
configs-list: ## List Docker configs of this stack
	@docker config ls -f name=$(CONFIG_PREFIX)_

.PHONY: reload-service
reload-service: ## Apply changed configs/secrets to the service (SERVICE=db; restarts it twice; DRY_RUN=1, FORCE=1)
	@test -n "$(SERVICE)" || { echo "SERVICE= required"; exit 1; }
	@$(_RELOAD) "$(SERVICE)"

# ---------- Volume ----------
.PHONY: volume-create
volume-create: ## Create an empty data volume — test stacks only (STACK_NAME=mariadb-test*)
	@case "$(STACK_NAME)|$(DB_VOLUME)" in \
		$(TEST_PREFIX)*"|"$(TEST_PREFIX)*) ;; \
		*) echo "Refused: volume-create is for test stacks only (STACK_NAME and DB_VOLUME must start with $(TEST_PREFIX))" >&2; exit 1 ;; \
	esac
	@docker volume inspect "$(DB_VOLUME)" >/dev/null 2>&1 \
		&& echo "Already exists: $(DB_VOLUME)" \
		|| { docker volume create "$(DB_VOLUME)" >/dev/null && echo "Created: $(DB_VOLUME)"; }

# ---------- Stack management ----------
.PHONY: stack-deploy
stack-deploy: check-swarm check-env check-tools secrets-check configs-check check-volume ## Deploy the stack (DB_VOLUME must exist)
	@echo "Deploying stack '$(STACK_NAME)' from: $(COMPOSE_FILE) (volume $(DB_VOLUME), port $(DB_PORT))"
	@set -a && source "$(DEPLOY_DIR)/.env" && set +a && \
	CONFIG_PREFIX="$(CONFIG_PREFIX)" SECRET_PREFIX="$(SECRET_PREFIX)" \
	DB_PORT="$(DB_PORT)" DB_VOLUME="$(DB_VOLUME)" DOCKER_ROOT_DIR="$(DOCKER_ROOT_DIR)" \
	docker stack deploy --detach=true --with-registry-auth -c "$(COMPOSE_FILE)" "$(STACK_NAME)" \
		2>&1 | tee -a "$(LOG_FILE)"
	@echo "Deployed. Check: make stack-health"

.PHONY: stack-rm
stack-rm: ## Remove the stack (data volume, secrets and configs stay)
	@echo "Removing stack '$(STACK_NAME)'..."
	@docker stack rm "$(STACK_NAME)"
	@echo "Waiting for full removal..."; \
	timeout 180 bash -c \
		'until [ -z "$$(docker ps -aq -f label=com.docker.stack.namespace=$(STACK_NAME))" ]; do sleep 2; done' \
		|| echo "Warning: timeout waiting for stack removal"
	@echo "Stack removed"

.PHONY: docker-cleanup
docker-cleanup: ## Remove leftovers after stack-rm (CONFIGS=1 SECRETS=1 VOLUMES=1 + CONFIRM=yes; no flag = list)
	@$(_CLEANUP)

.PHONY: stack-health
stack-health: ## Check the stack now: service converged, task Running, container healthy
	@STACK_NAME="$(STACK_NAME)" bash "$(SCRIPTS_DIR)/stack-health.sh"

# ---------- Service management ----------
.PHONY: service-update
service-update: ## Force update (restart) the service (SERVICE=db)
	@test -n "$(SERVICE)" || { echo "SERVICE= required"; exit 1; }
	@echo "Force-updating $(STACK_NAME)_$(SERVICE)..."
	@docker service update --force --detach=false $(STACK_NAME)_$(SERVICE)

.PHONY: service-rollback
service-rollback: ## Rollback the service to its previous spec (SERVICE=db)
	@test -n "$(SERVICE)" || { echo "SERVICE= required"; exit 1; }
	@echo "Rolling back $(STACK_NAME)_$(SERVICE)..."
	@docker service rollback $(STACK_NAME)_$(SERVICE)
	@echo "Rollback initiated. Check: make ps"

.PHONY: ps
ps: ## Show stack task status
	@docker stack ps "$(STACK_NAME)"

.PHONY: status
status: ## Show service running status
	@docker stack services "$(STACK_NAME)"

.PHONY: stats
stats: ## Show resource usage of the stack's containers
	@ids=$$(docker ps -q -f label=com.docker.stack.namespace=$(STACK_NAME)); \
	[ -n "$${ids}" ] || { echo "No running containers of $(STACK_NAME)"; exit 1; }; \
	docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" $${ids}

# ---------- Logs ----------
.PHONY: logs
logs: ## Follow service logs (SERVICE=db)
	@test -n "$(SERVICE)" || { echo "SERVICE= required"; exit 1; }
	@docker service logs -f $(STACK_NAME)_$(SERVICE)

# ---------- Exec ----------
.PHONY: exec
exec: require-container ## Open a shell inside the running container (no DB clients here — use db-cmd)
	@docker exec -it $(_CID) bash

# ---------- Database ----------
.PHONY: db-cmd
db-cmd: ## Run SQL as root in a separate client container (SQL= required; DB= optional)
	@$(_DB_CMD)

.PHONY: db-counts
db-counts: ## Exact row count per application table, sorted (SOURCE_CONTAINER= for a compose container)
	@$(_SCRIPT_ENV) bash "$(SCRIPTS_DIR)/db-counts.sh"

.PHONY: db-upgrade
db-upgrade: ## mariadb-upgrade for the running image, datadir mounted; verify (FORCE=1 = run again)
	@$(_SCRIPT_ENV) bash "$(SCRIPTS_DIR)/db-upgrade.sh"

.PHONY: healthcheck-check
healthcheck-check: ## Do the healthcheck@ accounts match .my-healthcheck.cnf? (SOURCE_CONTAINER= for a compose container)
	@$(_SCRIPT_ENV) bash "$(SCRIPTS_DIR)/healthcheck.sh" check

.PHONY: healthcheck-fix
healthcheck-fix: ## Set the healthcheck@ passwords from .my-healthcheck.cnf, no binlog (CONFIRM=yes; SOURCE_CONTAINER=)
	@$(_SCRIPT_ENV) bash "$(SCRIPTS_DIR)/healthcheck.sh" fix

.PHONY: db-backup
db-backup: ## Snapshot to BU_DIR: physical + dump + users (SOURCE_CONTAINER= for a compose container)
	@mkdir -p "$(BU_DIR)"
	@$(_SCRIPT_ENV) BU_DIR="$(BU_DIR)" bash "$(SCRIPTS_DIR)/db-backup.sh"

.PHONY: db-restore
db-restore: ## Logical restore into the running stack (FILE=<snapshot.tar.gz|dump.sql.gz> CONFIRM=yes; DB=, NO_BINLOG=yes)
	@$(_SCRIPT_ENV) FILE="$(FILE)" NO_BINLOG="$(NO_BINLOG)" bash "$(SCRIPTS_DIR)/db-restore.sh"

.PHONY: volume-from-snapshot
volume-from-snapshot: ## Physical restore into empty, unused DB_VOLUME (SNAPSHOT= CONFIRM=yes; RESET_ROOT=yes test only)
	@$(_SCRIPT_ENV) SNAPSHOT="$(SNAPSHOT)" RESET_ROOT="$(RESET_ROOT)" DB_IMAGE="$(DB_IMAGE)" \
		SECRET_ROOT_PASSWORD="$(SECRET_ROOT_PASSWORD)" \
		MY_CNF="$(firstword $(wildcard $(CONFIG_MY_CNF_SRC)) $(STACK_SRC_DIR)configs/my.cnf)" \
		bash "$(SCRIPTS_DIR)/volume-from-snapshot.sh"

# ---------- Replication ----------
.PHONY: repl-status
repl-status: ## Replication state of this server: role, binlog, GTID, semi-sync, replica threads
	@$(_REPL) status

.PHONY: repl-user-create
repl-user-create: ## On the primary: create/update repl@REPLICA_HOST with the repl secret (REPLICA_HOST= ip, ip/mask)
	@$(_REPL) user-create

.PHONY: repl-dump
repl-dump: ## On the primary: dump for seeding a replica, with GTID position, into BU_DIR
	@mkdir -p "$(BU_DIR)"
	@$(_REPL) dump

.PHONY: repl-start
repl-start: ## On the replica: replicate from PRIMARY_HOST:PRIMARY_PORT via GTID (FILE=<repl-dump> or GTID_POS= to seed)
	@$(_REPL) start

.PHONY: repl-stop
repl-stop: ## On the replica: stop the replica threads (configuration kept)
	@$(_REPL) stop

.PHONY: repl-promote
repl-promote: ## Replica -> primary: drop replication, writable now (CONFIRM=yes; then DB_ROLE=primary + reload-service)
	@$(_REPL) promote

.PHONY: repl-demote
repl-demote: ## Former primary -> replica of PRIMARY_HOST (CONFIRM=yes; then DB_ROLE=replica + reload-service)
	@$(_REPL) demote

# ---------- Internal ----------
.PHONY: require-container
require-container:
	@[ -n "$(_CID)" ] || { echo "Container not running: $(STACK_NAME)_$(SERVICE)"; exit 1; }
