# ANSI Color Codes
CYAN    := \033[0;36m
GREEN   := \033[0;32m
RED     := \033[0;31m
NC      := \033[0m # No Color

# Define "packages" to manage
PACKAGES := bash vscode xdg

# Target directory for symlinks (my home directory)
TARGET := ~

.PHONY: deploy clean

# Deploys all packages
deploy:
	@echo "${CYAN}==> Deploying dotfiles...${NC}"
	for pkg in $(PACKAGES); do \
		echo "${GREEN}Stowing package: $$pkg${NC}"; \
		stow -v -t $(TARGET) $$pkg; \
	done
	@echo "${GREEN}Deployment complete.${NC}"

# Removes all symlinks managed by these packages
clean:
	@echo "${RED}==> Unstowing dotfiles...${NC}"
	for pkg in $(PACKAGES); do \
		echo "${RED}Unstowing package: $$pkg${NC}"; \
		stow -v -D -t $(TARGET) $$pkg; \
	done
	@echo "${RED}Clean complete.${NC}"