# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a personal dotfiles repository that manages configuration for bash, vim, neovim, tmux, git, and related development tools. Configurations are Linux-focused (Bazzite/Fedora), with conditional behavior based on hostname (MaxMind work vs personal) and environment type (desktop/laptop/server).

## Installation

```bash
./install.sh
```

This symlinks configs to home directory, installs mise and its tools and packages, runs vim-plug installation, sets up git configuration, and installs TPM for tmux. Migrates old marker files and creates a new one if needed via heuristic detection.

## Key Architecture Decisions

### Environment Detection
- Two-axis scheme: **local/remote** x **work/personal**
- Environment types via marker files in `$HOME`:
  - `~/.local-work` → work laptop with i3/Regolith, enables i3 configs, xcape (X11 only), mise, vim
  - `~/.local-personal` → personal desktop (e.g., Bazzite/KDE), enables SSH agent, mise, xcape, vim
  - `~/.remote-work` → work server, minimal config (no brew, no modern CLI tools; mise only links the dotfiles)
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
- Heavy Perl tooling: perltidy, perlcritic

### Git Aliases (set by `git-config.sh`)
Key aliases: `from` (fetch + rebase origin/main), `pf` (push --force-with-lease), `dom/doms/domo` (diff against origin/main variants), `prom` (pull --rebase origin main), `sw` (switch), `rs` (restore)

### Tool Management
- **mise** links the dotfiles everywhere, and installs CLI tools and runtimes everywhere except remote-work, which stays minimal (bashrc does not activate mise there). All but the devcontainer use the standalone install at `~/.local/bin/mise` (self-updating); the devcontainer image ships its own.
- mise envs: `install.sh` writes `~/.config/mise/miserc.toml` from the marker on every run: `env = [<envtype>]`, plus `"desktop"` first on local-work and local-personal. `MISE_ENV`, `-E`, or a project's `.miserc.toml` *replaces* that list, so tool lists and settings never live in `config.<env>.toml` files, only bootstrap-time config
- `config/mise/base.toml` → `~/.config/mise/conf.d/05-base.toml` (every environment): mise's supply-chain settings and the `[dotfiles]` entries that `install.sh` deploys with `mise dot apply --force` and again in `mise bootstrap`. Sources are written `~/dot-files/...` because a relative source resolves against conf.d, not the repo. Symlink is the default; `copy` only where a file needs its own mode or an app rewrites it. Per-environment links are `variants` (`profile` = a mise env; one name per variant, and no entry may name two profiles one machine selects, or the tie voids it). Links gated on a runtime check (`~/.local_vimrc` by mm-perl, i3 on a personal box with i3, Regolith, alacritty) are still `ln -sf` in the installers
- `config/mise/config.<env>.toml` (`desktop`, `local-personal`, `remote-work`) → `~/.config/mise/`, linked on every machine by base.toml; only the selected ones load. They hold `[bootstrap.hooks]` that run `install/*.sh`, `[bootstrap.files]`/`services` (keyd config, `~/.ssh` modes), and edit entries (the SSH `Include` line), which take no variants
- Tool configs are base.toml variants in conf.d, everywhere but remote-work: `common.toml` → `conf.d/10-dotfiles.toml`; `mise.work.toml` / `mise.personal.toml` → `conf.d/20-work.toml` / `20-personal.toml`, which win on overlap. `config.toml` is no longer ours (the devcontainer image's own stays)
- Prefer aqua backends (checksummed release binaries); `github:` for tools aqua lacks; `http:` with the public releases feed for MaxMind's tools, whose org's SAML enforcement rejects the GitHub API token; asdf/vfox backends are disabled
- Machine-wide installs are `[bootstrap.packages]` entries (`brew:` for entr, `flatpak-user:` for LibreOffice), applied by `mise bootstrap --only packages` in a run of their own, since a failed package aborts a bootstrap run; entries whose manager is missing are skipped. `install/flatpak.sh` (a desktop pre-packages hook) installs Flatpak and adds the Flathub remote, which mise does not do
- `install.sh` runs `mise bootstrap --skip packages,tools --force-dotfiles` after its own tool install/upgrade/lock steps. Hooks run on every bootstrap, so `install/*.sh` must stay safe to repeat; a failing hook aborts the run. Avoid `pre/post-dotfiles` hooks (they also fire on plain `mise dot apply`) and a global `[tasks.bootstrap]` (it would show in every project)
- Dry-run changes against the real home with an isolated `MISE_CONFIG_DIR` (not `MISE_GLOBAL_CONFIG_FILE`), run from outside `$HOME`, or mise also finds the live `~/.config/mise/conf.d` as project config
- Homebrew itself remains for neovim nightly (`install/nvim.sh`) and the `brew:` package entries; `cleanup.sh` offers to uninstall brew formulae mise replaced
- Settings: `base.toml` has `minimum_release_age = "7d"`, `self_update.auto = true`, and the disabled backends; `common.toml` has `lockfile = true` (work adds `locked = true`)
- `install.sh` generates bash completions for mise tools into `~/.local/share/bash-completion/completions`; bashrc loads bash-completion, which picks them up on demand

## File Relationships

- `install.sh` → migrates old markers, auto-creates marker via heuristic, writes miserc, then `mise bootstrap` runs the installers as hooks: `nvim.sh` everywhere (base.toml); `flatpak.sh`, `keyd.sh` (pre-packages), `1password.sh`, `vim.sh` on desktops; `kde-tiling.sh` on local-personal; `vim.sh` on remote-work
- `install/vim.sh` → uses `bash_functions.sh` for IS_MM detection to pick `~/.local_vimrc`, installs vim-plug and plugins (`~/.vimrc` is a base.toml link)
- `install/nvim.sh` → installs neovim nightly via Homebrew (local-work, local-personal, remote-personal), syncs lazy.nvim plugins
- `vim/vimrc` sources `~/.local_vimrc` (set to either `maxmind_local_vimrc` or `vanilla_local_vimrc`)
- `bashrc` activates mise before the setup that probes for its tools (fzf, bat, eza, starship, zoxide) and sources `~/.local-bashrc` near the end
- `tmux/tmux.conf` uses TPM plugins (continuum, resurrect, sessionist)
- `uninstall.sh` reverts changes made by install.sh

## Bazzite/Immutable OS Notes

One deployment target is Bazzite (Fedora Atomic/immutable distro with KDE). Key differences:

### Package Management
- **DO NOT use `dnf install`** - the base system is read-only
- **System packages**: Use `rpm-ostree install <pkg>` (requires reboot to apply)
- **User-space tools**: Use mise (see Tool Management above); Homebrew only for what mise can't provide
- **Applications**: Prefer Flatpaks
- **Development environments**: Consider distrobox containers

### Wayland Considerations
- Bazzite with KDE uses Wayland by default
- `xcape` does not work on Wayland (bashrc checks `$XDG_SESSION_TYPE`)
- For Caps→Esc(tap)/Ctrl(hold) remap, use `keyd` (config in `keyd/`, written to `/etc/keyd` by `[bootstrap.files]` in `config.desktop.toml`; `install/keyd.sh` installs keyd itself). keyd is NOT in Fedora base repos — enable the `alternateved/keyd` COPR (`.repo` into `/etc/yum.repos.d/`) then `rpm-ostree install keyd` + reboot. `install/keyd.sh` prints the exact commands.
- Clipboard tools: use `wl-copy`/`wl-paste` instead of `xclip`

### Tiling on KDE/Wayland (personal desktop)
- i3-style tiling via Krohnkite (vendored + pinned in `kwin/`, installed by `install/kde-tiling.sh`)
- Borderless windows (i3 `default_border none`) via a forced `kwinrulesrc` rule; instant desktop switch by disabling the slide effect
- Keybindings are a clean personal port of `i3/config`, written to `kglobalshortcutsrc` via `kwriteconfig6` (KDE has no hand-editable rc); edits must be made with the kglobalaccel daemon quiescent, and a re-login activates them
- `install/kde-tiling.sh` runs only on local-personal (a hook in `config.local-personal.toml`) and still self-gates on `is_kde_wayland_personal` (`bash_functions.sh`): `~/.local-personal` + KDE + Wayland, since the personal laptop also has GNOME and i3 sessions
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
