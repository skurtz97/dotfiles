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

## GRUB Boot Menu

System-level configuration — **not** managed by Stow. These files live
outside `$HOME` and must be reapplied manually on a fresh install.

### Dual-boot layout

- Fedora: btrfs pool across `nvme0n1` + `nvme2n1`
- Windows 11: `nvme2n1`, sharing the ESP at `nvme0n1p1`
- GRUB chainloads Windows via `os-prober`
- Boot order: `efibootmgr -o 0001,0000` (Fedora first)

### `/etc/default/grub`

Non-default values:

```bash
GRUB_TIMEOUT=10                  # 10s to pick an OS
GRUB_TIMEOUT_STYLE=menu          # always show the menu
#GRUB_TERMINAL_OUTPUT="console"  # MUST stay commented: blocks gfx mode
GRUB_GFXMODE=2560x1440,auto      # native res (Odyssey G61SD)
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_OS_PROBER=false     # required to detect Windows
GRUB_THEME="/usr/share/grub/themes/tela/theme.txt"
```

### Theme

[vinceliuice/grub2-themes](https://github.com/vinceliuice/grub2-themes),
same author as the Colloid/Orchis GTK themes:

```bash
git clone https://github.com/vinceliuice/grub2-themes ~/src/grub2-themes
cd ~/src/grub2-themes
sudo ./install.sh -t tela -s 2k    # -s 2k = 2560x1440 assets
```

The installer writes `GRUB_THEME` and runs `grub2-mkconfig` itself, but
does *not* clobber `GRUB_TIMEOUT`.

### Regenerating

```bash
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

`/etc/grub2-efi.cfg` symlinks here; `/boot/efi/EFI/fedora/grub.cfg` is a
shim that chains to it. Verify the output includes
`Found Windows Boot Manager on /dev/nvme0n1p1`.

### Notes

- `/boot/grub2` is mode 700 — inspect with `sudo ls`, not `ls`.
- Kernel updates re-run `grub2-mkconfig` and preserve the theme. A
  `grub2-common` reinstall resets the shim and requires reapplying.
- If the menu is skipped entirely, check
  `sudo grub2-editenv - list` for `menu_auto_hide=1` and unset it.
- Custom PF2 font (unused, tela ships its own):
  `sudo grub2-mkfont -s 32 -o /boot/grub2/fonts/NAME.pf2 FONT.otf`