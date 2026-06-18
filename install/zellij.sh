#!/usr/bin/env bash
# Install Zellij (local multiplexer) on the personal KDE/Wayland desktop.
# tmux stays the remote multiplexer; nothing here touches tmux.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_DIR/bash_functions.sh"

if ! is_kde_wayland_personal; then
  echo "zellij: skipping (not local KDE/Wayland personal desktop)"
  exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "zellij: brew not found; skipping"
  exit 0
fi

if command -v zellij >/dev/null 2>&1; then
  echo "zellij: already installed"
  exit 0
fi

echo "zellij: installing via Homebrew"
brew install zellij
echo "zellij: installed. Run 'zellij' locally; tmux remains for remote."
