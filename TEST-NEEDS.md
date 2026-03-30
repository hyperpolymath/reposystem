# TEST-NEEDS: reposystem

## Current State

| Category | Count | Details |
|----------|-------|---------|
| **Source modules** | 22 | Rust CLI (14 commands, config, graph, scanner, tui, lib, main), 1 Ada spec, 1 Idris2 ABI |
| **Unit tests** | 66 | 50 invariant tests, 4 CLI integration, 3 hello_yard, 9 inline (graph=4, scanner=5) |
| **Integration tests** | 4 | cli_integration.rs only |
| **E2E tests** | 0 | None |
| **Benchmarks** | 0 | Shell scripts in scaffoldia/ and stateful-artefacts/ but no Rust criterion/divan benchmarks |
| **ReScript GUI files** | 958 | Massive GUI surface with ZERO dedicated GUI tests |

## What's Missing

### P2P Tests
- [ ] No peer-to-peer or inter-component communication tests between Rust CLI and ReScript GUI

### E2E Tests (CRITICAL)
- [ ] No end-to-end tests at all. 22 source modules, 958 GUI files, 0 E2E
- [ ] No test that actually runs `reposystem` as a binary and validates output
- [ ] No GUI rendering/interaction tests

### Aspect Tests
- [ ] **Security**: No tests for config file parsing safety, path traversal, untrusted repo input
- [ ] **Performance**: No tests for graph traversal at scale (100+ repo scenarios)
- [ ] **Concurrency**: No tests for parallel scan operations
- [ ] **Error handling**: No tests for malformed configs, missing repos, network failures

### Build & Execution
- [ ] No compilation smoke test in CI for the Ada spec (`intervention.ads`)
- [ ] No build verification for the Idris2 ABI types

### Benchmarks Needed
- [ ] Graph traversal (scan 100/500/1000 repos)
- [ ] TUI render performance
- [ ] Config parsing throughput
- [ ] ReScript GUI render cycle benchmarks

### Self-Tests
- [ ] No self-diagnostic / `reposystem --self-test` mode
- [ ] No healthcheck for the TUI

## FLAGGED ISSUES
- **958 ReScript GUI files with 0 tests** -- this is not "untested", this is a testing void
- **benchmark-suite.sh** and **performance_test.sh** exist in scaffoldia but are shell scripts, not proper benchmarks
- **4 CLI integration tests for 14 command modules** = 0.28 tests per command

## Priority: P0 (CRITICAL)
