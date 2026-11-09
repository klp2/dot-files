#!/usr/bin/env bash

set -eu -o pipefail

# Linux ping sockets are gated by the caller's group ID. Keep the exception to
# this user's primary group instead of granting raw sockets to the binary.
[[ "$(uname -s)" == Linux ]] || exit 0
command -v octomon >/dev/null || exit 0

gid=$(id -g)
read -r first last </proc/sys/net/ipv4/ping_group_range
if ((first <= gid && gid <= last)); then
  exit 0
fi

setting="net.ipv4.ping_group_range = $gid $gid"
config=/etc/sysctl.d/90-octomon-ping.conf
if ! printf '%s\n' "$setting" | sudo tee "$config" >/dev/null; then
  echo "WARNING: Octomon needs ping sockets for group $gid. Run: sudo sysctl -w net.ipv4.ping_group_range=\"$gid $gid\"" >&2
  exit 0
fi
if ! sudo sysctl -p "$config"; then
  echo "WARNING: Could not enable Octomon ping sockets from $config" >&2
fi
