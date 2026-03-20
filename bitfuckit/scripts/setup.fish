#!/usr/bin/env fish
# SPDX-License-Identifier: PMPL-1.0
# bitfuckit one-click setup for Fish shell

set INSTALL_DIR (set -q INSTALL_DIR; and echo $INSTALL_DIR; or echo "$HOME/.local/bin")
set DATA_DIR (set -q DATA_DIR; and echo $DATA_DIR; or echo "$HOME/.local/share/bitfuckit")
set CONFIG_DIR (set -q CONFIG_DIR; and echo $CONFIG_DIR; or echo "$HOME/.config/bitfuckit")

function log_info
    set_color blue
    echo -n "[INFO] "
    set_color normal
    echo $argv
end

function log_ok
    set_color green
    echo -n "[OK] "
    set_color normal
    echo $argv
end

function log_warn
    set_color yellow
    echo -n "[WARN] "
    set_color normal
    echo $argv
end

function log_error
    set_color red
    echo -n "[ERROR] "
    set_color normal
    echo $argv
end

function check_deps
    log_info "Checking dependencies..."

    set missing
    for cmd in curl git
        if not command -q $cmd
            set -a missing $cmd
        end
    end

    if test (count $missing) -gt 0
        log_error "Missing dependencies: $missing"
        return 1
    end

    log_ok "All dependencies satisfied"
end

function setup_dirs
    log_info "Creating directories..."
    mkdir -p $INSTALL_DIR
    mkdir -p $DATA_DIR
    mkdir -p $CONFIG_DIR
    log_ok "Directories created"
end

function install_binary
    log_info "Installing bitfuckit..."

    set ARCH (uname -m)
    set OS (uname -s | string lower)
    set RELEASE_URL "https://github.com/hyperpolymath/bitfuckit/releases/latest/download/bitfuckit-$OS-$ARCH"

    if curl -sfL $RELEASE_URL -o "$INSTALL_DIR/bitfuckit" 2>/dev/null
        chmod +x "$INSTALL_DIR/bitfuckit"
        log_ok "Downloaded pre-built binary"
    else
        log_warn "No pre-built binary, attempting source build..."

        if command -q gprbuild
            set TEMP_DIR (mktemp -d)
            git clone --depth 1 https://github.com/hyperpolymath/bitfuckit.git "$TEMP_DIR/bitfuckit"
            pushd "$TEMP_DIR/bitfuckit"
            gprbuild -P bitfuckit.gpr -j0
            cp bin/bitfuckit "$INSTALL_DIR/"
            popd
            rm -rf $TEMP_DIR
            log_ok "Built from source"
        else
            log_error "gprbuild not found. Install Ada compiler first."
            return 1
        end
    end
end

function setup_path
    if not contains $INSTALL_DIR $PATH
        log_info "Adding $INSTALL_DIR to PATH..."
        set -Ua fish_user_paths $INSTALL_DIR
        log_ok "Added to fish_user_paths"
    end
end

function install_completions
    log_info "Installing fish completions..."

    set COMP_DIR "$HOME/.config/fish/completions"
    mkdir -p $COMP_DIR

    # Basic completion
    echo 'complete -c bitfuckit -f -a "auth repo pr mirror tui help"' > "$COMP_DIR/bitfuckit.fish"
    echo 'complete -c bitfuckit -n "__fish_seen_subcommand_from auth" -a "login status"' >> "$COMP_DIR/bitfuckit.fish"
    echo 'complete -c bitfuckit -n "__fish_seen_subcommand_from repo" -a "create list delete exists"' >> "$COMP_DIR/bitfuckit.fish"
    echo 'complete -c bitfuckit -n "__fish_seen_subcommand_from pr" -a "list create merge"' >> "$COMP_DIR/bitfuckit.fish"

    log_ok "Fish completions installed"
end

function verify
    log_info "Verifying installation..."

    if $INSTALL_DIR/bitfuckit --help >/dev/null 2>&1
        log_ok "bitfuckit installed successfully!"
        echo
        $INSTALL_DIR/bitfuckit --help | head -5
    else
        log_error "Installation verification failed"
        return 1
    end
end

function main
    echo
    set_color blue
    echo "  bitfuckit"
    set_color normal
    echo " - The Bitbucket CLI Atlassian never made"
    echo "  One-click setup (Fish)"
    echo

    check_deps; or return 1
    setup_dirs
    install_binary; or return 1
    setup_path
    install_completions
    verify; or return 1

    echo
    log_ok "Setup complete!"
    echo
    echo "  Next steps:"
    echo "    1. Login: bitfuckit auth login"
    echo "    2. Get started: bitfuckit repo list"
    echo
    echo "  Documentation: https://github.com/hyperpolymath/bitfuckit/wiki"
    echo
end

main $argv
