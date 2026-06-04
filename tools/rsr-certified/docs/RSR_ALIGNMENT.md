<!--
SPDX-License-Identifier: MPL-2.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# RSR Framework Alignment

This document explains how `git-rsr-certified` aligns with and extends the [Rhodium Standard Repositories](https://gitlab.com/hyperpolymath/rhodium-standard-repositories) framework.

## Relationship to RSR

```
┌─────────────────────────────────────────────────────────────────┐
│                    RSR ECOSYSTEM                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────┐     ┌─────────────────────────────┐   │
│  │  RSR Framework      │     │  git-rsr-certified          │   │
│  │  (Standards Body)   │────▶│  (Enforcement Engine)       │   │
│  │                     │     │                             │   │
│  │  • Defines rules    │     │  • Checks compliance        │   │
│  │  • 150+ criteria    │     │  • Universal platform       │   │
│  │  • CCCP principles  │     │  • Automated verification   │   │
│  └─────────────────────┘     └─────────────────────────────┘   │
│           │                              │                      │
│           ▼                              ▼                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Compliant Repositories                      │   │
│  │  • Emotionally safe development                         │   │
│  │  • Technically excellent                                │   │
│  │  • Politically autonomous                               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Tier Mapping

| RSR Level | git-rsr-certified Tier | Score |
|-----------|------------------------|-------|
| 🏆 Gold | ◆ Rhodium | 100% |
| 🥈 Silver | ★ Gold | 90-99% |
| 🥉 Bronze | ☆ Silver | 75-89% |
| Non-Compliant | ● Bronze | <75% |

## RSR Compliance Categories Mapped to Checks

### 1. Foundational Infrastructure
- [x] Nix flake support → `rhodium.reproducible_builds`
- [x] Justfile presence → `silver.ci_config` (build automation)
- [x] GitLab CI / GitHub Actions → `silver.ci_config`
- [x] Podman/Container support → Container deployment
- [x] Git configuration → Base requirement

### 2. Documentation Standards
- [x] README → `bronze.readme`
- [x] LICENSE → `bronze.license`
- [x] SECURITY.md → `silver.security_policy`
- [x] CODE_OF_CONDUCT.md → `silver.code_of_conduct`
- [x] CONTRIBUTING.md → `silver.contributing`
- [ ] .well-known/ directory → *Planned for Rhodium tier*

### 3. Security Architecture
- [x] No hardcoded secrets → `bronze.no_secrets`
- [x] Dependency scanning → `gold.dependency_scanning`
- [ ] SPDX headers → *Planned*
- [ ] Supply chain security (SLSA) → `rhodium.slsa`

### 4. Architecture Principles
- [ ] Offline-first → *Future check*
- [ ] CRDTs → *Future check*
- [x] Reproducible builds → `rhodium.reproducible_builds`

### 5. Lifecycle Management
- [x] Dependency management → Lock files check
- [x] Changelog → `silver.changelog`
- [ ] SemVer enforcement → *Planned*

### 6. Community & Governance
- [x] Contributing guide → `silver.contributing`
- [x] Code of Conduct → `silver.code_of_conduct`
- [ ] GOVERNANCE.md → *Planned for Gold tier*

## Self-Compliance

This repository (`git-rsr-certified`) aims to achieve **RSR Gold (Silver tier in RSR terms)**:

### Current Status
```
✓ LICENSE (MIT + Apache-2.0 dual license)
✓ README.md
✓ CONTRIBUTING.md
✓ CODE_OF_CONDUCT.md
✓ SECURITY.md
✓ CI/CD (.github/workflows/)
✓ Containerized deployment
✓ Dependency management (Cargo.lock)
○ .well-known/ directory (in progress)
○ GOVERNANCE.md (in progress)
○ Nix flake (in progress)
```

## Database Architecture

For production compliance tracking, we use a multi-database architecture:

```
┌──────────────────────────────────────────────────────────────┐
│                    DATA LAYER                                 │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │
│  │  DragonflyDB   │  │   SurrealDB    │  │   ArangoDB     │ │
│  │  (Cache/Queue) │  │  (Documents)   │  │   (Graphs)     │ │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘ │
│          │                   │                   │          │
│          └───────────────────┼───────────────────┘          │
│                              │                              │
│                    ┌─────────▼─────────┐                    │
│                    │   RSR Engine      │                    │
│                    │   Data Layer      │                    │
│                    └───────────────────┘                    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### DragonflyDB (Redis-compatible)
- **Purpose**: Caching, job queues, rate limiting
- **Why**: 25x faster than Redis, drop-in compatible
- **Use cases**:
  - Webhook event queue
  - API response caching
  - Rate limit counters
  - Session storage

### SurrealDB (Multi-model)
- **Purpose**: Primary compliance data store
- **Why**: Document + graph + relational in one, with built-in auth
- **Use cases**:
  - Compliance reports (documents)
  - Repository metadata
  - User/org data
  - Audit history

### ArangoDB (Graph-focused)
- **Purpose**: Relationship and dependency tracking
- **Why**: Native graph queries, excellent for dependency trees
- **Use cases**:
  - Dependency graphs
  - Repository relationships
  - Compliance inheritance
  - Impact analysis

## CCCP Alignment

The Campaign for Cooler Coding and Programming principles embedded in RSR:

| CCCP Principle | Implementation in git-rsr-certified |
|----------------|-------------------------------------|
| Emotional Safety | Clear error messages, non-judgmental reports |
| Offline-First | CLI works without network, local checks |
| Post-JS Liberation | Written in Rust, not JavaScript |
| Formal Verification | Type-safe compliance checks |
| Community Over Ego | Open contribution model |
| Language Polyglotism | Supports all language ecosystems |

## Integration with rsr-audit.sh

The existing `rsr-audit.sh` script can be used alongside git-rsr-certified:

```bash
# RSR framework audit (shell-based, 150+ checks)
./rsr-audit.sh /path/to/repo

# git-rsr-certified (Rust engine, platform integration)
rsr check /path/to/repo

# Both produce compatible compliance levels
```

### Complementary Roles
- **rsr-audit.sh**: Deep, comprehensive local audits
- **git-rsr-certified**: Automated CI/CD integration, webhooks, badges

## Roadmap for Full RSR Alignment

### Phase 1 (Current)
- [x] Core compliance checks (Bronze/Silver/Gold)
- [x] Multi-platform support
- [x] Containerized deployment

### Phase 2 (Next)
- [ ] Full RSR 150+ check coverage
- [ ] .well-known/ directory checks
- [ ] GOVERNANCE.md validation
- [ ] Nix flake integration

### Phase 3 (Future)
- [ ] CCCP principle validation
- [ ] Emotional safety metrics
- [ ] Community health scoring
- [ ] Formal verification integration

## Contributing to RSR Alignment

We follow the RSR Tri-Perimeter Contribution Framework (TPCF):

- 🔒 **Perimeter 1 (Core)**: Engine architecture, security
- 🧠 **Perimeter 2 (Expert)**: New compliance checks, adapters
- 🌱 **Perimeter 3 (Community)**: Documentation, tests, proposals

See [CONTRIBUTING.md](../CONTRIBUTING.adoc) for details.
