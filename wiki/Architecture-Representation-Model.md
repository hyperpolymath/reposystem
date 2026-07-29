<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Architecture / Representation Model

This is the deep reference for reposystem's canonical schema — the one representation that every front-end renders. If a fact about the data model is in dispute, the answer is whatever `src/lib.rs` says.

Reposystem is the estate cockpit: a single canonical representation of a repo/forge estate (the hyperpolymath org, "estate #1"), rendered by converged front-ends. The mental model is a railway yard — repos are yards, slots are needs, providers are offers, edges are tracks, switches are points, with aspect overlays. This page documents the types that encode that model.

See also: [Estate / Submodule Layout](Estate-Submodule-Layout), [Tool Registry](Tool-Registry), [Getting Started](Getting-Started).

---

## 1. The single schema of record

The Rust `types` module in `src/lib.rs` is the **schema of record**. Everything else mirrors it:

- `spec/DATA-MODEL.adoc` is documentation that tracks the Rust types (it says so in its own opening `[IMPORTANT]` block).
- `repos.toml` is the generated estate **inventory**, not a competing schema — it is imported into the graph via `reposystem import manifest`.
- The legacy `graph.toml` / `GRAPH-STRUCTURE.md` design is explicitly **superseded**; its old fields survive only as free-form strings inside a repo's `metadata` map (see `Repo::metadata` doc comment: `phase`, `completion_percentage`, `seo_score`, `health_score`, `tech_stack`, …).

Why the Rust types win: the model used to be described in several places that could drift apart (a TOML graph file, a markdown structure doc, the inventory). Promoting one strongly-typed, `serde`-backed module to "schema of record" means IDs, enum spellings, and serialization are defined exactly once, and `DATA-MODEL.adoc` + the Nickel contracts in `config/` are downstream mirrors rather than independent truths.

The non-negotiable invariants the model is built around (from `spec/DATA-MODEL.adoc`): **stable IDs** (deterministic across imports), **explainability** (non-manual tags carry evidence), **scenario isolation** (scenarios reference the baseline, never mutate it), **reversibility** (changes expressible as small deltas), and **UI-agnostic** (layout is optional metadata, not structure).

---

## 2. The type catalogue

All names below are verified against `src/lib.rs`. Field names are the Rust field identifiers; `#[serde(rename …)]` differences are called out where they matter.

### Forge

`enum Forge` — `#[serde(rename_all = "lowercase")]`, with explicit per-variant short codes:

| Variant | serde code | `code()` |
|---|---|---|
| `GitHub` | `gh` | `gh` |
| `GitLab` | `gl` | `gl` |
| `Bitbucket` | `bb` | `bb` |
| `Codeberg` | `cb` | `cb` |
| `Sourcehut` | `sr` | `sr` |
| `Local` | `local` | `local` |

`Forge::from_url` maps known forge hostnames (github.com, gitlab.com, bitbucket.org, codeberg.org, sr.ht / git.sr.ht) to the variant, returning `None` otherwise.

### Estate (tenant identity)

`struct Estate` carries `kind`, `id`, `name`, `description: Option<String>`, `forges: Vec<Forge>`, `root_owner: Option<String>`. IDs are `estate:<slug>` (`Estate::id_for`). `default_estate()` returns `"estate:hyperpolymath"` — hyperpolymath is estate #1, and the model is parameterised so other estates can be added later without changing any node IDs.

### Repo (node subtype) — `+estate`, `+metadata`

`struct Repo` fields: `kind`, `id`, `forge: Forge`, `owner`, `name`, `default_branch`, `visibility: Visibility`, `tags: Vec<String>`, plus the two fields that make the model multi-estate and migration-friendly:

- `estate: String` — `#[serde(default = "default_estate")]`, so older data without the field still loads as hyperpolymath.
- `metadata: HashMap<String, String>` — free-form. This is where superseded `graph.toml` fields and tool-registry stamps live (`tool_role`, `actions`).

Also `imports: ImportMeta` (`source`, `path_hint: Option<PathBuf>`, `imported_at`) and `local_path: Option<PathBuf>` which is `#[serde(skip)]` (runtime-only, never persisted).

IDs are deterministic: `Repo::forge_id` produces `repo:<forge_code>:<owner>/<name>`; `Repo::local_id` hashes the canonicalised path with SHA-256 and emits `repo:local:<first-12-hex>`.

`enum Visibility` — `Public`, `Private`, `Internal` (lowercase serde).

### Group (cluster) — `+members`

`struct Group`: `kind`, `id` (`group:<name>`), `name`, `description: Option<String>`, `members: Vec<String>` (repo IDs; a repo may belong to multiple groups). Note: in the importer's output a group's `description` is set to `None` and `members` are resolved from repo *names* to IDs.

### ExternalSeam / SeamDomain (the repos-only boundary)

Reposystem models repos and forges only. Sibling systems appear as **external seams** — boundary nodes the estate points at, storing none of those systems' internals.

`enum SeamDomain` (lowercase serde): `Network`, `Machine`, `Service`, `Org`, `Other`.

`struct ExternalSeam`: `kind`, `id` (`seam:<system>:<slug>` via `ExternalSeam::seam_id`), `domain: SeamDomain`, `system`, `name`, `uri: Option<String>`, `description: Option<String>`, `estate` (defaults to `default_estate`). Per `src/importers/manifest.rs`, `aerie` → `SeamDomain::Network` and `ambientops` → `SeamDomain::Machine`.

### Edge + RelationType + Channel + seam-as-sink validation

`struct Edge`: `kind`, `id`, `from`, `to`, `rel: RelationType`, `channel: Channel`, `label: Option<String>`, `evidence: Vec<Evidence>`, `meta: EdgeMeta`. Edge IDs are content-hashes: `Edge::generate_id` SHA-256s `(from, to, rel, channel, label)` and emits `edge:<first-8-hex>`.

`enum RelationType` (lowercase serde):

| Variant | serde | Meaning |
|---|---|---|
| `Uses` | `uses` | A depends on B |
| `Provides` | `provides` | A implements interface for B |
| `Extends` | `extends` | A builds on B |
| `Mirrors` | `mirrors` | A is a mirror/fork of B |
| `Replaces` | `replaces` | A can substitute for B |
| `RefersTo` | `refersto` | A points at an external seam |

`enum Channel` (lowercase serde): `Api`, `Artifact`, `Config`, `Runtime`, `Human`, `Unknown` — the "no hidden channels" surface.

**Seams are edge sinks.** This is enforced in code, not just documented. `EcosystemGraph::add_edge` (in `src/graph.rs`) bails when:

```rust
if Self::is_seam_id(&edge.from) {
    anyhow::bail!("external seam {} cannot be an edge source", edge.from);
}
if Self::is_seam_id(&edge.to) && edge.rel != RelationType::RefersTo {
    anyhow::bail!(
        "edges targeting external seam {} must use rel=refers-to",
        edge.to
    );
}
```

`is_seam_id` is simply `id.starts_with("seam:")`. So a seam can never originate a structural edge, and the only relation allowed to *target* a seam is `RefersTo`.

### Aspects (overlays, not structure)

`struct Aspect` (`kind`, `id`, `name`, `description`) with ten curated defaults from `Aspect::defaults()`: `security`, `reliability`, `maintainability`, `portability`, `performance`, `observability`, `ux`, `docs`, `supply-chain`, `automation`. Annotations (`struct AspectAnnotation`) carry `weight: u8` (0–3), `polarity: Polarity` (`Risk` / `Strength` / `Neutral`), `reason`, `evidence`, and an `AnnotationSource`. They target a node **or** an edge ID — overlays on top of the graph, never part of its structure.

### Slots, Providers, Bindings (the f2 swap mechanism)

`struct Slot` (id `slot:<category>.<name>`), `struct Provider` (id `provider:<slot_id>:<name>`, `provider_type: ProviderType` ∈ `Local`/`Ecosystem`/`External`/`Stub`), and `struct SlotBinding` (id `binding:<consumer>:<slot>`, `mode: BindingMode` ∈ `Manual`/`Auto`/`Scenario`/`Default`). `SlotStore::check_compatibility` returns a `CompatibilityResult` checking interface-version match and required-capability coverage.

### The five stores

The runtime container is `EcosystemGraph` (`src/graph.rs`), which holds a `petgraph` `DiGraph` for algorithms plus five serializable stores:

| Store | Field on `EcosystemGraph` | Holds | JSON file |
|---|---|---|---|
| `GraphStore` | `store` | `repos`, `components`, `groups`, `edges`, `scenarios`, `changesets`, `estates`, `estate` (current id), `seams` | `graph.json` |
| `AspectStore` | `aspects` | `aspects`, `annotations` | `aspects.json` |
| `SlotStore` | `slots` | `slots`, `providers`, `bindings` | `slots.json` |
| `PlanStore` | `plans` | `plans`, `diffs` | `plans.json` |
| `AuditStore` | `audit` | `entries` | `audit.json` |

`rebuild_graph()` populates the `petgraph` from the store: it adds every repo **and** every seam as a node, then adds edges only when both endpoints resolve — so the seam sinks participate in the graph as valid edge targets.

---

## 3. The estate-export envelope

There is one interchange artifact every front-end (web HUD, GUI, TUI, exporters) consumes: the unified envelope. It is produced by `EcosystemGraph::to_estate_export()` in `src/graph.rs`. Verified from the serializer, the JSON object has these top-level keys, in this order:

```json
{
  "schema": "reposystem/estate-export@1",
  "estate": { ... },
  "estates": [ ... ],
  "repos": [ ... ],
  "components": [ ... ],
  "seams": [ ... ],
  "groups": [ ... ],
  "edges": [ ... ],
  "scenarios": [ ... ],
  "aspects": [ ... ],
  "annotations": [ ... ],
  "slots": [ ... ],
  "providers": [ ... ],
  "bindings": [ ... ],
  "plans": [ ... ]
}
```

The schema id is the string literal `"reposystem/estate-export@1"`. The `estate` key is the *current* estate (resolved from `store.estate`, falling back to `default_estate()`, then to the first known estate); `estates` is the full set. The envelope is a strict superset of `GraphStore` — one serializer, many transports.

This is emitted by `reposystem export` in the `estate-json` format. `src/commands/export.rs` defines `ExportFormat::from_str`, which accepts `estate-json` (alias `estate`) for the envelope, `dot` (alias `graphviz`) for Graphviz output via `to_dot()`, and `json` for the bare `GraphStore`. `yaml` and `toml` are recognised as format names but currently `bail!` as not-yet-implemented. The graph is loaded from the data dir (overridable via the `REPOSYSTEM_DATA_DIR` env var; otherwise an OS-specific project data dir).

The `to_dot()` serializer (also in `src/graph.rs`) renders repos as boxes, groups as dashed subgraph clusters, seams as dashed `note` nodes, slots as diamonds, providers as hexagons, and bindings as bold consumer→provider edges.

---

## 4. The manifest importer bridge

`src/importers/manifest.rs` is the bridge from the real estate inventory into the `GraphStore`. It reads `repos.toml` (and the optional, hand-maintained `repos.groups.toml`) and populates a fresh `EcosystemGraph`. Invoked via `reposystem import manifest`. (For the verified declared count of ~297 repos, see [Estate / Submodule Layout](Estate-Submodule-Layout) and [Getting Started](Getting-Started).)

How it maps inventory to schema:

- Each `[[repo]]` entry becomes a `Repo`. The forge is inferred from the entry's `url` via `Forge::from_url` (falling back to `Forge::Local`); the owner/name are parsed from the URL. The ID is `Repo::forge_id(...)` for forge-hosted repos, or `repo:local:<name>` for local ones.
- Every imported repo is stamped with the import's `estate_id` (default `estate:hyperpolymath`) and an `imports.source` of `"manifest:repos.toml"`. The entry's `kind` and `path` are preserved in `metadata` as `manifest_kind` / `manifest_path`.
- **Seam promotion**: entries whose basename matches `DEFAULT_SEAM_SYSTEMS` — `("aerie", Network)` and `("ambientops", Machine)` — are promoted to `ExternalSeam` nodes instead of repos, enforcing the strict repos-only boundary. `seam_match` matches on the basename, so a group-prefixed name like `systems-ecosystem/ambientops` still resolves to the `ambientops` seam.
- Groups from `repos.groups.toml` resolve member repo *names* to IDs and become `Group` nodes.
- The resulting `Estate` is stamped with the forges actually observed during the import (`seen_forges`), and `store.estate` is set to the import's estate id.

The importer returns an `ImportSummary { repos, seams, groups }` count alongside the populated graph.

---

## 5. The audited Plan → Apply → Rollback flow, and VeriSimDB persistence

### Plans (f3)

A `Plan` is an ordered, reviewable set of `PlanOp`s with an `overall_risk` and a `status`. The operation enum (`#[serde(tag = "op", rename_all = "snake_case")]`) has four variants:

- `SwitchBinding { binding_id, consumer_id, slot_id, from_provider_id, to_provider_id, risk, reason }` — note `from_provider_id` is retained specifically for rollback.
- `CreateBinding { consumer_id, slot_id, provider_id, risk, reason }`
- `RemoveBinding { binding_id, consumer_id, slot_id, provider_id, risk, reason }`
- `FileChange { repo_id, file_path, change_type: FileChangeType, diff, risk }`

`RiskLevel` ∈ `Low`/`Medium`/`High`/`Critical`; `Plan::calculate_overall_risk` takes the max across ops. `PlanStatus` ∈ `Draft`/`Ready`/`Applied`/`RolledBack`/`Cancelled`.

### Rollback as a generated inverse plan

`PlanStore::generate_rollback(plan)` builds a new `Plan` by walking the original ops **in reverse** and inverting each:

- `SwitchBinding` is inverted by swapping `from_provider_id` and `to_provider_id`.
- `CreateBinding` inverts to `RemoveBinding`.
- `RemoveBinding` inverts to `CreateBinding`.
- `FileChange` is currently **skipped** (a `None` in the filter_map; the source comment notes file-change rollback is deferred to f4).

The rollback plan is created in `PlanStatus::Draft` with id `plan:rollback:<original>` and `created_by: "system"`.

### Audit (f4)

Applying a plan records an `AuditEntry` (in `AuditStore`): `plan_id`, an overall `result: ApplyResult` (`Success`/`PartialFailure`/`Failure`/`RolledBack`), per-operation `op_results: Vec<OpResult>`, `started_at`/`finished_at`, `applied_by`, `auto_rollback_triggered`, optional `rollback_plan_id`, optional `health_check_passed`, and `notes`. Helper methods include `success_count`, `failure_count`, `errors`, and `AuditStore::failed_entries`. This is what makes the flow auditable: a plan, the inverse plan that undoes it, and a logged record of what actually happened.

### VeriSimDB persistence

`src/verisimdb.rs` provides `VeriSimDbClient`, which mirrors all five JSON stores to VeriSimDB collections. The collection mapping is one-per-former-file:

| Store / file | Collection |
|---|---|
| `graph.json` | `reposystem:graph` |
| `aspects.json` | `reposystem:aspects` |
| `slots.json` | `reposystem:slots` |
| `plans.json` | `reposystem:plans` |
| `audit.json` | `reposystem:audit` |

Each collection holds a `"snapshot"` document with the full serialised store; the graph collection additionally upserts individual repo records (under their IDs) and edge records (under `edge:<edge_id>`) for fine-grained queries.

Load/save priority is layered. `EcosystemGraph::load` tries VeriSimDB first for each store, falling back to the flat JSON file in the data dir, then to a default empty store. `EcosystemGraph::save` writes the flat JSON files first (the authoritative on-disk copy) and then mirrors to VeriSimDB via `save_all` — and VeriSimDB failures are logged as warnings only, never propagated, so a missing or offline database never blocks a save. The base URL comes from the `VERISIMDB_URL` env var (default `http://localhost:8080`), and the client uses a 5-second-timeout blocking HTTP client under the `/api/v1` path prefix.
