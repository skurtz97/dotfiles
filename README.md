# Dotfiles

This repository houses my personal workstation configuration for Fedora 44. It is managed using **GNU Stow**, which allows me to maintain a clean home directory by symlinking configuration files from this repository to their correct locations in ~/ or ~/.config/.

## Directory Structure

```bash
.
├── bash/        # Shell configuration (.bashrc, .bash_profile)
├── nvim/        # Neovim configuration (~/.config/nvim/)
├── scripts/     # Custom user scripts (~/.local/bin/)
├── systemd/     # User-level systemd services
├── vscode/      # VS Code settings and keybindings
├── vscode-meta/ # VS Code metadata (e.g., argv.json)
├── xdg/         # XDG directory configurations
└── Makefile     # Automation tool for stow
```

## Quick Start

To setup on a new machine:

1. Clone the repository:

    ```bash
    mkdir -p ~/src
    git clone https://github.com/skurtz97/dotfiles ~/src/dotfiles
    cd ~/src/dotfiles
    ```

2. Deploy the dotfiles

    ```bash
    make
    ```

## Makefile Usage

| Command | Action |
| ------- | ------ |
| `make` | **Default**. Runs `restow`. Use this after changing any config file. |
| `make restow` | Refreshes and relinks packages. |
| `make adopt` | Imports an existing local file into the repo and links it (essential when adding existing condfigs.) |
| `make delete` | Removes all symlinks managed by this repo |
| `make help` | Displays this command list |

...

## Neovim Setup

This configuration uses `lazy.nvim` as the plugin manager and `lazydev.nvim` for LSP development.

- **Managing Plugins**: Open Neovim and run `:Lazy` to open the plugin manager UI.
- **Troubleshooting**: If you see red dots in the `:Lazy` UI, highlight the plugin and press `Enter` to see the error logs. Use `:TSUpdate` to manually re-compile treesitter parsers if highlighting breaks.
- **Intellisense**: The `.vscode/settings.json` is linked to the project root. If IntelliSense fails in VSCode, open the command palette and run **"Lua: Restart Language Server"**
