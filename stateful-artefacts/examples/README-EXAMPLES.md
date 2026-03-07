# Gnosis Examples

This directory contains example templates and STATE.scm configurations to help you get started with stateful artefacts.

## Template Examples

### 1. README Template
**File:** `README.template.md`

Basic project README showing project status, health metrics, and statistics.

**Usage:**
```bash
gnosis README.template.md README.md
```

### 2. PROFILE Template
**File:** `PROFILE.template.md`

GitHub/GitLab profile page with repository statistics and current focus.

**Usage:**
```bash
gnosis PROFILE.template.md PROFILE.md
```

### 3. CONTRIBUTING Template
**File:** `CONTRIBUTING.template.md`

Contributing guidelines that stay current with project phase and compliance level.

**Usage:**
```bash
gnosis CONTRIBUTING.template.md CONTRIBUTING.md
```

### 4. CHANGELOG Template
**File:** `CHANGELOG.template.md`

Changelog that auto-updates with current version, phase, and health metrics.

**Usage:**
```bash
gnosis CHANGELOG.template.md CHANGELOG.md
```

### 5. ISSUE_TEMPLATE
**File:** `ISSUE_TEMPLATE.md`

GitHub issue template that includes current project version and phase.

**Usage:**
```bash
gnosis ISSUE_TEMPLATE.md .github/ISSUE_TEMPLATE/bug_report.md
```

## STATE.scm Scenarios

### Production-Ready Project
**File:** `STATE-production.scm`

Example for a stable, production-deployed project:
- Version: 2.5.0
- Phase: production
- Health: 95/100
- Compliance: A

### Early-Stage Project
**File:** `STATE-early.scm`

Example for a prototype/experimental project:
- Version: 0.0.1
- Phase: prototype
- Health: 45/100
- Compliance: B

### Active Development
**File:** `../.machine_readable/STATE.scm` (repository default)

Example for a project in active development (alpha/beta phase).

## Trying Examples

### Test with Production State

```bash
# Copy production STATE to test location
cp STATE-production.scm ../.machine_readable/STATE.scm

# Render a template
gnosis README.template.md README-production.md

# Result: "ProductionApp v2.5.0 (production)"
```

### Test with Early-Stage State

```bash
# Copy early-stage STATE
cp STATE-early.scm ../.machine_readable/STATE.scm

# Render a template
gnosis README.template.md README-early.md

# Result: "ExperimentalTool v0.0.1 (prototype)"
```

## Creating Your Own Templates

Templates use `(:placeholder)` syntax for dynamic content:

```markdown
# (:name)

**Version:** (:version)
**Phase:** (:phase)
**Health:** (:health)/100
```

### Available Placeholders

From STATE.scm:
- `(:name)` - Project name
- `(:mood)` - Current mood (active, idle, flow, crunch, hyper-focused)
- `(:version)` - Semantic version
- `(:phase)` - Development phase (prototype, alpha, beta, production)
- `(:health)` - Health score (0-100)
- `(:compliance)` - Compliance level (A, B, F)

Custom placeholders: Add any key-value pair to STATE.scm and reference it in templates.

## Automation Example

See `automation-update-stats.sh` for a complete example of daily automation that:
1. Fetches current statistics from GitHub API
2. Updates STATE.scm with new values
3. Re-renders all templates
4. Commits changes

## Next Steps

1. Copy an example STATE.scm to your project's `.machine_readable/` directory
2. Customize the values to match your project
3. Copy example templates and adapt them to your needs
4. Set up automation to keep STATE.scm current
5. Enjoy always-current documentation!
