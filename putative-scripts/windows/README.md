# windows/ helper scripts

## Launch-ClaudePlan.ps1

**Problem it fixes.** `/ultraplan` (and any "Claude Code on the web" / cloud
feature) refuses to start unless the working directory is a git repo:

```
ultraplan: cannot launch cloud session -
Cloud agents require a git repository (checked: C:\Windows\System32).
```

That happens when Claude Code is started from a shortcut with no **Start in**
directory (or via Win+R), so its cwd defaults to `C:\Windows\System32`.

**Fix.** Launch from a repo. This script picks a repo under your WSL Debian
developer tree and starts `claude` there.

```powershell
# from a pwsh prompt:
\\wsl.localhost\Debian\home\hyperpolymath\developer\scripts\windows\Launch-ClaudePlan.ps1 statistikles
# or interactive picker:
\\wsl.localhost\Debian\home\hyperpolymath\developer\scripts\windows\Launch-ClaudePlan.ps1
# native inside Debian (avoids UNC / dubious-ownership issues):
\\wsl.localhost\...\Launch-ClaudePlan.ps1 statistikles -Wsl
```

Roots searched: `hyper-repos`, `meta-repos`, `repos` under
`\\wsl.localhost\Debian\home\hyperpolymath\developer`.

**Permanent fix (optional):** edit your Claude Code Start-menu shortcut →
Properties → set **Start in** to a repo path, so it never lands in System32.
Even better, run Claude Code natively inside Debian where your repos live.

---

## Note on the antivirus "TrojanDownloader" alert

On 2026-07-13 the Behavior Blocker flagged:

```
C:\Users\USER\AppData\Roaming\Claude\claude-code\2.1.205\claude.exe
```

This is a **false positive**:

- `AppData\Roaming\Claude\claude-code\<version>\` is Claude Code's
  **auto-updater staging folder**. It downloads a new build and swaps it in -
  literally "download an executable and run it", which heuristic engines label
  `TrojanDownloader`. That folder is gone now; the live install is
  `C:\Users\USER\.local\bin\claude.exe`.
- The alert's SHA1 was all zeros - the engine fired on *behaviour*, not a
  signature match.
- The current binary is **validly Authenticode-signed by "Anthropic, PBC"**
  (DigiCert EV code-signing cert, signature status Valid).

If it keeps tripping, add an AV exclusion for:
`C:\Users\USER\.local\bin\` and `C:\Users\USER\AppData\Roaming\Claude\`.
