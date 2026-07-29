// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
//! Importers that populate the ecosystem graph from external sources.
//!
//! The Rust `types` module is the schema of record (see `spec/DATA-MODEL.adoc`).
//! Importers map external inventories onto that schema — they never define a
//! competing one.

/// Import the estate from the generated `repos.toml` manifest (and the
/// hand-maintained `repos.groups.toml`).
pub mod manifest;
