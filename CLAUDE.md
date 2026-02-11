# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a personal dotfiles repository that manages configuration for bash, vim, neovim, tmux, git, and related development tools. Configurations are Linux-focused (Bazzite/Fedora), with conditional behavior based on hostname (MaxMind work vs personal) and environment type (desktop/laptop/server).

## Installation

```bash
./install.sh
```

This symlinks configs to home directory, runs vim-plug installation, sets up git configuration, and installs TPM for tmux. Migrates old marker files and creates a new one if needed via heuristic detection.

## Key Architecture Decisions

### Environment Detection
- Two-axis scheme: **local/remote** x **work/personal**
- Environment types via marker files in `$HOME`:
  - `~/.local-work` → work laptop with i3/Regolith, enables i3 configs, xcape (X11 only), brew, vim
  - `~/.local-personal` → personal desktop (e.g., Bazzite/KDE), enables SSH agent, brew, xcape, vim
  - `~/.remote-work` → work server, minimal config (no brew, no modern CLI tools)
  - `~/.remote-personal` → personal server, full tooling (brew, neovim, starship) but no vim, xcape, or gpgconf
- Heuristic detection when no marker exists (graphical session → local, hostname contains "maxmind" → work)
- `install.sh` auto-creates marker file on first run with diagnostic output
- Work vs personal distinguished by hostname containing "maxmind"
- Wayland detection: `$XDG_SESSION_TYPE` checked before running X11-only tools like xcape
- Local customizations via `~/.local-bashrc` and `~/.local_vimrc`
- Work-specific items (gcloud, MaxMind tools) go in `~/.local-bashrc`

### Editor Configuration
- **Vim**: Uses vim-plug for plugins. Config in `vim/vimrc`. Go and Perl development focused with ALE linting, fzf integration, and perltidy formatting. Keybindings roughly aligned with neovim.
- **Neovim**: Simplified config with lazy.nvim. Single `init.lua` with LSP (gopls, pyright, etc.), telescope, treesitter, copilot. Nightly builds via Homebrew. Keybindings:
  - `=` runs perltidy (Perl files)
  - `<leader>perl` / `<leader>gomain` / `<leader>bash` for language templates
  - `<C-h/j/k/l>` for window navigation
  - `zz` for fold-search toggle

### Shell Configuration
- Vi mode enabled (`set -o vi`)
- Custom prompt function `cynprompt` with git status integration via `bin/git-prompt`
- Persistent history to `~/.persistent_history`
- Heavy Perl tooling: plenv, perltidy, perlcritic

### Git Aliases (set by `git-config.sh`)
Key aliases: `from` (fetch + rebase origin/main), `pf` (push --force-with-lease), `dom/doms/domo` (diff against origin/main variants), `prom` (pull --rebase origin main), `sw` (switch), `rs` (restore)

## File Relationships

- `install.sh` → migrates old markers, auto-creates marker via heuristic, calls `install/vim.sh` (skipped for remote-personal) and `install/nvim.sh`
- `install/vim.sh` → uses `bash_functions.sh` for IS_MM detection, installs vim-plug, symlinks vimrc
- `install/nvim.sh` → installs neovim nightly via Homebrew (local-work, local-personal, remote-personal), symlinks init.lua, syncs lazy.nvim plugins
- `vim/vimrc` sources `~/.local_vimrc` (set to either `maxmind_local_vimrc` or `vanilla_local_vimrc`)
- `bashrc` sources `~/.local-bashrc` at end (NVM lazy-loaded for fast shell startup)
- `tmux/tmux.conf` uses TPM plugins (continuum, resurrect, sessionist)
- `uninstall.sh` reverts changes made by install.sh

## Bazzite/Immutable OS Notes

One deployment target is Bazzite (Fedora Atomic/immutable distro with KDE). Key differences:

### Package Management
- **DO NOT use `dnf install`** - the base system is read-only
- **System packages**: Use `rpm-ostree install <pkg>` (requires reboot to apply)
- **User-space tools**: Use Homebrew (`brew install`) - bashrc already adds linuxbrew to PATH
- **Applications**: Prefer Flatpaks
- **Development environments**: Consider distrobox containers

### Wayland Considerations
- Bazzite with KDE uses Wayland by default
- `xcape` does not work on Wayland (bashrc checks `$XDG_SESSION_TYPE`)
- For Ctrl→Escape keyboard remap, use `keyd` (needs `rpm-ostree install keyd`)
- Clipboard tools: use `wl-copy`/`wl-paste` instead of `xclip`

### What Works Without Changes
- All shell configs, vim/neovim, tmux, git
- Homebrew-installed tools (ripgrep, fzf, tmux, neovim, bat, eza, fd, tailspin, lnav)
- Version managers in user space (plenv, pyenv, nvm, cargo)

## Code Quality

### Git Hooks (Automatic)
- **pre-commit**: Auto-formats bash files with shfmt (no friction)
- **pre-push**: Verifies shellcheck passes and formatting is correct

Hooks are installed automatically by `install.sh`.

### Manual Commands
```bash
# Lint bash scripts
shellcheck bashrc bash_common.sh install.sh git-config.sh

# Format bash scripts (2-space indent)
shfmt -i 2 -ci -w bashrc install.sh
```

### Acceptable shellcheck Warnings
- SC1090/SC1091 - Can't follow dynamic `source` (unavoidable)
- SC2155 - Declare/assign separately (style preference)
- SC2139 - Variable expands at definition (intentional for ls alias)

### Formatting Style
- 2-space indentation
- Case statements indented
- No space after redirects (`>file` not `> file`)
- Binary operators at end of line when wrapping

## Maintenance

Run `./install.sh` weekly to pick up dotfile changes and upgrade brew tools. The shell displays a reminder if it's been over a week. Use `--no-upgrade` to skip brew upgrades.
