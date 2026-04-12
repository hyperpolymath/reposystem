# SPDX-License-Identifier: PMPL-1.0-or-later
# asdf-metaiconic-plugin production configuration

{
  # Plugin metadata
  plugin_name | String = "asdf-metaiconic-plugin",
  plugin_type | [| 'ui, 'security, 'metaiconic |] = 'metaiconic,
  description | String = "Nickel-powered aspect-oriented config plugin for generating deployment artefacts and weaving cross-cutting concerns",

  # Tags for categorization
  tags | Array String = [
    "metaiconic",
    "homoiconic",
    "config",
    "aspects",
    "licensing",
    "provenance"
  ],

  # Deployment configuration
  deploy | {
    target | [| 'cloudflare_pages, 'vercel, 'netlify, 'self_hosted |] = 'cloudflare_pages,
    wrangler_project | String = plugin_name,
    node_fallback | Bool = true,
    podman_quadlet | Bool = false, # CLI-style, no persistent service
  } = {},

  # Service configuration
  service | {
    port | Number = 845,
    persistent | Bool = false, # CLI-style, not a long-running service
    cli_mode | Bool = true,
  } = {},

  # RBAC configuration
  rbac | {
    enabled | Bool = true,
    default_role | [| 'viewer, 'operator, 'admin |] = 'operator,
    alternatives | Array [| 'viewer, 'operator, 'admin |] = ['viewer, 'admin],
    require_auth | Bool = true,
  } = {},

  # Aspects configuration
  aspects | {
    enabled | Array String = [
      "security-hardening",
      "audit-provenance",
      "licensing-palimpsest",
      "provenance-tracker"
    ],
    hooks | {
      pre_startup | Bool = true,
      post_update | Bool = true,
      render_docs | Bool = true,
      inject_headers | Bool = true,
    } = {},
  } = {},

  # Security configuration
  security | {
    csp | [| 'strict, 'moderate, 'permissive |] = 'strict,
    downgrade | {
      allow_inline_styles | Bool = false,
      allow_external_connect | Array String = [],
      allow_unsafe_eval | Bool = false,
    } = {},
  } = {},

  # License configuration
  license | {
    primary | String = "PMPL-1.0-or-later",
    secondary | String = "Palimpsest",
    canonical | String = "https://gitlab.com/hyperpolymath/palimpsest-license",
  } = {},

  # Stack configuration
  stack | {
    config_language | String = "Nickel",
    runtime | String = "Bun",
    plugin_logic | String = "ReScript",
  } = {},

  # asdf plugin requirements
  asdf | {
    required_scripts | Array String = ["list-all", "install", "download"],
    recommended_scripts | Array String = [
      "latest-stable",
      "help.overview",
      "help.deps",
      "help.config",
      "help.links"
    ],
    optional_scripts | Array String = [
      "exec-env"
    ],
    custom_commands | Array String = [
      "inject",
      "export",
      "validate",
      "render"
    ],
  } = {},

  # Generated artefacts (what this plugin generates for other repos)
  artefacts | Array String = [
    "wrangler.toml",
    "_routes.json",
    "_headers",
    "*.container",
    "docs/*.adoc",
    "cfg/profiles/*.ncl",
    "SECURITY.md",
    "LICENSE"
  ],

  # Artefact generation rules
  generation | {
    wrangler | {
      enabled | Bool = true,
      compatibility_date | String = "2026-02-01",
      include_env | Bool = true,
    } = {},
    quadlet | {
      enabled | Bool = true,
      restart_policy | [| 'always, 'on_failure, 'unless_stopped |] = 'always,
      after | Array String = ["network-online.target"],
    } = {},
    headers | {
      csp_strict | Bool = true,
      hsts | Bool = true,
      x_frame_options | [| 'deny, 'sameorigin |] = 'deny,
    } = {},
    docs | {
      format | [| 'asciidoc, 'markdown |] = 'asciidoc,
      include_examples | Bool = true,
      include_api_docs | Bool = true,
    } = {},
  } = {},
}
