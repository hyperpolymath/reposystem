#!/usr/bin/env bash
# estate-scan.sh — Phase 0: Triage every repo in your estate
#
# Scans GitHub orgs and/or local directories, classifies each repo, detects
# anti-patterns, and outputs a CSV triage report.
#
# Usage:
#   ./estate-scan.sh --github hyperpolymath metadatastician
#   ./estate-scan.sh --local ~/home/hyperpolymath/developer/hyper-repos ~/home/hyperpolymath/developer/meta-repos
#   ./estate-scan.sh --github hyperpolymath --local ~/home/hyperpolymath/developer/hyper-repos ~/home/hyperpolymath/developer/meta-repos
#
# Default local paths (if --local given with no args):
#   ~/home/hyperpolymath/developer/hyper-repos
#   ~/home/hyperpolymath/developer/meta-repos
#
# Requirements: gh (authenticated), jq, git
# Output: estate-triage-report.csv in current directory

set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────

BANNED_LANGUAGES=(
  "Go" "Python" "Nix" "JavaScript" "TypeScript" "ReScript"
  "CoffeeScript" "Dart" "PHP" "Ruby" "Perl" "Lua" "R"
  "Objective-C" "Swift" "Kotlin" "Java" "Scala" "Groovy"
  "C#" "F#" "Visual Basic" "PowerShell"
)

# Languages that are always allowed in the target stack
ALLOWED_LANGUAGES=(
  "Rust" "Zig" "Idris" "Haskell" "Julia" "Erlang" "Elixir"
  "Shell" "Makefile" "Dockerfile" "Just" "Nix"  # Nix banned for app code but ok in CI configs
  "AsciiDoc" "Markdown" "LaTeX" "TOML" "YAML" "JSON"
  "C" "C++" "Assembly"  # via hexadeca only — flagged if direct
)

REPORT_FILE="estate-triage-report.csv"
DETAIL_DIR="estate-scan-details"
GITHUB_ORGS=()
LOCAL_DIRS=()

# ─── Argument parsing ──────────────────────────────────────────────────────

# Parse command-line options and set the scan mode and target.
parse_args() {
  local mode=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --github) mode="github"; shift ;;
      --local)  mode="local";  shift ;;
      --help|-h)
        echo "Usage: $0 [--github org1 org2...] [--local dir1 dir2...]"
        exit 0
        ;;
      *)
        if [[ "$mode" == "github" ]]; then
          GITHUB_ORGS+=("$1")
        elif [[ "$mode" == "local" ]]; then
          LOCAL_DIRS+=("$1")
        else
          echo "Error: specify --github or --local before arguments" >&2
          exit 1
        fi
        shift
        ;;
    esac
  done

  if [[ ${#GITHUB_ORGS[@]} -eq 0 && ${#LOCAL_DIRS[@]} -eq 0 ]]; then
    echo "Error: provide at least one --github org or --local directory" >&2
    exit 1
  fi
}

# ─── Anti-pattern detectors ────────────────────────────────────────────────

# Print the anti-patterns (e.g. NIF without SNIF) found in a repo checkout.
detect_antipatterns() {
  local repo_path="$1"
  local patterns=()

  # NIF without SNIF
  if grep -rql 'erl_nif\.h\|:nif\b\|NIF\b\|#\[rustler::nif\]' "$repo_path" 2>/dev/null; then
    if ! grep -rql 'snif\|SNIF\|safe_nif' "$repo_path" 2>/dev/null; then
      patterns+=("NIF_WITHOUT_SNIF")
    fi
  fi

  # Plain Rust without formal verification
  if find "$repo_path" -name "Cargo.toml" -not -path "*/target/*" 2>/dev/null | head -1 | grep -q .; then
    if ! grep -rql 'gnatprove\|kani\|creusot\|prusti\|verus\|#\[requires\]\|#\[ensures\]\|#\[invariant\]\|#\[proof\]' "$repo_path" 2>/dev/null; then
      patterns+=("UNVERIFIED_RUST")
    fi
  fi

  # Deno usage (should be Bun)
  if find "$repo_path" -name "deno.json" -o -name "deno.jsonc" -o -name "deno.lock" 2>/dev/null | head -1 | grep -q .; then
    patterns+=("DENO_NOT_BUN")
  fi

  # Node usage (should be Bun)
  if find "$repo_path" -name "package-lock.json" -o -name "yarn.lock" -o -name "pnpm-lock.yaml" 2>/dev/null | head -1 | grep -q .; then
    if ! find "$repo_path" -name "bun.lockb" -o -name "bunfig.toml" 2>/dev/null | head -1 | grep -q .; then
      patterns+=("NODE_NOT_BUN")
    fi
  fi

  # Direct C FFI (should go through hexadeca)
  if grep -rql '@cImport\|extern "C"\|ctypes\.\|cffi\.\|cgo\|:ffi\b\|Foreign\.C\.' "$repo_path" 2>/dev/null; then
    if ! grep -rql 'hexadeca\|hexadeca_adapter\|hexadeca-adapter' "$repo_path" 2>/dev/null; then
      patterns+=("DIRECT_FFI_NO_HEXADECA")
    fi
  fi

  # Idris2 not used as ABI layer
  if find "$repo_path" -name "*.idr" 2>/dev/null | head -1 | grep -q .; then
    if ! grep -rql 'ABI\|abi\|Foreign\|Layout\|idrisiser' "$repo_path" 2>/dev/null; then
      patterns+=("IDRIS2_NOT_ABI_ROLE")
    fi
  fi

  # Nix flakes (should be Guix or Justfile)
  if find "$repo_path" -name "flake.nix" -o -name "default.nix" -o -name "shell.nix" 2>/dev/null | head -1 | grep -q .; then
    patterns+=("NIX_PRESENT")
  fi

  # Vite (debate item — flag but don't classify as error)
  if find "$repo_path" -name "vite.config.*" 2>/dev/null | head -1 | grep -q .; then
    patterns+=("VITE_DEBATE")
  fi

  echo "${patterns[*]:-NONE}"
}

# ─── Language detection (local repos) ──────────────────────────────────────

# Print the languages present in a local repo, by file extension counts.
detect_languages_local() {
  local repo_path="$1"
  local langs=()

  # Count files by extension
  declare -A ext_map=(
    [rs]="Rust" [zig]="Zig" [idr]="Idris" [hs]="Haskell"
    [jl]="Julia" [erl]="Erlang" [ex]="Elixir" [exs]="Elixir"
    [go]="Go" [py]="Python" [ts]="TypeScript" [tsx]="TypeScript"
    [js]="JavaScript" [jsx]="JavaScript" [res]="ReScript" [resi]="ReScript"
    [nix]="Nix" [v]="V" [c]="C" [h]="C" [cpp]="C++" [hpp]="C++"
    [rb]="Ruby" [pl]="Perl" [lua]="Lua" [r]="R"
    [java]="Java" [kt]="Kotlin" [scala]="Scala" [cs]="C#"
    [swift]="Swift" [m]="Objective-C" [dart]="Dart" [php]="PHP"
    [sh]="Shell" [bash]="Shell"
  )

  local seen=()
  while IFS= read -r file; do
    local ext="${file##*.}"
    local lang="${ext_map[$ext]:-}"
    if [[ -n "$lang" ]] && [[ ! " ${seen[*]:-} " =~ " $lang " ]]; then
      seen+=("$lang")
      langs+=("$lang")
    fi
  done < <(find "$repo_path" -type f \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/target/*" \
    -not -path "*/_build/*" \
    -not -path "*/vendor/*" \
    -not -path "*/.zig-cache/*" \
    2>/dev/null | head -500)

  echo "${langs[*]:-Unknown}"
}

# ─── Classification logic ─────────────────────────────────────────────────

# Classify a repo (compliant, banned-language, unclassified, ...) from its languages, policy and anti-patterns.
classify_repo() {
  local languages="$1"
  local has_policy="$2"    # whether .language-policy.toml exists
  local role="$3"          # from policy file, or "unknown"
  local antipatterns="$4"

  local has_banned=false
  local has_target=false

  for lang in $languages; do
    for banned in "${BANNED_LANGUAGES[@]}"; do
      if [[ "$lang" == "$banned" ]]; then
        has_banned=true
        break
      fi
    done
    for allowed in "${ALLOWED_LANGUAGES[@]}"; do
      if [[ "$lang" == "$allowed" ]]; then
        has_target=true
        break
      fi
    done
  done

  # Community adapter — has banned language but that's the point
  if [[ "$role" == "community-adapter" ]]; then
    if [[ "$antipatterns" == "NONE" ]]; then
      echo "COMMUNITY_OK"
    else
      echo "COMMUNITY_NEEDS_FIX"
    fi
    return
  fi

  # No banned languages and no anti-patterns
  if [[ "$has_banned" == false && "$antipatterns" == "NONE" ]]; then
    echo "DONE"
    return
  fi

  # No banned languages but has anti-patterns
  if [[ "$has_banned" == false && "$antipatterns" != "NONE" ]]; then
    echo "CLEAN"
    return
  fi

  # Has banned languages — is there any target-stack code too?
  if [[ "$has_target" == true ]]; then
    echo "MIGRATE"
  else
    echo "KILL"
  fi
}

# ─── Repo freshness ───────────────────────────────────────────────────────

# Print a local repo's last commit date and commit count as 'date|count'.
repo_freshness_local() {
  local repo_path="$1"
  local last_commit
  last_commit=$(git -C "$repo_path" log -1 --format='%ci' 2>/dev/null || echo "unknown")
  local commit_count
  commit_count=$(git -C "$repo_path" rev-list --count HEAD 2>/dev/null || echo "0")
  echo "$last_commit|$commit_count"
}

# ─── Scan GitHub org ───────────────────────────────────────────────────────

# Scan every repo of a GitHub org and append one CSV row per repo to the report.
scan_github_org() {
  local org="$1"
  echo "Scanning GitHub org: $org ..." >&2

  # Get all repos with metadata.
  # The `languages` field over a large org is an expensive GraphQL query that
  # GitHub intermittently answers with HTTP 502. Under `set -e` a single 502
  # aborts the entire scan, so fetch to a temp file with bounded retries first.
  local listing
  listing=$(mktemp)
  local try=1 max_try=5 ok=false
  while [[ $try -le $max_try ]]; do
    if gh repo list "$org" --limit 1000 \
         --json name,primaryLanguage,languages,isArchived,isFork,pushedAt,stargazerCount,forkCount,description \
         > "$listing" 2>/dev/null && [[ -s "$listing" ]]; then
      ok=true
      break
    fi
    echo "  gh repo list $org failed (attempt $try/$max_try); retrying in $(( try * 10 ))s ..." >&2
    sleep $(( try * 10 ))
    try=$(( try + 1 ))
  done
  if [[ "$ok" != true ]]; then
    echo "ERROR: could not list org '$org' after $max_try attempts — SKIPPING (not silently passing)" >&2
    rm -f "$listing"
    return 1
  fi

  jq -r '.[] | [
        .name,
        (.primaryLanguage.name // "None"),
        ([.languages[].node.name] | join(";")),
        .isArchived,
        .isFork,
        .pushedAt,
        .stargazerCount,
        .forkCount,
        (.description // "" | gsub(","; " ") | gsub("\n"; " "))
      ] | @csv' "$listing" \
  | while IFS=, read -r name primary all_langs archived fork pushed_at stars forks description; do
    # Strip quotes from CSV
    name=$(echo "$name" | tr -d '"')
    primary=$(echo "$primary" | tr -d '"')
    all_langs=$(echo "$all_langs" | tr -d '"' | tr ';' ' ')
    archived=$(echo "$archived" | tr -d '"')
    fork=$(echo "$fork" | tr -d '"')
    pushed_at=$(echo "$pushed_at" | tr -d '"')
    stars=$(echo "$stars" | tr -d '"')
    forks=$(echo "$forks" | tr -d '"')
    description=$(echo "$description" | tr -d '"')

    # Skip archived and forks
    if [[ "$archived" == "true" ]]; then
      echo "github:$org,$name,$primary,\"$all_langs\",ARCHIVED,NONE,$pushed_at,$stars,$forks,\"$description\""
      continue
    fi
    if [[ "$fork" == "true" ]]; then
      echo "github:$org,$name,$primary,\"$all_langs\",FORK,NONE,$pushed_at,$stars,$forks,\"$description\""
      continue
    fi

    # Clone shallowly to check for anti-patterns and policy file
    local tmpdir
    tmpdir=$(mktemp -d)
    if gh repo clone "$org/$name" "$tmpdir/$name" -- --depth 1 --quiet 2>/dev/null; then
      local antipatterns
      antipatterns=$(detect_antipatterns "$tmpdir/$name")

      local has_policy="false"
      local role="unknown"
      if [[ -f "$tmpdir/$name/.language-policy.toml" ]]; then
        has_policy="true"
        role=$(grep -oP 'role\s*=\s*"\K[^"]+' "$tmpdir/$name/.language-policy.toml" 2>/dev/null || echo "unknown")
      fi

      local classification
      classification=$(classify_repo "$all_langs" "$has_policy" "$role" "$antipatterns")

      echo "github:$org,$name,$primary,\"$all_langs\",$classification,$antipatterns,$pushed_at,$stars,$forks,\"$description\""
      rm -rf "$tmpdir"
    else
      echo "github:$org,$name,$primary,\"$all_langs\",SCAN_FAILED,CLONE_ERROR,$pushed_at,$stars,$forks,\"$description\""
      rm -rf "$tmpdir"
    fi
  done

  rm -f "$listing"
}

# ─── Scan local directory ─────────────────────────────────────────────────

# Scan every git checkout directly under a directory and append one CSV row per repo.
scan_local_dir() {
  local base_dir="$1"
  echo "Scanning local directory: $base_dir ..." >&2

  for repo_path in "$base_dir"/*/; do
    [[ -d "$repo_path/.git" ]] || continue

    local name
    name=$(basename "$repo_path")

    local languages
    languages=$(detect_languages_local "$repo_path")

    local primary
    primary=$(echo "$languages" | awk '{print $1}')

    local antipatterns
    antipatterns=$(detect_antipatterns "$repo_path")

    local has_policy="false"
    local role="unknown"
    if [[ -f "$repo_path/.language-policy.toml" ]]; then
      has_policy="true"
      role=$(grep -oP 'role\s*=\s*"\K[^"]+' "$repo_path/.language-policy.toml" 2>/dev/null || echo "unknown")
    fi

    local classification
    classification=$(classify_repo "$languages" "$has_policy" "$role" "$antipatterns")

    local freshness
    freshness=$(repo_freshness_local "$repo_path")
    local last_commit="${freshness%%|*}"
    local commit_count="${freshness##*|}"

    local description=""
    if [[ -f "$repo_path/README.md" ]]; then
      description=$(head -5 "$repo_path/README.md" | tr ',' ' ' | tr '\n' ' ' | cut -c1-120)
    elif [[ -f "$repo_path/README.adoc" ]]; then
      description=$(head -5 "$repo_path/README.adoc" | tr ',' ' ' | tr '\n' ' ' | cut -c1-120)
    fi

    echo "local:$(basename "$base_dir"),$name,$primary,\"$languages\",$classification,$antipatterns,$last_commit,$commit_count,0,\"$description\""
  done
}

# ─── Main ──────────────────────────────────────────────────────────────────

# Entry point: parse arguments, run the selected scan and write the report.
main() {
  parse_args "$@"

  mkdir -p "$DETAIL_DIR"

  # CSV header
  echo "source,name,primary_language,all_languages,classification,antipatterns,last_activity,stars_or_commits,forks,description" > "$REPORT_FILE"

  # Scan GitHub orgs
  local failed_orgs=()
  for org in "${GITHUB_ORGS[@]}"; do
    if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
      # Do not let one failed org abort the whole scan (incl. the local dirs),
      # but record it loudly so the report is never silently partial.
      if ! scan_github_org "$org" >> "$REPORT_FILE"; then
        failed_orgs+=("$org")
      fi
    else
      echo "WARNING: gh CLI not authenticated. Skipping GitHub org: $org" >&2
      echo "  Run 'gh auth login' first, or use --local for local directories." >&2
    fi
  done

  # Scan local directories
  for dir in "${LOCAL_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      scan_local_dir "$dir" >> "$REPORT_FILE"
    else
      echo "WARNING: directory not found: $dir" >&2
    fi
  done

  # Summary
  echo "" >&2
  echo "════════════════════════════════════════════════════════════" >&2
  echo "  ESTATE SCAN COMPLETE" >&2
  echo "════════════════════════════════════════════════════════════" >&2
  echo "" >&2
  echo "  Report: $REPORT_FILE" >&2
  echo "" >&2

  # Count by classification
  for class in KILL MIGRATE CLEAN DONE COMMUNITY_OK COMMUNITY_NEEDS_FIX ARCHIVED FORK SCAN_FAILED; do
    # `grep -c` prints 0 AND exits 1 on no-match; `|| echo 0` would concatenate
    # to "0\n0" and break the numeric test. Assign, then default on failure.
    count=$(grep -c ",$class," "$REPORT_FILE" 2>/dev/null) || count=0
    if [[ "$count" -gt 0 ]]; then
      printf "  %-25s %s\n" "$class" "$count" >&2
    fi
  done

  echo "" >&2

  # Anti-pattern summary
  echo "  Anti-patterns found:" >&2
  for pattern in NIF_WITHOUT_SNIF UNVERIFIED_RUST DENO_NOT_BUN NODE_NOT_BUN DIRECT_FFI_NO_HEXADECA IDRIS2_NOT_ABI_ROLE NIX_PRESENT VITE_DEBATE; do
    count=$(grep -c "$pattern" "$REPORT_FILE" 2>/dev/null) || count=0
    if [[ "$count" -gt 0 ]]; then
      printf "    %-30s %s\n" "$pattern" "$count" >&2
    fi
  done

  echo "" >&2
  echo "  Next: review KILL items first, then MIGRATE, then CLEAN." >&2
  echo "════════════════════════════════════════════════════════════" >&2

  # Fail loudly rather than reporting a silently-partial scan as success.
  if [[ ${#failed_orgs[@]} -gt 0 ]]; then
    echo "" >&2
    echo "  INCOMPLETE: these orgs could not be scanned: ${failed_orgs[*]}" >&2
    echo "  The report above is PARTIAL. Re-run before trusting it." >&2
    return 1
  fi
}

main "$@"
