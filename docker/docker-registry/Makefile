SHELL := /bin/bash

# ==============================================================================
# Configuration Variables
# ==============================================================================

# Environment: dev, qa, prod
ENV               ?= dev
TAG               ?= latest
SERVICE           ?= registry
SERVICES          ?= registry
STACK_NAME        ?= $(SERVICE)

# Paths
PROJECTS_DIR      ?= $(HOME)/projects/itv
DEPLOY_DIR         = $(PROJECTS_DIR)/$(SERVICE)/dswarm/$(ENV)/deploy
COMPOSE_FILE      := $(DEPLOY_DIR)/docker-compose.yml
COMPOSE_FILES      = $(SERVICES:%=docker-compose.yml)
ALL_SERVICES       = $(foreach f,$(COMPOSE_FILES),-c $(f))

# Git configuration
GIT_BRANCH        ?= dev
GIT_BRANCH_DEVOPS ?= devops
GIT_REPO_DIR      ?= $(PROJECTS_DIR)/main/repo

# Deployment
DEPLOY_INCLUDES   ?= *
DEPLOY_EXCLUDES   ?= ""

# Registry configuration
REGISTRY_HOST     ?= 10.10.1.2
REGISTRY_PORT     ?= 5000
REGISTRY_URL       = http://$(REGISTRY_HOST):$(REGISTRY_PORT)
REGISTRY_API       = $(REGISTRY_URL)/v2

# Manifest accept headers
MANIFEST_V2        = application/vnd.docker.distribution.manifest.v2+json
MANIFEST_LIST      = application/vnd.docker.distribution.manifest.list.v2+json
MANIFEST_OCI       = application/vnd.oci.image.manifest.v1+json

# ==============================================================================
# Helper Functions
# ==============================================================================

# Get registry container ID
define get_container_id
$(shell docker ps -q -f name=$(STACK_NAME)_$(SERVICE))
endef

# Check if container exists
define check_container
@CONTAINER_ID=$(call get_container_id); \
if [ -z "$$CONTAINER_ID" ]; then \
	echo "Error: Registry container not found"; \
	exit 1; \
fi
endef

# ==============================================================================
# Help & Utility
# ==============================================================================

.PHONY: help
help: ## Show this help message
	@echo 'Usage: make [target] [VARIABLE=value]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ==============================================================================
# Stack Deployment
# ==============================================================================

.PHONY: init
init: ## Initialize deployment directory
	@echo "Preparing deployment directory: $(DEPLOY_DIR)"
	@mkdir -p $(DEPLOY_DIR)
	@echo "✓ Directory ready"

.PHONY: copy-deploy-files
copy-deploy-files: ## Copy deployment files from repository
	@echo "Copying deployment files..."
	@cd $(GIT_REPO_DIR) && \
		git switch $(GIT_BRANCH_DEVOPS) && \
		cd projects/docker-$(SERVICE) && \
		rsync -av --exclude=".git" --exclude="$(DEPLOY_DIR)" \
			--include="$(DEPLOY_INCLUDES)" --exclude="$(DEPLOY_EXCLUDES)" . $(DEPLOY_DIR)
	@echo "✓ Files copied"

.PHONY: stack-ls
stack-ls: ## List all stacks
	@docker stack ls

.PHONY: stack-deploy
stack-deploy: ## Deploy stack
	@echo "Deploying stack '$(STACK_NAME)' with tag $(TAG)..."
	@cd $(DEPLOY_DIR) && docker stack deploy $(ALL_SERVICES) $(STACK_NAME)
	@echo "✓ Stack deployed"

.PHONY: stack-rm
stack-rm: ## Remove stack
	@echo "Removing stack '$(STACK_NAME)'..."
	@docker stack rm $(STACK_NAME)
	@echo "✓ Stack removed"

.PHONY: ps
ps: ## Show stack status
	@docker stack ps $(STACK_NAME)

# ==============================================================================
# Service Management
# ==============================================================================

.PHONY: service-ls
service-ls: ## List all services
	@docker service ls

.PHONY: services-stack-ls
services-stack-ls: ## List services in current stack
	@docker service ls -f name=$(STACK_NAME)

.PHONY: service-deploy
service-deploy: ## Deploy specific service (SERVICE=name)
	@echo "Deploying service $(SERVICE) in stack '$(STACK_NAME)' with tag $(TAG)"
	@cd $(DEPLOY_DIR) && \
		docker stack deploy -c $(COMPOSE_FILE) --with-registry-auth $(STACK_NAME)
	@echo "✓ Service deployed"

.PHONY: service-scale
service-scale: ## Scale service (SERVICE=name REPLICAS=n)
ifndef REPLICAS
	$(error REPLICAS is not set. Example: make service-scale SERVICE=registry REPLICAS=3)
endif
	@echo "Scaling $(SERVICE) to $(REPLICAS) replicas..."
	@docker service scale $(STACK_NAME)_$(SERVICE)=$(REPLICAS)
	@echo "✓ Service scaled"

.PHONY: logs
logs: ## Show service logs (SERVICE=name)
	@docker service logs -f $(STACK_NAME)_$(SERVICE)

.PHONY: service-env
service-env: ## Show service environment variables (SERVICE=name)
	@echo "Environment for $(SERVICE):"
	@docker service inspect $(STACK_NAME)_$(SERVICE) | jq '.[].Spec.TaskTemplate.ContainerSpec.Env'

# ==============================================================================
# Registry - Information
# ==============================================================================

.PHONY: registry-info
registry-info: ## Show registry information and health
	@echo "=== Registry Information ==="
	@echo "Host:     $(REGISTRY_HOST):$(REGISTRY_PORT)"
	@echo "Endpoint: $(REGISTRY_API)/"
	@echo ""
	@echo "Total repositories: $$(curl -s $(REGISTRY_API)/_catalog | jq '.repositories | length')"
	@echo ""
	@echo "=== Health Check ==="
	@curl -s $(REGISTRY_API)/ | jq

.PHONY: registry-list
registry-list: ## List all repositories
	@echo "=== Repositories ==="
	@curl -s $(REGISTRY_API)/_catalog | jq -r '.repositories[]'

.PHONY: registry-list-all
registry-list-all: ## List all images with tags and short digests
	@echo "=== All Images and Tags ==="
	@curl -s $(REGISTRY_API)/_catalog | jq -r '.repositories[]' | while read repo; do \
		echo ""; \
		echo "Repository: $$repo"; \
		curl -s $(REGISTRY_API)/$$repo/tags/list | jq -r '.tags[]' | while read tag; do \
			DIGEST=$$(curl -s -I -H "Accept: $(MANIFEST_V2)" \
				$(REGISTRY_API)/$$repo/manifests/$$tag 2>/dev/null | \
				grep -i "Docker-Content-Digest:" | awk '{print $$2}' | tr -d '\r\n' | cut -d: -f2 | cut -c1-12); \
			if [ -n "$$DIGEST" ]; then \
				printf "  %-20s %s\n" "$$tag" "$$DIGEST"; \
			else \
				printf "  %-20s %s\n" "$$tag" "<orphaned>"; \
			fi; \
		done; \
	done

.PHONY: registry-tags
registry-tags: ## List tags with short digests (IMAGE=repo/name)
ifndef IMAGE
	$(error IMAGE is not set. Example: make registry-tags IMAGE=myapp)
endif
	@echo "Tags for $(IMAGE):"
	@printf "  %-20s %s\n" "TAG" "SHORT-ID"
	@printf "  %-20s %s\n" "---" "--------"
	@curl -s $(REGISTRY_API)/$(IMAGE)/tags/list | jq -r '.tags[]' | while read tag; do \
		DIGEST=$$(curl -s -I -H "Accept: $(MANIFEST_V2)" \
			$(REGISTRY_API)/$(IMAGE)/manifests/$$tag 2>/dev/null | \
			grep -i "Docker-Content-Digest:" | awk '{print $$2}' | tr -d '\r\n' | cut -d: -f2 | cut -c1-12); \
		if [ -n "$$DIGEST" ]; then \
			printf "  %-20s %s\n" "$$tag" "$$DIGEST"; \
		else \
			printf "  %-20s %s\n" "$$tag" "<orphaned>"; \
		fi; \
	done

# ==============================================================================
# Registry - Verification
# ==============================================================================

.PHONY: registry-verify-manifest
registry-verify-manifest: ## Verify manifest exists (IMAGE=repo/name TAG=tag)
ifndef IMAGE
	$(error IMAGE is not set)
endif
ifndef TAG
	$(error TAG is not set)
endif
	@echo "Verifying $(IMAGE):$(TAG)..."
	@RESPONSE=$$(curl -s -o /dev/null -w "%{http_code}" \
		-H "Accept: $(MANIFEST_V2)" \
		$(REGISTRY_API)/$(IMAGE)/manifests/$(TAG)); \
	if [ "$$RESPONSE" = "200" ]; then \
		echo "✓ Manifest exists (HTTP $$RESPONSE)"; \
	else \
		echo "✗ Manifest NOT found (HTTP $$RESPONSE) - orphaned tag"; \
	fi

.PHONY: registry-check-manifest
registry-check-manifest: ## Check manifest headers (IMAGE=repo/name TAG=tag)
ifndef IMAGE
	$(error IMAGE is not set)
endif
ifndef TAG
	$(error TAG is not set)
endif
	@echo "Checking manifest for $(IMAGE):$(TAG)"
	@echo ""
	@echo "=== Manifest V2 Schema 2 ==="
	@curl -s -I -H "Accept: $(MANIFEST_V2)" \
		$(REGISTRY_API)/$(IMAGE)/manifests/$(TAG)
	@echo ""
	@echo "=== Manifest List ==="
	@curl -s -I -H "Accept: $(MANIFEST_LIST)" \
		$(REGISTRY_API)/$(IMAGE)/manifests/$(TAG)
	@echo ""
	@echo "=== Default Accept ==="
	@curl -s -I $(REGISTRY_API)/$(IMAGE)/manifests/$(TAG)

# ==============================================================================
# Registry - Deletion (API)
# ==============================================================================

.PHONY: registry-remove-tag
registry-remove-tag: ## Remove specific tag via API (IMAGE=repo/name TAG=tag)
ifndef IMAGE
	$(error IMAGE is not set. Example: make registry-remove-tag IMAGE=myapp TAG=v1.0)
endif
ifndef TAG
	$(error TAG is not set. Example: make registry-remove-tag IMAGE=myapp TAG=v1.0)
endif
	@echo "Removing $(IMAGE):$(TAG)..."
	@DIGEST=$$(curl -s -I -H "Accept: $(MANIFEST_V2)" \
		$(REGISTRY_API)/$(IMAGE)/manifests/$(TAG) | \
		grep -i Docker-Content-Digest | awk '{print $$2}' | tr -d '\r'); \
	if [ -z "$$DIGEST" ]; then \
		echo "✗ Could not get digest - tag may be orphaned"; \
		echo "  Use: make registry-cleanup-orphaned IMAGE=$(IMAGE)"; \
		exit 1; \
	fi; \
	echo "Digest: $$DIGEST"; \
	RESPONSE=$$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
		$(REGISTRY_API)/$(IMAGE)/manifests/$$DIGEST); \
	echo "HTTP Response: $$RESPONSE"; \
	echo ""; \
	echo "✓ Tag marked for deletion"; \
	echo "  Run: make registry-gc"

.PHONY: registry-remove-old
registry-remove-old: ## Remove old tags, keep N latest (IMAGE=repo/name KEEP=N)
ifndef IMAGE
	$(error IMAGE is not set. Example: make registry-remove-old IMAGE=myapp KEEP=3)
endif
ifndef KEEP
	$(error KEEP is not set. Example: make registry-remove-old IMAGE=myapp KEEP=3)
endif
	@echo "Removing old tags for $(IMAGE), keeping $(KEEP) latest..."
	@TAGS_TO_DELETE=$$(curl -s $(REGISTRY_API)/$(IMAGE)/tags/list | \
		jq -r '.tags[]' | sort -r | tail -n +$$(($(KEEP) + 1))); \
	if [ -z "$$TAGS_TO_DELETE" ]; then \
		echo "No tags to delete"; \
		exit 0; \
	fi; \
	echo "Tags to delete:"; \
	echo "$$TAGS_TO_DELETE" | sed 's/^/  - /'; \
	echo ""; \
	echo "$$TAGS_TO_DELETE" | while read tag; do \
		echo "Removing: $$tag"; \
		DIGEST=$$(curl -s -I -H "Accept: $(MANIFEST_V2)" \
			$(REGISTRY_API)/$(IMAGE)/manifests/$$tag | \
			grep -i Docker-Content-Digest | awk '{print $$2}' | tr -d '\r'); \
		if [ -n "$$DIGEST" ]; then \
			curl -s -o /dev/null -X DELETE $(REGISTRY_API)/$(IMAGE)/manifests/$$DIGEST; \
		fi; \
	done; \
	echo ""; \
	echo "✓ Old tags marked for deletion"; \
	echo "  Run: make registry-gc"

# ==============================================================================
# Registry - Deletion (Filesystem)
# ==============================================================================

.PHONY: registry-remove-image
registry-remove-image: ## Remove image (API or filesystem) (IMAGE=repo/name)
ifndef IMAGE
	$(error IMAGE is not set. Example: make registry-remove-image IMAGE=myapp)
endif
	@echo "Removing $(IMAGE)..."
	@DELETED=0; \
	TAGS=$$(curl -s $(REGISTRY_API)/$(IMAGE)/tags/list | jq -r '.tags[]'); \
	if [ -z "$$TAGS" ]; then \
		echo "✗ No tags found for $(IMAGE)"; \
		exit 1; \
	fi; \
	echo "Found tags: $$TAGS" | tr '\n' ' '; echo ""; \
	echo ""; \
	for tag in $$TAGS; do \
		echo "Processing: $$tag"; \
		DIGEST=""; \
		for ACCEPT in "$(MANIFEST_V2)" "$(MANIFEST_LIST)" "$(MANIFEST_OCI)"; do \
			DIGEST=$$(curl -s -I -H "Accept: $$ACCEPT" \
				$(REGISTRY_API)/$(IMAGE)/manifests/$$tag 2>/dev/null | \
				grep -i "Docker-Content-Digest:" | awk '{print $$2}' | tr -d '\r\n'); \
			if [ -n "$$DIGEST" ]; then \
				echo "  Deleting via API ($$DIGEST)"; \
				curl -s -o /dev/null -X DELETE $(REGISTRY_API)/$(IMAGE)/manifests/$$DIGEST; \
				DELETED=1; \
				break; \
			fi; \
		done; \
		if [ -z "$$DIGEST" ]; then \
			echo "  ✗ Orphaned tag (no manifest)"; \
		fi; \
	done; \
	echo ""; \
	if [ $$DELETED -eq 0 ]; then \
		echo "No valid manifests found - removing from filesystem..."; \
		CONTAINER_ID=$(call get_container_id); \
		if [ -z "$$CONTAINER_ID" ]; then \
			echo "✗ Registry container not found"; \
			exit 1; \
		fi; \
		docker exec $$CONTAINER_ID rm -rf /var/lib/registry/docker/registry/v2/repositories/$(IMAGE); \
		echo "✓ Repository removed from filesystem"; \
	else \
		echo "✓ Tags deleted via API"; \
	fi; \
	echo "  Run: make registry-gc"

.PHONY: registry-cleanup-orphaned
registry-cleanup-orphaned: ## Remove orphaned tags from filesystem (IMAGE=repo/name)
ifndef IMAGE
	$(error IMAGE is not set. Example: make registry-cleanup-orphaned IMAGE=myapp)
endif
	$(call check_container)
	@echo "Removing orphaned tags for $(IMAGE)..."
	@CONTAINER_ID=$(call get_container_id); \
	echo "Container: $$CONTAINER_ID"; \
	echo ""; \
	echo "Tags in filesystem:"; \
	docker exec $$CONTAINER_ID ls -la /var/lib/registry/docker/registry/v2/repositories/$(IMAGE)/_manifests/tags/ || \
		(echo "✗ Repository not found in filesystem"; exit 1); \
	echo ""; \
	read -p "Delete these tags? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker exec $$CONTAINER_ID rm -rf /var/lib/registry/docker/registry/v2/repositories/$(IMAGE)/_manifests/tags/*; \
		echo "✓ Tags removed from filesystem"; \
	else \
		echo "Cancelled"; \
	fi

.PHONY: registry-cleanup-repo
registry-cleanup-repo: ## Remove entire repository from filesystem (IMAGE=repo/name)
ifndef IMAGE
	$(error IMAGE is not set. Example: make registry-cleanup-repo IMAGE=myapp)
endif
	$(call check_container)
	@echo "WARNING: This will completely remove $(IMAGE) from registry!"
	@CONTAINER_ID=$(call get_container_id); \
	read -p "Are you sure? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker exec $$CONTAINER_ID rm -rf /var/lib/registry/docker/registry/v2/repositories/$(IMAGE); \
		echo "✓ Repository removed from filesystem"; \
		echo "  Run: make registry-gc"; \
	else \
		echo "Cancelled"; \
	fi

# ==============================================================================
# Registry - Garbage Collection
# ==============================================================================

.PHONY: registry-gc
registry-gc: ## Run garbage collection
	$(call check_container)
	@echo "Running garbage collection..."
	@CONTAINER_ID=$(call get_container_id); \
	docker exec $$CONTAINER_ID bin/registry garbage-collect /etc/docker/registry/config.yml
	@echo "✓ Garbage collection completed"

.PHONY: registry-gc-dry
registry-gc-dry: ## Run garbage collection (dry-run mode)
	$(call check_container)
	@echo "Running garbage collection (dry-run)..."
	@CONTAINER_ID=$(call get_container_id); \
	docker exec $$CONTAINER_ID bin/registry garbage-collect --dry-run /etc/docker/registry/config.yml
	@echo "✓ Dry-run completed"
