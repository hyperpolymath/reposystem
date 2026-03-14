# git-morph — Technical Design
<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->

## Architecture

```
git-morph/
├── src/
│   ├── main.rs          # CLI entry point (clap subcommands)
│   ├── lib.rs           # Public API
│   ├── manifest.rs      # .morph.a2ml parsing and validation
│   ├── inflate.rs       # Component → standalone repo
│   ├── deflate.rs       # Standalone repo → monorepo component
│   ├── template.rs      # Template expansion engine
│   ├── history.rs       # Git history filtering (via gix)
│   ├── diff.rs          # Round-trip diffing and dry-run previews
│   └── detect.rs        # Auto-detect file classification heuristics
├── tests/
│   ├── inflate_test.rs
│   ├── deflate_test.rs
│   └── roundtrip_test.rs
└── Cargo.toml
```

## Core Concepts

### Component Manifest (`.morph.a2ml`)

Each morphable component in a monorepo has a manifest:

```toml
[component]
name = "libgit2-ffi"
path = "ffi/libgit2/"

[files]
# Files unique to this component — copied as-is in both directions
owned = [
  "ffi/**",
  "src/abi/**",
  "build.zig",
  "docs/**",
  "examples/**",
]

# Files inherited from monorepo root — stripped on deflate, generated on inflate
inherited = [
  "LICENSE",
  "SECURITY.md",
  "CODE_OF_CONDUCT.md",
  "CONTRIBUTING.md",
  ".github/workflows/*.yml",
]

[template]
name = "rsr-template-repo"
vars = { repo_name = "libgit2-ffi", description = "Zig FFI bindings for libgit2" }

[dependencies]
components = []

[registry]
type = "none"
```

### File Classification

Every file falls into one of three categories:

| Category | On Inflate | On Deflate |
|----------|-----------|-----------|
| **Owned** | Copied as-is | Copied as-is |
| **Inherited** | Generated from template | Stripped (monorepo root provides) |
| **Ignored** | Skipped (build artefacts, .git) | Skipped |

### Inflate Operation

```
git morph inflate <component-path> [--output <dir>] [--with-history] [--template <name>] [--dry-run]
```

1. Read manifest from `<component-path>/.morph.a2ml`
2. Validate (all owned files exist, template accessible)
3. Create output directory (default: `../<component-name>/`)
4. Copy owned files preserving directory structure
5. Apply template for inherited files (resolve template, substitute variables)
6. If `--with-history`: filter git log to only commits touching owned files
7. Write `.morph.a2ml` into standalone repo (for future deflation)
8. Report: files copied, files generated, total size

### Deflate Operation

```
git morph deflate <repo-path> [--into <monorepo>] [--at <path>] [--squash] [--dry-run]
```

1. Read manifest from `<repo-path>/.morph.a2ml` (or auto-detect if absent)
2. Classify all files as owned, inherited, or ignored
3. Strip inherited files
4. Copy owned files into monorepo at `--at <path>`
5. Create/update manifest in monorepo
6. If `--squash`: single commit summarising the import
7. Report: files copied, files stripped, conflicts

### Auto-Detection Heuristics (`detect.rs`)

When deflating a repo without a manifest, classify by convention:

**Likely inherited** (monorepo provides):
- `LICENSE`, `LICENSE.*`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`
- `.github/workflows/hypatia-scan.yml` and other standard RSR workflows
- `.editorconfig`, `.gitignore` (if identical to monorepo root)
- `0-AI-MANIFEST.a2ml`

**Likely owned** (component-specific):
- `src/`, `lib/`, `ffi/`, `tests/`, `docs/`, `examples/`
- `Cargo.toml`, `deno.json`, `rescript.json`, `build.zig`, `justfile`
- Source files: `*.rs`, `*.res`, `*.zig`, `*.adb`, `*.ads`, `*.idr`, `*.gleam`
- `README.adoc`, `README.md`

**Always ignored**:
- `.git/`, `target/`, `node_modules/`, `_build/`, `.lake/`
- Object files: `*.o`, `*.so`, `*.dylib`, `*.exe`

### Round-trip Guarantee

```
deflate(inflate(component)) = component   # exact: owned files unchanged
inflate(deflate(repo)) ≈ repo             # structural: template may differ
```

## CLI Design

```
git-morph — Transform repos between monorepo components and standalone repos

USAGE:
    git morph <COMMAND>

COMMANDS:
    inflate    Extract a monorepo component into a standalone repo
    deflate    Pack a standalone repo into a monorepo as a component
    list       List components with .morph.a2ml manifests
    diff       Preview what inflate or deflate would change
    help       Print help

INFLATE:
    <COMPONENT>              Path to component within monorepo
    -o, --output <DIR>       Output directory (default: ../<name>/)
    -t, --template <NAME>    Template override (default: from manifest)
    -H, --with-history       Preserve git history for owned files
    -n, --dry-run            Preview without writing
    -v, --verbose            Verbose output

DEFLATE:
    <REPO>                   Path to standalone repo
    -i, --into <MONOREPO>    Target monorepo (default: current directory)
    -a, --at <PATH>          Path within monorepo (default: from manifest)
    -s, --squash             Squash history into single commit
    -n, --dry-run            Preview without writing
    -v, --verbose            Verbose output

LIST:
    -d, --dir <DIR>          Directory to scan (default: .)
    -r, --recursive          Scan subdirectories
```

## Phases

### Phase 1: Core (current)
- CLI skeleton with clap subcommands
- `.morph.a2ml` manifest parsing
- File classification (owned/inherited/ignored)
- File copy with structure preservation
- Template application from local rsr-template-repo
- Dry-run mode
- Integration tests

### Phase 2: History
- `--with-history` via gix filter
- `--squash` for deflate
- Conflict detection for deflating into occupied paths

### Phase 3: Registry
- Auto-detect package type (Cargo.toml, deno.json, etc.)
- Inflate generates registry-ready metadata
- Deflate strips registry-specific files

### Phase 4: Extended Morphs
- `git morph split` — inflate all components in a monorepo at once
- `git morph merge` — deflate N repos into one monorepo
- `git morph sync` — bidirectional sync between inflated and source
- `git morph audit` — verify all manifests are current

## Use Cases

1. **asdf-tool-plugins**: 74 plugins in one monorepo, each inflatable to standalone
2. **developer-ecosystem**: Julia/Deno/Zig/ReScript packages for registry publishing
3. **nextgen-languages**: Language implementations extractable as standalone projects
4. **FFI bindings**: Domain-specific FFIs, inflatable for independent use
5. **Any monorepo** that needs to publish or share individual components
