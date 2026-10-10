#!/usr/bin/env bash
# Seed the untracked secret-reference files that bashrc's opload/oprun helpers
# read, on local desktops. A final hook in config/mise/config.desktop.toml. The
# 1Password CLI (op) itself is a mise tool (config/mise/common.toml).
#
# No secret ever lands in this repo. ~/.config/op/env holds only op:// URIs,
# which are references resolved at runtime against the vault -- useless on their
# own without an authenticated 1Password session.
set -euo pipefail

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
