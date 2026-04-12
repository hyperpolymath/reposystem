# SPDX-License-Identifier: PMPL-1.0-or-later
# asdf-security-plugin production configuration

{
  # Plugin metadata
  plugin_name | String = "asdf-security-plugin",
  plugin_type | [| 'ui, 'security, 'metaiconic |] = 'security,
  description | String = "ReScript+Bun security plugin with CVE scanning, VirusTotal, and provenance tracking",

  # Tags for categorization
  tags | Array String = [
    "security",
    "cve",
    "virustotal",
    "provenance",
    "audit",
    "licensing"
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
    port | Number = 844,
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
      allow_external_connect | Array String = [
        "https://cve.mitre.org",
        "https://nvd.nist.gov",
        "https://www.virustotal.com"
      ],
      allow_unsafe_eval | Bool = false,
    } = {},
    hsts_max_age | Number = 31536000,
    x_frame_options | [| 'deny, 'sameorigin |] = 'deny,
  } = {},

  # Security features configuration
  features | {
    cve_scanning | {
      enabled | Bool = true,
      sources | Array String = ["NVD", "MITRE", "OSV"],
      severity_threshold | [| 'critical, 'high, 'medium, 'low |] = 'medium,
      auto_update_db | Bool = true,
    } = {},
    virustotal | {
      enabled | Bool = true,
      api_key_required | Bool = true,
      scan_downloads | Bool = true,
      hash_types | Array String = ["sha256", "sha1", "md5"],
    } = {},
    provenance | {
      enabled | Bool = true,
      track_downloads | Bool = true,
      verify_signatures | Bool = true,
      slsa_level | Number = 3,
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
    runtime | String = "Bun",
    plugin_logic | String = "ReScript",
    api_framework | String = "Hono",
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
      "uninstall"
    ],
    custom_commands | Array String = [
      "scan",
      "check-cve",
      "verify-provenance"
    ],
  } = {},

  # Generated artefacts
  artefacts | Array String = [
    "wrangler.toml",
    "_routes.json",
    "_headers",
    "asdf-security-plugin.container",
    "docs/security.adoc",
    "docs/api.adoc",
    "docs/cve-scanning.adoc"
  ],
}
