#!/bin/bash

DOT_FILES_DIR=/home/ubuntu/dot-files

# Set environment type before install.sh runs
touch ~/.devcontainer-work

# Clone dot-files on first run, pull updates on subsequent runs
if [ ! -d "$DOT_FILES_DIR/.git" ]; then
  echo "Cloning dot-files..."
  git clone https://github.com/klp2/dot-files.git "$DOT_FILES_DIR"
else
  echo "Updating dot-files..."
  git -C "$DOT_FILES_DIR" pull --ff-only 2>/dev/null || true
fi

# Remove neovim from mise global config so brew nightly takes priority
# (mise's dynamic PATH management would otherwise shadow brew's version)
sed -i '/"aqua:neovim\/neovim"/d' ~/.config/mise/config.toml 2>/dev/null || true

# NONINTERACTIVE=1 tells Homebrew installer to skip sudo -v prompt
# --yes skips install.sh's own interactive prompts
export NONINTERACTIVE=1
cd "$DOT_FILES_DIR" && bash install.sh --update --yes
