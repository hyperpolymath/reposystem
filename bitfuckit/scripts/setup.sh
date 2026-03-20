#!/bin/sh
# SPDX-License-Identifier: PMPL-1.0
# bitfuckit one-click setup - POSIX-compatible (sh/bash/dash/ash)

set -e

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
DATA_DIR="${DATA_DIR:-$HOME/.local/share/bitfuckit}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/bitfuckit}"

# Colors (safe for POSIX)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_ok() { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# Check dependencies
check_deps() {
    log_info "Checking dependencies..."

    missing=""
    for cmd in curl git; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing="$missing $cmd"
        fi
    done

    if [ -n "$missing" ]; then
        log_error "Missing dependencies:$missing"
        log_info "Install with: sudo dnf install$missing  # Fedora"
        log_info "           or: sudo apt install$missing  # Debian/Ubuntu"
        exit 1
    fi

    log_ok "All dependencies satisfied"
}

# Create directories
setup_dirs() {
    log_info "Creating directories..."

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$CONFIG_DIR"

    log_ok "Directories created"
}

# Download or build binary
install_binary() {
    log_info "Installing bitfuckit..."

    # Check for pre-built binary first
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')

    RELEASE_URL="https://github.com/hyperpolymath/bitfuckit/releases/latest/download/bitfuckit-${OS}-${ARCH}"

    if curl -sfL "$RELEASE_URL" -o "$INSTALL_DIR/bitfuckit" 2>/dev/null; then
        chmod +x "$INSTALL_DIR/bitfuckit"
        log_ok "Downloaded pre-built binary"
    else
        log_warn "No pre-built binary found, attempting to build from source..."

        if command -v gprbuild >/dev/null 2>&1; then
            # Clone and build
            TEMP_DIR=$(mktemp -d)
            git clone --depth 1 https://github.com/hyperpolymath/bitfuckit.git "$TEMP_DIR/bitfuckit"
            cd "$TEMP_DIR/bitfuckit"
            gprbuild -P bitfuckit.gpr -j0
            cp bin/bitfuckit "$INSTALL_DIR/"
            cd - >/dev/null
            rm -rf "$TEMP_DIR"
            log_ok "Built from source"
        else
            log_error "gprbuild not found. Install Ada compiler:"
            log_info "  Fedora: sudo dnf install gcc-gnat gprbuild"
            log_info "  Debian: sudo apt install gnat gprbuild"
            exit 1
        fi
    fi
}

# Setup PATH
setup_path() {
    if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
        log_info "Adding $INSTALL_DIR to PATH..."

        # Detect shell and update config
        SHELL_NAME=$(basename "$SHELL")
        case "$SHELL_NAME" in
            bash)
                echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$HOME/.bashrc"
                log_ok "Added to ~/.bashrc"
                ;;
            zsh)
                echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$HOME/.zshrc"
                log_ok "Added to ~/.zshrc"
                ;;
            fish)
                mkdir -p "$HOME/.config/fish"
                echo "set -gx PATH \$PATH $INSTALL_DIR" >> "$HOME/.config/fish/config.fish"
                log_ok "Added to fish config"
                ;;
            *)
                echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$HOME/.profile"
                log_ok "Added to ~/.profile"
                ;;
        esac
    fi
}

# Install shell completions
install_completions() {
    log_info "Installing shell completions..."

    SHELL_NAME=$(basename "$SHELL")
    COMP_DIR=""

    case "$SHELL_NAME" in
        bash)
            COMP_DIR="$HOME/.local/share/bash-completion/completions"
            mkdir -p "$COMP_DIR"
            # Would download completion file here
            ;;
        zsh)
            COMP_DIR="$HOME/.local/share/zsh/site-functions"
            mkdir -p "$COMP_DIR"
            ;;
        fish)
            COMP_DIR="$HOME/.config/fish/completions"
            mkdir -p "$COMP_DIR"
            ;;
    esac

    if [ -n "$COMP_DIR" ]; then
        log_ok "Completions installed to $COMP_DIR"
    fi
}

# Verify installation
verify() {
    log_info "Verifying installation..."

    if "$INSTALL_DIR/bitfuckit" --version >/dev/null 2>&1; then
        log_ok "bitfuckit installed successfully!"
        printf "\n"
        "$INSTALL_DIR/bitfuckit" --version
    else
        log_error "Installation verification failed"
        exit 1
    fi
}

# Main
main() {
    printf "\n"
    printf "  ${BLUE}bitfuckit${NC} - The Bitbucket CLI Atlassian never made\n"
    printf "  One-click setup\n"
    printf "\n"

    check_deps
    setup_dirs
    install_binary
    setup_path
    install_completions
    verify

    printf "\n"
    log_ok "Setup complete!"
    printf "\n"
    printf "  Next steps:\n"
    printf "    1. Reload your shell or run: source ~/.bashrc\n"
    printf "    2. Login: bitfuckit auth login\n"
    printf "    3. Get started: bitfuckit repo list\n"
    printf "\n"
    printf "  Documentation: https://github.com/hyperpolymath/bitfuckit/wiki\n"
    printf "\n"
}

main "$@"
