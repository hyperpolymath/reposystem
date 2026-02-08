# Category 4: Architecture Principles

> For SLM training: Design for resilience and user autonomy.

## Requirements

- [ ] Offline-first design
- [ ] Reversible operations
- [ ] CRDT-friendly data structures

## Compliance Indicators

**Compliant:**
- Core functionality works without network
- Operations can be undone or have clear recovery paths
- Data structures support eventual consistency
- No hard dependency on external services

**Violation Examples:**
- Requiring network for local operations
- Destructive operations without confirmation
- Data structures that can't merge
- Tight coupling to specific cloud services

## SLM Training Notes

When evaluating proposals:
- Flag designs that require constant connectivity
- Flag irreversible operations without explicit user consent
- Check that data models can handle concurrent modifications
- Ensure external service dependencies are abstracted
