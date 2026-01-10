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

echo "=== Removing shell config symlinks ==="
remove_symlink_if_points_to_dotfiles ~/.bashrc
remove_symlink_if_points_to_dotfiles ~/.bash_profile
remove_symlink_if_points_to_dotfiles ~/.profile
remove_symlink_if_points_to_dotfiles ~/.ackrc

echo
echo "=== Removing Perl config symlinks ==="
remove_symlink_if_points_to_dotfiles ~/.perlcriticrc
remove_symlink_if_points_to_dotfiles ~/.perltidyrc

echo
echo "=== Removing vim/neovim config ==="
remove_symlink_if_points_to_dotfiles ~/.vimrc
remove_symlink_if_points_to_dotfiles ~/.vim_templates
remove_symlink_if_points_to_dotfiles ~/.local_vimrc
remove_symlink_if_points_to_dotfiles ~/.vim/vim-plug-vimrc
remove_symlink_if_points_to_dotfiles ~/.config/nvim/init.lua
remove_symlink_if_points_to_dotfiles ~/.config/nvim/lua/plugins.lua

echo
echo "=== Removing tmux config symlinks ==="
remove_symlink_if_points_to_dotfiles ~/.tmux.conf
remove_symlink_if_points_to_dotfiles ~/.tmux-osx.conf
remove_symlink_if_points_to_dotfiles ~/.tmux-default-layout
remove_symlink_if_points_to_dotfiles ~/.tmux-three-win-layout

echo
echo "=== Removing other config symlinks ==="
remove_symlink_if_points_to_dotfiles ~/.screenrc
remove_symlink_if_points_to_dotfiles ~/.psqlrc
remove_symlink_if_points_to_dotfiles ~/.config/i3
remove_symlink_if_points_to_dotfiles ~/.config/i3status

echo
echo "=== Removing copied files ==="
remove_if_exists ~/.dataprinter
remove_if_exists ~/bin/vim_file_template
remove_if_exists ~/bin/git-prompt
remove_if_exists ~/.vim/after/syntax/perl/heredoc-sql.vim

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
