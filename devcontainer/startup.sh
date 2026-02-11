#!/bin/bash

DOT_FILES_DIR=/home/ubuntu/dot-files

# Set environment type before install.sh runs
touch ~/.devcontainer-work

# Clone dot-files on first run, pull updates on subsequent runs
if [ ! -d "$DOT_FILES_DIR/.git" ]; then
  echo "Cloning dot-files..."
  gh repo clone klp2/dot-files "$DOT_FILES_DIR"
else
  echo "Updating dot-files..."
  git -C "$DOT_FILES_DIR" pull --ff-only 2>/dev/null || true
fi

# Run dotfiles install (--yes skips interactive prompts)
cd "$DOT_FILES_DIR" && ./install.sh --update --yes
