#!/usr/bin/env bash

set -eu -o pipefail

SELF_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
source "$SELF_PATH/bash_common.sh"

echo "git config"

if is_maxmind || [[ ${DOTFILES_ENVTYPE:-} =~ work ]]; then
  git config --global user.email "kphair@maxmind.com"
else
  git config --global user.email "phair.kevin@gmail.com"
fi

git config --global user.name "Kevin Phair"

git config --global branch.autosetuprebase always
git config --global diff.algorithm histogram
git config --global github.user klp2
git config --global help.autocorrect 10
git config --global merge.conflictstyle diff3
git config --global push.default simple
git config --global push.autoSetupRemote true
git config --global rerere.enabled 1

git config --global alias.b 'branch'
git config --global alias.ba 'branch -a'
git config --global alias.cam 'commit --amend'
git config --global alias.changes 'diff --name-status -r'
git config --global alias.ci 'commit'
git config --global alias.co 'checkout'
git config --global alias.dc 'diff --cached'
git config --global alias.delete-untracked-files 'clean -f -d'
git config --global alias.diffstat 'diff --stat -r'
git config --global alias.dm 'diff -w -M main...HEAD'
git config --global alias.dom 'diff -w -M origin/main...HEAD'
git config --global alias.doms 'diff -w -M origin/main...HEAD --stat'
git config --global alias.domo 'diff -w -M origin/main...HEAD --name-only'
git config --global alias.flog 'log --stat --abbrev-commit --relative-date --pretty=oneline'
git config --global alias.from '!git fetch -p; git rebase origin/main'
git config --global alias.plog "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative"
git config --global alias.prom 'pull --rebase origin main'
git config --global alias.p 'push'
git config --global alias.pt 'push --tags'
git config --global alias.pf 'push --force-with-lease'
git config --global alias.rc "rebase --continue"
git config --global alias.root "rev-parse --show-toplevel"
git config --global alias.st 'status'
git config --global alias.stu 'status --untracked-files=no'
git config --global alias.sw 'switch'
git config --global alias.rs 'restore'

# https://unix.stackexchange.com/questions/19317/can-less-retain-colored-output
git config --global color.ui always

# Use delta for beautiful diffs if available, otherwise fall back to less
if command -v delta &>/dev/null; then
  git config --global core.pager 'delta'
  git config --global interactive.diffFilter 'delta --color-only'
  git config --global delta.navigate true
  git config --global delta.line-numbers true
  git config --global delta.side-by-side false
else
  git config --global core.pager 'less -r'
fi

# Modern convenience aliases
git config --global alias.recent "branch --sort=-committerdate --format='%(committerdate:relative)%09%(refname:short)'"
git config --global alias.uncommit 'reset --soft HEAD~1'

# Structural diff with difftastic (when delta's line-based diff isn't enough)
if command -v difft &>/dev/null; then
  git config --global alias.dft 'difftool --tool=difftastic'
  git config --global difftool.difftastic.cmd 'difft "$LOCAL" "$REMOTE"'
fi

# for Facebook Path Picker (fpp)
git config --global grep.lineNumber true

# a "git config --unset" on something that isn't set but is a valid key returns with no
# message but an exit code of 5, which cause's bash's "set -e" to terminate both this
# script and the calling install script
set +e
git config --global --unset branch.main.merge
exit 0
