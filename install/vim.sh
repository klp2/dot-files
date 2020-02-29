#!/usr/bin/env bash

set -eu -o pipefail

PREFIX=~/dot-files

source $PREFIX/bash_functions.sh

ln -sf $PREFIX/vim/vimrc ~/.vimrc
ln -sf $PREFIX/vim/vim_templates ~/.vim_templates

cp $PREFIX/vim/bin/vim_file_template ~/bin/

if [ $IS_MM = true ]
then
    ln -sf $PREFIX/vim/maxmind_local_vimrc ~/.local_vimrc
    cp $PREFIX/bin/mm-git-prompt ~/bin/git-prompt
else
    ln -sf $PREFIX/vim/vanilla_local_vimrc ~/.local_vimrc
    cp $PREFIX/bin/git-prompt ~/bin/
fi

curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

rm -rf ~/.vim/Trashed-Bundles ~/.vim/bundle

# The abolish plugin interferes with a fresh install
rm -f ~/.vim/after

rm -f ~/.vimrc
ln -sf $PREFIX/vim/vim-plug-vimrc ~/.vimrc
echo "About to install vim plugins"
vim +'PlugInstall --sync' +qa
echo "Done installing vim plugins"
rm ~/.vimrc

ln -sf $PREFIX/vim/vimrc ~/.vimrc
ln -sf $PREFIX/vim/vim-plug-vimrc ~/.vim/vim-plug-vimrc
ln -sf $LINK_FLAG $PREFIX/vim/after ~/.vim/after


exit 0
