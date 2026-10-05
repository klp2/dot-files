#!/usr/bin/env bash

set -eu -o pipefail

SELF_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

source "$SELF_PATH"/bash_functions.sh
source "$SELF_PATH"/bash_common.sh

# Parse arguments
FORCE_MODE=""
UPGRADE_BREW="yes"
AUTO_YES=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --fresh)
      FORCE_MODE="fresh"
      shift
      ;;
    --update)
      FORCE_MODE="update"
      shift
      ;;
    --no-upgrade)
      UPGRADE_BREW=""
      shift
      ;;
    --yes)
      AUTO_YES="yes"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Detect install mode or use forced mode
if [[ -n "$FORCE_MODE" ]]; then
  INSTALL_MODE="$FORCE_MODE"
elif [[ ! -L ~/.bashrc ]] || [[ "$(readlink -f ~/.bashrc 2>/dev/null)" != "$SELF_PATH/bashrc" ]]; then
  INSTALL_MODE="fresh"
else
  INSTALL_MODE="update"
fi

echo "=== Dotfiles $INSTALL_MODE ==="
echo ""

mkdir -p ~/.config
mkdir -p ~/.vimundo

if ! [ -d ~/bin ]; then
  mkdir ~/bin
fi

# Migrate old marker files to new naming scheme
if [[ -e "$HOME/.laptop" && ! -e "$HOME/.local-work" ]]; then
  echo "Migrating ~/.laptop → ~/.local-work"
  mv "$HOME/.laptop" "$HOME/.local-work"
fi
if [[ -e "$HOME/.desktop" && ! -e "$HOME/.local-personal" ]]; then
  echo "Migrating ~/.desktop → ~/.local-personal"
  mv "$HOME/.desktop" "$HOME/.local-personal"
fi

# Re-source after migration so detect_envtype sees new markers
source "$SELF_PATH"/bash_common.sh
envtype=$DOTFILES_ENVTYPE

# Create marker file if none exists
if [[ ! -e "$HOME/.devcontainer-work" && ! -e "$HOME/.local-work" && ! -e "$HOME/.local-personal" &&
  ! -e "$HOME/.remote-work" && ! -e "$HOME/.remote-personal" ]]; then
  echo ""
  echo "=== Environment Detection ==="
  echo "No marker file found (~/.local-work, ~/.local-personal, etc.)"
  echo "Running heuristic detection..."
  local_graphical="no"
  local_graphical_detail="${XDG_SESSION_TYPE:-tty}"
  if [[ "${XDG_SESSION_TYPE:-}" == "x11" || "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    local_graphical="yes"
  fi
  local_mm="no"
  local_hostname=$(detect_hostname)
  if is_maxmind; then
    local_mm="yes"
  fi
  echo "  Graphical session: $local_graphical  (XDG_SESSION_TYPE=$local_graphical_detail)"
  echo "  MaxMind hostname:  $local_mm  (hostname=$local_hostname)"
  echo "  Result: $envtype"
  touch "$HOME/.$envtype"
  echo "Creating ~/.$envtype"
  echo "To change, delete this file and create the correct one (e.g. ~/.remote-work)"
  echo ""
fi

# Bootstrap Homebrew if missing (not on remote-work)
if [[ $envtype == 'local-work' || $envtype == 'local-personal' || $envtype == 'remote-personal' || $envtype == 'devcontainer-work' ]] && ! command -v brew &>/dev/null; then
  echo ""
  echo "=== Homebrew Setup ==="
  echo "Homebrew not found. Downloading installer for review..."
  BREW_SCRIPT="/tmp/brew-install-$$.sh"
  if curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$BREW_SCRIPT"; then
    echo "Downloaded to: $BREW_SCRIPT"
    echo "Size: $(wc -c <"$BREW_SCRIPT") bytes, $(wc -l <"$BREW_SCRIPT") lines"
    echo "SHA256: $(sha256sum "$BREW_SCRIPT" | cut -d' ' -f1)"
    echo ""
    echo "Review with: less $BREW_SCRIPT"
    if [[ -n "$AUTO_YES" ]]; then
      REPLY="y"
    else
      read -p "Run Homebrew installer? [y/N] " -n 1 -r
      echo
    fi
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      bash "$BREW_SCRIPT"
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    else
      echo "Skipping Homebrew installation. Brew-dependent tools will not be installed."
    fi
    rm -f "$BREW_SCRIPT"
  else
    echo "Failed to download Homebrew installer."
  fi
fi

# Skip vim on remote-personal and devcontainer-work (neovim only)
if [[ $envtype != 'remote-personal' && $envtype != 'devcontainer-work' ]]; then
  "$SELF_PATH"/install/vim.sh
fi
"$SELF_PATH"/install/nvim.sh

# Local KDE/Wayland personal desktop extras (each self-gates; no-op elsewhere):
# keyd Caps remap, Zellij multiplexer, and Krohnkite i3-style tiling.
"$SELF_PATH"/install/keyd.sh
"$SELF_PATH"/install/1password.sh
UPGRADE="$UPGRADE_BREW" "$SELF_PATH"/install/libreoffice.sh
"$SELF_PATH"/install/zellij.sh
"$SELF_PATH"/install/kde-tiling.sh

# Prompt setup - git-prompt-fallback and starship config
cp "$SELF_PATH"/bin/git-prompt-fallback ~/bin/
chmod +x ~/bin/git-prompt-fallback
cp "$SELF_PATH"/bin/install-starship.sh ~/bin/
chmod +x ~/bin/install-starship.sh
mkdir -p ~/.config
ln -sf "$SELF_PATH"/starship.toml ~/.config/starship.toml

# Install starship if not already present (not on remote-work)
if [[ $envtype == 'local-work' || $envtype == 'local-personal' || $envtype == 'remote-personal' || $envtype == 'devcontainer-work' ]] && ! command -v starship &>/dev/null; then
  echo "Installing starship prompt..."
  "$SELF_PATH"/bin/install-starship.sh ~/bin
fi

# Install modern CLI tools via Homebrew (not on remote-work)
if [[ $envtype == 'devcontainer-work' ]]; then
  # Devcontainer provides via mise/apt: ripgrep fd jq bat git-delta gopls
  #   golangci-lint shellcheck shfmt gh mise
  # fzf is NOT taken from the devcontainer: bashrc needs >= 0.48 (see the check
  # at the end of this block) and distro packages are routinely older, so it is
  # listed here and comes from brew like everywhere else.
  BREW_TOOLS="fzf eza zoxide lazygit entr difftastic just glow ast-grep tlrc dust tailspin lnav sr tree-sitter-cli"
else
  BREW_TOOLS="ripgrep fd fzf jq bat eza git-delta zoxide lazygit golangci-lint shellcheck shfmt entr difftastic just glow ast-grep gh tlrc dust tailspin lnav mise gopls sr tree-sitter-cli"
fi
if [[ $envtype == 'local-work' || $envtype == 'local-personal' || $envtype == 'remote-personal' || $envtype == 'devcontainer-work' ]] && command -v brew &>/dev/null; then
  # Ensure personal tap is available
  brew tap klp2/sr 2>/dev/null || true

  # Refresh formula metadata before working out what to install or upgrade.
  echo "Updating brew..."
  brew update --quiet

  # tldr was abandoned upstream and Homebrew disabled the formula on 2025-10-24.
  # tlrc is the official Rust client and the documented replacement, but the two
  # conflict (both install a `tldr` binary), so the old one must go first. This
  # runs before the installed-packages snapshot below so tlrc is then seen as
  # missing and picked up by the normal install path.
  if brew list --formula tldr &>/dev/null; then
    echo "Migrating deprecated tldr -> tlrc..."
    brew uninstall --ignore-dependencies tldr || true
  fi

  # Get installed packages once (much faster than checking each individually)
  BREW_INSTALLED=$(brew list --formula 2>/dev/null)
  TOOLS_TO_INSTALL=""
  for tool in $BREW_TOOLS; do
    if ! echo "$BREW_INSTALLED" | grep -q "^${tool}$"; then
      TOOLS_TO_INSTALL="$TOOLS_TO_INSTALL $tool"
    fi
  done
  if [[ -n "$TOOLS_TO_INSTALL" ]]; then
    echo "Installing modern CLI tools:$TOOLS_TO_INSTALL"
    # `brew install a b c` aborts the whole batch if any single formula fails,
    # and errors were previously sent to /dev/null -- which is how shellcheck
    # and shfmt silently went missing here despite being listed for months.
    # Keep the fast batch path, but fall back to per-tool installs so one bad
    # formula cannot take the rest down, and say plainly what failed.
    # shellcheck disable=SC2086  # intentional word splitting
    if ! brew install $TOOLS_TO_INSTALL; then
      echo "Batch install failed; retrying tools individually..."
      BREW_FAILED=""
      for tool in $TOOLS_TO_INSTALL; do
        brew install "$tool" || BREW_FAILED="$BREW_FAILED $tool"
      done
      if [[ -n "$BREW_FAILED" ]]; then
        echo "WARNING: these brew tools failed to install:$BREW_FAILED"
        echo "WARNING: re-run ./install.sh or install them by hand."
      fi
    fi
  fi

  # Check for available upgrades
  echo "Checking for brew upgrades..."
  BREW_OUTDATED=$(brew outdated --formula 2>/dev/null)
  TOOLS_OUTDATED=""
  for tool in $BREW_TOOLS; do
    if echo "$BREW_OUTDATED" | grep -qE "(^|/)${tool}$"; then
      TOOLS_OUTDATED="$TOOLS_OUTDATED $tool"
    fi
  done
  if [[ -n "$TOOLS_OUTDATED" ]]; then
    if [[ -n "$UPGRADE_BREW" ]]; then
      echo "Upgrading:$TOOLS_OUTDATED"
      brew upgrade $TOOLS_OUTDATED 2>/dev/null || true
    else
      echo "Upgrades available but skipped (--no-upgrade):$TOOLS_OUTDATED"
    fi
  else
    echo "All brew tools up to date."
  fi

  # fzf rides the normal install/upgrade path above like every other tool, but
  # it is the one hard dependency of the interactive shell: bashrc runs
  # `eval "$(fzf --bash)"`, which needs >= 0.48, and it guards its whole fzf
  # section on `command -v fzf` -- so a missing or stale fzf degrades the shell
  # silently. Check explicitly instead of letting that happen.
  if command -v fzf &>/dev/null; then
    FZF_VER=$(fzf --version 2>/dev/null | awk '{print $1}')
    if ! printf '0.48.0\n%s\n' "$FZF_VER" | sort -V -C; then
      echo "WARNING: fzf $FZF_VER is older than 0.48; bashrc's 'fzf --bash' needs >= 0.48."
      echo "WARNING: an old distro fzf may be shadowing the brew one on PATH."
    fi
  else
    echo "WARNING: fzf is not installed; bashrc will skip its fzf integration entirely."
  fi
fi

# Tool configs (bat, ripgrep, lnav)
mkdir -p ~/.config/bat
mkdir -p ~/.config/ripgrep
mkdir -p ~/.config/lnav
ln -sf "$SELF_PATH"/config/bat/config ~/.config/bat/config
ln -sf "$SELF_PATH"/config/ripgrep/config ~/.config/ripgrep/config
ln -sf "$SELF_PATH"/config/lnav/config.json ~/.config/lnav/config.json

# Mise global config (environment-specific)
mkdir -p ~/.config/mise
if [[ $envtype == 'devcontainer-work' ]]; then
  # Use conf.d so personal config coexists with Dockerfile's default config.toml
  mkdir -p ~/.config/mise/conf.d
  ln -sf "$SELF_PATH"/config/mise/mise.work.toml ~/.config/mise/conf.d/50-personal.toml
  # Clean up old symlink from previous installs (preserve Dockerfile's regular file)
  if [ -L ~/.config/mise/config.toml ]; then
    rm ~/.config/mise/config.toml
  fi
elif [[ $envtype == 'local-work' ]]; then
  ln -sf "$SELF_PATH"/config/mise/mise.work.toml ~/.config/mise/config.toml
elif [[ $envtype == 'local-personal' || $envtype == 'remote-personal' ]]; then
  ln -sf "$SELF_PATH"/config/mise/mise.personal.toml ~/.config/mise/config.toml
fi
if command -v mise &>/dev/null; then
  echo "Installing mise tools..."
  MISE_LOCKED=0 mise install --quiet
  # The lockfile pins "latest" tools (e.g. npm:linearis) to whatever resolved
  # at first install, so `mise install` alone never moves them forward.
  if [[ -n "$UPGRADE_BREW" ]]; then
    echo "Upgrading mise tools..."
    MISE_LOCKED=0 mise upgrade --quiet
  fi
  MISE_LOCKED=0 mise lock --global --quiet
fi

# Alacritty terminal config (only if alacritty is installed)
if command -v alacritty &>/dev/null; then
  mkdir -p ~/.config/alacritty
  ln -sf "$SELF_PATH"/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml
fi

ln -sf "$SELF_PATH"/ackrc ~/.ackrc
cp "$SELF_PATH"/golangci.yml ~/.golangci.yml

ln -sf "$SELF_PATH"/bashrc ~/.bashrc
ln -sf "$SELF_PATH"/bash_profile ~/.bash_profile
ln -sf "$SELF_PATH"/bash_common.sh ~/.bash_common.sh

cp "$SELF_PATH"/dataprinter ~/.dataprinter
chmod 700 ~/.dataprinter

ln -sf "$SELF_PATH"/perlcriticrc ~/.perlcriticrc
ln -sf "$SELF_PATH"/perltidyrc ~/.perltidyrc
ln -sf "$SELF_PATH"/profile ~/.profile
ln -sf "$SELF_PATH"/screenrc ~/.screenrc
ln -sf "$SELF_PATH"/tmux/tmux.conf ~/.tmux.conf
ln -sf "$SELF_PATH"/tmux/tmux-default-layout ~/.tmux-default-layout
ln -sf "$SELF_PATH"/tmux/tmux-three-win-layout ~/.tmux-three-win-layout
ln -sf "$SELF_PATH"/psql/psqlrc ~/.psqlrc

# i3 configs: always on the work laptop (Regolith), and on a personal box only
# when i3 is actually installed. has_i3 rather than a session check, because the
# personal laptop may be installed from its GNOME session but still needs these
# in place for the next i3 login; the check keeps ~/.config/i3 off the KDE box.
if [[ $envtype == 'local-work' ]] || { [[ $envtype == 'local-personal' ]] && has_i3; }; then
  ln -sfn "$SELF_PATH"/i3 ~/.config/i3
  ln -sfn "$SELF_PATH"/i3status ~/.config/i3status
fi

if [[ $envtype == 'local-work' ]]; then
  # Devcontainer local customizations (symlink so deploy dereferences)
  mkdir -p ~/.config/devcontainer-local
  ln -sf "$SELF_PATH"/devcontainer/startup.sh ~/.config/devcontainer-local/startup.sh
fi

# Regolith 3: tracked Xresources and i3status-rust config.
# Machine-specific overrides (wallpaper, look theme) go in the un-tracked
# ~/.config/regolith3/Xresources.d/local, included via cpp by the main file.
if [[ ($envtype == 'local-work' || $envtype == 'local-personal') && -d /etc/regolith ]]; then
  mkdir -p ~/.config/regolith3/i3status-rust ~/.config/regolith3/Xresources.d
  ln -sf "$SELF_PATH"/regolith3/Xresources ~/.config/regolith3/Xresources
  ln -sf "$SELF_PATH"/regolith3/i3status-rust/config.toml ~/.config/regolith3/i3status-rust/config.toml
  if [[ ! -e ~/.config/regolith3/Xresources.d/local ]]; then
    cat >~/.config/regolith3/Xresources.d/local <<'EOF'
! Machine-specific Regolith 3 overrides — not tracked in dotfiles.
! Examples:
!   regolith.wallpaper.file: /path/to/wallpaper.webp
!   regolith.lockscreen.wallpaper.file: /path/to/wallpaper.webp
!   regolith.look.path: /usr/share/regolith-look/dracula
EOF
  fi
fi

if ! [ -d ~/.ssh/keys ]; then
  mkdir -p ~/.ssh/keys
fi

# SSH: manage a fragment, never the whole config. ~/.ssh/config holds
# machine-specific host entries and absolute key paths, and both Trellis and the
# 1Password app rewrite it unprompted -- symlinking it would drop their edits
# into this git tree. Only local desktops get the 1Password agent.
if is_local_desktop; then
  mkdir -p ~/.ssh/config.d
  chmod 700 ~/.ssh ~/.ssh/config.d
  ln -sf "$SELF_PATH"/ssh/1password.conf ~/.ssh/config.d/1password.conf
  touch ~/.ssh/config
  chmod 600 ~/.ssh/config
  SSH_INCLUDE='Include ~/.ssh/config.d/*.conf'
  if ! grep -qF "$SSH_INCLUDE" ~/.ssh/config; then
    # Must precede every Host block: ssh scopes a bare Include to whichever Host
    # section encloses it, so appending would bind the fragment to the last host.
    echo "Adding '$SSH_INCLUDE' to ~/.ssh/config"
    printf '%s\n\n' "$SSH_INCLUDE" | cat - ~/.ssh/config >~/.ssh/config.dotfiles-tmp
    mv ~/.ssh/config.dotfiles-tmp ~/.ssh/config
    chmod 600 ~/.ssh/config
  fi
fi

git submodule init
git submodule update

./git-config.sh

# Install git hooks for this repo
ln -sf ../../hooks/pre-commit .git/hooks/pre-commit
ln -sf ../../hooks/pre-push .git/hooks/pre-push

LOCALCHECKOUT=~/.tmux/plugins/tpm
if [ ! -d $LOCALCHECKOUT ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
  pushd $LOCALCHECKOUT
  git pull origin master
  popd
fi

# Run cleanup for updates only (interactive, skip with --yes)
if [[ "$INSTALL_MODE" == "update" && -z "$AUTO_YES" ]]; then
  echo ""
  echo "=== Checking for deprecated tools ==="
  "$SELF_PATH"/cleanup.sh
fi

# Warn about machine-local path pins in ~/.local-bashrc that no longer
# resolve — e.g. LOCAL_REVIEW_LLAMA pinning a versioned llama.cpp build dir,
# or a model snapshot path, after an upgrade replaced it. Checks every
# exported variable whose value is an absolute path.
if [ -f "$HOME/.local-bashrc" ]; then
  while IFS= read -r pinvar; do
    pinval="$(bash -c ". \"\$HOME/.local-bashrc\" >/dev/null 2>&1; printf '%s' \"\${$pinvar-}\"")"
    case "$pinval" in
      /*)
        if [ ! -e "$pinval" ]; then
          echo "WARNING: ~/.local-bashrc pins $pinvar=$pinval, which does not exist — update the pin"
        fi
        ;;
    esac
  done < <(grep -oE '^export [A-Za-z_][A-Za-z0-9_]*' "$HOME/.local-bashrc" | cut -d' ' -f2)
fi

# Show post-install message
echo ""
if [[ "$INSTALL_MODE" == "fresh" ]]; then
  echo "=== Fresh install complete ==="
  echo "Run 'source ~/.bashrc' to load your new shell config"
  echo "Run './cleanup.sh' later to remove any old tools"
else
  echo "=== Update complete ==="
fi

# Record timestamp for weekly reminder system
date +%s >"$HOME/.dotfiles-last-update"
