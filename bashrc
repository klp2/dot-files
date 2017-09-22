## Prompt originally by cynikal at NYI, with some tweaks over the years
## The rest of the file influenced heavily by https://raw.githubusercontent.com/oalders/dot-files/master/bashrc when updating in 2017, as its been a long time since I've used bash


# http://stackoverflow.com/questions/394230/detect-the-os-from-a-bash-script
platform='unknown'
unamestr=`uname`
hostname=`hostname`
if [[ "$unamestr" == 'Linux' ]]; then
   platform='linux'
elif [[ "$unamestr" == 'Darwin' ]]; then
   platform='osx'
fi

if [[ $platform == 'linux' ]]; then
    hostname=`hostname -f`
else
    hostname=`hostname`
fi

if [[ $hostname =~ "maxmind" ]]; then
    alias perl=mm-perl
fi

export EDITOR=vim
export me=$USER

# use vim mappings to move around the command line
set -o vi

# don't put duplicate lines in the history. See bash(1) for more options
# http://www.linuxjournal.com/content/using-bash-history-more-efficiently-histcontrol
export HISTCONTROL=ignoreboth

## TODO: look into separate persistent history file - http://eli.thegreenplace.net/2013/06/11/keeping-persistent-history-in-bash

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# partial search
if [[ $- == *i* ]]
then
    bind '"\e[A": history-search-backward'
    bind '"\e[B": history-search-forward'
fi

# sets the prompt to have the hostname, time, loginname@tty, directory and prompt
# on the next line.. see man bash(1) under PROMPTING
PS1='a\033[00;34m\332\304\260\033[01;34m\260\261\033[01;37;44m \h \033[01;34;40m\261\260\033[00;34m\260\304(\033[01;37m\t\033[00;34m)-(\033[01;37m\u\033[00;34m@\033[01;37m$(basename `tty`)\033[00;34m)\304(\033[01;37m\w/\033[00;34m)\304-\n\300 \033[01;37m\$ \033[00;37;40m'

# uses ls options (i.e.. colors, formatting, etc)
if [[ $platform == 'osx' ]]; then
    LS_OPTIONS='-G'
elif [[ $platform == 'linux' ]]; then
    LS_OPTIONS="--color=auto"
fi
LSCOLORS="ExFxCxDxBxEGEDABAGACAD"

# search history
alias hist='history | ack $1'

# cleanup homebrew refuse
alias brewski='brew update && brew upgrade && brew cleanup; brew doctor'

# check tty usage, sorting by tty's
alias ttyuse='ps auxww|awk "\$7 ~ /^p/ && \$7 !~ /-/ {print}"|sort +6'

# list all processes that are running with the string in it
# stolen from here: http://www.karl-voit.at/scripts/any
alias jn='ps auxwwwwwww|ack -i $1'

# run ls with the specified colors
alias ls="ls $LS_OPTIONS"
# checks top 5/10 most cpu intensive programs
alias cpu='ps u|head -1 && ps auxww|ack -v "USER"|sort +2|tail -5'
alias cpu10='ps u|head -1 && ps auxww|ack -v "USER"|sort +2|tail -10'

# checks top 5/10 most memory intensive programs
alias mem='ps u|head -1 && ps auxww|ack -v "USER"|sort +3|tail -5'
alias mem10='ps u|head -1 && ps auxww|ack -v "USER"|sort +3|tail -10'

# checks the count on given process name
alias pscnt='echo "The current process count is: " `ps ax|wc -l`'

# lists all the process sorted by pid/cputime
alias allps='ps auxww|sort +1 -n|more'
alias cpups='ps auxw|ack -v "USER"|sort +9'

# lists load averages:
alias load='uptime|cut -dl -f2-|cut -d: -f2-|awk "{print \" 1 min load average: \" \$1 \"\n 5 min load average: \" \$2 \"\n15 min load average: \" \$3 \".\"}"'

# cp with preservation of all inode information
alias tarcp='tar cvf - . | ( cd \!* ; tar xvf - )'

alias cdr='cd `git root`'
alias delete-merged-branches='show-merged-branches | xargs -n 1 git branch -d'
alias ll='ls -alhG'
alias ps='ps auxw'
alias show-merged-branches='git branch --no-color --merged | grep -v "\*" | grep -v master'

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
alias gc="git commit"
alias gp="git push"
alias t="tmux"

# integer to ip address and back
alias intip="perl -MSocket=inet_ntoa -le 'print inet_ntoa(pack(\"N\",shift))'"
alias ipint="perl -MSocket -le 'print unpack(\"N\",inet_aton(shift))'"

export COLORTERM LS_OPTIONS LSCOLORS PATH PS1


# http://superuser.com/questions/39751/add-directory-to-path-if-its-not-already-there
pathadd() {
    if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
        PATH="$1:$PATH"
    fi
}

pathadd "/usr/local/sbin";
pathadd "/usr/local/bin";
pathadd "$HOME/local/bin";
pathadd "$HOME/bin";

LOCALPERLBIN=~/perl5/bin

if [[ ! -d ~/.plenv ]]; then
    PERL_CPANM_OPT="--local-lib=~/perl5"
    # adds $HOME/perl5/bin to PATH
    [ $SHLVL -eq 1 ] && eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)"

    if [ -d $LOCALPERBIN ] ; then
        export PATH="$LOCALPERLBIN:$PATH"
    fi
fi

if ! type "ack" > /dev/null  2>&1; then
    if type 'ack-grep' > /dev/null 2>&1; then
        alias ack='ack-grep'
    fi
fi
# gh = git home
# brings you to the top level of the git repo you are currently in
# http://stackoverflow.com/questions/957928/is-there-a-way-to-get-the-git-root-directory-in-one-command
function gh() { cd "$(git rev-parse --show-toplevel)"; }
# If the first arg to "vi" contains "::" then assume it's a Perl module that's
# either in lib or t/lib

function vi() {
    local vi=$(type -fp vim)
    string=$1
    if [[ ! $string == *"::"* ]]; then
        $vi "$@"
        return 1
    fi

    string=$(sed 's/::/\//g;' <<< $1)
    string="lib/$string.pm"
    if [[ ! -e $string ]]; then
        string="t/$string"
    fi
    $vi "$string"
}
export GOPATH=~/go
if [ -d $GOPATH ] ; then
    export PATH="$GOPATH/bin:$PATH"
fi


if [[ $platform == 'osx' ]]; then
    export PATH="~/dot-files/bin/osx:$PATH"
fi

source "$HOME/.local-bashrc"

# clean up PATH
# http://linuxg.net/oneliners-for-removing-the-duplicates-in-your-path/
PATH=`echo -n $PATH | awk -v RS=: -v ORS=: '!arr[$0]++'`

# lazy add ssh keys
for key in `ls $HOME/.ssh/keys`; do
    ssh-add $HOME/.ssh/keys/$key >& /dev/null
done 

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

local TITLEBAR='\[\033]0;\u@\h:\w\007\]'

local GRAD1=$(tty|cut -d/ -f3-)
PS1="$TITLEBAR\
$GRAY=$LIGHT_GRAY=$WHITE<\
$LIGHT_CYAN\u$CYAN@$LIGHT_CYAN\h\
$WHITE>${LIGHT_GRAY}-$GRAY<\
$LIGHT_BLUE$GRAD1\
$GRAY>${LIGHT_GRAY}-$WHITE<\
$LIGHT_GRAY\$(date +%H:%M:%S)\
$WHITE>$LIGHT_GRAY=$GRAY=$LIGHT_CYAN\$(git-prompt)\
$LIGHT_GRAY\n\
<$RED$SHLVL$LIGHT_GRAY> $GRAY-$BLUE-$LIGHT_BLUE[\
$CYAN\w\
$LIGHT_BLUE]$BLUE-$GRAY-$LIGHT_GRAY $WHITE$PROMPT $LIGHT_GRAY"
PS2="$LIGHT_CYAN-$CYAN-$GRAY-$LIGHT_GRAY "
}

cynprompt

source ~/perl5/perlbrew/etc/bashrc
