# Load .bashrc
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"
export PATH="/usr/local/opt/libxml2/bin:$PATH"
eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
