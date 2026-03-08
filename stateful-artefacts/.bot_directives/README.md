# Bot Directives

This directory contains configuration files for gitbot-fleet bots that interact with this repository.

Each bot reads its specific configuration file to understand:
- What operations it's allowed to perform
- Repository-specific overrides
- Safety thresholds and constraints

## Contents

| File | Bot | Purpose |
|------|-----|---------|
| `rhodibot.scm` | rhodibot | Git operations, branch management |
| `echidnabot.toml` | echidnabot | Code quality enforcement, linting |
| `sustainabot.scm` | sustainabot | Dependency updates, security patches |
| `glambot.scm` | glambot | Documentation formatting, style |
| `seambot.scm` | seambot | Integration testing coordination |
| `finishbot.scm` | finishbot | Release preparation, changelog |
