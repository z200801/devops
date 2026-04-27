DATE := $(shell date +%Y%m%d_%H%M%S)

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: du
du: ## Show disk usage of nvim config and data
	@echo "Config:"; du -sh ~/.config/nvim
	@echo "Data:"; du -sh ~/.local/share/nvim
	@echo "Plugins:"; du -sh ~/.local/share/nvim/lazy/* 2>/dev/null | sort -h | tail -10
	@echo "Backups:"; du -sh ~/.config/nvim.bak.* ~/.local/share/nvim.bak.* 2>/dev/null || echo "none"

.PHONY: backup
backup: ## Backup current nvim config and data
	mv ~/.config/nvim ~/.config/nvim.bak.$(DATE)
	mv ~/.local/share/nvim ~/.local/share/nvim.bak.$(DATE)

.PHONY: restore
restore: ## Restore latest backup
	$(eval BACKUP := $(shell ls -d ~/.config/nvim.bak.* 2>/dev/null | sort | tail -1))
	mv ~/.config/nvim ~/.config/nvim.disabled
	mv $(BACKUP) ~/.config/nvim
	$(eval BACKUP_SHARE := $(shell ls -d ~/.local/share/nvim.bak.* 2>/dev/null | sort | tail -1))
	mv ~/.local/share/nvim ~/.local/share/nvim.disabled
	mv $(BACKUP_SHARE) ~/.local/share/nvim

.PHONY: clean-disabled
clean-disabled: ## Remove disabled config and data
	rm -rf ~/.config/nvim.disabled
	rm -rf ~/.local/share/nvim.disabled

.PHONY: list
list: ## List all backups
	@echo "Config backups:"; ls -d ~/.config/nvim.bak.* 2>/dev/null || echo "none"
	@echo "Share backups:"; ls -d ~/.local/share/nvim.bak.* 2>/dev/null || echo "none"

.PHONY: install
install: ## Backup old config and install new
	$(MAKE) backup
	bash setup-nvim.sh

.PHONY: update
update: ## Update all plugins
	nvim --headless "+Lazy! sync" +qa

.PHONY: mason-update
mason-update: ## Update all mason packages
	nvim --headless "+MasonUpdate" +qa


.PHONY: remove-backup
remove-backup: ## Remove specific backup (usage: make remove-backup DATE=20260427_123456)
	@if [ -z "$(BACKUP)" ]; then \
		echo "Usage: make remove-backup BACKUP=20260427_123456"; \
	else \
		rm -rf ~/.config/nvim.bak.$(BACKUP) ~/.local/share/nvim.bak.$(BACKUP); \
		echo "Removed backup $(BACKUP)"; \
	fi

