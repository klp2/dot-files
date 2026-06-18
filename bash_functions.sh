# shellcheck shell=bash
IS_MM=false
if [ -e /usr/local/bin/mm-perl ]; then
  IS_MM=true
fi

export IS_MM

# True only on the local KDE/Wayland personal desktop (Bazzite daily driver).
# Used to gate tiling/keyd/zellij setup so remote and work-X11 boxes are untouched.
is_kde_wayland_personal() {
  [ -f "$HOME/.local-personal" ] &&
    [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]] &&
    [ "${XDG_SESSION_TYPE:-}" = "wayland" ]
}
