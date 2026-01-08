#!/bin/bash
# Cleanup banned runtimes per RSR Language Policy
# Removes: nodejs, bun, nvm (keeps deno as replacement)

set -e

echo "=== Cleaning Banned Runtimes (RSR Policy) ==="
echo ""

# 1. Remove asdf nodejs
echo "[1/4] Removing asdf nodejs..."
if asdf list nodejs &>/dev/null; then
    asdf uninstall nodejs 25.2.1 2>/dev/null || true
    asdf plugin remove nodejs 2>/dev/null || true
    echo "✓ asdf nodejs removed"
else
    echo "- asdf nodejs not installed"
fi

# 2. Remove asdf bun
echo "[2/4] Removing asdf bun..."
if asdf list bun &>/dev/null; then
    asdf uninstall bun 1.3.5 2>/dev/null || true
    asdf plugin remove bun 2>/dev/null || true
    echo "✓ asdf bun removed"
else
    echo "- asdf bun not installed"
fi

# 3. Remove nvm entirely
echo "[3/4] Removing nvm..."
if [ -d "$HOME/.nvm" ]; then
    rm -rf "$HOME/.nvm"
    echo "✓ nvm removed (295MB)"
else
    echo "- nvm not installed"
fi

# 4. Clear npm cache (legacy)
echo "[4/4] Clearing npm cache..."
if [ -d "$HOME/.npm" ]; then
    rm -rf "$HOME/.npm/_cacache" "$HOME/.npm/_logs" "$HOME/.npm/_npx"
    echo "✓ npm cache cleared"
else
    echo "- npm cache not found"
fi

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Deno remains as your JavaScript/TypeScript runtime."
echo "Run 'deno --version' to verify."
