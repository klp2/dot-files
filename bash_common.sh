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

detect_envtype() {
    if [[ -e "$HOME/.laptop" ]]; then
        echo 'laptop'
    elif [[ -e "$HOME/.desktop" ]]; then
        echo 'desktop'
    else
        echo 'remote'
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
