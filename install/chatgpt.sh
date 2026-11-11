#!/usr/bin/env bash
# Official Linux desktop app and daily APT updates on supported Debian/Ubuntu.
# https://learn.chatgpt.com/docs/linux/linux-app
set -euo pipefail

# shellcheck source=/dev/null
source /etc/os-release
case "$ID:$VERSION_ID" in
  ubuntu:24.04 | ubuntu:26.04 | debian:13) ;;
  *) exit 0 ;;
esac

arch=$(dpkg --print-architecture)
case "$arch" in
  amd64 | arm64) ;;
  *) exit 0 ;;
esac

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
as_root=()
if ((EUID != 0)); then
  as_root=(sudo)
fi

if [[ $(dpkg-query -W -f='${Status}' chatgpt 2>/dev/null || true) != 'install ok installed' ]]; then
  # An optional already-downloaded official .deb avoids downloading it twice.
  deb=${1:-}
  if [[ -z $deb ]]; then
    download_dir=$(mktemp -d)
    trap 'rm -rf "$download_dir"' EXIT
    chmod 0755 "$download_dir"
    deb="$download_dir/chatgpt_${arch}.deb"
    curl --proto '=https' --tlsv1.2 -fL -o "$deb" \
      "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_${arch}.deb"
  fi
  [[ $(dpkg-deb -f "$deb" Package) == chatgpt ]]
  [[ $(dpkg-deb -f "$deb" Architecture) == "$arch" ]]
  "${as_root[@]}" apt-get install -y "$deb"
fi

if [[ ! -f /etc/apt/sources.list.d/chatgpt.sources ]]; then
  echo 'chatgpt: OpenAI APT repository is missing; automatic updates cannot be configured.' >&2
  exit 1
fi

if [[ $(dpkg-query -W -f='${Status}' unattended-upgrades 2>/dev/null || true) != 'install ok installed' ]]; then
  "${as_root[@]}" apt-get update
  "${as_root[@]}" apt-get install -y unattended-upgrades
fi

"${as_root[@]}" install -m 0644 "$repo_dir/config/apt/52chatgpt-updates" \
  /etc/apt/apt.conf.d/52chatgpt-updates
"${as_root[@]}" systemctl enable --now apt-daily.timer apt-daily-upgrade.timer
echo 'chatgpt: installed; daily updates enabled through unattended-upgrades.'
