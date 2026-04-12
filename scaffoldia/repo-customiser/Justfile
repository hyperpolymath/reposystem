# Rhodium Standard Justfile
set shell := ["bash", "-c"]

# Universal Recipes
default: bootstrap
    @just --list

# The 'Just' Route: Security and Toolchain
bootstrap:
    @echo "Securing Rhodium Toolchain..."
    @bash scripts/bootstrap.sh

# White-space and Deprecation Purge (The Just Route)
tidy:
    @echo "Purging legacy white-space and checking for deprecations..."
    @sed -i 's/[[:space:]]*$//' $(find . -type f -not -path "./.git/*")
    @echo "Standard Refined."

# Cross-Platform Build (ASIC to PC)
build target="native":
    @echo "Building {{target}}..."
    @nicaug build --arch {{target}}
