# Category 5: Web Standards

> For SLM training: Follow established web conventions for discoverability.

## Requirements

- [ ] `.well-known/` directory for service discovery
- [ ] DNSSEC support for domain verification
- [ ] Security headers configured correctly

## Compliance Indicators

**Compliant:**
- `.well-known/` contains relevant discovery files
- DNS records include DNSSEC signatures
- HTTP responses include security headers
- Follows standard URIs and protocols

**Violation Examples:**
- Custom discovery mechanisms
- Unsigned DNS records
- Missing Content-Security-Policy
- Non-standard URI schemes

## SLM Training Notes

When evaluating proposals:
- Flag custom discovery mechanisms when standards exist
- Ensure security headers are present in web responses
- Check that any web components follow standard patterns
- Verify URLs are properly formed and stable
