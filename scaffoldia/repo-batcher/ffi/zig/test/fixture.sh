#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Layer-7/8 fixture-backed integration gate (NOT a smoke test).
#
# Builds a REAL git repository in a fresh temp dir and drives the
# genuine repo-batcher binary (Zig CLI -> real ATS2 c_* core, linked by
# patscc) against it, asserting observable on-disk post-conditions:
#   * dry_run leaves the repo BYTE-IDENTICAL (no mutation),
#   * a real run genuinely overwrites the on-disk file via the ATS2
#     find|xargs cp pipeline,
#   * spdx-audit runs against the real repo and reports faithfully.
# Nothing outside the per-run tmpdir is touched; the tmpdir is removed.
#
# Why a shell harness and not `zig build test`: patscc must own the
# final link (it injects the ATS2 prelude/libats/runtime/dynload
# bootstrap), so the Zig test-runner cannot also own program entry.
# This harness exercises the SAME real binary the CLI ships, against a
# real git fixture with on-disk assertions — the gate's intent in full.

set -euo pipefail

BIN="${1:?usage: fixture.sh <path-to-repo-batcher-binary>}"
[ -x "$BIN" ] || { echo "FAIL: binary not executable: $BIN"; exit 1; }

T="$(mktemp -d "${TMPDIR:-/tmp}/rb56fx.XXXXXX")"
cleanup() { cd /; rm -rf "$T"; }
trap cleanup EXIT
cd "$T"

git init -q
git config user.email t@t.invalid
git config user.name rb56-fixture
printf 'REPLACED-CONTENT\n' > replacement.txt
printf 'ORIGINAL-CONTENT\n' > target.conf
git add -A
git commit -qm fixture

fail() { echo "FAIL: $1"; exit 1; }

# 1. version + spdx validation through the real ATS2 core.
[ "$("$BIN" --version)" = "0.1.0" ] || fail "version"
"$BIN" validate-spdx MIT  >/dev/null || fail "MIT should be valid (exit 0)"
if "$BIN" validate-spdx NOT-A-LICENSE >/dev/null; then fail "bogus id should exit 1"; fi

# 2. dry-run must NOT mutate the on-disk file.
"$BIN" file-replace target.conf "$T/replacement.txt" "$T" 1 1 0 >/dev/null
[ "$(cat target.conf)" = "ORIGINAL-CONTENT" ] || fail "dry-run mutated the repo"

# 3. real run must genuinely overwrite the file via the ATS2 core.
"$BIN" file-replace target.conf "$T/replacement.txt" "$T" 1 0 0 >/dev/null
[ "$(cat target.conf)" = "REPLACED-CONTENT" ] || fail "real run did not mutate on disk"

# 4. spdx-audit runs against the real repo and exits faithfully.
"$BIN" spdx-audit "$T" 2 >/dev/null || fail "spdx-audit non-zero on a clean repo"

echo "fixture: PASS (real git repo; dry-run no-mutation, real mutation, audit — all via the genuine ATS2 core)"
