#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# check-root-shape.sh — enforce the canonical root shape, in BOTH directions,
# against the repository root allowlist, under EITHER canonical spelling:
#   .machine_readable/root-allow.txt  (dotted, the estate majority)
#   machine-readable/root-allow.txt   (hyphenated, what this template emits)
#
#   * an entry at root that is not listed          -> drift (extra)
#   * a listed entry WITHOUT '?' that is missing   -> drift (missing)
#
# The second direction was absent until 2026-08, and its absence is why the
# allowlist rotted: it accumulated 19 permissions for files the April root
# cleanup had already moved into docs/, and nothing could ever notice. A
# one-directional allowlist only ratchets open, so over time it licenses
# exactly the drift it was written to prevent.
#
# '?' marks an entry that is legitimately absent in some conforming repo —
# template-only material removed at mint, or a capability-gated module.
#
# Companion to scripts/validate-template.sh: that script enforces required
# files; this one enforces the shape as a whole.
#
# Exit codes:
#   0 — root matches allowlist
#   1 — drift (extras at root, or required entries missing)
#   2 — usage / setup error

set -euo pipefail

REPO_ROOT="${1:-.}"
REPO_ROOT_DOTTED="${REPO_ROOT}/.machine_readable/root-allow.txt"
REPO_ROOT_HYPHEN="${REPO_ROOT}/machine-readable/root-allow.txt"

# Both spellings are estate contract. Resolve whichever exists; if BOTH exist
# that is itself drift (two sources of truth) and is refused.
if [ -f "$REPO_ROOT_DOTTED" ] && [ -f "$REPO_ROOT_HYPHEN" ]; then
    echo "ERROR: both .machine_readable/ and machine-readable/ carry a root-allow.txt;" >&2
    echo "       pick one spelling — two allowlists cannot both be canonical." >&2
    exit 2
elif [ -f "$REPO_ROOT_DOTTED" ]; then
    ALLOW_FILE="$REPO_ROOT_DOTTED"
elif [ -f "$REPO_ROOT_HYPHEN" ]; then
    ALLOW_FILE="$REPO_ROOT_HYPHEN"
else
    echo "ERROR: allowlist not found at either $REPO_ROOT_DOTTED or $REPO_ROOT_HYPHEN" >&2
    exit 2
fi

# Build the allow set: strip comments, trailing slashes, and blank lines.
# A leading '?' marks the entry optional; it is not part of the name.
mapfile -t ALLOW_RAW < <(
    sed -E 's/[[:space:]]*#.*$//' "$ALLOW_FILE" \
        | sed -E 's|/$||' \
        | awk 'NF' \
        | sed -E 's/[[:space:]]+$//'
)

declare -A ALLOW_SET=()
REQUIRED=()
ALLOW=()
for raw in "${ALLOW_RAW[@]}"; do
    if [[ "$raw" == '?'* ]]; then
        entry="${raw#\?}"
    else
        entry="$raw"
        REQUIRED+=("$entry")
    fi
    ALLOW_SET["$entry"]=1
    ALLOW+=("$entry")
done

# Enumerate everything at the repository root, EXCLUDING git-ignored entries.
#
# This was a bare `find`, which contradicted the contract root-allow.txt states
# ("Anything tracked at root that is not in this list is drift"): a plain
# filesystem scan also sees build output. Any repo with a root-level build
# directory -- `target/` for Cargo, `node_modules/`, `_build/` for Mix --
# therefore failed this gate the moment someone built before running it, and
# the tempting "fix" was to allowlist an artifact directory that must never be
# committed.
#
# Filtering through `git check-ignore` makes the check mean what it says. The
# fallback keeps the script working outside a git worktree.
mapfile -t ACTUAL < <(
    cd "$REPO_ROOT" && \
    find . -mindepth 1 -maxdepth 1 \
        ! -name '.' \
        -printf '%f\n' \
    | { if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            git check-ignore --stdin --non-matching --verbose 2>/dev/null \
                | sed -n 's/^::[[:space:]]//p'
        else
            cat
        fi; } \
    | sort
)

declare -A ACTUAL_SET=()
for entry in "${ACTUAL[@]}"; do
    ACTUAL_SET["$entry"]=1
done

# Direction 1 — present at root but not permitted.
EXTRAS=()
for entry in "${ACTUAL[@]}"; do
    if [ -z "${ALLOW_SET[$entry]+x}" ]; then
        EXTRAS+=("$entry")
    fi
done

# Direction 2 — required by the allowlist but not present.
MISSING=()
for entry in "${REQUIRED[@]}"; do
    if [ -z "${ACTUAL_SET[$entry]+x}" ]; then
        MISSING+=("$entry")
    fi
done

if [ ${#EXTRAS[@]} -eq 0 ] && [ ${#MISSING[@]} -eq 0 ]; then
    OPTIONAL_COUNT=$(( ${#ALLOW[@]} - ${#REQUIRED[@]} ))
    echo "PASS: root matches allowlist (${#ACTUAL[@]} entries; ${#REQUIRED[@]} required, ${OPTIONAL_COUNT} optional)"
    exit 0
fi

if [ ${#EXTRAS[@]} -gt 0 ]; then
    echo "FAIL: ${#EXTRAS[@]} root entries are not on the allowlist:" >&2
    for e in "${EXTRAS[@]}"; do
        if [ -d "$REPO_ROOT/$e" ]; then
            echo "  - $e/  (directory)" >&2
        else
            echo "  - $e" >&2
        fi
    done
    echo "" >&2
    echo "Either move them into the appropriate subdirectory, or add a justified" >&2
    echo "entry to machine-readable/root-allow.txt." >&2
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "FAIL: ${#MISSING[@]} allowlist entries are required but absent:" >&2
    for e in "${MISSING[@]}"; do
        echo "  - $e" >&2
    done
    echo "" >&2
    echo "Either restore them, or - if they are legitimately absent in this repo -" >&2
    echo "mark the entry optional with a leading '?' in root-allow.txt and say why." >&2
    echo "Do not mark an entry optional merely to silence this." >&2
fi
exit 1
