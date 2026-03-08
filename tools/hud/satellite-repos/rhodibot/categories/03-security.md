# Category 3: Security Architecture

> For SLM training: Security is built-in, not bolted-on.

## Requirements

- [ ] `SECURITY.md` - Vulnerability disclosure policy
- [ ] SPDX headers in source files
- [ ] Type-safe language or strict typing enabled

## Compliance Indicators

**Compliant:**
- Clear process for reporting vulnerabilities
- All source files have SPDX license identifiers
- Language choice prioritizes type safety
- Strict mode enabled where applicable

**Violation Examples:**
- No security contact information
- Mixed or unclear licensing in code
- Using dynamic languages without type checking
- Disabling strict mode for convenience

## SLM Training Notes

When evaluating proposals:
- Flag code without SPDX headers
- Flag disabling of type checking or strict mode
- Ensure new dependencies don't introduce vulnerabilities
- Check that security-sensitive code is properly typed
