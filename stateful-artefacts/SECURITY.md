# Security Policy

## Supported Versions

We actively support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in stateful-artefacts-for-gitforges, please report it responsibly:

### How to Report

1. **DO NOT** open a public GitHub issue for security vulnerabilities
2. Email security details to: [Your security contact email]
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response Timeline

- **Initial Response:** Within 48 hours
- **Status Update:** Within 7 days
- **Fix Timeline:** Depends on severity
  - Critical: 7-14 days
  - High: 14-30 days
  - Medium: 30-60 days
  - Low: Next regular release

### Security Measures

This project implements the following security practices:

#### Code Quality
- ✅ CodeQL security scanning
- ✅ Dependency review on PRs
- ✅ SBOM (Software Bill of Materials) generation
- ✅ License compliance checking

#### Supply Chain Security
- ✅ SHA-pinned GitHub Actions
- ✅ Minimal permissions in workflows (`permissions: read-all`)
- ✅ Dependabot security updates
- ✅ Signed commits encouraged

#### Runtime Safety
- ✅ Type-safe Haskell implementation
- ✅ Tri-Guard sanitization system
- ✅ FlexiText accessibility enforcement
- ✅ Input validation for S-expressions

### Known Security Considerations

#### Input Parsing
- S-expression parser handles untrusted input from `.scm` files
- Template system processes user-provided templates
- Sanitization applied via Tri-Guard system

#### Recommendations
- Only load `.scm` files from trusted sources
- Validate templates before processing
- Use HTTPS for badge URLs in production

## Security Advisories

Security advisories will be published at:
- GitHub Security Advisories: https://github.com/hyperpolymath/stateful-artefacts-for-gitforges/security/advisories

## Acknowledgments

We appreciate responsible disclosure and will credit security researchers who report vulnerabilities (unless they prefer to remain anonymous).
