# Stateful Artefacts for Git Forges

## License & Philosophy

This project must declare **MPL-2.0-or-later** for platform/tooling compatibility.

Philosophy: **Palimpsest**. The Palimpsest-MPL (PMPL) text is provided in `license/PMPL-1.0.txt`, and the canonical source is the palimpsest-license repository.

**Metadata-driven documentation that updates automatically as your project evolves.**

Gnosis reads your project's 6scm metadata files and renders dynamic templates into static documentation that **stays current**—automatically updating repo counts, completion percentages, phase changes, and more as your project grows.

```
Today:     "426 repositories"
Two years: "537 repositories"  ← Updated automatically, no manual editing
```

---

## The Problem

Traditional documentation requires manual updates:
- README claims "426 repos" but you now have 537 (manual count, out of date)
- "80% complete" but project is actually 35% (manual estimate, wrong)
- "Currently in alpha" but you shipped beta last month (manual phase, stale)

**Every update requires:**
1. Remember to update the number
2. Find all places it appears (README, wiki, website)
3. Manual search-and-replace
4. Hope you didn't miss any

**Result:** Documentation goes stale in days.

---

## The Solution: Single Source of Truth

### Before (Manual Hell)
```markdown
README.md:     "426 repositories" ← Manual, stale
website.html:  "426 projects"     ← Manual, stale
wiki.md:       "425 repos"        ← Manual, WRONG
```

### After (Automated Truth)
```scheme
;; .machine_readable/STATE.scm
(state
  (stats
    (repo-count . 537)))  ← ONE place, auto-updated by scripts
```

```markdown
;; README.template.md
**(:repo-count) repositories** ← Renders to "537 repositories"

;; website.template.html
<p>(:repo-count) projects</p>  ← Renders to "537 projects"

;; WIKI.template.md
Total: (:repo-count) repos     ← Renders to "537 repos"
```

**One update in STATE.scm → All docs update automatically.**

---

## How It Works

### 1. Automation Updates Metadata

Your CI/GitHub Actions/cron jobs update STATE.scm:

```bash
#!/bin/bash
# update-stats.sh - runs daily via cron

# Count repositories
REPO_COUNT=$(gh repo list hyperpolymath --limit 1000 | wc -l)

# Update STATE.scm
sed -i "s/(repo-count . [0-9]*)/(repo-count . $REPO_COUNT)/" .machine_readable/STATE.scm

# Re-render all docs
gnosis README.template.md README.md
gnosis PROFILE.template.md PROFILE.md
gnosis wiki/HOME.template.md wiki/HOME.md

# Commit
git add .
git commit -m "docs: update stats (repo-count: $REPO_COUNT)"
git push
```

### 2. Gnosis Renders Templates

Template with placeholder:
```markdown
I maintain **(:repo-count) open source repositories**.
```

Gnosis replaces `(:repo-count)` with current value from STATE.scm:
```markdown
I maintain **537 open source repositories**.
```

### 3. Git Forge Displays Current State

- GitHub: Shows README.md with "537 repositories"
- GitLab: Shows wiki with "537 repositories"
- Bitbucket: Shows profile with "537 repositories"

All numbers **guaranteed in sync** because they come from one source.

---

## Djot Support for Git Forges

### What is Djot?

[Djot](https://djot.net/) is a light markup language (like Markdown) with:
- Consistent, unambiguous syntax
- Better table support
- Semantic footnotes
- Math notation

### Git Forge Support

| Forge | Native Djot | Workaround |
|-------|-------------|------------|
| **GitHub** | ❌ Not yet | ✅ Render to `.md` with Gnosis |
| **GitLab** | ❌ Not yet | ✅ Render to `.md` or HTML |
| **Gitea** | ❌ Not yet | ✅ Render to `.md` |
| **Sourcehut** | ⚠️ Partial | ✅ Render to `.md` |

**Gnosis Strategy:**
1. Write templates in Djot (`.template.djot`)
2. Gnosis renders to Markdown (`.md`) for GitHub/GitLab
3. When forges add Djot support, switch output to `.djot`

**Benefits:**
- Write in superior markup (Djot)
- Output compatible format (Markdown)
- Future-proof (ready for native Djot)

### Example: Profile Page

`PROFILE.template.djot`:

```djot
# Jonathan D.A. Jewell (@hyperpolymath)

## Stats

::: metrics
| Metric | Value |
|--------|-------|
| Repositories | (:repo-count) |
| Total Stars | (:star-count) |
| Active Projects | (:active-count) |
| Languages | (:language-count) |
:::

## Current Focus

**Phase:** (:current-phase)
**Working on:** (:current-focus)

Last updated: (:last-updated)
```

Rendered output (`PROFILE.md`):

```markdown
# Jonathan D.A. Jewell (@hyperpolymath)

## Stats

| Metric | Value |
|--------|-------|
| Repositories | 537 |
| Total Stars | 1,243 |
| Active Projects | 47 |
| Languages | 23 |

## Current Focus

**Phase:** Shipping ProvenCrypto.jl v0.1
**Working on:** Post-quantum cryptography implementation

Last updated: 2026-01-24
```

---

## Live Example: Repo Count Over Time

### Day 1 (2024-01-01)
```scheme
;; STATE.scm
(stats (repo-count . 426))
```
→ README: "I maintain **426 repositories**"

### 6 Months Later (2024-07-01)
Your automation script runs, detects 473 repos, updates STATE.scm:
```scheme
;; STATE.scm
(stats (repo-count . 473))
```
→ README: "I maintain **473 repositories**" ← Auto-updated!

### 2 Years Later (2026-01-01)
Script detects 537 repos:
```scheme
;; STATE.scm
(stats (repo-count . 537))
```
→ README: "I maintain **537 repositories**" ← Still current!

**You never manually edited the README. It stayed current automatically.**

---

## Quick Start

### Installation

**Prerequisites:** GHC 9.0+ and either Stack or Cabal

#### Option 1: Using Stack (Recommended)

```bash
# Clone repository
git clone https://github.com/hyperpolymath/stateful-artefacts-for-gitforges
cd stateful-artefacts-for-gitforges/gnosis

# Build with Stack
stack build

# Binary location:
# .stack-work/install/x86_64-linux-tinfo6/.../9.14.1/bin/gnosis

# Optional: Install to ~/.local/bin
stack install
```

#### Option 2: Using Cabal

```bash
# Clone repository
git clone https://github.com/hyperpolymath/stateful-artefacts-for-gitforges
cd stateful-artefacts-for-gitforges/gnosis

# Build with Cabal
cabal update
cabal build
cabal install
```

### Basic Usage

```bash
# 1. Create metadata
cat > .machine_readable/STATE.scm << 'EOF'
(state
  (identity
    (name . "My Project")
    (version . "1.0.0"))
  (stats
    (repo-count . 426)))
EOF

# 2. Create template
cat > README.template.md << 'EOF'
# (:name)

Version: (:version)
Repositories: (:repo-count)
EOF

# 3. Render
gnosis README.template.md README.md

# Output:
# # My Project
#
# Version: 1.0.0
# Repositories: 426
```

### Automated Updates

`.github/workflows/update-stats.yml`:

```yaml
name: Update Statistics
on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Count repositories
        id: stats
        run: |
          REPO_COUNT=$(gh repo list ${{ github.repository_owner }} --limit 1000 | wc -l)
          echo "repo_count=$REPO_COUNT" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Update STATE.scm
        run: |
          # Update repo count in STATE.scm
          sed -i "s/(repo-count . [0-9]*)/(repo-count . ${{ steps.stats.outputs.repo_count }})/" \
            .machine_readable/STATE.scm

      - name: Install Gnosis
        run: |
          cd gnosis
          cabal update
          cabal install

      - name: Render templates
        run: |
          gnosis README.template.md README.md
          gnosis PROFILE.template.md PROFILE.md

      - name: Commit changes
        run: |
          git config user.name "Gnosis Bot"
          git config user.email "bot@gnosis"
          git add .
          git diff-index --quiet HEAD || \
            git commit -m "docs: update stats (repos: ${{ steps.stats.outputs.repo_count }})"
          git push
```

**Result:** Your README updates automatically every day with current repo count!

---

## Dynamic Placeholders

### Project Statistics

```scheme
;; STATE.scm
(stats
  (repo-count . 537)
  (star-count . 1243)
  (contributor-count . 42)
  (language-count . 23)
  (active-count . 47)
  (archived-count . 490))
```

Template:
```markdown
**(:repo-count)** repos | **(:star-count)** stars | **(:contributor-count)** contributors
```

Output:
```markdown
**537** repos | **1,243** stars | **42** contributors
```

### Project Phase

```scheme
;; STATE.scm
(identity
  (phase . "beta")
  (version . "0.8.0")
  (mood . "flow"))

(milestones
  ((name . "v1.0")
   (completion . 85)))
```

Template:
```markdown
**Phase:** (:phase) | **Version:** (:version) | **Mood:** (:mood)
**Progress to v1.0:** (:completion)%
```

Output:
```markdown
**Phase:** beta | **Version:** 0.8.0 | **Mood:** flow
**Progress to v1.0:** 85%
```

### Temporal Updates

```scheme
;; STATE.scm updated by automation
(temporal
  (last-commit . "2026-01-24T14:32:00Z")
  (last-release . "2026-01-15")
  (days-since-release . 9)
  (commits-this-month . 47))
```

Template:
```markdown
Last commit: (:last-commit)
Last release: (:last-release) ((:days-since-release) days ago)
Activity: (:commits-this-month) commits this month
```

Output updates daily as automation recalculates `days-since-release` and `commits-this-month`.

---

## The 6scm Standard

Gnosis reads six Scheme files (the "6scm" standard):

| File | Purpose | Example Placeholders |
|------|---------|---------------------|
| **STATE.scm** | Current state, stats, milestones | `:repo-count`, `:version`, `:phase`, `:completion` |
| **ECOSYSTEM.scm** | Related projects, dependencies | `:related-count`, `:dependency-count` |
| **META.scm** | Architecture decisions, ADRs | `:adr-count`, `:decision-count` |
| **NEUROSYM.scm** | Neural-symbolic patterns | `:neural-components`, `:symbolic-components` |
| **AGENTIC.scm** | AI agent capabilities | `:agent-count`, `:autonomy-level` |
| **PLAYBOOK.scm** | Operational runbooks | `:playbook-count`, `:runbook-count` |

### Placeholder Resolution

Gnosis searches all 6scm files for matching keys:

```scheme
;; Any of these works:
(repo-count . 537)          ;; In STATE.scm
(state (stats (repo-count . 537)))  ;; Nested
(identity (repo-count . 537))       ;; Different section
```

Template `(:repo-count)` resolves to `537` from **any** 6scm file.

---

## FlexiText: Accessibility First

Every dynamic value is a **FlexiText** with:
- **Visual:** What sighted users see (emoji, badge, number)
- **Alt-text:** What screen readers announce

```haskell
FlexiText
  { visual = "537"
  , altText = "Repository count: 537"
  }
```

### Badge Mode

```bash
gnosis --badges README.template.md README.md
```

Renders `(:repo-count)` as a Shields.io badge:

```markdown
![Repository count: 537](https://img.shields.io/badge/537-grey?label=repositories)
```

Result: ![Repository count: 537](https://img.shields.io/badge/537-grey?label=repositories)

**Screen reader announcement:** "Image: Repository count: 537"

---

## Tri-Guard Safety System

Gnosis enforces three security guarantees:

### Guard 1: Sanitization
- URL placeholders: Only `a-zA-Z0-9-_./:`
- Alt-text: No `[]"` (breaks Markdown)
- Table cells: No `|` or `\n`

### Guard 2: Validation
- Alt-text cannot be empty (accessibility violation)
- Keys must exist in 6scm files or show `(:MISSING:key)`

### Guard 3: Accessibility
- Every visual element paired with alt-text
- Screen reader compatible

---

## Automation Examples

### Daily Stats Update

```bash
#!/bin/bash
# automation/update-daily-stats.sh

# Fetch current stats
REPOS=$(gh repo list hyperpolymath --limit 1000 | wc -l)
STARS=$(gh repo list hyperpolymath --limit 1000 --json stargazerCount --jq 'map(.stargazerCount) | add')
COMMITS_THIS_MONTH=$(git log --since="1 month ago" --all --oneline | wc -l)

# Update STATE.scm
cat > .machine_readable/STATE.scm << EOF
(state
  (stats
    (repo-count . $REPOS)
    (star-count . $STARS)
    (commits-this-month . $COMMITS_THIS_MONTH)
    (last-updated . "$(date -Iseconds)")))
EOF

# Re-render all templates
gnosis README.template.md README.md
gnosis PROFILE.template.md PROFILE.md

# Commit
git add .
git commit -m "docs: daily stats update (repos: $REPOS, stars: $STARS)"
git push
```

### Project Phase Progression

```bash
#!/bin/bash
# automation/advance-phase.sh

# When CI detects 100% milestone completion, advance phase
COMPLETION=$(grep -oP '(?<=completion . )\d+' .machine_readable/STATE.scm)

if [ "$COMPLETION" -ge 100 ]; then
  # Advance from alpha → beta → rc → stable
  sed -i 's/(phase . "alpha")/(phase . "beta")/' .machine_readable/STATE.scm

  gnosis README.template.md README.md
  git commit -am "docs: advance to beta phase"
  git push
fi
```

---

## Roadmap

### Horizon 1: Clean Foundation (50% Complete)
- [x] Tri-Guard Sanitization
- [x] FlexiText Accessibility
- [x] S-expression parser
- [x] Template renderer with `(:placeholder)` syntax
- [ ] Paxos-Lite conflict resolution
- [ ] Full 6scm parser (currently parses STATE.scm)

### Horizon 2: Logic Layer (DAX Era) (0% Complete)
- [ ] Conditional rendering: `{{#if phase == "beta"}}...{{/if}}`
- [ ] Loops: `{{#for milestone in milestones}}...{{/for}}`
- [ ] Functions: `{{repo-count | thousands-separator}}`
- [ ] Time intelligence: `{{last-updated | relativeTime}}`
- [ ] Arithmetic: `{{(completed / total) * 100}}%`

### Horizon 3: Neurosymbolic Bridge (0% Complete)
- [ ] Code scanning (detect banned languages)
- [ ] Language compliance audit (auto-update `compliance-level`)
- [ ] Living dashboard (real-time project health visualization)
- [ ] Git forge API integration (auto-sync GitHub/GitLab)
- [ ] AI agent suggestions (review PRs, suggest milestone updates)

---

## Philosophy

### Single Source of Truth
6scm files are the **only** authoritative state. READMEs, wikis, profiles, and dashboards are **derived** outputs—never manually edited.

### Automation-First
Humans write templates once. Automation updates 6scm files. Gnosis re-renders. Docs stay current without manual editing.

### Accessibility by Default
Every visual element has alt-text. No exceptions. Screen reader users get full information.

### Machine-Readable First
- Humans read rendered docs (README.md, wiki)
- Machines read 6scm files (STATE.scm, ECOSYSTEM.scm)
- Both stay in sync automatically

### Neurosymbolic
- **Symbolic:** 6scm files (machine-parseable Scheme)
- **Neural:** (Future) AI agents suggest updates based on code analysis, humans approve

---

## Use Cases

### Open Source Maintainer Profile

**Problem:** Profile says "I maintain 426 repos" but you actually have 537.

**Solution:**
```scheme
;; STATE.scm (updated by GH Actions daily)
(stats (repo-count . 537))
```

```markdown
;; PROFILE.template.md
I maintain (:repo-count) open source repositories.
```

**Result:** Profile always shows current count. No manual updates.

### Multi-Repo Organization

**Problem:** Organization has hundreds of repos. README lists "Active: 42" but it's actually 58.

**Solution:**
```bash
# Count active (non-archived) repos
ACTIVE=$(gh repo list myorg --limit 1000 --json isArchived --jq 'map(select(.isArchived == false)) | length')

# Update STATE.scm
sed -i "s/(active-count . [0-9]*)/(active-count . $ACTIVE)/" STATE.scm
```

**Result:** Organization README always shows accurate active count.

### Project Roadmap

**Problem:** README claims "60% to v1.0" but you're at 85% after recent sprint.

**Solution:**
```scheme
;; STATE.scm (updated by Jira/Linear webhook)
(milestones
  ((name . "v1.0")
   (completion . 85)))
```

```markdown
;; README.template.md
**Progress to v1.0:** (:completion)%
```

**Result:** Roadmap percentage updates automatically as issues close.

---

## Contributing

1. Update `.machine_readable/*.scm` files (never edit rendered docs)
2. Run `gnosis` to regenerate all templates
3. Commit both `.scm` files and rendered outputs
4. CI validates `.scm` syntax and re-renders on merge

---

## License

- **Gnosis engine:** AGPL-3.0-or-later (Haskell code)
- **6scm standard:** PMPL-1.0-or-later (Scheme metadata format)
- **Templates:** Your choice (MIT, CC0, etc.)

---

## Author

Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

---

## References

- [6scm Standard Specification](https://github.com/hyperpolymath/6scm)
- [Djot Markup Language](https://djot.net/)
- [Shields.io Badge API](https://shields.io/)
- [Paxos Algorithm (Conflict Resolution)](https://lamport.azurewebsites.net/pubs/paxos-simple.pdf)
- [FlexiText Accessibility Model](./docs/flexitext.md)
- [Tri-Guard Safety System](./docs/tri-guard.md)

---

*This README was generated by Gnosis v0.1.0 from README.template.md*
*Last updated: 2026-01-24 (Repo count: 537)*
