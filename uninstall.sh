#!/usr/bin/env bash

# Uninstall script to revert changes made by install.sh
# Run with --dry-run to see what would be removed without actually removing

set -eu -o pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "=== DRY RUN MODE - No changes will be made ==="
  echo
fi

remove_if_exists() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "[would remove] $target"
    else
      rm -rf "$target"
      echo "[removed] $target"
    fi
  fi
}

remove_symlink_if_points_to_dotfiles() {
  local target="$1"
  if [[ -L "$target" ]]; then
    local link_target
    link_target=$(readlink "$target")
    if [[ "$link_target" == *"dot-files"* ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        echo "[would remove symlink] $target -> $link_target"
      else
        rm "$target"
        echo "[removed symlink] $target"
      fi
    else
      echo "[skipping] $target (points to $link_target, not dot-files)"
    fi
  fi
}

echo "=== Removing links and copies that mise deployed ==="
# Everything in base.toml's [dotfiles] and the files it links in, including the
# ~/.dataprinter copy and the SSH Include line. Runs while that config is still
# in place, since mise reads it to find its targets. --force because mise
# refuses to remove a line edit (it carries no ownership marker) or a copy
# changed since it was deployed.
if command -v mise &>/dev/null; then
  if [[ "$DRY_RUN" == true ]]; then
    mise dotfiles unapply --force --dry-run
  else
    mise dotfiles unapply --force || echo "WARNING: mise could not remove every deployed file (see above)."
  fi
else
  echo "WARNING: mise not found; the links in config/mise/base.toml stay in place."
fi

echo
echo "=== Removing links made by the installers ==="
remove_symlink_if_points_to_dotfiles ~/.local_vimrc
remove_symlink_if_points_to_dotfiles ~/.config/i3
remove_symlink_if_points_to_dotfiles ~/.config/i3status
remove_symlink_if_points_to_dotfiles ~/.config/alacritty/alacritty.toml
remove_symlink_if_points_to_dotfiles ~/.config/regolith3/Xresources
remove_symlink_if_points_to_dotfiles ~/.config/regolith3/i3status-rust/config.toml

echo
echo "=== Removing mise config ==="
for f in ~/.config/mise/conf.d/*.toml ~/.config/mise/config.*.toml; do
  remove_symlink_if_points_to_dotfiles "$f"
done
remove_if_exists ~/.config/mise/miserc.toml

echo
echo "=== Removing copied files ==="
remove_if_exists ~/bin/vim_file_template
remove_if_exists ~/bin/git-prompt

echo
echo "=== The following require manual confirmation ==="
echo

# These are more destructive, ask before removing
confirm_remove() {
  local target="$1"
  local description="$2"

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    return
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo "[would ask to remove] $target ($description)"
    return
  fi

  read -p "Remove $target ($description)? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$target"
    echo "[removed] $target"
  else
    echo "[kept] $target"
  fi
}

confirm_remove ~/.vim/plugged "vim plugins installed by vim-plug"
confirm_remove ~/.vim/autoload/plug.vim "vim-plug itself"
confirm_remove ~/.local/share/nvim "neovim data and lazy.nvim plugins"
confirm_remove ~/.tmux/plugins "tmux plugins installed by tpm"
confirm_remove ~/local/src/PathPicker "Facebook PathPicker source"
confirm_remove ~/local/bin/fpp "Facebook PathPicker symlink"

echo
echo "=== Done ==="
echo
echo "Note: Git global config changes from git-config.sh are NOT reverted."
echo "To clear git config, run: git config --global --unset-all <key>"
echo
echo "Directories that may be empty and can be manually removed:"
echo "  ~/.vim/after/syntax/perl/"
echo "  ~/.config/nvim/lua/"
echo "  ~/bin/ (if you don't use it for other things)"
