#!/usr/bin/env bash

set -eu -o pipefail

PREFIX=~/dot-files

mkdir -p ~/.config/nvim/lua
ln -sf $PREFIX/nvim/init.lua ~/.config/nvim/init.lua
ln -sf $PREFIX/nvim/lua/plugins.lua ~/.config/nvim/lua/plugins.lua

exit 0
