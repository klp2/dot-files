#!/usr/bin/env bash
# Make Flatpak and the per-user Flathub remote available on local desktops. A
# pre-packages hook in config/mise/config.desktop.toml.
#
# The apps themselves are flatpak-user entries in [bootstrap.packages]
# (config/mise/common.toml), which mise installs but cannot set up for: it
# neither installs Flatpak nor adds remotes. LibreOffice comes from Flathub
# because Homebrew ships it only as a macOS cask.
set -euo pipefail

if ! command -v flatpak >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    echo "flatpak: installing (requires sudo)"
    sudo apt-get update -qq
    sudo apt-get install -y flatpak
  else
    echo "flatpak: not found and no apt-get; skipping"
    exit 0
  fi
fi

flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
