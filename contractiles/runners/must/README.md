# must

> Task runner + template engine + project enforcer

**Version:** 0.1.0
**License:** MPL-2.0 (PMPL-1.0-or-later preferred)
**Language:** Ada 2022 with SPARK contracts

## Overview

`must` is a unified project automation tool that combines:
- **Task Runner**: Execute tasks defined in `mustfile.toml`
- **Template Engine**: Mustache-based code generation
- **Project Enforcer**: Validate project requirements and standards
- **Container Deployer**: Build and deploy via Containerfile

## Installation

### From Source

```bash
# Requires: GNAT 15.2.1+, gprbuild
git clone https://github.com/hyperpolymath/must.git
cd must
gprbuild -P must.gpr
./bin/must --version
```

### From Container

```bash
podman pull ghcr.io/hyperpolymath/must:latest
podman run --rm must --help
```

## Quick Start

### Initialize Project

```bash
must init
```

Creates `mustfile.toml` with default configuration.

### Run Tasks

```bash
# List all tasks
must --list

# Run specific task
must build
must test
```

### Apply Templates

```bash
# Apply all templates
must apply

# Apply specific template
must apply --template ada_package --var module=MyModule
```

### Check Requirements

```bash
# Check all requirements
must check

# Auto-fix violations
must fix

# Check + apply + verify
must enforce
```

### Deploy Containers

```bash
# Build from Containerfile
must deploy

# Build and push with tag
must deploy --tag v1.0.0 --push
```

## Features

### Memory Safety (SPARK)

All code uses **bounded strings** with fixed maximum lengths:
- No heap allocations
- Stack-only memory
- Buffer overflow protection
- Zero runtime errors (provable with SPARK)

### Type Safety

Explicit bounded string types:
- `Bounded_Path` (4096 bytes) - File paths
- `Bounded_String` (1024 bytes) - General strings
- `Bounded_Command` (8192 bytes) - Shell commands
- `Bounded_Description` (2048 bytes) - Descriptions

### License Enforcement

Validates and enforces project licensing standards:
- Check for SPDX headers
- Validate copyright holders
- Enforce Podman over Docker
- Check for trailing whitespace, tabs, line endings

## Configuration

### mustfile.toml

```toml
[project]
name = "my-project"
version = "0.1.0"
license = "MPL-2.0"

[tasks.build]
description = "Build the project"
commands = ["make build"]

[tasks.test]
description = "Run tests"
dependencies = ["build"]
commands = ["make test"]

[templates.ada_package]
source = "templates/package.ads.mustache"
destination = "src/{{module_name}}.ads"

[requirements]
must_have = ["LICENSE", "README.md"]
must_not_have = ["Makefile", "Dockerfile"]

[enforcement]
license = "MPL-2.0"
podman_not_docker = true
```

## Project Structure

```
must/
├── src/
│   ├── must.adb               # Main entry point
│   ├── must_types.ads/adb     # Bounded string types
│   ├── cli/                   # CLI argument parsing
│   ├── config/                # TOML configuration
│   ├── tasks/                 # Task execution
│   ├── templates/             # Mustache rendering
│   ├── requirements/          # Requirement checking
│   └── deploy/                # Container deployment
├── must.gpr                   # GNAT project file
└── mustfile.toml              # Project configuration
```

## Development Status

**Current Phase:** Alpha (v0.1.0)

**SPARK Conversion:** ✅ Complete (2026-02-05)
- All 9 modules converted to bounded strings
- Zero compilation errors/warnings
- Memory safety guaranteed
- Ready for formal verification

**Next Release:** v0.2.0
- Mustache partials support
- Content requirement checks
- Enhanced TOML variable loading

## Contributing

See [SECURITY.md](SECURITY.md) for security policy.

All contributions must:
- Use bounded strings (no `Unbounded_String`)
- Include SPDX license headers
- Pass all requirement checks
- Compile with zero warnings

## License

Mozilla Public License 2.0 (MPL-2.0)

**Preferred:** PMPL-1.0-or-later (Palimpsest License)
**Required:** MPL-2.0 for GNAT ecosystem compatibility

## Related Projects

- **mustfile** (`_pathroot`): Global authority specification
- **nicaug**: Nickel-augmented configuration engine
- **mustorch**: Rust orchestrator for multi-platform deployment

## Links

- **Repository:** https://github.com/hyperpolymath/must
- **Container:** ghcr.io/hyperpolymath/must:latest
- **Issues:** https://github.com/hyperpolymath/must/issues
