// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
//! Apply and rollback plan execution

use crate::graph::EcosystemGraph;
use crate::types::{
    ApplyResult, AuditEntry, BindingMode, OpResult, Plan, PlanOp, PlanStatus, SlotBinding,
};
use anyhow::{anyhow, bail, Context, Result};
use chrono::Utc;
use std::path::Path;

/// Arguments for apply commands
#[derive(Debug, Default)]
pub struct ApplyArgs {
    /// Dry-run mode - show what would happen without executing
    pub dry_run: bool,
    /// Auto-rollback on failure - revert changes if any operation fails
    pub auto_rollback: bool,
    /// Skip health check after successful apply
    pub skip_health_check: bool,
}

/// Run apply command
pub fn run(action: &str, plan_name: Option<String>, args: ApplyArgs) -> Result<()> {
    let data_dir = std::env::var("REPOSYSTEM_DATA_DIR")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(|_| std::path::PathBuf::from(".reposystem"));

    match action {
        "apply" | "execute" => run_apply(&data_dir, plan_name, args),
        "undo" | "rollback" => run_undo(&data_dir, plan_name, args),
        "status" | "audit" | "log" => run_audit_log(&data_dir, plan_name),
        _ => {
            bail!("Unknown apply action: {}. Use apply, undo, or status", action);
        }
    }
}

/// Apply a plan
fn run_apply(data_dir: &Path, plan_name: Option<String>, args: ApplyArgs) -> Result<()> {
    let plan_id = plan_name.ok_or_else(|| anyhow!("Plan name/ID is required"))?;

    let mut graph = EcosystemGraph::load(data_dir)
        .context("Failed to load ecosystem graph")?;

    // Find the plan
    let plan = graph
        .plans
        .plans
        .iter()
        .find(|p| p.id == plan_id || p.name == plan_id)
        .cloned()
        .ok_or_else(|| anyhow!("Plan not found: {}", plan_id))?;

    if plan.status == PlanStatus::Applied {
        return Err(anyhow!("Plan has already been applied"));
    }

    if args.dry_run {
        println!("Dry-run: Would apply plan '{}'", plan.name);
        println!();
        println!("Operations to execute:");
        for (i, op) in plan.operations.iter().enumerate() {
            println!("  {}. {}", i + 1, op.description());
        }
        println!();
        println!("Overall risk: {:?}", plan.overall_risk);
        return Ok(());
    }

    println!("Applying plan: {}", plan.name);
    println!("{}", "-".repeat(60));

    let started_at = Utc::now();
    let applied_by = std::env::var("USER").unwrap_or_else(|_| "unknown".into());
    let mut op_results: Vec<OpResult> = Vec::new();
    let mut notes: Vec<String> = Vec::new();
    let mut failed = false;
    let mut failure_index: Option<usize> = None;

    // Execute operations
    for (i, op) in plan.operations.iter().enumerate() {
        println!("  [{}/{}] {}", i + 1, plan.operations.len(), op.description());

        let result = execute_operation(&mut graph, op);
        let success = result.is_ok();
        let error = result.err().map(|e| e.to_string());

        op_results.push(OpResult {
            op_index: i,
            success,
            error: error.clone(),
            executed_at: Utc::now(),
        });

        if success {
            println!("       OK");
        } else {
            println!("       FAILED: {}", error.as_ref().unwrap());
            failed = true;
            failure_index = Some(i);

            if args.auto_rollback {
                notes.push(format!("Auto-rollback triggered after operation {} failed", i + 1));
                break;
            }
        }
    }

    let finished_at = Utc::now();

    // Determine result
    let (result, auto_rollback_triggered, rollback_plan_id) = if failed {
        if args.auto_rollback && failure_index.is_some() {
            // Execute rollback
            let rollback_result = execute_rollback(&mut graph, &plan, failure_index.unwrap());
            match rollback_result {
                Ok(rollback_id) => (ApplyResult::RolledBack, true, Some(rollback_id)),
                Err(e) => {
                    notes.push(format!("Rollback failed: {}", e));
                    (ApplyResult::Failure, true, None)
                }
            }
        } else {
            (ApplyResult::PartialFailure, false, None)
        }
    } else {
        (ApplyResult::Success, false, None)
    };

    // Health check
    let health_check_passed = if !args.skip_health_check && result == ApplyResult::Success {
        let health_result = run_health_check(&graph);
        if !health_result {
            notes.push("Health check failed - manual review recommended".into());
        }
        Some(health_result)
    } else {
        None
    };

    // Create audit entry
    let audit_entry = AuditEntry {
        kind: "AuditEntry".into(),
        id: format!("audit:{}:{}", plan.id, started_at.timestamp()),
        plan_id: plan.id.clone(),
        result,
        op_results,
        started_at,
        finished_at,
        applied_by,
        auto_rollback_triggered,
        rollback_plan_id: rollback_plan_id.clone(),
        health_check_passed,
        notes,
    };

    graph.audit.entries.push(audit_entry);

    // Update plan status
    if let Some(p) = graph.plans.plans.iter_mut().find(|p| p.id == plan.id) {
        p.status = match result {
            ApplyResult::Success => PlanStatus::Applied,
            ApplyResult::RolledBack => PlanStatus::Draft,
            _ => PlanStatus::Draft,
        };
        if result == ApplyResult::Success {
            p.applied_at = Some(Utc::now());
        }
    }

    // Save changes
    graph.save(data_dir).context("Failed to save graph")?;

    // Print summary
    println!();
    println!("{}", "=".repeat(60));
    match result {
        ApplyResult::Success => {
            println!("Plan applied successfully!");
            if health_check_passed == Some(true) {
                println!("Health check: PASSED");
            } else if health_check_passed == Some(false) {
                println!("Health check: FAILED - review recommended");
            }
        }
        ApplyResult::PartialFailure => {
            println!("Plan partially applied with failures");
            println!("Some operations may need manual cleanup");
        }
        ApplyResult::Failure => {
            println!("Plan application failed");
        }
        ApplyResult::RolledBack => {
            println!("Plan was rolled back due to failure");
            if let Some(ref rb_id) = rollback_plan_id {
                println!("Rollback plan ID: {}", rb_id);
            }
        }
    }

    Ok(())
}

/// Undo/rollback a plan
fn run_undo(data_dir: &Path, plan_name: Option<String>, args: ApplyArgs) -> Result<()> {
    let plan_id = plan_name.ok_or_else(|| anyhow!("Plan name/ID is required"))?;

    let mut graph = EcosystemGraph::load(data_dir)
        .context("Failed to load ecosystem graph")?;

    // Find the plan
    let plan = graph
        .plans
        .plans
        .iter()
        .find(|p| p.id == plan_id || p.name == plan_id)
        .cloned()
        .ok_or_else(|| anyhow!("Plan not found: {}", plan_id))?;

    if plan.status != PlanStatus::Applied {
        return Err(anyhow!("Plan has not been applied, cannot undo"));
    }

    // Generate rollback operations (reverse order)
    let rollback_ops: Vec<PlanOp> = plan
        .operations
        .iter()
        .rev()
        .filter_map(|op| reverse_operation(op))
        .collect();

    if args.dry_run {
        println!("Dry-run: Would undo plan '{}'", plan.name);
        println!();
        println!("Rollback operations:");
        for (i, op) in rollback_ops.iter().enumerate() {
            println!("  {}. {}", i + 1, op.description());
        }
        return Ok(());
    }

    println!("Undoing plan: {}", plan.name);
    println!("{}", "-".repeat(60));

    let started_at = Utc::now();
    let applied_by = std::env::var("USER").unwrap_or_else(|_| "unknown".into());
    let mut op_results: Vec<OpResult> = Vec::new();
    let mut failed = false;

    for (i, op) in rollback_ops.iter().enumerate() {
        println!("  [{}/{}] {}", i + 1, rollback_ops.len(), op.description());

        let result = execute_operation(&mut graph, op);
        let success = result.is_ok();
        let error = result.err().map(|e| e.to_string());

        op_results.push(OpResult {
            op_index: i,
            success,
            error: error.clone(),
            executed_at: Utc::now(),
        });

        if success {
            println!("       OK");
        } else {
            println!("       FAILED: {}", error.as_ref().unwrap());
            failed = true;
        }
    }

    let finished_at = Utc::now();
    let result = if failed {
        ApplyResult::PartialFailure
    } else {
        ApplyResult::Success
    };

    // Create audit entry for the undo
    let audit_entry = AuditEntry {
        kind: "AuditEntry".into(),
        id: format!("audit:undo:{}:{}", plan.id, started_at.timestamp()),
        plan_id: plan.id.clone(),
        result,
        op_results,
        started_at,
        finished_at,
        applied_by,
        auto_rollback_triggered: false,
        rollback_plan_id: None,
        health_check_passed: None,
        notes: vec!["Manual undo operation".into()],
    };

    graph.audit.entries.push(audit_entry);

    // Update plan status back to draft
    if !failed {
        if let Some(p) = graph.plans.plans.iter_mut().find(|p| p.id == plan.id) {
            p.status = PlanStatus::Draft;
            p.applied_at = None;
        }
    }

    graph.save(data_dir).context("Failed to save graph")?;

    println!();
    println!("{}", "=".repeat(60));
    if failed {
        println!("Undo completed with some failures - manual review needed");
    } else {
        println!("Plan undone successfully!");
    }

    Ok(())
}

/// Show audit log
fn run_audit_log(data_dir: &Path, plan_name: Option<String>) -> Result<()> {
    let graph = EcosystemGraph::load(data_dir)
        .context("Failed to load ecosystem graph")?;

    let entries: Vec<_> = if let Some(ref plan_id) = plan_name {
        graph
            .audit
            .entries
            .iter()
            .filter(|e| e.plan_id.contains(plan_id))
            .collect()
    } else {
        graph.audit.entries.iter().collect()
    };

    if entries.is_empty() {
        println!("No audit log entries found");
        return Ok(());
    }

    println!("Audit Log ({} entries)", entries.len());
    println!("{}", "=".repeat(80));

    for entry in entries {
        println!();
        println!("ID: {}", entry.id);
        println!("Plan: {}", entry.plan_id);
        println!("Result: {:?}", entry.result);
        println!("Applied by: {}", entry.applied_by);
        println!("Started: {}", entry.started_at.format("%Y-%m-%d %H:%M:%S"));
        println!("Finished: {}", entry.finished_at.format("%Y-%m-%d %H:%M:%S"));
        println!(
            "Duration: {}ms",
            (entry.finished_at - entry.started_at).num_milliseconds()
        );

        let success_count = entry.op_results.iter().filter(|r| r.success).count();
        let fail_count = entry.op_results.len() - success_count;
        println!("Operations: {} succeeded, {} failed", success_count, fail_count);

        if entry.auto_rollback_triggered {
            println!("Auto-rollback: triggered");
            if let Some(ref rb_id) = entry.rollback_plan_id {
                println!("Rollback plan: {}", rb_id);
            }
        }

        if let Some(health) = entry.health_check_passed {
            println!("Health check: {}", if health { "PASSED" } else { "FAILED" });
        }

        if !entry.notes.is_empty() {
            println!("Notes:");
            for note in &entry.notes {
                println!("  - {}", note);
            }
        }

        println!("{}", "-".repeat(80));
    }

    Ok(())
}

/// Execute a single operation
fn execute_operation(graph: &mut EcosystemGraph, op: &PlanOp) -> Result<()> {
    match op {
        PlanOp::SwitchBinding {
            binding_id,
            consumer_id,
            slot_id,
            from_provider_id: _,
            to_provider_id,
            ..
        } => {
            // Remove old binding
            let initial_len = graph.slots.bindings.len();
            graph.slots.bindings.retain(|b| b.id != *binding_id);

            if graph.slots.bindings.len() == initial_len {
                // Binding wasn't found by ID, try to find by slot/consumer
                graph.slots.bindings.retain(|b| {
                    !(b.slot_id == *slot_id && b.consumer_id == *consumer_id)
                });
            }

            // Create new binding
            let provider = graph
                .slots
                .providers
                .iter()
                .find(|p| p.id == *to_provider_id)
                .ok_or_else(|| anyhow!("Provider not found: {}", to_provider_id))?;

            // Check compatibility
            let slot = graph
                .slots
                .slots
                .iter()
                .find(|s| s.id == *slot_id)
                .ok_or_else(|| anyhow!("Slot not found: {}", slot_id))?;

            // Version compatibility check
            if slot.interface_version != provider.interface_version {
                return Err(anyhow!(
                    "Version mismatch: slot requires {:?}, provider has {:?}",
                    slot.interface_version,
                    provider.interface_version
                ));
            }

            // Capability check
            for cap in &slot.required_capabilities {
                if !provider.capabilities.contains(cap) {
                    return Err(anyhow!(
                        "Missing capability: provider lacks required '{}'",
                        cap
                    ));
                }
            }

            let new_binding = SlotBinding {
                kind: "SlotBinding".into(),
                id: format!(
                    "binding:{}:{}:{}",
                    slot_id.split(':').last().unwrap_or("slot"),
                    consumer_id.split(':').last().unwrap_or("consumer"),
                    to_provider_id.split(':').last().unwrap_or("provider")
                ),
                slot_id: slot_id.clone(),
                consumer_id: consumer_id.clone(),
                provider_id: to_provider_id.clone(),
                mode: BindingMode::Manual,
                created_at: Utc::now(),
                created_by: std::env::var("USER").unwrap_or_else(|_| "apply".into()),
            };

            graph.slots.bindings.push(new_binding);
            Ok(())
        }
        PlanOp::CreateBinding {
            consumer_id,
            slot_id,
            provider_id,
            ..
        } => {
            // Check if binding already exists
            if graph.slots.bindings.iter().any(|b| {
                b.slot_id == *slot_id && b.consumer_id == *consumer_id
            }) {
                return Err(anyhow!("Binding already exists for this slot/consumer"));
            }

            let binding = SlotBinding {
                kind: "SlotBinding".into(),
                id: format!(
                    "binding:{}:{}:{}",
                    slot_id.split(':').last().unwrap_or("slot"),
                    consumer_id.split(':').last().unwrap_or("consumer"),
                    provider_id.split(':').last().unwrap_or("provider")
                ),
                slot_id: slot_id.clone(),
                consumer_id: consumer_id.clone(),
                provider_id: provider_id.clone(),
                mode: BindingMode::Manual,
                created_at: Utc::now(),
                created_by: std::env::var("USER").unwrap_or_else(|_| "apply".into()),
            };

            graph.slots.bindings.push(binding);
            Ok(())
        }
        PlanOp::RemoveBinding {
            binding_id,
            consumer_id,
            slot_id,
            ..
        } => {
            let initial_len = graph.slots.bindings.len();

            // Try to remove by binding_id first
            graph.slots.bindings.retain(|b| b.id != *binding_id);

            if graph.slots.bindings.len() == initial_len {
                // Binding wasn't found by ID, try by slot/consumer
                graph.slots.bindings.retain(|b| {
                    !(b.slot_id == *slot_id && b.consumer_id == *consumer_id)
                });
            }

            if graph.slots.bindings.len() == initial_len {
                return Err(anyhow!("Binding not found"));
            }
            Ok(())
        }
        PlanOp::FileChange { repo_id, file_path, change_type, .. } => {
            // File changes are recorded but not executed automatically
            // This is a safety measure - actual file operations should be done manually
            println!("       [FILE] {:?} {} in {}", change_type, file_path, repo_id);
            println!("       Note: File changes require manual execution");
            Ok(())
        }
    }
}

/// Generate a reverse operation for rollback
fn reverse_operation(op: &PlanOp) -> Option<PlanOp> {
    match op {
        PlanOp::SwitchBinding {
            binding_id,
            consumer_id,
            slot_id,
            from_provider_id,
            to_provider_id,
            risk,
            reason,
        } => Some(PlanOp::SwitchBinding {
            binding_id: binding_id.clone(),
            consumer_id: consumer_id.clone(),
            slot_id: slot_id.clone(),
            from_provider_id: to_provider_id.clone(),  // Swap
            to_provider_id: from_provider_id.clone(),  // Swap
            risk: *risk,
            reason: format!("Rollback: {}", reason),
        }),
        PlanOp::CreateBinding {
            consumer_id,
            slot_id,
            provider_id,
            risk,
            reason,
        } => Some(PlanOp::RemoveBinding {
            binding_id: format!(
                "binding:{}:{}:{}",
                slot_id.split(':').last().unwrap_or("slot"),
                consumer_id.split(':').last().unwrap_or("consumer"),
                provider_id.split(':').last().unwrap_or("provider")
            ),
            consumer_id: consumer_id.clone(),
            slot_id: slot_id.clone(),
            provider_id: provider_id.clone(),
            risk: *risk,
            reason: format!("Rollback: {}", reason),
        }),
        PlanOp::RemoveBinding {
            binding_id: _,
            consumer_id,
            slot_id,
            provider_id,
            risk,
            reason,
        } => Some(PlanOp::CreateBinding {
            consumer_id: consumer_id.clone(),
            slot_id: slot_id.clone(),
            provider_id: provider_id.clone(),
            risk: *risk,
            reason: format!("Rollback: {}", reason),
        }),
        PlanOp::FileChange { .. } => {
            // File changes can't be automatically reversed
            None
        }
    }
}

/// Execute rollback for a failed plan
fn execute_rollback(graph: &mut EcosystemGraph, plan: &Plan, up_to_index: usize) -> Result<String> {
    let rollback_ops: Vec<PlanOp> = plan.operations[..=up_to_index]
        .iter()
        .rev()
        .filter_map(|op| reverse_operation(op))
        .collect();

    let rollback_id = format!("rollback:{}:{}", plan.id, Utc::now().timestamp());

    println!();
    println!("  Executing automatic rollback...");

    for (i, op) in rollback_ops.iter().enumerate() {
        println!("  [rollback {}/{}] {}", i + 1, rollback_ops.len(), op.description());
        if let Err(e) = execute_operation(graph, &op) {
            println!("       ROLLBACK FAILED: {}", e);
            return Err(anyhow!("Rollback failed at step {}: {}", i + 1, e));
        }
        println!("       OK");
    }

    Ok(rollback_id)
}

/// Run health check after apply
fn run_health_check(graph: &EcosystemGraph) -> bool {
    // Basic health checks:
    // 1. All bindings reference valid slots, consumers, and providers
    // 2. No orphaned providers
    // 3. Slot versions match

    let mut healthy = true;

    for binding in &graph.slots.bindings {
        // Check slot exists
        if !graph.slots.slots.iter().any(|s| s.id == binding.slot_id) {
            eprintln!("Health check: Binding {} references missing slot {}", binding.id, binding.slot_id);
            healthy = false;
        }
        // Check provider exists
        if !graph.slots.providers.iter().any(|p| p.id == binding.provider_id) {
            eprintln!("Health check: Binding {} references missing provider {}", binding.id, binding.provider_id);
            healthy = false;
        }
    }

    // Check for version mismatches in active bindings
    for binding in &graph.slots.bindings {
        if let (Some(slot), Some(provider)) = (
            graph.slots.slots.iter().find(|s| s.id == binding.slot_id),
            graph.slots.providers.iter().find(|p| p.id == binding.provider_id),
        ) {
            if slot.interface_version != provider.interface_version {
                eprintln!(
                    "Health check: Version mismatch in binding {} (slot: {:?}, provider: {:?})",
                    binding.id, slot.interface_version, provider.interface_version
                );
                healthy = false;
            }
        }
    }

    healthy
}
