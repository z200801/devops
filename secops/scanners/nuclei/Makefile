.SHELL        := /bin/bash
.DEFAULT_GOAL := help
# Variables
IMAGE_NAME    ?= nuclei-scanner
TAG           ?= latest
RESULTS_DIR   ?= ./results
TARGET_URL    ?= http://localhost
TARGET_FILE   ?= targets.txt
SEVERITY      ?= critical,high,cve

# Create results directory if it doesn't exist
$(RESULTS_DIR):
	mkdir -p $(RESULTS_DIR)

# ---------- Commands ----------
.PHONY: help
help: ## Show this help message
	@echo "Nuclei Scanner - Makefile Commands"
	@echo "=================================="
	@echo ""
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo "Examples:"
	@echo "  make scan TARGET_URL=https://example.com"
	@echo "  make scan-list TARGET_FILE=my-targets.txt"
	@echo "  make scan-severity TARGET_URL=https://example.com SEVERITY=medium,high"

.PHONY: build
build: ## Build Docker image
	docker build -t $(IMAGE_NAME):$(TAG) .

.PHONY: verify-templates
verify-templates: ## Verify templates are installed
	@echo "Checking installed templates..."
	docker run --rm $(IMAGE_NAME):$(TAG) -tl | head -20


.PHONY: run
run: ## Run container with help
	docker run --rm $(IMAGE_NAME):$(TAG)


.PHONY: scan
scan: ## Scan single target (use TARGET_URL=https://...)
	docker run --rm \
		-v $(PWD)/$(RESULTS_DIR):/output \
		$(IMAGE_NAME):$(TAG) \
		-u $(TARGET_URL) \
		-o /output/scan-results.txt



.PHONY: scan-list 
scan-list: ## Scan from targets file (use TARGET_FILE=targets.txt) 
	@if [ ! -f $(TARGET_FILE) ]; then \
		echo "Error: $(TARGET_FILE) not found!"; \
		exit 1; \
	fi
	docker run --rm \
		-v $(PWD)/$(TARGET_FILE):/targets.txt \
		-v $(PWD)/$(RESULTS_DIR):/output \
		$(IMAGE_NAME):$(TAG) \
		-l /targets.txt \
		-o /output/scan-results.txt


.PHONY: scan-cve
scan-cve: ## Scan CVEs only
	docker run --rm \
		-v $(PWD)/$(RESULTS_DIR):/output \
		$(IMAGE_NAME):$(TAG) \
		-u $(TARGET_URL) \
		-tags cves \
		-o /output/cve-scan.txt

.PHONY: scan-severity
scan-severity: ## Scan with severity filter (use SEVERITY=critical,high)
	docker run --rm \
		-v $(PWD)/$(RESULTS_DIR):/output \
		$(IMAGE_NAME):$(TAG) \
		-u $(TARGET_URL) \
		-severity $(SEVERITY) \
		-o /output/severity-scan.txt


.PHONY: scan-exposures
scan-exposures: ## Scan exposures
	docker run --rm \
		-v $(PWD)/$(RESULTS_DIR):/output \
		$(IMAGE_NAME):$(TAG) \
		-u $(TARGET_URL) \
		-tags exposure \
		-o /output/exposures-scan.txt


.PHONY: scan-misconfig
scan-misconfig: ## Scan misconfigurations
	docker run --rm \
		-v $(PWD)/$(RESULTS_DIR):/output \
		$(IMAGE_NAME):$(TAG) \
		-u $(TARGET_URL) \
		-tags misconfig \
		-o /output/misconfig-scan.txt


.PHONY: update-templates
update-templates: ## Update templates in running container
	docker run --rm $(IMAGE_NAME):$(TAG) -update-templates

.PHONY: clean
clean: ## Clean results and Docker image
	rm -rf $(RESULTS_DIR)
	docker rmi $(IMAGE_NAME):$(TAG) 2>/dev/null || true

.PHONY: clean-results
clean-results: ## Clean only results
	rm -rf $(RESULTS_DIR)/*


