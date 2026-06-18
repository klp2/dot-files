#!/usr/bin/env bash
# Install + enable Krohnkite and apply the i3-style keybindings on the personal
# KDE/Wayland desktop. Idempotent; backs up kglobalshortcutsrc before editing.
#
# Krohnkite's directional focus/move/resize defaults already match the i3 config
# (Meta+HJKL / Meta+Shift+HJKL / Meta+Ctrl+HJKL), so this only sets native KWin
# actions, app-launch keys, virtual desktops, and overrides the two Krohnkite
# defaults that collide with the i3/spec bindings (see kwin/shortcuts.sh).
#
# Ordering matters: KWin is reconfigured FIRST so Krohnkite registers its actions
# (and tiling starts live); shortcut edits are written LAST so nothing
# re-registers over them; then kglobalaccel is reloaded. A re-login (or reboot)
# is the guaranteed activation, which the keyd/alacritty reboot already covers.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_DIR/bash_functions.sh"
# shellcheck source=/dev/null
source "$REPO_DIR/kwin/shortcuts.sh"

if ! is_kde_wayland_personal; then
  echo "kde-tiling: skipping (not local KDE/Wayland personal desktop)"
  exit 0
fi

for tool in kpackagetool6 kwriteconfig6 kreadconfig6; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "kde-tiling: $tool not found; is this Plasma 6? skipping"
    exit 0
  fi
done

# Ask KWin to reload its config/scripts (qdbus6 is absent on some installs).
kwin_reconfigure() {
  local b
  for b in qdbus6 qdbus-qt6 qdbus; do
    if command -v "$b" >/dev/null 2>&1; then
      "$b" org.kde.KWin /KWin reconfigure 2>/dev/null && return
    fi
  done
  dbus-send --session --type=method_call --dest=org.kde.KWin \
    /KWin org.kde.KWin.reconfigure 2>/dev/null || true
}

# Reload the global-shortcuts daemon so it re-reads kglobalshortcutsrc.
kglobalaccel_reload() {
  if systemctl --user restart plasma-kglobalaccel.service 2>/dev/null; then
    return
  fi
  kquitapp6 kglobalaccel6 2>/dev/null || true
}

PKG="$REPO_DIR/kwin/krohnkite.kwinscript"

# Install or upgrade Krohnkite (install fails if already present -> upgrade).
if kpackagetool6 -t KWin/Script -l 2>/dev/null | grep -qi krohnkite; then
  echo "kde-tiling: upgrading Krohnkite"
  kpackagetool6 -t KWin/Script -u "$PKG" || true
else
  echo "kde-tiling: installing Krohnkite"
  kpackagetool6 -t KWin/Script -i "$PKG"
fi

# Enable the script and ensure 10 virtual desktops.
kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled true
kwriteconfig6 --file kwinrc --group Desktops --key Number 10

# Instant desktop switching (disable the slide animation) -- i3-like feel.
kwriteconfig6 --file kwinrc --group Plugins --key slideEnabled false

# Register Krohnkite's actions (and start tiling live) BEFORE editing shortcuts.
kwin_reconfigure

# slideEnabled=false stops the slide on next login, but a reconfigure won't
# unload an already-running effect -- do that live so the instant switch applies
# now too. Harmless if slide is already unloaded.
for b in qdbus6 qdbus-qt6 qdbus; do
  if command -v "$b" >/dev/null 2>&1; then
    "$b" org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect slide 2>/dev/null || true
    break
  fi
done

# --- Keybindings (written last so nothing re-registers over them) ----------
backup_kglobalshortcutsrc

# Free Meta+1..9 from Plasma's "activate task manager entry N" defaults so they
# can drive desktop switching.
for i in 1 2 3 4 5 6 7 8 9; do
  kwriteconfig6 --file kglobalshortcutsrc --group plasmashell \
    --key "activate task manager entry $i" "none,Meta+$i,Activate Task Manager Entry $i"
done

apply_native_shortcuts

# App launchers. Alacritty installs as the "Alacritty" desktop id (native rpm).
set_launch_shortcut "Alacritty" "Meta+Return" "Alacritty"
# KRunner: best-effort launcher bind; KRunner also stays on its KDE defaults
# (Meta tap / Meta+Space) if this id is not wired on this system.
set_launch_shortcut "org.kde.krunner" "Meta+D" "KRunner"

clear_kde_conflicts
apply_krohnkite_overrides

# Reload the shortcuts daemon (re-login/reboot guarantees full activation).
kglobalaccel_reload

cat <<'EOF'
kde-tiling: done.
  - Krohnkite installed + enabled (tiling is active now).
  - Keybindings written to kglobalshortcutsrc (original backed up at *.dotfiles.bak).
  - Log out/in (or reboot) to guarantee all shortcuts are live.
  - Terminal bind (Meta+Return -> Alacritty) needs Alacritty installed.
EOF
