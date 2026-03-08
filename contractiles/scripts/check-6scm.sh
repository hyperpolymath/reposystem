#!/usr/bin/env bash
set -euo pipefail

missing=0
for f in AGENTIC.scm ECOSYSTEM.scm META.scm NEUROSYM.scm PLAYBOOK.scm STATE.scm; do
  src=".machine_readable/$f"
  dst=".machine_readable/6scm/$f"
  if [ ! -f "$src" ]; then
    continue
  fi
  if [ ! -f "$dst" ]; then
    echo "Missing mirror: $dst" >&2
    missing=1
    continue
  fi
  if ! diff -u "$src" "$dst" >/dev/null; then
    echo "Out of sync: $src -> $dst" >&2
    missing=1
  fi
done

exit $missing
