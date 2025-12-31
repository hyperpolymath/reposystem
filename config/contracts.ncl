# SPDX-License-Identifier: AGPL-3.0-or-later
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

  # Export format
  ExportFormat = [| 'dot, 'json, 'yaml, 'toml, 'csv |],

  # Theme
  Theme = [| 'dark, 'light, 'solarized, 'gruvbox, 'nord |],

  # Repo kind
  RepoKind = [| 'Library, 'Application, 'Service, 'Tool, 'Documentation, 'Data, 'Config |],

  # Edge kind
  EdgeKind = [| 'Artifact, 'Runtime, 'DevDep, 'Peer, 'Optional, 'Build, 'Test |],

  # Full repo contract
  Repo = {
    id | ValidId,
    path | ValidPath,
    name | NonEmptyString,
    kind | RepoKind,
    channels | { default | String, ..String },
    metadata | { ..String } | optional,
  },

  # Full edge contract
  Edge = {
    from | ValidId,
    to | ValidId,
    kind | EdgeKind,
    channel | String | default = "default",
    weight | Weight | default = 1.0,
  },

  # Ecosystem contract
  Ecosystem = {
    version | String | default = "1.0",
    repos | Array Repo,
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
