# =============================================================================
# Dotfiles Makefile (GNU Stow Automation)
# =============================================================================

# Default target directory is the user's home directory
TARGET   := $(HOME)

# List of all dotfile packages to manage with Stow
PACKAGES := \
	bash \
	git \
	nvim \
	systemd \
	vscode \
	vscode-meta \
	xdg \
	shellcheck \
	nautilus \
	aider \
	ssh \
	opencode \
	x3270

# Stow base arguments (-v: verbose, --target: destination)
STOW_CMD := stow -v --no-folding --target="$(TARGET)"

# Scripts are linked by hand so extensions can be stripped:
# scripts/bin/foo.sh -> ~/.local/bin/foo
BIN_DIR  := $(HOME)/.local/bin
SCRIPTS  := $(wildcard scripts/bin/*)

.PHONY: all stow restow adopt delete link-scripts unlink-scripts clean-links help

# Default action when just running `make`
all: restow

# -----------------------------------------------------------------------------
# Core Stow Targets
# -----------------------------------------------------------------------------
# Deploy symlinks for all tracked packages
stow: link-scripts
	@echo "=> Stowing packages to $(TARGET)..."
	@$(STOW_CMD) $(PACKAGES)

# Refresh/relink symlinks (useful after renaming or moving files)
restow: link-scripts
	@echo "=> Restowing packages to $(TARGET)..."
	@$(STOW_CMD) -R $(PACKAGES)

# Adopt existing host files into the repo and symlink them
adopt: link-scripts
	@echo "=> Adopting host files and restowing..."
	@$(STOW_CMD) -R --adopt $(PACKAGES)
	@echo "=> Note: Check 'git status' to review adopted files!"

# Remove all symlinks created by Stow
delete: unlink-scripts
	@echo "=> Removing stow symlinks from $(TARGET)..."
	@$(STOW_CMD) -D $(PACKAGES)

# -----------------------------------------------------------------------------
# Script Targets
# -----------------------------------------------------------------------------
# Link scripts/bin/* into BIN_DIR with any extension stripped
link-scripts:
	@echo "=> Linking scripts to $(BIN_DIR)..."
	@mkdir -p "$(BIN_DIR)"
	@for f in $(SCRIPTS); do \
		name=$${f##*/}; \
		ln -sfrv "$$f" "$(BIN_DIR)/$${name%.*}"; \
	done

# Remove the links made by link-scripts
unlink-scripts:
	@echo "=> Removing script links from $(BIN_DIR)..."
	@for f in $(SCRIPTS); do \
		name=$${f##*/}; link="$(BIN_DIR)/$${name%.*}"; \
		if [ -L "$$link" ]; then rm -v "$$link"; fi; \
	done

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
	@echo "  make stow           - Symlink all packages to $(TARGET)"
	@echo "  make restow         - Refresh/relink all packages (Default)"
	@echo "  make adopt          - Pull host files into repo & link"
	@echo "  make delete         - Remove all package symlinks"
	@echo "  make link-scripts   - Link scripts/bin/* to $(BIN_DIR), extension stripped"
	@echo "  make unlink-scripts - Remove those links"
	@echo "  make clean-links    - Delete dead symlinks in $(TARGET)"
