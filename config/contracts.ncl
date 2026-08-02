# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
#
# contracts.ncl - Nickel contracts for reposystem configuration

{
  # Non-empty string contract
  NonEmptyString = std.contract.from_predicate (fun s =>
    std.is_string s && std.string.length s > 0
  ),

  # Valid ID format (lowercase, alphanumeric, hyphens)
  ValidId = std.contract.from_predicate (fun s =>
    std.is_string s &&
    std.string.length s > 0 &&
    std.string.is_match "^[a-z0-9-]+$" s
  ),

  # Valid path (non-empty, starts with / or ~)
  ValidPath = std.contract.from_predicate (fun s =>
    std.is_string s &&
    std.string.length s > 0 &&
    (std.string.substring 0 1 s == "/" || std.string.substring 0 1 s == "~")
  ),

  # Color hex code
  HexColor = std.contract.from_predicate (fun s =>
    std.is_string s &&
    std.string.is_match "^#[0-9a-fA-F]{6}$" s
  ),

  # Positive number
  PositiveNumber = std.contract.from_predicate (fun n =>
    std.is_number n && n > 0
  ),

  # Weight (0.0 to 1.0)
  Weight = std.contract.from_predicate (fun n =>
    std.is_number n && n >= 0.0 && n <= 1.0
  ),

  # Log level
  LogLevel = [| 'trace, 'debug, 'info, 'warn, 'error |],

  # Export format ('estate = the unified estate-export envelope)
  ExportFormat = [| 'dot, 'json, 'estate, 'yaml, 'toml, 'csv |],

  # Theme
  Theme = [| 'dark, 'light, 'solarized, 'gruvbox, 'nord |],

  # Git forge (mirrors Rust `types::Forge`)
  Forge = [| 'gh, 'gl, 'bb, 'cb, 'sr, 'local |],

  # Repository visibility (mirrors Rust `types::Visibility`)
  Visibility = [| 'public, 'private, 'internal |],

  # Repo kind (legacy GRAPH-STRUCTURE classification; informational only)
  RepoKind = [| 'Library, 'Application, 'Service, 'Tool, 'Documentation, 'Data, 'Config |],

  # Relationship type (mirrors Rust `types::RelationType`). `refersto` is the
  # only relation allowed to target an external seam.
  RelationType = [| 'uses, 'provides, 'extends, 'mirrors, 'replaces, 'refersto |],

  # Edge channel (mirrors Rust `types::Channel`)
  Channel = [| 'api, 'artifact, 'config, 'runtime, 'human, 'unknown |],

  # External seam domain (mirrors Rust `types::SeamDomain`)
  SeamDomain = [| 'network, 'machine, 'service, 'org, 'other |],

  # Full repo contract
  Repo = {
    id | ValidId,
    path | ValidPath,
    name | NonEmptyString,
    kind | RepoKind,
    estate | String | default = "estate:hyperpolymath",
    channels | { default | String, ..String },
    metadata | { ..String } | optional,
  },

  # Full edge contract (mirrors Rust `types::Edge`)
  Edge = {
    from | ValidId,
    to | ValidId,
    rel | RelationType,
    channel | Channel | default = 'unknown,
    label | String | optional,
  },

  # Estate identity (multi-estate parameterisation; hyperpolymath = #1)
  Estate = {
    id | String,
    name | NonEmptyString,
    forges | Array Forge | default = [],
    root_owner | String | optional,
  },

  # External seam: a loose outward pointer to a sibling system (aerie =
  # networks, ambientops = machines). Seams are edge sinks; reposystem stores
  # none of the sibling system's internals.
  Seam = {
    id | String,
    system | NonEmptyString,
    domain | SeamDomain,
    name | NonEmptyString,
    uri | String | optional,
    estate | String | default = "estate:hyperpolymath",
  },

  # Ecosystem contract
  Ecosystem = {
    version | String | default = "1.0",
    estate | String | default = "estate:hyperpolymath",
    estates | Array Estate | default = [],
    repos | Array Repo,
    seams | Array Seam | default = [],
    edges | Array Edge,
    groups | Array {
      id | ValidId,
      name | NonEmptyString,
      repos | Array ValidId,
      color | HexColor | optional,
    } | default = [],
    aspects | Array {
      id | ValidId,
      name | NonEmptyString,
      color | HexColor,
      description | String | optional,
    } | default = [],
  },
}
