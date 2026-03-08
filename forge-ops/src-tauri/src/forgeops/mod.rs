// SPDX-License-Identifier: PMPL-1.0-or-later

//! ForgeOps — Git forge management module (GitHub, GitLab, Bitbucket).
//!
//! Provides Tauri command handlers for interacting with the three forge APIs:
//! - GitHub REST API v3 + GraphQL v4
//! - GitLab REST API v4
//! - Bitbucket REST API 2.0
//!
//! Operations: repo listing, settings management, mirror sync, branch protection,
//! webhooks, CI/CD status, secrets audit, security scanning, RSR compliance,
//! cross-forge diff, and offline config.
//!
//! Credentials stored via OS keyring (Tauri) or environment variables (CLI/CI):
//! - `GITHUB_TOKEN`, `GITLAB_TOKEN`, `BITBUCKET_TOKEN` + `BITBUCKET_USER`
//!
//! Config cache at `~/.config/forgeops/`

pub mod api;
pub mod commands;
pub mod config;
pub mod diff;
pub mod mirror;
pub mod types;
