# KDE Tiling + keyd + Zellij Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an i3/Sway-style tiling workflow (Krohnkite), kernel-level Caps=Esc/Ctrl remap (keyd), and the Zellij multiplexer to the Bazzite KDE/Wayland personal desktop, all gated so remote and work-X11 environments are untouched.

**Architecture:** New gated install scripts under `install/`, driven by a detection helper in `bash_functions.sh`, each managing one component. Config artifacts live in new top-level dirs (`keyd/`, `zellij/`, `kwin/`). KDE keybindings are applied by scripting `kwriteconfig6` against `kglobalshortcutsrc`/`kwinrc` (KDE has no hand-editable rc like i3), with the live config read first to discover exact action identifiers before binding.

**Tech Stack:** Bash (shfmt 2-space, shellcheck-clean), KDE Plasma 6 / Wayland, `kwriteconfig6`/`kpackagetool6`/`kreadconfig6`, Krohnkite (`anametologin` fork), keyd, Zellij (Homebrew), Homebrew.

## Global Constraints

- Activate only when ALL hold: `~/.local-personal` marker exists, `$XDG_CURRENT_DESKTOP` contains `KDE`, `$XDG_SESSION_TYPE` == `wayland`.
- Never touch `remote-*` or `local-work` environments; tmux config stays unchanged.
- Never silently `sudo` or run `rpm-ostree`/system changes — prompt or print the command for the user (immutable-OS + "warn before system changes" rules).
- All bash: shfmt `-i 2 -ci`, shellcheck-clean (SC1090/SC1091/SC2155/SC2139 acceptable per CLAUDE.md), idempotent re-runs.
- Commit messages: succinct, one line preferred, attribution `Co-Authored-By: Claude <claude@anthropic.com>`.
- Krohnkite engine = `anametologin` fork; Zellij = pure upstream defaults (no custom config).
- Keybinding mod key = `Meta` (Super), clean personal port (no work workspaces/launchers).

---

## File Structure

- `bash_functions.sh` (modify) — add `is_kde_wayland_personal` detection helper.
- `keyd/default.conf` (create) — keyd remap config.
- `install/keyd.sh` (create) — install/apply keyd config (guarded sudo).
- `zellij/README.md` (create) — documents the deliberate no-config decision.
- `install/zellij.sh` (create) — Homebrew install of zellij, gated.
- `kwin/VERSION` (create) — pinned Krohnkite release tag.
- `kwin/krohnkite.kwinscript` (create) — vendored pinned Krohnkite package.
- `kwin/shortcuts.sh` (create) — the desired-binding table + `kwriteconfig6` writer logic (sourced/called by the installer).
- `install/kde-tiling.sh` (create) — install+enable Krohnkite, ensure desktops, apply shortcuts.
- `install.sh` (modify) — call the three new gated installers.
- `CLAUDE.md` (modify) — update Bazzite notes to point at the new setup.

---

### Task 1: Detection helper

**Files:**
- Modify: `bash_functions.sh`
- Test: ad-hoc sourced invocation with simulated env (no test file in this repo)

**Interfaces:**
- Produces: `is_kde_wayland_personal()` → returns 0 (true) iff `~/.local-personal` exists AND `$XDG_CURRENT_DESKTOP` matches `*KDE*` AND `$XDG_SESSION_TYPE` == `wayland`; returns 1 otherwise. Consumed by all three install scripts.

- [ ] **Step 1: Read existing detection patterns**

Run: `grep -n 'IS_MM\|XDG_SESSION_TYPE\|local-personal\|^[a-z_]*()' bash_functions.sh`
Purpose: match the existing helper style (function naming, return convention) before adding a new one.

- [ ] **Step 2: Add the helper**

Append to `bash_functions.sh`, matching surrounding style:

```bash
# True only on the local KDE/Wayland personal desktop (Bazzite daily driver).
# Used to gate tiling/keyd/zellij setup so remote and work-X11 boxes are untouched.
is_kde_wayland_personal() {
  [ -f "$HOME/.local-personal" ] &&
    [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]] &&
    [ "${XDG_SESSION_TYPE:-}" = "wayland" ]
}
```

- [ ] **Step 3: Verify true-case**

Run:
```bash
touch "$HOME/.local-personal"
XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland bash -c 'source bash_functions.sh; is_kde_wayland_personal && echo MATCH || echo NOMATCH'
```
Expected: `MATCH`

- [ ] **Step 4: Verify false-cases**

Run:
```bash
XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=x11 bash -c 'source bash_functions.sh; is_kde_wayland_personal && echo MATCH || echo NOMATCH'
XDG_CURRENT_DESKTOP=GNOME XDG_SESSION_TYPE=wayland bash -c 'source bash_functions.sh; is_kde_wayland_personal && echo MATCH || echo NOMATCH'
```
Expected: `NOMATCH` for both.
(If `~/.local-personal` did not exist before Step 3, remove it again: `rm -f "$HOME/.local-personal"` — do not leave a marker you created on a non-personal author machine.)

- [ ] **Step 5: Lint**

Run: `shellcheck bash_functions.sh && shfmt -i 2 -ci -d bash_functions.sh`
Expected: no output (clean), or only the CLAUDE.md-accepted codes.

- [ ] **Step 6: Commit**

```bash
git add bash_functions.sh
git commit -m "Add is_kde_wayland_personal detection helper"
```

---

### Task 2: keyd config + installer

**Files:**
- Create: `keyd/default.conf`
- Create: `install/keyd.sh`
- Modify: `bash_functions.sh` (only if the installer needs to source it — it does, no change to the file)

**Interfaces:**
- Consumes: `is_kde_wayland_personal` from Task 1.
- Produces: a runnable `install/keyd.sh` that is safe to call unconditionally (self-gates).

- [ ] **Step 1: Write the keyd config**

Create `keyd/default.conf`:

```
[ids]
*

[main]
capslock = overload(control, escape)
```

- [ ] **Step 2: Write the installer**

Create `install/keyd.sh`:

```bash
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
```

- [ ] **Step 3: Make executable**

Run: `chmod +x install/keyd.sh`

- [ ] **Step 4: Verify self-gating on the author machine**

Run: `./install/keyd.sh`
Expected (on any non-personal machine): `keyd: skipping (not local KDE/Wayland personal desktop)` and exit 0.

- [ ] **Step 5: Lint**

Run: `shellcheck install/keyd.sh && shfmt -i 2 -ci -d install/keyd.sh`
Expected: clean (SC1091 for the dynamic source is acceptable).

- [ ] **Step 6: Commit**

```bash
git add keyd/default.conf install/keyd.sh
git commit -m "Add keyd Caps=Esc/Ctrl remap and gated installer"
```

- [ ] **Step 7: On-desktop verification (Bazzite only — checklist, not author-machine)**

  - `rpm-ostree install keyd` then reboot if not present.
  - `./install/keyd.sh` applies config without error.
  - Tap Caps → Escape lands (test in a terminal: `cat`, press Caps, see nothing/escape behavior in vim).
  - Hold Caps + c interrupts (acts as Ctrl+C).

---

### Task 3: Zellij install

**Files:**
- Create: `zellij/README.md`
- Create: `install/zellij.sh`

**Interfaces:**
- Consumes: `is_kde_wayland_personal` from Task 1.
- Produces: `install/zellij.sh` (self-gating, idempotent).

- [ ] **Step 1: Document the no-config decision**

Create `zellij/README.md`:

```markdown
# Zellij

Installed via Homebrew on the local KDE/Wayland personal desktop only
(see `install/zellij.sh`). Used as the local multiplexer; tmux remains the
remote/SSH multiplexer (see `tmux/`).

**No config by design.** We run pure upstream Zellij defaults to lean on its
on-screen keybinding hints and its clean copy/scroll behavior. If a config is
ever added, put it at `~/.config/zellij/config.kdl` and symlink it from here.
```

- [ ] **Step 2: Write the installer**

Create `install/zellij.sh`:

```bash
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
```

- [ ] **Step 3: Make executable**

Run: `chmod +x install/zellij.sh`

- [ ] **Step 4: Verify self-gating**

Run: `./install/zellij.sh`
Expected (non-personal machine): `zellij: skipping (not local KDE/Wayland personal desktop)`.

- [ ] **Step 5: Lint**

Run: `shellcheck install/zellij.sh && shfmt -i 2 -ci -d install/zellij.sh`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add zellij/README.md install/zellij.sh
git commit -m "Add gated Zellij install (local multiplexer)"
```

---

### Task 4: Vendor + pin Krohnkite

**Files:**
- Create: `kwin/VERSION`
- Create: `kwin/krohnkite.kwinscript`

**Interfaces:**
- Produces: a pinned `kwin/krohnkite.kwinscript` and `kwin/VERSION` consumed by `install/kde-tiling.sh` (Task 6).

- [ ] **Step 1: Discover the latest release tag**

Run:
```bash
curl -fsSL https://codeberg.org/api/v1/repos/anametologin/Krohnkite/releases/latest | grep -o '"tag_name":"[^"]*"'
```
Record the tag (e.g. the printed value). If the API shape differs, open the releases page `https://codeberg.org/anametologin/Krohnkite/releases` and read the newest tag and the `.kwinscript` asset name.

- [ ] **Step 2: Download and vendor the pinned package**

Run (substitute the tag and asset URL discovered in Step 1):
```bash
curl -fsSL -o kwin/krohnkite.kwinscript "<asset-url-for-the-.kwinscript-from-step-1>"
file kwin/krohnkite.kwinscript
```
Expected: `file` reports a Zip archive (a `.kwinscript` is a zip). If the project ships source-only, build per its README and place the resulting `.kwinscript` here.

- [ ] **Step 3: Record the pin**

Run:
```bash
printf '%s\n' "<tag-from-step-1>" > kwin/VERSION
```

- [ ] **Step 4: Sanity-check the archive contents**

Run: `unzip -l kwin/krohnkite.kwinscript | grep -i metadata`
Expected: a `metadata.json` / `metadata.desktop` entry exists (confirms it's a valid KWin script package).

- [ ] **Step 5: Commit**

```bash
git add kwin/VERSION kwin/krohnkite.kwinscript
git commit -m "Vendor pinned Krohnkite kwinscript"
```

---

### Task 5: Krohnkite shortcut writer

**Files:**
- Create: `kwin/shortcuts.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks (pure KDE config writer).
- Produces: `apply_kde_shortcuts()` and `backup_kglobalshortcutsrc()`, called by `install/kde-tiling.sh` (Task 6).

- [ ] **Step 1: Write the backup + native-shortcut writer**

Create `kwin/shortcuts.sh`. Native KWin actions (desktop switch/move, close, fullscreen) have stable identifiers and are written directly. Krohnkite's own action names are discovered at apply time (Step 2 of Task 6), so this file writes only the native set plus a documented helper for Krohnkite keys:

```bash
#!/usr/bin/env bash
# KDE keybinding writer. Writes the clean personal port of the i3 binds into
# kglobalshortcutsrc via kwriteconfig6. kglobalshortcutsrc value format is:
#   ActionName=Current,Default,DisplayName
set -euo pipefail

backup_kglobalshortcutsrc() {
  local f="$HOME/.config/kglobalshortcutsrc"
  if [ -f "$f" ] && [ ! -f "$f.dotfiles.bak" ]; then
    cp "$f" "$f.dotfiles.bak"
    echo "kde: backed up kglobalshortcutsrc -> $f.dotfiles.bak"
  fi
}

# set_kwin_shortcut ACTION KEYS DISPLAY
set_kwin_shortcut() {
  kwriteconfig6 --file kglobalshortcutsrc --group kwin \
    --key "$1" "$2,$2,$3"
}

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

# apply_krohnkite_shortcut DISCOVERED_ACTION KEYS
# DISCOVERED_ACTION is read from the live config (see kde-tiling.sh); we only
# overwrite the Current field, preserving Default/DisplayName.
apply_krohnkite_shortcut() {
  local action="$1" keys="$2"
  local existing
  existing="$(kreadconfig6 --file kglobalshortcutsrc --group kwin --key "$action" 2>/dev/null || true)"
  local default display
  default="$(printf '%s' "$existing" | cut -d, -f2)"
  display="$(printf '%s' "$existing" | cut -d, -f3-)"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin \
    --key "$action" "$keys,${default},${display}"
}
```

- [ ] **Step 2: Lint**

Run: `shellcheck kwin/shortcuts.sh && shfmt -i 2 -ci -d kwin/shortcuts.sh`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add kwin/shortcuts.sh
git commit -m "Add KDE shortcut writer for native + Krohnkite bindings"
```

---

### Task 6: Tiling installer (install + enable + bind)

**Files:**
- Create: `install/kde-tiling.sh`

**Interfaces:**
- Consumes: `is_kde_wayland_personal` (Task 1), `kwin/krohnkite.kwinscript` + `kwin/VERSION` (Task 4), `kwin/shortcuts.sh` functions (Task 5).
- Produces: `install/kde-tiling.sh` (self-gating, idempotent).

- [ ] **Step 1: Write the installer**

Create `install/kde-tiling.sh`:

```bash
#!/usr/bin/env bash
# Install + enable Krohnkite and apply the i3-style keybindings on the
# personal KDE/Wayland desktop. Idempotent; backs up kglobalshortcutsrc.
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

PKG="$REPO_DIR/kwin/krohnkite.kwinscript"

# Install or upgrade Krohnkite (install fails if already present -> upgrade).
if kpackagetool6 -t KWin/Script -l 2>/dev/null | grep -qi krohnkite; then
  kpackagetool6 -t KWin/Script -u "$PKG" || true
else
  kpackagetool6 -t KWin/Script -i "$PKG"
fi

# Enable the script.
kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled true

# Ensure 10 virtual desktops.
kwriteconfig6 --file kwinrc --group Desktops --key Number 10

# Apply keybindings.
backup_kglobalshortcutsrc
apply_native_shortcuts

# Reload KWin so Krohnkite registers its shortcut actions before we rebind.
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null ||
  dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true

cat <<'EOF'
kde-tiling: Krohnkite installed + enabled, native binds applied.

Krohnkite registers its own action names under [kwin] in kglobalshortcutsrc.
To finish the directional hjkl binds, discover the exact action names:

    kreadconfig6 --file kglobalshortcutsrc --group kwin | grep -i krohnkite
    # or inspect: grep -i 'Krohnkite' ~/.config/kglobalshortcutsrc

Then bind them (example, adjust action strings to what you found):

    source kwin/shortcuts.sh
    apply_krohnkite_shortcut "Krohnkite: Focus Down"  "Meta+J"
    apply_krohnkite_shortcut "Krohnkite: Focus Up"    "Meta+K"
    apply_krohnkite_shortcut "Krohnkite: Focus Left"  "Meta+H"
    apply_krohnkite_shortcut "Krohnkite: Focus Right" "Meta+L"
    # move window: Krohnkite "Move" actions -> Meta+Shift+H/J/K/L
    # master ratio (resize analog): -> Meta+Ctrl+H / Meta+Ctrl+L
    # toggle float: Krohnkite float action -> Meta+Shift+Space
    # toggle tiling: Krohnkite disable/enable action -> Meta+T

Then reload: qdbus6 org.kde.KWin /KWin reconfigure

Any Krohnkite action that has no directional equivalent is listed here when
discovered; nothing is silently dropped.
EOF
```

- [ ] **Step 2: Make executable**

Run: `chmod +x install/kde-tiling.sh`

- [ ] **Step 3: Verify self-gating**

Run: `./install/kde-tiling.sh`
Expected (non-personal machine): `kde-tiling: skipping (not local KDE/Wayland personal desktop)`.

- [ ] **Step 4: Lint**

Run: `shellcheck install/kde-tiling.sh && shfmt -i 2 -ci -d install/kde-tiling.sh`
Expected: clean (SC1091 acceptable).

- [ ] **Step 5: Commit**

```bash
git add install/kde-tiling.sh
git commit -m "Add gated Krohnkite tiling installer with KDE keybindings"
```

- [ ] **Step 6: On-desktop verification (Bazzite only — checklist)**

  - `./install/kde-tiling.sh` runs clean; Krohnkite appears in System Settings → Window Management → KWin Scripts (enabled).
  - Windows auto-tile; `Meta+1..0` switches desktops; `Meta+Shift+1..0` moves windows; `Meta+Shift+Q` closes; `Meta+F` fullscreens.
  - Run the discovery command, bind directional `hjkl`/move/master-ratio/float/toggle per the printed guide, reload, and confirm each works.
  - Record the final, confirmed Krohnkite action names back into `install/kde-tiling.sh` (replace the example block with the real `apply_krohnkite_shortcut` calls so the next run is fully automatic). Commit that follow-up:
    `git commit -am "Wire confirmed Krohnkite directional binds"`.
  - Launch Steam Game Mode and confirm gaming is unaffected.

---

### Task 7: Wire into install.sh + docs

**Files:**
- Modify: `install.sh`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: the three installers (Tasks 2, 3, 6).

- [ ] **Step 1: Find the install.sh call sequence**

Run: `grep -n 'install/\|vim.sh\|nvim.sh' install.sh`
Purpose: locate where the existing `install/*.sh` scripts are invoked so the new calls follow the same pattern.

- [ ] **Step 2: Add the three calls**

In `install.sh`, after the existing nvim install call, add (match surrounding style/indentation):

```bash
# Local KDE/Wayland personal desktop extras (self-gating; no-op elsewhere).
"$(dirname "$0")/install/keyd.sh"
"$(dirname "$0")/install/zellij.sh"
"$(dirname "$0")/install/kde-tiling.sh"
```

(If `install.sh` already computes a repo-dir variable, reuse it instead of `$(dirname "$0")` to match the existing convention found in Step 1.)

- [ ] **Step 3: Update CLAUDE.md Bazzite notes**

In `CLAUDE.md`, replace the line `- For Ctrl→Escape keyboard remap, use \`keyd\` (needs \`rpm-ostree install keyd\`)` with:

```markdown
- For Caps→Esc(tap)/Ctrl(hold) remap, use `keyd` (config in `keyd/`, applied by `install/keyd.sh`; needs `rpm-ostree install keyd` + reboot first)
- Tiling on KDE/Wayland: Krohnkite (vendored in `kwin/`, installed by `install/kde-tiling.sh`); i3-style binds written via `kwriteconfig6`
- Local multiplexer: Zellij (`install/zellij.sh`); tmux remains the remote/SSH multiplexer
```

- [ ] **Step 4: Lint the changed script**

Run: `shellcheck install.sh && shfmt -i 2 -ci -d install.sh`
Expected: clean.

- [ ] **Step 5: Dry-run install.sh self-gating**

Run: `./install.sh` on the author (non-personal) machine.
Expected: the three new scripts each print their `skipping` line and `install.sh` completes without error.

- [ ] **Step 6: Commit**

```bash
git add install.sh CLAUDE.md
git commit -m "Wire KDE tiling/keyd/zellij installers into install.sh"
```

---

## Self-Review

**Spec coverage:**
- Gating (KDE+Wayland+personal) → Task 1, enforced in Tasks 2/3/6. ✓
- Krohnkite i3-style tiling + ported binds → Tasks 4, 5, 6. ✓
- keyd Caps=Esc/Ctrl, guarded sudo, immutable-OS handling → Task 2. ✓
- Zellij local, pure defaults, tmux untouched → Task 3. ✓
- Repo integration + conventions + docs → Task 7. ✓
- Known risks (directional bind discovery, no resize-mode, version-sensitive shortcut writes, reboot for keyd) → handled via discover-then-bind (Task 6), master-ratio mapping (Task 5/6), backup-before-merge (Task 5), guided manual step (Task 2). ✓

**Placeholder scan:** The only deliberately-deferred values are the Krohnkite release tag/asset URL (Task 4, discovered via a concrete API command) and the exact Krohnkite action strings (Task 6, discovered on the live machine via a concrete `kreadconfig6`/`grep` command, then committed back). These are environment-discovery steps with exact commands, not unspecified work.

**Type/name consistency:** `is_kde_wayland_personal` (Task 1) used verbatim in Tasks 2/3/6. `backup_kglobalshortcutsrc`, `apply_native_shortcuts`, `set_kwin_shortcut`, `apply_krohnkite_shortcut` defined in Task 5, called in Task 6. `kwin/krohnkite.kwinscript`/`kwin/VERSION` produced in Task 4, consumed in Task 6. Consistent. ✓
