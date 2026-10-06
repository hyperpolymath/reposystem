#!/usr/bin/env bash
# gh-auth-health.sh — REPORT-ONLY liveness check for GitHub CLI authentication.
#
# WHY THIS EXISTS (measured incident 2026-09-09):
#   WSL rebooted 08:07:21Z. gnome-keyring came back LOCKED, so gh could not read
#   its PAT — and instead of failing loudly it SILENTLY DEGRADED TO ANONYMOUS.
#   16 sessions then shared one 60/hr anonymous IP quota; 401s became 403
#   rate-limit errors within ~7 minutes. Because `gh api --jq` PRINTS THE ERROR
#   BODY, failed calls parsed as though they were data: reports came out
#   silently FALSE rather than obviously broken. Blind window 08:07Z -> 08:25Z.
#
# THE FAILURE TO CATCH IS NOT "gh IS DEAD". It is "gh STILL WORKS, ANONYMOUSLY".
#
# PROBE DOCTRINE (each measured in the field; do not "simplify" any of it):
#   * `gh api user`, judged by EXIT CODE, is the ONLY sound auth probe.
#     /user requires authentication, so rc=0 proves a credential was accepted.
#   * DO NOT gate on `gh api rate_limit` succeeding first. An INVALID token
#     fails rate_limit too, so a connectivity gate built on it reports "offline"
#     and exits 0 on exactly the case this script exists to catch.
#     Offline-vs-dead is decided instead by WHETHER GITHUB ANSWERED: an HTTP
#     status in gh's error means we reached it and auth is dead; a dial/DNS/TLS
#     error means we never got there, which is not an auth fault.
#   * The core rate-limit CEILING is corroboration only: 60 = anonymous,
#     5000 = authenticated. Never the verdict — it exits zero unauthenticated
#     AND at remaining=0. And only `.limit` is trustworthy: measured 09-09,
#     `gh api rate_limit` said used=0 remaining=5000 while the next response
#     header said used=3174 remaining=1826. Read the budget from HEADERS.
#     And NEVER judge budget on `remaining` alone: it is a ROLLING HOURLY
#     bucket, so a low reading is expected at the end of every window
#     (measured 1826 -> reset -> 4909). Pair it with X-RateLimit-Reset.
#   * LIVENESS AND SUFFICIENCY ARE DIFFERENT QUESTIONS. `gh api user` rc=0
#     proves a credential was accepted; it CANNOT see a missing scope. The only
#     sufficiency probe is the X-Oauth-Scopes header. A credential restored by
#     `gh auth login` came back without `workflow` on 09-09 and every liveness
#     check stayed green while workflow writes 404'd.
#   * `gh auth status` prints "the token in default is invalid" for an EMPTY
#     credential store exactly as for a REVOKED one. It cannot tell them apart.
#   * `gh auth token` rc was observed INCONSISTENT between shells during the
#     same outage. Context only; it never decides the verdict.
#   * NEVER judge a gh call by parsing --jq output: an error body parses as
#     data, and an anonymous read can return a clean WRONG-SHAPED answer that
#     no exit-code check catches.
#
# Prints no secret: exit codes, byte counts, ceilings, and the account login.
# Changes nothing — not the credential store, not gh's config.
#
# Exit: 0 = authenticated, or GitHub genuinely unreachable (not an auth fault)
#       1 = GitHub answered but we are NOT authenticated  <- the silent state
#       2 = could not run
#
# Fixture (proves it can go red without touching your real credential):
#   GH_TOKEN=ghp_0000000000000000000000000000000000 gh-auth-health.sh ; echo $?

set -uo pipefail

echo "gh-auth-health  as-of $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "boot: $(uptime -s 2>/dev/null) (local) — an outage of this kind starts at a reboot"
echo

command -v gh >/dev/null 2>&1 || { echo "FATAL: gh not on PATH"; exit 2; }

# ---- 1. AUTH PROBE. The only sound one. Judged by exit code; stderr kept
#         solely to tell "GitHub said no" apart from "GitHub never answered".
err=$(mktemp) || exit 2
trap 'rm -f "$err"' EXIT
login=$(gh api user --jq .login 2>"$err"); auth_rc=$?
stderr=$(cat "$err")

if [ "$auth_rc" -eq 0 ] && [ -n "$login" ]; then
  echo "1. AUTH  OK — gh api user rc=0, login=$login"

  # One -i call yields BOTH remaining probes from the SAME response: the scope
  # header and the REAL rate-limit headers. Measured 2026-09-09: `gh api
  # rate_limit` reported used=0 remaining=5000 while the very next response
  # header said used=3174 remaining=1826. The rate_limit BODY is fiction for
  # .used/.remaining; only .limit survived. Headers are authoritative.
  hdrs=$(gh api user -i 2>/dev/null | /usr/bin/tr -d '\r')
  scopes=$(printf '%s' "$hdrs" | /usr/bin/grep -i '^x-oauth-scopes:' | cut -d: -f2- | sed 's/^ *//')
  rl_lim=$(printf '%s' "$hdrs" | /usr/bin/grep -i '^x-ratelimit-limit:'     | cut -d: -f2- | tr -dc '0-9')
  rl_rem=$(printf '%s' "$hdrs" | /usr/bin/grep -i '^x-ratelimit-remaining:' | cut -d: -f2- | tr -dc '0-9')
  rl_rst=$(printf '%s' "$hdrs" | /usr/bin/grep -i '^x-ratelimit-reset:'     | cut -d: -f2- | tr -dc '0-9')

  # A LOW `remaining` IS NORMAL AT THE END OF EVERY WINDOW. The core quota is a
  # ROLLING HOURLY BUCKET, not a depleting reserve: measured 09-09, remaining
  # read 2400 -> 1826 -> (reset 08:46:59Z) -> 4909 within minutes. Warning on
  # `remaining` alone therefore fires once an HOUR, every hour, on a healthy
  # system — the exact cry-wolf pattern that gets a checker ignored.
  # X-RateLimit-Reset is in the SAME response, so the two cases are separable:
  # low + reset SOON = end of window, unremarkable.
  # low + reset DISTANT = the burn is real and the window will run dry.
  if [ -n "$rl_lim" ]; then
    if [ -n "$rl_rst" ]; then
      secs=$(( rl_rst - $(date -u +%s) ))
      [ "$secs" -lt 0 ] && secs=0
      echo "2. BUDGET  core ${rl_rem:-?}/${rl_lim}, window resets in $(( secs / 60 ))m"
      echo "   (from RESPONSE HEADERS — \`gh api rate_limit\` .used/.remaining were"
      echo "   measured WRONG; only .limit is sound. Rolling hourly bucket.)"
      if [ -n "$rl_rem" ] && [ "$rl_rem" -lt 500 ] && [ "$secs" -gt 900 ]; then
        echo "   *** LOW WITH A DISTANT RESET — this burn is real, not end-of-window."
        echo "   One PAT is shared across every live session on this box. ***"
      elif [ -n "$rl_rem" ] && [ "$rl_rem" -lt 500 ]; then
        echo "   Low, but the window rolls shortly — normal, not a fault."
      fi
    else
      echo "2. BUDGET  core ${rl_rem:-?}/${rl_lim} (no reset header — cannot tell"
      echo "   end-of-window from a real burn, so not judged)."
    fi
  else
    echo "2. BUDGET  rate-limit headers unavailable (not a fault on its own)."
  fi

  # ---- SUFFICIENCY. A DIFFERENT QUESTION FROM LIVENESS, and the one rc cannot
  #      answer. Measured 2026-09-09: after `gh auth login` restored auth, the
  #      new credential came back WITHOUT `workflow`. gh api user was rc=0 and
  #      every liveness probe was green, yet any write under .github/workflows/
  #      returned a bare 404 — never a 403, never naming the scope, and
  #      indistinguishable from "this repo does not exist".
  #      An EMPTY header is not evidence of absence: fine-grained PATs and App
  #      tokens carry no scope list at all, so blank means UNKNOWN, never red.
  if [ -z "$scopes" ]; then
    echo "3. SUFFICIENCY  no scope header (fine-grained PAT or App token) — cannot"
    echo "   determine scopes from here. Not treated as a fault."
    echo
    echo "VERDICT: authenticated (scope sufficiency unknown)."
    exit 0
  fi
  echo "3. SUFFICIENCY  scopes: $scopes"
  if printf '%s' "$scopes" | /usr/bin/grep -qw 'workflow'; then
    echo "   workflow scope present."
    echo
    echo "VERDICT: authenticated."
    exit 0
  fi
  echo "   *** MISSING 'workflow' SCOPE — writes under .github/workflows/ will"
  echo "   return a bare 404 that names nothing and reads exactly like a missing"
  echo "   repo. Liveness is GREEN and the credential is still INSUFFICIENT. ***"
  echo "   Cure:  gh auth refresh -h github.com -s workflow"
  echo "   NOTE: a re-login after a reboot must carry -s workflow, or the scope"
  echo "   is silently dropped again — that is how this state arose."
  echo
  echo "VERDICT: authenticated but INSUFFICIENT (missing workflow scope)."
  exit 1
fi

# ---- 2. FAILED. Did GitHub answer at all?
#         An HTTP status in the error = we reached GitHub and it refused us.
if [ "$auth_rc" -eq 4 ] || printf '%s' "$stderr" | /usr/bin/grep -qiE 'gh auth login|GH_TOKEN environment variable'; then
  # gh exits 4 with this wording when it holds NO credential at all — it does
  # not even try the call. Distinct from a rejected one; same verdict.
  reached=nocred
elif printf '%s' "$stderr" | /usr/bin/grep -qiE 'rate limit|secondary rate|abuse detection'; then
  # A VALID credential that has burned its 5000/hr also returns HTTP 403.
  # Same red, completely different cure — never tell the owner to re-login.
  reached=quota
elif printf '%s' "$stderr" | /usr/bin/grep -qiE 'HTTP (4|5)[0-9][0-9]|gh: Not Found|Bad credentials|Requires authentication'; then
  reached=yes
elif printf '%s' "$stderr" | /usr/bin/grep -qiE 'error connecting to|check your internet connection|githubstatus|dial tcp|no such host|lookup |connection refused|network is unreachable|i/o timeout|TLS handshake|certificate'; then
  reached=no
else
  reached=unknown
fi

case "$reached" in
  no)
    echo "1. AUTH  gh api user rc=$auth_rc — but GitHub was never reached"
    echo "   (transport error, not a refusal). Network or GitHub outage."
    echo
    echo "VERDICT: unknown (offline). NOT an authentication fault; nothing to act on."
    exit 0
    ;;
  unknown)
    echo "1. AUTH  gh api user rc=$auth_rc — error not recognised as either a"
    echo "   refusal or a transport failure. Treating as an auth fault, because"
    echo "   a false alarm is cheap and a missed silent-anonymous window is not."
    ;;
  yes)
    echo "1. AUTH  FAILED — GitHub answered and refused us (gh api user rc=$auth_rc)"
    ;;
  nocred)
    echo "1. AUTH  FAILED — gh holds NO usable credential (rc=$auth_rc)."
    echo "   Closest to the 2026-09-09 shape: the PAT is unreadable, so gh either"
    echo "   refuses outright or falls back to ANONYMOUS calls that still succeed."
    ;;
  quota)
    echo "1. QUOTA  Credential is VALID but its rate limit is EXHAUSTED (rc=$auth_rc)."
    echo "   *** DO NOT run 'gh auth login' — authentication is not the problem. ***"
    echo "   16 concurrent sessions share one PAT and one 5000/hr budget."
    echo "   Cure: wait for the reset, or stagger the sessions. Check the budget with:"
    echo "         gh api rate_limit --jq '.resources.core'"
    echo
    echo "VERDICT: authenticated but rate-limited — report only, nothing was changed."
    exit 1
    ;;
esac

# Corroboration. Do not gate on it: with a bad token this fails too.
ceiling=$(gh api rate_limit --jq '.resources.core.limit' 2>/dev/null); ceil_rc=$?
# `gh api --jq` prints the ERROR BODY on failure, so an unsanitised $ceiling
# can be a whole JSON blob. Only digits are a ceiling; anything else is noise.
case "$ceiling" in ([0-9]|[0-9][0-9]|[0-9][0-9][0-9]|[0-9][0-9][0-9][0-9]|[0-9][0-9][0-9][0-9][0-9]) ;; (*) ceiling="" ;; esac
if [ "$ceil_rc" -eq 0 ] && [ -n "$ceiling" ] && [ "$ceiling" -le 60 ]; then
  echo "2. CORROBORATION  ceiling=$ceiling — gh is running ANONYMOUSLY, not erroring."
  echo "   *** EVERY gh RESULT GATHERED NOW IS SILENTLY UNTRUSTWORTHY. ***"
  echo "   The anonymous 60/hr quota is shared across every session on this IP"
  echo "   and exhausts in minutes, turning 401s into 403 rate-limit errors."
else
  echo "2. CORROBORATION  rate_limit rc=$ceil_rc ceiling=${ceiling:-n/a}"
  echo "   (a rejected credential fails this call too — expected, not extra news)."
fi

tok=$(gh auth token 2>/dev/null); tok_rc=$?
printf '3. CONTEXT  gh auth token rc=%s len=%s (inconsistent across shells — not a verdict)\n' \
       "$tok_rc" "${#tok}"
echo
# Shade the diagnosis by how long ago we booted. A revoked PAT and a locked
# keyring produce the IDENTICAL 'Bad credentials'; the script cannot tell them
# apart, so it must not assert that nothing was revoked.
boot_epoch=$(date -d "$(uptime -s)" +%s 2>/dev/null || echo 0)
now_epoch=$(date +%s)
if [ "$boot_epoch" -gt 0 ] && [ "$(( now_epoch - boot_epoch ))" -lt 3600 ]; then
  echo "   Booted less than an hour ago — the likely cause is a LOCKED KEYRING:"
  echo "   the PAT is intact but unreadable. Cure:  gh auth login"
else
  echo "   Boot was not recent, so a locked keyring is the less likely of the two."
  echo "   A REVOKED PAT and a locked keyring are indistinguishable from here"
  echo "   (both give 'Bad credentials'). Check the token is still live on GitHub"
  echo "   before assuming a re-login is all that is needed.  Cure:  gh auth login"
fi
echo "   Then re-verify:  gh api user"
echo "   DISCARD any gh-derived measurement taken since the last reboot."
echo
echo "VERDICT: NOT authenticated — report only, nothing was changed."
exit 1
