# CLAUDE.md - Stateful Artefacts for Git Forges

## Project Overview

Gnosis: metadata-driven documentation that updates automatically. Reads 6scm files (STATE.scm, ECOSYSTEM.scm, META.scm, etc.) and renders dynamic templates with `(:placeholder)` syntax. Haskell-based template engine.

## Architecture

```
.machine_readable/STATE.scm    ← Source of truth (updated by automation)
        ↓
Gnosis template engine          ← Haskell, reads 6scm, renders templates
        ↓
README.md, PROFILE.md, etc.    ← Rendered outputs (never manually edited)
```

## Build & Run

```bash
cd gnosis
stack build        # or: cabal build
stack install      # Install gnosis binary
gnosis README.template.md README.md   # Render a template
```

## Key Features

- `(:placeholder)` syntax resolves from any 6scm file
- FlexiText accessibility (every visual element has alt-text)
- Tri-Guard safety (sanitization, validation, accessibility)
- Shields.io badge rendering mode
- Djot markup support (renders to Markdown for forge compatibility)

## Planned Feature: Hypothesis-Style Annotation Layer (Sonnet Task)

### Idea (2026-02-08)

Add a Hypothesis/Basilisk-style annotation layer so users can leave post-it notes and layered conversations on rendered documentation. Even if only the author or contributors can see them.

### What Hypothesis Does

[Hypothesis](https://web.hypothes.is/) overlays annotations on any web page:
- Highlight text, leave comments
- Threaded conversations per annotation
- Public, private, or group-scoped visibility
- Works via browser extension or embedded JS

### Integration Plan

1. **Embed Hypothesis JS** in rendered HTML outputs (not Markdown - needs HTML wrapper)
   - Add `<script src="https://hypothes.is/embed.js" async></script>` to HTML template
   - Gnosis renders `.template.html` → `.html` with Hypothesis embedded

2. **Scoped visibility options**:
   - `--annotations public` — anyone can annotate
   - `--annotations contributors` — only repo contributors (via Hypothesis groups)
   - `--annotations private` — only the author

3. **Git-backed annotation storage** (alternative to Hypothesis cloud):
   - Store annotations as JSON in `.annotations/` directory
   - Each annotation: file, line range, author, timestamp, text, thread
   - Render as overlay in HTML output
   - Git history tracks annotation changes over time

4. **Use cases**:
   - Leave "post-it" reminders on documentation sections
   - Threaded design discussions anchored to specific text
   - Code review comments that persist across sessions
   - Contributor onboarding notes ("here's why this is like this")

### Implementation Options

| Approach | Pros | Cons |
|----------|------|------|
| **Hypothesis embed** | Ready-made, established | Requires network, external service |
| **Git-backed JSON** | Self-hosted, works offline | Need to build overlay UI |
| **Both** | Best of both worlds | More code to maintain |

### Recommendation

Start with Hypothesis embed (minimal effort, proven UX), then add git-backed storage as a fallback for offline/self-hosted use.

## Roadmap Status

- **Horizon 1** (50%): Tri-Guard, FlexiText, S-expression parser, template renderer
- **Horizon 2** (0%): Conditional rendering, loops, functions, arithmetic
- **Horizon 3** (0%): Code scanning, neurosymbolic bridge, AI agent suggestions, annotation layer

## Code Style

- SPDX headers: `PMPL-1.0-or-later` (MPL-2.0 as fallback for platform requirements only)
- Author: Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>
- Haskell for Gnosis engine
- 6scm files in Guile Scheme
