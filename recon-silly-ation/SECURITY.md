# Security Policy

## Supported Versions

We currently support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please follow these steps:

### How to Report

**DO NOT** create a public GitHub issue for security vulnerabilities.

Instead, please report security vulnerabilities by emailing:

**j.d.a.jewell@open.ac.uk**

Or use GitHub's security advisory feature:
https://github.com/Hyperpolymath/recon-silly-ation/security/advisories/new

### What to Include

Please include the following in your report:

1. **Description** - Detailed description of the vulnerability
2. **Impact** - What can an attacker achieve?
3. **Steps to Reproduce** - Clear steps to reproduce the issue
4. **Proof of Concept** - Code or screenshots demonstrating the issue
5. **Suggested Fix** - If you have ideas for how to address the issue

### What to Expect

- **Acknowledgment**: We will acknowledge receipt within 48 hours
- **Assessment**: We will assess the vulnerability within 7 days
- **Updates**: We will keep you informed of our progress
- **Disclosure**: We prefer coordinated disclosure after a fix is available
- **Credit**: We will credit you in the security advisory (unless you prefer to remain anonymous)

## Security Best Practices

When using recon-silly-ation:

### Configuration Security

1. **Secrets Management**
   - Never commit credentials to version control
   - Use environment variables for sensitive data
   - Rotate ArangoDB passwords regularly
   - Use strong passwords (min 16 characters)

2. **Database Access**
   - Restrict ArangoDB network access
   - Use authentication for all database connections
   - Enable SSL/TLS for production deployments
   - Regular backup of database contents

3. **LLM API Keys**
   - Store API keys in environment variables
   - Never log API keys
   - Use separate keys for dev/staging/production
   - Monitor API usage for anomalies

### Runtime Security

1. **File System Access**
   - Run with minimal required permissions
   - Use read-only file system access when possible
   - Validate all file paths before access
   - Sanitize user input

2. **Podman Security**
   - Use Chainguard base images
   - Run as non-root user where possible
   - Scan images for vulnerabilities
   - Keep base images updated

3. **Network Security**
   - Use HTTPS for all external connections
   - Validate SSL certificates
   - Implement rate limiting
   - Use firewall rules to restrict access

### Code Security

1. **Input Validation**
   - Validate all document content
   - Sanitize user-provided data
   - Check file size limits
   - Prevent path traversal attacks

2. **LLM Output**
   - NEVER auto-execute LLM-generated code
   - Always require human approval (`requiresApproval: true`)
   - Validate generated content
   - Maintain audit trail

3. **Dependencies**
   - Regularly update dependencies (`deno lint`)
   - Review dependency security advisories
   - Use lock files (`deno.lock`)
   - Minimize dependency count

## Known Security Considerations

### LLM Integration

- **Risk**: LLM outputs may contain malicious content
- **Mitigation**: Always `requiresApproval: true`, validation before use
- **Status**: Guardrails implemented ✅

### Content Hashing

- **Risk**: Hash collisions (theoretical)
- **Mitigation**: SHA-256 provides 2^256 space, collisions astronomically unlikely
- **Status**: Production-safe ✅

### ArangoDB Access

- **Risk**: SQL injection (theoretical in AQL)
- **Mitigation**: Parameterized queries, input validation
- **Status**: Type-safe client prevents injection ✅

### File System Access

- **Risk**: Path traversal, unauthorized file access
- **Mitigation**: Path validation, sandboxing
- **Status**: Basic validation implemented, recommend running in container

## Security Updates

We will:

- Release security patches as soon as possible
- Publish security advisories for all vulnerabilities
- Credit researchers who responsibly disclose issues
- Maintain a changelog of security fixes

## Compliance

### CCCP Compliance

This project includes CCCP compliance checking:

- Detects Python files ("Patrojisign/insulti" warnings)
- Identifies security anti-patterns in Python code
- Recommends migrations to ReScript/Deno
- See `src/CCCPCompliance.res` for implementation

### Data Privacy

- No personal data is collected by default
- Document content is stored locally or in your ArangoDB instance
- No telemetry or analytics sent to external services
- LLM integrations may send content to third parties (user's choice)

## Contact

- **Security Email**: j.d.a.jewell@open.ac.uk
- **Repository**: https://github.com/Hyperpolymath/recon-silly-ation
- **Security Advisories**: https://github.com/Hyperpolymath/recon-silly-ation/security/advisories

---

Last updated: 2026-02-14
