#!/usr/bin/env bash
# Install the keyd Caps=Esc(tap)/Ctrl(hold) remap on the personal KDE/Wayland
# desktop. keyd is kernel-level so it works on Wayland and in gamescope.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_DIR/bash_functions.sh"

if ! is_kde_wayland_personal; then
  echo "keyd: skipping (not local KDE/Wayland personal desktop)"
  exit 0
fi

SRC="$REPO_DIR/keyd/default.conf"
DEST="/etc/keyd/default.conf"

if ! command -v keyd >/dev/null 2>&1; then
  cat <<'EOF'
keyd: not installed. On Bazzite this is a system package and needs a reboot:
    rpm-ostree install keyd
    systemctl reboot
Then re-run ./install.sh to apply the config.
EOF
  exit 0
fi

if sudo test -f "$DEST" && sudo cmp -s "$SRC" "$DEST"; then
  echo "keyd: config already current"
  exit 0
fi

echo "keyd: installing $SRC -> $DEST (requires sudo)"
sudo install -D -m 0644 "$SRC" "$DEST"
sudo systemctl enable --now keyd
sudo keyd reload || sudo systemctl restart keyd
echo "keyd: applied. Tap Caps for Esc; hold Caps for Ctrl."
