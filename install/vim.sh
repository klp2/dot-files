#!/usr/bin/env bash
# vim-plug and vim plugins. A final hook in config/mise/config.desktop.toml and
# config.remote-work.toml; ~/.vimrc and heredoc-sql.vim are base.toml links.

set -eu -o pipefail

PREFIX=~/dot-files

source "$PREFIX/bash_functions.sh"

# Link local vimrc based on whether mm-perl is installed
if [ "$IS_MM" = true ]; then
  ln -sf "$PREFIX/vim/maxmind_local_vimrc" ~/.local_vimrc
else
  ln -sf "$PREFIX/vim/vanilla_local_vimrc" ~/.local_vimrc
fi

# Install vim-plug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Clean up old bundle directories (from pathogen days)
rm -rf ~/.vim/Trashed-Bundles ~/.vim/bundle

# Install plugins (vimrc contains the plugin list)
vim +'PlugInstall --sync' +qa

# Install vim-go binaries (gopls, goimports, etc.) if go is available
if command -v go &>/dev/null; then
  echo "Installing vim-go binaries..."
  vim +'GoInstallBinaries' +qa 2>/dev/null || true
fi

exit 0
