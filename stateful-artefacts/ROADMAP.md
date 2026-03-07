# Stateful Artefacts for Git Forges - Roadmap

## Vision

Transform Git forge documentation from static, manually-maintained files to **self-updating artifacts** that stay current through automation and metadata-driven rendering.

---

## Horizon 1: Clean Foundation (50% Complete) ✅

**Target:** Q1 2026
**Status:** In Progress

### Completed Features
- ✅ **Tri-Guard Sanitization System**
  - URL sanitization (alphanumeric + safe chars only)
  - Alt-text sanitization (no Markdown-breaking chars)
  - Table cell sanitization (no pipes or newlines)

- ✅ **FlexiText Accessibility Model**
  - Every visual element paired with semantic alt-text
  - Screen reader compatibility guaranteed
  - Non-empty alt-text enforcement (compile-time check)

- ✅ **S-Expression Parser**
  - Recursive descent parser for Scheme syntax
  - Comment stripping
  - Dotted pair support: `(key . "value")`
  - List syntax: `(key "value")`

- ✅ **Template Renderer**
  - `(:placeholder)` syntax
  - Context-driven replacement from 6scm files
  - Missing key detection: `(:MISSING:key)`

- ✅ **Gnosis Haskell Engine**
  - Fast, type-safe template hydration
  - Functional architecture
  - Zero runtime dependencies (static binary)

### Remaining Work
- [ ] **Paxos-Lite Conflict Resolution**
  - Timestamp-based ballot numbers
  - Last-write-wins with causality tracking
  - Merge conflicts from concurrent STATE.scm updates

- [ ] **Full 6scm Parser**
  - Currently: Parses STATE.scm only
  - Target: Parse all 6 files (ECOSYSTEM, META, NEUROSYM, AGENTIC, PLAYBOOK)
  - Deep tree traversal for nested keys
  - Cross-file placeholder resolution

---

## Horizon 2: Logic Layer (DAX Era) (0% Complete) 🚧

**Target:** Q2-Q3 2026
**Status:** Planned

### Conditional Rendering

**Syntax:**
```djot
{{#if mood == "crunch"}}
⚠️ Project in crunch mode - expect delays
{{/if}}

{{#if completion >= 80}}
🎉 Almost done! Just (:completion)% to go.
{{/if}}
```

**Implementation:**
- Boolean expressions: `==`, `!=`, `>`, `<`, `>=`, `<=`
- Logical operators: `&&`, `||`, `!`
- String matching: `phase == "beta"`
- Numeric comparison: `health > 50`

### Iteration

**Syntax:**
```djot
## Milestones

{{#for milestone in milestones}}
### {{milestone.name}}
**Status:** {{milestone.status}}
**Completion:** {{milestone.completion}}%
{{/for}}
```

**Implementation:**
- List iteration from 6scm arrays
- Nested property access: `milestone.name`
- Index access: `{{@index}}` for counter
- Filter support: `{{#for repo in repos where repo.active}}`

### Functions (Filters)

**Syntax:**
```djot
Last updated: {{last-updated | relativeTime}}
Stars: {{star-count | thousands-separator}}
Progress: {{(completed / total) * 100 | round 2}}%
```

**Built-in Functions:**
| Function | Purpose | Example |
|----------|---------|---------|
| `relativeTime` | "2 days ago" from ISO timestamp | `{{timestamp \| relativeTime}}` |
| `thousands-separator` | Add commas: 1243 → 1,243 | `{{count \| thousands-separator}}` |
| `round` | Round float to N decimals | `{{85.7283 \| round 2}}` → 85.73 |
| `percentage` | Multiply by 100, add % | `{{0.85 \| percentage}}` → 85% |
| `uppercase` | ALL CAPS | `{{phase \| uppercase}}` → BETA |
| `lowercase` | all lowercase | `{{name \| lowercase}}` |
| `capitalize` | Title Case | `{{name \| capitalize}}` |

### Arithmetic

**Syntax:**
```djot
Progress: {{(completed / total) * 100}}%
Remaining: {{total - completed}} items
Average: {{sum / count | round 1}}
```

**Operators:** `+`, `-`, `*`, `/`, `%` (modulo), `^` (power)

### Time Intelligence

**Relative Time:**
```djot
Last commit: {{last-commit | relativeTime}}
```
Output: "2 hours ago", "3 days ago", "2 months ago"

**Date Formatting:**
```djot
Released: {{release-date | dateFormat "MMMM DD, YYYY"}}
```
Output: "January 15, 2026"

**Duration Calculations:**
```djot
Project age: {{created-at | durationUntil now | humanize}}
```
Output: "2 years, 3 months"

---

## Horizon 2.5: Static Site Generation & Browser Extension (0% Complete) 🌐

**Target:** Oct-Dec 2026
**Status:** Planned

### casket-ssg Integration (v0.6.0)

**Merge Gnosis into casket-ssg:**

casket-ssg is an existing Haskell-based static site generator at `hyperpolymath/casket-ssg`. It already has:
- Frontmatter parsing
- Markdown rendering
- Template engine (`{{placeholder}}` syntax)
- Build pipeline and file watching

**Integration Plan:**

1. **Add Gnosis modules to casket-ssg:**
```
casket-ssg/src/
├── Gnosis/
│   ├── Types.hs      # FlexiText, Context
│   ├── SExp.hs       # S-expression parser
│   └── Render.hs     # (:placeholder) renderer
├── Format.hs         # Format detection (Markdown/Djot/AsciiDoc)
└── Casket.hs         # Main (enhanced with Gnosis)
```

2. **Enhanced Frontmatter:**
```yaml
---
title: My Post
format: djot           # NEW: format preference
template: blog
---
```

3. **Unified Pipeline:**
```haskell
processFile :: Context -> FilePath -> FilePath -> IO ()
processFile gnosisCtx inputPath outputPath = do
  content <- readFile inputPath
  let (fm, body) = parseFrontmatter content

  -- Detect format (from frontmatter or file extension)
  let format = detectFormat fm inputPath

  -- Parse with appropriate format parser
  html <- case format of
    Markdown  -> return $ parseMarkdown body
    Djot      -> parseDjot body      -- Via Pandoc
    AsciiDoc  -> parseAsciiDoc body  -- Via Pandoc
    Org       -> parseOrg body       -- Via Pandoc

  -- Apply Gnosis rendering ((:placeholder) from 6scm)
  let hydrated = renderWithMode PlainText gnosisCtx html

  -- Apply casket template ({{title}} from frontmatter)
  let output = applyTemplate fm hydrated

  writeFile outputPath output
```

4. **6scm as Site-Wide Context:**
```bash
# Site structure
my-site/
├── .machine_readable/
│   ├── STATE.scm          # Site-wide metadata
│   └── ECOSYSTEM.scm
├── content/
│   ├── post1.md
│   └── post2.djot         # Djot format
└── templates/
    └── blog.html

# Build command
casket-ssg build content/ _site/
# Loads 6scm context ONCE
# Processes all content files
# Renders (:placeholders) from 6scm
# Outputs static site
```

**Benefits:**
- Write in any format (Markdown, Djot, AsciiDoc, Org)
- Metadata-driven (6scm context available everywhere)
- Accessibility-enforced (FlexiText for all dynamic content)
- Temporal updates (automation updates 6scm, site rebuilds)

---

### Browser Extension (v0.8.0)

**Client-Side Format Preference:**

**Problem:** Git forges (GitHub, GitLab) control rendering. You can't say "render my .md as Djot."

**Solution:** Browser extension that respects repository owner's format preference.

**How It Works:**

1. **Repository owner adds to META.scm:**
```scheme
(rendering-preferences
  (preferred-format . "djot")
  (fallback-format . "markdown"))
```

2. **Extension detects when viewing .md files:**
- Checks if repo has `.machine_readable/META.scm`
- Reads `rendering-preferences`
- Fetches .md content via GitHub API
- Re-renders with preferred format parser (Djot.js)
- Injects rendered HTML into page

3. **User experience:**
- Extension users see: Content in owner's preferred format
- Non-extension users see: GitHub's default Markdown
- Repository owner: Controls presentation via metadata

**Technology Stack:**
- Browser extension: Chrome/Firefox WebExtension API
- Parser: Djot.js (compiled to WebAssembly)
- API: GitHub/GitLab REST API for content fetching
- Caching: IndexedDB for parsed content

**Privacy:**
- Extension only activates on Git forge domains
- Reads only public repositories (or user's authorized repos)
- No data sent to external servers
- All parsing happens client-side

---

## Horizon 3: Neurosymbolic Bridge (0% Complete) 🔮

**Target:** Q1-Q2 2027
**Status:** Research

### Code Scanning

**Detect Banned Languages:**
```bash
# Scan repo for Python/Go/Node.js (banned per RSR)
gnosis scan --detect-languages

# Output:
# ⚠️ Found banned language: Python (3 files)
#   - scripts/legacy.py
#   - tools/convert.py
#   - setup.py
# ✅ Compliant: No banned languages found
```

**Auto-Update Compliance:**
```scheme
;; Before scan
(vital-signs (compliance-level . "A"))

;; After detecting Python
(vital-signs (compliance-level . "F"))  ;; Auto-downgraded
```

### Language Compliance Audit

**Automatic Compliance Detection:**
1. Scan repository for source files
2. Detect languages (file extensions, shebang lines)
3. Check against allowlist (Julia, Rust, Haskell, ReScript, Gleam, Elixir)
4. Check against blocklist (Python, Go, Node.js, TypeScript)
5. Update `compliance-level` in STATE.scm:
   - `A`: All compliant
   - `B`: Warnings (deprecated languages in non-critical paths)
   - `F`: Banned languages present

**CI Integration:**
```yaml
# .github/workflows/compliance-audit.yml
- name: Scan for banned languages
  run: gnosis scan --update-state

- name: Fail if non-compliant
  run: |
    COMPLIANCE=$(grep -oP '(?<=compliance-level . ")[^"]*' STATE.scm)
    if [ "$COMPLIANCE" = "F" ]; then
      echo "❌ Failed: Banned languages detected"
      exit 1
    fi
```

### Living Dashboard

**Real-Time Project Health:**
- Web-based dashboard reading 6scm files
- Metrics:
  - Completion velocity (% per week)
  - Blocker analysis (critical/high/medium/low)
  - Compliance trend over time
  - Commit activity heatmap
  - Milestone burn-down charts

**Technology:**
- Backend: Haskell (Servant API reading 6scm files)
- Frontend: ReScript + React (per RSR)
- Deployment: Static site + API (Netlify/Vercel)

**Features:**
- Historical trends (track STATE.scm changes over time via Git)
- Predictive analytics (estimate completion date based on velocity)
- Alert system (Slack/Discord when health drops below threshold)

### Git Forge API Integration

**Auto-Sync to GitHub/GitLab:**
```bash
# Gnosis fetches data from Git forge API
gnosis sync github --owner hyperpolymath

# Updates STATE.scm with:
# - Repo count
# - Star count
# - Issue count
# - PR count
# - Recent activity

# Then re-renders templates
gnosis render --all

# Commits back to repo
git commit -am "docs: sync from GitHub API"
```

**Two-Way Sync:**
1. **Pull:** Fetch stats from forge → Update STATE.scm → Render
2. **Push:** Update STATE.scm → Render → Commit → Push to forge

### AI Agent Suggestions

**Neural Analysis:**
- Scan commit messages for completion signals
  - "Closes #42" → Increment completion %
  - "Fixes bug in module X" → Update health score
- Analyze code churn to predict stability
- Suggest milestone updates based on velocity

**Symbolic Verification:**
- Humans approve all STATE.scm changes
- AI proposes, humans dispose
- Audit trail of agent suggestions

**Example Flow:**
1. Agent detects: "Last 3 PRs closed issues for Milestone v1.0"
2. Agent suggests: "Update v1.0 completion from 75% to 85%"
3. Human reviews: "Approve" or "Reject"
4. If approved: STATE.scm updated, docs re-rendered

---

## Future Ideas (Beyond Horizon 3)

### Multi-Language Template Support
- Input: Djot, Markdown, AsciiDoc, Org-mode
- Output: HTML, PDF, EPUB, man pages

### Plugin System
- Custom functions via Haskell plugins
- Example: `{{repo | ghStars}}` fetches live star count

### CRDT-Based Merging
- Conflict-free replicated data types for STATE.scm
- Multiple tools can update simultaneously
- Automatic merge without conflicts

### Blockchain Timestamping
- Cryptographic proof of STATE.scm updates
- Immutable audit trail
- Verify "This project was 85% complete on 2026-03-15"

### Natural Language Queries
- Ask: "What was our completion percentage last month?"
- Gnosis parses Git history of STATE.scm
- Returns: "You were at 62% on January 1st"

---

## Release Schedule

| Version | Target Date | Horizon | Key Features |
|---------|-------------|---------|--------------|
| **v0.1.0** | 2026-01-31 | H1 | Gnosis engine, basic rendering, 6scm templates |
| **v0.2.0** | 2026-02-28 | H1 | Paxos-Lite, full 6scm parser |
| **v0.3.0** | 2026-04-30 | H2 | Conditional rendering, loops |
| **v0.4.0** | 2026-06-30 | H2 | Functions, time intelligence |
| **v0.5.0** | 2026-09-30 | H2 | Arithmetic, time intelligence |
| **v0.6.0** | 2026-10-31 | H2.5 | casket-ssg integration, multi-format support |
| **v0.7.0** | 2026-11-30 | H3 | Code scanning, compliance audit |
| **v0.8.0** | 2026-12-31 | H2.5 | Browser extension, format preferences |
| **v0.9.0** | 2027-02-28 | H3 | Living dashboard, Git forge API integration |
| **v1.0.0** | 2027-03-31 | H3 | AI suggestions, plugin system, Git forge complete |

---

## Contributing

Want to help build the future of metadata-driven documentation?

### Priority Areas
1. **DAX Era Logic Layer** (Q2 2026)
   - Implement conditional rendering parser
   - Add iteration support
   - Build function registry

2. **Language Compliance Scanner** (Q3 2026)
   - File extension detection
   - Shebang parsing
   - Allowlist/blocklist checking

3. **Living Dashboard** (Q4 2026)
   - ReScript frontend
   - Haskell API backend
   - Historical trend analysis

### How to Contribute
1. Check [GitHub Issues](https://github.com/hyperpolymath/stateful-artefacts-for-gitforges/issues)
2. Pick a Horizon 2 or 3 feature
3. Open a PR with tests
4. Update this ROADMAP with your progress

---

## License

PMPL-1.0-or-later (Polymathematical Meta-Public License)

---

*This roadmap is metadata-driven! It's generated from ROADMAP.template.md using STATE.scm.*
*Last updated: 2026-01-24*
