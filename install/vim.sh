#!/usr/bin/env bash

set -eu -o pipefail

PREFIX=~/dot-files

source $PREFIX/bash_functions.sh

ln -sf $PREFIX/vim/vimrc ~/.vimrc

if [ $IS_MM = true ]; then
  ln -sf $PREFIX/vim/maxmind_local_vimrc ~/.local_vimrc
else
  ln -sf $PREFIX/vim/vanilla_local_vimrc ~/.local_vimrc
fi
# Note: git-prompt-fallback is now copied by install.sh (starship is primary)

curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

rm -rf ~/.vim/Trashed-Bundles ~/.vim/bundle

mkdir -p ~/.vim/after/syntax/perl/
cp $PREFIX/vim/heredoc-sql.vim ~/.vim/after/syntax/perl/

rm -f ~/.vimrc
ln -sf $PREFIX/vim/vim-plug-vimrc ~/.vimrc
vim +'PlugInstall --sync' +qa
rm ~/.vimrc

ln -sf $PREFIX/vim/vimrc ~/.vimrc
ln -sf $PREFIX/vim/vim-plug-vimrc ~/.vim/vim-plug-vimrc

exit 0
