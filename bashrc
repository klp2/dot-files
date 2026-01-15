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
envtype=${DOTFILES_ENVTYPE:-remote}

# Remind to update dotfiles weekly
check_dotfiles_update_reminder() {
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

if [[ $envtype == 'laptop' ]] && command -v mm-perl &>/dev/null; then
  alias perl=mm-perl
fi

export EDITOR=vim
export me=$USER

# use vim mappings to move around the command line
set -o vi

# http://superuser.com/questions/39751/add-directory-to-path-if-its-not-already-there
pathadd() {
  if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
    PATH="$1:$PATH"
  fi
}

if [[ $envtype == 'laptop' || $envtype == 'desktop' ]]; then
  if [[ $platform == 'linux' ]]; then
    # xcape only works on X11, not Wayland
    if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
      xcape -e 'Control_L=Escape'
    fi

    if [[ -d "/home/linuxbrew/" ]]; then
      pathadd "/home/linuxbrew/.linuxbrew/bin/"
    fi

    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

    # cleanup homebrew refuse
    alias brewski='brew update && brew upgrade && brew cleanup; brew doctor'
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

# sets the prompt to have the hostname, time, loginname@tty, directory and prompt
# on the next line.. see man bash(1) under PROMPTING
PS1='a\033[00;34m\332\304\260\033[01;34m\260\261\033[01;37;44m \h \033[01;34;40m\261\260\033[00;34m\260\304(\033[01;37m\t\033[00;34m)-(\033[01;37m\u\033[00;34m@\033[01;37m$(basename `tty`)\033[00;34m)\304(\033[01;37m\w/\033[00;34m)\304-\n\300 \033[01;37m\$ \033[00;37;40m'

# uses ls options (colors, formatting)
LS_OPTIONS="--color=auto"
LSCOLORS="ExFxCxDxBxEGEDABAGACAD"

# search history (use rg for ripgrep)
hist() { history | rg "$1"; }

# check tty usage, sorting by tty's
# shellcheck disable=SC2142  # \$7 is awk field reference, not bash positional param
alias ttyuse='ps auxww|awk "\$7 ~ /^p/ && \$7 !~ /-/ {print}"|sort +6'

alias time='NOWTIME=$(date +%s);/usr/bin/time -v -o time.output.$NOWTIME'

# run ls with the specified colors
alias ls="ls $LS_OPTIONS"

# checks the count on given process name
alias pscnt='echo "The current process count is: $(ps ax|wc -l)"'

# lists all the process sorted by pid/cputime
alias allps='ps auxww|sort +1 -n|more'

# lists load averages:
# shellcheck disable=SC2142  # \$1 \$2 \$3 are awk field references, not bash positional params
alias load='uptime|cut -dl -f2-|cut -d: -f2-|awk "{print \" 1 min load average: \" \$1 \"\n 5 min load average: \" \$2 \"\n15 min load average: \" \$3 \".\"}"'

# cp with preservation of all inode information
tarcp() { tar cvf - . | (cd "$1" && tar xvf -); }

alias cdr='cd $(git root)'
alias delete-merged-branches='show-merged-branches | xargs -n 1 git branch -d'
alias ll='ls -alhG'
alias ps='ps auxw'
alias show-merged-branches='git branch --no-color --merged | grep -v "\*" | grep -v main'

# conversions
alias d2b="perl -e 'printf qq|%b\n|, int( shift )'"
alias d2h="perl -e 'printf qq|%X\n|, int( shift )'"
alias d2o="perl -e 'printf qq|%o\n|, int( shift )'"
alias h2b="perl -e 'printf qq|%b\n|, hex( shift )'"
alias h2d="perl -e 'printf qq|%d\n|, hex( shift )'"
alias h2o="perl -e 'printf qq|%o\n|, hex( shift )'"
alias o2b="perl -e 'printf qq|%b\n|, oct( shift )'"
alias o2d="perl -e 'printf qq|%d\n|, oct( shift )'"
alias o2h="perl -e 'printf qq|%X\n|, oct( shift )'"

alias ga="git add"
alias lgb="git for-each-ref --sort=committerdate refs/heads/ --format='%(committerdate:short) %(authorname) %(refname:short)'"
alias gb="git branch"
alias co="git checkout"
alias gs="git status"
alias gd="git diff"
alias gc="git commit -v -e -m"
alias gp="git push"
alias t="tmux"

# integer to ip address and back
alias intip="perl -MSocket=inet_ntoa -le 'print inet_ntoa(pack(\"N\",shift))'"
alias ipint="perl -MSocket -le 'print unpack(\"N\",inet_aton(shift))'"

export COLORTERM LS_OPTIONS LSCOLORS PATH PS1

pathadd "/usr/local/sbin"
pathadd "/usr/local/bin"
pathadd "$HOME/local/bin"
pathadd "$HOME/bin"
if [[ -d $HOME/.cargo ]]; then
  pathadd "$HOME/.cargo/bin"
fi

# Modern CLI tool configs
if [[ -f "$HOME/.config/ripgrep/config" ]]; then
  export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"
fi

# fzf configuration - use fd for file finding, bat for preview
if command -v fzf &>/dev/null; then
  # Use fd if available (respects .gitignore, faster)
  if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  fi

  # fzf appearance and behavior
  export FZF_DEFAULT_OPTS="
    --height=40%
    --layout=reverse
    --border=rounded
    --info=inline
    --margin=1
    --padding=1
    --bind='ctrl-y:execute-silent(echo {} | wl-copy)'
    --bind='ctrl-/:toggle-preview'
    --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
    --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
    --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
    --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
  "

  # Preview with bat if available
  if command -v bat &>/dev/null; then
    export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"
  fi
fi

# Modern CLI tool aliases (conditional on availability)
command -v bat &>/dev/null && alias cat='bat --paging=never'
command -v eza &>/dev/null && alias ls='eza' && alias ll='eza -la --git' && alias lt='eza -la --git --sort oldest' && alias tree='eza --tree'
command -v fd &>/dev/null && alias find='fd'
command -v rg &>/dev/null && alias grep='rg'
command -v tspin &>/dev/null && alias tf='tspin -f'
# zoxide init moved to end of file (required by zoxide)

function diffcol() {
  awk -v col="$1" 'NR==FNR{c[col]++;next};c[col] == 0' "$3" "$2"
  awk -v col="$1" 'NR==FNR{c[col]++;next};c[col] == 0' "$2" "$3"
}

function testme() {
  awk -v col="$1" -v col2="$2" -v col3="$3" '{ print col }'
  return 0
}

# If the first arg to "vi" contains "::" then assume it's a Perl module that's
# either in lib or t/lib
function vi() {
  local vi=$(type -fp vim)
  string=$1
  if [[ ! $string == *"::"* ]]; then
    $vi "$@"
    return 1
  fi

  string=$(sed 's/::/\//g;' <<<"$1")
  string="lib/$string.pm"
  if [[ ! -e $string ]]; then
    string="t/$string"
  fi
  $vi "$string"
}

[ -f "$HOME/.local-bashrc" ] && source "$HOME/.local-bashrc"

# clean up PATH
# http://linuxg.net/oneliners-for-removing-the-duplicates-in-your-path/
PATH=$(echo -n "$PATH" | awk -v RS=: -v ORS=: '!arr[$0]++')

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

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
[ -f /usr/share/bash-completion/completions/git ] && source /usr/share/bash-completion/completions/git

# Linuxbrew completions (bat, eza, fd, delta, zoxide, lazygit, golangci-lint)
if [ -d /home/linuxbrew/.linuxbrew/etc/bash_completion.d ]; then
  for f in /home/linuxbrew/.linuxbrew/etc/bash_completion.d/*; do
    [ -f "$f" ] && source "$f"
  done
fi

# pyenv - only if installed
if [ -d "$HOME/.pyenv" ]; then
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi

# plenv - only if installed
if command -v plenv &>/dev/null; then
  eval "$(plenv init -)"
fi

# nvm - lazy load for faster shell startup
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # Lazy-load nvm: define placeholder functions that load nvm on first use
  nvm() {
    unset -f nvm node npm npx
    # shellcheck source=/dev/null
    \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    nvm "$@"
  }
  node() {
    nvm
    command node "$@"
  }
  npm() {
    nvm
    command npm "$@"
  }
  npx() {
    nvm
    command npx "$@"
  }
fi

# zoxide - must be at end of bashrc
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"
export PATH="$HOME/.local/bin:$PATH"
