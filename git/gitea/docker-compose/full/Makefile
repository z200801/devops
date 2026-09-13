SHELL        := /bin/bash
PROJECT      := gitea
SERVICE      := gitea
COMPOSE_FILE := docker-compose.yml
COMPOSE      := docker compose -p $(PROJECT) -f $(COMPOSE_FILE)
TIMESTAMP    := $(shell date +%Y%m%d%H%M%S)
DEPLOY_DIR   := $(HOME)/deploy/$(PROJECT)
VERSIONS_DIR := $(DEPLOY_DIR)/versions
ACTIVE_FILE  := $(DEPLOY_DIR)/active_version
BACKUP_DIR   := $(HOME)/backups/$(PROJECT)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# --- Container management ---

.PHONY: up
up: ## Start stack in background
	$(COMPOSE) up -d

.PHONY: down
down: ## Stop and remove containers
	$(COMPOSE) down

.PHONY: restart
restart: ## Restart containers (SVC=<service> to target one)
	$(COMPOSE) restart $(SVC)

.PHONY: status
status: ## Show container status
	$(COMPOSE) ps

.PHONY: logs
logs: ## Tail logs (SVC=<service> to tail one)
	$(COMPOSE) logs -f $(SVC)

# --- Version management ---

.PHONY: version-create
version-create: ## Snapshot working directory as a timestamped version
	@mkdir -p "$(VERSIONS_DIR)"; \
	NAME="$(TIMESTAMP)"; \
	rsync -a --exclude='.git' . "$(VERSIONS_DIR)/$$NAME"; \
	echo "$$NAME" > "$(ACTIVE_FILE)"; \
	echo "Created and activated: $$NAME"

.PHONY: version-list
version-list: ## List versions (* = active)
	@CURRENT=$$(cat "$(ACTIVE_FILE)" 2>/dev/null || echo none); \
	for v in $$(ls -1t "$(VERSIONS_DIR)" 2>/dev/null); do \
		if [ "$$v" = "$$CURRENT" ]; then echo "* $$v"; else echo "  $$v"; fi; \
	done

.PHONY: version-set
version-set: _check-version ## Activate a version (VERSION=<name>)
	@[ -d "$(VERSIONS_DIR)/$(VERSION)" ] || { echo "Not found: $(VERSION)"; exit 1; }; \
	echo "$(VERSION)" > "$(ACTIVE_FILE)"; \
	echo "Active: $(VERSION)"

.PHONY: version-delete
version-delete: _check-version ## Delete a version (VERSION=<name>; FORCE=1 to delete active)
	@CURRENT=$$(cat "$(ACTIVE_FILE)" 2>/dev/null); \
	if [ "$(VERSION)" = "$$CURRENT" ] && [ "$(FORCE)" != "1" ]; then \
		echo "Cannot delete active version. Use FORCE=1 to override."; exit 1; \
	fi; \
	rm -rf "$(VERSIONS_DIR)/$(VERSION)"; \
	echo "Deleted: $(VERSION)"

# --- Deployment ---

.PHONY: deploy
deploy: ## Start the active version (falls back to working directory)
	@if [ -f "$(ACTIVE_FILE)" ]; then \
		V=$$(cat "$(ACTIVE_FILE)"); echo "Deploying: $$V"; \
		cd "$(VERSIONS_DIR)/$$V" && docker compose -p $(PROJECT) -f $(COMPOSE_FILE) up -d; \
	else \
		$(COMPOSE) up -d; \
	fi

.PHONY: rollback
rollback: ## Activate the previous version (run make deploy after to apply)
	@CURRENT=$$(cat "$(ACTIVE_FILE)" 2>/dev/null || echo none); \
	PREV=$$(ls -1t "$(VERSIONS_DIR)" 2>/dev/null | grep -v "^$$CURRENT$$" | head -1); \
	[ -z "$$PREV" ] && { echo "No previous version found"; exit 1; }; \
	echo "$$PREV" > "$(ACTIVE_FILE)"; \
	echo "Active version set to: $$PREV (run make deploy to apply)"

# --- Backup ---

.PHONY: gitea-backup-list
gitea-backup-list: ## List available backups in $(BACKUP_DIR)
	@ls -1th "$(BACKUP_DIR)"/gitea*.tar.gz 2>/dev/null | while read f; do \
		sz=$$(du -h "$$f" | cut -f1); \
		printf "  %-50s %s\n" "$$(basename $$f)" "$$sz"; \
	done; \
	total=$$(ls -1 "$(BACKUP_DIR)"/gitea*.tar.gz 2>/dev/null | wc -l); \
	echo "---"; echo "Total: $$total backup(s) in $(BACKUP_DIR)"

.PHONY: gitea-backup
gitea-backup: ## Dump Gitea data to $(BACKUP_DIR) using gitea dump
	@mkdir -p "$(BACKUP_DIR)"
	$(COMPOSE) exec --user 1000 $(SERVICE) \
		gitea dump --type tar.gz -f /tmp/gitea-$(TIMESTAMP).tar.gz
	$(COMPOSE) cp $(SERVICE):/tmp/gitea-$(TIMESTAMP).tar.gz "$(BACKUP_DIR)/"
	$(COMPOSE) exec $(SERVICE) rm /tmp/gitea-$(TIMESTAMP).tar.gz
	@echo "Backup: $(BACKUP_DIR)/gitea-$(TIMESTAMP).tar.gz"

.PHONY: gitea-restore
gitea-restore: _check-backup ## Restore Gitea from a dump archive (BACKUP=<path-to-tar.gz>)
	@echo "==> Stopping stack..."
	$(COMPOSE) down
	@echo "==> Starting only db..."
	$(COMPOSE) up -d db
	@sleep 5
	@echo "==> Extracting backup..."
	@TMPDIR=$$(mktemp -d); \
	tar xzf "$(BACKUP)" -C "$$TMPDIR" && \
	echo "==> Restoring database..." && \
	$(COMPOSE) exec -T db bash -c \
		'dropdb -U $${POSTGRES_USER:-gitea} --if-exists $${POSTGRES_DB:-gitea} && \
		 createdb -U $${POSTGRES_USER:-gitea} $${POSTGRES_DB:-gitea}' && \
	cat "$$TMPDIR/gitea-db.sql" | $(COMPOSE) exec -T db \
		psql -U $${POSTGRES_USER:-gitea} -d $${POSTGRES_DB:-gitea} -q && \
	echo "==> Starting full stack..." && \
	$(COMPOSE) up -d && \
	sleep 5 && \
	echo "==> Restoring files..." && \
	$(COMPOSE) cp "$$TMPDIR/data/." $(SERVICE):/data/gitea/ && \
	$(COMPOSE) cp "$$TMPDIR/repos/." $(SERVICE):/data/git/repositories/ && \
	echo "==> Regenerating hooks..." && \
	$(COMPOSE) exec --user 1000 $(SERVICE) gitea admin regenerate hooks && \
	$(COMPOSE) restart $(SERVICE) && \
	rm -rf "$$TMPDIR" && \
	echo "Restore complete. Verify with: $(COMPOSE) exec --user 1000 $(SERVICE) gitea doctor check"

.PHONY: gitea-backup-repos
gitea-backup-repos: ## Archive only Git repositories to $(BACKUP_DIR)
	@mkdir -p "$(BACKUP_DIR)"
	$(COMPOSE) exec --user 1000 $(SERVICE) \
		tar czf /tmp/gitea-repos-$(TIMESTAMP).tar.gz -C /data/git repositories
	$(COMPOSE) cp $(SERVICE):/tmp/gitea-repos-$(TIMESTAMP).tar.gz "$(BACKUP_DIR)/"
	$(COMPOSE) exec $(SERVICE) rm /tmp/gitea-repos-$(TIMESTAMP).tar.gz
	@echo "Repos backup: $(BACKUP_DIR)/gitea-repos-$(TIMESTAMP).tar.gz"

.PHONY: gitea-restore-repos
gitea-restore-repos: _check-backup ## Restore only Git repositories (BACKUP=<path-to-tar.gz>)
	$(COMPOSE) cp "$(BACKUP)" $(SERVICE):/tmp/gitea-repos-restore.tar.gz
	$(COMPOSE) exec --user 1000 $(SERVICE) \
		tar xzf /tmp/gitea-repos-restore.tar.gz -C /data/git
	$(COMPOSE) exec $(SERVICE) rm /tmp/gitea-repos-restore.tar.gz
	$(COMPOSE) exec --user 1000 $(SERVICE) gitea admin regenerate hooks
	$(COMPOSE) restart $(SERVICE)
	@echo "Repos restored. Hooks regenerated."

.PHONY: gitea-backup-gc
gitea-backup-gc: ## GC old backups: keep COUNT per period (COUNT=3, FORCE=1 to delete)
	@COUNT=$${COUNT:-3}; \
	[ $$COUNT -lt 2 ] && { echo "COUNT must be >= 2"; exit 1; }; \
	KEEP=$$(mktemp); \
	mapfile -t FILES < <(ls -1t "$(BACKUP_DIR)"/gitea*.tar.gz 2>/dev/null); \
	if [ $${#FILES[@]} -eq 0 ]; then echo "No backups in $(BACKUP_DIR)"; rm -f "$$KEEP"; exit 0; fi; \
	_pick() { \
		local level=$$1; local n=0; local -A seen; \
		for f in "$${FILES[@]}"; do \
			ts=$$(basename "$$f" | grep -oE '[0-9]{14}'); \
			case $$level in \
				daily)   key=$${ts:0:8} ;; \
				weekly)  key=$$(date -d "$${ts:0:8}" +%G-W%V) ;; \
				monthly) key=$${ts:0:6} ;; \
				yearly)  key=$${ts:0:4} ;; \
			esac; \
			if [ -z "$${seen[$$key]+x}" ]; then \
				seen[$$key]=1; \
				echo "$$f" >> "$$KEEP"; \
				n=$$((n+1)); \
				[ $$n -ge $$COUNT ] && break; \
			fi; \
		done; \
	}; \
	_pick daily; _pick weekly; _pick monthly; _pick yearly; \
	KEPT=$$(sort -u "$$KEEP"); \
	echo "Retention: $$COUNT daily, $$COUNT weekly, $$COUNT monthly, $$COUNT yearly"; \
	echo "---"; \
	del=0; \
	for f in "$${FILES[@]}"; do \
		if echo "$$KEPT" | grep -qxF "$$f"; then \
			echo "  keep:   $$(basename $$f)"; \
		else \
			del=$$((del+1)); \
			if [ "$${FORCE:-0}" = "1" ]; then \
				rm "$$f"; \
				echo "  delete: $$(basename $$f)"; \
			else \
				echo "  delete: $$(basename $$f) (dry run)"; \
			fi; \
		fi; \
	done; \
	rm -f "$$KEEP"; \
	echo "---"; \
	echo "Total: $${#FILES[@]}, keep: $$(( $${#FILES[@]} - $$del )), delete: $$del"; \
	if [ "$${FORCE:-0}" != "1" ] && [ $$del -gt 0 ]; then echo "Dry run. Use FORCE=1 to delete."; fi; true

# --- TLS ---

.PHONY: traefik-cert-generate
traefik-cert-generate: _check-domain ## Generate self-signed cert+key into ./certs/
	@mkdir -p ./certs
	openssl req -x509 -newkey rsa:4096 \
		-keyout ./certs/key.pem \
		-out ./certs/cert.pem \
		-days 365 -nodes \
		-subj "/CN=$(DOMAIN)" \
		-addext "subjectAltName=DNS:$(DOMAIN)"
	@echo "Generated: ./certs/cert.pem ./certs/key.pem"

# --- Gitea admin ---

.PHONY: gitea-registration-enable
gitea-registration-enable: ## Allow new user self-registration
	$(COMPOSE) exec --user 1000 $(SERVICE) \
		bash -c 'sed -i "/DISABLE_REGISTRATION/ s/true/false/g" /data/gitea/conf/app.ini'
	$(COMPOSE) restart $(SERVICE)

.PHONY: gitea-user-list
gitea-user-list: ## List all Gitea users
	$(COMPOSE) exec --user 1000 $(SERVICE) gitea admin user list

.PHONY: gitea-registry-enable
gitea-registry-enable: ## Enable the Gitea package/container registry
	$(COMPOSE) exec --user 1000 $(SERVICE) \
		bash -c 'grep -q "^\[packages\]" /data/gitea/conf/app.ini \
		&& sed -i "/^\[packages\]/,/^\[/ s/^ENABLED.*/ENABLED = true/" /data/gitea/conf/app.ini \
		|| printf "\n[packages]\nENABLED = true\n" >> /data/gitea/conf/app.ini'
	$(COMPOSE) restart $(SERVICE)

# --- Internal ---

.PHONY: _check-version
_check-version:
ifndef VERSION
	$(error VERSION is required. Usage: make <target> VERSION=<name>)
endif

.PHONY: _check-domain
_check-domain:
ifndef DOMAIN
	$(eval DOMAIN := $(shell grep -oP '^DOMAIN=\K.*' .env 2>/dev/null))
endif
ifndef DOMAIN
	$(error DOMAIN is required. Set it in .env or pass DOMAIN=<domain>)
endif

.PHONY: _check-backup
_check-backup:
ifndef BACKUP
	$(error BACKUP is required. Usage: make gitea-restore BACKUP=~/backups/gitea/gitea-<timestamp>.tar.gz)
endif
