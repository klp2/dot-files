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
  # Devcontainer provides via mise/apt: ripgrep fd fzf jq bat git-delta gopls
  #   golangci-lint shellcheck shfmt gh mise
  BREW_TOOLS="eza zoxide lazygit entr difftastic just glow ast-grep tldr dust tailspin lnav sr"
else
  BREW_TOOLS="ripgrep fd fzf jq bat eza git-delta zoxide lazygit golangci-lint shellcheck shfmt entr difftastic just glow ast-grep gh tldr dust tailspin lnav mise gopls sr"
fi
if [[ $envtype == 'local-work' || $envtype == 'local-personal' || $envtype == 'remote-personal' || $envtype == 'devcontainer-work' ]] && command -v brew &>/dev/null; then
  # Ensure personal tap is available
  brew tap klp2/sr 2>/dev/null || true

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
    brew install $TOOLS_TO_INSTALL 2>/dev/null || true
  fi

  # Update brew to discover new versions (especially from taps)
  echo "Updating brew..."
  brew update --quiet 2>/dev/null || true

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
fi

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

if [[ $envtype == 'local-work' ]]; then
  ln -sfn "$SELF_PATH"/i3 ~/.config/i3
  ln -sfn "$SELF_PATH"/i3status ~/.config/i3status

  # Devcontainer local customizations (symlink so deploy dereferences)
  mkdir -p ~/.config/devcontainer-local
  ln -sf "$SELF_PATH"/devcontainer/startup.sh ~/.config/devcontainer-local/startup.sh
fi

if ! [ -d ~/.ssh/keys ]; then
  mkdir -p ~/.ssh/keys
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
