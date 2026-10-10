#!/usr/bin/env bash
# Interactive cleanup of deprecated tools and configs
# Run periodically to remove things no longer used

set -eu -o pipefail

echo "Checking for deprecated tools and configs..."
echo ""

# Helper function for interactive removal
ask_remove() {
  local name="$1"
  local path="$2"
  local description="$3"

  if [[ -e "$path" ]]; then
    echo "Found: $name"
    echo "  Path: $path"
    echo "  Note: $description"
    read -p "  Remove? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "$path"
      echo "  Removed."
    else
      echo "  Kept."
    fi
    echo ""
  fi
}

# Deprecated tools
ask_remove "Facebook PathPicker (fpp)" \
  "$HOME/local/src/PathPicker" \
  "Superseded by fzf, telescope, lazygit"

ask_remove "fpp symlink" \
  "$HOME/local/bin/fpp" \
  "Symlink to PathPicker"

ask_remove "Old Perl git-prompt" \
  "$HOME/bin/git-prompt" \
  "Replaced by starship + git-prompt-fallback"

ask_remove "Old mm-git-prompt" \
  "$HOME/bin/mm-git-prompt" \
  "Replaced by starship + git-prompt-fallback"

# Old vim plugin managers (if vim-plug is now standard)
ask_remove "Vundle" \
  "$HOME/.vim/bundle/Vundle.vim" \
  "Replaced by vim-plug"

ask_remove "Old vim bundles" \
  "$HOME/.vim/bundle" \
  "vim-plug uses different directory"

# Deprecated configs
ask_remove "Old packer.nvim" \
  "$HOME/.local/share/nvim/site/pack/packer" \
  "Replaced by lazy.nvim"

# Replaced by mise (config/mise/)
# Hand-made links to nvm's node; checked before ~/.nvm, since ask_remove skips
# a link whose target is already gone
for nvm_link in node npm npx; do
  if [[ "$(readlink "$HOME/.local/bin/$nvm_link" 2>/dev/null)" == "$HOME/.nvm/"* ]]; then
    ask_remove "$nvm_link symlink into nvm" \
      "$HOME/.local/bin/$nvm_link" \
      "Shadows mise's node on PATH"
  fi
done

ask_remove "nvm" \
  "$HOME/.nvm" \
  "Replaced by mise's node; global npm packages need re-adding as npm: tools"

ask_remove "starship in ~/bin" \
  "$HOME/bin/starship" \
  "Replaced by mise's starship"

ask_remove "install-starship.sh" \
  "$HOME/bin/install-starship.sh" \
  "Replaced by mise's starship"

# Homebrew formulae that mise now provides. Each is offered separately, since
# some may also have been installed for reasons outside these dotfiles.
if command -v brew &>/dev/null; then
  BREW_INSTALLED=$(brew list --formula 2>/dev/null)
  for formula in ast-grep bat cmake difftastic docker-compose dust eza fd fzf \
    geoipupdate gh git-delta glow golangci-lint gopls goreleaser jq just \
    lazygit lnav mmdbinspect neovim ripgrep rojo rust shellcheck shfmt sqlc sr \
    starship tailspin tldr tlrc tree-sitter-cli zellij zoxide; do
    grep -qx "$formula" <<<"$BREW_INSTALLED" || continue
    echo "Found: Homebrew $formula"
    echo "  Note: now installed by mise"
    read -p "  Uninstall? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      brew uninstall "$formula" || echo "  Could not uninstall $formula."
    else
      echo "  Kept."
    fi
    echo ""
  done
fi

echo "Cleanup complete."
