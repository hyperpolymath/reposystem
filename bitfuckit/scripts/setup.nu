# SPDX-License-Identifier: PMPL-1.0
# bitfuckit one-click setup for Nushell

let install_dir = ($env.INSTALL_DIR? | default ($env.HOME | path join ".local" "bin"))
let data_dir = ($env.DATA_DIR? | default ($env.HOME | path join ".local" "share" "bitfuckit"))
let config_dir = ($env.CONFIG_DIR? | default ($env.HOME | path join ".config" "bitfuckit"))

def log_info [msg: string] {
    print $"(ansi blue)[INFO](ansi reset) ($msg)"
}

def log_ok [msg: string] {
    print $"(ansi green)[OK](ansi reset) ($msg)"
}

def log_warn [msg: string] {
    print $"(ansi yellow)[WARN](ansi reset) ($msg)"
}

def log_error [msg: string] {
    print $"(ansi red)[ERROR](ansi reset) ($msg)"
}

def check_deps [] {
    log_info "Checking dependencies..."

    let missing = ["curl" "git"] | where { |cmd| (which $cmd | is-empty) }

    if ($missing | is-not-empty) {
        log_error $"Missing dependencies: ($missing | str join ', ')"
        return false
    }

    log_ok "All dependencies satisfied"
    true
}

def setup_dirs [] {
    log_info "Creating directories..."

    mkdir $install_dir
    mkdir $data_dir
    mkdir $config_dir

    log_ok "Directories created"
}

def install_binary [] {
    log_info "Installing bitfuckit..."

    let arch = (uname | get machine)
    let os = (uname | get kernel-name | str downcase)
    let release_url = $"https://github.com/hyperpolymath/bitfuckit/releases/latest/download/bitfuckit-($os)-($arch)"
    let target = ($install_dir | path join "bitfuckit")

    try {
        http get $release_url | save $target
        chmod +x $target
        log_ok "Downloaded pre-built binary"
    } catch {
        log_warn "No pre-built binary, attempting source build..."

        if (which gprbuild | is-not-empty) {
            let temp_dir = (mktemp -d)
            cd $temp_dir
            git clone --depth 1 https://github.com/hyperpolymath/bitfuckit.git
            cd bitfuckit
            gprbuild -P bitfuckit.gpr -j0
            cp bin/bitfuckit $target
            cd ~
            rm -rf $temp_dir
            log_ok "Built from source"
        } else {
            log_error "gprbuild not found. Install Ada compiler first."
            return false
        }
    }
    true
}

def setup_path [] {
    if not ($install_dir in $env.PATH) {
        log_info $"Add to your config.nu: $env.PATH = ($env.PATH | prepend '($install_dir)')"
    }
}

def verify [] {
    log_info "Verifying installation..."

    let target = ($install_dir | path join "bitfuckit")

    try {
        run-external $target "--help" | ignore
        log_ok "bitfuckit installed successfully!"
        true
    } catch {
        log_error "Installation verification failed"
        false
    }
}

def main [] {
    print ""
    print $"  (ansi blue)bitfuckit(ansi reset) - The Bitbucket CLI Atlassian never made"
    print "  One-click setup (Nushell)"
    print ""

    if not (check_deps) { return }
    setup_dirs
    if not (install_binary) { return }
    setup_path
    if not (verify) { return }

    print ""
    log_ok "Setup complete!"
    print ""
    print "  Next steps:"
    print "    1. Login: bitfuckit auth login"
    print "    2. Get started: bitfuckit repo list"
    print ""
    print "  Documentation: https://github.com/hyperpolymath/bitfuckit/wiki"
    print ""
}
