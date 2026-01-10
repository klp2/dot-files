# shellcheck shell=bash
IS_MM=false
if [ -e /usr/local/bin/mm-perl ]; then
  IS_MM=true
fi

IS_DARWIN=false

# https://stackoverflow.com/a/17072017/406224
if [ "$(uname)" == "Darwin" ]; then
  IS_DARWIN=true
fi

export IS_MM
export IS_DARWIN
export LINK_FLAG
