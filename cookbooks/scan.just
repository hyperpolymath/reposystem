# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
#
# scan.just - Repository scanning cookbook
#
# Import: import 'cookbooks/scan.just'

# Default scan path
default_scan_path := "~/repos"

# Quick shallow scan (fast)
scan-shallow path=default_scan_path:
    @echo "Shallow scan: {{path}}"
    reposystem scan --shallow {{path}}

# Deep scan with full metadata extraction
scan-deep path=default_scan_path:
    @echo "Deep scan: {{path}}"
    reposystem scan --deep --metadata {{path}}

# Incremental scan (only changed repos)
scan-incremental path=default_scan_path:
    @echo "Incremental scan: {{path}}"
    reposystem scan --incremental {{path}}

# Scan and auto-detect workspaces (Cargo, npm, etc.)
scan-workspaces path=default_scan_path:
    @echo "Workspace scan: {{path}}"
    reposystem scan --detect-workspaces {{path}}

# Scan with specific aspect focus
scan-aspect path=default_scan_path aspect="security":
    @echo "Aspect scan ({{aspect}}): {{path}}"
    reposystem scan --aspect {{aspect}} {{path}}

# Scan and immediately export
scan-export path=default_scan_path format="dot":
    @echo "Scan and export: {{path}} -> {{format}}"
    reposystem scan {{path}}
    reposystem export --format {{format}}

# Scan with verbose output for debugging
scan-debug path=default_scan_path:
    @echo "Debug scan: {{path}}"
    RUST_LOG=debug reposystem scan -vvv {{path}}

# Scan multiple paths
scan-multi *paths:
    @echo "Multi-path scan: {{paths}}"
    @for path in {{paths}}; do \
        reposystem scan "$path"; \
    done

# Scan and generate report
scan-report path=default_scan_path:
    @echo "Scan with report: {{path}}"
    reposystem scan {{path}}
    reposystem report --format markdown > scan-report.md
    @echo "Report: scan-report.md"

# Full ecosystem scan with all features
scan-full path=default_scan_path:
    @echo "Full ecosystem scan: {{path}}"
    reposystem scan --deep --metadata --detect-workspaces {{path}}
    reposystem analyze
    reposystem report --format markdown > ecosystem-report.md
    @echo "✓ Full scan complete"
