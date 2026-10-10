#!/usr/bin/env bash

set -eu -o pipefail

SELF_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

source "$SELF_PATH"/bash_functions.sh
source "$SELF_PATH"/bash_common.sh

# Parse arguments
FORCE_MODE=""
UPGRADE="yes"
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
      UPGRADE=""
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
# install/libreoffice.sh reads it too
export UPGRADE

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

# Download an installer script, show its size and hash, and run it only once
# confirmed (or with --yes). Fails if the download fails or the user declines.
run_reviewed_installer() {
  local name="$1" url="$2" script rc
  script=$(mktemp "/tmp/$name-install.XXXXXX")
  if ! curl -fsSL "$url" -o "$script"; then
    echo "Failed to download the $name installer."
    rm -f "$script"
    return 1
  fi
  echo "Downloaded to: $script"
  echo "Size: $(wc -c <"$script") bytes, $(wc -l <"$script") lines"
  echo "SHA256: $(sha256sum "$script" | cut -d' ' -f1)"
  echo ""
  echo "Review with: less $script"
  if [[ -z "$AUTO_YES" ]]; then
    read -p "Run $name installer? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Skipping $name installation."
      rm -f "$script"
      return 1
    fi
  fi
  rc=0
  bash "$script" || rc=$?
  rm -f "$script"
  return $rc
}

# mise: CLI tools and runtimes (not on remote-work, which stays minimal)
if [[ $envtype != 'remote-work' ]]; then
  # Use the standalone mise in ~/.local/bin, which self-updates without brew,
  # unless a non-brew mise is already provided (e.g. the devcontainer image).
  brew_mise=""
  if command -v brew &>/dev/null && brew list --formula mise &>/dev/null; then
    brew_mise="yes"
  fi
  if [[ ! -x ~/.local/bin/mise ]] && { [[ -n "$brew_mise" ]] || ! command -v mise &>/dev/null; }; then
    echo ""
    echo "=== mise Setup ==="
    run_reviewed_installer mise https://mise.run || true
  fi
  export PATH="$HOME/.local/bin:$PATH"
  if [[ -n "$brew_mise" && -x ~/.local/bin/mise ]]; then
    echo "Removing Homebrew's mise (replaced by ~/.local/bin/mise)..."
    brew uninstall mise || echo "WARNING: could not uninstall Homebrew's mise; ~/.local/bin/mise still takes precedence."
  fi

  # common.toml goes in conf.d so the per-environment config.toml wins on overlap
  mkdir -p ~/.config/mise/conf.d
  ln -sf "$SELF_PATH"/config/mise/common.toml ~/.config/mise/conf.d/10-dotfiles.toml
  if [[ $envtype == 'devcontainer-work' ]]; then
    # Also conf.d, so it coexists with the Dockerfile's default config.toml
    ln -sf "$SELF_PATH"/config/mise/mise.work.toml ~/.config/mise/conf.d/50-personal.toml
    # Clean up old symlink from previous installs (preserve Dockerfile's regular file)
    if [ -L ~/.config/mise/config.toml ]; then
      rm ~/.config/mise/config.toml
    fi
  elif [[ $envtype == 'local-work' ]]; then
    ln -sf "$SELF_PATH"/config/mise/mise.work.toml ~/.config/mise/config.toml
  else
    ln -sf "$SELF_PATH"/config/mise/mise.personal.toml ~/.config/mise/config.toml
  fi

  if command -v mise &>/dev/null; then
    if [[ -n "$UPGRADE" && -x ~/.local/bin/mise ]]; then
      mise self-update --yes || true
    fi
    # A tool that fails to install is reported, not fatal: mise still installs
    # the rest, and the next run retries it.
    echo "Installing mise tools..."
    MISE_LOCKED=0 mise install --quiet || echo "WARNING: some mise tools failed to install (see above)."
    # The lockfile pins "latest" tools to whatever resolved at first install,
    # so `mise install` alone never moves them forward.
    if [[ -n "$UPGRADE" ]]; then
      echo "Upgrading mise tools..."
      MISE_LOCKED=0 mise upgrade --quiet || echo "WARNING: some mise tools failed to upgrade (see above)."
    fi
    MISE_LOCKED=0 mise lock --global --quiet
    # Locking records npm tools against a lock artifact, and mise reports them
    # missing until they are reinstalled from it
    MISE_LOCKED=0 mise install --quiet || echo "WARNING: some mise tools failed to install (see above)."
    # Shims are symlinks to the mise binary, so repoint them if it moved
    mise reshim
    export PATH="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$PATH"

    # Bash completions, loaded on demand by bash-completion (see bashrc)
    comp_dir="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
    mkdir -p "$comp_dir"
    while read -r cmd gen; do
      command -v "$cmd" &>/dev/null || continue
      # shellcheck disable=SC2086  # $gen is a command line, split on purpose
      if $gen >"$comp_dir/$cmd.tmp" 2>/dev/null; then
        mv "$comp_dir/$cmd.tmp" "$comp_dir/$cmd"
      else
        rm -f "$comp_dir/$cmd.tmp"
      fi
    done <<'EOF'
ast-grep ast-grep completions bash
bat bat --completion bash
delta delta --generate-completion bash
fd fd --gen-completions bash
gh gh completion -s bash
glow glow completion bash
golangci-lint golangci-lint completion bash
goreleaser goreleaser completion bash
just just --completions bash
mise mise completion bash
rg rg --generate complete-bash
sqlc sqlc completion bash
starship starship completions bash
zellij zellij setup --generate-completion bash
EOF
  fi
fi

# Homebrew covers only what mise can't: neovim nightly (install/nvim.sh) and
# entr, which publishes no release binaries.
if [[ $envtype == 'local-work' || $envtype == 'local-personal' || $envtype == 'remote-personal' ]]; then
  if ! command -v brew &>/dev/null; then
    echo ""
    echo "=== Homebrew Setup ==="
    if run_reviewed_installer Homebrew https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
  fi
  if command -v brew &>/dev/null; then
    if ! brew list --formula entr &>/dev/null; then
      brew install entr
    elif [[ -n "$UPGRADE" ]]; then
      brew upgrade entr || true
    fi
  fi
fi

# Skip vim on remote-personal and devcontainer-work (neovim only)
if [[ $envtype != 'remote-personal' && $envtype != 'devcontainer-work' ]]; then
  "$SELF_PATH"/install/vim.sh
fi
"$SELF_PATH"/install/nvim.sh

# Local KDE/Wayland personal desktop extras (each self-gates; no-op elsewhere):
# keyd Caps remap, 1Password, LibreOffice, and Krohnkite i3-style tiling.
"$SELF_PATH"/install/keyd.sh
"$SELF_PATH"/install/1password.sh
"$SELF_PATH"/install/libreoffice.sh
"$SELF_PATH"/install/kde-tiling.sh

# Prompt setup - git-prompt-fallback and starship config
cp "$SELF_PATH"/bin/git-prompt-fallback ~/bin/
chmod +x ~/bin/git-prompt-fallback
mkdir -p ~/.config
ln -sf "$SELF_PATH"/starship.toml ~/.config/starship.toml

# Tool configs (bat, ripgrep, lnav)
mkdir -p ~/.config/bat
mkdir -p ~/.config/ripgrep
mkdir -p ~/.config/lnav
ln -sf "$SELF_PATH"/config/bat/config ~/.config/bat/config
ln -sf "$SELF_PATH"/config/ripgrep/config ~/.config/ripgrep/config
ln -sf "$SELF_PATH"/config/lnav/config.json ~/.config/lnav/config.json

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
