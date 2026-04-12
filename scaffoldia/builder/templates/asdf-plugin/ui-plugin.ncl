# SPDX-License-Identifier: PMPL-1.0-or-later
# asdf-ui-plugin production configuration

{
  # Plugin metadata
  plugin_name | String = "asdf-ui-plugin",
  plugin_type | [| 'ui, 'security, 'metaiconic |] = 'ui,
  description | String = "SvelteKit/Vite dashboard for asdf with RBAC and audit logging",

  # Tags for categorization
  tags | Array String = [
    "ui",
    "security",
    "audit",
    "licensing",
    "provenance"
  ],

  # Deployment configuration
  deploy | {
    target | [| 'cloudflare_pages, 'vercel, 'netlify, 'self_hosted |] = 'cloudflare_pages,
    wrangler_project | String = plugin_name,
    node_fallback | Bool = true,
    podman_quadlet | Bool = true,
  } = {},

  # Service configuration
  service | {
    port | Number = 843,
    persistent | Bool = true,
    health_check | String = "/health",
    restart_policy | [| 'always, 'on_failure, 'unless_stopped |] = 'always,
  } = {},

  # RBAC configuration
  rbac | {
    enabled | Bool = true,
    default_role | [| 'viewer, 'operator, 'admin |] = 'operator,
    alternatives | Array [| 'viewer, 'operator, 'admin |] = ['viewer, 'admin],
    require_auth | Bool = true,
  } = {},

  # Security configuration
  security | {
    csp | [| 'strict, 'moderate, 'permissive |] = 'strict,
    downgrade | {
      allow_inline_styles | Bool = false,
      allow_external_connect | Array String = [],
      allow_unsafe_eval | Bool = false,
    } = {},
    hsts_max_age | Number = 31536000,
    x_frame_options | [| 'deny, 'sameorigin |] = 'deny,
  } = {},

  # License configuration
  license | {
    primary | String = "PMPL-1.0-or-later",
    secondary | String = "Palimpsest",
    canonical | String = "https://gitlab.com/hyperpolymath/palimpsest-license",
  } = {},

  # Stack configuration
  stack | {
    ui_framework | String = "SvelteKit",
    build_tool | String = "Vite",
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
      "list-bin-paths",
      "exec-env",
      "uninstall",
      "post-plugin-add",
      "post-plugin-update",
      "pre-plugin-remove"
    ],
  } = {},

  # Generated artefacts
  artefacts | Array String = [
    "wrangler.toml",
    "_routes.json",
    "_headers",
    "asdf-ui-plugin.container",
    "docs/usage.adoc",
    "docs/api.adoc"
  ],
}
