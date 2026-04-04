// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! VeriSimDB client for reposystem.
//!
//! Reposystem historically persisted all state to five flat JSON files:
//!
//! | File         | Content                               | VeriSimDB collection        |
//! |--------------|---------------------------------------|-----------------------------|
//! | graph.json   | Repos, edges, groups                  | `reposystem:graph`          |
//! | aspects.json | Aspect definitions + annotations      | `reposystem:aspects`        |
//! | slots.json   | Slots, providers, bindings            | `reposystem:slots`          |
//! | plans.json   | Scenario plans                        | `reposystem:plans`          |
//! | audit.json   | Audit log entries                     | `reposystem:audit`          |
//!
//! This module provides a [`VeriSimDbClient`] that:
//! 1. On every `save()` call, serialises each store and PUTs it to VeriSimDB.
//! 2. On `load()`, attempts to read from VeriSimDB first; falls back to the
//!    flat JSON files when VeriSimDB is unreachable (`VERISIMDB_URL` not set
//!    or server offline).
//!
//! # Environment
//!
//! - `VERISIMDB_URL` — base URL (default: `http://localhost:8080`)
//!
//! # Collection layout
//!
//! Each collection holds a single document keyed `"snapshot"` containing the
//! full serialised store. This matches the existing file-per-store model while
//! keeping VeriSimDB queries simple.  Individual repo/edge/aspect records are
//! also upserted under their own IDs in the same collection for fine-grained
//! queries.
//!
//! ```
//! reposystem:graph/snapshot       — full GraphStore JSON
//! reposystem:graph/{repo_id}      — individual Repo record
//! reposystem:graph/edge:{edge_id} — individual Edge record
//!
//! reposystem:aspects/snapshot     — full AspectStore JSON
//! reposystem:slots/snapshot       — full SlotStore JSON
//! reposystem:plans/snapshot       — full PlanStore JSON
//! reposystem:audit/snapshot       — full AuditStore JSON
//! ```

use crate::types::{AspectStore, AuditStore, GraphStore, PlanStore, SlotStore};
use anyhow::{Context, Result};
use serde::Serialize;
use tracing::{debug, warn};

/// Name of the environment variable carrying the VeriSimDB base URL.
const VERISIMDB_URL_ENV: &str = "VERISIMDB_URL";

/// Default base URL when the environment variable is not set.
const VERISIMDB_URL_DEFAULT: &str = "http://localhost:8080";

/// VeriSimDB API path prefix.
const API_PREFIX: &str = "/api/v1";

// Collection names — one per former JSON file.
const COL_GRAPH:   &str = "reposystem:graph";
const COL_ASPECTS: &str = "reposystem:aspects";
const COL_SLOTS:   &str = "reposystem:slots";
const COL_PLANS:   &str = "reposystem:plans";
const COL_AUDIT:   &str = "reposystem:audit";

/// Synchronous HTTP client for VeriSimDB.
///
/// Uses `reqwest::blocking` so it can be called from non-async contexts
/// (the reposystem CLI is currently synchronous Tokio via `#[tokio::main]`
/// but commands do not `await` inside async blocks).
pub struct VeriSimDbClient {
    /// Base URL, e.g. `http://localhost:8080`
    base_url: String,
    /// Underlying blocking HTTP client
    client: reqwest::blocking::Client,
}

impl VeriSimDbClient {
    /// Create a new client. Reads `VERISIMDB_URL` from the environment.
    #[must_use]
    pub fn new() -> Self {
        let base_url = std::env::var(VERISIMDB_URL_ENV)
            .unwrap_or_else(|_| VERISIMDB_URL_DEFAULT.to_string());
        let base_url = base_url.trim_end_matches('/').to_string();

        let client = reqwest::blocking::Client::builder()
            .timeout(std::time::Duration::from_secs(5))
            .build()
            .expect("Failed to build HTTP client");

        debug!("[VeriSimDB] base_url={}", base_url);
        Self { base_url, client }
    }

    // ── Internal helpers ──────────────────────────────────────────────────

    /// Build the full URL for a collection / document path.
    fn url(&self, collection: &str, id: &str) -> String {
        format!("{}{}/{}/{}", self.base_url, API_PREFIX, collection, id)
    }

    /// PUT a serialisable document to VeriSimDB.
    /// Returns `Ok(())` on 200/201/204, `Err` on non-2xx or network error.
    fn put<T: Serialize>(&self, collection: &str, id: &str, doc: &T) -> Result<()> {
        let url = self.url(collection, id);
        let response = self
            .client
            .put(&url)
            .json(doc)
            .send()
            .with_context(|| format!("VeriSimDB PUT {url}"))?;

        let status = response.status();
        if status.is_success() {
            debug!("[VeriSimDB] PUT {url} -> {}", status.as_u16());
            Ok(())
        } else {
            let body = response.text().unwrap_or_default();
            anyhow::bail!("VeriSimDB PUT {url} returned {}: {}", status.as_u16(), body);
        }
    }

    /// GET a document from VeriSimDB. Returns `Ok(None)` on 404.
    fn get_raw(&self, collection: &str, id: &str) -> Result<Option<String>> {
        let url = self.url(collection, id);
        let response = self
            .client
            .get(&url)
            .send()
            .with_context(|| format!("VeriSimDB GET {url}"))?;

        let status = response.status();
        if status == reqwest::StatusCode::NOT_FOUND {
            return Ok(None);
        }
        if status.is_success() {
            let body = response
                .text()
                .with_context(|| format!("VeriSimDB GET {url} read body"))?;
            Ok(Some(body))
        } else {
            let body = response.text().unwrap_or_default();
            anyhow::bail!("VeriSimDB GET {url} returned {}: {}", status.as_u16(), body);
        }
    }

    // ── Public persistence API ─────────────────────────────────────────────

    /// Save all five stores to VeriSimDB.
    ///
    /// Each store is saved as a snapshot document plus individual records for
    /// repos and edges (enabling future fine-grained queries).
    ///
    /// Failures are logged as warnings rather than propagated — the flat-file
    /// save in `EcosystemGraph::save()` remains the authoritative on-disk store.
    pub fn save_all(
        &self,
        graph:   &GraphStore,
        aspects: &AspectStore,
        slots:   &SlotStore,
        plans:   &PlanStore,
        audit:   &AuditStore,
    ) {
        // ── graph snapshot ─────────────────────────────────────────────────
        if let Err(e) = self.put(COL_GRAPH, "snapshot", graph) {
            warn!("[VeriSimDB] graph snapshot write failed: {e:#}");
        }

        // Individual repo records
        for repo in &graph.repos {
            if let Err(e) = self.put(COL_GRAPH, &repo.id, repo) {
                warn!("[VeriSimDB] repo {} write failed: {e:#}", repo.id);
            }
        }

        // Individual edge records (prefixed to avoid ID collision with repos)
        for edge in &graph.edges {
            let edge_doc_id = format!("edge:{}", edge.id);
            if let Err(e) = self.put(COL_GRAPH, &edge_doc_id, edge) {
                warn!("[VeriSimDB] edge {} write failed: {e:#}", edge.id);
            }
        }

        // ── aspects snapshot ───────────────────────────────────────────────
        if let Err(e) = self.put(COL_ASPECTS, "snapshot", aspects) {
            warn!("[VeriSimDB] aspects snapshot write failed: {e:#}");
        }

        // ── slots snapshot ─────────────────────────────────────────────────
        if let Err(e) = self.put(COL_SLOTS, "snapshot", slots) {
            warn!("[VeriSimDB] slots snapshot write failed: {e:#}");
        }

        // ── plans snapshot ─────────────────────────────────────────────────
        if let Err(e) = self.put(COL_PLANS, "snapshot", plans) {
            warn!("[VeriSimDB] plans snapshot write failed: {e:#}");
        }

        // ── audit snapshot ─────────────────────────────────────────────────
        if let Err(e) = self.put(COL_AUDIT, "snapshot", audit) {
            warn!("[VeriSimDB] audit snapshot write failed: {e:#}");
        }
    }

    /// Attempt to load `GraphStore` from VeriSimDB (`reposystem:graph/snapshot`).
    ///
    /// Returns `Ok(None)` when VeriSimDB is unavailable or the snapshot is
    /// absent, allowing the caller to fall back to the flat JSON file.
    pub fn load_graph(&self) -> Result<Option<GraphStore>> {
        match self.get_raw(COL_GRAPH, "snapshot") {
            Ok(Some(json)) => {
                let store: GraphStore = serde_json::from_str(&json)
                    .with_context(|| "Failed to parse GraphStore from VeriSimDB")?;
                Ok(Some(store))
            }
            Ok(None) => Ok(None),
            Err(e) => {
                warn!("[VeriSimDB] load_graph failed: {e:#}");
                Ok(None)
            }
        }
    }

    /// Attempt to load `AspectStore` from VeriSimDB.
    pub fn load_aspects(&self) -> Result<Option<AspectStore>> {
        match self.get_raw(COL_ASPECTS, "snapshot") {
            Ok(Some(json)) => {
                let store: AspectStore = serde_json::from_str(&json)
                    .with_context(|| "Failed to parse AspectStore from VeriSimDB")?;
                Ok(Some(store))
            }
            Ok(None) => Ok(None),
            Err(e) => {
                warn!("[VeriSimDB] load_aspects failed: {e:#}");
                Ok(None)
            }
        }
    }

    /// Attempt to load `SlotStore` from VeriSimDB.
    pub fn load_slots(&self) -> Result<Option<SlotStore>> {
        match self.get_raw(COL_SLOTS, "snapshot") {
            Ok(Some(json)) => {
                let store: SlotStore = serde_json::from_str(&json)
                    .with_context(|| "Failed to parse SlotStore from VeriSimDB")?;
                Ok(Some(store))
            }
            Ok(None) => Ok(None),
            Err(e) => {
                warn!("[VeriSimDB] load_slots failed: {e:#}");
                Ok(None)
            }
        }
    }

    /// Attempt to load `PlanStore` from VeriSimDB.
    pub fn load_plans(&self) -> Result<Option<PlanStore>> {
        match self.get_raw(COL_PLANS, "snapshot") {
            Ok(Some(json)) => {
                let store: PlanStore = serde_json::from_str(&json)
                    .with_context(|| "Failed to parse PlanStore from VeriSimDB")?;
                Ok(Some(store))
            }
            Ok(None) => Ok(None),
            Err(e) => {
                warn!("[VeriSimDB] load_plans failed: {e:#}");
                Ok(None)
            }
        }
    }

    /// Attempt to load `AuditStore` from VeriSimDB.
    pub fn load_audit(&self) -> Result<Option<AuditStore>> {
        match self.get_raw(COL_AUDIT, "snapshot") {
            Ok(Some(json)) => {
                let store: AuditStore = serde_json::from_str(&json)
                    .with_context(|| "Failed to parse AuditStore from VeriSimDB")?;
                Ok(Some(store))
            }
            Ok(None) => Ok(None),
            Err(e) => {
                warn!("[VeriSimDB] load_audit failed: {e:#}");
                Ok(None)
            }
        }
    }
}

impl Default for VeriSimDbClient {
    fn default() -> Self {
        Self::new()
    }
}
