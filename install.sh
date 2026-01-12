#!/usr/bin/env bash

set -eu -o pipefail

SELF_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

source "$SELF_PATH"/bash_functions.sh
source "$SELF_PATH"/bash_common.sh

# Parse arguments
FORCE_MODE=""
UPGRADE_BREW=""
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
    --upgrade)
      UPGRADE_BREW="yes"
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

# Use shared environment detection
envtype=$DOTFILES_ENVTYPE

# Bootstrap Homebrew if missing (desktop/laptop only)
if [[ $envtype == 'desktop' || $envtype == 'laptop' ]] && ! command -v brew &>/dev/null; then
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
    read -p "Run Homebrew installer? [y/N] " -n 1 -r
    echo
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

"$SELF_PATH"/install/vim.sh
"$SELF_PATH"/install/nvim.sh

# Prompt setup - git-prompt-fallback and starship config
cp "$SELF_PATH"/bin/git-prompt-fallback ~/bin/
chmod +x ~/bin/git-prompt-fallback
cp "$SELF_PATH"/bin/install-starship.sh ~/bin/
chmod +x ~/bin/install-starship.sh
mkdir -p ~/.config
ln -sf "$SELF_PATH"/starship.toml ~/.config/starship.toml

# Install starship on desktop/laptop if not already present (not on remote servers)
if [[ $envtype == 'desktop' || $envtype == 'laptop' ]] && ! command -v starship &>/dev/null; then
  echo "Installing starship prompt..."
  "$SELF_PATH"/bin/install-starship.sh ~/bin
fi

# Install modern CLI tools on desktop/laptop via Homebrew
BREW_TOOLS="ripgrep fd fzf jq bat eza git-delta zoxide lazygit golangci-lint shellcheck shfmt entr difftastic just glow ast-grep gh tldr dust tailspin lnav"
if [[ $envtype == 'desktop' || $envtype == 'laptop' ]] && command -v brew &>/dev/null; then
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

  # Check for available upgrades
  echo "Checking for brew upgrades..."
  BREW_OUTDATED=$(brew outdated --formula 2>/dev/null)
  TOOLS_OUTDATED=""
  for tool in $BREW_TOOLS; do
    if echo "$BREW_OUTDATED" | grep -q "^${tool}$"; then
      TOOLS_OUTDATED="$TOOLS_OUTDATED $tool"
    fi
  done
  if [[ -n "$TOOLS_OUTDATED" ]]; then
    if [[ -n "$UPGRADE_BREW" ]]; then
      echo "Upgrading:$TOOLS_OUTDATED"
      brew upgrade $TOOLS_OUTDATED 2>/dev/null || true
    else
      echo "Updates available:$TOOLS_OUTDATED"
      echo "  Run: brew upgrade$TOOLS_OUTDATED"
      echo "  Or:  ./install.sh --upgrade"
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

if [[ $envtype == 'laptop' ]]; then
  ln -sf "$SELF_PATH"/i3 ~/.config/i3
  ln -sf "$SELF_PATH"/i3status ~/.config/i3status
fi

if ! [ -d ~/.ssh/keys ]; then
  mkdir ~/.ssh/keys
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

# Run cleanup for updates only (interactive)
if [[ "$INSTALL_MODE" == "update" ]]; then
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
