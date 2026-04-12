#!/usr/bin/env bash
# ==============================================================================
# RHODIUM STANDARD BOOTSTRAP (v2.0)
# Authority: github.com/hyperpolymath/must-spec
# Targets: Linux, Minix, macOS, iOS, Android, PC (ASIC/Edge compatible)
# Shells: bash, cmd, oil, ash, csh, dash, elvish, fish, ion, ksh, murex, 
#         ngs, nushell, powershell-core, tcsh, tsh, zsh, minix shell
# ==============================================================================

set -euo pipefail

# 1. CONSTANTS & PATHS
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

# 2. TOOL MANIFEST
# Satellite Repos: must-spec, nickel-augmented (nicaug), tnav (tree-navigator)
TOOLS=("just" "must" "nicaug")

# 3. HELPER: INSTALLER
install_tool() {
    local tool=$1
    echo "--- [Securing $tool] ---"
    
    # Priority Route: Check for local binary first (Offline-First)
    if command -v "$tool" &> /dev/null; then
        echo "$tool is already locked. skipping."
        return
    fi

    # Deployment Route: Download latest release
    # In a production RSR, point these to your specific mirrors
    case $tool in
        "just")
# WARNING: Pipe-to-shell is unsafe — download and verify first
# WARNING: Pipe-to-shell is unsafe — download and verify first
# WARNING: Pipe-to-shell is unsafe — download and verify first
# WARNING: Pipe-to-shell is unsafe — download and verify first
            curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to "$BIN_DIR"
            ;;
        "must")
            curl -L "https://github.com/hyperpolymath/must-spec/releases/latest/download/must" -o "$BIN_DIR/must"
            ;;
        "nicaug")
            curl -L "https://github.com/hyperpolymath/nickel-augmented/releases/latest/download/nicaug" -o "$BIN_DIR/nicaug"
            ;;
    esac
    chmod +x "$BIN_DIR/$tool"
}

# 4. EXECUTION
echo "Initializing Rhodium Environment..."

for tool in "${TOOLS[@]}"; do
    install_tool "$tool"
done

# 5. ALIAS ENFORCEMENT
# Ensures tree-navigator is always invoked as tnav
if [[ ! -L "$BIN_DIR/tnav" ]] && [[ -f "$BIN_DIR/tree-navigator" ]]; then
    ln -s "$BIN_DIR/tree-navigator" "$BIN_DIR/tnav"
    echo "Alias tnav -> tree-navigator secured."
fi

echo "--- Rhodium Standard Environment Secured ---"
echo "Use 'just' for local tasks and 'must' for global deployment."
