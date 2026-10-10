#!/usr/bin/env bash
# Install the keyd Caps=Esc(tap)/Ctrl(hold) remap on local desktops.
#
# keyd operates at the kernel evdev layer, so unlike xcape it works under
# Wayland as well as X11 and in gamescope. That is what lets one config serve
# the Bazzite/KDE desktop and the laptop's GNOME/Wayland and i3/X11 sessions
# alike. Where keyd is running, bashrc suppresses xcape so Caps is not
# double-bound.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_DIR/bash_functions.sh"

if ! is_local_desktop; then
  echo "keyd: skipping (not a local desktop)"
  exit 0
fi

SRC="$REPO_DIR/keyd/default.conf"
DEST="/etc/keyd/default.conf"
KEYD_VERSION="${KEYD_VERSION:-v2.6.0}"

# Fedora Atomic: keyd is not in the base repos, and layering needs a reboot, so
# this can only print instructions rather than do the work.
install_keyd_rpm_ostree() {
  local fver repo
  fver="$(rpm -E %fedora 2>/dev/null || echo 44)"
  repo="https://copr.fedorainfracloud.org/coprs/alternateved/keyd/repo/fedora-${fver}/alternateved-keyd-fedora-${fver}.repo"
  cat <<EOF
keyd: not installed. It is NOT in Fedora's base repos; enable the COPR, then
layer it (needs a reboot to apply). alacritty IS in the base repos:
    sudo curl -fsSL -o /etc/yum.repos.d/_copr_alternateved-keyd.repo "$repo"
    sudo rpm-ostree install keyd alacritty
    systemctl reboot
Then re-run ./install.sh to apply the config.
EOF
  return 1
}

# Debian/Ubuntu. keyd reached the Ubuntu archive in 25.10 (questing, 2.5.0-4)
# and 26.04 LTS (2.5.0-5); it is absent from 22.04 and 24.04 LTS, which need a
# source build. The apt-cache probe below picks the packaged version wherever it
# exists, so a box only compiles for as long as it is on an older release.
#
# TODO: once every machine is on 25.10+ the source build can be deleted and this
# reduced to a plain `sudo apt-get install -y keyd`.
install_keyd_apt() {
  if apt-cache policy keyd 2>/dev/null | grep -qE 'Candidate: [0-9]'; then
    echo "keyd: installing from apt"
    sudo apt-get install -y keyd
    return 0
  fi

  local tool
  for tool in git make gcc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "keyd: not packaged for this release and '$tool' is missing."
      echo "keyd: install the build tools and re-run:  sudo apt-get install -y git make gcc"
      return 1
    fi
  done

  echo "keyd: not packaged for this release; building $KEYD_VERSION from source (requires sudo)"
  local build_dir
  build_dir="$(mktemp -d)"
  # shellcheck disable=SC2064  # expand build_dir now, not at trap time
  trap "rm -rf '$build_dir'" EXIT

  git clone --depth 1 --branch "$KEYD_VERSION" https://github.com/rvaiya/keyd "$build_dir/keyd"
  make -C "$build_dir/keyd"
  sudo make -C "$build_dir/keyd" install
}

if ! command -v keyd >/dev/null 2>&1; then
  case "$(pkg_manager)" in
    rpm-ostree) install_keyd_rpm_ostree || exit 0 ;;
    apt) install_keyd_apt || exit 0 ;;
    *)
      echo "keyd: no known install path for this system ($(pkg_manager)); skipping"
      exit 0
      ;;
  esac
fi

if sudo test -f "$DEST" && sudo cmp -s "$SRC" "$DEST"; then
  echo "keyd: config already current"
  exit 0
fi

echo "keyd: installing $SRC -> $DEST (requires sudo)"
sudo install -D -m 0644 "$SRC" "$DEST"
sudo systemctl enable --now keyd
sudo keyd reload || sudo systemctl restart keyd
echo "keyd: applied. Tap Caps for Esc; hold Caps for Ctrl; both Shifts toggle Caps Lock."
