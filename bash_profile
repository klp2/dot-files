# shellcheck shell=bash
# Load .bashrc
if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi

test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
