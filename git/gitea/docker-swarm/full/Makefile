SHELL      := /bin/bash
STACK      := gitea
STACK_FILE := stack.yml
ENV_FILE   := .env
GITEA_SVC  := $(STACK)_gitea
BACKUP_DIR := $(HOME)/backups/$(STACK)
TIMESTAMP  := $(shell date +%Y%m%d%H%M%S)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# --- Stack management ---

.PHONY: stack-deploy
stack-deploy: ## Deploy or update the Swarm stack
	@set -a; source $(ENV_FILE); set +a; \
	docker stack deploy -c $(STACK_FILE) $(STACK)

.PHONY: stack-rm
stack-rm: ## Remove the Swarm stack (does not delete volumes or secrets)
	docker stack rm $(STACK)

.PHONY: stack-status
stack-status: ## Show stack service status
	docker stack services $(STACK)

.PHONY: service-restart
service-restart: _check-service ## Force-restart a service (SERVICE=<gitea|db|traefik>)
	docker service update --force $(STACK)_$(SERVICE)

.PHONY: logs
logs: _check-service ## Tail service logs (SERVICE=<gitea|db|traefik>)
	docker service logs -f $(STACK)_$(SERVICE)

# --- Secrets ---

STACK_SECRETS := gitea_db_password gitea_admin_password

.PHONY: secrets-create
secrets-create: ## Create all required secrets (auto-generates values)
	@for name in $(STACK_SECRETS); do \
		if docker secret inspect $$name >/dev/null 2>&1; then \
			echo "  exists: $$name"; \
		else \
			val=$$(openssl rand -hex 16); \
			echo -n "$$val" | docker secret create $$name - && \
			echo "  created: $$name = $$val"; \
		fi; \
	done

.PHONY: secret-create
secret-create: _check-name ## Create one secret from stdin: echo -n <val> | make secret-create NAME=<name>
	docker secret create $(STACK)_$(NAME) -
	@echo "Created: $(STACK)_$(NAME)"

.PHONY: secret-rm
secret-rm: _check-name ## Remove a secret (NAME=<name>)
	docker secret rm $(STACK)_$(NAME)

.PHONY: secrets-list
secrets-list: ## List Docker secrets belonging to this stack
	@docker secret ls --filter name=$(STACK)_

.PHONY: secrets-ls
secrets-ls: ## Show secret names and values for this stack
	@G_CID=$$(docker ps -q -f name=$(GITEA_SVC)); \
	if [ -z "$$G_CID" ]; then echo "No running container for $(GITEA_SVC)"; exit 1; fi; \
	docker exec $$G_CID sh -c 'for f in /run/secrets/*; do \
		[ -f "$$f" ] || continue; \
		printf "  %-30s %s\n" "$$(basename $$f)" "$$(cat $$f)"; \
	done'

.PHONY: secrets-rotate
secrets-rotate: ## Rotate all secrets and update services
	@for name in $(STACK_SECRETS); do \
		val=$$(openssl rand -hex 16); \
		_ver=$$(date +%s); \
		_new="$${name}_$$_ver"; \
		echo -n "$$val" | docker secret create "$$_new" - && \
		echo "  rotated: $$name → $$_new = $$val"; \
	done; \
	echo "---"; \
	echo "Redeploy to apply: make stack-deploy"

.PHONY: secret-rotate
secret-rotate: _check-name ## Rotate one secret (NAME=<name> VALUE=<val>, auto-generates if no VALUE)
	@_full=$(STACK)_$(NAME); \
	_val=$${VALUE:-$$(openssl rand -hex 16)}; \
	_ver=$$(date +%s); \
	_new="$${_full}_$$_ver"; \
	echo -n "$$_val" | docker secret create "$$_new" - && \
	echo "Rotated: $$_full → $$_new"; \
	if [ -z "$${VALUE}" ]; then echo "Value: $$_val"; fi; \
	echo "Update service: docker service update --secret-rm $$_full --secret-add source=$$_new,target=$$_full <service>"

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
	docker exec $$(docker ps -q -f name=$(GITEA_SVC)) \
		su -c 'gitea dump --type tar.gz -f /tmp/gitea-$(TIMESTAMP).tar.gz' git
	docker cp $$(docker ps -q -f name=$(GITEA_SVC)):/tmp/gitea-$(TIMESTAMP).tar.gz "$(BACKUP_DIR)/"
	docker exec $$(docker ps -q -f name=$(GITEA_SVC)) rm /tmp/gitea-$(TIMESTAMP).tar.gz
	@echo "Backup: $(BACKUP_DIR)/gitea-$(TIMESTAMP).tar.gz"

.PHONY: gitea-restore
gitea-restore: _check-backup ## Restore Gitea from a dump archive (BACKUP=<path-to-tar.gz>)
	@echo "==> Scaling gitea to 0..."
	docker service scale $(GITEA_SVC)=0 --detach=false
	@echo "==> Extracting backup..."
	@TMPDIR=$$(mktemp -d); \
	tar xzf "$(BACKUP)" -C "$$TMPDIR" && \
	echo "==> Restoring database..." && \
	DB_CID=$$(docker ps -q -f name=$(STACK)_db) && \
	docker exec $$DB_CID bash -c \
		'dropdb -U $${POSTGRES_USER:-gitea} --if-exists $${POSTGRES_DB:-gitea} && \
		 createdb -U $${POSTGRES_USER:-gitea} $${POSTGRES_DB:-gitea}' && \
	cat "$$TMPDIR/gitea-db.sql" | docker exec -i $$DB_CID \
		psql -U $${POSTGRES_USER:-gitea} -d $${POSTGRES_DB:-gitea} -q && \
	echo "==> Scaling gitea to 1..." && \
	docker service scale $(GITEA_SVC)=1 --detach=false && \
	sleep 5 && \
	G_CID=$$(docker ps -q -f name=$(GITEA_SVC)) && \
	echo "==> Restoring files..." && \
	docker cp "$$TMPDIR/data/." $$G_CID:/data/gitea/ && \
	docker cp "$$TMPDIR/repos/." $$G_CID:/data/git/repositories/ && \
	echo "==> Regenerating hooks..." && \
	docker exec $$G_CID su -c 'gitea admin regenerate hooks' git && \
	docker service update --force $(GITEA_SVC) && \
	rm -rf "$$TMPDIR" && \
	echo "Restore complete."

.PHONY: gitea-backup-repos
gitea-backup-repos: ## Archive only Git repositories to $(BACKUP_DIR)
	@mkdir -p "$(BACKUP_DIR)"
	docker exec $$(docker ps -q -f name=$(GITEA_SVC)) \
		tar czf /tmp/gitea-repos-$(TIMESTAMP).tar.gz -C /data/git repositories
	docker cp $$(docker ps -q -f name=$(GITEA_SVC)):/tmp/gitea-repos-$(TIMESTAMP).tar.gz "$(BACKUP_DIR)/"
	docker exec $$(docker ps -q -f name=$(GITEA_SVC)) rm /tmp/gitea-repos-$(TIMESTAMP).tar.gz
	@echo "Repos backup: $(BACKUP_DIR)/gitea-repos-$(TIMESTAMP).tar.gz"

.PHONY: gitea-restore-repos
gitea-restore-repos: _check-backup ## Restore only Git repositories (BACKUP=<path-to-tar.gz>)
	docker cp "$(BACKUP)" $$(docker ps -q -f name=$(GITEA_SVC)):/tmp/gitea-repos-restore.tar.gz
	docker exec $$(docker ps -q -f name=$(GITEA_SVC)) \
		tar xzf /tmp/gitea-repos-restore.tar.gz -C /data/git
	docker exec $$(docker ps -q -f name=$(GITEA_SVC)) rm /tmp/gitea-repos-restore.tar.gz
	docker exec $$(docker ps -q -f name=$(GITEA_SVC)) su -c 'gitea admin regenerate hooks' git
	docker service update --force $(GITEA_SVC)
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

TRAEFIK_CERT_CONFIGS := $(STACK)_traefik_cert:./certs/cert.pem $(STACK)_traefik_key:./certs/key.pem
TRAEFIK_DYN_CONFIGS  := $(STACK)_traefik_dynamic_tls:./traefik/dynamic/tls.yml:/etc/traefik/dynamic/tls.yml
TRAEFIK_CONFIGS      := $(TRAEFIK_CERT_CONFIGS) $(TRAEFIK_DYN_CONFIGS)

.PHONY: traefik-config-create
traefik-config-create: ## Create Docker configs for Traefik (certs + dynamic TLS)
	@for entry in $(TRAEFIK_CONFIGS); do \
		cfg=$${entry%%:*}; file=$${entry#*:}; file=$${file%%:*}; \
		if docker config inspect $$cfg >/dev/null 2>&1; then \
			echo "  exists: $$cfg"; \
		else \
			docker config create $$cfg $$file && \
			echo "  created: $$cfg ← $$file"; \
		fi; \
	done

.PHONY: traefik-config-ls
traefik-config-ls: ## List Docker configs for Traefik
	@docker config ls --filter name=$(STACK)_traefik_

.PHONY: traefik-config-rm
traefik-config-rm: ## Remove all Traefik Docker configs (stack must be stopped)
	@for entry in $(TRAEFIK_CONFIGS); do \
		cfg=$${entry%%:*}; \
		if docker config inspect $$cfg >/dev/null 2>&1; then \
			docker config rm $$cfg && echo "  removed: $$cfg"; \
		else \
			echo "  absent: $$cfg"; \
		fi; \
	done

.PHONY: traefik-config-rotate
traefik-config-rotate: ## Rotate Traefik configs (tls.yml) without stopping gitea/db
	@for entry in $(TRAEFIK_DYN_CONFIGS); do \
		cfg=$${entry%%:*}; rest=$${entry#*:}; file=$${rest%%:*}; target=$${rest#*:}; \
		tmp=$${cfg}_tmp; \
		docker config rm $$tmp 2>/dev/null || true; \
		echo "==> Creating temporary config $$tmp..." && \
		docker config create $$tmp $$file && \
		echo "==> Swapping $$cfg → $$tmp on traefik..." && \
		docker service update \
			--config-rm $$cfg \
			--config-add source=$$tmp,target=$$target \
			$(STACK)_traefik && \
		echo "==> Verifying traefik health..." && \
		sleep 5 && \
		if ! docker service ps --filter desired-state=running --format '{{.CurrentState}}' $(STACK)_traefik | grep -q Running; then \
			echo "!!! Traefik not healthy — rolling back..." && \
			docker service update \
				--config-rm $$tmp \
				--config-add source=$$cfg,target=$$target \
				$(STACK)_traefik && \
			docker config rm $$tmp && \
			echo "Rolled back. Aborting." && exit 1; \
		fi && \
		echo "==> Traefik healthy. Replacing permanent config..." && \
		docker config rm $$cfg && \
		docker config create $$cfg $$file && \
		echo "==> Swapping $$tmp → $$cfg on traefik..." && \
		docker service update \
			--config-rm $$tmp \
			--config-add source=$$cfg,target=$$target \
			$(STACK)_traefik && \
		docker config rm $$tmp && \
		echo "  rotated: $$cfg"; \
	done && \
	echo "Traefik configs rotated."

.PHONY: traefik-cert-rotate
traefik-cert-rotate: _check-domain ## Rotate TLS certs+configs: stack-rm → generate → recreate → stack-deploy
	@set -a; source $(ENV_FILE); set +a; \
	echo "==> Removing stack..." && \
	docker stack rm $(STACK) && \
	echo "==> Waiting for stack removal..." && \
	while docker network inspect $(STACK)_gitea >/dev/null 2>&1; do sleep 1; done && \
	echo "==> Removing old configs..." && \
	for entry in $(TRAEFIK_CONFIGS); do \
		cfg=$${entry%%:*}; \
		docker config rm $$cfg 2>/dev/null && echo "  removed: $$cfg" || true; \
	done && \
	echo "==> Generating new certificate..." && \
	mkdir -p ./certs && \
	openssl req -x509 -newkey rsa:4096 \
		-keyout ./certs/key.pem \
		-out ./certs/cert.pem \
		-days 365 -nodes \
		-subj "/CN=$(DOMAIN)" \
		-addext "subjectAltName=DNS:$(DOMAIN)" && \
	echo "==> Creating new configs..." && \
	for entry in $(TRAEFIK_CONFIGS); do \
		cfg=$${entry%%:*}; file=$${entry#*:}; file=$${file%%:*}; \
		docker config create $$cfg $$file && \
		echo "  created: $$cfg ← $$file"; \
	done && \
	echo "==> Deploying stack..." && \
	docker stack deploy -c $(STACK_FILE) $(STACK) && \
	echo "Certificate rotated and stack redeployed."

# --- Gitea admin ---

.PHONY: gitea-registration-enable
gitea-registration-enable: ## Allow new user self-registration
	docker exec $$(docker ps -q -f name=$(GITEA_SVC)) \
		su -c "sed -i '/DISABLE_REGISTRATION/ s/true/false/g' /data/gitea/conf/app.ini" git
	docker service update --force $(GITEA_SVC)

.PHONY: gitea-user-list
gitea-user-list: ## List all Gitea users
	docker exec $$(docker ps -q -f name=$(GITEA_SVC)) \
		su -c 'gitea admin user list' git

.PHONY: gitea-registry-enable
gitea-registry-enable: ## Enable the Gitea package/container registry
	docker exec $$(docker ps -q -f name=$(GITEA_SVC)) \
		su -c 'grep -q "^\[packages\]" /data/gitea/conf/app.ini \
		&& sed -i "/^\[packages\]/,/^\[/ s/^ENABLED.*/ENABLED = true/" /data/gitea/conf/app.ini \
		|| printf "\n[packages]\nENABLED = true\n" >> /data/gitea/conf/app.ini' git
	docker service update --force $(GITEA_SVC)

# --- Internal ---

.PHONY: _check-service
_check-service:
ifndef SERVICE
	$(error SERVICE is required. Usage: make service-restart SERVICE=<gitea|db|traefik>)
endif

.PHONY: _check-name
_check-name:
ifndef NAME
	$(error NAME is required. Creates: $(STACK)_NAME. Usage: make secret-create NAME=db_password)
endif

.PHONY: _check-domain
_check-domain:
ifndef DOMAIN
	$(eval DOMAIN := $(shell grep -oP '^DOMAIN=\K.*' $(ENV_FILE) 2>/dev/null))
endif
ifndef DOMAIN
	$(error DOMAIN is required. Set it in $(ENV_FILE) or pass DOMAIN=<domain>)
endif

.PHONY: _check-backup
_check-backup:
ifndef BACKUP
	$(error BACKUP is required. Usage: make restore BACKUP=~/backups/gitea/gitea-<timestamp>.tar.gz)
endif
