# Stateful Artefacts - Vision Roadmap (v0.0.1 → v10.0)

## Executive Summary

**Paradigm Shift:** From static content that goes stale → **metadata-driven artifacts that stay current**

**Problem at Scale:**
- **Billions** of stale READMEs on GitHub ("426 repos" but actually 537)
- **Millions** of outdated project websites ("v0.8" but shipped v1.2 last year)
- **Thousands** of corporate dashboards with manual KPI updates
- **Universal:** Every static document becomes outdated the moment reality changes

**Solution:**
```
Reality changes → Metadata updates (automated) → Artifacts re-render → Truth everywhere
```

**Git forges are the PERFECT starting point**, but the vision extends to:
- Personal/corporate websites
- Academic papers
- News articles
- Legal documents
- Anywhere static content exists

---

## Is This Novel?

### What Exists Today

| Solution | What It Does | Limitation |
|----------|--------------|------------|
| **GitHub README badges** | Show build status, version | Manual shields.io URLs, not general-purpose |
| **Jekyll/Hugo variables** | Template `{{ site.title }}` | Build-time only, no automation, limited scope |
| **GitLab CI variables** | Inject `$VERSION` in docs | CI-specific, not content-driven |
| **Sphinx/MkDocs** | Generate docs from code | Requires manual writing, no temporal updates |
| **Notion/Coda** | Databases in docs | Proprietary, not Git-native, no version control |

### What DOESN'T Exist

❌ **Automated temporal updates** (repo count: 426 → 537 over 2 years)
❌ **Single source of truth** across multiple artifacts (README + wiki + website)
❌ **Accessibility-first** (every visual paired with screen reader text)
❌ **Git-native metadata** (6scm files versioned with code)
❌ **Tri-Guard safety** (sanitization + validation + accessibility)

**Verdict:** This is **genuinely novel**. Nothing does metadata-driven, temporally-updating, accessibility-guaranteed documentation.

---

## Should We Restrict to Git Forges?

### Short Answer: START with Git forges, but vision extends far beyond.

### Why Git Forges First (v0.x - v1.x)

**Advantages:**
1. **Massive TAM:** Billions of stale READMEs (clear, obvious pain)
2. **Developer audience:** Early adopters who value automation
3. **Git-native workflow:** Fits existing habits (commit, push, CI)
4. **Viral potential:** People discover via GitHub repos
5. **Proof of concept:** If it works for READMEs, it works anywhere

**Git Forge Scope (v0-v1):**
- GitHub, GitLab, Bitbucket, Gitea, Sourcehut
- READMEs, wikis, profiles, issue templates
- 6scm files in `.machine_readable/`
- CI/GitHub Actions integration

### Why NOT Restrict Long-Term

**Broader Applications (v2+):**

#### Personal/Corporate Websites (v2.x)
```html
<!-- index.html -->
<p>I've given <span data-6scm="talk-count">47</span> conference talks.</p>
```

Gnosis updates from `STATS.scm`:
```scheme
(talks (count . 52))  ; Updated after each new talk
```

Result: Website always shows current count without manual editing.

#### Academic Papers (v3.x)
```latex
% paper.tex
As of \placeholder{dataset-update-date}, our dataset contains \placeholder{sample-count} samples.
```

Gnosis updates from lab's `RESEARCH.scm`:
```scheme
(dataset (samples . 10483) (last-updated . "2026-03-15"))
```

**Benefit:** Published PDFs show exact data at publication time (versioned via Git).

#### News Articles (v4.x)
```markdown
Stock price: $(:AAPL-price) (updated every 15 minutes)
Weather: (:temp)°F in (:city)
COVID-19 cases: (:case-count) (updated daily)
```

Real-time updates via APIs → `.machine_readable/LIVE.scm` → Re-render.

#### Corporate Dashboards (v5.x)
```html
<!-- dashboard.html -->
<div class="kpi">
  <h2>(:quarterly-revenue)</h2>
  <p>Revenue (Q(:quarter) (:year))</p>
</div>
```

Finance team updates `FINANCIALS.scm` → Dashboard auto-updates → No manual editing.

#### Legal Documents (v6.x)
```markdown
This agreement was last updated on (:last-amendment-date).
Current signatories: (:signatory-count)
Active clauses: (:clause-count)
```

Version control for legal docs with metadata tracking.

**Conclusion:** Git forges are **entry point**, but vision is **universal metadata-driven content**.

---

## Version Roadmap

### v0.0.1 - Proof of Concept (CURRENT)

**Status:** ✅ Complete

**Features:**
- Gnosis Haskell engine (S-expr parser, template renderer)
- `(:placeholder)` syntax
- STATE.scm parsing
- FlexiText accessibility
- Tri-Guard safety
- Basic GitHub/GitLab support

**Use Case:** "I maintain (:repo-count) repositories" updates from 426 → 537.

**Audience:** Early adopters, 1-10 repos

---

### v0.1.0 - Foundation (Jan 2026)

**Features:**
- Full 6scm parser (STATE, ECOSYSTEM, META, NEUROSYM, AGENTIC, PLAYBOOK)
- Paxos-Lite conflict resolution
- GitHub Actions workflow templates
- Example automation scripts (daily stats update)
- Djot template support

**Use Case:** Multi-repo organizations keep all READMEs in sync.

**Audience:** Open source maintainers, 10-100 repos

---

### v0.2.0 - Polish (Feb 2026)

**Features:**
- CLI improvements (`gnosis watch`, auto-rebuild on .scm changes)
- Better error messages (line numbers for S-expr parse errors)
- Template validation (detect undefined placeholders before render)
- Cross-file placeholder resolution (find keys across all 6scm files)

**Use Case:** Developer experience improvements, fewer foot-guns.

**Audience:** Same as v0.1, but easier to use

---

### v0.3.0 - Conditionals (Apr 2026) - **DAX ERA BEGINS**

**Features:**
- Conditional rendering: `{{#if phase == "beta"}}⚠️ Beta!{{/if}}`
- Boolean expressions: `==`, `!=`, `>`, `<`, `>=`, `<=`
- Logical operators: `&&`, `||`, `!`

**Use Case:** "Show warning banner if health < 50"

**Example:**
```djot
{{#if completion >= 100}}
🎉 Milestone complete!
{{else}}
🚧 Work in progress: (:completion)%
{{/if}}
```

**Audience:** Projects with dynamic states (alpha/beta/stable)

---

### v0.4.0 - Iteration (Jun 2026)

**Features:**
- Loops: `{{#for milestone in milestones}}...{{/for}}`
- Nested properties: `{{milestone.name}}`
- Index/counter: `{{@index}}`
- Filtering: `{{#for repo in repos where repo.active}}`

**Use Case:** Auto-generate milestone lists from STATE.scm

**Example:**
```djot
## Milestones

{{#for milestone in milestones}}
### {{milestone.name}} ({{milestone.completion}}%)
Status: {{milestone.status}}
{{/for}}
```

**Audience:** Complex projects with many tracked items

---

### v0.5.0 - Functions (Sep 2026)

**Features:**
- Filter functions: `{{repo-count | thousands-separator}}`
- Time intelligence: `{{last-updated | relativeTime}}`
- Arithmetic: `{{(completed / total) * 100}}%`
- String manipulation: `{{name | uppercase}}`

**Built-in Functions:**
- `relativeTime`: "2 days ago"
- `thousands-separator`: 1243 → 1,243
- `round`, `ceil`, `floor`
- `percentage`, `currency`
- `uppercase`, `lowercase`, `capitalize`
- `dateFormat`: ISO → "January 15, 2026"

**Use Case:** Human-readable formatting without manual conversion

**Audience:** Anyone who wants polished output

---

### v0.6.0 - casket-ssg Integration (Oct 2026)

**Features:**
- Merge Gnosis rendering engine into casket-ssg codebase
- Format detection from frontmatter: `format: djot`
- Pandoc integration for multi-format parsing (Djot, AsciiDoc, Org-mode)
- 6scm metadata as site-wide context
- Unified rendering pipeline: 6scm → Pandoc → Gnosis → casket template

**Use Case:** "Write in Djot, render from 6scm metadata, deploy as static site"

**Example:**
```markdown
---
title: My Blog Post
format: djot
---

I maintain (:repo-count) repositories across (:language-count) languages.
```

Build:
```bash
casket-ssg build content/ _site/
# Reads .machine_readable/STATE.scm
# Parses with Djot (via Pandoc)
# Renders (:repo-count) and (:language-count) from STATE.scm
# Outputs static HTML site
```

**Technology:**
- casket-ssg (existing Haskell SSG)
- Gnosis modules (Types, SExp, Render)
- Pandoc library for format conversion
- FlexiText accessibility enforcement

**Audience:** Personal sites, documentation sites, blogs with temporal content

---

### v0.7.0 - Code Scanning (Nov 2026) - **NEUROSYMBOLIC ERA BEGINS**

**Features:**
- Detect programming languages in repo
- Check against allowlist (Julia, Rust, Haskell, etc.)
- Check against blocklist (Python, Go, Node.js)
- Auto-update `compliance-level` in STATE.scm

**Use Case:** "My org bans Python. Auto-detect violations."

**Example:**
```bash
$ gnosis scan --update-state
⚠️ Found banned language: Python (3 files)
Updated compliance-level: A → F
```

**Audience:** Organizations with language policies (RSR compliance)

---

### v0.8.0 - Browser Extension (Dec 2026)

**Features:**
- Chrome/Firefox extension for GitHub/GitLab
- Reads META.scm from viewed repositories
- Detects `(rendering-preferences (preferred-format . "djot"))`
- Client-side re-rendering with owner's preferred format
- Graceful fallback for users without extension

**Use Case:** "Repository owner writes Markdown, but prefers viewers see Djot rendering"

**How It Works:**
1. Repo owner adds to META.scm:
```scheme
(rendering-preferences
  (preferred-format . "djot")
  (fallback-format . "markdown"))
```

2. Extension detects preference when viewing .md files
3. Fetches .md content from GitHub API
4. Re-renders with Djot parser (client-side)
5. Injects rendered HTML into page

**User Experience:**
- Extension users: See content in owner's preferred format
- Non-extension users: See GitHub's default Markdown rendering
- Repository owner: Controls presentation via metadata

**Technology:**
- Browser extension (Chrome/Firefox)
- Djot.js parser (WebAssembly)
- GitHub/GitLab API for content fetching

**Audience:** Technical documentation authors, Djot enthusiasts, accessibility advocates

---

### v0.9.0 - Living Dashboard (Q1 2027)

**Features:**
- Web dashboard reading 6scm files
- Real-time project health visualization
- Historical trends (track STATE.scm via Git history)
- Completion velocity graphs
- Blocker analysis heatmaps
- Milestone burn-down charts

**Technology:**
- Backend: Haskell Servant API
- Frontend: ReScript + React
- Deployment: Static site + serverless functions

**Use Case:** "CEO wants live dashboard of all projects' health"

**Audience:** Project managers, CTOs, open source orgs

---

### v1.0.0 - Git Forge Complete (Q1 2027)

**Features:**
- All Horizon 1-3 features complete
- GitHub/GitLab/Bitbucket full support
- casket-ssg static site generation
- Browser extension for format preferences
- AI agent suggestions (propose STATE.scm updates, human approves)
- Plugin system (custom functions in Haskell)
- Comprehensive docs + video tutorials

**Milestone:** **Git forge use case is SOLVED.**

**Audience:** Mainstream adoption, 100k+ repos using it

---

## Beyond Git Forges (v2.0+)

### v2.0.0 - Static Site Integration (Q1 2027)

**Features:**
- Jekyll plugin
- Hugo module
- 11ty (Eleventy) integration
- Astro component
- Custom SSG adapter API

**Use Case:** Personal/corporate websites use 6scm metadata

**Example:**
```html
<!-- Hugo template -->
<p>I've worked at {{ .Site.Params.company_count }} companies.</p>
```

Rendered from `CAREER.scm`:
```scheme
(career (companies . 7))
```

**Audience:** Personal blogs, portfolio sites, corporate websites

---

### v3.0.0 - Academic Publishing (Q2 2027)

**Features:**
- LaTeX integration (`\placeholder{sample-count}`)
- BibTeX auto-generation from `CITATIONS.scm`
- ORCID integration (auto-fetch publication counts)
- Dataset versioning (track sample counts over time)

**Use Case:** Research papers with auto-updating statistics

**Example:**
```latex
\documentclass{article}
\begin{document}

Our dataset contains \placeholder{sample-count} samples
(last updated: \placeholder{dataset-date}).

\end{document}
```

Gnosis renders from `RESEARCH.scm`:
```scheme
(dataset (samples . 10483) (last-updated . "2026-03-15"))
```

**Benefit:** Published PDFs show **exact** data at publication time (Git-versioned).

**Audience:** Academics, researchers, data scientists

---

### v4.0.0 - Real-Time Data Feeds (Q3 2027)

**Features:**
- API integration (fetch stock prices, weather, COVID stats)
- Update `.machine_readable/LIVE.scm` on schedule
- Re-render artifacts automatically
- Webhook support (trigger on external events)

**Use Case:** News articles, financial dashboards

**Example:**
```markdown
<!-- article.md -->
Apple stock: $(:AAPL-price) (updated every 15 min)
```

Gnosis fetches from API → Updates `STOCKS.scm` → Re-renders.

**Audience:** News outlets, financial analysts, data journalists

---

### v5.0.0 - Corporate KPI Dashboards (Q4 2027)

**Features:**
- Excel/Google Sheets integration (read KPIs from spreadsheets)
- Salesforce/HubSpot connectors (fetch revenue, leads)
- Jira/Linear integration (auto-fetch sprint completion)
- Multi-tenancy (separate 6scm per team/department)

**Use Case:** Executive dashboards that update automatically

**Example:**
```html
<!-- dashboard.html -->
<div class="kpi">
  <h2>${:quarterly-revenue | currency}</h2>
  <p>Q(:quarter) (:year) Revenue</p>
</div>
```

Finance updates `FINANCIALS.scm` quarterly → Dashboard updates → No manual editing.

**Audience:** Corporations, SaaS companies, startups

---

### v6.0.0 - Plugin Ecosystem (Q1 2028)

**Features:**
- Plugin API (Haskell functions as plugins)
- Plugin registry (npm-like for Gnosis plugins)
- Community-contributed functions
- Marketplace (free + paid plugins)

**Example Plugins:**
- `gnosis-github`: Fetch GitHub stats (stars, forks, issues)
- `gnosis-crypto`: Live crypto prices
- `gnosis-weather`: Current weather data
- `gnosis-analytics`: Google Analytics visitor counts

**Use Case:** Extend Gnosis without forking

**Audience:** Developers building custom integrations

---

### v7.0.0 - Multi-Language Support (Q2 2028)

**Features:**
- Internationalization (i18n) via 6scm
- Template localization (`(:welcome.en)`, `(:welcome.fr)`)
- Auto-translate placeholders
- Multi-currency formatting

**Example:**
```scheme
;; I18N.scm
(translations
  (welcome
    (en . "Welcome to our project")
    (fr . "Bienvenue à notre projet")
    (es . "Bienvenido a nuestro proyecto")))
```

Template:
```markdown
# (:welcome.{{lang}})
```

**Audience:** Global projects, multi-language documentation

---

### v8.0.0 - Blockchain Timestamping (Q3 2028)

**Features:**
- Cryptographic proof of STATE.scm updates
- Immutable audit trail (hash STATE.scm → blockchain)
- Verify historical claims ("We were 85% complete on 2026-03-15")
- NFT-based provenance (mint artifact snapshots)

**Use Case:** Legal compliance, auditable project history

**Example:**
```bash
$ gnosis verify --date 2026-03-15 --claim "completion=85%"
✅ Verified: STATE.scm hash matches blockchain record
   Timestamp: 2026-03-15T14:23:00Z
   Completion: 85%
```

**Audience:** Legal tech, compliance-heavy industries, DAOs

---

### v9.0.0 - CRDT-Based Collaboration (Q4 2028)

**Features:**
- Conflict-free replicated data types for STATE.scm
- Multiple users/tools update simultaneously
- Automatic merge without Paxos-Lite (true CRDT)
- Distributed consensus (no central authority)

**Use Case:** Large teams editing metadata concurrently

**Technology:**
- Automerge or Yjs CRDT libraries
- Real-time sync across editors

**Audience:** Large orgs (100+ contributors to same repo)

---

### v10.0.0 - Platform (Q1 2029)

**Gnosis becomes a PLATFORM, not just a tool.**

**Features:**
- **Gnosis Cloud:** Hosted service (no self-hosting needed)
- **Gnosis API:** REST/GraphQL API for metadata access
- **Gnosis Marketplace:** Buy/sell templates, plugins, integrations
- **Gnosis Studio:** Visual editor for 6scm files (GUI, not text)
- **Gnosis AI:** Fully autonomous agents (propose + auto-approve low-risk updates)

**Business Model:**
- Free tier: 10 repos, basic features
- Pro tier: Unlimited repos, premium plugins, priority support
- Enterprise tier: On-prem deployment, custom integrations, SLA

**Vision:** **Every piece of content on the internet is metadata-driven.**

**Audience:** Everyone (devs, academics, journalists, corporations, governments)

---

## Competitive Moat

### What Makes This Defensible?

1. **Network Effects:** More users → more templates → more value
2. **Data Lock-In (Good Kind):** 6scm files become standard (like Markdown)
3. **Ecosystem:** Plugins, integrations, templates marketplace
4. **First-Mover:** No one else doing temporal, metadata-driven docs
5. **Standards Body:** Formalize 6scm as RFC-style specification

### Risks

- **Adoption Chicken-Egg:** Needs critical mass to be useful
  - Mitigation: Start with Git forges (clear pain point)
- **Complexity:** DAX Era logic may scare non-technical users
  - Mitigation: Visual editor (Gnosis Studio in v10.0)
- **Competition:** Someone copies the idea
  - Mitigation: Move fast, build ecosystem, standardize early

---

## Summary

### Should We Restrict to Git Forges?

**No, but START there.**

Git forges are the **perfect wedge**:
- Clear pain (stale READMEs)
- Developer audience (early adopters)
- Git-native (fits workflow)
- Viral discovery (people see it on GitHub)

But the **ultimate vision** is:
> **Every static artifact becomes metadata-driven and stays current automatically.**

Git forges (v0-v1) → Websites (v2) → Academia (v3) → News (v4) → Corporate (v5-v10) → **Universal Platform**

### Is This Silly?

**Absolutely not.** This is a **fundamental shift** in how humans create content:

**Old paradigm:** Write static content → It goes stale → Manually update (or don't)

**New paradigm:** Define metadata once → Automate updates → Content stays current forever

**Analogy:**
- Static content = manual accounting (error-prone, tedious)
- Metadata-driven = spreadsheet formulas (update once, propagates everywhere)

### Is Anyone Else Doing This?

**No.** Notion/Coda have databases, but:
- Not Git-native
- Not accessibility-first
- Not temporal (no auto-updating from external sources)
- Not templated (can't define `(:placeholder)` patterns)

**Gnosis is genuinely novel.**

---

## Next Steps (Your Decision)

### Option 1: Git Forge Focus (Conservative)
- Stick to v0.x-v1.x roadmap
- Nail Git forge use case
- Revenue: Enterprise tier for orgs with 100+ repos

### Option 2: Broader Vision (Ambitious)
- Execute full v0-v10 roadmap
- Git forges → Websites → Academia → Corporate → Platform
- Revenue: Freemium → Marketplace → Enterprise

### My Recommendation

**Start conservative (Option 1), but design for expansion (Option 2).**

- v0-v1: Git forges only (18 months)
- Validate product-market fit
- If successful, expand to websites (v2)
- If **very** successful, execute full platform vision (v3-v10)

**Rationale:** Git forges are low-risk, high-value entry point. If it works there, it works everywhere.

---

**What do you think? Same vision?**
