#!/usr/bin/env bash
# lazy.nvim plugins. A final hook in config/mise/base.toml, so it runs on every
# machine after the links and tools are in place; neovim itself is a mise tool
# (config/mise/common.toml).

set -eu -o pipefail

# Run Lazy sync if nvim is available (install/update plugins); bootstrap has
# already linked init.lua from base.toml
if command -v nvim &>/dev/null; then
  echo "Syncing neovim plugins..."
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
fi

exit 0
