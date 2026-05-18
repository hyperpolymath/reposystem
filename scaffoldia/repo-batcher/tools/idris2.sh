#!/bin/sh
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Reproducible idris2 0.8.0 invoker for repo-batcher Layer-6 ABI checks.
#
# The estate idris2 0.8.0 is a RELOCATED Chez install: its bin/idris2
# wrapper sets the runtime library paths but the package prefix baked
# into idris2.so points at the original (non-existent) build location,
# so a bare `idris2 --check` fails with "Module Prelude not found".
# Idris2's documented override for a relocated install is IDRIS2_PREFIX
# (it then resolves $PREFIX/idris2-<ver>/{prelude,base,...}-<ver>).
# This script supplies ONLY that relocation prefix and execs the
# project's pinned idris2 — it uses the binary's own bundled stdlib,
# it does NOT hand-locate or stage any .ttc.
set -e
IDRIS2_HOME=/home/hyperpolymath/dev/tools/provers/idris2/0.8.0
export IDRIS2_PREFIX="$IDRIS2_HOME"
exec "$IDRIS2_HOME/bin/idris2" "$@"
