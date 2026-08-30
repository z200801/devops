SHELL := /bin/bash

# ---------- Global variables ----------
PROJECT_NAME         ?= monitoring
ENV                  ?= prod
STACK_NAME           ?= mon2
SERVICE              ?=
PROJECTS_DIR         ?= $(HOME)/projects
DEPLOY_DIR            = $(PROJECTS_DIR)/$(PROJECT_NAME)/grafana-vm/dswarm/$(ENV)/deploy
COMPOSE_FILE         := $(DEPLOY_DIR)/stack.yml
LOG_FILE              = $(DEPLOY_DIR)/deploy.log
DEPLOY_INCLUDES      ?= *
DEPLOY_EXCLUDES      ?=
TIMESTAMP            := $(shell date +%Y%m%d%H%M%S)
TIMESTAMP_SHORT      := $(shell date +%Y%m%d)
BU_DIR               ?= $(PROJECTS_DIR)/$(PROJECT_NAME)/bu/$(ENV)/$(TIMESTAMP_SHORT)

# ---------- Git ----------
GIT_BRANCH_DEVOPS    ?= main
GIT_REPO_DIR         ?= $(PROJECTS_DIR)/repo/h2-dswarm

# ---------- Secrets ----------
SECRET_GRAFANA_USER     ?= grafana_admin_user
SECRET_GRAFANA_PASSWORD ?= grafana_admin_password
GRAFANA_ADMIN_USER      ?= admin
GRAFANA_ADMIN_PASSWORD  ?= changeme

# ---------- Configs ----------
CONFIG_SCRAPE           ?= scrape_config
CONFIG_LOKI             ?= loki_config
CONFIG_PROMTAIL         ?= promtail_config
CONFIG_ALERTMANAGER     ?= alertmanager_config
CONFIG_GRAFANA_DS       ?= grafana_datasources
CONFIG_GRAFANA_DASH     ?= grafana_dashboards_provider

# ---------- Config source files ----------
CONFIGS_DIR             := $(DEPLOY_DIR)/configs
CONFIG_SCRAPE_SRC       := $(CONFIGS_DIR)/victoriametrics/scrape.yml
CONFIG_LOKI_SRC         := $(CONFIGS_DIR)/loki/loki.yml
CONFIG_PROMTAIL_SRC     := $(CONFIGS_DIR)/promtail/promtail.yml
CONFIG_ALERTMANAGER_SRC := $(CONFIGS_DIR)/alertmanager/alertmanager.yml
CONFIG_GRAFANA_DS_SRC   := $(CONFIGS_DIR)/grafana/datasources.yml
CONFIG_GRAFANA_DASH_SRC := $(CONFIGS_DIR)/grafana/dashboards.yml

# ---------- Discord ----------
DISCORD_WEBHOOK_URL     ?=

# ---------- Helpers ----------
_CID = $$(docker ps -q -f name=$(STACK_NAME)_$(SERVICE) | head -1)

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
	@echo "  make copy-deploy-files"
	@echo "  make env-init"
	@echo "  make secrets-create GRAFANA_ADMIN_USER=admin GRAFANA_ADMIN_PASSWORD=secret"
	@echo "  make configs-create DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/..."
	@echo "  make stack-deploy"
	@echo "  make logs SERVICE=grafana"
	@echo "  make service-rollback SERVICE=victoriametrics"
	@echo "  make secrets-rotate GRAFANA_ADMIN_USER=admin GRAFANA_ADMIN_PASSWORD=secret"

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
		printf "GRAFANA_ROOT_URL=http://localhost:3000\n" > "$(DEPLOY_DIR)/.env"; \
		echo "Created: $(DEPLOY_DIR)/.env — edit before deploying"; \
	fi

.PHONY: copy-deploy-files
copy-deploy-files: ## Copy deployment files from GIT_REPO_DIR to DEPLOY_DIR
	@test -n "$(GIT_REPO_DIR)"      || { echo "GIT_REPO_DIR= required";          exit 1; }
	@test -n "$(PROJECT_NAME)"      || { echo "PROJECT_NAME= required";           exit 1; }
	@test -d "$(GIT_REPO_DIR)/.git" || { echo "Not a git repo: $(GIT_REPO_DIR)";  exit 1; }
	@test -d "$(GIT_REPO_DIR)/$(PROJECT_NAME)" || { echo "Not found: $(GIT_REPO_DIR)/$(PROJECT_NAME)"; exit 1; }
	@mkdir -p "$(DEPLOY_DIR)"
	@echo "Copying deployment files from $(GIT_REPO_DIR)/$(PROJECT_NAME)..."
	@cd "$(GIT_REPO_DIR)" && \
	 git switch "$(GIT_BRANCH_DEVOPS)" && \
	 rsync -av \
	   --exclude=".git" \
	   $$([ -n "$(DEPLOY_EXCLUDES)" ] && echo "--exclude=$(DEPLOY_EXCLUDES)") \
	   --include="$(DEPLOY_INCLUDES)" \
	   "$(PROJECT_NAME)/" "$(DEPLOY_DIR)/"
	@echo "Files copied to: $(DEPLOY_DIR)"

# ---------- Checks ----------
.PHONY: check-swarm
check-swarm: ## Verify Docker Swarm is active
	@docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active" || \
		{ echo "Swarm not active. Run: docker swarm init"; exit 1; }
	@echo "Swarm: active"

.PHONY: check-env
check-env: ## Validate stack file and .env presence
	@[ -f "$(COMPOSE_FILE)" ]    || { echo "Missing stack file: $(COMPOSE_FILE)"; exit 1; }
	@[ -n "$(PROJECT_NAME)" ]    || { echo "PROJECT_NAME= required"; exit 1; }
	@[ -n "$(STACK_NAME)" ]      || { echo "STACK_NAME= required";   exit 1; }
	@[ -f "$(DEPLOY_DIR)/.env" ] || { echo "Missing: $(DEPLOY_DIR)/.env — run: make env-init"; exit 1; }

.PHONY: check-tools
check-tools: ## Verify required tools are installed
	@for tool in docker rsync envsubst; do \
		command -v $${tool} >/dev/null || { echo "Install $${tool}"; exit 1; }; \
	done

# ---------- Secrets ----------
.PHONY: secrets-create
secrets-create: ## Create Grafana secrets (GRAFANA_ADMIN_USER= GRAFANA_ADMIN_PASSWORD= required)
	@[ -n "$(GRAFANA_ADMIN_USER)" ]     || { echo "GRAFANA_ADMIN_USER= required";     exit 1; }
	@[ -n "$(GRAFANA_ADMIN_PASSWORD)" ] || { echo "GRAFANA_ADMIN_PASSWORD= required"; exit 1; }
	@docker secret inspect "$(SECRET_GRAFANA_USER)" >/dev/null 2>&1 \
		&& echo "Already exists: $(SECRET_GRAFANA_USER)" \
		|| { echo -n "$(GRAFANA_ADMIN_USER)" | docker secret create "$(SECRET_GRAFANA_USER)" - \
			&& echo "Created: $(SECRET_GRAFANA_USER)"; }
	@docker secret inspect "$(SECRET_GRAFANA_PASSWORD)" >/dev/null 2>&1 \
		&& echo "Already exists: $(SECRET_GRAFANA_PASSWORD)" \
		|| { echo -n "$(GRAFANA_ADMIN_PASSWORD)" | docker secret create "$(SECRET_GRAFANA_PASSWORD)" - \
			&& echo "Created: $(SECRET_GRAFANA_PASSWORD)"; }

.PHONY: secrets-rotate
secrets-rotate: stack-rm ## Rotate Grafana secrets (GRAFANA_ADMIN_USER= GRAFANA_ADMIN_PASSWORD= required)
	@[ -n "$(GRAFANA_ADMIN_USER)" ]     || { echo "GRAFANA_ADMIN_USER= required";     exit 1; }
	@[ -n "$(GRAFANA_ADMIN_PASSWORD)" ] || { echo "GRAFANA_ADMIN_PASSWORD= required"; exit 1; }
	@echo "Rotating secrets..."
	@docker secret rm "$(SECRET_GRAFANA_USER)"     2>/dev/null || true
	@docker secret rm "$(SECRET_GRAFANA_PASSWORD)" 2>/dev/null || true
	@$(MAKE) secrets-create \
		GRAFANA_ADMIN_USER="$(GRAFANA_ADMIN_USER)" \
		GRAFANA_ADMIN_PASSWORD="$(GRAFANA_ADMIN_PASSWORD)"
	@echo "Secrets rotated. Run: make configs-create && make stack-deploy"

.PHONY: secrets-check
secrets-check: ## Verify required secrets exist in swarm
	@missing=0; \
	for s in "$(SECRET_GRAFANA_USER)" "$(SECRET_GRAFANA_PASSWORD)"; do \
		docker secret inspect "$${s}" >/dev/null 2>&1 \
			&& echo "OK: $${s}" \
			|| { echo "MISSING: $${s}"; missing=1; }; \
	done; \
	[ "$${missing}" = "0" ] || { echo "Run: make secrets-create GRAFANA_ADMIN_USER=... GRAFANA_ADMIN_PASSWORD=..."; exit 1; }

.PHONY: secrets-list
secrets-list: ## List Docker secrets
	@docker secret ls

# ---------- Configs ----------
.PHONY: configs-create
configs-create: ## Create all Docker configs (DISCORD_WEBHOOK_URL= required)
	@[ -n "$(DISCORD_WEBHOOK_URL)" ] || { echo "DISCORD_WEBHOOK_URL= required"; exit 1; }
	@test -f "$(CONFIG_SCRAPE_SRC)"       || { echo "Missing: $(CONFIG_SCRAPE_SRC)";       exit 1; }
	@test -f "$(CONFIG_LOKI_SRC)"         || { echo "Missing: $(CONFIG_LOKI_SRC)";         exit 1; }
	@test -f "$(CONFIG_PROMTAIL_SRC)"     || { echo "Missing: $(CONFIG_PROMTAIL_SRC)";     exit 1; }
	@test -f "$(CONFIG_ALERTMANAGER_SRC)" || { echo "Missing: $(CONFIG_ALERTMANAGER_SRC)"; exit 1; }
	@test -f "$(CONFIG_GRAFANA_DS_SRC)"   || { echo "Missing: $(CONFIG_GRAFANA_DS_SRC)";   exit 1; }
	@test -f "$(CONFIG_GRAFANA_DASH_SRC)" || { echo "Missing: $(CONFIG_GRAFANA_DASH_SRC)"; exit 1; }
	@docker config inspect "$(CONFIG_SCRAPE)" >/dev/null 2>&1 \
		&& echo "Already exists: $(CONFIG_SCRAPE)" \
		|| { docker config create "$(CONFIG_SCRAPE)" "$(CONFIG_SCRAPE_SRC)" \
			&& echo "Created: $(CONFIG_SCRAPE)"; }
	@docker config inspect "$(CONFIG_LOKI)" >/dev/null 2>&1 \
		&& echo "Already exists: $(CONFIG_LOKI)" \
		|| { docker config create "$(CONFIG_LOKI)" "$(CONFIG_LOKI_SRC)" \
			&& echo "Created: $(CONFIG_LOKI)"; }
	@docker config inspect "$(CONFIG_PROMTAIL)" >/dev/null 2>&1 \
		&& echo "Already exists: $(CONFIG_PROMTAIL)" \
		|| { docker config create "$(CONFIG_PROMTAIL)" "$(CONFIG_PROMTAIL_SRC)" \
			&& echo "Created: $(CONFIG_PROMTAIL)"; }
	@docker config inspect "$(CONFIG_ALERTMANAGER)" >/dev/null 2>&1 \
		&& echo "Already exists: $(CONFIG_ALERTMANAGER)" \
		|| { DISCORD_WEBHOOK_URL="$(DISCORD_WEBHOOK_URL)" \
			envsubst < "$(CONFIG_ALERTMANAGER_SRC)" | \
			docker config create "$(CONFIG_ALERTMANAGER)" - \
			&& echo "Created: $(CONFIG_ALERTMANAGER)"; }
	@docker config inspect "$(CONFIG_GRAFANA_DS)" >/dev/null 2>&1 \
		&& echo "Already exists: $(CONFIG_GRAFANA_DS)" \
		|| { docker config create "$(CONFIG_GRAFANA_DS)" "$(CONFIG_GRAFANA_DS_SRC)" \
			&& echo "Created: $(CONFIG_GRAFANA_DS)"; }
	@docker config inspect "$(CONFIG_GRAFANA_DASH)" >/dev/null 2>&1 \
		&& echo "Already exists: $(CONFIG_GRAFANA_DASH)" \
		|| { docker config create "$(CONFIG_GRAFANA_DASH)" "$(CONFIG_GRAFANA_DASH_SRC)" \
			&& echo "Created: $(CONFIG_GRAFANA_DASH)"; }

.PHONY: configs-rotate
configs-rotate: stack-rm ## Rotate all Docker configs (DISCORD_WEBHOOK_URL= required)
	@[ -n "$(DISCORD_WEBHOOK_URL)" ] || { echo "DISCORD_WEBHOOK_URL= required"; exit 1; }
	@echo "Rotating configs..."
	@for c in "$(CONFIG_SCRAPE)" "$(CONFIG_LOKI)" "$(CONFIG_PROMTAIL)" \
	          "$(CONFIG_ALERTMANAGER)" "$(CONFIG_GRAFANA_DS)" "$(CONFIG_GRAFANA_DASH)"; do \
		docker config rm "$${c}" 2>/dev/null || true; \
	done
	@$(MAKE) configs-create DISCORD_WEBHOOK_URL="$(DISCORD_WEBHOOK_URL)"
	@echo "Configs rotated. Run: make stack-deploy"

.PHONY: configs-check
configs-check: ## Verify required Docker configs exist
	@missing=0; \
	for c in "$(CONFIG_SCRAPE)" "$(CONFIG_LOKI)" "$(CONFIG_PROMTAIL)" \
	         "$(CONFIG_ALERTMANAGER)" "$(CONFIG_GRAFANA_DS)" "$(CONFIG_GRAFANA_DASH)"; do \
		docker config inspect "$${c}" >/dev/null 2>&1 \
			&& echo "OK: $${c}" \
			|| { echo "MISSING: $${c}"; missing=1; }; \
	done; \
	[ "$${missing}" = "0" ] || { echo "Run: make configs-create DISCORD_WEBHOOK_URL=..."; exit 1; }

.PHONY: configs-list
configs-list: ## List Docker configs
	@docker config ls

# ---------- Stack management ----------
.PHONY: stack-deploy
stack-deploy: check-swarm check-env check-tools secrets-check configs-check ## Deploy monitoring stack
	@echo "Deploying stack '$(STACK_NAME)' from: $(COMPOSE_FILE)"
	@set -a && source "$(DEPLOY_DIR)/.env" && set +a && \
	docker stack deploy --with-registry-auth -c "$(COMPOSE_FILE)" "$(STACK_NAME)" \
		2>&1 | tee -a "$(LOG_FILE)"
	@echo "Deployed. Check: make status"

.PHONY: stack-rm
stack-rm: ## Remove monitoring stack
	@echo "Removing stack '$(STACK_NAME)'..."
	@docker stack rm "$(STACK_NAME)"
	@echo "Waiting for full removal..."; \
	timeout 60 bash -c \
		'until [ -z "$$(docker stack ps $(STACK_NAME) 2>/dev/null)" ]; do sleep 2; done' \
		|| echo "Warning: timeout waiting for stack removal"
	@echo "Stack removed"

.PHONY: stack-backup
stack-backup: ## Backup current stack config and service list
	@mkdir -p "$(BU_DIR)"
	@cp "$(COMPOSE_FILE)" "$(BU_DIR)/stack.$(TIMESTAMP).yml"
	@docker service ls -f name=$(STACK_NAME) > "$(BU_DIR)/services.$(TIMESTAMP).txt"
	@echo "Backup saved to: $(BU_DIR)"

.PHONY: stack-health
stack-health: ## Check all services are converged
	@failed=$$(docker stack ps $(STACK_NAME) --format "{{.CurrentState}}" | grep -v "Running" | wc -l); \
	[ "$${failed}" = "0" ] && echo "All tasks running" || { \
		echo "WARNING: $${failed} task(s) not in Running state:"; \
		docker stack ps $(STACK_NAME) --format "table {{.Name}}\t{{.CurrentState}}\t{{.Error}}" | grep -v "Running"; \
		exit 1; \
	}

.PHONY: start
start: stack-deploy ## Alias: deploy stack

.PHONY: stop
stop: stack-rm ## Alias: remove stack

.PHONY: restart
restart: ## Restart stack (WARNING: full downtime)
	@echo "WARNING: Full stack restart."
	@[ "$(FORCE)" = "y" ] || { read -r -p "Continue? [y/N] " ans && [ "$$ans" = "y" ]; }
	@$(MAKE) stop start

# ---------- Service management ----------
.PHONY: service-ls
service-ls: ## List all services in stack
	@docker service ls -f name=$(STACK_NAME)

.PHONY: service-update
service-update: ## Force update service (SERVICE= required)
	@test -n "$(SERVICE)" || { echo "SERVICE= required"; exit 1; }
	@echo "Force-updating $(STACK_NAME)_$(SERVICE)..."
	@docker service update --force $(STACK_NAME)_$(SERVICE)

.PHONY: service-rollback
service-rollback: ## Rollback service to previous version (SERVICE= required)
	@test -n "$(SERVICE)" || { echo "SERVICE= required"; exit 1; }
	@echo "Rolling back $(STACK_NAME)_$(SERVICE)..."
	@docker service rollback $(STACK_NAME)_$(SERVICE)
	@echo "Rollback initiated. Check: make ps"

.PHONY: service-scale
service-scale: ## Scale service (SERVICE= REPLICAS= required)
ifndef REPLICAS
	$(error REPLICAS is not set. Example: make service-scale SERVICE=grafana REPLICAS=2)
endif
	@test -n "$(SERVICE)" || { echo "SERVICE= required"; exit 1; }
	@docker service scale $(STACK_NAME)_$(SERVICE)=$(REPLICAS)

.PHONY: ps
ps: ## Show stack task status
	@docker stack ps "$(STACK_NAME)"

.PHONY: status
status: ## Show service running status
	@docker service ls -f name=$(STACK_NAME)

.PHONY: stats
stats: ## Show resource usage for all stack containers
	@docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" \
		$(shell docker ps --filter "name=$(STACK_NAME)" --format "{{.Names}}")

.PHONY: service-env
service-env: ## Show service environment variables (SERVICE= required)
	@test -n "$(SERVICE)" || { echo "SERVICE= required"; exit 1; }
	@docker service inspect $(STACK_NAME)_$(SERVICE) \
		--format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | jq

# ---------- Logs ----------
.PHONY: logs
logs: ## Follow service logs (SERVICE= required)
	@test -n "$(SERVICE)" || { echo "SERVICE= required"; exit 1; }
	@docker service logs -f $(STACK_NAME)_$(SERVICE)

# ---------- Exec ----------
.PHONY: exec
exec: require-container ## Open shell inside running container (SERVICE= required)
	@docker exec -it $(_CID) bash

# ---------- Internal ----------
.PHONY: require-container
require-container:
	@[ -n "$(_CID)" ] || { echo "Container not running: $(STACK_NAME)_$(SERVICE)"; exit 1; }
