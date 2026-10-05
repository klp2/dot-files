#!/usr/bin/env bash
# Install and update LibreOffice from Flathub on local desktops.
#
# Homebrew is not used: LibreOffice ships only as a Homebrew cask, and casks
# are macOS-only. Flatpak gives the same current release on Bazzite and Ubuntu.
# Set UPGRADE="" to skip the update (install.sh passes --no-upgrade through).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_DIR/bash_functions.sh"

APP_ID=org.libreoffice.LibreOffice

if ! is_local_desktop; then
  echo "libreoffice: skipping (not a local desktop)"
  exit 0
fi

if ! command -v flatpak >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    echo "libreoffice: installing flatpak (requires sudo)"
    sudo apt-get update -qq
    sudo apt-get install -y flatpak
  else
    echo "libreoffice: flatpak not found and no apt-get; skipping"
    exit 0
  fi
fi

flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

if flatpak info "$APP_ID" >/dev/null 2>&1; then
  if [[ -n "${UPGRADE-yes}" ]]; then
    echo "libreoffice: updating"
    flatpak update -y --noninteractive "$APP_ID"
  else
    echo "libreoffice: installed; update skipped (--no-upgrade)"
  fi
else
  echo "libreoffice: installing from Flathub"
  flatpak install --user -y --noninteractive flathub "$APP_ID"
fi
