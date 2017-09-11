#!/usr/bin/env bash

set -eu -o pipefail
SELF_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

echo $SELF_PATH

ln -sf $SELF_PATH/bashrc ~/.bashrc
ln -sf $SELF_PATH/bash_profile ~/.bash_profile

ln -sf $SELF_PATH/perltidyrc ~/.perltidyrc
ln -sf $SELF_PATH/profile ~/.profile
ln -sf $SELF_PATH/screenrc ~/.screenrc
ln -sf $SELF_PATH/tmux/tmux.conf ~/.tmux.conf
ln -sf $SELF_PATH/tmux/tmux-osx.conf ~/.tmux-osx.conf
ln -sf $SELF_PATH/tmux/tmux-default-layout ~/.tmux-default-layout
ln -sf $SELF_PATH/tmux/tmux-three-win-layout ~/.tmux-three-win-layout
ln -sf $SELF_PATH/vim/vimrc ~/.vimrc
ln -sf $SELF_PATH/vim/vim_templates ~/.vim_templates

if ! [ -d ~/bin ]
then
    mkdir ~/bin
fi
cp $SELF_PATH/vim/bin/vim_file_template ~/bin/
cp $SELF_PATH/bin/git-prompt ~/bin/

if ! [ -f ~/.ssh/keys ]
then
    mkdir ~/.ssh/keys
fi

if [ -f /usr/local/bin/mm-perl ]
then
    ln -sf $SELF_PATH/vim/maxmind_local_vimrc ~/.local_vimrc
else
    ln -sf $SELF_PATH/vim/vanilla_local_vimrc ~/.local_vimrc
fi

git submodule init
git submodule update

$SELF_PATH/inc/vim-update-bundles/vim-update-bundles

./git-config.sh

go get github.com/github/hub

# silence warnings when perlbrew not installed
mkdir -p $HOME/perl5/perlbrew/etc
touch $HOME/perl5/perlbrew/etc/bashrc

LOCALCHECKOUT=~/.tmux/plugins/tpm
if [ ! -d $LOCALCHECKOUT ]
then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
    pushd $LOCALCHECKOUT
    git pull origin master
    popd
fi

# git extras
echo "installing git-extras"

cd inc/git-extras
make install PREFIX="$HOME/local"
