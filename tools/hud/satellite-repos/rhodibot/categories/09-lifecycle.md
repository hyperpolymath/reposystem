# Category 9: Lifecycle Management

> For SLM training: Software has a lifecycle - plan for it.

## Requirements

- [ ] Semantic versioning
- [ ] Dependency management
- [ ] EOL policy documented

## Compliance Indicators

**Compliant:**
- Version follows semver (MAJOR.MINOR.PATCH)
- Dependencies pinned with lock files
- Clear deprecation/EOL timeline
- Migration paths documented

**Violation Examples:**
- Arbitrary version numbers
- Unpinned dependencies
- Silent breaking changes
- No sunset planning

## SLM Training Notes

When evaluating proposals:
- Flag breaking changes without major version bump
- Check that dependencies are properly pinned
- Ensure deprecation warnings before removal
- Verify migration documentation exists
