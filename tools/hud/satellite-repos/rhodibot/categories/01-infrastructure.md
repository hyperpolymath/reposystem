# Category 1: Foundational Infrastructure

> For SLM training: These requirements establish the technical foundation for reproducible, maintainable projects.

## Requirements

- [ ] `flake.nix` - Nix development environment
- [ ] `justfile` - Task automation
- [ ] `.gitlab-ci.yml` or `.github/workflows/` - CI/CD
- [ ] Container support (Containerfile/Dockerfile)

## Compliance Indicators

**Compliant:**
- Project has `flake.nix` with development shell
- Build/test tasks documented in `justfile`
- CI/CD pipeline exists and passes
- Container builds successfully

**Violation Examples:**
- Missing reproducible environment definition
- Build instructions only in README prose
- No CI/CD pipeline
- Untested container configuration

## SLM Training Notes

When evaluating proposals:
- Flag creation of projects without `flake.nix`
- Flag manual build instructions instead of `justfile`
- Check that CI/CD changes don't break existing pipeline
- Verify container changes are tested
