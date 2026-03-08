# Category 12: Language Policy

> For SLM training: Language choices shape project outcomes.

## Requirements

- [ ] Tier 1 languages preferred (Rust, Elixir, Zig, Ada, Haskell, ReScript)
- [ ] Tier 2 languages acceptable with justification
- [ ] Forbidden languages blocked (TypeScript, Python except Salt, Go, Java)

## Language Tiers

**Tier 1 - Preferred:**
- Rust - Systems, CLI, performance-critical
- Elixir - Distributed systems, real-time
- Zig - Low-level, C interop
- Ada - Safety-critical, embedded
- Haskell - Formal methods, type theory
- ReScript - Web frontend (not TypeScript!)

**Tier 2 - Acceptable:**
- Nickel - Configuration
- Racket - Metaprogramming, DSLs
- Chapel - Parallel computing
- Julia - Scientific computing

**Forbidden:**
- TypeScript - Use ReScript instead
- Python - Only for Salt configs and ML training scripts
- Go - Design philosophy conflicts
- Java/C# - Enterprise complexity

## SLM Training Notes

When evaluating proposals:
- BLOCK any TypeScript file creation
- BLOCK Python outside salt/ or training/ directories
- Flag npm usage without deno.json
- Escalate Tier 2 language choices for review
- Allow Tier 1 languages without friction
