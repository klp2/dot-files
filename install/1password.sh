#!/usr/bin/env bash
# Install the 1Password CLI (op) on local desktops and seed the untracked
# secret-reference file that bashrc's opload/oprun helpers read.
#
# Homebrew is deliberately not used: 1password-cli ships as a Homebrew *cask*,
# and casks are macOS-only, so Linuxbrew cannot install it. Each distro gets its
# own vendor repo instead.
#
# No secret ever lands in this repo. ~/.config/op/env holds only op:// URIs,
# which are references resolved at runtime against the vault -- useless on their
# own without an authenticated 1Password session.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_DIR/bash_functions.sh"

if ! is_local_desktop; then
  echo "1password: skipping (not a local desktop)"
  exit 0
fi

OP_ENV_FILE="$HOME/.config/op/env"
OP_AUTOLOAD_FILE="$HOME/.config/op/autoload"

seed_env_file() {
  if [ -e "$OP_ENV_FILE" ]; then
    echo "1password: $OP_ENV_FILE already exists, leaving it alone"
    return 0
  fi
  mkdir -p "$(dirname "$OP_ENV_FILE")"
  cat >"$OP_ENV_FILE" <<'EOF'
# 1Password secret references, one NAME=op://Vault/Item/field per line.
# This file is NOT tracked in dotfiles and holds no secret values -- only
# references, resolved at runtime by `opload` (exports into the current shell)
# or `oprun` (injects into one command without touching the environment).
#
# Keep this file in op's dotenv syntax -- `op run` parses it directly, so a
# comment or NAME=op://... line is all it tolerates. To have a name exported
# automatically at login instead of on demand, list it in ./autoload.
#
# Discover the reference for an item with:
#     op item get "GitHub PAT" --format json | jq -r '.fields[].reference'
#
# Examples -- replace the vault/item names with your own:
#GITHUB_TOKEN=op://Personal/GitHub PAT/credential
#CLOUDFLARE_API_TOKEN=op://Personal/Cloudflare/api token
#CLOUDFLARE_ACCOUNT_ID=op://Personal/Cloudflare/account id
EOF
  chmod 600 "$OP_ENV_FILE"
  echo "1password: seeded $OP_ENV_FILE"
}

seed_autoload_file() {
  if [ -e "$OP_AUTOLOAD_FILE" ]; then
    echo "1password: $OP_AUTOLOAD_FILE already exists, leaving it alone"
    return 0
  fi
  mkdir -p "$(dirname "$OP_AUTOLOAD_FILE")"
  cat >"$OP_AUTOLOAD_FILE" <<'EOF'
# Names from ./env to resolve at login rather than on demand, one per line.
# Reserve this for secrets that tools expect to find already in the environment
# (linearis, gh); anything else is better left to `opload` / `oprun`.
#
# The first shell of a session resolves these and may raise a biometric prompt;
# the values are then cached in $XDG_RUNTIME_DIR until logout. Editing this file
# or ./env invalidates that cache.
#
# Examples -- the name must also have a reference in ./env:
#LINEAR_API_TOKEN
#GH_ENTERPRISE_TOKEN
EOF
  chmod 600 "$OP_AUTOLOAD_FILE"
  echo "1password: seeded $OP_AUTOLOAD_FILE"
}

install_op_apt() {
  # The 1Password desktop app package drops its own repo into
  # /etc/apt/sources.list.d/, so on a box that already has the app this is
  # usually just a cache refresh. Add the repo only if it is genuinely missing.
  if ! grep -rqs 'downloads.1password.com' /etc/apt/sources.list.d/ 2>/dev/null; then
    echo "1password: adding apt repository (requires sudo)"
    curl -sS https://downloads.1password.com/linux/keys/1password.asc |
      sudo gpg --dearmor --yes --output /usr/share/keyrings/1password-archive-keyring.gpg
    local arch
    arch="$(dpkg --print-architecture)"
    echo "deb [arch=${arch} signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/${arch} stable main" |
      sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
    sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
    curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol |
      sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol >/dev/null
  fi

  echo "1password: installing 1password-cli (requires sudo)"
  sudo apt-get update -qq
  sudo apt-get install -y 1password-cli
}

install_op_rpm_ostree() {
  cat <<'EOF'
1password: not installed. On Fedora Atomic, layer it (needs a reboot):
    sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
    sudo tee /etc/yum.repos.d/1password.repo >/dev/null <<'REPO'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
REPO
    sudo rpm-ostree install 1password-cli
    systemctl reboot
Then re-run ./install.sh.
EOF
  return 1
}

if ! command -v op >/dev/null 2>&1; then
  case "$(pkg_manager)" in
    apt) install_op_apt ;;
    rpm-ostree) install_op_rpm_ostree || exit 0 ;;
    dnf)
      echo "1password: install 1password-cli from the 1Password RPM repo, then re-run"
      exit 0
      ;;
    *)
      echo "1password: no known install path for this system ($(pkg_manager)); skipping"
      exit 0
      ;;
  esac
fi

seed_env_file
seed_autoload_file

cat <<'EOF'
1password: done. To finish, in the 1Password desktop app:
  1. Settings > Security      -> turn on "Unlock using system authentication"
  2. Settings > Developer     -> turn on "Integrate with 1Password CLI"
Then add your references to ~/.config/op/env and use:
    opload            # export the secrets into this shell
    oprun -- cmd ...  # run cmd with them injected, leaving the shell clean
EOF
