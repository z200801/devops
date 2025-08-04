# Syncthing Bidirectional Replication Cluster

# Default variables
NODE_IP ?= 
FOLDER_ID ?= 
FOLDER_PATH ?= 
DEVICE_ID ?= 
SYNCTHING_UI_PORT ?= 8384
SYNCTHING_SYNC_PORT ?= 22000
DATA_DIR ?= $(HOME)/projects/replica_data/cluster/data

PROJECT_NAME ?= syncthing
CONTAINER_NAME ?= syncthing-replica
DOCKER_COMPOSE = docker compose

WAIT_SERVICE_DURATION ?= 30
.DEFAULT_GOAL := help

GID ?= 1000
UID ?= 1000

API_KEY ?= $(shell docker exec $(CONTAINER_NAME) grep '<apikey>' /var/syncthing/config/config.xml | sed -E 's/.*<apikey>([^<]+)<\/apikey>.*/\1/')
BASE_URL = http://localhost:$(SYNCTHING_UI_PORT)

.PHONY: help
help: ## Show this help message
	@echo "Syncthing Bidirectional Replication Cluster"
	@echo "Available commands:"
	@echo ""
	@printf "%-25s %s\n" "COMMAND" "DESCRIPTION"
	@printf "%-25s %s\n" "-------" "-----------"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "%-25s %s\n", $$1, $$2}' | \
	sort
	@echo ""
	@echo "Examples:"
	@echo "  make start"
	@echo "  make device-add NODE_IP=192.168.1.105"
	@echo "  make folder-create FOLDER_ID=my-folder"
	@echo "  make folder-share-name FOLDER_ID=my-folder DEVICE_NAME=node-192.168.1.105"
	@echo "  make folder-approve FOLDER_ID=shared-folder"
	@echo "  make device-remove DEVICE_NAME=node-192.168.1.105"

.PHONY: init
init: ## Initialize node
	@mkdir -p $(DATA_DIR); \
	echo "Node initialized"

.PHONY: start
start: ## Start services
	@$(DOCKER_COMPOSE) -p $(PROJECT_NAME) up -d
	@echo "Services started"

.PHONY: stop  
stop: ## Stop services
	@$(DOCKER_COMPOSE) -p $(PROJECT_NAME) down
	@echo "Services stopped"

.PHONY: restart
restart: stop start ## Restart services

.PHONY: status
status: ## Show status
	@if docker ps | grep -q $(CONTAINER_NAME); then \
		echo "Container: Running"; \
	else \
		echo "Container: Not running"; \
	fi

.PHONY: get-api-key-from-config
get-api-key-from-config:
	@docker exec $(CONTAINER_NAME) grep '<apikey>' /var/syncthing/config/config.xml | sed -E 's/.*<apikey>([^<]+)<\/apikey>.*/\1/'

.PHONY: device-id
device-id: require-container ## Get device ID
	@docker exec $(CONTAINER_NAME) cat /var/syncthing/config/config.xml | grep 'device id=' | head -1 | sed 's/.*device id="\([^"]*\)".*/\1/' 2>/dev/null

.PHONY: device-list
device-list: ## Get device list
	@printf "%-20s %s\n" "NAME" "DEVICE ID"
	@printf "%-20s %s\n" "----" "---------"
	@for id in $$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices list); do \
   	name=$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices $$id dump-json | jq -r '.name'); \
   	printf "%-20s %s\n" "$$name" "$$id"; \
	done

.PHONY: device-list-rest
device-list-rest:
	@curl -s -H "X-API-Key: $(API_KEY)" $(BASE_URL)/rest/config \
		| jq -r '.devices[] | "\(.name)\t\(.deviceID)"'

.PHONY: device-add
device-add: ## Add device (NODE_IP required)
	@test -n "$(NODE_IP)" || (echo "NODE_IP required" && exit 1)
	@remote_id=$$(curl -s -I http://$(NODE_IP):$(SYNCTHING_UI_PORT)/ | grep 'X-Syncthing-Id:' | cut -d':' -f2 | tr -d ' \r\n'); \
	docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices add --device-id "$${remote_id}" --name "node-$(NODE_IP)" --addresses "tcp://$(NODE_IP):$(SYNCTHING_SYNC_PORT)"; \
	echo "Device added: $${remote_id}"

.PHONY: device-update-address
device-update-address: require-container ## Update device address (DEVICE_NAME and NODE_IP required)
	@test -n "$(DEVICE_NAME)" || (echo "DEVICE_NAME required" && exit 1)
	@test -n "$(NODE_IP)" || (echo "NODE_IP required" && exit 1)
	@device_id=""; \
	for id in $$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices list); do \
		name=$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices $$id dump-json | jq -r '.name'); \
		if [ "$$name" = "$(DEVICE_NAME)" ]; then \
			device_id=$$id; \
			break; \
		fi; \
	done; \
	if [ -z "$$device_id" ]; then \
		echo "Error: Device with name '$(DEVICE_NAME)' not found"; \
		exit 1; \
	fi; \
	echo "Updating address for device '$(DEVICE_NAME)'..."; \
	echo "Current addresses:"; \
	docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices "$$device_id" addresses list; \
	echo "Clearing old addresses and adding new one..."; \
	for addr_idx in $$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices "$$device_id" addresses list); do \
		docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices "$$device_id" addresses "$$addr_idx" delete; \
	done; \
	docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices "$$device_id" addresses add "tcp://$(NODE_IP):$(SYNCTHING_SYNC_PORT)"; \
	echo "Address updated for device '$(DEVICE_NAME)' to tcp://$(NODE_IP):$(SYNCTHING_SYNC_PORT)"

.PHONY: device-remove
device-remove: require-container ## Remove device (DEVICE_ID or DEVICE_NAME required)
	@if [ -n "$(DEVICE_ID)" ]; then \
   	echo "Removing device with ID: $(DEVICE_ID)"; \
   	if docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices "$(DEVICE_ID)" delete; then \
   		echo "Success: Device $(DEVICE_ID) removed"; \
   	else \
   		echo "Error: Failed to remove device $(DEVICE_ID)"; \
   		exit 1; \
   	fi; \
   elif [ -n "$(DEVICE_NAME)" ]; then \
   	echo "Looking for device with name '$(DEVICE_NAME)'..."; \
   	device_id=""; \
   	for id in $$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices list); do \
   		name=$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices $$id dump-json | jq -r '.name'); \
   		if [ "$$name" = "$(DEVICE_NAME)" ]; then \
   			device_id=$$id; \
   			break; \
   		fi; \
   	done; \
   	if [ -z "$$device_id" ]; then \
   		echo "Error: Device with name '$(DEVICE_NAME)' not found"; \
   		echo "Available devices:"; \
   		for id in $$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices list); do \
   			name=$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices $$id dump-json | jq -r '.name'); \
   			printf "  %-20s %s\n" "$$name" "$$id"; \
   		done; \
   		exit 1; \
   	fi; \
   	echo "Found device '$(DEVICE_NAME)' with ID: $$device_id"; \
   	if docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices "$$device_id" delete; then \
   		echo "Success: Device '$(DEVICE_NAME)' ($$device_id) removed"; \
   	else \
   		echo "Error: Failed to remove device '$(DEVICE_NAME)'"; \
   		exit 1; \
   	fi; \
   else \
   	echo "Error: Either DEVICE_ID or DEVICE_NAME required"; \
   	echo "Usage:"; \
   	echo "  make device-remove DEVICE_ID=<device_id>"; \
   	echo "  make device-remove DEVICE_NAME=<device_name>"; \
   	exit 1; \
	fi

.PHONY: folder-create
folder-create: ## Create folder (FOLDER_ID required)
	@test -n "$(FOLDER_ID)" || (echo "FOLDER_ID required" && exit 1)
	@echo "Creating folder $(FOLDER_ID)..."
	@docker exec $(CONTAINER_NAME) mkdir -p "/var/syncthing/$(FOLDER_ID)"
	@docker exec $(CONTAINER_NAME) chown 1000:1000 "/var/syncthing/$(FOLDER_ID)"
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config folders add --id "$(FOLDER_ID)" --path "/var/syncthing/$(FOLDER_ID)" --label "$(FOLDER_ID)"
	@echo "Folder $(FOLDER_ID) created"

.PHONY: folder-remove
folder-remove: require-container ## Remove folder (FOLDER_ID required)
	@test -n "$(FOLDER_ID)" || (echo "FOLDER_ID required" && exit 1)
	@echo "Removing folder $(FOLDER_ID)..."
	@if docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config folders list | grep -q "^$(FOLDER_ID)$$"; then \
		docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config folders $(FOLDER_ID) delete; \
		echo "Folder $(FOLDER_ID) removed from configuration"; \
		echo "Note: Local files in /var/syncthing/$(FOLDER_ID) are preserved"; \
	else \
		echo "Error: Folder $(FOLDER_ID) not found"; \
		echo "Available folders:"; \
		docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config folders list | sed 's/^/  /'; \
		exit 1; \
	fi

.PHONY: folder-remove-with-data
folder-remove-with-data: require-container ## Remove folder and delete its data (FOLDER_ID required)
	@test -n "$(FOLDER_ID)" || (echo "FOLDER_ID required" && exit 1)
	@echo "WARNING: This will remove folder $(FOLDER_ID) and DELETE all its data!"
	@echo "Continue? [y/N]" && read -r confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || (echo "Cancelled" && exit 1)
	@echo "Removing folder $(FOLDER_ID) from configuration..."
	@if docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config folders list | grep -q "^$(FOLDER_ID)$$"; then \
		docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config folders $(FOLDER_ID) delete; \
		echo "Folder removed from configuration"; \
		echo "Deleting folder data..."; \
		docker exec syncthing-replica rm -rf "/var/syncthing/$(FOLDER_ID)"; \
		echo "✓ Folder $(FOLDER_ID) and all its data removed"; \
	else \
		echo "Error: Folder $(FOLDER_ID) not found"; \
		exit 1; \
	fi

.PHONY: folder-pause
folder-pause: require-container ## Pause folder synchronization (FOLDER_ID required)
	@test -n "$(FOLDER_ID)" || (echo "FOLDER_ID required" && exit 1)
	@echo "Pausing folder $(FOLDER_ID)..."
	@docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config folders $(FOLDER_ID) paused set true
	@echo "Folder $(FOLDER_ID) paused"

.PHONY: folder-resume
folder-resume: require-container ## Resume folder synchronization (FOLDER_ID required)
	@test -n "$(FOLDER_ID)" || (echo "FOLDER_ID required" && exit 1)
	@echo "Resuming folder $(FOLDER_ID)..."
	@docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config folders $(FOLDER_ID) paused set false
	@echo "Folder $(FOLDER_ID) resumed"


.PHONY: folder-share
folder-share: ## Share folder (FOLDER_ID and DEVICE_ID required)
	@test -n "$(FOLDER_ID)" || (echo "FOLDER_ID required" && exit 1)
	@test -n "$(DEVICE_ID)" || (echo "DEVICE_ID required" && exit 1)
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config folders devices add --folder-id "$(FOLDER_ID)" --device-id "$(DEVICE_ID)"
	@echo "Folder $(FOLDER_ID) shared with $(DEVICE_ID)"

.PHONY: folder-list
folder-list: ## List folders
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config folders list

# Таргет для діагностики папок
.PHONY: folder-status
folder-status: require-container ## Show folder synchronization status
	@api_key=$$(docker exec syncthing-replica grep '<apikey>' /var/syncthing/config/config.xml | sed -E 's/.*<apikey>([^<]+)<\/apikey>.*/\1/'); \
	if [ -n "$(FOLDER_ID)" ]; then \
		echo "Status for folder: $(FOLDER_ID)"; \
		curl -s -H "X-API-Key: $$api_key" http://localhost:8384/rest/db/status?folder=$(FOLDER_ID) | jq; \
	else \
		echo "All folders status:"; \
		for folder in $$(docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config folders list); do \
			echo "=== Folder: $$folder ==="; \
			curl -s -H "X-API-Key: $$api_key" http://localhost:8384/rest/db/status?folder=$$folder | jq -r '. | "State: \(.state), Files: \(.globalFiles), Errors: \(.errors // 0)"'; \
		done; \
	fi

.PHONY: logs
logs: ## Show logs
	@$(DOCKER_COMPOSE) -p $(PROJECT_NAME) logs -f syncthing

.PHONY: clean
clean: ## Clean up
	@$(DOCKER_COMPOSE) -p $(PROJECT_NAME) down -v

.PHONY: exec
exec: ## Open shell inside the container
	@docker exec -it $(CONTAINER_NAME) sh

.PHONY: require-container
require-container:
	@$(DOCKER_COMPOSE) -p $(PROJECT_NAME) ps | grep -q $(CONTAINER_NAME) || (echo "Error: $(CONTAINER_NAME) not running" && exit 1)

.PHONY: folder-share-name
folder-share-name: require-container ## Share folder (FOLDER_ID and DEVICE_NAME required)
	@test -n "$(FOLDER_ID)" || (echo "FOLDER_ID required" && exit 1)
	@test -n "$(DEVICE_NAME)" || (echo "DEVICE_NAME required" && exit 1)
	@echo "Looking for device with name '$(DEVICE_NAME)'..."
	@device_id=""; \
	for id in $$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices list); do \
		name=$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices $$id dump-json | jq -r '.name'); \
		if [ "$$name" = "$(DEVICE_NAME)" ]; then \
			device_id=$$id; \
			break; \
		fi; \
	done; \
	if [ -z "$$device_id" ]; then \
		echo "Error: Device with name '$(DEVICE_NAME)' not found"; \
		echo "Available devices:"; \
		for id in $$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices list); do \
			name=$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices $$id dump-json | jq -r '.name'); \
			echo "  $$name ($$id)"; \
		done; \
		exit 1; \
	fi; \
	echo "Found device '$(DEVICE_NAME)' with ID: $$device_id"; \
	if docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config folders "$(FOLDER_ID)" devices add --device-id "$$device_id"; then \
		echo "Success: Folder '$(FOLDER_ID)' shared with device '$(DEVICE_NAME)' (ID: $$device_id)"; \
	else \
		echo "Error: Failed to share folder '$(FOLDER_ID)' with device '$(DEVICE_NAME)'"; \
		exit 1; \
	fi

.PHONY: folder-approve
folder-approve: require-container ## Approve folder for add
	@api_key=$$(docker exec $(CONTAINER_NAME) cat /var/syncthing/config/config.xml | grep '<apikey>' | sed -E 's/.*<apikey>([^<]+)<\/apikey>.*/\1/'); \
   if [ -z "$(FOLDER_ID)" ]; then \
   	echo "Pending folders:"; \
   	pending_folders=$$(curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/cluster/pending/folders | jq -r 'keys[]'); \
   	if [ -z "$$pending_folders" ]; then \
   		echo "  No pending folders found"; \
   	else \
   		echo "$$pending_folders" | sed 's/^/  /'; \
   		echo ""; \
   		echo "Usage: make folder-approve FOLDER_ID=<folder_id>"; \
   	fi; \
   else \
   	echo "Checking for pending folder '$(FOLDER_ID)'..."; \
   	pending_data=$$(curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/cluster/pending/folders | jq -r '.["$(FOLDER_ID)"] // empty'); \
   	if [ -z "$$pending_data" ]; then \
   		echo "Error: No pending folder '$(FOLDER_ID)' found"; \
   		echo "Available pending folders:"; \
   		curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/cluster/pending/folders | jq -r 'keys[]' | sed 's/^/  /'; \
   		exit 1; \
   	fi; \
   	offering_device=$$(curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/cluster/pending/folders | jq -r '.["$(FOLDER_ID)"].offeredBy | keys[0]'); \
   	existing=$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config folders list | grep "^$(FOLDER_ID)$$" || true); \
   	if [ -n "$$existing" ]; then \
   		echo "Folder '$(FOLDER_ID)' already exists, adding sharing device..."; \
   		docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config folders "$(FOLDER_ID)" devices add --device-id "$$offering_device"; \
   		echo "Success: Folder '$(FOLDER_ID)' approved with device $$offering_device"; \
   	else \
   		echo "Found pending folder '$(FOLDER_ID)', approving..."; \
   		docker exec $(CONTAINER_NAME) mkdir -p "/var/syncthing/$(FOLDER_ID)"; \
   		docker exec $(CONTAINER_NAME) chown $(UID):$(GID) "/var/syncthing/$(FOLDER_ID)"; \
   		if docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config folders add --id "$(FOLDER_ID)" --path "/var/syncthing/$(FOLDER_ID)" --label "$(FOLDER_ID)"; then \
   			docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config folders "$(FOLDER_ID)" devices add --device-id "$$offering_device"; \
   			echo "Success: Folder '$(FOLDER_ID)' approved and configured with device $$offering_device"; \
   		else \
   			echo "Error: Failed to approve folder '$(FOLDER_ID)'"; \
   			exit 1; \
   		fi; \
   	fi; \
   fi

.PHONY: device-status
device-status: require-container ## Show device status (DEVICE_ID or DEVICE_NAME optional)
	@api_key=$$(docker exec $(CONTAINER_NAME) cat /var/syncthing/config/config.xml | grep '<apikey>' | sed -E 's/.*<apikey>([^<]+)<\/apikey>.*/\1/'); \
if [ -n "$(DEVICE_ID)" ]; then \
	echo "Status for device $(DEVICE_ID):"; \
	curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/stats/device | jq '.["$(DEVICE_ID)"] // "Device not found"'; \
elif [ -n "$(DEVICE_NAME)" ]; then \
	echo "Looking for device with name '$(DEVICE_NAME)'..."; \
	device_id=""; \
	for id in $$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices list); do \
		name=$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices $$id dump-json | jq -r '.name'); \
		if [ "$$name" = "$(DEVICE_NAME)" ]; then \
			device_id=$$id; \
			break; \
		fi; \
	done; \
	if [ -z "$$device_id" ]; then \
		echo "Error: Device with name '$(DEVICE_NAME)' not found"; \
		exit 1; \
	fi; \
	echo "Status for device '$(DEVICE_NAME)' ($$device_id):"; \
	curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/stats/device | jq '.["'$$device_id'"] // "Device not found"'; \
else \
	echo "Device Status Overview:"; \
	printf "%-20s %-15s %-15s %s\n" "NAME" "STATUS" "LAST_SEEN" "CONNECTION"; \
	printf "%-20s %-15s %-15s %s\n" "----" "------" "---------" "----------"; \
	connections=$$(curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/system/connections); \
	for id in $$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices list); do \
		name=$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices $$id dump-json | jq -r '.name'); \
		status=$$(echo "$$connections" | jq -r '.connections["'$$id'"].connected // false'); \
		if [ "$$status" = "true" ]; then \
			connection_type=$$(echo "$$connections" | jq -r '.connections["'$$id'"].type // "unknown"'); \
			printf "%-20s %-15s %-15s %s\n" "$$name" "Connected" "Now" "$$connection_type"; \
		else \
			last_seen=$$(echo "$$connections" | jq -r '.connections["'$$id'"].at // "never"'); \
			if [ "$$last_seen" != "never" ] && [ "$$last_seen" != "null" ]; then \
				last_seen=$$(echo "$$last_seen" | cut -d'T' -f1); \
			fi; \
			printf "%-20s %-15s %-15s %s\n" "$$name" "Disconnected" "$$last_seen" "-"; \
		fi; \
	done; \
	fi

.PHONY: global-discovery-disable
global-discovery-disable: require-container ## Disable global discovery
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options global-ann-enabled set false
	@echo "Global discovery disabled"

.PHONY: global-discovery-enable
global-discovery-enable: require-container ## Enable global discovery
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options global-ann-enabled set true
	@echo "Global discovery enabled"

.PHONY: relay-enable
relay-enable: require-container ## Enable relay servers
	@echo "Enabling relay servers..."
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options relays-enabled set true
	@echo "Relay servers enabled"

.PHONY: relay-disable
relay-disable: require-container ## Disable relay servers
	@echo "Disabling relay servers..."
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options relays-enabled set false
	@echo "Relay servers disabled"

.PHONY: network-options
network-options: require-container ## Show current network options
	@echo "Current network settings:"
	@printf "%-20s %s\n" "Global Discovery:" "$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options global-ann-enabled get)"
	@printf "%-20s %s\n" "Relay Servers:" "$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options relays-enabled get)"
	@printf "%-20s %s\n" "Local Discovery:" "$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options local-ann-enabled get)"
	@printf "%-20s %s\n" "NAT Enabled:" "$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options natenabled get)"
	@printf "%-20s %s\n" "Start Browser:" "$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options start-browser get)"

.PHONY: nat-enable
nat-enable: require-container ## Enable NAT traversal
	@echo "Enabling NAT traversal..."
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options natenabled set true
	@echo "NAT traversal enabled"

.PHONY: nat-disable
nat-disable: require-container ## Disable NAT traversal
	@echo "Disabling NAT traversal..."
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options natenabled set false
	@echo "NAT traversal disabled"

.PHONY: config-backup
config-backup: require-container ## Backup Syncthing configuration
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	backup_file="syncthing_config_backup_$$timestamp.tar.gz"; \
	echo "Creating backup: $$backup_file"; \
	docker exec $(CONTAINER_NAME) tar -czf "/var/syncthing/$$backup_file" -C /var/syncthing config; \
	docker cp $(CONTAINER_NAME):"/var/syncthing/$$backup_file" "./$$backup_file"; \
	docker exec $(CONTAINER_NAME) rm "/var/syncthing/$$backup_file"; \
	echo "Configuration backed up to: $$backup_file"

.PHONY: config-restore
config-restore: ## Restore configuration from backup (BACKUP_FILE required)
	@test -n "$(BACKUP_FILE)" || (echo "BACKUP_FILE required. Usage: make config-restore BACKUP_FILE=backup.tar.gz" && exit 1)
	@test -f "$(BACKUP_FILE)" || (echo "Error: Backup file '$(BACKUP_FILE)' not found" && exit 1)
	@echo "WARNING: This will overwrite current configuration!"
	@echo "Backup file: $(BACKUP_FILE)"
	@echo "Continue? [y/N]" && read -r confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || (echo "Cancelled" && exit 1)
	@echo "Stopping Syncthing..."
	@$(MAKE) stop
	@echo "Backing up current config as safety measure..."
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	safety_backup="syncthing_config_safety_$$timestamp.tar.gz"; \
	docker run --rm -v $(DATA_DIR):/data alpine tar -czf "/data/$$safety_backup" -C /data config 2>/dev/null || echo "No existing config to backup"; \
	echo "Safety backup created: $$safety_backup"
	@echo "Clearing current configuration..."
	@docker run --rm -v $(DATA_DIR):/data alpine rm -rf /data/config/* 2>/dev/null || true
	@echo "Restoring from backup..."
	@docker run --rm -v $(DATA_DIR):/data -v "$$(pwd):/backup" alpine tar -xzf "/backup/$(BACKUP_FILE)" -C /data
	@echo "Starting Syncthing..."
	@$(MAKE) start
	@echo "Configuration restored successfully from $(BACKUP_FILE)"
	@echo "Waiting for service to start..."
	@sleep 5
	@$(MAKE) status

.PHONY: config-list-backups
config-list-backups: ## List available configuration backups
	@echo "Available configuration backups:"
	@ls -la syncthing_config_backup_*.tar.gz 2>/dev/null | awk '{print $$9, "(" $$5 " bytes, " $$6 " " $$7 " " $$8 ")"}' || echo "No backups found"

.PHONY: config-restore-emergency
config-restore-emergency: ## Emergency restore without confirmation (BACKUP_FILE required)
	@test -n "$(BACKUP_FILE)" || (echo "BACKUP_FILE required" && exit 1)
	@test -f "$(BACKUP_FILE)" || (echo "Error: Backup file '$(BACKUP_FILE)' not found" && exit 1)
	@echo "EMERGENCY RESTORE: $(BACKUP_FILE)"
	@$(MAKE) stop
	@docker run --rm -v $(DATA_DIR):/data alpine rm -rf /data/config/*
	@docker run --rm -v $(DATA_DIR):/data -v "$$(pwd):/backup" alpine tar -xzf "/backup/$(BACKUP_FILE)" -C /data
	@$(MAKE) start
	@echo "Emergency restore completed"

.PHONY: security-harden
security-harden: require-container ## Apply security hardening
	@echo "Applying security hardening..."
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options global-ann-enabled set false
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options relays-enabled set false
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options local-ann-enabled set false
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options start-browser set false
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options uraccepted set -1
	@docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options auto-upgrade-intervalh set 0
	@echo "Security hardening applied"

.PHONY: security-status
security-status: require-container ## Show security status
	@echo "Security Status:"
	@printf "%-25s %s\n" "Global Discovery:" "$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options global-ann-enabled get)"
	@printf "%-25s %s\n" "Relay Servers:" "$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options relays-enabled get)"
	@printf "%-25s %s\n" "Local Announcements:" "$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options local-ann-enabled get)"
	@printf "%-25s %s\n" "Usage Reporting:" "$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options uraccepted get)"
	@printf "%-25s %s\n" "Auto Updates:" "$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options auto-upgrade-intervalh get)"
	@printf "%-25s %s\n" "Auto Start Browser:" "$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config options start-browser get)"

.PHONY: security-check
security-check: require-container ## Check for security issues
	@echo "Security Check Report:"
	@echo "====================="
	@echo "1. Checking exposed ports..."
	@ss -tulnp | grep -E "(8384|22000|21027)" || echo "No exposed ports found"
	@echo ""
	@echo "2. Checking for unknown devices..."
	@$(MAKE) device-list
	@echo ""
	@echo "3. Checking API key exposure..."
	@api_key=$$($(MAKE) get-api-key-from-config); \
	if [ $${#api_key} -lt 32 ]; then \
		echo "WARNING: API key seems weak"; \
	else \
		echo "API key length: OK"; \
	fi

.PHONY: rotate-api-key
rotate-api-key: require-container ## Rotate API key
	@echo "Rotating API key..."
	@new_key=$$(openssl rand -hex 16); \
	docker exec $(CONTAINER_NAME) sed -i "s/<apikey>.*<\/apikey>/<apikey>$$new_key<\/apikey>/" /var/syncthing/config/config.xml; \
	echo "New API key generated. Restart required."; \
	echo "New key: $$new_key"

.PHONY: audit-log
audit-log: require-container ## Show audit information
	@echo "Recent Syncthing activity:"
	@docker logs $(CONTAINER_NAME) --since 24h | grep -E "(connect|disconnect|error|warn)" | tail -20

.PHONY: emergency-shutdown
emergency-shutdown: ## Emergency shutdown and isolation
	@echo "EMERGENCY: Stopping all services and isolating..."
	@docker stop $(CONTAINER_NAME)
	@docker network disconnect syncthing $(CONTAINER_NAME) 2>/dev/null || true
	@echo "Container stopped and isolated"

.PHONY: emergency-restore
emergency-restore: ## Restore from backup after incident
	@test -n "$(BACKUP_FILE)" || (echo "BACKUP_FILE required" && exit 1)
	@echo "Restoring from backup: $(BACKUP_FILE)"
	@$(MAKE) stop
	@docker exec $(CONTAINER_NAME) rm -rf /var/syncthing/config/*
	@docker cp "$(BACKUP_FILE)" $(CONTAINER_NAME):/tmp/
	@docker exec $(CONTAINER_NAME) tar -xzf "/tmp/$(BACKUP_FILE)" -C /var/syncthing/
	@$(MAKE) start

.PHONY: monitor-connections
monitor-connections: require-container ## Monitor active connections
	@echo "Active network connections:"
	@docker exec $(CONTAINER_NAME) netstat -an | grep -E "(8384|22000|21027)" 2>/dev/null || echo "No connections found"
	@echo ""
	@echo "Syncthing Device Connections:"
	@echo "============================="
	@api_key=$$(docker exec $(CONTAINER_NAME) grep '<apikey>' /var/syncthing/config/config.xml | sed -E 's/.*<apikey>([^<]+)<\/apikey>.*/\1/'); \
	if [ -z "$$api_key" ]; then \
		echo "Error: Could not retrieve API key"; \
		exit 1; \
	fi; \
	response=$$(curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/system/connections); \
	if echo "$$response" | grep -q "Forbidden"; then \
		echo "Error: API key invalid or expired"; \
		echo "Try: make rotate-api-key"; \
		exit 1; \
	fi; \
	printf "%-20s %-12s %-15s %-10s %s\n" "DEVICE NAME" "STATUS" "TYPE" "CLIENT" "ADDRESS"; \
	printf "%-20s %-12s %-15s %-10s %s\n" "-----------" "------" "----" "------" "-------"; \
	for device_id in $$(echo "$$response" | jq -r '.connections | keys[]'); do \
		device_name=$$(docker exec $(CONTAINER_NAME) syncthing cli --home=/var/syncthing/config config devices "$$device_id" dump-json 2>/dev/null | jq -r '.name // "Unknown"'); \
		connected=$$(echo "$$response" | jq -r ".connections[\"$$device_id\"].connected"); \
		if [ "$$connected" = "true" ]; then \
			conn_type=$$(echo "$$response" | jq -r ".connections[\"$$device_id\"].type // \"unknown\""); \
			client_version=$$(echo "$$response" | jq -r ".connections[\"$$device_id\"].clientVersion // \"unknown\""); \
			address=$$(echo "$$response" | jq -r ".connections[\"$$device_id\"].address // \"unknown\""); \
			printf "%-20s %-12s %-15s %-10s %s\n" "$$device_name" "Connected" "$$conn_type" "$$client_version" "$$address"; \
		else \
			last_seen=$$(echo "$$response" | jq -r ".connections[\"$$device_id\"].at // \"never\""); \
			if [ "$$last_seen" != "never" ] && [ "$$last_seen" != "null" ]; then \
				last_seen=$$(echo "$$last_seen" | cut -d'T' -f1); \
			fi; \
			printf "%-20s %-12s %-15s %-10s %s\n" "$$device_name" "Disconnected" "-" "-" "Last: $$last_seen"; \
		fi; \
	done

.PHONY: usage-reporting-disable
usage-reporting-disable: require-container ## Disable anonymous usage reporting
	@echo "Disabling anonymous usage reporting..."
	@docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config options uraccepted set -- -1
	@echo "Usage reporting disabled"

.PHONY: usage-reporting-enable
usage-reporting-enable: require-container ## Enable anonymous usage reporting
	@echo "Enabling anonymous usage reporting..."
	@docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config options uraccepted set 3
	@echo "Usage reporting enabled"

.PHONY: usage-reporting-status
usage-reporting-status: require-container ## Show usage reporting status
	@echo "Usage Reporting Status:"
	@status=$$(docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config options uraccepted get); \
	case "$$status" in \
		-1) echo "  Status: Disabled (permanently declined)" ;; \
		0) echo "  Status: Not decided yet" ;; \
		1|2|3) echo "  Status: Enabled (accepted version $$status)" ;; \
		*) echo "  Status: Unknown ($$status)" ;; \
	esac; \
	echo "  URL: $$(docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config options ururl get)"; \
	echo "  Unique ID: $$(docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config options urunique-id get)"

.PHONY: telemetry-disable-all
telemetry-disable-all: require-container ## Disable all telemetry and external connections
	@echo "Disabling all telemetry and external connections..."
	@docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config options uraccepted set -- -1
	@docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config options auto-upgrade-intervalh set 0
	@docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config options crenabled set false
	@echo "All telemetry disabled:"
	@echo "  ✓ Usage reporting: disabled"
	@echo "  ✓ Auto updates: disabled"  
	@echo "  ✓ Crash reporting: disabled"

.PHONY: gui-set-password
gui-set-password: require-container ## Set GUI password via API (GUI_USER and GUI_PASSWORD required)
	@test -n "$(GUI_USER)" || (echo "GUI_USER required. Usage: make gui-set-password GUI_USER=admin GUI_PASSWORD=secret" && exit 1)
	@test -n "$(GUI_PASSWORD)" || (echo "GUI_PASSWORD required. Usage: make gui-set-password GUI_USER=admin GUI_PASSWORD=secret" && exit 1)
	@echo "Setting GUI authentication via API..."
	@api_key=$$(docker exec syncthing-replica grep '<apikey>' /var/syncthing/config/config.xml | sed -E 's/.*<apikey>([^<]+)<\/apikey>.*/\1/'); \
	if [ -z "$$api_key" ]; then \
		echo "Error: Could not retrieve API key"; \
		exit 1; \
	fi; \
	echo "Getting current configuration..."; \
	config=$$(curl -s -H "X-API-Key: $$api_key" -H "X-CSRF-Token: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/config); \
	if [ -z "$$config" ]; then \
		echo "Error: Could not retrieve configuration"; \
		exit 1; \
	fi; \
	echo "Updating GUI configuration..."; \
	updated_config=$$(echo "$$config" | jq '.gui.user = "$(GUI_USER)" | .gui.password = "$(GUI_PASSWORD)"'); \
	response=$$(curl -s -X PUT -H "X-API-Key: $$api_key" -H "X-CSRF-Token: $$api_key" -H "Content-Type: application/json" \
		-d "$$updated_config" http://localhost:$(SYNCTHING_UI_PORT)/rest/config); \
	if echo "$$response" | grep -q "error"; then \
		echo "Error setting password: $$response"; \
		exit 1; \
	fi; \
	echo "GUI authentication configured successfully"; \
	echo "Username: $(GUI_USER)"; \
	echo "Password: $(GUI_PASSWORD)"; \
	echo "Note: Changes applied immediately, no restart needed"

.PHONY: gui-test-login
gui-test-login: require-container ## Test GUI login (GUI_USER and GUI_PASSWORD required)
	@test -n "$(GUI_USER)" || (echo "GUI_USER required" && exit 1)
	@test -n "$(GUI_PASSWORD)" || (echo "GUI_PASSWORD required" && exit 1)
	@echo "Testing GUI login..."
	@api_key=$$(docker exec syncthing-replica grep '<apikey>' /var/syncthing/config/config.xml | sed -E 's/.*<apikey>([^<]+)<\/apikey>.*/\1/'); \
	response=$$(curl -s -u "$(GUI_USER):$(GUI_PASSWORD)" -H "X-API-Key: $$api_key" -H "X-CSRF-Token: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/system/ping 2>/dev/null); \
	if echo "$$response" | grep -q "pong"; then \
		echo "✓ Login successful"; \
	else \
		echo "✗ Login failed"; \
		echo "Response: $$response"; \
		exit 1; \
	fi

.PHONY: gui-show-config
gui-show-config: require-container ## Show current GUI configuration
	@echo "Current GUI Configuration:"
	@printf "%-15s %s\n" "User:" "$$(docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config gui user get)"
	@password=$$(docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config gui password get); \
	if [ -n "$$password" ]; then \
		password_preview=$$(echo "$$password" | cut -c1-16); \
		echo "Password:       Set (hash: $$password_preview...)"; \
	else \
		echo "Password:       Not set"; \
	fi
	@api_key=$$(docker exec syncthing-replica grep '<apikey>' /var/syncthing/config/config.xml | sed -E 's/.*<apikey>([^<]+)<\/apikey>.*/\1/'); \
	gui_config=$$(curl -s -u "admin:admin" -H "X-API-Key: $$api_key" -H "X-CSRF-Token: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/config | jq '.gui'); \
	address=$$(echo "$$gui_config" | jq -r '.address // "0.0.0.0:8384"'); \
	tls=$$(echo "$$gui_config" | jq -r '.tls // false'); \
	printf "%-15s %s\n" "Address:" "$$address"; \
	printf "%-15s %s\n" "TLS:" "$$tls"

.PHONY: gui-remove-password
gui-remove-password: require-container ## Remove GUI password authentication
	@echo "Removing GUI authentication..."
	@docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config gui user set ""
	@docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config gui password set ""
	@echo "GUI authentication removed"
	@echo "Note: Restart required for changes to take effect"

.PHONY: gui-secure-setup
gui-secure-setup: require-container ## Complete GUI security setup (GUI_USER and GUI_PASSWORD required)
	@test -n "$(GUI_USER)" || (echo "GUI_USER required" && exit 1)
	@test -n "$(GUI_PASSWORD)" || (echo "GUI_PASSWORD required" && exit 1)
	@echo "Setting up secure GUI configuration..."
	@$(MAKE) gui-set-password GUI_USER=$(GUI_USER) GUI_PASSWORD=$(GUI_PASSWORD)
	@$(MAKE) gui-enable-tls
	@echo "Restarting to apply changes..."
	@$(MAKE) restart
	@echo "Secure GUI setup completed!"
	@echo "Access GUI at: https://localhost:8384"
	@echo "Username: $(GUI_USER)"
	@echo "Password: [as provided]"

.PHONY: security-monitor
security-monitor: require-container ## Monitor security events  
	@echo "=== Security Events Monitoring ==="
	@echo "Recent security events (last 2 hours):"
	@docker logs syncthing-replica --since 2h | grep -i -E "(wrong credentials|unauthorized|forbidden|failed|error|csrf|api)" | \
		while read line; do echo "$$(date '+%H:%M:%S') $$line"; done | tail -20 || echo "No security events found"
	@echo ""
	@echo "Failed API access attempts:"
	@docker logs syncthing-replica --since 24h | grep "Wrong credentials" | \
		sed -E 's/.*from ([0-9.]+).*/\1/' | sort | uniq -c | sort -nr || echo "No failed attempts"
	@echo ""
	@echo "Most active IPs (last 24h):"
	@docker logs syncthing-replica --since 24h | grep -E "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | \
		sed -E 's/.*from ([0-9.]+).*/\1/' | sort | uniq -c | sort -nr | head -5 || echo "No IP activity found"
	@echo ""
	@echo "Current banned IPs:"
	@$(MAKE) security-ban-ip-list 2>/dev/null

.PHONY: security-ban-ip-list
security-ban-ip-list: ## List all banned IPs with reasons
	@echo "Banned IPs (via iptables):"
	@printf "%-18s %-20s %s\n" "IP ADDRESS" "DATE" "REASON"
	@printf "%-18s %-20s %s\n" "----------" "----" "------"
	@sudo iptables -L INPUT -n --line-numbers 2>/dev/null | grep "DROP" | \
		while IFS= read -r line; do \
			if echo "$$line" | grep -q "SYNCTHING-BAN"; then \
				ip=$$(echo "$$line" | awk '{print $$5}'); \
				comment=$$(echo "$$line" | grep -o '/\* .* \*/' | sed 's|/\* \(.*\) \*/|\1|'); \
				if [ -n "$$comment" ]; then \
					reason=$$(echo "$$comment" | sed 's/SYNCTHING-BAN: //'); \
					printf "%-18s %s\n" "$$ip" "$$reason"; \
				fi; \
			fi; \
		done 2>/dev/null || echo "No banned IPs found"
	@echo ""
	@if [ -f /tmp/syncthing_banned_ips.log ]; then \
		echo "Ban/Unban History (last 10 entries):"; \
		tail -10 /tmp/syncthing_banned_ips.log 2>/dev/null; \
	fi

.PHONY: security-events-live
security-events-live: require-container ## Live monitoring of security events (Ctrl+C to stop)
	@echo "Live security monitoring started... (Press Ctrl+C to stop)"
	@docker logs syncthing-replica -f 2>/dev/null | grep --line-buffered -i -E "(wrong credentials|unauthorized|forbidden|failed|error)" | \
		while IFS= read -r line; do \
			timestamp=$$(date '+%Y-%m-%d %H:%M:%S'); \
			echo "[$$timestamp] $$line"; \
		done

.PHONY: security-summary
security-summary: require-container ## Quick security summary
	@echo "=== Quick Security Summary ==="
	@printf "%-25s " "Container Status:"
	@if docker ps | grep -q syncthing-replica; then echo "✓ Running"; else echo "✗ Stopped"; fi
	@printf "%-25s " "GUI Authentication:"
	@if $(MAKE) gui-show-config 2>/dev/null | grep -q "User:.*[a-zA-Z]"; then echo "✓ Enabled"; else echo "✗ Disabled"; fi
	@printf "%-25s " "Failed logins (24h):"
	@count=$$(docker logs syncthing-replica --since 24h 2>/dev/null | grep -c "Wrong credentials" || echo "0"); echo "$$count attempts"
	@printf "%-25s " "Banned IPs:"
	@banned=$$(sudo iptables -L INPUT -n 2>/dev/null | grep -c "SYNCTHING-BAN" || echo "0"); echo "$$banned IPs"
	@printf "%-25s " "Global Discovery:"
	@if $(MAKE) network-options 2>/dev/null | grep -q "Global Discovery:.*false"; then echo "✓ Disabled"; else echo "⚠ Enabled"; fi

.PHONY: security-ban-ip
security-ban-ip: ## Ban IP address with label (IP_ADDRESS required, REASON optional)
	@test -n "$(IP_ADDRESS)" || (echo "IP_ADDRESS required. Usage: make security-ban-ip IP_ADDRESS=192.168.1.65 REASON='Failed login attempts'" && exit 1)
	@reason="$${REASON:-Syncthing security violation}"; \
	timestamp=$$(date '+%Y-%m-%d %H:%M:%S'); \
	comment="SYNCTHING-BAN: $$reason - $$timestamp"; \
	echo "Banning IP: $(IP_ADDRESS)"; \
	echo "Reason: $$reason"; \
	if sudo iptables -C INPUT -s $(IP_ADDRESS) -j DROP 2>/dev/null; then \
		echo "IP $(IP_ADDRESS) is already banned"; \
	else \
		sudo iptables -A INPUT -s $(IP_ADDRESS) -j DROP -m comment --comment "$$comment"; \
		echo "✓ IP $(IP_ADDRESS) banned successfully"; \
	fi; \
	echo "$$timestamp - Banned $(IP_ADDRESS): $$reason" >> /tmp/syncthing_banne_ips.log

.PHONY: security-ban-ip-list-detailed
security-ban-ip-list-detailed: ## Detailed list of banned IPs with rule numbers
	@echo "Detailed banned IPs list:"
	@printf "%-4s %-18s %-30s %s\n" "LINE" "IP ADDRESS" "TARGET" "COMMENT"
	@printf "%-4s %-18s %-30s %s\n" "----" "----------" "------" "-------"
	@sudo iptables -L INPUT -n --line-numbers | grep "DROP" | \
		while IFS= read -r line; do \
			if echo "$$line" | grep -q "SYNCTHING-BAN\|[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+"; then \
				line_num=$$(echo "$$line" | awk '{print $$1}'); \
				ip=$$(echo "$$line" | awk '{print $$5}'); \
				target=$$(echo "$$line" | awk '{print $$2}'); \
				comment=$$(echo "$$line" | grep -o '/\* .* \*/' | sed 's|/\* \(.*\) \*/|\1|' | head -c 25); \
				printf "%-4s %-18s %-30s %s\n" "$$line_num" "$$ip" "$$target" "$$comment"; \
			fi; \
		done 2>/dev/null || echo "No banned IPs found"

.PHONY: security-unban-by-line
security-unban-by-line: ## Unban IP by iptables line number (LINE_NUMBER required)
	@test -n "$(LINE_NUMBER)" || (echo "LINE_NUMBER required. Usage: make security-unban-by-line LINE_NUMBER=5" && exit 1)
	@echo "Removing iptables rule at line $(LINE_NUMBER)..."
	@rule_info=$$(sudo iptables -L INPUT -n --line-numbers | sed -n '$(LINE_NUMBER)p'); \
	if [ -n "$$rule_info" ]; then \
		ip=$$(echo "$$rule_info" | awk '{print $$5}'); \
		echo "Rule info: $$rule_info"; \
		sudo iptables -D INPUT $(LINE_NUMBER); \
		timestamp=$$(date '+%Y-%m-%d %H:%M:%S'); \
		echo "$$timestamp - Unbanned $$ip (via line number $(LINE_NUMBER))" >> /tmp/syncthing_banned_ips.log; \
		echo "✓ Rule at line $(LINE_NUMBER) removed successfully"; \
	else \
		echo "No rule found at line $(LINE_NUMBER)"; \
	fi

.PHONY: security-clear-all-bans
security-clear-all-bans: ## Clear all Syncthing-related bans
	@echo "Clearing all Syncthing-related bans..."
	@# Видаляти правила поки вони є
	@while sudo iptables -L INPUT -n --line-numbers | grep -q "SYNCTHING-BAN\|DROP.*[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"; do \
		line_num=$$(sudo iptables -L INPUT -n --line-numbers | grep "SYNCTHING-BAN\|DROP.*[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}" | head -1 | awk '{print $$1}'); \
		if [ -n "$$line_num" ]; then \
			rule_info=$$(sudo iptables -L INPUT -n --line-numbers | sed -n "$${line_num}p"); \
			ip=$$(echo "$$rule_info" | awk '{print $$5}'); \
			sudo iptables -D INPUT $$line_num; \
			echo "✓ Removed ban for $$ip"; \
		else \
			break; \
		fi; \
	done; \
	timestamp=$$(date '+%Y-%m-%d %H:%M:%S'); \
	echo "$$timestamp - Cleared all Syncthing bans" >> /tmp/syncthing_banned_ips.log; \
	echo "✓ All Syncthing-related bans cleared"

.PHONY: security-unban-ip
security-unban-ip: ## Unban IP address (IP_ADDRESS required)
	@test -n "$(IP_ADDRESS)" || (echo "IP_ADDRESS required. Usage: make security-unban-ip IP_ADDRESS=192.168.1.65" && exit 1)
	@echo "Unbanning IP: $(IP_ADDRESS)"
	@echo "Searching for iptables rules containing $(IP_ADDRESS)..."
	@# Показати які правила знайдено
	@sudo iptables -L INPUT -n --line-numbers | grep "$(IP_ADDRESS)" || echo "No rules found containing $(IP_ADDRESS)"
	@echo ""
	@# Видалити всі правила що містять цей IP
	@rules_removed=0; \
	while true; do \
		line_num=$$(sudo iptables -L INPUT -n --line-numbers | grep "$(IP_ADDRESS)" | head -1 | awk '{print $$1}'); \
		if [ -n "$$line_num" ] && [ "$$line_num" != "" ]; then \
			rule_info=$$(sudo iptables -L INPUT -n --line-numbers | sed -n "$${line_num}p"); \
			echo "Removing rule at line $$line_num: $$rule_info"; \
			sudo iptables -D INPUT $$line_num; \
			rules_removed=$$((rules_removed + 1)); \
		else \
			break; \
		fi; \
	done; \
	if [ $$rules_removed -gt 0 ]; then \
		timestamp=$$(date '+%Y-%m-%d %H:%M:%S'); \
		echo "$$timestamp - Unbanned $(IP_ADDRESS) (removed $$rules_removed rules)" >> /tmp/syncthing_banned_ips.log; \
		echo "✓ Successfully removed $$rules_removed rule(s) for IP $(IP_ADDRESS)"; \
	else \
		echo "✗ No rules found for IP $(IP_ADDRESS)"; \
	fi

.PHONY: security-debug-rules
security-debug-rules: ## Debug iptables rules for troubleshooting
	@echo "=== All INPUT rules ==="
	@sudo iptables -L INPUT -n --line-numbers
	@echo ""
	@echo "=== Rules containing 'DROP' ==="
	@sudo iptables -L INPUT -n --line-numbers | grep DROP || echo "No DROP rules found"
	@echo ""
	@echo "=== Rules containing 'SYNCTHING' ==="
	@sudo iptables -L INPUT -n --line-numbers | grep SYNCTHING || echo "No SYNCTHING rules found"

.PHONY: service-wait
service-wait: ## Wait for Syncthing service to be fully ready
	@echo "Waiting for Syncthing service to be ready..."; \
	waited=0; \
	while [ $$waited -lt $(WAIT_SERVICE_DURATION) ]; do \
		if $(MAKE) device-id >/dev/null 2>&1; then \
			echo "✓ Service ready (waited $${waited}s)"; \
			exit 0; \
		fi; \
		sleep 1; \
		waited=$$((waited + 1)); \
	done; \
	echo "✗ Service not ready after $(WAIT_SERVICE_DURATION)s"; \
	exit 1

.PHONY: device-pending
device-pending: require-container ## Show pending device connections
	@echo "Pending device connections:"
	@api_key=$$(docker exec syncthing-replica grep '<apikey>' /var/syncthing/config/config.xml | sed -E 's/.*<apikey>([^<]+)<\/apikey>.*/\1/'); \
	pending=$$(curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/cluster/pending/devices); \
	if echo "$$pending" | jq -e '. | length > 0' >/dev/null 2>&1; then \
		printf "%-50s %-20s %-15s %s\n" "DEVICE ID" "NAME" "ADDRESS" "TIME"; \
		printf "%-50s %-20s %-15s %s\n" "---------" "----" "-------" "----"; \
		echo "$$pending" | jq -r 'to_entries[] | "\(.key) \(.value.name // "Unknown") \(.value.address // "Unknown") \(.value.time // "Unknown")"' | \
			while read device_id name address time; do \
				printf "%-50s %-20s %-15s %s\n" "$$device_id" "$$name" "$$address" "$$time"; \
			done; \
	else \
		echo "  No pending device connections"; \
	fi

.PHONY: device-reject
device-reject: require-container ## Reject pending device connection (DEVICE_ID required)
	@test -n "$(DEVICE_ID)" || (echo "DEVICE_ID required. Usage: make device-reject DEVICE_ID=<device_id>" && exit 1)
	@echo "Rejecting device connection: $(DEVICE_ID)"
	@api_key=$$(docker exec syncthing-replica grep '<apikey>' /var/syncthing/config/config.xml | sed -E 's/.*<apikey>([^<]+)<\/apikey>.*/\1/'); \
	response=$$(curl -s -X DELETE -H "X-API-Key: $$api_key" -H "X-CSRF-Token: $$api_key" \
		http://localhost:$(SYNCTHING_UI_PORT)/rest/cluster/pending/devices/$(DEVICE_ID)); \
	echo "✓ Device $(DEVICE_ID) connection rejected"

.PHONY: device-approve
device-approve: require-container ## Approve pending device connections (DEVICE_ID or DEVICE_NAME optional)
	@api_key=$$(docker exec syncthing-replica grep '<apikey>' /var/syncthing/config/config.xml | sed -E 's/.*<apikey>([^<]+)<\/apikey>.*/\1/'); \
	if [ -z "$(DEVICE_ID)" ] && [ -z "$(DEVICE_NAME)" ]; then \
		echo "Pending device connections:"; \
		pending_devices=$$(curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/cluster/pending/devices | jq -r 'keys[]' 2>/dev/null); \
		if [ -z "$$pending_devices" ]; then \
			echo "  No pending device connections found"; \
		else \
			echo "$$pending_devices" | while read device_id; do \
				device_info=$$(curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/cluster/pending/devices | jq -r ".\"$$device_id\""); \
				name=$$(echo "$$device_info" | jq -r '.name // "Unknown"'); \
				address=$$(echo "$$device_info" | jq -r '.address // "Unknown"'); \
				time=$$(echo "$$device_info" | jq -r '.time // "Unknown"'); \
				echo "  Device ID: $$device_id"; \
				echo "  Name: $$name"; \
				echo "  Address: $$address"; \
				echo "  Time: $$time"; \
				echo ""; \
			done; \
			echo "Usage:"; \
			echo "  make device-approve DEVICE_ID=<full_device_id>"; \
			echo "  make device-approve DEVICE_NAME=<device_name>"; \
		fi; \
	else \
		target_device_id=""; \
		if [ -n "$(DEVICE_ID)" ]; then \
			target_device_id="$(DEVICE_ID)"; \
		elif [ -n "$(DEVICE_NAME)" ]; then \
			echo "Looking for device with name '$(DEVICE_NAME)'..."; \
			target_device_id=$$(curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/cluster/pending/devices | \
				jq -r 'to_entries[] | select(.value.name == "$(DEVICE_NAME)") | .key' 2>/dev/null); \
			if [ -z "$$target_device_id" ]; then \
				echo "Error: No pending device found with name '$(DEVICE_NAME)'"; \
				echo "Available pending devices:"; \
				curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/cluster/pending/devices | \
					jq -r 'to_entries[] | "  \(.value.name // "Unknown") (\(.key))"'; \
				exit 1; \
			fi; \
		fi; \
		echo "Approving device: $$target_device_id"; \
		pending_info=$$(curl -s -H "X-API-Key: $$api_key" http://localhost:$(SYNCTHING_UI_PORT)/rest/cluster/pending/devices | jq -r ".\"$$target_device_id\" // empty"); \
		if [ -z "$$pending_info" ]; then \
			echo "Error: No pending connection found for device $$target_device_id"; \
			exit 1; \
		fi; \
		device_name=$$(echo "$$pending_info" | jq -r '.name // "device-$$target_device_id"'); \
		device_address=$$(echo "$$pending_info" | jq -r '.address // "dynamic"'); \
		echo "Device info:"; \
		echo "  Name: $$device_name"; \
		echo "  Address: $$device_address"; \
		if docker exec syncthing-replica syncthing cli --home=/var/syncthing/config config devices add --device-id "$$target_device_id" --name "$$device_name" --addresses "$$device_address"; then \
			echo "✓ Device approved and added"; \
			echo "  ID: $$target_device_id"; \
			echo "  Name: $$device_name"; \
		else \
			echo "✗ Failed to approve device"; \
			exit 1; \
		fi; \
	fi
