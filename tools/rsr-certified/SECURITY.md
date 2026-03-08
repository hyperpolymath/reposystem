# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**DO NOT** create a public GitHub issue for security vulnerabilities.

Instead, please report vulnerabilities via:

1. **GitHub Security Advisories** (preferred)
   - Go to the Security tab of this repository
   - Click "Report a vulnerability"
   - Fill in the details

2. **Email**
   - Send details to: security@rsr-certified.dev (placeholder)
   - Use PGP encryption if possible

### What to Include

Please include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)
- Your contact information

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 1 week
- **Resolution Target**: Within 90 days (depending on severity)

### Disclosure Policy

We follow coordinated disclosure:

1. Reporter submits vulnerability
2. We confirm and assess severity
3. We develop and test a fix
4. We release the fix
5. We publish a security advisory
6. Reporter may publish their findings (after fix is released)

## Security Measures

### Webhook Verification

All platform adapters implement webhook signature verification:

- **GitHub**: HMAC-SHA256 via `X-Hub-Signature-256`
- **GitLab**: Token verification via `X-Gitlab-Token`
- **Bitbucket**: HMAC-SHA256 signature
- **Gitea**: HMAC-SHA256 via `X-Gitea-Signature`

### Secret Detection

The compliance engine includes secret detection to prevent:

- Hardcoded API keys
- Private keys
- Database credentials
- OAuth tokens
- AWS/GCP/Azure credentials

### Supply Chain Security

This project aims for SLSA Level 2+ compliance:

- Signed releases
- Reproducible builds
- SBOM generation
- Dependency review

### Container Security

- Non-root container user
- Read-only root filesystem
- Minimal base image (Alpine)
- No unnecessary capabilities

## Security-Related Configuration

### Environment Variables

Never commit these to version control:

```
GITHUB_WEBHOOK_SECRET
GITHUB_PRIVATE_KEY
GITLAB_TOKEN
GITLAB_WEBHOOK_SECRET
BITBUCKET_TOKEN
```

Use environment variables or secret management systems.

### Network Security

When deploying:

- Use HTTPS/TLS for all endpoints
- Configure proper firewall rules
- Use network policies in Kubernetes
- Consider IP allowlisting for webhooks

## Vulnerability History

No known vulnerabilities at this time.

---

Thank you for helping keep RSR-Certified and its users safe!
