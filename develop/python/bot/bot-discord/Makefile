# Makefile for Docker Compose Deployment Management
# Version: 10.3.1

SHELL := /bin/bash

#-----------------------------------------------------------------
# Global Configuration
#-----------------------------------------------------------------
PROJECT_NAME        ?= bot-discord
DEPLOY_DIR          ?= $(HOME)/projects/$(PROJECT_NAME)/docker-compose/deploy/$(ENVIRONMENT)
VERSIONS_DIR         = $(DEPLOY_DIR)/versions
ACTIVE_VERSION_FILE  = $(DEPLOY_DIR)/active_version
DC_PR_NAME          ?= bot-discord
ENVIRONMENT         ?= dev
LOG_FILE             = $(DEPLOY_DIR)/deploy.log
VERSION_LOG          = $(DEPLOY_DIR)/version.log
DEPLOY_INCLUDES     ?= *
TIMESTAMP           := $(shell date +%Y%m%d%H%M%S)
SERVICE             ?=  

# Dynamic Docker Compose file path
DOCKER_COMPOSE_FILE = $(shell \
	if [ -f "$(ACTIVE_VERSION_FILE)" ]; then \
		VERSION=$$(cat "$(ACTIVE_VERSION_FILE)"); \
		echo "$(VERSIONS_DIR)/$${VERSION}/docker-compose.yaml"; \
	else \
		echo "$(DEPLOY_DIR)/docker-compose.yml"; \
	fi)

# Docker Compose command template
DOCKER_COMPOSE_CMD = docker compose -p $(DC_PR_NAME)_$(ENVIRONMENT) -f $(DOCKER_COMPOSE_FILE)

# Git commands
GIT_BRANCH_CMD   = git branch --show-current 2>/dev/null || echo "no-branch"
GIT_COMMIT_CMD    = git rev-parse --short HEAD 2>/dev/null || echo "no-hash"
GIT_MESSAGE_CMD   = git log -1 --pretty=%B 2>/dev/null || echo "no-commit-message"

#-----------------------------------------------------------------
# Functions
#-----------------------------------------------------------------
define _chk_var
	if ! env| grep -Poq "^$1=\K\S+"; then $(call _print_not_set,$1); exit 1; fi
endef

define _chk_vars
	_vars=$1; \
	for i in $${_vars}; do $(call _chk_var,$${i}); done
endef

define _print_not_set
	echo "Error. Not set variable [$1]"
endef

define _dcp_exec
	__service=$(1); \
	__cmd=$(2); \
	__terminal=$(3); \
	__user=$(4); \
	if [ -n "$${__user}" ]; then __user_cmd="--user $${__user}"; else __user_cmd=""; fi; \
	$(DOCKER_COMPOSE_CMD) exec -it $${__user_cmd} $${__terminal} $${__service} sh -c "$${__cmd}"
endef

define run_compose_command
	set -euo pipefail; \
	if [ -f "$(ACTIVE_VERSION_FILE)" ]; then \
		VERSION_PATH="$(VERSIONS_DIR)/$$(cat "$(ACTIVE_VERSION_FILE)")"; \
		cd "$${VERSION_PATH}"; \
	fi; \
	echo $(DOCKER_COMPOSE_CMD) $(1); \
	$(DOCKER_COMPOSE_CMD) $(1)
endef

#-----------------------------------------------------------------
# Phony Targets Declaration
#-----------------------------------------------------------------
.PHONY: init \
        gen-branch-info gen-version-info \
        version-create version-list version-set version-delete \
        deploy rollback \
        down stop start restart status logs \
        security-check \
        check-env check-tools \
        help

.DEFAULT_GOAL := help

#-----------------------------------------------------------------
# Initialization
#-----------------------------------------------------------------
init:
	@mkdir -p "$(DEPLOY_DIR)" "$(VERSIONS_DIR)"
	@touch "$(LOG_FILE)" "$(VERSION_LOG)"
	@echo "Initialized deployment directory: $(DEPLOY_DIR)"

#-----------------------------------------------------------------
# Version Information Generation
#-----------------------------------------------------------------
gen-branch-info:
	@set -euo pipefail; \
	if [ -d .git ]; then \
		echo "Generating branch.info..."; \
		printf "Branch: %s\n" "$$($(GIT_BRANCH_CMD))" > branch.info; \
		printf "Commit: %s\n" "$$($(GIT_COMMIT_CMD))" >> branch.info; \
		printf "Message: %s\n" "$$($(GIT_MESSAGE_CMD))" >> branch.info; \
	else \
		echo "Creating empty branch.info"; \
		printf "Branch: no-branch\nCommit: no-hash\nMessage: no-commit-message\n" > branch.info; \
	fi

gen-version-info: gen-branch-info
	@set -euo pipefail; \
	if [ -d .git ] && git tag --list >/dev/null 2>&1; then \
		VERSION="$$(git describe --tags --abbrev=0 2>/dev/null || echo 'temporary')"; \
	else \
		VERSION="temporary"; \
	fi; \
	echo "$${VERSION}" > version.info;

#-----------------------------------------------------------------
# Version Management
#-----------------------------------------------------------------
version-create: gen-version-info
	@if [[ "$${VERSION}" =~ [[:space:]] ]]; then \
		echo "Error: Version name cannot contain spaces"; \
		exit 1; \
	fi; \
	if [ -n "$(VERSION)" ]; then \
		VERSION_NAME="$(VERSION)-$(TIMESTAMP)"; \
	else \
		VERSION=$$(cat version.info); \
		if [ "$${VERSION}" = "temporary" ]; then \
			VERSION_NAME="temporary-$(TIMESTAMP)"; \
		else \
			VERSION_NAME="$${VERSION}-$(TIMESTAMP)"; \
		fi; \
	fi; \
	VERSION_PATH="$(VERSIONS_DIR)/$${VERSION_NAME}"; \
	if [ -d "$${VERSION_PATH}" ]; then \
		echo "Version $${VERSION_NAME} already exists"; \
		exit 1; \
	fi; \
	mkdir -p "$${VERSION_PATH}" && \
	rsync -a --exclude=".git" --exclude="$(DEPLOY_DIR)" \
		--include="$(DEPLOY_INCLUDES)" --exclude="*" . "$${VERSION_PATH}" && \
	{ [ -f branch.info ] && mv branch.info "$${VERSION_PATH}" || true; } && \
	{ [ -f version.info ] && mv version.info "$${VERSION_PATH}" || true; } && \
	printf "%s Created %s\n" "$$(date +'%Y-%m-%d %H:%M:%S')" "$${VERSION_NAME}" >> "$(VERSION_LOG)" && \
	if [ ! -f "$(ACTIVE_VERSION_FILE)" ]; then \
		echo "$${VERSION_NAME}" > "$(ACTIVE_VERSION_FILE)"; \
		echo "Automatically set as active version: $${VERSION_NAME}"; \
	fi; \
	echo "Created version: $${VERSION_NAME}"

version-list:
	@echo "Available versions in $(VERSIONS_DIR):"; \
	echo "------------------------------------"; \
	CURRENT=$$([ -f "$(ACTIVE_VERSION_FILE)" ] && cat "$(ACTIVE_VERSION_FILE)" || echo "none"); \
	for version in $$(ls -1 "$(VERSIONS_DIR)" | sort -r); do \
		DATE=$$(stat -c %y "$(VERSIONS_DIR)/$$version" | cut -d' ' -f1); \
		if [ "$${version}" = "$${CURRENT}" ]; then \
			echo "* $${version} ($${DATE})"; \
		else \
			echo "  $${version} ($${DATE})"; \
		fi; \
	done; \
	echo "------------------------------------"; \
	echo "Active version: $${CURRENT}"; \
	echo "Total versions: $$(ls -1 "$(VERSIONS_DIR)" | wc -l | tr -d ' ')"

######################

.PHONY: version-latest
version-latest:
	@if [ ! -d "$(VERSIONS_DIR)" ] || [ -z "$$(ls -A "$(VERSIONS_DIR)" 2>/dev/null)" ]; then \
		echo "No versions found in $(VERSIONS_DIR)"; \
		exit 1; \
	fi; \
	LATEST_VERSION=$$(ls -1t "$(VERSIONS_DIR)" | head -n 1); \
	echo "$${LATEST_VERSION}"

version-set:
	@[ -z "$(VERSION)" ] && { echo "Specify VERSION=version_name"; exit 1; }; \
	set -euo pipefail; \
	FULL_VERSION=$$( \
		if [ -d "$(VERSIONS_DIR)/$(VERSION)" ]; then \
			echo "$(VERSION)"; \
		else \
			find "$(VERSIONS_DIR)" -maxdepth 1 -name "$(VERSION)*" -printf "%f\n" | sort -r | head -n 1 | xargs; \
		fi \
	); \
	if [ -z "$${FULL_VERSION}" ] || [ ! -d "$(VERSIONS_DIR)/$${FULL_VERSION}" ]; then \
		echo "Version $(VERSION) not found"; \
		exit 1; \
	fi; \
	printf "%s" "$${FULL_VERSION}" > "$(ACTIVE_VERSION_FILE)" && \
	printf "%s Set active: %s\n" "$$(date +'%Y-%m-%d %H:%M:%S')" "$${FULL_VERSION}" >> "$(VERSION_LOG)" && \
	echo "Active version set to: $${FULL_VERSION}"

.PHONY: version-set-latest
version-set-latest:
	@LATEST_VERSION=$$($(MAKE) -s version-latest) && \
	echo "Latest version is [$${LATEST_VERSION}]" && \
	$(MAKE) version-set VERSION=$${LATEST_VERSION} && \
	$(MAKE) version-list

version-delete:
	@[ -z "$(VERSION)" ] && { echo "Specify VERSION=version_name"; exit 1; }; \
	set -euo pipefail; \
	FULL_VERSION=$$( \
		if [ -d "$(VERSIONS_DIR)/$(VERSION)" ]; then \
			echo "$(VERSION)"; \
		else \
			find "$(VERSIONS_DIR)" -maxdepth 1 -name "$(VERSION)*" -printf "%f\n" | sort -r | head -n 1 | xargs; \
		fi \
	); \
	if [ -z "$${FULL_VERSION}" ] || [ ! -d "$(VERSIONS_DIR)/$${FULL_VERSION}" ]; then \
		echo "Version $(VERSION) not found"; \
		exit 1; \
	fi; \
	if [ -f "$(ACTIVE_VERSION_FILE)" ] && [ "$$(cat "$(ACTIVE_VERSION_FILE)")" = "$${FULL_VERSION}" ]; then \
		if [ "$(FORCE)" != "1" ]; then \
			echo "Error: Cannot delete active version. Use FORCE=1 to override."; \
			exit 1; \
		else \
			rm -f "$(ACTIVE_VERSION_FILE)"; \
			echo "Removed active version: $${FULL_VERSION}"; \
		fi; \
	fi; \
	rm -rf "$(VERSIONS_DIR)/$${FULL_VERSION}" && \
	printf "%s Deleted: %s\n" "$$(date +'%Y-%m-%d %H:%M:%S')" "$${FULL_VERSION}" >> "$(VERSION_LOG)" && \
	echo "Deleted version: $${FULL_VERSION}"

.PHONY: version-get-latest
version-get-latest:
	@find $(VERSIONS_DIR) -maxdepth 1 -mindepth 1 -type d -exec \
		stat -c "%W %n" {} \;|sort -r|head -n 1|grep -Po "\s+\K.*\/\K\S+"


.PHONY: version-deploy
version-deploy:
	@$(MAKE) --silent version-create
	@$(eval VERSION_LATEST := $(shell $(MAKE) --silent version-get-latest))
	@echo "VERSION_LATEST=[$(VERSION_LATEST)]"
	@$(MAKE) --silent version-set-latest
	@$(MAKE) --silent version-copy
	@$(MAKE) --silent build create restart

define _version_prepare
	_version_path=$1 && \
	cd $${_version_path} && \
	echo "Section for prepare files after copy"
endef

define _get_current_version_path
	CURRENT=$$([ -f "$(ACTIVE_VERSION_FILE)" ] && cat "$(ACTIVE_VERSION_FILE)" || echo "none"); \
	if [ $${CURRENT} != "none" ]; then \
		echo "$(VERSIONS_DIR)/$${CURRENT}"; \
	fi
endef

.PHONY: version-copy
version-copy:
	@echo "Copy docker compose builds files"
	@VERSION_PATH=$$($(call _get_current_version_path)) && \
	rsync -av --exclude=".git" --exclude="$(DEPLOY_DIR)" \
		--include="$(DEPLOY_INCLUDES)" --exclude="*" --exclude="Makefile.root" \
		--exclude="README.md" . "$${VERSION_PATH}" && \
	{ [ -f branch.info ] && mv branch.info "$${VERSION_PATH}" || true; } && \
	{ [ -f version.info ] && mv version.info "$${VERSION_PATH}" || true; } && \
	printf "%s Created %s\n" "$$(date +'%Y-%m-%d %H:%M:%S')" "$${VERSION_NAME}" >> "$(VERSION_LOG)" && \
	if [ ! -f "$(ACTIVE_VERSION_FILE)" ]; then \
		echo "$${VERSION_NAME}" > "$(ACTIVE_VERSION_FILE)"; \
		echo "Automatically set as active version: $${VERSION_NAME}"; \
	fi; \
	echo "Now current version dir: $${VERSION_PATH}"; \
	cd $${VERSION_PATH} || exit 1; \
	$(call _version_prepare,$${VERSION_PATH}) && \
	echo "Created version: $${VERSION_NAME}"

#-----------------------------------------------------------------
# Validation
#-----------------------------------------------------------------
check-env:
	@[ -f "$(DOCKER_COMPOSE_FILE)" ] || { echo "Missing Docker Compose file: $(DOCKER_COMPOSE_FILE)"; exit 1; }

check-tools:
	@for tool in docker rsync; do \
		command -v $${tool} >/dev/null || { echo "Install $${tool}"; exit 1; }; \
	done
	@docker compose version >/dev/null 2>&1 || { echo "Install Docker Compose Plugin"; exit 1; }

#-----------------------------------------------------------------
# Container Management
#-----------------------------------------------------------------
DC_CMD := start stop restart up down exec build create ps
DC_FORMAT ?= "table{{.Name}}\\t{{.Service}}\\t{{.Status}}\\t{{.Ports}}"

.PHONY: $(DC_CMD)
$(DC_CMD):
	@echo "Command=[$(@)]"; if [ -n "$(SERVICE)" ]; then echo "Serice=[$(SERVICE)]"; fi
	@DC_CMD="$(@)"; if [ -n "$(SERVICE)" ]; then DC_CMD="$(@) $(SERVICE)"; fi; \
	$(call run_compose_command,$${DC_CMD})

status:
	@DC_CMD="ps --format $(DC_FORMAT)";\
	if [ -n "$(SERVICE)" ]; then DC_CMD="$${DC_CMD} $(SERVICE)"; fi; \
	$(call run_compose_command,$${DC_CMD})

logs:
	@DC_CMD="logs"; if [ -n "$(SERVICE)" ]; then DC_CMD="$${DC_CMD} $(SERVICE)"; fi; \
	$(call run_compose_command,$${DC_CMD})

#-----------------------------------------------------------------
# Deployment Operations
#-----------------------------------------------------------------
define deployment_header
	echo "\n=== Deployment Info ===" | tee -a "$(LOG_FILE)"; \
	echo "Timestamp: $$(date)" | tee -a "$(LOG_FILE)"; \
	echo "Version: $1" | tee -a "$(LOG_FILE)"; \
	echo "Project: $(DC_PR_NAME)" | tee -a "$(LOG_FILE)"; \
	echo "Environment: $(ENVIRONMENT)" | tee -a "$(LOG_FILE)"; \
	[ -f "$2/branch.info" ] && { echo "Git Info:" | tee -a "$(LOG_FILE)"; cat "$2/branch.info" | tee -a "$(LOG_FILE)"; }
endef

.PHONY: deploy
deploy: check-env check-tools
	@if [ -f "$(ACTIVE_VERSION_FILE)" ]; then \
		VERSION_NAME=$$(cat "$(ACTIVE_VERSION_FILE)"); \
		VERSION_PATH="$(VERSIONS_DIR)/$$VERSION_NAME"; \
		$(call deployment_header,$$VERSION_NAME,$$VERSION_PATH); \
		cd "$$VERSION_PATH" && $(DOCKER_COMPOSE_CMD) up -d --build; \
	else \
		$(call deployment_header,"current directory",.); \
		$(DOCKER_COMPOSE_CMD) up -d --build; \
	fi 2>&1 | tee -a "$(LOG_FILE)"

rollback:
	@set -euo pipefail; \
	if [ -f "$(ACTIVE_VERSION_FILE)" ]; then \
		CURRENT=$$(cat "$(ACTIVE_VERSION_FILE)"); \
		PREVIOUS=$$(ls -1 "$(VERSIONS_DIR)" | grep -v "$${CURRENT}" | sort -r | head -n 1 | xargs); \
		[ -z "$${PREVIOUS}" ] && { echo "No previous version found"; exit 1; }; \
		echo "$${PREVIOUS}" > "$(ACTIVE_VERSION_FILE)"; \
		echo "Rolled back to: $${PREVIOUS}"; \
	else \
		echo "No active version to rollback from"; \
		exit 1; \
	fi

.PHONY: dcp-cmd
dcp-cmd:
	@$(call _chk_var,DCP_CMD)
	@$(DOCKER_COMPOSE_CMD) exec -it $(TERMINAL) $(BACKEND_SVC_NAME) sh -c '$(DCP_CMD)'

.PHONY: dcp-svc-cmd
dcp-svc-cmd:
	@$(call _chk_vars,"DCP_CMD SERVICE")
	@$(call _dcp_exec,$(SERVICE),'$(DCP_CMD)',$(TERMINAL),$(DOCKER_USER))

#-----------------------------------------------------------------
# Security Checks
#-----------------------------------------------------------------
security-check:
	@echo "Running security checks..."; \
	docker scan $(DC_PR_NAME) || true; \
	echo "Security checks completed."

#-----------------------------------------------------------------
# Help
#-----------------------------------------------------------------
help:
	@echo "Deployment Management System"
	@echo "Usage: make [target] [OPTIONS]"
	@echo ""
	@echo "Options:"
	@echo "  DC_PR_NAME      - Docker project name (default: myproject)"
	@echo "  ENVIRONMENT     - Deployment environment (default: dev)"
	@echo "  VERSION         - Version name for version-* commands"
	@echo "  FORCE           - Force dangerous operations (e.g. FORCE=1)"
	@echo "  DC_FORMAT       - Set docker compose ps format (e.g. DC_FORMAT='table{{.Service}}\t{{.Ports}}'"
	@echo ""
	@echo "Targets:"
	@echo "  init                Initialize deployment directory"
	@echo "  gen-branch-info     Generate branch information file"
	@echo "  version-create      Create new deployment version"
	@echo "  version-list        List available versions with creation dates"
	@echo "  version-latest      Print latest version"
	@echo "  version-set         Set active version (VERSION=name)"
	@echo "  version-set-latest  Set activer last version"
	@echo "  version-delete      Delete version (VERSION=name, requires FORCE=1 if active)"
	@echo "  deploy              Deploy active version"
	@echo "  down                Stop and remove containers"
	@echo "  stop                Stop running containers"
	@echo "  start               Start existing containers"
	@echo "  restart             Restart containers"
	@echo "  status              Show container status"
	@echo "  logs                View container logs"
	@echo "  rollback            Rollback to previous version"
	@echo "  check-env           Validate environment configuration"
	@echo "  check-tools         Verify required tools are installed"
	@echo "  security-check      Run basic security checks"
	@echo "  help                Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make version-create VERSION=0.0.2"
	@echo "  make down"
	@echo "  make version-set VERSION=0.0.2"
	@echo "  make deploy"
	@echo "  make down"
	@echo "  make version-delete VERSION=0.0.2"
	@echo "  make rollback"
	@echo "  make deploy"
	@echo ""
	@echo "  make rollback VERSION=0.0.1"
	@echo "  make rollback"
	@echo ""
	@echo "  make version-create version-set-latest deploy VERSION=0.0.4 DC_PR_NAME=project_dev"
	@echo "  make down rollback deploy DC_PR_NAME=project_dev"
	@echo "  make version-delete VERSION=0.0.4"
	@echo "  make deploy"

