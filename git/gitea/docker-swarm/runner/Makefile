SHELL      := /bin/bash
STACK      := gitea-runner
STACK_FILE := stack.yml
ENV_FILE   := .env
SERVICE    := runner

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# --- Stack management ---

.PHONY: stack-deploy
stack-deploy: ## Deploy or update the runner stack
	@set -a; source $(ENV_FILE); set +a; \
	docker stack deploy -c $(STACK_FILE) $(STACK)

.PHONY: stack-rm
stack-rm: ## Remove the runner stack (does not delete volumes or secrets)
	docker stack rm $(STACK)

.PHONY: stack-status
stack-status: ## Show stack service status
	docker stack services $(STACK)

.PHONY: logs
logs: ## Tail runner service logs
	docker service logs -f $(STACK)_$(SERVICE)

# --- Secrets ---

.PHONY: secrets-create
secrets-create: ## Create runner token secret from stdin: echo -n <token> | make secrets-create
	@if docker secret inspect gitea_runner_token >/dev/null 2>&1; then \
		echo "  exists: gitea_runner_token"; \
	else \
		docker secret create gitea_runner_token - && \
		echo "  created: gitea_runner_token"; \
	fi

.PHONY: secrets-list
secrets-list: ## List Docker secrets belonging to this runner
	@docker secret ls --filter name=gitea_runner_token

.PHONY: secrets-ls
secrets-ls: ## Show secret names and values for this runner
	@R_CID=$$(docker ps -q -f name=$(STACK)_$(SERVICE)); \
	if [ -z "$$R_CID" ]; then echo "No running container for $(STACK)_$(SERVICE)"; exit 1; fi; \
	docker exec $$R_CID sh -c 'for f in /run/secrets/*; do \
		[ -f "$$f" ] || continue; \
		printf "  %-30s %s\n" "$$(basename $$f)" "$$(cat $$f)"; \
	done'

# --- Token rotation ---

.PHONY: token-rotate
token-rotate: ## Rotate runner token: echo -n <new-token> | make token-rotate (or VALUE=<token>)
	@_ver=$$(date +%s); \
	_new=gitea_runner_token_$$_ver; \
	if [ -n "$${VALUE}" ]; then \
		echo -n "$${VALUE}" | docker secret create "$$_new" -; \
	else \
		docker secret create "$$_new" -; \
	fi && \
	docker service update \
		--secret-rm gitea_runner_token \
		--secret-add "source=$$_new,target=gitea_runner_token" \
		$(STACK)_$(SERVICE) && \
	echo "Token rotated. Active secret: $$_new"
