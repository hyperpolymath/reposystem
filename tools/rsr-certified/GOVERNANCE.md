# Governance

This document describes the governance model for the RSR-Certified project.

## Principles

RSR-Certified follows the governance principles of the [Rhodium Standard Repositories](https://gitlab.com/hyperpolymath/rhodium-standard-repositories) framework:

1. **Emotional Safety**: All decisions prioritize contributor wellbeing
2. **Transparency**: All significant decisions are documented publicly
3. **Community Over Ego**: No single person has absolute authority
4. **Gradual Trust**: Responsibilities increase with demonstrated commitment

## Decision Making

### Consensus Model

We use lazy consensus for most decisions:
- Propose changes via issues or pull requests
- Allow 72 hours for feedback on significant changes
- If no objections, proceed
- If objections, discuss until resolution

### Voting

For contentious decisions:
- Simple majority for regular decisions
- 2/3 majority for governance changes
- Core maintainers have binding votes
- Community members have advisory votes

## Roles

### Core Maintainers

Responsible for:
- Final merge authority
- Release management
- Security response
- Governance evolution

Current maintainers: See [MAINTAINERS.md](MAINTAINERS.md)

### Contributors

Anyone who has contributed code, documentation, or significant feedback.

Rights:
- Propose changes
- Participate in discussions
- Advisory votes on decisions

### Community Members

Anyone participating in discussions or using the project.

Rights:
- Open issues
- Request features
- Provide feedback

## Tri-Perimeter Contribution Framework (TPCF)

Following RSR standards, we use graduated trust levels:

### 🔒 Perimeter 1 (Core)
**Access**: Maintainers only

Covers:
- Build system and CI/CD
- Security-critical code
- Governance documents
- Release process

### 🧠 Perimeter 2 (Expert)
**Access**: Trusted contributors

Covers:
- Platform adapters
- Compliance check implementations
- Database integrations
- Performance optimizations

Progression requirements:
- 3+ merged PRs
- Demonstrated expertise
- Maintainer nomination

### 🌱 Perimeter 3 (Community)
**Access**: Open to all

Covers:
- Documentation improvements
- Bug reports and fixes
- Test additions
- Example repositories

## Code of Conduct Enforcement

1. **Warning**: First violation, private discussion
2. **Temporary Ban**: Repeated violations, 7-day ban
3. **Permanent Ban**: Severe or continued violations

Appeals go to maintainers not involved in the original decision.

## Conflict Resolution

1. **Direct Discussion**: Parties try to resolve directly
2. **Mediation**: Uninvolved maintainer mediates
3. **Vote**: Community vote if mediation fails
4. **External**: CCCP community mediation as last resort

## Changes to Governance

This document can be changed via:
1. Proposal in an issue
2. 14-day discussion period
3. 2/3 majority of maintainers
4. 7-day implementation delay

## Inspiration

This governance model draws from:
- [Rust Governance](https://www.rust-lang.org/governance)
- [Node.js Foundation](https://nodejs.org/en/about/governance/)
- [Apache Software Foundation](https://www.apache.org/foundation/governance/)
- [Rhodium Standard TPCF](https://gitlab.com/hyperpolymath/rhodium-standard-repositories)

---

*Last updated: 2024-01-01*
*Next review: 2025-01-01*
