#!/usr/bin/env bash
# KDE keybinding writer for the i3-style personal port.
#
# kglobalshortcutsrc value format per entry is: Active,Default,DisplayName
# (kwriteconfig6 stores the value verbatim; commas are part of the value).
#
# Krohnkite's directional focus/move/resize binds already ship correct in the
# pinned kwin/krohnkite.kwinscript (Meta+HJKL, Meta+Shift+HJKL, Meta+Ctrl+HJKL),
# so we do NOT rewrite those here -- the pin guarantees their reproducibility.
# We only set native KWin actions, app-launch keys, and override the two
# Krohnkite defaults that collide with the i3/spec bindings.

# shellcheck shell=bash

# Back up the live shortcuts file once, before any edits.
backup_kglobalshortcutsrc() {
  local f="$HOME/.config/kglobalshortcutsrc"
  if [ -f "$f" ] && [ ! -f "$f.dotfiles.bak" ]; then
    cp "$f" "$f.dotfiles.bak"
    echo "kde: backed up kglobalshortcutsrc -> $f.dotfiles.bak"
  fi
}

# set_kwin_shortcut ACTION KEYS DISPLAY
# Writes a full Active,Default,Display triple under the [kwin] component.
set_kwin_shortcut() {
  kwriteconfig6 --file kglobalshortcutsrc --group kwin \
    --key "$1" "$2,$2,$3"
}

# override_kwin_active ACTION KEYS
# Replaces only the Active field of an existing [kwin] entry (e.g. a Krohnkite
# action already registered), preserving its Default and DisplayName so the
# KCM still shows the right labels. Falls back to a bare write if absent.
override_kwin_active() {
  local action="$1" keys="$2" existing default display
  existing="$(kreadconfig6 --file kglobalshortcutsrc --group kwin --key "$action" 2>/dev/null || true)"
  if [ -z "$existing" ]; then
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "$action" "$keys,$keys,$action"
    return
  fi
  default="$(printf '%s' "$existing" | cut -d, -f2)"
  display="$(printf '%s' "$existing" | cut -d, -f3-)"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin \
    --key "$action" "$keys,$default,$display"
}

# set_launch_shortcut DESKTOP_ID KEYS DISPLAY
# Binds an application's .desktop _launch action to a global shortcut. DESKTOP_ID
# is the desktop file id WITHOUT the .desktop suffix (e.g. Alacritty,
# org.kde.krunner). Plasma 6 stores these under the NESTED [services][<id>.desktop]
# group -- a top-level [<id>.desktop] group is pruned by kglobalacceld on login.
set_launch_shortcut() {
  local id="$1" keys="$2" display="$3"
  kwriteconfig6 --file kglobalshortcutsrc --group services --group "${id}.desktop" \
    --key "_launch" "$keys,$keys,$display"
  kwriteconfig6 --file kglobalshortcutsrc --group services --group "${id}.desktop" \
    --key "_k_friendly_name" "$display"
}

# Native KWin window/desktop actions (stable identifiers across Plasma 6).
apply_native_shortcuts() {
  local i
  for i in 1 2 3 4 5 6 7 8 9; do
    set_kwin_shortcut "Switch to Desktop $i" "Meta+$i" "Switch to Desktop $i"
    set_kwin_shortcut "Window to Desktop $i" "Meta+Shift+$i" "Window to Desktop $i"
  done
  set_kwin_shortcut "Switch to Desktop 10" "Meta+0" "Switch to Desktop 10"
  set_kwin_shortcut "Window to Desktop 10" "Meta+Shift+0" "Window to Desktop 10"
  set_kwin_shortcut "Window Close" "Meta+Shift+Q" "Close Window"
  set_kwin_shortcut "Window Fullscreen" "Meta+F" "Toggle Fullscreen"
}

# Free KDE default shortcuts that collide with the i3/Krohnkite bindings. KDE
# wins these at registration otherwise, silently leaving the Krohnkite action
# unbound. We blank the active field but keep KDE's default as the 2nd field.
clear_kde_conflicts() {
  # Lock Session owns Meta+L (we want Focus Right). Move lock to the i3 bind
  # (Meta+Ctrl+Shift+L) so locking still works and Meta+L is freed.
  kwriteconfig6 --file kglobalshortcutsrc --group ksmserver \
    --key "Lock Session" "Meta+Ctrl+Shift+L,Meta+L,Lock Session"
  # KDE's built-in tile editor owns Meta+T (we want Krohnkite Tile Layout).
  kwriteconfig6 --file kglobalshortcutsrc --group kwin \
    --key "Edit Tiles" "none,Meta+T,Toggle Tiles Editor"
  # Peek at Desktop owns Meta+D (we want KRunner).
  kwriteconfig6 --file kglobalshortcutsrc --group kwin \
    --key "Show Desktop" "none,Meta+D,Peek at Desktop"
}

# Resolve the Krohnkite defaults that collide with the i3/spec bindings, and
# explicitly (re)set the binds KDE defaults had stolen at registration:
#   - Toggle Float defaults to Meta+F (we want fullscreen there) -> Meta+Shift+Space.
#   - Set master defaults to Meta+Return (we want the terminal there) -> Meta+Shift+Return.
#   - Focus Right (Meta+L) and Tile Layout (Meta+T) lost to KDE defaults -> reclaim.
# Run AFTER Krohnkite has registered its actions and clear_kde_conflicts has run.
apply_krohnkite_overrides() {
  override_kwin_active "KrohnkiteToggleFloat" "Meta+Shift+Space"
  override_kwin_active "KrohnkiteSetMaster" "Meta+Shift+Return"
  override_kwin_active "KrohnkiteFocusRight" "Meta+L"
  override_kwin_active "KrohnkiteTileLayout" "Meta+T"
}
