#!/usr/bin/env bash
# Common environment detection functions
# Sourced by bashrc, git-config.sh, and install.sh

detect_platform() {
  case "$(uname)" in
    Linux) echo 'linux' ;;
    Darwin) echo 'osx' ;;
    *) echo 'unknown' ;;
  esac
}

detect_hostname() {
  local platform=$(detect_platform)
  if [[ $platform == 'linux' ]]; then
    hostname -f 2>/dev/null || hostname
  else
    hostname
  fi
}

_detect_envtype_heuristic() {
  local graphical=false
  if [[ "${XDG_SESSION_TYPE:-}" == "x11" || "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    graphical=true
  fi

  if $graphical; then
    if is_maxmind; then
      echo 'local-work'
    else
      echo 'local-personal'
    fi
  else
    if is_maxmind; then
      echo 'remote-work'
    else
      echo 'remote-personal'
    fi
  fi
}

detect_envtype() {
  if [[ -e "$HOME/.local-work" ]]; then
    echo 'local-work'
  elif [[ -e "$HOME/.local-personal" ]]; then
    echo 'local-personal'
  elif [[ -e "$HOME/.remote-work" ]]; then
    echo 'remote-work'
  elif [[ -e "$HOME/.remote-personal" ]]; then
    echo 'remote-personal'
  # Legacy marker files
  elif [[ -e "$HOME/.laptop" ]]; then
    echo 'local-work'
  elif [[ -e "$HOME/.desktop" ]]; then
    echo 'local-personal'
  else
    _detect_envtype_heuristic
  fi
}

is_maxmind() {
  [[ $(detect_hostname) =~ "maxmind" ]]
}

# Export variables if sourced (not just function definitions)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export DOTFILES_PLATFORM=$(detect_platform)
  export DOTFILES_HOSTNAME=$(detect_hostname)
  export DOTFILES_ENVTYPE=$(detect_envtype)
fi
