#!/usr/bin/env bash

set -eu -o pipefail

PREFIX=~/dot-files

source "$PREFIX/bash_common.sh"

# Install/update neovim via Homebrew (not on remote-work or devcontainer-work where mise provides it)
if [[ $DOTFILES_ENVTYPE == 'local-work' || $DOTFILES_ENVTYPE == 'local-personal' || $DOTFILES_ENVTYPE == 'remote-personal' ]] && command -v brew &>/dev/null; then
  if brew list --formula neovim &>/dev/null && ! command -v nvim &>/dev/null; then
    # Installed but not linked: what an interrupted upgrade leaves behind
    echo "Relinking neovim..."
    brew link neovim || echo "WARNING: could not relink neovim; run 'brew link neovim'."
  elif ! command -v nvim &>/dev/null; then
    echo "Installing neovim (nightly)..."
    brew install neovim --HEAD
  elif brew list neovim --versions 2>/dev/null | grep -q HEAD; then
    echo "Checking for neovim nightly updates..."
    brew upgrade neovim --fetch-HEAD || echo "WARNING: neovim nightly upgrade failed (see above)."
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

exit 0
