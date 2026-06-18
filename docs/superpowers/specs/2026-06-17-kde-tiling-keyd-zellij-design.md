# KDE Tiling + keyd + Zellij for the Bazzite Personal Desktop

**Date:** 2026-06-17
**Status:** Approved design, pending implementation plan

## Problem

The primary dev environment has historically used a tiling WM (Regolith/i3, recently Sway). The new daily-driver desktop runs Bazzite (Fedora Atomic, immutable) with KDE Plasma 6 on Wayland, chosen because it makes gaming easier. The goal is to recover a tiling-WM-style dev workflow on that machine without compromising gaming, and without the heavy, reboot-requiring path of layering a full third-party compositor onto an immutable OS.

Three pieces are in scope:

1. **Tiling** — an i3/Sway-style dynamic tiling experience on KDE.
2. **keyd** — kernel-level Caps Lock remap (replaces the X11-only xcape).
3. **Multiplexer** — add Zellij locally while keeping tmux for remote/SSH.

## Goals

- i3/Sway-style dynamic tiling on KDE Plasma 6 / Wayland with keybindings ported from the existing `i3/config`.
- Caps Lock acts as Escape when tapped, Control when held — working on Wayland.
- Zellij available on the local desktop with sane defaults; tmux untouched for remote parity.
- Everything gated to the local KDE/Wayland personal desktop only; remote and work-X11 environments unaffected.
- Gaming (Steam Game Mode / gamescope) completely unaffected.
- Reproducible and idempotent installs consistent with the repo's existing conventions.

## Non-Goals

- Layering a full third-party Wayland compositor (Hyprland/niri/Sway) via rpm-ostree. Rejected: heavy, requires reboots, mutates the base image, more to maintain.
- Replacing or restyling the remote tmux config. tmux stays as-is for SSH ubiquity.
- A faithful 1:1 port of work-specific i3 bindings (named workspaces `slack`/`pct`/`gcp`/`vagrant`, work app launchers). This is a clean *personal* port.
- Custom Zellij keybindings. User chose pure Zellij defaults to lean on its on-screen hints.

## Key Decisions (from brainstorming)

| Decision | Choice | Rationale |
|---|---|---|
| Tiling feel | i3/Sway-style dynamic | Matches existing muscle memory and `i3/config`. |
| Tiling engine | Krohnkite (`anametologin` fork) | Maintained into 2026, Plasma 6 X11+Wayland, dwm/i3-style dynamic tiler. Polonium rejected (Bismuth-style auto-tree = wrong feel). |
| Keybinding scope | Clean personal port | Keep navigation muscle memory; drop work workspaces/launchers. |
| Caps remap | Tap=Esc, Hold=Ctrl | `capslock = overload(control, escape)`. Classic vim dual-role. |
| Multiplexer | Run both | Zellij locally, tmux for remote/SSH. |
| Zellij binds | Pure defaults | Directly addresses "can't remember binds" + copy/scroll friction. |

## Architecture

### Gating

All new behavior activates only when **all** of:
- `~/.local-personal` marker present, AND
- `$XDG_CURRENT_DESKTOP` contains `KDE`, AND
- `$XDG_SESSION_TYPE` is `wayland`.

This mirrors the existing `bashrc` guard pattern for `xcape`. The `remote-*` and `local-work` environments are never touched. Detection helpers live in `bash_functions.sh` alongside existing `IS_MM`-style logic.

### Component 1: Tiling (Krohnkite)

- **Install:** Vendor or version-pin the Krohnkite `.kwinscript` in `kwin/`. Install reproducibly via `kpackagetool6 -t KWin/Script -i <file>` (upgrade with `-u`). Enable via `kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled true`.
- **Shortcuts:** Written into `~/.config/kglobalshortcutsrc` (and `kwinrc` where relevant) via `kwriteconfig6`. The install script **backs up** the existing `kglobalshortcutsrc` before merging and is idempotent.
- **Keybinding map (clean personal port):**
  - `Super+h/j/k/l` → focus left/down/up/right
  - `Super+Shift+h/j/k/l` → move window left/down/up/right
  - `Super+1‒0` → switch to virtual desktop 1‒10 (native KWin action)
  - `Super+Shift+1‒0` → move window to virtual desktop 1‒10 (native KWin action)
  - `Super+Return` → Alacritty
  - `Super+Shift+q` → close window
  - `Super+d` → KRunner (KDE-native launcher; replaces dmenu)
  - `Super+f` → toggle fullscreen
  - `Super+Shift+space` → toggle floating
  - `Super+t` → toggle tiling on/off
  - `Super+Ctrl+h/l` → adjust master area ratio (closest analog to i3 resize-mode)
- **Virtual desktops:** Ensure 10 virtual desktops exist via `kwriteconfig6` on `kwinrc` (`[Desktops] Number=10`).

### Component 2: keyd

- **Repo file:** `keyd/default.conf`:
  ```
  [ids]
  *

  [main]
  capslock = overload(control, escape)
  ```
- **Install (`install/keyd.sh`):**
  - If `keyd` binary is present: copy/symlink `keyd/default.conf` → `/etc/keyd/default.conf` (requires sudo — **prompt the user, never silently sudo**), then `sudo systemctl enable --now keyd` / `systemctl restart keyd`.
  - If `keyd` is absent: print the `rpm-ostree install keyd` command and the reboot caveat for the user to run manually (immutable-OS + "warn before system changes" rules).
- **Relationship to xcape:** This replaces xcape on this box. xcape is X11-only and already skipped on Wayland by `bashrc`; no change needed there.

### Component 3: Zellij

- **Install (`install/zellij.sh`):** Homebrew install, gated on `local-personal` (consistent with the nvim/brew approach).
- **Config:** None — pure upstream defaults.
- **tmux:** Untouched. No forced auto-start of either multiplexer. Optional auto-attach hook noted for future, not implemented now.

### Repo Integration

New directories:
- `keyd/` — `default.conf`
- `zellij/` — placeholder/README (no config by design)
- `kwin/` — pinned Krohnkite `.kwinscript` + the `kwriteconfig6` shortcut-writer script

New install scripts (gated, called from `install.sh`):
- `install/kde-tiling.sh`
- `install/keyd.sh`
- `install/zellij.sh`

Conventions: `bash_functions.sh` for detection, shfmt 2-space / `-ci`, shellcheck-clean, idempotent re-runs, pre-commit/pre-push hooks apply.

## Known Risks / Caveats

1. **Krohnkite default bindings differ from i3.** Krohnkite's defaults use `Super+h/l` for master-ratio and next/prev (not strictly directional) focus. The install will rebind to directional `hjkl` where Krohnkite exposes the action; any binding Krohnkite cannot do 1:1 will be **listed explicitly**, not silently dropped.
2. **No i3 resize-mode equivalent.** Mapped to master-ratio adjust (`Super+Ctrl+h/l`).
3. **KDE shortcut writes are version-sensitive.** `kglobalshortcutsrc` key naming can shift across Plasma releases. Mitigation: back up before merge, keep writes idempotent, verify after apply.
4. **keyd requires system layering + reboot** on Bazzite. Handled as a guided manual step, not silent automation.

## Verification

- Tiling: log into KDE/Wayland personal desktop, confirm windows auto-tile and each ported keybinding performs its action; confirm Game Mode still launches and tiles nothing.
- keyd: tap Caps → Escape; hold Caps + key → Control chord; verify in both desktop and a terminal.
- Zellij: `zellij` launches with defaults on local; `tmux` unchanged locally and on a remote box.
- Idempotency: re-running `install.sh` produces no diff/errors and does not duplicate shortcuts.
- All bash scripts pass shellcheck and shfmt.
