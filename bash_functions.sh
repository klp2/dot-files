# shellcheck shell=bash
IS_MM=false
if [ -e /usr/local/bin/mm-perl ]; then
  IS_MM=true
fi

export IS_MM
