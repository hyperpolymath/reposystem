# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
#
# reposystem.ncl - Main Nickel configuration for reposystem
#
# Validate: nickel typecheck config/reposystem.ncl
# Export:   nickel export config/reposystem.ncl --format json

let contracts = import "contracts.ncl" in

{
  # ==========================================================================
  # SCHEMA DEFINITIONS
  # ==========================================================================

  Schema = {
    # Repository configuration
    Repo = {
      id | String,
      path | String,
      name | String,
      kind | [| 'Library, 'Application, 'Service, 'Tool, 'Documentation |],
      channels | { default | String, ..String },
      metadata | { ..String } | optional,
    },

    # Edge (dependency) configuration
    Edge = {
      from | String,
      to | String,
      kind | [| 'Artifact, 'Runtime, 'DevDep, 'Peer, 'Optional |],
      channel | String | default = "default",
      weight | Number | default = 1.0,
    },

    # Group configuration
    Group = {
      id | String,
      name | String,
      repos | Array String,
      color | String | optional,
    },

    # Aspect tag configuration
    AspectTag = {
      id | String,
      name | String,
      color | String,
      description | String | optional,
    },

    # Scenario configuration
    Scenario = {
      id | String,
      name | String,
      base | String | optional,
      changes | Array {
        repo | String,
        field | String,
        value | Dyn,
      },
    },
  },

  # ==========================================================================
  # DEFAULT CONFIGURATION
  # ==========================================================================

  defaults = {
    # Data directory
    data_dir = "${XDG_DATA_HOME:-$HOME/.local/share}/reposystem",

    # Cache directory
    cache_dir = "${XDG_CACHE_HOME:-$HOME/.cache}/reposystem",

    # Config directory
    config_dir = "${XDG_CONFIG_HOME:-$HOME/.config}/reposystem",

    # Default scan paths
    scan_paths = [
      "~/repos",
      "~/projects",
      "~/src",
    ],

    # Graph export settings
    export = {
      dot = {
        rankdir = "LR",
        node_shape = "box",
        edge_style = "solid",
        font = "Helvetica",
        font_size = 12,
      },
      json = {
        pretty = true,
        include_metadata = true,
      },
    },

    # TUI settings
    tui = {
      theme = "dark",
      refresh_rate_ms = 100,
      mouse_enabled = true,
      unicode_borders = true,
    },

    # Aspect colors (for visualization)
    aspect_colors = {
      security = "#ff6b6b",
      reliability = "#4ecdc4",
      performance = "#45b7d1",
      maintainability = "#96ceb4",
      supply_chain = "#dda0dd",
      compliance = "#f39c12",
    },

    # Logging
    log = {
      level = "info",
      format = "pretty",
      file = null,
    },
  },

  # ==========================================================================
  # COOKBOOK RECIPES
  # ==========================================================================

  cookbook = {
    # Recipe: Scan and export ecosystem
    scan_and_export = {
      description = "Scan repositories and export graph",
      steps = [
        { cmd = "reposystem scan ~/repos", desc = "Scan repos" },
        { cmd = "reposystem export --format dot -o ecosystem.dot", desc = "Export DOT" },
        { cmd = "reposystem export --format json -o ecosystem.json", desc = "Export JSON" },
        { cmd = "dot -Tsvg ecosystem.dot -o ecosystem.svg", desc = "Render SVG" },
      ],
    },

    # Recipe: Security audit
    security_audit = {
      description = "Run security-focused analysis",
      steps = [
        { cmd = "reposystem scan --deep ~/repos", desc = "Deep scan" },
        { cmd = "reposystem aspect --filter security", desc = "Filter security" },
        { cmd = "reposystem weak-links --aspect security", desc = "Find weak links" },
        { cmd = "reposystem export --aspect security -o security.dot", desc = "Export" },
      ],
    },

    # Recipe: Compare scenarios
    compare_scenarios = {
      description = "Compare two configuration scenarios",
      steps = [
        { cmd = "reposystem scenario create --name baseline", desc = "Create baseline" },
        { cmd = "reposystem scenario create --name proposed --base baseline", desc = "Create proposed" },
        { cmd = "reposystem scenario modify proposed --switch mylib:external", desc = "Modify" },
        { cmd = "reposystem scenario compare baseline proposed", desc = "Compare" },
      ],
    },

    # Recipe: TortoiseGit integration
    tortoisegit_setup = {
      description = "Set up TortoiseGit integration",
      steps = [
        { cmd = "reposystem config set integrations.tortoisegit.enabled true", desc = "Enable" },
        { cmd = "reposystem config set integrations.tortoisegit.menu_items '[\"scan\", \"view\", \"export\"]'", desc = "Menu items" },
        { cmd = "reposystem integrations install tortoisegit", desc = "Install hooks" },
      ],
    },

    # Recipe: IDE integration
    ide_integration = {
      description = "Set up IDE integration (VSCode, JetBrains)",
      steps = [
        { cmd = "reposystem integrations install vscode", desc = "VSCode extension" },
        { cmd = "reposystem integrations install jetbrains", desc = "JetBrains plugin" },
        { cmd = "reposystem integrations install lsp", desc = "LSP server" },
      ],
    },
  },

  # ==========================================================================
  # VALIDATION FUNCTIONS
  # ==========================================================================

  validate = {
    # Validate a repo configuration
    repo = fun config =>
      config
      |> contracts.Repo,

    # Validate entire ecosystem config
    ecosystem = fun config =>
      let repos_valid = std.array.all (fun r => validate.repo r) config.repos in
      let edges_valid = std.array.all (fun e =>
        std.array.any (fun r => r.id == e.from) config.repos &&
        std.array.any (fun r => r.id == e.to) config.repos
      ) config.edges in
      repos_valid && edges_valid,
  },
}
