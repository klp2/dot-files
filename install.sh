#!/usr/bin/env bash

set -eu -o pipefail

SELF_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

source ~/dot-files/bash_functions.sh

echo $SELF_PATH

mkdir -p ~/.re.pl
mkdir -p ~/.config
mkdir -p ~/.vimundo

if ! [ -d ~/bin ]
then
    mkdir ~/bin
fi

$SELF_PATH/install/vim.sh

ln -sf $SELF_PATH/ackrc ~/.ackrc

ln -sf $SELF_PATH/bashrc ~/.bashrc
ln -sf $SELF_PATH/bash_profile ~/.bash_profile

cp     $SELF_PATH/dataprinter ~/.dataprinter
chmod 700 ~/.dataprinter

ln -sf $LINK_FLAG $SELF_PATH/dzil ~/.dzil
ln -sf $SELF_PATH/perlcriticrc ~/.perlcriticrc
ln -sf $SELF_PATH/perltidyrc ~/.perltidyrc
ln -sf $SELF_PATH/profile ~/.profile
ln -sf $SELF_PATH/re.pl/repl.rc ~/.re.pl/repl.rc
ln -sf $SELF_PATH/screenrc ~/.screenrc
ln -sf $SELF_PATH/tmux/tmux.conf ~/.tmux.conf
ln -sf $SELF_PATH/tmux/tmux-osx.conf ~/.tmux-osx.conf
ln -sf $SELF_PATH/tmux/tmux-default-layout ~/.tmux-default-layout
ln -sf $SELF_PATH/tmux/tmux-three-win-layout ~/.tmux-three-win-layout
ln -sf $SELF_PATH/i3 ~/.config/i3
ln -sf $SELF_PATH/i3status ~/.config/i3status


if ! [ -d ~/.ssh/keys ]
then
    mkdir ~/.ssh/keys
fi

git submodule init
git submodule update

./git-config.sh

# silence warnings when perlbrew not installed
mkdir -p $HOME/perl5/perlbrew/etc
touch $HOME/perl5/perlbrew/etc/bashrc

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

# git extras
echo "installing git-extras"

cd inc/git-extras
make install PREFIX="$HOME/local"
