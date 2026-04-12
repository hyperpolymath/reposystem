#!/bin/bash

echo "🧱 Starting Scaffoldia setup..."

# Define folders
folders=(
  "registry/rust" "registry/haskell" "registry/docker" "registry/elixir"
  "registry/metadata" "registry/examples"
  "builder/inputs" "builder/rules" "builder/shell" "builder/eval" "builder/output/repo-scaffold"
  "constraints/examples"
  "cli"
  "ui/public" "ui/src/blocks"
  "docs"
  "scripts"
  "assets/dialect-icons"
)

# Create folders if they don't exist
for folder in "${folders[@]}"; do
  if [ ! -d "$folder" ]; then
    mkdir -p "$folder"
    echo "✅ Created: $folder"
  else
    echo "⚠️ Skipped (already exists): $folder"
  fi
done

# Define files
files=(
  ".gitignore" "LICENSE" "README.md" "CONTRIBUTING.md"
  "builder/main.ncl" "builder/merge.ncl"
  "constraints/repo-logic.scm" "constraints/dialect-roles.scm"
  "cli/scaffoldia.hs" "cli/config.yaml"
  "scripts/scaffoldia-init.nu" "scripts/ci-inject.sh"
  "docs/architecture.md" "docs/mascot-narration.md" "docs/voletaire.md" "docs/contribution-guide.md"
)

# Create files if they don't exist
for file in "${files[@]}"; do
  if [ ! -f "$file" ]; then
    touch "$file"
    echo "📄 Created: $file"
  else
    echo "⚠️ Skipped (already exists): $file"
  fi
done

echo "🎉 Scaffoldia structure is ready. You may now begin cultivating your own repo."
