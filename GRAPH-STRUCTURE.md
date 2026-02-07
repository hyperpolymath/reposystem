# Reposystem Graph Structure

## Overview

The reposystem graph is a TOML-based data structure that tracks all repositories in the hyperpolymath ecosystem, their relationships, and metadata.

## File Location

Primary graph file: `~/Documents/hyperpolymath-repos/reposystem/graph.toml`

## Schema (v1.0)

### Top-Level Structure

```toml
[meta]
version = "1.0"
created_at = "2026-02-07T10:00:00Z"
updated_at = "2026-02-07T11:30:00Z"
total_repos = 571

[settings]
default_aspects = ["quality", "security", "seo"]
auto_discover = true
scan_interval_days = 7
```

### Repository Entries

Each repository is defined as a `[[repositories]]` table:

```toml
[[repositories]]
id = "git-dispatcher"
name = "git-dispatcher"
path = "/var/mnt/eclipse/repos/git-dispatcher"
forge = "github"
owner = "hyperpolymath"
url = "https://github.com/hyperpolymath/git-dispatcher"

# Metadata
description = "Execution engine for reposystem plans"
tech_stack = ["ReScript", "Deno"]
created_at = "2024-06-01T00:00:00Z"

# Classification
group = "reposystem-core"
aspects = ["execution", "automation"]
tags = ["deno", "rescript", "dispatcher", "gitbot-fleet"]

# State
active = true
archived = false
completion_percentage = 35
phase = "active-implementation"

# Integration
registered_in_reposystem = true
seo_score = 0
health_score = 0

# Relationships
depends_on = ["reposystem"]  # Repo IDs it depends on
provides_to = ["gitbot-fleet"]  # Repo IDs that consume it
related = ["git-hud", "git-seo"]  # Parallel tools
```

### Relationship Types

#### Dependencies (`depends_on`)
- Direct dependencies (imports, package.json deps, Cargo.toml deps)
- Data dependencies (consumes output from another tool)
- Build dependencies (required to build)

#### Providers (`provides_to`)
- Tools that consume this repo's output
- Downstream tools in pipeline
- Bots that use this tool

#### Related (`related`)
- Parallel tools (same layer, different function)
- Sibling projects
- Complementary tools

### Groups

Pre-defined groups:

- `reposystem-core` - Core reposystem tools (reposystem, git-dispatcher, etc.)
- `analysis-tools` - Analysis and monitoring (git-seo, gitvisor, etc.)
- `gitbot-fleet` - Automation bots (rhodibot, echidnabot, etc.)
- `templates` - Repository templates (rsr-template-repo, scaffoldia templates)
- `build-tools` - Build and CI tools
- `documentation` - Documentation projects

### Aspects

Pre-defined aspects:

- `execution` - Executes operations
- `analysis` - Analyzes repositories
- `automation` - Automated workflows
- `security` - Security-related
- `quality` - Code quality
- `seo` - Discoverability
- `documentation` - Documentation generation
- `scaffolding` - Repository generation

## Example: Complete Entry

```toml
[[repositories]]
id = "git-seo"
name = "git-seo"
path = "/var/mnt/eclipse/repos/git-seo"
forge = "github"
owner = "hyperpolymath"
url = "https://github.com/hyperpolymath/git-seo"

description = "Repository discoverability analysis tool"
tech_stack = ["Julia"]
created_at = "2025-01-15T00:00:00Z"

group = "analysis-tools"
aspects = ["analysis", "seo"]
tags = ["julia", "seo", "discoverability", "analysis"]

active = true
archived = false
completion_percentage = 100
phase = "production"

registered_in_reposystem = true
seo_score = 85
health_score = 90

# git-seo doesn't depend on other repos (standalone CLI)
depends_on = []

# Used by git-dispatcher (UpdateMetadataFromSeo) and git-hud (displays scores)
provides_to = ["git-dispatcher", "git-hud"]

# Related analysis tools
related = ["gitvisor", "git-health"]
```

## API Operations

### Query Operations

```rescript
// Get repository by ID
getRepo(id: string): option<repository>

// Get all repositories in group
getReposByGroup(group: string): array<repository>

// Get repositories with aspect
getReposByAspect(aspect: string): array<repository>

// Get dependencies of repo
getDependencies(id: string): array<repository>

// Get dependents (what depends on this)
getDependents(id: string): array<repository>

// Search by tag
getReposByTag(tag: string): array<repository>
```

### Mutation Operations

```rescript
// Add new repository
registerRepo(repo: repository): Result.t<unit, string>

// Update repository metadata
updateRepo(id: string, updates: Js.Dict.t<string>): Result.t<unit, string>

// Add relationship
addDependency(from: string, to: string): Result.t<unit, string>
addProvider(from: string, to: string): Result.t<unit, string>

// Remove repository
unregisterRepo(id: string): Result.t<unit, string>
```

### Validation

```rescript
// Validate graph consistency
validateGraph(): array<validationError>

// Check for circular dependencies
checkCircularDeps(): array<cycle>

// Verify all paths exist
validatePaths(): array<invalidPath>

// Check for orphaned repos (no relationships)
findOrphans(): array<repository>
```

## Implementation Plan

### v0.1.0 (Bootstrap)
- [x] Define schema
- [ ] Create empty graph.toml
- [ ] Implement TOML parser in ReScript
- [ ] Implement basic read operations
- [ ] Add validation

### v0.2.0 (Mutations)
- [ ] Implement write operations
- [ ] Add transaction support
- [ ] Implement relationship management
- [ ] Add graph visualization

### v0.3.0 (Intelligence)
- [ ] Dependency resolution
- [ ] Impact analysis (what breaks if X changes)
- [ ] Recommendation engine
- [ ] Auto-discovery from filesystem

## Usage in git-dispatcher

`RegisterInReposystem` operation:

```rescript
RegisterInReposystem({
  repoPath: "/var/mnt/eclipse/repos/new-repo",
  repoName: "new-repo",
  aspects: ["analysis"],
  group: Some("analysis-tools"),
})
```

Execution flow:
1. Read graph.toml
2. Create new [[repositories]] entry
3. Detect tech stack from files (Project.toml → Julia, Cargo.toml → Rust, etc.)
4. Scan imports/dependencies to populate `depends_on`
5. Update `.machine_readable/STATE.scm`:
   ```scheme
   (integration (reposystem-registered . "true"))
   ```
6. Write graph.toml back to disk
7. Return success with registration details

## Tooling

- **Graph visualizer**: Generate GraphViz dot file from graph.toml
- **Dependency analyzer**: Find all transitive dependencies
- **Impact calculator**: What repos are affected by changes
- **Health dashboard**: Overall ecosystem health metrics
