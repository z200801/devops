# Makefile for Key Tracker version control

# Set shell to bash explicitly
SHELL := /bin/bash

# By default, if no target is specified, run the help target
.DEFAULT_GOAL := help

# Default values
DEFAULT_DD := $(HOME)/projects/key-tracker/docker-compose/deploy
DEPLOY_DIR ?= $(DEPLOY_DIRECTORY)
DEPLOY_DIR := $(if $(DEPLOY_DIR),$(DEPLOY_DIR),$(DEFAULT_DD))

# Version file and log
VERSION_FILE := $(DEPLOY_DIR)/.version

# If VERSION is not specified and deploy target is called, use current version
ifeq ($(VERSION),)
  ifeq ($(MAKECMDGOALS),deploy)
    ifneq ($(wildcard $(VERSION_FILE)),)
      VERSION := $(shell cat $(VERSION_FILE))
      $(info VERSION parameter not provided, using current version: $(VERSION))
    endif
  endif
endif

PROJECT_NAME ?= keytracker
VERSION ?= 
FRONTEND_PORT ?=
DC_FILE ?= docker-compose.yml
FORCE ?= 0

VERSION_LOG := $(DEPLOY_DIR)/version-history.log
VERSIONS_DIR := $(DEPLOY_DIR)/versions

# Commands
DOCKER_COMPOSE := docker compose -f $(DC_FILE)
MKDIR := mkdir -p
RM := rm -rf
RSYNC := rsync -av
GREP := grep
SED := sed
DATE := date
CAT := cat
SLEEP := sleep

# Help target
.PHONY: help
help:
	@echo "Key Tracker - Version Control System"
	@echo ""
	@echo "Usage:"
	@echo "  make tag VERSION=<version>                         - Tag current state as a version"
	@echo "  make deploy [VERSION=<version>] [PROJECT_NAME=<n>] \\"
	@echo "       [FRONTEND_PORT=<port>] [DC_FILE=<file>]       - Deploy specified or current version"
	@echo "  make rollback VERSION=<version> [PROJECT_NAME=<n>] \\"
	@echo "       [DC_FILE=<file>]                              - Rollback to specified version"
	@echo "  make stop [PROJECT_NAME=<n>] [DC_FILE=<file>]      - Stop running containers"
	@echo "  make list                                          - Show available versions"
	@echo "  make current                                       - Show current version"
	@echo "  make delete VERSION=<version> [FORCE=1]            - Delete a version (if not active)"
	@echo "  make active VERSION=<version>                      - Set version as active without deployment"
	@echo ""
	@echo "Options:"
	@echo "  PROJECT_NAME=<n>                           - Specify Docker Compose project name"
	@echo "  DEPLOY_DIR=<path>                             - Specify deployments directory"
	@echo "  DEPLOY_DIRECTORY=<path>                       - Environment variable for deployment directory"
	@echo "  FRONTEND_PORT=<port>                          - Specify frontend service port (default: unchanged)"
	@echo "  DC_FILE=<filename>                            - Specify Docker Compose file (default: docker-compose.yml)"
	@echo "  FORCE=1                                       - Force action without confirmation"
	@echo ""
	@echo "Examples:"
	@echo "  make tag VERSION=v1.0.0"
	@echo "  make deploy                                   - Deploy current version"
	@echo "  make deploy VERSION=v1.0.0 PROJECT_NAME=myproject FRONTEND_PORT=8080"
	@echo "  make deploy VERSION=v1.0.0 DC_FILE=docker-compose.prod.yml FRONTEND_PORT=8080"
	@echo "  make rollback VERSION=v1.0.0 PROJECT_NAME=myproject"
	@echo "  make stop PROJECT_NAME=myproject"
	@echo "  make delete VERSION=v0.9.0                    - Delete old version with confirmation"
	@echo "  make delete VERSION=v0.9.0 FORCE=1            - Delete old version without confirmation"
	@echo "  make active VERSION=v1.0.0                    - Set version v1.0.0 as active"
	@echo "  DEPLOY_DIRECTORY=/opt/deployments make list"

# Create directories
$(VERSIONS_DIR):
	@$(MKDIR) $(DEPLOY_DIR)
	@$(MKDIR) $(VERSIONS_DIR)

# Tag a new version
.PHONY: tag
tag: check-version $(VERSIONS_DIR)
	@echo "Creating version $(VERSION)..."
	@if [ -d "$(VERSIONS_DIR)/$(VERSION)" ]; then \
		echo "Error: Version $(VERSION) already exists"; \
		exit 1; \
	fi
	@$(MKDIR) $(VERSIONS_DIR)/$(VERSION)
	@$(RSYNC) \
		--exclude="$(DEPLOY_DIR)" \
		--exclude="node_modules" \
		--exclude=".git" \
		--exclude="__pycache__" \
		--exclude="*.pyc" \
		--exclude="*.pyo" \
		--exclude="*.pyd" \
		--exclude=".pytest_cache" \
		--exclude=".coverage" \
		--exclude="coverage" \
		--exclude="dist" \
		--exclude="build" \
		--exclude="*.egg-info" \
		--exclude="venv" \
		--exclude="env" \
		--exclude="migrations" \
		./ $(VERSIONS_DIR)/$(VERSION)/
	@echo "$(VERSION)" > $(VERSION_FILE)
	@echo "$(shell $(DATE) '+%Y-%m-%d %H:%M:%S') - Tagged version $(VERSION)" >> $(VERSION_LOG)
	@if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
		BRANCH=$$(git branch --show-current); \
		COMMIT=$$(git log -1 --pretty=format:"%h %s"); \
		echo "$${BRANCH} $${COMMIT}" > $(VERSIONS_DIR)/$(VERSION)/branch.info; \
		echo "Git information saved to $(VERSIONS_DIR)/$(VERSION)/branch.info"; \
	else \
		echo "Not a git repository, skipping branch info"; \
	fi
	@echo "Version $(VERSION) successfully created in $(DEPLOY_DIR)"

# Stop running containers
.PHONY: stop
stop:
	@echo "Stopping containers for project '$(PROJECT_NAME)'..."
	@$(DOCKER_COMPOSE) -p $(PROJECT_NAME) down
	@echo "Containers stopped successfully"

# Check if Docker Compose project is running
.PHONY: check-project-running
check-project-running:
	@if ! $(DOCKER_COMPOSE) -p $(PROJECT_NAME) ps | grep -q "Up"; then \
		echo "Error: Project $(PROJECT_NAME) is not running"; \
		echo "Available running projects:"; \
		docker ps --format "{{.Names}}" | grep -o "^[^-]*" | sort -u; \
		exit 1; \
	fi

# Rollback to a specific version
.PHONY: rollback
rollback: check-version $(VERSIONS_DIR)
	@echo "Preparing to rollback to version $(VERSION) for project '$(PROJECT_NAME)'..."
	@if [ ! -d "$(VERSIONS_DIR)/$(VERSION)" ]; then \
		echo "Error: Version $(VERSION) not found"; \
		echo "Available versions:"; \
		$(MAKE) -s list; \
		exit 1; \
	fi
	@if [ ! -f "$(DC_FILE)" ]; then \
		echo "Error: $(DC_FILE) not found in the current directory"; \
		exit 1; \
	fi
	@if ! $(DOCKER_COMPOSE) -p $(PROJECT_NAME) ps | grep -q "Up"; then \
		echo "Error: Project $(PROJECT_NAME) is not running"; \
		echo "Available projects:"; \
		docker ps --format "{{.Names}}" | grep -o "^[^-]*" | sort -u; \
		exit 1; \
	fi
	@TEMP_BACKUP="backup_before_rollback_$$($(DATE) +%Y%m%d_%H%M%S)"; \
	$(MKDIR) $(DEPLOY_DIR)/$${TEMP_BACKUP}; \
	$(RSYNC) \
		--exclude="$(DEPLOY_DIR)" \
		--exclude="node_modules" \
		--exclude=".git" \
		--exclude="__pycache__" \
		--exclude="*.pyc" \
		./ $(DEPLOY_DIR)/$${TEMP_BACKUP}/; \
	echo "Created temporary backup in $(DEPLOY_DIR)/$${TEMP_BACKUP}"; \
	echo "Stopping current containers..."; \
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) down; \
	echo "Copying version $(VERSION) files to project directory..."; \
	$(RSYNC) --delete \
		--exclude="$(DEPLOY_DIR)" \
		--exclude="node_modules" \
		--exclude=".git" \
		--exclude="Makefile" \
		$(VERSIONS_DIR)/$(VERSION)/ ./; \
	echo "Starting containers with version $(VERSION)..."; \
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) up -d --build; \
	echo "Checking container status..."; \
	$(SLEEP) 10; \
	if $(DOCKER_COMPOSE) -p $(PROJECT_NAME) ps | $(GREP) -q "Exit"; then \
		echo "Error: One or more containers failed to start after rollback"; \
		echo "Restoring from backup..."; \
		$(RSYNC) --delete \
			--exclude="$(DEPLOY_DIR)" \
			--exclude="node_modules" \
			--exclude=".git" \
			$(DEPLOY_DIR)/$${TEMP_BACKUP}/ ./; \
		$(DOCKER_COMPOSE) -p $(PROJECT_NAME) up -d --build; \
		echo "Restore from backup completed"; \
		if [ -d "$(DEPLOY_DIR)/$${TEMP_BACKUP}" ]; then \
			$(RM) $(DEPLOY_DIR)/$${TEMP_BACKUP}; \
		fi; \
		exit 1; \
	fi; \
	echo "$(VERSION)" > $(VERSION_FILE); \
	echo "$$($(DATE) "+%Y-%m-%d %H:%M:%S") - Rolled back to version $(VERSION) for project $(PROJECT_NAME)" >> $(VERSION_LOG); \
	if [ -d "$(DEPLOY_DIR)/$${TEMP_BACKUP}" ]; then \
		$(RM) $(DEPLOY_DIR)/$${TEMP_BACKUP}; \
	fi; \
	echo "Successfully rolled back to version $(VERSION) for project $(PROJECT_NAME)"

# Deploy a specific version
.PHONY: deploy
deploy: $(VERSIONS_DIR)
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: No current version found in $(VERSION_FILE) and no VERSION parameter provided"; \
		echo "Available versions:"; \
		$(MAKE) -s list; \
		exit 1; \
	fi
	@if [ ! -d "$(VERSIONS_DIR)/$(VERSION)" ]; then \
		echo "Error: Version $(VERSION) not found"; \
		echo "Available versions:"; \
		$(MAKE) -s list; \
		exit 1; \
	fi
	@if [ ! -z "$(FRONTEND_PORT)" ]; then \
		if ! [[ "$(FRONTEND_PORT)" =~ ^[0-9]+$$ ]]; then \
			echo "Error: FRONTEND_PORT must be a valid port number"; \
			exit 1; \
		fi; \
		if [ "$(FRONTEND_PORT)" -lt 1024 ] || [ "$(FRONTEND_PORT)" -gt 65535 ]; then \
			echo "Error: FRONTEND_PORT must be between 1024 and 65535"; \
			exit 1; \
		fi; \
	fi
	@CURRENT_VERSION=$$(cat $(VERSION_FILE) 2>/dev/null || echo "unknown"); \
	echo "Deploying version $(VERSION) with project name $(PROJECT_NAME)..."; \
	echo "Using deployment directory: $(DEPLOY_DIR)"; \
	if [ "$${CURRENT_VERSION}" != "unknown" ]; then \
		TEMP_BACKUP="backup_before_deploy_$$($(DATE) +%Y%m%d_%H%M%S)"; \
		$(MKDIR) $(DEPLOY_DIR)/$${TEMP_BACKUP}; \
		$(RSYNC) \
			--exclude="$(DEPLOY_DIR)" \
			--exclude="node_modules" \
			--exclude=".git" \
			--exclude="__pycache__" \
			--exclude="*.pyc" \
			./ $(DEPLOY_DIR)/$${TEMP_BACKUP}/; \
		echo "Created temporary backup in $(DEPLOY_DIR)/$${TEMP_BACKUP}"; \
	fi; \
	echo "Stopping current containers..."; \
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) down; \
	echo "Copying version files to project directory..."; \
	$(RSYNC) --delete \
		--exclude="$(DEPLOY_DIR)" \
		--exclude="node_modules" \
		--exclude=".git" \
		--exclude="Makefile" \
		$(VERSIONS_DIR)/$(VERSION)/ ./; \
	if [ ! -z "$(FRONTEND_PORT)" ] && [ -f "$(DC_FILE)" ]; then \
		echo "Updating frontend port to $(FRONTEND_PORT) in $(DC_FILE)..."; \
		cp "$(DC_FILE)" "$(DC_FILE).bak"; \
		$(SED) -i -E "s|127\.0\.0\.1:[0-9]+:80|127.0.0.1:$(FRONTEND_PORT):80|g" "$(DC_FILE)"; \
		echo "Frontend port updated in $(DC_FILE)"; \
	fi; \
	echo "Starting containers with version $(VERSION)..."; \
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) up -d --build; \
	echo "Checking container status..."; \
	$(SLEEP) 10; \
	if $(DOCKER_COMPOSE) -p $(PROJECT_NAME) ps | $(GREP) -q "Exit"; then \
		echo "Error: One or more containers failed to start"; \
		if [ "$${CURRENT_VERSION}" != "unknown" ]; then \
			echo "Automatic rollback to version $${CURRENT_VERSION}..."; \
			$(RSYNC) --delete \
				--exclude="$(DEPLOY_DIR)" \
				--exclude="node_modules" \
				--exclude=".git" \
				--exclude="Makefile" \
				$(VERSIONS_DIR)/$${CURRENT_VERSION}/ ./; \
			$(DOCKER_COMPOSE) -p $(PROJECT_NAME) up -d --build; \
			echo "Rollback to version $${CURRENT_VERSION} completed"; \
		else \
			echo "Cannot perform automatic rollback: previous version unknown"; \
		fi; \
		if [ -d "$(DEPLOY_DIR)/$${TEMP_BACKUP}" ]; then \
			$(RM) $(DEPLOY_DIR)/$${TEMP_BACKUP}; \
		fi; \
		exit 1; \
	fi; \
	echo "$(VERSION)" > $(VERSION_FILE); \
	echo "$$($(DATE) "+%Y-%m-%d %H:%M:%S") - Deployed version $(VERSION) with project name $(PROJECT_NAME)" >> $(VERSION_LOG); \
	if [ -d "$(DEPLOY_DIR)/$${TEMP_BACKUP}" ]; then \
		$(RM) $(DEPLOY_DIR)/$${TEMP_BACKUP}; \
	fi; \
	echo "Version $(VERSION) successfully deployed with project name $(PROJECT_NAME)"

# List available versions with current version marked
.PHONY: list
list: $(VERSIONS_DIR)
	@echo "Available versions in $(DEPLOY_DIR):"
	@if [ ! -d "$(VERSIONS_DIR)" ] || [ -z "$(shell ls -A $(VERSIONS_DIR) 2>/dev/null)" ]; then \
		echo "  No versions found"; \
	else \
		CURRENT_VERSION=$$(cat $(VERSION_FILE) 2>/dev/null || echo ""); \
		for d in $(VERSIONS_DIR)/*; do \
			if [ -d "$${d}" ] && [[ ! "$$(basename "$${d}")" == *backup_before_deploy_* ]] && [[ ! "$$(basename "$${d}")" == *backup_before_rollback_* ]]; then \
				v="$$(basename "$${d}")"; \
				created=$$(stat -c %y "$${d}" | cut -d" " -f1); \
				binfo=""; \
				if [ -f "$${d}/branch.info" ]; then \
					binfo=$$(cat "$${d}/branch.info"); \
				fi; \
				if [ "$${v}" = "$${CURRENT_VERSION}" ]; then \
					if [ ! -z "$${binfo}" ]; then \
						echo "* $${v} (created: $${created}) [$${binfo}]"; \
					else \
						echo "* $${v} (created: $${created})"; \
					fi; \
				else \
					if [ ! -z "$${binfo}" ]; then \
						echo "  $${v} (created: $${created}) [$${binfo}]"; \
					else \
						echo "  $${v} (created: $${created})"; \
					fi; \
				fi; \
			fi; \
		done; \
	fi

# Show current version
.PHONY: current
current:
	@if [ -f "$(VERSION_FILE)" ]; then \
		CURRENT_VERSION=$$(cat $(VERSION_FILE)); \
		echo "Current version: $${CURRENT_VERSION} (in $(DEPLOY_DIR))"; \
	else \
		echo "Current version not set in $(DEPLOY_DIR)"; \
	fi

# Delete a version (if not active)
.PHONY: delete
delete: check-version $(VERSIONS_DIR)
	@echo "Preparing to delete version $(VERSION)..."
	@if [ ! -d "$(VERSIONS_DIR)/$(VERSION)" ]; then \
		echo "Error: Version $(VERSION) not found"; \
		echo "Available versions:"; \
		$(MAKE) -s list; \
		exit 1; \
	fi
	@if [ -f "$(VERSION_FILE)" ]; then \
		CURRENT_VERSION=$$(cat $(VERSION_FILE) 2>/dev/null || echo ""); \
		if [ "$${CURRENT_VERSION}" = "$(VERSION)" ]; then \
			echo "Error: Cannot delete active version $(VERSION)"; \
			echo "Please deploy a different version before deleting this one"; \
			exit 1; \
		fi; \
	fi
	@if [ "$(FORCE)" = "1" ]; then \
		echo "Force flag detected. Deleting version $(VERSION) without confirmation..."; \
		$(RM) -r "$(VERSIONS_DIR)/$(VERSION)"; \
		echo "$$($(DATE) "+%Y-%m-%d %H:%M:%S") - Deleted version $(VERSION) (FORCE=1)" >> $(VERSION_LOG); \
		echo "Version $(VERSION) has been deleted"; \
	else \
		echo -n "Are you sure you want to delete version $(VERSION)? This action cannot be undone. [y/N] "; \
		read confirm; \
		if [ "$${confirm}" = "y" ] || [ "$${confirm}" = "Y" ]; then \
			echo "Deleting version $(VERSION)..."; \
			$(RM) -r "$(VERSIONS_DIR)/$(VERSION)"; \
			echo "$$($(DATE) "+%Y-%m-%d %H:%M:%S") - Deleted version $(VERSION)" >> $(VERSION_LOG); \
			echo "Version $(VERSION) has been deleted"; \
		else \
			echo "Delete operation cancelled"; \
		fi; \
	fi

# Verify version parameter is provided
.PHONY: check-version
check-version:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION parameter is required"; \
		echo "Usage: make $(MAKECMDGOALS) VERSION=<version>"; \
		exit 1; \
	fi

# Set version as active without deployment
.PHONY: active
active: check-version $(VERSIONS_DIR)
	@echo "Setting version $(VERSION) as active..."
	@if [ ! -d "$(VERSIONS_DIR)/$(VERSION)" ]; then \
		echo "Error: Version $(VERSION) not found"; \
		echo "Available versions:"; \
		$(MAKE) -s list; \
		exit 1; \
	fi
	@echo "$(VERSION)" > $(VERSION_FILE)
	@echo "$$($(DATE) "+%Y-%m-%d %H:%M:%S") - Set version $(VERSION) as active" >> $(VERSION_LOG)
	@echo "Version $(VERSION) is now set as active"
	@echo "Note: This command only updates the active version marker."
	@echo "      It does not affect running containers or files."
	@echo "      Use 'make deploy' to actually deploy this version."
