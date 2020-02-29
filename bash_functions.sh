IS_MM=false
if [ -e /usr/local/bin/mm-perl ]; then
    IS_MM=true
fi

IS_DARWIN=false
LINK_FLAG=""

# https://stackoverflow.com/a/17072017/406224
if [ "$(uname)" == "Darwin" ]; then
    IS_DARWIN=true
    LINK_FLAG="-hF"
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    LINK_FLAG="-T"
fi

export IS_MM
export IS_DARWIN
export LINK_FLAG
