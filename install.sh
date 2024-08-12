#!/usr/bin/env bash

set -eu -o pipefail

SELF_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

source $SELF_PATH/bash_functions.sh

mkdir -p ~/.config
mkdir -p ~/.vimundo

if ! [ -d ~/bin ]
then
    mkdir ~/bin
fi

envtype='remote'

if [[ -e "$HOME/.laptop" ]]; then
    envtype='laptop'
fi


$SELF_PATH/install/vim.sh
$SELF_PATH/install/nvim.sh

ln -sf $SELF_PATH/ackrc ~/.ackrc

ln -sf $SELF_PATH/bashrc ~/.bashrc
ln -sf $SELF_PATH/bash_profile ~/.bash_profile

cp     $SELF_PATH/dataprinter ~/.dataprinter
chmod 700 ~/.dataprinter

ln -sf $SELF_PATH/perlcriticrc ~/.perlcriticrc
ln -sf $SELF_PATH/perltidyrc ~/.perltidyrc
ln -sf $SELF_PATH/profile ~/.profile
ln -sf $SELF_PATH/screenrc ~/.screenrc
ln -sf $SELF_PATH/tmux/tmux.conf ~/.tmux.conf
ln -sf $SELF_PATH/tmux/tmux-osx.conf ~/.tmux-osx.conf
ln -sf $SELF_PATH/tmux/tmux-default-layout ~/.tmux-default-layout
ln -sf $SELF_PATH/tmux/tmux-three-win-layout ~/.tmux-three-win-layout
ln -sf $SELF_PATH/psql/psqlrc ~/.psqlrc

if [[ $envtype == 'laptop' ]]; then
    ln -sf $SELF_PATH/i3 ~/.config/i3
    ln -sf $SELF_PATH/i3status ~/.config/i3status
fi

if ! [ -d ~/.ssh/keys ]
then
    mkdir ~/.ssh/keys
fi

git submodule init
git submodule update

./git-config.sh

bash ./install-fpp.sh

LOCALCHECKOUT=~/.tmux/plugins/tpm
if [ ! -d $LOCALCHECKOUT ]
then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
    pushd $LOCALCHECKOUT
    git pull origin master
    popd
fi

#PACKER_LOCAL_REPO=~/.local/share/nvim/site/pack/packer/start/packer.nvim
#git -C $PACKER_LOCAL_REPO pull || git clone --depth 1 https://github.com/wbthomason/packer.nvim $PACKER_LOCAL_REPO
#git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim

# git extras
echo "installing git-extras"

cd inc/git-extras
make install PREFIX="$HOME/local"
