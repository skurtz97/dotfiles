# ANSI Color Codes
CYAN    := \033[0;36m
GREEN   := \033[0;32m
RED     := \033[0;31m
NC      := \033[0m # No Color

# Define "packages" to manage
PACKAGES := bash vscode vscode-meta gamemode xdg scripts systemd

# Target directory for symlinks (my home directory)
TARGET := ~

.PHONY: deploy clean archive systemd

# Deploys all packages
deploy:
	@echo -e "${CYAN}==> Deploying dotfiles...${NC}"
	for pkg in $(PACKAGES); do \
		echo -e "${GREEN}Stowing package: $$pkg${NC}"; \
		stow -v -t $(TARGET) $$pkg; \
	done
	@echo -e "${GREEN}Deployment complete.${NC}"

# Removes all symlinks managed by these packages
clean:
	@echo "${RED}==> Unstowing dotfiles...${NC}"
	for pkg in $(PACKAGES); do \
		echo -e "${RED}Unstowing package: $$pkg${NC}"; \
		stow -v -D -t $(TARGET) $$pkg; \
	done
	@echo -e "${RED}Clean complete.${NC}"

# Automated Backup Target
archive:
	echo -e "${CYAN}==> Starting automated backup...${NC}"
	/home/skurtz/bin/backup-home.sh
	echo -e "${GREEN}Backup complete.${NC}"