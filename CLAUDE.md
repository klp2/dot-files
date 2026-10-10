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
  - `~/.local-work` → work laptop with i3/Regolith, enables i3 configs, xcape (X11 only), mise, vim
  - `~/.local-personal` → personal desktop (e.g., Bazzite/KDE), enables SSH agent, mise, xcape, vim
  - `~/.remote-work` → work server, minimal config (no brew, no modern CLI tools)
  - `~/.remote-personal` → personal server, full tooling (mise, neovim, starship) but no vim, xcape, or gpgconf
- Heuristic detection when no marker exists (graphical session → local, hostname contains "maxmind" → work)
- `install.sh` auto-creates marker file on first run with diagnostic output
- Work vs personal distinguished by hostname containing "maxmind"
- Wayland detection: `$XDG_SESSION_TYPE` checked before running X11-only tools like xcape
- Local customizations via `~/.local-bashrc` and `~/.local_vimrc`. Some `~/.local-bashrc` exports pin absolute paths to versioned tools (e.g. `LOCAL_REVIEW_LLAMA` → a llama.cpp build dir, `LOCAL_REVIEW_MODEL` → a model snapshot); `install.sh` warns when a pinned path no longer exists, and upgrading the pinned tool means updating the pin
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

### Tool Management
- **mise** installs CLI tools and runtimes everywhere except remote-work, which stays minimal. Personal and local-work machines use the standalone install at `~/.local/bin/mise` (self-updating); the devcontainer image ships its own.
- `config/mise/common.toml` → `~/.config/mise/conf.d/10-dotfiles.toml` (shared tool list); per-environment `mise.personal.toml` / `mise.work.toml` → `~/.config/mise/config.toml`, which wins on overlap (devcontainer links the work file into conf.d instead, beside the image's own config.toml)
- Prefer aqua backends (checksummed release binaries); `github:` for tools aqua lacks; `http:` with the public releases feed for MaxMind's tools, whose org's SAML enforcement rejects the GitHub API token; asdf/vfox backends are disabled
- Machine-wide installs are `[bootstrap.packages]` entries (`brew:` for entr, `flatpak-user:` for LibreOffice), applied by `mise bootstrap packages apply`; entries whose manager is missing are skipped. `install/flatpak.sh` installs Flatpak and adds the Flathub remote, which mise does not do
- Homebrew itself remains for neovim nightly (`install/nvim.sh`) and the `brew:` package entries; `cleanup.sh` offers to uninstall brew formulae mise replaced
- Settings in `common.toml`: `lockfile = true` everywhere (work adds `locked = true`), `minimum_release_age = "7d"`
- `install.sh` generates bash completions for mise tools into `~/.local/share/bash-completion/completions`; bashrc loads bash-completion, which picks them up on demand

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
- **User-space tools**: Use mise (see Tool Management below); Homebrew only for what mise can't provide
- **Applications**: Prefer Flatpaks
- **Development environments**: Consider distrobox containers

### Wayland Considerations
- Bazzite with KDE uses Wayland by default
- `xcape` does not work on Wayland (bashrc checks `$XDG_SESSION_TYPE`)
- For Caps→Esc(tap)/Ctrl(hold) remap, use `keyd` (config in `keyd/`, applied by `install/keyd.sh`). keyd is NOT in Fedora base repos — enable the `alternateved/keyd` COPR (`.repo` into `/etc/yum.repos.d/`) then `rpm-ostree install keyd` + reboot. `install/keyd.sh` prints the exact commands.
- Clipboard tools: use `wl-copy`/`wl-paste` instead of `xclip`

### Tiling on KDE/Wayland (personal desktop)
- i3-style tiling via Krohnkite (vendored + pinned in `kwin/`, installed by `install/kde-tiling.sh`)
- Borderless windows (i3 `default_border none`) via a forced `kwinrulesrc` rule; instant desktop switch by disabling the slide effect
- Keybindings are a clean personal port of `i3/config`, written to `kglobalshortcutsrc` via `kwriteconfig6` (KDE has no hand-editable rc); edits must be made with the kglobalaccel daemon quiescent, and a re-login activates them
- All KDE/keyd/Zellij installers self-gate on `is_kde_wayland_personal` (`bash_functions.sh`): `~/.local-personal` + KDE + Wayland
- Local multiplexer is Zellij (installed by mise, pure defaults); tmux stays the remote/SSH multiplexer
- Design/plan: `docs/superpowers/specs/` and `docs/superpowers/plans/`

### What Works Without Changes
- All shell configs, vim/neovim, tmux, git
- mise-installed tools and runtimes (all user space)
- Homebrew-installed tools (neovim nightly, entr)

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

Run `./install.sh` weekly to pick up dotfile changes and upgrade mise and brew tools. The shell displays a reminder if it's been over a week. Use `--no-upgrade` to skip upgrades.
