# Release Notes: v0.1.0 - MVP Release

**Release Date:** 2026-01-24
**Status:** Minimum Viable Product (MVP)

## Overview

First public release of **Stateful Artefacts for Git Forges** - a metadata-driven documentation system that keeps docs current automatically through S-expression metadata files and template rendering.

## What's Included

### ✅ Gnosis Rendering Engine (Haskell)

- **S-Expression Parser**: Reads Guile Scheme-style metadata files
- **Template Renderer**: Replaces `(:placeholder)` syntax with values from STATE.scm
- **FlexiText Accessibility**: Every visual element paired with semantic alt-text
- **Tri-Guard Safety**: Sanitization, validation, and accessibility enforcement
- **Badge Generation**: Shields.io-compatible badge rendering

**Compilation:** Stack and Cabal support
**Platforms:** Linux, macOS (via CI)
**GHC Versions:** 9.4.8, 9.6.6+ tested

### ✅ Template Examples

- `README.template.md` - Project documentation with live stats
- `PROFILE.template.md` - GitHub/GitLab profile page
- `CONTRIBUTING.template.md` - Contribution guidelines
- `CHANGELOG.template.md` - Auto-updating changelog
- `ISSUE_TEMPLATE.md` - Bug report template

### ✅ STATE.scm Scenarios

- **Production:** Stable project example (v2.5.0)
- **Early-Stage:** Prototype project example (v0.0.1)
- **Development:** Active development (default)

### ✅ Automation Support

- Example bash script: `automation-update-stats.sh`
- GitHub Actions workflow example
- Daily stats update pattern

### ✅ Documentation

- Comprehensive README with:
  - Problem statement and solution
  - Installation instructions (Stack & Cabal)
  - Quick start guide
  - Djot support strategy
  - Philosophy and use cases
- Examples guide: `examples/README-EXAMPLES.md`
- Roadmap: Horizon 1-3 technical plan
- Vision: v0.1 → v10.0 long-term roadmap

### ✅ CI/CD

- GitHub Actions workflow: `gnosis-ci.yml`
- Multi-platform builds (Ubuntu, macOS)
- Multi-GHC testing (9.4.8, 9.6.6)
- Automated rendering tests
- Binary artifacts (30-day retention)

## Installation

### Prerequisites
- GHC 9.0+
- Stack or Cabal

### Quick Start

```bash
# Clone repository
git clone https://github.com/hyperpolymath/stateful-artefacts-for-gitforges
cd stateful-artefacts-for-gitforges/gnosis

# Build with Stack
stack build

# Or build with Cabal
cabal build
```

## Usage

```bash
# Create STATE.scm with your data
cat > .machine_readable/STATE.scm << 'EOF'
(state
  (identity
    (name . "My Project")
    (version . "1.0.0")))
EOF

# Create template
cat > README.template.md << 'EOF'
# (:name)
Version: (:version)
EOF

# Render
gnosis README.template.md README.md
```

## Available Placeholders

From STATE.scm:
- `(:name)` - Project name
- `(:mood)` - Current mood (active, idle, flow, crunch, hyper-focused)
- `(:version)` - Semantic version
- `(:phase)` - Development phase
- `(:health)` - Health score (0-100)
- `(:compliance)` - Compliance level (A, B, F)

Custom: Add any key-value pair to STATE.scm

## What's NOT in v0.1.0

- **Paxos-Lite Conflict Resolution** (Planned: v0.2.0)
- **DAX Era Logic** (Conditionals, loops, functions) (Planned: v0.3-v0.5)
- **Code Scanning** (Planned: v0.7)
- **Browser Extension** (Planned: v0.8)
- **Living Dashboard** (Planned: v0.9)

See ROADMAP.md for full feature timeline.

## Known Limitations

1. **Parser:** Doesn't handle full Guile Scheme module syntax (use simple S-expressions)
2. **Placeholders:** Must exist in STATE.scm or render as `(:MISSING:key)`
3. **No Name Loading:** Main.hs doesn't load `name` placeholder (use custom context)
4. **Flat Keys:** Parser searches nested trees but may not find deeply nested keys

## Migration from Pre-release

If you used pre-release versions:
1. Update STATE.scm to simple S-expression format (no `define-module`)
2. Rebuild gnosis with `stack build`
3. Re-render templates with new binary

## Feedback

- GitHub Issues: https://github.com/hyperpolymath/stateful-artefacts-for-gitforges/issues
- Discussions: https://github.com/hyperpolymath/stateful-artefacts-for-gitforges/discussions

## Next Release: v0.2.0 (Target: 2026-02-28)

- Paxos-Lite conflict resolution
- Full 6scm parser (ECOSYSTEM, META, NEUROSYM, AGENTIC, PLAYBOOK)
- Cross-file placeholder resolution
- Better error messages

---

**License:** PMPL-1.0-or-later
**Author:** Jonathan D.A. Jewell (@hyperpolymath)

**This release includes contributions from Claude Sonnet 4.5**
