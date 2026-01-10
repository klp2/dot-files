# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a personal dotfiles repository that manages configuration for bash, vim, neovim, tmux, git, and related development tools. Configurations support both Linux and macOS, with conditional behavior based on hostname (MaxMind work vs personal) and platform detection.

## Installation

```bash
./install.sh
```

This symlinks configs to home directory, runs vim-plug installation, sets up git configuration, and installs TPM for tmux. Creates `~/.laptop` file to enable laptop-specific features (i3, xcape, linuxbrew paths).

## Key Architecture Decisions

### Environment Detection
- Platform detected via `uname` (linux/osx) in `bashrc` and `git-config.sh`
- Work vs personal distinguished by hostname containing "maxmind"
- Environment types via marker files:
  - `~/.laptop` → work laptop with i3/Regolith, enables i3 configs, xcape (X11 only)
  - `~/.desktop` → personal desktop (e.g., Bazzite/KDE), enables SSH agent and brew paths but NOT i3
  - Neither → remote server, minimal config
- Wayland detection: `$XDG_SESSION_TYPE` checked before running X11-only tools like xcape
- Local customizations via `~/.local-bashrc` and `~/.local_vimrc`

### Editor Configuration
- **Vim**: Uses vim-plug for plugins. Main config in `vim/vimrc`, plugin list in `vim/vim-plug-vimrc`. Perl and Go development focused with ALE linting, fzf integration, and perltidy formatting.
- **Neovim**: Based on kickstart.nvim. Single `init.lua` with lazy.nvim for plugins. Symlinked to `~/.config/nvim/`.

### Shell Configuration
- Vi mode enabled (`set -o vi`)
- Custom prompt function `cynprompt` with git status integration via `bin/git-prompt`
- Persistent history to `~/.persistent_history`
- Heavy Perl tooling: plenv, perltidy, perlcritic

### Git Aliases (set by `git-config.sh`)
Key aliases: `from` (fetch + rebase origin/master), `pf` (push --force-with-lease), `dom/doms/domo` (diff against origin/master variants), `prom` (pull --rebase origin master)

## File Relationships

- `install.sh` → calls `install/vim.sh` and `install/nvim.sh`
- `install/vim.sh` → uses `bash_functions.sh` for IS_MM detection, installs vim-plug, symlinks vimrc
- `vim/vimrc` sources `~/.local_vimrc` (set to either `maxmind_local_vimrc` or `vanilla_local_vimrc`)
- `bashrc` sources `~/.local-bashrc` at end
- `tmux/tmux.conf` uses TPM plugins and sources `~/.tmux-osx.conf` on macOS
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
- Homebrew-installed tools (ack, fzf, tmux, neovim, perl)
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
