#!/usr/bin/env bash
# bootstrap.sh - Quick bootstrap for Must development environment
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (C) 2025 Jonathan D.A. Jewell

set -euo pipefail

echo "=== Must Bootstrap ==="
echo ""

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Linux)
        if [ -f /etc/debian_version ]; then
            DISTRO="debian"
        elif [ -f /etc/fedora-release ]; then
            DISTRO="fedora"
        elif [ -f /etc/arch-release ]; then
            DISTRO="arch"
        else
            DISTRO="linux"
        fi
        ;;
    Darwin)
        DISTRO="macos"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

echo "Detected: $DISTRO"
echo ""

# Install GNAT if not present
if ! command -v gnat &> /dev/null; then
    echo "Installing GNAT Ada compiler..."
    case "$DISTRO" in
        debian)
            sudo apt-get update
            sudo apt-get install -y gnat gprbuild
            ;;
        fedora)
            sudo dnf install -y gcc-gnat gprbuild
            ;;
        arch)
            sudo pacman -S --noconfirm gcc-ada gprbuild
            ;;
        macos)
            if command -v brew &> /dev/null; then
                brew install gnat gprbuild
            else
                echo "Please install Homebrew first: https://brew.sh"
                exit 1
            fi
            ;;
        *)
            echo "Please install GNAT manually for your distribution"
            exit 1
            ;;
    esac
else
    echo "GNAT already installed: $(gnat --version | head -1)"
fi

# Install just if not present
if ! command -v just &> /dev/null; then
    echo "Installing just..."
    case "$DISTRO" in
        debian)
            sudo apt-get install -y just || {
                # Fallback to cargo if not in repos
                if command -v cargo &> /dev/null; then
                    cargo install just
                else
                    echo "Please install 'just' manually: https://just.systems"
                    exit 1
                fi
            }
            ;;
        fedora)
            sudo dnf install -y just
            ;;
        arch)
            sudo pacman -S --noconfirm just
            ;;
        macos)
            brew install just
            ;;
        *)
            if command -v cargo &> /dev/null; then
                cargo install just
            else
                echo "Please install 'just' manually: https://just.systems"
                exit 1
            fi
            ;;
    esac
else
    echo "just already installed: $(just --version)"
fi

# Install podman if not present (optional)
if ! command -v podman &> /dev/null; then
    echo ""
    echo "Note: podman not found. Install it for container deployment:"
    case "$DISTRO" in
        debian)
            echo "  sudo apt-get install podman"
            ;;
        fedora)
            echo "  sudo dnf install podman"
            ;;
        arch)
            echo "  sudo pacman -S podman"
            ;;
        macos)
            echo "  brew install podman"
            ;;
    esac
fi

echo ""
echo "=== Bootstrap Complete ==="
echo ""
echo "Next steps:"
echo "  just build        # Build must"
echo "  just test         # Run tests"
echo "  just install      # Install to /usr/local/bin"
echo ""
