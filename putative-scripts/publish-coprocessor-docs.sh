#!/usr/bin/env bash
set -Eeuo pipefail

# Publish the coprocessor/BerryWiki documentation commits from the developer
# estate.  This script is deliberately conservative: it never force-pushes,
# never resets, and stops when a rebase needs human conflict resolution.

DEV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$DEV_ROOT/llm-coding-configs/github"
SSH_CONFIG="$CONFIG_DIR/ssh-config"
FIX_SYSTEM_SSH=0
DRY_RUN=0
IDENTITY_FILE=""

repos=(
  "meta-repos/enaction-engine"
  "hyper-repos/_JULIA_LIBRARIES _SET/Axiom.jl"
  "hyper-repos/_JULIA_LIBRARIES _SET/AcceleratorGate.jl"
  "hyper-repos/_JULIA_LIBRARIES _SET/ZeroProb.jl"
)

# Print usage help.
usage() {
  cat <<'EOF'
Usage: scripts/publish-coprocessor-docs.sh [options]

Fetch, rebase, and push the current local history for the four coprocessor
repositories. The script does not force-push or discard work.

Options:
  --dry-run          Diagnose and fetch only; do not rebase or push.
  --fix-system-ssh  Repair the system OpenSSH config with sudo, if needed.
  --help             Show this help.
EOF
}

# Run a command, or only print it when in dry-run mode.
run() {
  if (( DRY_RUN )); then
    printf '+ %q' "$1"; shift; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

while (($#)); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --fix-system-ssh) FIX_SYSTEM_SSH=1 ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

if (( FIX_SYSTEM_SSH )); then
  if [[ "$(id -u)" -eq 0 ]]; then
    chown root:root /usr/lib/systemd/ssh_config.d/20-systemd-ssh-proxy.conf
    chmod 0644 /usr/lib/systemd/ssh_config.d/20-systemd-ssh-proxy.conf
    chown root:root /etc/ssh /etc/ssh/ssh_config /etc/ssh/ssh_config.d
    chmod 0755 /etc/ssh /etc/ssh/ssh_config.d
    chmod 0644 /etc/ssh/ssh_config
  else
    sudo chown root:root /usr/lib/systemd/ssh_config.d/20-systemd-ssh-proxy.conf
    sudo chmod 0644 /usr/lib/systemd/ssh_config.d/20-systemd-ssh-proxy.conf
    sudo chown root:root /etc/ssh /etc/ssh/ssh_config /etc/ssh/ssh_config.d
    sudo chmod 0755 /etc/ssh /etc/ssh/ssh_config.d
    sudo chmod 0644 /etc/ssh/ssh_config
  fi
fi

if ! getent hosts github.com >/dev/null 2>&1; then
  printf 'Cannot resolve github.com. Fix host/WSL DNS or network, then rerun.\n' >&2
  exit 10
fi

# Preserve the system SSH configuration and its agent when it parses. This is
# the path that authenticated the earlier GitHub attempts. Only use the
# project-local config when the system config is malformed or inaccessible.
if ssh -G github.com >/dev/null 2>&1; then
  unset GIT_SSH_COMMAND
else
  for candidate in \
    "$HOME/.ssh/id_ed25519" \
    "$HOME/.ssh/id_ecdsa" \
    "$HOME/.ssh/id_rsa" \
    "$HOME/.ssh/id_ed25519_sk"; do
    if [[ -f "$candidate" ]]; then
      IDENTITY_FILE="$candidate"
      break
    fi
  done
  if [[ -z "$IDENTITY_FILE" ]] && ! ssh-add -L >/dev/null 2>&1; then
    printf 'System SSH config is unusable and no fallback SSH identity was found.\n' >&2
    printf 'Repair system SSH or register a key under ~/.ssh.\n' >&2
    exit 13
  fi
  umask 077
  {
    printf '%s\n' 'Host github.com' '    HostName github.com' '    User git'
    if [[ -n "$IDENTITY_FILE" ]]; then
      printf '    IdentityFile %s\n    IdentitiesOnly yes\n' "$IDENTITY_FILE"
    fi
    printf '%s\n' '    StrictHostKeyChecking accept-new'
  } > "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
  export GIT_SSH_COMMAND="ssh -F $SSH_CONFIG"
fi

for rel in "${repos[@]}"; do
  repo="$DEV_ROOT/$rel"
  printf '\n==> %s\n' "$rel"
  [[ -d "$repo/.git" ]] || { printf 'Missing git checkout: %s\n' "$repo" >&2; exit 11; }

  branch="$(git -C "$repo" symbolic-ref --short HEAD)"
  [[ "$branch" == main ]] || { printf 'Expected main, found %s in %s\n' "$branch" "$rel" >&2; exit 12; }

  if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
    if (( DRY_RUN )); then
      printf 'Working tree is dirty (would stash with -u).\n'
    else
      stamp="coprocessor-publish-$(date -u +%Y%m%dT%H%M%SZ)"
      git -C "$repo" stash push -u -m "$stamp"
      printf 'Unrelated local work stashed as: %s\n' "$stamp"
    fi
  fi

  run git -C "$repo" fetch origin main
  printf 'Divergence (local-only remote-only): '
  git -C "$repo" rev-list --left-right --count HEAD...origin/main

  if (( DRY_RUN )); then
    continue
  fi

  git -C "$repo" rebase origin/main
  git -C "$repo" push origin main
done

printf '\nAll four documentation histories were fetched, rebased, and pushed.\n'
