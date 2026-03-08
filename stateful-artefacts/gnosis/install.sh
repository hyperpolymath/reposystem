#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Gnosis CLI installer
#
# Usage:
#   ./install.sh              # Install to ~/.local/bin/gnosis
#   ./install.sh /usr/local   # Install to /usr/local/bin/gnosis
#   PREFIX=/opt ./install.sh  # Install to /opt/bin/gnosis

set -euo pipefail

PREFIX="${1:-${PREFIX:-$HOME/.local}}"
BIN_DIR="$PREFIX/bin"

echo "Gnosis CLI Installer"
echo "===================="
echo ""

# Check for cabal
if ! command -v cabal &>/dev/null; then
    echo "ERROR: cabal not found. Install GHC and cabal-install first."
    echo ""
    echo "  Option 1: ghcup (recommended)"
    echo "    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh"
    echo ""
    echo "  Option 2: System package manager"
    echo "    Fedora:  sudo dnf install ghc cabal-install"
    echo "    Ubuntu:  sudo apt install ghc cabal-install"
    echo "    Arch:    sudo pacman -S ghc cabal-install"
    exit 1
fi

# Build
echo "Building gnosis..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
cabal build 2>&1 | tail -5

# Find binary
GNOSIS_BIN=$(cabal list-bin gnosis 2>/dev/null)
if [ ! -x "$GNOSIS_BIN" ]; then
    echo "ERROR: Build succeeded but binary not found"
    exit 1
fi

# Install
mkdir -p "$BIN_DIR"
cp "$GNOSIS_BIN" "$BIN_DIR/gnosis"
chmod +x "$BIN_DIR/gnosis"

echo ""
echo "Installed: $BIN_DIR/gnosis"
echo "Version:   $("$BIN_DIR/gnosis" --version 2>/dev/null || echo 'unknown')"
echo ""

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    echo "NOTE: $BIN_DIR is not in your PATH. Add it:"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    echo ""
fi

# Install pre-commit hook if in a git repo
if [ -d "$SCRIPT_DIR/../.git" ] || git -C "$SCRIPT_DIR/.." rev-parse --git-dir &>/dev/null 2>&1; then
    GIT_DIR=$(git -C "$SCRIPT_DIR/.." rev-parse --git-dir 2>/dev/null || echo "")
    if [ -n "$GIT_DIR" ] && [ ! -f "$GIT_DIR/hooks/pre-commit" ]; then
        echo "Install pre-commit hook for auto-hydration? [y/N] "
        read -r REPLY
        if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
            cp "$SCRIPT_DIR/hooks/pre-commit" "$GIT_DIR/hooks/pre-commit"
            chmod +x "$GIT_DIR/hooks/pre-commit"
            echo "Pre-commit hook installed."
        fi
    fi
fi

echo "Done. Run 'gnosis --help' for usage."
