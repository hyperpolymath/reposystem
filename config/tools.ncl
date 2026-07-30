# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# tools.ncl — the reposystem "super power collection" registry.
#
# One typed record per tool: what it does, whether it is embedded in the cockpit
# (curated core) or extracted to a standalone repo (referenced by repos.toml),
# and its role in the representation → visualisation → tools-as-interface →
# control-surface → interop stack. Consumed by the importer to stamp
# metadata.tool_role / metadata.actions onto tool nodes (feeds the cockpit view).
#
# Validate: nickel typecheck config/tools.ncl
# Export:   nickel export config/tools.ncl --format json

let Embed = [| 'core, 'standalone |] in
let Role =
  [| 'representation, 'visualisation, 'tools_as_interface, 'control_surface, 'interop, 'utility |]
in
# 'active     — embedded core component, in use
# 'extracting — declared standalone but still vendored as an embedded tree; gitlink extraction pending
# 'extracted  — now a real gitlink submodule (declared in .gitmodules)
# 'broken     — declared a submodule but committed as a tree (wiring mismatch)
# 'orphan     — gitlink with no .gitmodules URL and no forge repo
let Status = [| 'active, 'extracting, 'extracted, 'broken, 'orphan |] in
let Tool = {
  id | String,
  name | String,
  role | Role,
  embed | Embed,
  repo_ref | String | optional, # manifest id when standalone
  summary | String,
  actions | Array String | default = [],
  status | Status | default = 'active,
}
in
{
  tools | Array Tool = [
    # ---- Curated core (embedded in the cockpit) -----------------------------
    {
      id = "forge-ops",
      name = "ForgeOps",
      role = 'control_surface,
      embed = 'core,
      summary = "Multi-forge desktop control surface (Tauri): tokens, repos, branch protection, webhooks, mirrors, compliance.",
      actions = ["list-repos", "protect-branch", "create-webhook", "sync-mirror", "compliance-check"],
    },
    {
      id = "dispatcher",
      name = "Git Dispatcher",
      role = 'control_surface,
      embed = 'core,
      summary = "Execution engine that runs reposystem plans across the estate.",
      actions = ["dispatch-plan", "status"],
    },
    {
      id = "web",
      name = "Web HUD",
      role = 'visualisation,
      embed = 'core,
      summary = "Static estate canvas: railway-yard graph, estate scoping, external seams, annotations, ER mode.",
      actions = ["render", "annotate", "export-svg"],
    },
    {
      id = "tui",
      name = "TUI",
      role = 'visualisation,
      embed = 'core,
      summary = "Terminal explorer for the estate graph (ratatui).",
      actions = ["explore", "filter"],
    },
    {
      id = "gui",
      name = "Desktop GUI",
      role = 'visualisation,
      embed = 'core,
      summary = "ReScript + Gossamer desktop cockpit consuming the estate-export envelope.",
      actions = ["render", "act-on-node"],
    },

    # ---- Extracted → standalone (referenced via repos.toml) -----------------
    {
      id = "git-morph",
      name = "git-morph",
      role = 'utility,
      embed = 'standalone,
      repo_ref = "git-morph",
      summary = "Inflate/deflate components between standalone repos and the monorepo. Still vendored as an embedded tree in reposystem; gitlink extraction pending.",
      status = 'extracting,
      actions = ["inflate", "deflate", "detect"],
    },
    {
      id = "git-seo",
      name = "git-seo",
      role = 'utility,
      embed = 'standalone,
      repo_ref = "git-seo",
      summary = "Repository discoverability / SEO scoring (Julia). Still vendored as an embedded tree in reposystem; gitlink extraction pending.",
      status = 'extracting,
      actions = ["score"],
    },
    {
      id = "git-reticulator",
      name = "git-reticulator",
      role = 'utility,
      embed = 'standalone,
      repo_ref = "git-reticulator",
      summary = "Submodule / gitlink reticulation across the estate.",
      status = 'extracted,
      actions = ["reticulate"],
    },
    {
      id = "scaffoldia",
      name = "scaffoldia",
      role = 'utility,
      embed = 'standalone,
      repo_ref = "scaffoldia",
      summary = "Repository generator / customiser (trainyard topology).",
      status = 'extracted,
      actions = ["new-repo", "customise"],
    },
    {
      id = "bitfuckit",
      name = "bitfuckit",
      role = 'utility,
      embed = 'standalone,
      repo_ref = "bitfuckit",
      summary = "Ada/SPARK repository auditor (health, compliance, security posture).",
      status = 'extracted,
      actions = ["audit"],
    },
    {
      id = "contractiles",
      name = "contractiles",
      role = 'utility,
      embed = 'standalone,
      repo_ref = "contractiles",
      summary = "Declarative build/task contracts (ADJUST/INTENT/MUST/TRUST).",
      status = 'extracted,
      actions = ["run-contract"],
    },
    {
      id = "recon-silly-ation",
      name = "recon-silly-ation",
      role = 'interop,
      embed = 'standalone,
      repo_ref = "recon-silly-ation",
      summary = "WASM document reconciliation (ReconForth VM).",
      status = 'extracted,
      actions = ["reconcile"],
    },
    {
      id = "stateful-artefacts",
      name = "stateful-artefacts",
      role = 'interop,
      embed = 'standalone,
      repo_ref = "stateful-artefacts",
      summary = "Forge artefact hydration / consensus state (Paxos, DAX).",
      status = 'extracted,
      actions = ["hydrate"],
    },
    {
      id = "rpa-elysium",
      name = "rpa-elysium",
      role = 'utility,
      embed = 'standalone,
      repo_ref = "rpa-elysium",
      summary = "Robotic process automation engine (workflows, scheduler, plugins).",
      status = 'extracted,
      actions = ["run-workflow"],
    },
    # NOTE: the orphan gitlinks avatar-fabrication-facility and claim-forge
    # (no .gitmodules URL, no forge repo) were removed in PR #130 (f0586e8);
    # their registry records are dropped accordingly.
  ],
}
