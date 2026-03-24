// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! ForgeOps — Git forge management desktop application.
//!
//! Gossamer-based desktop application. Registers 23 IPC commands for forge
//! operations (token verification, repo listing, settings, mirrors, branch
//! protection, webhooks, pipelines, security, compliance, offline config)
//! via `gossamer_rs::App`.
//!
//! Command logic lives in `src-tauri/src/forgeops/commands.rs` — this file
//! delegates to those functions, wrapping their `Result<String, String>`
//! returns into `Result<serde_json::Value, String>` for Gossamer IPC.

#![forbid(unsafe_code)]

use gossamer_rs::App;
use serde_json::Value;

// Include the existing forgeops module tree from src-tauri/src/
#[path = "../src-tauri/src/forgeops/mod.rs"]
mod forgeops;

use forgeops::commands;

// =============================================================================
// Helper: convert Result<String, String> to Result<Value, String>
// =============================================================================

/// Parse the JSON string returned by a forgeops command into a serde_json::Value.
/// If the command returns Ok(json_string), parse it; if Err, pass through.
fn to_value(result: Result<String, String>) -> Result<Value, String> {
    match result {
        Ok(json_str) => serde_json::from_str(&json_str)
            .map_err(|e| format!("JSON parse error: {}", e)),
        Err(e) => Err(e),
    }
}

// =============================================================================
// Helper: extract string field from JSON payload
// =============================================================================

/// Extract a required string field from the JSON payload, returning an
/// IPC-friendly error string on failure.
fn required_str(payload: &Value, field: &str) -> Result<String, String> {
    payload[field]
        .as_str()
        .map(|s| s.to_string())
        .ok_or_else(|| format!("missing required field: {}", field))
}

// =============================================================================
// Entry point
// =============================================================================

fn main() -> Result<(), gossamer_rs::Error> {
    let mut app = App::new("ForgeOps - Git Forge Manager", 1200, 800)?;

    // =========================================================================
    // Token verification (2 commands)
    // =========================================================================

    app.command("forgeops_verify_tokens", {
        move |_payload| {
            to_value(commands::forgeops_verify_tokens())
        }
    });

    app.command("forgeops_verify_forge_token", {
        move |payload| {
            let forge = required_str(&payload, "forge")?;
            to_value(commands::forgeops_verify_forge_token(forge))
        }
    });

    // =========================================================================
    // Repo listing (2 commands)
    // =========================================================================

    app.command("forgeops_list_repos", {
        move |payload| {
            let forge = required_str(&payload, "forge")?;
            to_value(commands::forgeops_list_repos(forge))
        }
    });

    app.command("forgeops_list_all_repos", {
        move |_payload| {
            to_value(commands::forgeops_list_all_repos())
        }
    });

    // =========================================================================
    // Repo settings (2 commands)
    // =========================================================================

    app.command("forgeops_get_repo_settings", {
        move |payload| {
            let forge = required_str(&payload, "forge")?;
            let repo_name = required_str(&payload, "repo_name")?;
            to_value(commands::forgeops_get_repo_settings(forge, repo_name))
        }
    });

    app.command("forgeops_update_setting", {
        move |payload| {
            let forge = required_str(&payload, "forge")?;
            let repo_name = required_str(&payload, "repo_name")?;
            let setting_id = required_str(&payload, "setting_id")?;
            let value = required_str(&payload, "value")?;
            to_value(commands::forgeops_update_setting(forge, repo_name, setting_id, value))
        }
    });

    // =========================================================================
    // Mirror operations (2 commands)
    // =========================================================================

    app.command("forgeops_get_mirror_status", {
        move |_payload| {
            to_value(commands::forgeops_get_mirror_status())
        }
    });

    app.command("forgeops_force_sync_mirror", {
        move |payload| {
            let repo_name = required_str(&payload, "repo_name")?;
            let target_forge = required_str(&payload, "target_forge")?;
            to_value(commands::forgeops_force_sync_mirror(repo_name, target_forge))
        }
    });

    // =========================================================================
    // Branch protection (2 commands)
    // =========================================================================

    app.command("forgeops_get_protection", {
        move |payload| {
            let forge = required_str(&payload, "forge")?;
            let repo_name = required_str(&payload, "repo_name")?;
            to_value(commands::forgeops_get_protection(forge, repo_name))
        }
    });

    app.command("forgeops_update_protection", {
        move |payload| {
            let forge = required_str(&payload, "forge")?;
            let repo_name = required_str(&payload, "repo_name")?;
            let rules_json = required_str(&payload, "rules_json")?;
            to_value(commands::forgeops_update_protection(forge, repo_name, rules_json))
        }
    });

    // =========================================================================
    // Webhooks (2 commands)
    // =========================================================================

    app.command("forgeops_list_webhooks", {
        move |payload| {
            let forge = required_str(&payload, "forge")?;
            let repo_name = required_str(&payload, "repo_name")?;
            to_value(commands::forgeops_list_webhooks(forge, repo_name))
        }
    });

    app.command("forgeops_delete_webhook", {
        move |payload| {
            let forge = required_str(&payload, "forge")?;
            let repo_name = required_str(&payload, "repo_name")?;
            let webhook_id = required_str(&payload, "webhook_id")?;
            to_value(commands::forgeops_delete_webhook(forge, repo_name, webhook_id))
        }
    });

    // =========================================================================
    // CI/CD Pipelines (1 command)
    // =========================================================================

    app.command("forgeops_list_pipelines", {
        move |payload| {
            let forge = required_str(&payload, "forge")?;
            let repo_name = required_str(&payload, "repo_name")?;
            to_value(commands::forgeops_list_pipelines(forge, repo_name))
        }
    });

    // =========================================================================
    // Security (1 command)
    // =========================================================================

    app.command("forgeops_get_security_alerts", {
        move |payload| {
            let forge = required_str(&payload, "forge")?;
            let repo_name = required_str(&payload, "repo_name")?;
            to_value(commands::forgeops_get_security_alerts(forge, repo_name))
        }
    });

    // =========================================================================
    // Bulk operations (1 command)
    // =========================================================================

    app.command("forgeops_apply_compliance", {
        move |payload| {
            let repo_name = required_str(&payload, "repo_name")?;
            to_value(commands::forgeops_apply_compliance(repo_name))
        }
    });

    // =========================================================================
    // Offline config (1 command)
    // =========================================================================

    app.command("forgeops_download_config", {
        move |payload| {
            let repo_name = required_str(&payload, "repo_name")?;
            to_value(commands::forgeops_download_config(repo_name))
        }
    });

    // =========================================================================
    // Load frontend and run event loop
    // =========================================================================

    app.navigate("http://localhost:1421")?;
    app.run();
    Ok(())
}
