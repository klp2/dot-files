#!/usr/bin/env bash
# Make Flatpak and the per-user Flathub remote available on local desktops.
#
# The apps themselves are flatpak-user entries in [bootstrap.packages]
# (config/mise/common.toml), which mise installs but cannot set up for: it
# neither installs Flatpak nor adds remotes. LibreOffice comes from Flathub
# because Homebrew ships it only as a macOS cask.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_DIR/bash_functions.sh"

if ! is_local_desktop; then
  echo "flatpak: skipping (not a local desktop)"
  exit 0
fi

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
