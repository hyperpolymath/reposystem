# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.x.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

1. **Do NOT** create a public GitHub issue for security vulnerabilities
2. Email security concerns to the maintainers (see MAINTAINERS.md)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact assessment
   - Any suggested fixes (if applicable)

### What to Expect

- Acknowledgment within 48 hours
- Status update within 7 days
- Coordinated disclosure timeline discussion

### Scope

Security concerns include but are not limited to:

- Authentication/authorization bypasses
- Data exposure or leakage
- Injection vulnerabilities (SQL, command, etc.)
- Cryptographic weaknesses
- Supply chain vulnerabilities
- Container escape vectors

### Cryptographic Standards

This project uses the following cryptographic primitives:

| Purpose | Algorithm | Notes |
|---------|-----------|-------|
| Hashing | BLAKE3 | Primary hash function |
| XOF | SHAKE3-512 | Extendable output |
| Signatures | Ed448 | Classical signatures |
| Post-Quantum Sig | Dilithium | NIST PQC standard |
| KEM | Kyber-1024 | Post-quantum key exchange |
| Primes | Flat distribution | Proven strong primes |

### Security Headers

Deployed instances should implement:

- `Content-Security-Policy`
- `Strict-Transport-Security`
- `X-Content-Type-Options`
- `X-Frame-Options`
- `Referrer-Policy`
- `Permissions-Policy`

### DNSSEC

All DNS zones should be signed with:
- DNSSEC (full chain validation)
- ZONEMD (zone integrity)

## Security Advisories

Security advisories will be published via GitHub Security Advisories.
