#!/usr/bin/env bash

set -eu -o pipefail

SELF_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

source "$SELF_PATH"/bash_functions.sh
source "$SELF_PATH"/bash_common.sh

# Parse arguments
FORCE_MODE=""
UPGRADE="yes"
AUTO_YES=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --fresh)
      FORCE_MODE="fresh"
      shift
      ;;
    --update)
      FORCE_MODE="update"
      shift
      ;;
    --no-upgrade)
      UPGRADE=""
      shift
      ;;
    --yes)
      AUTO_YES="yes"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Detect install mode or use forced mode
if [[ -n "$FORCE_MODE" ]]; then
  INSTALL_MODE="$FORCE_MODE"
elif [[ ! -L ~/.bashrc ]] || [[ "$(readlink -f ~/.bashrc 2>/dev/null)" != "$SELF_PATH/bashrc" ]]; then
  INSTALL_MODE="fresh"
else
  INSTALL_MODE="update"
fi

echo "=== Dotfiles $INSTALL_MODE ==="
echo ""

mkdir -p ~/.config
mkdir -p ~/.vimundo

if ! [ -d ~/bin ]; then
  mkdir ~/bin
fi

# Migrate old marker files to new naming scheme
if [[ -e "$HOME/.laptop" && ! -e "$HOME/.local-work" ]]; then
  echo "Migrating ~/.laptop → ~/.local-work"
  mv "$HOME/.laptop" "$HOME/.local-work"
fi
if [[ -e "$HOME/.desktop" && ! -e "$HOME/.local-personal" ]]; then
  echo "Migrating ~/.desktop → ~/.local-personal"
  mv "$HOME/.desktop" "$HOME/.local-personal"
fi

# Re-source after migration so detect_envtype sees new markers
source "$SELF_PATH"/bash_common.sh
envtype=$DOTFILES_ENVTYPE

# Create marker file if none exists
if [[ ! -e "$HOME/.devcontainer-work" && ! -e "$HOME/.local-work" && ! -e "$HOME/.local-personal" &&
  ! -e "$HOME/.remote-work" && ! -e "$HOME/.remote-personal" ]]; then
  echo ""
  echo "=== Environment Detection ==="
  echo "No marker file found (~/.local-work, ~/.local-personal, etc.)"
  echo "Running heuristic detection..."
  local_graphical="no"
  local_graphical_detail="${XDG_SESSION_TYPE:-tty}"
  if [[ "${XDG_SESSION_TYPE:-}" == "x11" || "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    local_graphical="yes"
  fi
  local_mm="no"
  local_hostname=$(detect_hostname)
  if is_maxmind; then
    local_mm="yes"
  fi
  echo "  Graphical session: $local_graphical  (XDG_SESSION_TYPE=$local_graphical_detail)"
  echo "  MaxMind hostname:  $local_mm  (hostname=$local_hostname)"
  echo "  Result: $envtype"
  touch "$HOME/.$envtype"
  echo "Creating ~/.$envtype"
  echo "To change, delete this file and create the correct one (e.g. ~/.remote-work)"
  echo ""
fi

# Download an installer script, show its size and hash, and run it only once
# confirmed (or with --yes). Fails if the download fails or the user declines.
run_reviewed_installer() {
  local name="$1" url="$2" script rc
  script=$(mktemp "/tmp/$name-install.XXXXXX")
  if ! curl -fsSL "$url" -o "$script"; then
    echo "Failed to download the $name installer."
    rm -f "$script"
    return 1
  fi
  echo "Downloaded to: $script"
  echo "Size: $(wc -c <"$script") bytes, $(wc -l <"$script") lines"
  echo "SHA256: $(sha256sum "$script" | cut -d' ' -f1)"
  echo ""
  echo "Review with: less $script"
  if [[ -z "$AUTO_YES" ]]; then
    read -p "Run $name installer? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Skipping $name installation."
      rm -f "$script"
      return 1
    fi
  fi
  rc=0
  bash "$script" || rc=$?
  rm -f "$script"
  return $rc
}

# mise: dotfile links everywhere, plus CLI tools, runtimes, and packages
# everywhere but remote-work, which stays minimal.
# Use the standalone mise in ~/.local/bin, which self-updates without brew,
# unless a non-brew mise is already provided (e.g. the devcontainer image) that
# is new enough to have `mise dotfiles`.
brew_mise=""
if command -v brew &>/dev/null && brew list --formula mise &>/dev/null; then
  brew_mise="yes"
fi
if [[ ! -x ~/.local/bin/mise ]] && { [[ -n "$brew_mise" ]] || ! mise dotfiles --help &>/dev/null; }; then
  echo ""
  echo "=== mise Setup ==="
  run_reviewed_installer mise https://mise.run || true
fi
export PATH="$HOME/.local/bin:$PATH"
if [[ -n "$brew_mise" && -x ~/.local/bin/mise ]]; then
  echo "Removing Homebrew's mise (replaced by ~/.local/bin/mise)..."
  brew uninstall mise || echo "WARNING: could not uninstall Homebrew's mise; ~/.local/bin/mise still takes precedence."
fi
if ! mise dotfiles --help &>/dev/null; then
  echo "ERROR: linking the dotfiles needs a mise with 'mise dotfiles'; rerun once it is installed."
  exit 1
fi
# base.toml before self-update, which reads its minimum_release_age
mkdir -p ~/.config/mise/conf.d
ln -sf "$SELF_PATH"/config/mise/base.toml ~/.config/mise/conf.d/05-base.toml
# The mise envs this machine selects, which base.toml's variants and the
# config.<env>.toml files key on: the envtype, plus "desktop" on local machines
mise_envs="\"$envtype\""
if [[ $envtype == local-* ]]; then
  mise_envs="\"desktop\", $mise_envs"
fi
printf '# Written by install.sh from the ~/.%s marker\nenv = [%s]\n' "$envtype" "$mise_envs" >~/.config/mise/miserc.toml
# The tool configs install.sh used to link are base.toml variants in conf.d
# now. A regular config.toml (the devcontainer image's) is not ours; keep it.
for f in ~/.config/mise/config.toml ~/.config/mise/conf.d/50-personal.toml; do
  if [[ -L $f && $(readlink "$f") == */config/mise/mise.*.toml ]]; then
    rm "$f"
  fi
done
if [[ -n "$UPGRADE" && -x ~/.local/bin/mise ]]; then
  mise self-update --yes || true
fi

# The links go first, so the conf.d tool configs and config.<env>.toml files
# are in place before the mise commands below load them. --force replaces
# whatever is at a target, as `ln -sf` did.
if [[ "$SELF_PATH" != "$(cd -P ~/dot-files 2>/dev/null && pwd -P)" ]]; then
  echo "WARNING: base.toml links to ~/dot-files, not this checkout ($SELF_PATH)."
fi
echo "Linking dotfiles..."
mise dotfiles apply --force --yes
# ackrc and perlcriticrc left the repo long ago; drop the links left dangling
for f in ~/.ackrc ~/.perlcriticrc; do
  if [[ -L $f && ! -e $f ]]; then
    rm "$f"
  fi
done

if [[ $envtype != 'remote-work' ]]; then
  # A tool that fails to install is reported, not fatal: mise still installs
  # the rest, and the next run retries it.
  echo "Installing mise tools..."
  MISE_LOCKED=0 mise install --quiet || echo "WARNING: some mise tools failed to install (see above)."
  # The lockfile pins "latest" tools to whatever resolved at first install,
  # so `mise install` alone never moves them forward.
  if [[ -n "$UPGRADE" ]]; then
    echo "Upgrading mise tools..."
    MISE_LOCKED=0 mise upgrade --quiet || echo "WARNING: some mise tools failed to upgrade (see above)."
  fi
  MISE_LOCKED=0 mise lock --global --quiet
  # Locking records npm tools against a lock artifact, and mise reports them
  # missing until they are reinstalled from it
  MISE_LOCKED=0 mise install --quiet || echo "WARNING: some mise tools failed to install (see above)."
  # Shims are symlinks to the mise binary, so repoint them if it moved
  mise reshim
  export PATH="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$PATH"

  # Bash completions, loaded on demand by bash-completion (see bashrc)
  comp_dir="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
  mkdir -p "$comp_dir"
  while read -r cmd gen; do
    command -v "$cmd" &>/dev/null || continue
    # shellcheck disable=SC2086  # $gen is a command line, split on purpose
    if $gen >"$comp_dir/$cmd.tmp" 2>/dev/null; then
      mv "$comp_dir/$cmd.tmp" "$comp_dir/$cmd"
    else
      rm -f "$comp_dir/$cmd.tmp"
    fi
  done <<'EOF'
ast-grep ast-grep completions bash
bat bat --completion bash
delta delta --generate-completion bash
fd fd --gen-completions bash
gh gh completion -s bash
glow glow completion bash
golangci-lint golangci-lint completion bash
goreleaser goreleaser completion bash
just just --completions bash
mise mise completion bash
rg rg --generate complete-bash
sqlc sqlc completion bash
starship starship completions bash
zellij zellij setup --generate-completion bash
EOF
fi

# The rest of the setup is `mise bootstrap`, from base.toml and the selected
# config.<env>.toml files: their hooks run install/*.sh. Packages get a run of
# their own, because a failed package aborts a bootstrap run and these were
# never fatal; their pre-packages hooks (Flathub remote, keyd) run with them.
echo "Installing bootstrap packages..."
mise bootstrap --only packages --yes || echo "WARNING: some bootstrap packages failed to install (see above)."
if [[ -n "$UPGRADE" ]]; then
  mise bootstrap packages upgrade --yes || echo "WARNING: some bootstrap packages failed to upgrade (see above)."
fi
# Repos (tpm) too, so a failed clone or pull doesn't stop the rest. Bootstrap
# only clones a missing repo; update also fast-forwards the existing ones.
echo "Updating bootstrap repos..."
if [[ -n "$UPGRADE" ]]; then
  mise bootstrap repos update --yes || echo "WARNING: some bootstrap repos failed to update (see above)."
else
  mise bootstrap repos apply --yes || echo "WARNING: some bootstrap repos failed to clone (see above)."
fi
# Files, services, links, and the final hooks (vim, neovim, 1Password, KDE
# tiling). Tools were installed above, outside the lock.
echo "Running mise bootstrap..."
mise bootstrap --skip packages,repos,tools --force-dotfiles --yes

# Alacritty terminal config (only if alacritty is installed)
if command -v alacritty &>/dev/null; then
  mkdir -p ~/.config/alacritty
  ln -sf "$SELF_PATH"/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml
fi

# i3 configs on a personal box, only when i3 is actually installed (the work
# laptop gets them from base.toml). has_i3 rather than a session check, because
# the personal laptop may be installed from its GNOME session but still needs
# these in place for the next i3 login; the check keeps ~/.config/i3 off the
# KDE box.
if [[ $envtype == 'local-personal' ]] && has_i3; then
  ln -sfn "$SELF_PATH"/i3 ~/.config/i3
  ln -sfn "$SELF_PATH"/i3status ~/.config/i3status
fi

# Regolith 3: tracked Xresources and i3status-rust config.
# Machine-specific overrides (wallpaper, look theme) go in the un-tracked
# ~/.config/regolith3/Xresources.d/local, included via cpp by the main file.
if [[ ($envtype == 'local-work' || $envtype == 'local-personal') && -d /etc/regolith ]]; then
  mkdir -p ~/.config/regolith3/i3status-rust ~/.config/regolith3/Xresources.d
  ln -sf "$SELF_PATH"/regolith3/Xresources ~/.config/regolith3/Xresources
  ln -sf "$SELF_PATH"/regolith3/i3status-rust/config.toml ~/.config/regolith3/i3status-rust/config.toml
  if [[ ! -e ~/.config/regolith3/Xresources.d/local ]]; then
    cat >~/.config/regolith3/Xresources.d/local <<'EOF'
! Machine-specific Regolith 3 overrides — not tracked in dotfiles.
! Examples:
!   regolith.wallpaper.file: /path/to/wallpaper.webp
!   regolith.lockscreen.wallpaper.file: /path/to/wallpaper.webp
!   regolith.look.path: /usr/share/regolith-look/dracula
EOF
  fi
fi

if ! [ -d ~/.ssh/keys ]; then
  mkdir -p ~/.ssh/keys
fi

git submodule init
git submodule update

./git-config.sh

# Install git hooks for this repo
ln -sf ../../hooks/pre-commit .git/hooks/pre-commit
ln -sf ../../hooks/pre-push .git/hooks/pre-push

# Run cleanup for updates only (interactive, skip with --yes)
if [[ "$INSTALL_MODE" == "update" && -z "$AUTO_YES" ]]; then
  echo ""
  echo "=== Checking for deprecated tools ==="
  "$SELF_PATH"/cleanup.sh
fi

# Warn about machine-local path pins in ~/.local-bashrc that no longer
# resolve — e.g. LOCAL_REVIEW_LLAMA pinning a versioned llama.cpp build dir,
# or a model snapshot path, after an upgrade replaced it. Checks every
# exported variable whose value is an absolute path.
if [ -f "$HOME/.local-bashrc" ]; then
  while IFS= read -r pinvar; do
    pinval="$(bash -c ". \"\$HOME/.local-bashrc\" >/dev/null 2>&1; printf '%s' \"\${$pinvar-}\"")"
    case "$pinval" in
      /*)
        if [ ! -e "$pinval" ]; then
          echo "WARNING: ~/.local-bashrc pins $pinvar=$pinval, which does not exist — update the pin"
        fi
        ;;
    esac
  done < <(grep -oE '^export [A-Za-z_][A-Za-z0-9_]*' "$HOME/.local-bashrc" | cut -d' ' -f2)
fi

# One-time nudge: the gcloud ssh speed-up from the deleted master branch was
# never carried over, and it belongs in the work laptop's ~/.local-bashrc. Goes
# quiet once CLOUDSDK_PYTHON appears there; remove this block after that.
if [[ $envtype == 'local-work' ]] && ! grep -qs 'CLOUDSDK_PYTHON' "$HOME/.local-bashrc"; then
  echo ""
  echo "NOTE: if you still use 'gcloud ssh', this speeds it up (add to ~/.local-bashrc):"
  # shellcheck disable=SC2016  # printed for the user to copy, not expanded here
  echo '  export CLOUDSDK_PYTHON=$(which python3) CLOUDSDK_PYTHON_SITEPACKAGES=1'
  echo "  Not wanted? Add a '# CLOUDSDK_PYTHON: skip' comment there to silence this."
fi

# Show post-install message
echo ""
if [[ "$INSTALL_MODE" == "fresh" ]]; then
  echo "=== Fresh install complete ==="
  echo "Run 'source ~/.bashrc' to load your new shell config"
  echo "Run './cleanup.sh' later to remove any old tools"
else
  echo "=== Update complete ==="
fi

# Record timestamp for weekly reminder system
date +%s >"$HOME/.dotfiles-last-update"
