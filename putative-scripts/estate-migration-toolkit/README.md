# Estate Migration Toolkit

Tooling for the hyperpolymath/metadatastician estate migration to the target architecture (Rust/GNATprove, Zig hexadeca, Idris2 ABI, Bun, SNIF).

## Quick Start

```bash
# 1. Scan your estate (produces estate-triage-report.csv)
./scripts/estate-scan.sh --github hyperpolymath metadatastician \
  --local ~/home/hyperpolymath/developer/hyper-repos ~/home/hyperpolymath/developer/meta-repos

# 2. Review the kill list in estate-triage-report.csv
#    Delete/archive KILL repos, then proceed

# 3. Roll out language-gate CI to all repos (dry-run first!)
./scripts/rollout-language-gate.sh hyperpolymath --dry-run
./scripts/rollout-language-gate.sh hyperpolymath

# 4. Deprecate poly-*-mcp repos (point to boj-server)
./scripts/deprecate-poly-mcps.sh hyperpolymath --dry-run
./scripts/deprecate-poly-mcps.sh hyperpolymath

# 5. Check proven repo bindings for bot damage
./scripts/check-proven-bindings.sh

# 6. Find NIF usage that needs SNIF migration
./scripts/find-nif-to-snif.sh ~/home/hyperpolymath/developer/hyper-repos
./scripts/find-nif-to-snif.sh --github hyperpolymath

# 7. Migrate Deno repos to Bun (per-repo)
./scripts/migrate-deno-to-bun.sh /path/to/deno-repo --dry-run
./scripts/migrate-deno-to-bun.sh /path/to/deno-repo
```

## Files

| File | Purpose |
|------|---------|
| `scripts/estate-scan.sh` | Phase 0: Scan and classify all repos |
| `scripts/rollout-language-gate.sh` | Phase 1: Bulk-add CI policy to all repos |
| `scripts/deprecate-poly-mcps.sh` | Deprecate poly-*-mcp repos → boj-server |
| `scripts/check-proven-bindings.sh` | Verify proven repo bindings weren't corrupted |
| `scripts/find-nif-to-snif.sh` | Find NIF usage for SNIF migration |
| `scripts/migrate-deno-to-bun.sh` | Convert Deno projects to Bun |
| `ci/language-gate.yml` | The shared CI workflow (deploy to .github repo) |
| `templates/.language-policy.toml` | Per-repo policy template (with examples) |
| `templates/language-gate-caller.yml` | One-liner workflow each repo uses |

## Requirements

- `gh` CLI (authenticated via `gh auth login`)
- `jq`, `git`, `bash`
- `bun` (for Deno→Bun migration)
- Python 3 with `toml` package (for CI workflow)
