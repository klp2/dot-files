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
elif [[ -e "$HOME/.desktop" ]]; then
    envtype='desktop'
fi


$SELF_PATH/install/vim.sh
$SELF_PATH/install/nvim.sh

# Prompt setup - git-prompt-fallback and starship config
cp $SELF_PATH/bin/git-prompt-fallback ~/bin/
chmod +x ~/bin/git-prompt-fallback
cp $SELF_PATH/bin/install-starship.sh ~/bin/
chmod +x ~/bin/install-starship.sh
mkdir -p ~/.config
ln -sf $SELF_PATH/starship.toml ~/.config/starship.toml

# Install starship on desktop/laptop if not already present (not on remote servers)
if [[ $envtype == 'desktop' || $envtype == 'laptop' ]] && ! command -v starship &> /dev/null; then
    echo "Installing starship prompt..."
    $SELF_PATH/bin/install-starship.sh ~/bin
fi

# Install modern CLI tools on desktop/laptop via Homebrew
if [[ $envtype == 'desktop' || $envtype == 'laptop' ]] && command -v brew &> /dev/null; then
    echo "Installing modern CLI tools..."
    for tool in ripgrep fd fzf jq bat eza git-delta zoxide lazygit; do
        if ! brew list $tool &> /dev/null; then
            echo "  Installing $tool..."
            brew install $tool 2>/dev/null || true
        fi
    done
fi

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
