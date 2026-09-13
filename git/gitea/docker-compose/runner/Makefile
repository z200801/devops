SHELL    := /bin/bash
PROJECT  := gitea-runner
COMPOSE  := docker compose -p $(PROJECT) -f docker-compose.yml
ENV_FILE := .env

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: up
up: ## Start runner in background
	$(COMPOSE) up -d

.PHONY: down
down: ## Stop and remove runner container
	$(COMPOSE) down

.PHONY: restart
restart: ## Restart runner container
	$(COMPOSE) restart

.PHONY: status
status: ## Show runner container status
	$(COMPOSE) ps

.PHONY: logs
logs: ## Tail runner logs (Ctrl+C to stop)
	$(COMPOSE) logs -f

.PHONY: token-rotate
token-rotate: _check-token ## Rotate registration token: update .env and recreate container (TOKEN=<new>)
	@sed -i "s/^TOKEN=.*/TOKEN=$(TOKEN)/" $(ENV_FILE)
	$(COMPOSE) up -d --force-recreate

.PHONY: sync-config
sync-config: ## Restart runner to apply changes from data/config.yaml (bind-mounted)
	$(COMPOSE) restart

.PHONY: _check-token
_check-token:
ifndef TOKEN
	$(error TOKEN is required. Usage: make token-rotate TOKEN=<new-token>)
endif
