#!/usr/bin/env bash
# Interactive cleanup of deprecated tools and configs
# Run periodically to remove things no longer used

set -eu -o pipefail

echo "Checking for deprecated tools and configs..."
echo ""

# Helper function for interactive removal
ask_remove() {
  local name="$1"
  local path="$2"
  local description="$3"

  if [[ -e "$path" ]]; then
    echo "Found: $name"
    echo "  Path: $path"
    echo "  Note: $description"
    read -p "  Remove? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "$path"
      echo "  Removed."
    else
      echo "  Kept."
    fi
    echo ""
  fi
}

# Deprecated tools
ask_remove "Facebook PathPicker (fpp)" \
  "$HOME/local/src/PathPicker" \
  "Superseded by fzf, telescope, lazygit"

ask_remove "fpp symlink" \
  "$HOME/local/bin/fpp" \
  "Symlink to PathPicker"

ask_remove "Old Perl git-prompt" \
  "$HOME/bin/git-prompt" \
  "Replaced by starship + git-prompt-fallback"

ask_remove "Old mm-git-prompt" \
  "$HOME/bin/mm-git-prompt" \
  "Replaced by starship + git-prompt-fallback"

# Old vim plugin managers (if vim-plug is now standard)
ask_remove "Vundle" \
  "$HOME/.vim/bundle/Vundle.vim" \
  "Replaced by vim-plug"

ask_remove "Old vim bundles" \
  "$HOME/.vim/bundle" \
  "vim-plug uses different directory"

# Deprecated configs
ask_remove "Old packer.nvim" \
  "$HOME/.local/share/nvim/site/pack/packer" \
  "Replaced by lazy.nvim"

echo "Cleanup complete."
