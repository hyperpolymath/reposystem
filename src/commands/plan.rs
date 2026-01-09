// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Plan command implementations

use anyhow::{bail, Context, Result};
use chrono::Utc;
use std::path::Path;

use crate::graph::EcosystemGraph;
use crate::types::{
    Plan, PlanDiff, PlanOp, PlanStatus, RiskLevel, SlotBinding,
};

/// Arguments for plan creation
pub struct PlanArgs {
    /// Scenario to create plan from
    pub scenario: Option<String>,
    /// Optional plan name override
    pub name: Option<String>,
    /// Plan description
    pub description: Option<String>,
}

/// Run the plan command
pub fn run(action: &str, name: Option<String>, args: PlanArgs) -> Result<()> {
    let data_dir = std::env::var("REPOSYSTEM_DATA_DIR")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(|_| std::path::PathBuf::from(".reposystem"));

    match action {
        "create" => create_plan(&data_dir, args),
        "list" => list_plans(&data_dir),
        "show" => show_plan(&data_dir, name),
        "diff" => show_diff(&data_dir, name),
        "rollback" => generate_rollback(&data_dir, name),
        "delete" => delete_plan(&data_dir, name),
        _ => bail!("Unknown action: {}. Use create, list, show, diff, rollback, or delete", action),
    }
}

/// Create a plan from a scenario
fn create_plan(data_dir: &Path, args: PlanArgs) -> Result<()> {
    let mut graph = EcosystemGraph::load(data_dir)
        .context("Failed to load ecosystem graph")?;

    let scenario_id = args.scenario
        .ok_or_else(|| anyhow::anyhow!("--scenario is required"))?;

    // Verify scenario exists
    let scenario = graph.store.scenarios
        .iter()
        .find(|s| s.id == scenario_id || s.name == scenario_id)
        .ok_or_else(|| anyhow::anyhow!("Scenario not found: {}", scenario_id))?;

    let scenario_id = scenario.id.clone();
    let scenario_name = scenario.name.clone();

    // Get the changeset for this scenario
    let changeset = graph.store.changesets
        .iter()
        .find(|c| c.scenario_id == scenario_id);

    // Generate plan operations from the scenario's changeset and current bindings
    let operations = generate_plan_operations(&graph, &scenario_id, changeset)?;

    // Calculate overall risk
    let overall_risk = Plan::calculate_overall_risk(&operations);

    // Create the plan
    let plan_name = args.name.unwrap_or_else(|| format!("Plan for {}", scenario_name));
    let plan = Plan {
        kind: "Plan".into(),
        id: Plan::generate_id(&scenario_id),
        name: plan_name.clone(),
        scenario_id: scenario_id.clone(),
        description: args.description,
        operations,
        overall_risk,
        status: PlanStatus::Ready,
        created_at: Utc::now(),
        created_by: std::env::var("USER").unwrap_or_else(|_| "unknown".into()),
        applied_at: None,
        rollback_plan_id: None,
    };

    // Generate diff for the plan
    let diff = generate_plan_diff(&plan);

    // Add to store
    graph.plans.plans.push(plan.clone());
    graph.plans.diffs.push(diff.clone());

    // Save
    graph.save(data_dir)?;

    println!("Created plan: {} ({})", plan_name, plan.id);
    println!("  Scenario: {}", scenario_id);
    println!("  Operations: {}", plan.operations.len());
    println!("  Overall risk: {:?}", plan.overall_risk);
    println!();
    println!("Use 'reposystem plan diff --name {}' to preview changes", plan.id);

    Ok(())
}

/// Generate plan operations from a scenario
fn generate_plan_operations(
    graph: &EcosystemGraph,
    _scenario_id: &str,
    changeset: Option<&crate::types::ChangeSet>,
) -> Result<Vec<PlanOp>> {
    let mut operations = Vec::new();

    // If there's a changeset, analyze it for binding-related changes
    if let Some(cs) = changeset {
        for op in &cs.ops {
            match op {
                crate::types::ChangeOp::AddEdge { edge } => {
                    // Adding an edge might indicate a new binding relationship
                    // For now, we note it as informational
                    tracing::debug!("Scenario adds edge: {} -> {}", edge.from, edge.to);
                }
                crate::types::ChangeOp::RemoveEdge { edge_id } => {
                    tracing::debug!("Scenario removes edge: {}", edge_id);
                }
                _ => {}
            }
        }
    }

    // Compare current bindings to desired state
    // For each slot used by consumers, check if the binding should change
    for binding in &graph.slots.bindings {
        // Check if this binding's provider is marked for replacement in the scenario
        let current_provider = graph.slots.providers
            .iter()
            .find(|p| p.id == binding.provider_id);

        if let Some(provider) = current_provider {
            // Look for alternative providers for the same slot
            let alternatives: Vec<_> = graph.slots.providers
                .iter()
                .filter(|p| p.slot_id == binding.slot_id && p.id != binding.provider_id)
                .collect();

            // If there are alternatives with higher priority, suggest a switch
            for alt in &alternatives {
                if alt.priority > provider.priority && !alt.is_fallback {
                    // Check compatibility
                    let compat = graph.slots.check_compatibility(&binding.slot_id, &alt.id);
                    if compat.compatible {
                        let risk = assess_binding_switch_risk(graph, binding, provider, alt);
                        operations.push(PlanOp::SwitchBinding {
                            binding_id: binding.id.clone(),
                            consumer_id: binding.consumer_id.clone(),
                            slot_id: binding.slot_id.clone(),
                            from_provider_id: binding.provider_id.clone(),
                            to_provider_id: alt.id.clone(),
                            risk,
                            reason: format!(
                                "Higher priority provider available: {} (priority {}) vs {} (priority {})",
                                alt.name, alt.priority, provider.name, provider.priority
                            ),
                        });
                    }
                }
            }
        }
    }

    // Also check for consumers that need bindings
    for repo in &graph.store.repos {
        // Check each slot to see if this repo might need it
        for slot in &graph.slots.slots {
            let existing_binding = graph.slots.get_binding(&repo.id, &slot.id);
            if existing_binding.is_none() {
                // Check if there's a compatible provider available
                let compatible_providers: Vec<_> = graph.slots.providers
                    .iter()
                    .filter(|p| {
                        p.slot_id == slot.id &&
                        graph.slots.check_compatibility(&slot.id, &p.id).compatible
                    })
                    .collect();

                if !compatible_providers.is_empty() {
                    // Pick the highest priority non-fallback provider
                    let best = compatible_providers
                        .iter()
                        .filter(|p| !p.is_fallback)
                        .max_by_key(|p| p.priority)
                        .or_else(|| compatible_providers.first());

                    if let Some(provider) = best {
                        // Only suggest if this seems relevant based on scenario
                        // For now, we're conservative and only include explicit switches
                        tracing::debug!(
                            "Could bind {} to {} via {}",
                            repo.id, slot.id, provider.id
                        );
                    }
                }
            }
        }
    }

    Ok(operations)
}

/// Assess risk level for a binding switch
fn assess_binding_switch_risk(
    graph: &EcosystemGraph,
    _binding: &SlotBinding,
    from_provider: &crate::types::Provider,
    to_provider: &crate::types::Provider,
) -> RiskLevel {
    let mut risk_score = 0;

    // Switching from local to external is higher risk
    if from_provider.provider_type == crate::types::ProviderType::Local
        && to_provider.provider_type == crate::types::ProviderType::External
    {
        risk_score += 2;
    }

    // Switching to a fallback provider is medium risk
    if to_provider.is_fallback {
        risk_score += 1;
    }

    // Version mismatch increases risk
    if from_provider.interface_version != to_provider.interface_version {
        risk_score += 1;
    }

    // Check for security aspects on the providers
    for annotation in &graph.aspects.annotations {
        if annotation.target == from_provider.id || annotation.target == to_provider.id {
            if annotation.polarity == crate::types::Polarity::Risk {
                risk_score += annotation.weight as i32;
            }
        }
    }

    match risk_score {
        0 => RiskLevel::Low,
        1 => RiskLevel::Medium,
        2..=3 => RiskLevel::High,
        _ => RiskLevel::Critical,
    }
}

/// Generate a diff summary for a plan
fn generate_plan_diff(plan: &Plan) -> PlanDiff {
    let mut bindings_changed = 0;
    let mut bindings_created = 0;
    let mut bindings_removed = 0;
    let mut files_affected = 0;
    let file_diffs = Vec::new();

    for op in &plan.operations {
        match op {
            PlanOp::SwitchBinding { .. } => bindings_changed += 1,
            PlanOp::CreateBinding { .. } => bindings_created += 1,
            PlanOp::RemoveBinding { .. } => bindings_removed += 1,
            PlanOp::FileChange { .. } => files_affected += 1,
        }
    }

    PlanDiff {
        plan_id: plan.id.clone(),
        bindings_changed,
        bindings_created,
        bindings_removed,
        files_affected,
        file_diffs,
    }
}

/// List all plans
fn list_plans(data_dir: &Path) -> Result<()> {
    let graph = EcosystemGraph::load(data_dir)
        .context("Failed to load ecosystem graph")?;

    if graph.plans.plans.is_empty() {
        println!("No plans found.");
        println!("Use 'reposystem plan create --scenario <name>' to create a plan.");
        return Ok(());
    }

    println!("Plans ({}):", graph.plans.plans.len());
    println!();

    for plan in &graph.plans.plans {
        let status_icon = match plan.status {
            PlanStatus::Draft => "📝",
            PlanStatus::Ready => "✅",
            PlanStatus::Applied => "🚀",
            PlanStatus::RolledBack => "↩️",
            PlanStatus::Cancelled => "❌",
        };
        let risk_icon = match plan.overall_risk {
            RiskLevel::Low => "🟢",
            RiskLevel::Medium => "🟡",
            RiskLevel::High => "🟠",
            RiskLevel::Critical => "🔴",
        };

        println!("{} {} {} - {} ({} ops)",
            status_icon, risk_icon, plan.id, plan.name, plan.operations.len());
        println!("     Scenario: {}", plan.scenario_id);
        println!("     Created: {}", plan.created_at.format("%Y-%m-%d %H:%M"));
        if let Some(applied) = plan.applied_at {
            println!("     Applied: {}", applied.format("%Y-%m-%d %H:%M"));
        }
        println!();
    }

    Ok(())
}

/// Show plan details
fn show_plan(data_dir: &Path, name: Option<String>) -> Result<()> {
    let graph = EcosystemGraph::load(data_dir)
        .context("Failed to load ecosystem graph")?;

    let plan_id = name.ok_or_else(|| anyhow::anyhow!("Plan name or ID required"))?;

    let plan = graph.plans.plans
        .iter()
        .find(|p| p.id == plan_id || p.name == plan_id)
        .ok_or_else(|| anyhow::anyhow!("Plan not found: {}", plan_id))?;

    println!("Plan: {}", plan.name);
    println!("  ID: {}", plan.id);
    println!("  Scenario: {}", plan.scenario_id);
    println!("  Status: {:?}", plan.status);
    println!("  Overall Risk: {:?}", plan.overall_risk);
    println!("  Created: {} by {}", plan.created_at.format("%Y-%m-%d %H:%M:%S"), plan.created_by);
    if let Some(desc) = &plan.description {
        println!("  Description: {}", desc);
    }
    println!();

    if plan.operations.is_empty() {
        println!("  No operations in this plan.");
    } else {
        println!("  Operations ({}):", plan.operations.len());
        for (i, op) in plan.operations.iter().enumerate() {
            let risk_icon = match op.risk() {
                RiskLevel::Low => "🟢",
                RiskLevel::Medium => "🟡",
                RiskLevel::High => "🟠",
                RiskLevel::Critical => "🔴",
            };
            println!("    {}. {} {}", i + 1, risk_icon, op.description());
        }
    }

    // Show risk summary
    let summary = plan.risk_summary();
    if !summary.is_empty() {
        println!();
        println!("  Risk Summary:");
        for (level, count) in &summary {
            println!("    {}: {}", level, count);
        }
    }

    Ok(())
}

/// Show dry-run diff for a plan
fn show_diff(data_dir: &Path, name: Option<String>) -> Result<()> {
    let graph = EcosystemGraph::load(data_dir)
        .context("Failed to load ecosystem graph")?;

    let plan_id = name.ok_or_else(|| anyhow::anyhow!("Plan name or ID required"))?;

    let plan = graph.plans.plans
        .iter()
        .find(|p| p.id == plan_id || p.name == plan_id)
        .ok_or_else(|| anyhow::anyhow!("Plan not found: {}", plan_id))?;

    let diff = graph.plans.get_diff(&plan.id);

    println!("Dry-Run Diff for: {}", plan.name);
    println!("{}", "=".repeat(60));
    println!();

    if let Some(d) = diff {
        println!("Summary:");
        println!("  Bindings changed: {}", d.bindings_changed);
        println!("  Bindings created: {}", d.bindings_created);
        println!("  Bindings removed: {}", d.bindings_removed);
        println!("  Files affected: {}", d.files_affected);
        println!();

        if !d.file_diffs.is_empty() {
            println!("File Changes:");
            for fd in &d.file_diffs {
                println!("  {} ({:?})", fd.file_path, fd.change_type);
                println!("    +{} -{}", fd.lines_added, fd.lines_removed);
                if !fd.diff.is_empty() {
                    for line in fd.diff.lines().take(10) {
                        println!("    {}", line);
                    }
                    if fd.diff.lines().count() > 10 {
                        println!("    ... ({} more lines)", fd.diff.lines().count() - 10);
                    }
                }
            }
        }
    }

    println!("Operations:");
    for (i, op) in plan.operations.iter().enumerate() {
        println!();
        println!("{}. {}", i + 1, op.description());
        match op {
            PlanOp::SwitchBinding { from_provider_id, to_provider_id, reason, .. } => {
                println!("   From: {}", from_provider_id);
                println!("   To:   {}", to_provider_id);
                println!("   Reason: {}", reason);
            }
            PlanOp::CreateBinding { provider_id, reason, .. } => {
                println!("   Provider: {}", provider_id);
                println!("   Reason: {}", reason);
            }
            PlanOp::RemoveBinding { provider_id, reason, .. } => {
                println!("   Was: {}", provider_id);
                println!("   Reason: {}", reason);
            }
            PlanOp::FileChange { file_path, change_type, diff, .. } => {
                println!("   File: {}", file_path);
                println!("   Change: {:?}", change_type);
                if let Some(d) = diff {
                    println!("   Diff preview:");
                    for line in d.lines().take(5) {
                        println!("     {}", line);
                    }
                }
            }
        }
    }

    println!();
    println!("To apply this plan (in f4): reposystem apply --plan {}", plan.id);

    Ok(())
}

/// Generate a rollback plan
fn generate_rollback(data_dir: &Path, name: Option<String>) -> Result<()> {
    let mut graph = EcosystemGraph::load(data_dir)
        .context("Failed to load ecosystem graph")?;

    let plan_id = name.ok_or_else(|| anyhow::anyhow!("Plan name or ID required"))?;

    let plan = graph.plans.plans
        .iter()
        .find(|p| p.id == plan_id || p.name == plan_id)
        .ok_or_else(|| anyhow::anyhow!("Plan not found: {}", plan_id))?
        .clone();

    // Generate rollback plan
    let rollback = crate::types::PlanStore::generate_rollback(&plan);

    println!("Generated rollback plan: {}", rollback.id);
    println!("  For plan: {}", plan.id);
    println!("  Operations: {} (reversed)", rollback.operations.len());
    println!();

    // Show rollback operations
    for (i, op) in rollback.operations.iter().enumerate() {
        println!("  {}. {}", i + 1, op.description());
    }

    // Add rollback plan to store
    let rollback_id = rollback.id.clone();
    graph.plans.plans.push(rollback);

    // Save
    graph.save(data_dir)?;

    println!();
    println!("Rollback plan saved. Use 'reposystem plan show --name {}' to review.", rollback_id);

    Ok(())
}

/// Delete a plan
fn delete_plan(data_dir: &Path, name: Option<String>) -> Result<()> {
    let mut graph = EcosystemGraph::load(data_dir)
        .context("Failed to load ecosystem graph")?;

    let plan_id = name.ok_or_else(|| anyhow::anyhow!("Plan name or ID required"))?;

    let plan_idx = graph.plans.plans
        .iter()
        .position(|p| p.id == plan_id || p.name == plan_id)
        .ok_or_else(|| anyhow::anyhow!("Plan not found: {}", plan_id))?;

    let plan = graph.plans.plans.remove(plan_idx);

    // Also remove associated diff
    graph.plans.diffs.retain(|d| d.plan_id != plan.id);

    // Save
    graph.save(data_dir)?;

    println!("Deleted plan: {} ({})", plan.name, plan.id);

    Ok(())
}
