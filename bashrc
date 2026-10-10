# shellcheck shell=bash
## Prompt originally by cynikal at NYI, with some tweaks over the years
## The rest of the file influenced heavily by
## https://raw.githubusercontent.com/oalders/dot-files/master/bashrc
## when updating in 2017, as its been a long time since I've used bash

# Source shared environment detection
if [[ -f ~/.bash_common.sh ]]; then
  source ~/.bash_common.sh
fi

# Use exported variables from bash_common.sh (with fallbacks)
platform=${DOTFILES_PLATFORM:-unknown}
hostname=${DOTFILES_HOSTNAME:-$(hostname)}
envtype=${DOTFILES_ENVTYPE:-remote-work}

# Fix missing terminfo in containers (e.g. alacritty not in container's terminfo db)
if [[ $envtype == 'devcontainer-work' ]] && ! infocmp "$TERM" &>/dev/null; then
  export TERM=xterm-256color
fi
# COLORTERM is not forwarded over the devpod ssh hop
export COLORTERM="${COLORTERM:-truecolor}"

# Remind to update dotfiles weekly
check_dotfiles_update_reminder() {
  # Skip for non-interactive shells (scp, rsync-over-ssh, ssh <host> <cmd>, …):
  # any stdout here corrupts scp's protocol stream.
  [[ $- == *i* ]] || return

  local update_file="$HOME/.dotfiles-last-update"
  local week_seconds=604800

  [[ -f "$update_file" ]] || return

  local last_update current_time
  last_update=$(cat "$update_file")
  current_time=$(date +%s)

  if ((current_time - last_update > week_seconds)); then
    echo "Reminder: dotfiles haven't been updated in over a week. Run ~/dot-files/install.sh"
  fi
}
check_dotfiles_update_reminder

if [[ $envtype == 'local-work' ]] && command -v mm-perl &>/dev/null; then
  alias perl=mm-perl
fi

# use vim mappings to move around the command line
set -o vi

# http://superuser.com/questions/39751/add-directory-to-path-if-its-not-already-there
pathadd() {
  if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
    PATH="$1:$PATH"
  fi
}

# PATH, set up early: the 1Password block below needs op (from brew), and
# everything that checks for fzf, bat, eza, starship, or zoxide needs mise.
# pathadd prepends, so these run from lowest priority to highest; mise
# activate then puts its tools ahead of all of them.
if [[ $envtype != 'remote-work' ]]; then
  pathadd "/home/linuxbrew/.linuxbrew/bin"
  # Homebrew 7 asks before every install and upgrade; don't
  export HOMEBREW_NO_ASK=1
  alias brewski='brew update && brew upgrade && brew cleanup; brew doctor'
fi
pathadd "/usr/local/sbin"
pathadd "/usr/local/bin"
pathadd "$HOME/bin"
pathadd "$HOME/.cargo/bin"
pathadd "$HOME/.opencode/bin"
pathadd "$HOME/.local/bin"

# mise - CLI tools and runtimes, plus the environment variables and aliases
# from [env] and [shell_alias] (config in ~/dot-files/config/mise). Every
# machine activates it; remote-work just has no tools.
if command -v mise &>/dev/null; then
  # activate applies the tool PATH, env, and aliases right away and again from
  # a prompt hook, and puts the shims behind it as the fallback for anything
  # that does not source this file: a git hook inherits PATH from whatever
  # shell ran git. Needed by gaem, whose mise.toml pins gh and jq for scripts
  # that run non-interactively.
  eval "$(mise activate bash)"
elif [[ $- == *i* ]]; then
  echo "mise not found, so its aliases and environment are missing. Run ~/dot-files/install.sh" >&2
fi

# Keyboard remaps: X11 fallback for machines without keyd (local envtypes).
# keyd works at the kernel layer and covers Wayland too, so wherever it is
# running it owns both the Caps remap and the both-Shift Caps Lock toggle (see
# keyd/default.conf); xcape and setxkbmap must stay out of the way, or keys end
# up double-bound. Session type is checked at runtime rather than by envtype
# because this laptop alternates between GNOME/Wayland and i3/X11.
if [[ $envtype == 'local-work' || $envtype == 'local-personal' ]]; then
  if [[ $platform == 'linux' && "$XDG_SESSION_TYPE" == "x11" ]] &&
    ! systemctl is-active --quiet keyd 2>/dev/null; then
    # Caps is remapped away, so recover capslock via both shift keys together
    if command -v setxkbmap &>/dev/null; then
      setxkbmap -option shift:both_capslock
    fi
    if command -v xcape &>/dev/null; then
      xcape -e 'Control_L=Escape'
    fi
  fi
fi

# Default browser (local envtypes only; meaningless over SSH)
if [[ $envtype == 'local-personal' ]]; then
  export BROWSER=firefox
elif [[ $envtype == 'local-work' ]]; then
  export BROWSER=google-chrome
fi

# 1Password-backed secrets.
# ~/.config/op/env maps NAME=op://Vault/Item/field and is untracked; it holds
# references, never values. Secrets belong here or in ~/.local-bashrc, never in
# a tracked file.
#
# References resolve on demand by default: `op read` talks to the desktop app and
# can raise a biometric prompt, so opload/oprun fetch only when asked. Names
# listed in ~/.config/op/autoload are the exception -- tools like linearis and gh
# expect them already exported -- and are resolved once per session by
# __op_autoload below.
#
# The autoload selection is a separate file rather than an inline marker because
# $OP_ENV_FILE has to stay valid op dotenv syntax for `op run` to parse it.
if command -v op &>/dev/null; then
  export OP_ENV_FILE="${OP_ENV_FILE:-$HOME/.config/op/env}"
  export OP_AUTOLOAD_FILE="${OP_AUTOLOAD_FILE:-$HOME/.config/op/autoload}"

  # opload -- export every reference in $OP_ENV_FILE into the current shell
  opload() {
    if [[ ! -f "$OP_ENV_FILE" ]]; then
      echo "opload: no $OP_ENV_FILE (run install/1password.sh)" >&2
      return 1
    fi
    local name ref value
    while IFS='=' read -r name ref; do
      [[ -z "$name" || "$name" == \#* ]] && continue
      [[ "$ref" != op://* ]] && continue
      if ! value=$(op read "$ref" 2>/dev/null); then
        echo "opload: could not read $name from $ref" >&2
        continue
      fi
      export "$name=$value"
      echo "opload: exported $name"
    done <"$OP_ENV_FILE"
  }

  # oprun -- run a command with the secrets injected, leaving this shell clean
  oprun() {
    op run --env-file="$OP_ENV_FILE" -- "$@"
  }

  # __op_autoload -- export the names in $OP_AUTOLOAD_FILE, once per session.
  # The resolved values are cached in $XDG_RUNTIME_DIR (tmpfs, 0600, cleared at
  # logout), so only the first shell of a session pays the op call and any
  # biometric prompt; later shells read the cache. The cache is rebuilt when
  # either source file changes.
  # A failed read exports nothing rather than an empty string, so a locked or
  # offline 1Password leaves an existing value in the environment intact.
  __op_autoload() {
    local cache="${XDG_RUNTIME_DIR:-/tmp}/op-autoload.env"
    local name ref value tmp
    local -A want=() seen=()

    if [[ -s $cache && ! $OP_ENV_FILE -nt $cache && ! $OP_AUTOLOAD_FILE -nt $cache ]]; then
      while IFS='=' read -r name value || [[ -n $name ]]; do
        [[ -n $name ]] && export "$name=$value"
      done <"$cache"
      return 0
    fi

    [[ -f $OP_ENV_FILE && -f $OP_AUTOLOAD_FILE ]] || return 0

    while read -r name || [[ -n $name ]]; do
      name="${name%%#*}"
      name="${name//[[:space:]]/}"
      [[ -n $name ]] && want[$name]=1
    done <"$OP_AUTOLOAD_FILE"
    ((${#want[@]})) || return 0

    tmp="$(mktemp "$cache.XXXXXX")" || return 0
    while IFS='=' read -r name ref || [[ -n $name ]]; do
      [[ -z $name || $name == \#* || $ref != op://* ]] && continue
      [[ -n ${want[$name]:-} ]] || continue
      # One op call per distinct reference: several names may share a secret
      if [[ -n ${seen[$ref]+set} ]]; then
        value="${seen[$ref]}"
      else
        value="$(op read "$ref" 2>/dev/null)" || value=''
        seen[$ref]="$value"
      fi
      [[ -n $value ]] || continue
      export "$name=$value"
      printf '%s=%s\n' "$name" "$value" >>"$tmp"
    done <"$OP_ENV_FILE"

    if [[ -s $tmp ]]; then
      chmod 600 "$tmp" && mv -f "$tmp" "$cache"
    else
      rm -f "$tmp"
    fi
  }
  __op_autoload
fi

# SSH agent (local envtypes only).
# Prefer 1Password where it is running: ssh already routes to it via
# IdentityAgent in ~/.ssh/config.d/1password.conf, so pointing SSH_AUTH_SOCK at
# the same socket keeps ssh-add and other agent-aware tools consistent with what
# ssh actually uses instead of reporting a different agent's keys.
# gpg-agent stays the fallback for boxes without 1Password (and the guard means
# no error on hosts with no gpgconf at all).
if [[ $envtype == 'local-work' || $envtype == 'local-personal' ]]; then
  if [[ $platform == 'linux' ]]; then
    if [[ -S "$HOME/.1password/agent.sock" ]]; then
      export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
    elif command -v gpgconf &>/dev/null; then
      export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    fi
  fi
fi

# don't put duplicate lines in the history. See bash(1) for more options
# http://www.linuxjournal.com/content/using-bash-history-more-efficiently-histcontrol
export HISTCONTROL=ignoreboth
export HISTTIMEFORMAT="%F %T "

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
export HISTSIZE=10000
export HISTFILESIZE=1048576

## http://eli.thegreenplace.net/2013/06/11/keeping-persistent-history-in-bash
log_bash_persistent_history() {
  [[ $(history 1) =~ ^\ *[0-9]+\ +([^\ ]+\ [^\ ]+)\ +(.*)$ ]]
  local date_part="${BASH_REMATCH[1]}"
  local command_part="${BASH_REMATCH[2]}"
  if [ "$command_part" != "$PERSISTENT_HISTORY_LAST" ]; then
    echo "$date_part" "|" "$command_part" >>~/.persistent_history
    export PERSISTENT_HISTORY_LAST="$command_part"
  fi
}

run_on_prompt_command() {
  log_bash_persistent_history
}

PROMPT_COMMAND="run_on_prompt_command"

# partial search
if [[ $- == *i* ]]; then
  bind '"\e[A": history-search-backward'
  bind '"\e[B": history-search-forward'
fi

# search history (use rg for ripgrep)
hist() { history | rg "$1"; }

# cp with preservation of all inode information
tarcp() { tar cvf - . | (cd "$1" && tar xvf -); }

# Sync devcontainer-local config then start devcontainer
devup() {
  dev/bin/general/deploy-devcontainer-local
  devpod up . --open-ide=false "$@"
}

# Wrapper for mssh to set compatible TERM for remote servers
# Remote GCP hosts often lack alacritty terminfo
mssh() {
  TERM=xterm-256color command mssh "$@"
}

# fzf shell integration (keybindings: Ctrl-R, Ctrl-T, Alt-C + tab completion);
# its FZF_* settings are [env] in config/mise/common.toml
if command -v fzf &>/dev/null; then
  eval "$(fzf --bash)"

  # Git helpers powered by fzf
  # For more comprehensive git+fzf, see: https://github.com/junegunn/fzf-git.sh
  gsw() {
    local branch
    branch=$(git branch --sort=-committerdate --format='%(refname:short)' 2>/dev/null | fzf --header="Switch branch") &&
      git switch "$branch"
  }

  glog() {
    git log --oneline --color=always --decorate |
      fzf --ansi --no-sort --preview 'git show --color=always {1}' \
        --bind 'enter:execute(git show --color=always {1} | less -R)'
  }

  gstash() {
    local stash
    stash=$(git stash list --color=always |
      fzf --ansi --no-sort --preview 'git stash show -p --color=always {1}' |
      cut -d: -f1) &&
      git stash pop "$stash"
  }
fi

# The other aliases and exported settings (vi, git, eza, bat, EDITOR, ...) are
# [shell_alias] and [env] in config/mise: base.toml everywhere, common.toml
# where mise installs the tools they need. mise activate (above) sets them.

# rg and fd are NOT drop-in replacements - they reject standard syntax outright
# (`grep -E 'a|b'` and `find . -name '*.md'` both exit 2), which silently breaks
# any non-interactive consumer of this file. Invoke rg/fd by name when wanted.
if [[ $- == *i* ]]; then
  command -v fd &>/dev/null && alias find='fd'
  command -v rg &>/dev/null && alias grep='rg'
fi
# zoxide init moved to end of file (required by zoxide)

function diffcol() {
  awk -v col="$1" 'NR==FNR{c[col]++;next};c[col] == 0' "$3" "$2"
  awk -v col="$1" 'NR==FNR{c[col]++;next};c[col] == 0' "$2" "$3"
}

[ -f "$HOME/.local-bashrc" ] && source "$HOME/.local-bashrc"

# clean up PATH
# http://linuxg.net/oneliners-for-removing-the-duplicates-in-your-path/
PATH=$(echo -n "$PATH" | awk -v RS=: -v ORS=: '!arr[$0]++')
# ORS leaves a trailing colon, an empty entry that puts the cwd on PATH
PATH=${PATH%:}

# lazy add ssh keys
if [[ -d "$HOME/.ssh/keys" ]]; then
  for key in "$HOME"/.ssh/keys/*; do
    [[ -f "$key" ]] && ssh-add "$key" &>/dev/null
  done
fi

# shellcheck disable=SC1087  # False positive: \[ in PS1 is not array syntax
function cynprompt {

  local GRAY="\[\033[1;30m\]"
  local LIGHT_GRAY="\[\033[0;37m\]"
  local CYAN="\[\033[0;36m\]"
  local LIGHT_CYAN="\[\033[1;36m\]"
  local BLUE="\[\033[0;34m\]"
  local LIGHT_BLUE="\[\033[1;34m\]"
  local WHITE="\[\033[1;37m\]"
  local RED="\[\033[0;31m\]"

  case $(id -u) in
    0)
      local PROMPT="#"
      ;;
    *)
      local PROMPT="$"
      ;;
  esac

  local WITH_AGENT=""
  if [ -n "$SSH_AUTH_SOCK" ]; then
    WITH_AGENT+="🔑"
  fi

  local TITLEBAR='\[\033]0;\u@\h:\w\007\]'

  local GRAD1=$(tty | cut -d/ -f3-)
  PS1="$TITLEBAR$GRAY=$LIGHT_GRAY=$WHITE<\
$LIGHT_CYAN\u$CYAN@$LIGHT_CYAN\h\
$WHITE>${LIGHT_GRAY}-$GRAY<\
$LIGHT_BLUE$GRAD1$GRAY>${LIGHT_GRAY}-$WHITE<\
$LIGHT_GRAY\$(date +%H:%M:%S)\
$WHITE>$LIGHT_GRAY=$GRAY=$LIGHT_CYAN\$(git-prompt-fallback 2>/dev/null) $WITH_AGENT$LIGHT_GRAY\n\
<$RED$SHLVL$LIGHT_GRAY> $GRAY-$BLUE-$LIGHT_BLUE[\
$CYAN\w\
$LIGHT_BLUE]$BLUE-$GRAY-$LIGHT_GRAY $WHITE$PROMPT $LIGHT_GRAY"
  PS2="$LIGHT_CYAN-$CYAN-$GRAY-$LIGHT_GRAY "
}

# Use starship if available, otherwise fall back to cynprompt
if command -v starship &>/dev/null; then
  eval "$(starship init bash)"
else
  cynprompt
fi

# bash-completion loads completions on demand: git's, and the ones install.sh
# generates for mise tools in ~/.local/share/bash-completion/completions
if [[ $- == *i* && -f /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
elif [ -f /usr/share/bash-completion/completions/git ]; then
  source /usr/share/bash-completion/completions/git
fi

# Completions for the remaining Linuxbrew formulae
if [ -d /home/linuxbrew/.linuxbrew/etc/bash_completion.d ]; then
  for f in /home/linuxbrew/.linuxbrew/etc/bash_completion.d/*; do
    [ -f "$f" ] && source "$f"
  done
fi

# zoxide - must be at end of bashrc
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"
