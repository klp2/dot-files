#!/usr/bin/env bash
# Install starship to ~/bin (no root required)
# Usage: ./install-starship.sh [install-dir]
#        Default install dir is ~/bin

set -eu -o pipefail

INSTALL_DIR="${1:-$HOME/bin}"
mkdir -p "$INSTALL_DIR"

# Detect architecture
ARCH=$(uname -m)
OS=$(uname -s)

case "$OS" in
    Linux)
        case "$ARCH" in
            x86_64)  ARCH="x86_64-unknown-linux-gnu" ;;
            aarch64) ARCH="aarch64-unknown-linux-gnu" ;;
            *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
        esac
        ;;
    Darwin)
        case "$ARCH" in
            x86_64)  ARCH="x86_64-apple-darwin" ;;
            arm64)   ARCH="aarch64-apple-darwin" ;;
            *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
        esac
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

echo "Downloading starship for ${OS}/${ARCH}..."

# Download and extract
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

curl -sL "https://github.com/starship/starship/releases/latest/download/starship-${ARCH}.tar.gz" | tar xz -C "$TMPDIR"
mv "$TMPDIR/starship" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/starship"

echo "Starship installed to $INSTALL_DIR/starship"
echo ""
echo "Add to your bashrc:"
echo '  eval "$(starship init bash)"'
