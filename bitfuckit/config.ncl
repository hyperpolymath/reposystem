# SPDX-License-Identifier: PMPL-1.0
# Nickel configuration for bitfuckit
#
# Cookbook - Common Configuration Patterns:
#
# 1. Development Build:
#    just build
#    # Uses: build.commands.build
#
# 2. Release Build:
#    just build-release
#    # Uses: build.commands.release with optimizations
#
# 3. Full Installation:
#    just install-full
#    # Installs: binary, completions, man page
#
# 4. Forge Mirror Sync:
#    just forge-all
#    # Syncs to all forges listed in forges.targets
#
# 5. Package Build:
#    just package-arch
#    # Uses: package.aur configuration
#
# 6. CI Pipeline:
#    just ci
#    # Runs: clean → verify → build-release → test-all

{
  # ============================================================================
  # Project Metadata
  # ============================================================================
  project = {
    name = "bitfuckit",
    version = "0.1.0",
    language = "ada",
    license = "PMPL-1.0",
    description = "Bitbucket CLI tool - the one Atlassian didn't make",
    homepage = "https://github.com/hyperpolymath/bitfuckit",
    repository = "https://github.com/hyperpolymath/bitfuckit",

    # Classification
    keywords = ["bitbucket", "cli", "ada", "spark", "git", "forge"],
    categories = ["Development Tools", "Version Control", "CLI"],
  },

  # ============================================================================
  # Build Configuration
  # ============================================================================
  build = {
    system = "gprbuild",
    project_file = "bitfuckit.gpr",
    output_dir = "bin",
    binary = "bitfuckit",

    # Build modes with associated flags
    modes = {
      development = {
        flags = "-g -gnata",
        description = "Debug build with assertions",
      },
      release = {
        flags = "-O2 -gnatn",
        description = "Optimized release build",
      },
      spark = {
        flags = "-gnata -gnatVa",
        description = "SPARK verification mode",
      },
    },

    # Command recipes (concatenative pattern)
    commands = {
      build = "gprbuild -P bitfuckit.gpr",
      clean = "gprclean -P bitfuckit.gpr",
      release = "gprbuild -P bitfuckit.gpr -XBUILD_MODE=release",
      verify = "gnatprove -P bitfuckit.gpr --mode=check",
      prove = "gnatprove -P bitfuckit.gpr --mode=prove --level=2",
    },
  },

  # ============================================================================
  # Installation Paths
  # ============================================================================
  install = {
    # User-level installation
    user = {
      bin = "~/.local/bin",
      man = "~/.local/share/man/man1",
      completions = {
        bash = "~/.local/share/bash-completion/completions",
        zsh = "~/.local/share/zsh/site-functions",
        fish = "~/.config/fish/completions",
      },
    },

    # System-level installation
    system = {
      bin = "/usr/local/bin",
      man = "/usr/share/man/man1",
      completions = {
        bash = "/usr/share/bash-completion/completions",
        zsh = "/usr/share/zsh/site-functions",
        fish = "/usr/share/fish/vendor_completions.d",
      },
    },
  },

  # ============================================================================
  # Dependencies
  # ============================================================================
  dependencies = {
    build = [
      { name = "gnat", version = ">= 12", description = "GNAT Ada compiler" },
      { name = "gprbuild", version = ">= 22", description = "GPR build system" },
    ],
    runtime = [
      { name = "curl", version = ">= 7", description = "HTTP client" },
    ],
    optional = [
      { name = "gnatprove", version = ">= 24", description = "SPARK prover", for = "verification" },
    ],
  },

  # ============================================================================
  # Platform Support Matrix
  # ============================================================================
  platforms = {
    linux_x86_64 = {
      supported = true,
      tested = true,
      primary = true,
      notes = "Primary development platform",
    },
    linux_aarch64 = {
      supported = true,
      tested = false,
      notes = "Awaiting CI infrastructure",
    },
    macos_intel = {
      supported = true,
      tested = false,
      notes = "Requires Homebrew GNAT",
    },
    macos_arm = {
      supported = false,
      tested = false,
      notes = "Awaiting GNAT Apple Silicon support",
    },
    windows = {
      supported = false,
      tested = false,
      notes = "Planned for v1.0",
    },
  },

  # ============================================================================
  # Forge Configuration (Multi-forge mirroring)
  # ============================================================================
  forges = {
    # Target forges for mirroring
    targets = [
      { name = "github", url = "github.com", enabled = true, primary = true },
      { name = "gitlab", url = "gitlab.com", enabled = true },
      { name = "bitbucket", url = "bitbucket.org", enabled = true },
      { name = "codeberg", url = "codeberg.org", enabled = true },
      { name = "sourcehut", url = "git.sr.ht", enabled = true },
      { name = "gitea", url = "gitea.com", enabled = true },
      { name = "disroot", url = "git.disroot.org", enabled = true },
      { name = "radicle", url = "radicle.xyz", enabled = true },
    ],

    # Fallback order when primary is unavailable
    fallback_order = ["gitlab", "codeberg", "sourcehut", "bitbucket"],
  },

  # ============================================================================
  # Package Configuration
  # ============================================================================
  package = {
    formats = ["aur", "rpm", "deb", "homebrew", "nix", "macports", "winget"],

    aur = {
      name = "bitfuckit",
      pkgver = "0.1.0",
      pkgrel = 1,
      arch = ["x86_64", "aarch64"],
      license = "PMPL-1.0",
      depends = ["curl"],
      makedepends = ["gcc-ada", "gprbuild"],
      source = "https://github.com/hyperpolymath/bitfuckit/archive/v\${pkgver}.tar.gz",
    },

    rpm = {
      name = "bitfuckit",
      version = "0.1.0",
      release = 1,
      requires = ["curl"],
      build_requires = ["gcc-gnat", "gprbuild"],
    },

    deb = {
      name = "bitfuckit",
      version = "0.1.0",
      section = "devel",
      priority = "optional",
      depends = ["curl"],
      build_depends = ["gnat", "gprbuild"],
    },

    homebrew = {
      name = "bitfuckit",
      description = "Bitbucket CLI tool written in Ada",
      homepage = "https://github.com/hyperpolymath/bitfuckit",
      head = "https://github.com/hyperpolymath/bitfuckit.git",
      depends = ["gcc", "gprbuild"],
    },

    macports = {
      name = "bitfuckit",
      version = "0.1.0",
      categories = ["devel", "vcs"],
      platforms = "darwin",
      depends = ["curl"],
    },

    winget = {
      id = "hyperpolymath.bitfuckit",
      name = "bitfuckit",
      version = "0.1.0",
      publisher = "hyperpolymath",
      license = "PMPL-1.0",
    },
  },

  # ============================================================================
  # CI/CD Configuration
  # ============================================================================
  ci = {
    pipelines = {
      quick = ["build", "test"],
      full = ["clean", "verify", "build-release", "test-all"],
      security = ["verify", "lint"],
      release = ["ci", "package-all", "mirror-self"],
    },

    required_files = ["README.adoc", "LICENSE", "SECURITY.md", "CONTRIBUTING.adoc"],
  },

  # ============================================================================
  # Feature Flags
  # ============================================================================
  features = {
    graphql_server = {
      enabled = true,
      default_port = 4000,
      playground = true,
    },
    tui = {
      enabled = true,
      vim_keys = true,
      colors = true,
    },
    spark_verification = {
      enabled = true,
      level = 2,
      mode = "check",
    },
  },
}
