# scaffoldia-init.nu

print "🧱 Starting Scaffoldia setup..."

let folders = [
  "registry/rust", "registry/haskell", "registry/docker", "registry/elixir",
  "registry/metadata", "registry/examples",
  "builder/inputs", "builder/rules", "builder/shell", "builder/eval", "builder/output/repo-scaffold",
  "constraints/examples",
  "cli",
  "ui/public", "ui/src/blocks",
  "docs",
  "scripts",
  "assets/dialect-icons"
]

for folder in $folders {
  if not ($folder | path exists) {
    mkdir $folder
    print $"✅ Created: ($folder)"
  } else {
    print $"⚠️ Skipped (already exists): ($folder)"
  }
}

let files = [
  ".gitignore", "LICENSE", "README.md", "CONTRIBUTING.md",
  "builder/main.ncl", "builder/merge.ncl",
  "constraints/repo-logic.scm", "constraints/dialect-roles.scm",
  "cli/scaffoldia.hs", "cli/config.yaml",
  "scripts/scaffoldia-init.nu", "scripts/ci-inject.sh",
  "docs/architecture.md", "docs/mascot-narration.md", "docs/voletaire.md", "docs/contribution-guide.md"
]

for file in $files {
  if not ($file | path exists) {
    touch $file
    print $"📄 Created: ($file)"
  } else {
    print $"⚠️ Skipped (already exists): ($file)"
  }
}

print "🎉 Scaffoldia structure is ready. You may now begin cultivating your own repo."
