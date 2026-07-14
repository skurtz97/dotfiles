# =============================================================================
# Dotfiles Makefile (GNU Stow Automation)
# =============================================================================

# Default target directory is the user's home directory
TARGET   := $(HOME)

# List of all dotfile packages to manage with Stow
PACKAGES := bash nvim scripts systemd vscode vscode-meta xdg shellcheck

# Stow base arguments (-v: verbose, --target: destination)
STOW_CMD := stow -v --target="$(TARGET)"

.PHONY: all stow restow adopt delete clean-links help

# Default action when just running `make`
all: restow

# -----------------------------------------------------------------------------
# Core Stow Targets
# -----------------------------------------------------------------------------
# Deploy symlinks for all tracked packages
stow:
	@echo "=> Stowing packages to $(TARGET)..."
	@$(STOW_CMD) $(PACKAGES)

# Refresh/relink symlinks (useful after renaming or moving files)
restow:
	@echo "=> Restowing packages to $(TARGET)..."
	@$(STOW_CMD) -R $(PACKAGES)

# Adopt existing host files into the repo and symlink them
adopt:
	@echo "=> Adopting host files and restowing..."
	@$(STOW_CMD) -R --adopt $(PACKAGES)
	@echo "=> Note: Check 'git status' to review adopted files!"

# Remove all symlinks created by Stow
delete:
	@echo "=> Removing stow symlinks from $(TARGET)..."
	@$(STOW_CMD) -D $(PACKAGES)

# -----------------------------------------------------------------------------
# Maintenance Targets
# -----------------------------------------------------------------------------

# Find and delete broken/dead symlinks up to 3 levels deep in $HOME
clean-links:
	@echo "=> Sweeping $(TARGET) for broken symlinks..."
	@find "$(TARGET)" -maxdepth 3 -xtype l -delete 2>/dev/null || true
	@echo "=> Sweep complete."

# Display available commands
help:
	@echo "Available targets:"
	@echo "  make stow        - Symlink all packages to $(TARGET)"
	@echo "  make restow      - Refresh/relink all packages (Default)"
	@echo "  make adopt       - Pull host files into repo & link"
	@echo "  make delete      - Remove all package symlinks"
	@echo "  make clean-links - Delete dead symlinks in $(TARGET)"