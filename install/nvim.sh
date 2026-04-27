#!/usr/bin/env bash

set -eu -o pipefail

PREFIX=~/dot-files

source "$PREFIX/bash_common.sh"

# Install/update neovim via Homebrew (not on remote-work or devcontainer-work where mise provides it)
if [[ $DOTFILES_ENVTYPE == 'local-work' || $DOTFILES_ENVTYPE == 'local-personal' || $DOTFILES_ENVTYPE == 'remote-personal' ]] && command -v brew &>/dev/null; then
  if ! command -v nvim &>/dev/null; then
    echo "Installing neovim (nightly)..."
    brew install neovim --HEAD
  else
    # Check if it's a HEAD install and offer upgrade
    if brew list neovim --versions 2>/dev/null | grep -q HEAD; then
      echo "Checking for neovim nightly updates..."
      brew upgrade neovim --fetch-HEAD 2>/dev/null || true
    fi
  fi
fi

# Link neovim config
mkdir -p ~/.config/nvim
ln -sf "$PREFIX/nvim/init.lua" ~/.config/nvim/init.lua

# Run Lazy sync if nvim is available (install/update plugins)
if command -v nvim &>/dev/null; then
  echo "Syncing neovim plugins..."
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
fi

# Build tree-sitter parsers (replaces the archived nvim-treesitter plugin).
# Default mode: build pinned SHAs from nvim/parsers.lock — reproducible, no
# silent upgrades. Run `./install/nvim-parsers.sh --update` to refresh pins.
if command -v nvim &>/dev/null && command -v cc &>/dev/null; then
  "$PREFIX/install/nvim-parsers.sh"
fi

exit 0
