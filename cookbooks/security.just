# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
#
# security.just - Security analysis cookbook

# Full security audit
security-audit:
    @echo "Running full security audit..."
    reposystem scan --aspect security
    reposystem weak-links --aspect security
    reposystem analyze --vulnerabilities
    @echo "✓ Security audit complete"

# Dependency vulnerability check
security-deps:
    @echo "Checking dependency vulnerabilities..."
    reposystem deps --check-vulnerabilities
    cargo audit 2>/dev/null || true
    @echo "✓ Dependency check complete"

# Supply chain analysis
security-supply-chain:
    @echo "Analyzing supply chain..."
    reposystem analyze --supply-chain
    reposystem report --aspect supply-chain > supply-chain-report.md

# Generate SBOM (Software Bill of Materials)
security-sbom format="cyclonedx":
    @echo "Generating SBOM ({{format}})..."
    reposystem sbom --format {{format}} > sbom.json
    @echo "✓ SBOM generated: sbom.json"

# Find weak links in security
security-weak-links:
    @echo "Finding security weak links..."
    reposystem weak-links --aspect security --severity high

# Check for secrets in code
security-secrets:
    @echo "Scanning for secrets..."
    git secrets --scan 2>/dev/null || \
    trufflehog filesystem . --no-update 2>/dev/null || \
    @echo "Install git-secrets or trufflehog for secret scanning"

# Full security pipeline
security-full:
    @echo "Running full security pipeline..."
    just -f cookbooks/security.just security-audit
    just -f cookbooks/security.just security-deps
    just -f cookbooks/security.just security-supply-chain
    just -f cookbooks/security.just security-sbom
    just -f cookbooks/security.just security-secrets
    @echo "✓ Full security pipeline complete"

# Export security-filtered graph
security-export format="dot":
    @echo "Exporting security view..."
    reposystem export --aspect security --format {{format}} -o security-graph.{{format}}
