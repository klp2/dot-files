# shellcheck shell=bash
IS_MM=false
if [ -e /usr/local/bin/mm-perl ]; then
  IS_MM=true
fi

export IS_MM

# --- Capability predicates ---------------------------------------------------
# The envtype marker files answer "whose machine is this, and is it graphical".
# They deliberately do NOT encode the desktop environment: the personal laptop
# offers both a GNOME/Wayland and an i3/X11 session, and which one is live is
# chosen at the login screen. A marker written once at install time cannot
# represent that, so anything depending on the desktop, the session type, or an
# installed binary must be gated on these runtime predicates instead of $envtype.

is_local_personal() {
  [ -f "$HOME/.local-personal" ]
}

has_kde() {
  [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]]
}

is_wayland() {
  [ "${XDG_SESSION_TYPE:-}" = "wayland" ]
}

is_x11() {
  [ "${XDG_SESSION_TYPE:-}" = "x11" ]
}

has_i3() {
  command -v i3 >/dev/null 2>&1
}

# Echoes the system package manager: rpm-ostree (Bazzite/Fedora Atomic), dnf,
# apt, or none. Homebrew is deliberately excluded -- it is user-space and always
# on PATH via bashrc; this is only for system/kernel-level packages like keyd.
pkg_manager() {
  if command -v rpm-ostree >/dev/null 2>&1; then
    echo 'rpm-ostree'
  elif command -v dnf >/dev/null 2>&1; then
    echo 'dnf'
  elif command -v apt-get >/dev/null 2>&1; then
    echo 'apt'
  else
    echo 'none'
  fi
}

# True only on the local KDE/Wayland personal desktop (Bazzite daily driver).
# Gates the Krohnkite tiling setup and Zellij, which are Plasma-specific.
is_kde_wayland_personal() {
  is_local_personal && has_kde && is_wayland
}
