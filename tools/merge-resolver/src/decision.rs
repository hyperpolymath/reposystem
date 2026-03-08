// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! Decision logging for merge conflict resolution
//!
//! Every merge resolution decision is captured as structured JSON for:
//! - Auditing and review
//! - VeriSimDB hexad persistence
//! - PanLL Panel-N visualization (AI reasoning)
//! - Rollback granularity (revert individual decisions)

use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use uuid::Uuid;

/// Type of merge conflict
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ConflictType {
    /// Both branches modified the same file
    BothModified,
    /// One branch deleted, the other modified
    DeleteModify,
    /// File renamed differently in both branches
    RenameConflict,
    /// File added in both branches with different content
    AddAdd,
    /// Submodule conflict
    Submodule,
}

impl std::fmt::Display for ConflictType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::BothModified => write!(f, "both_modified"),
            Self::DeleteModify => write!(f, "delete_modify"),
            Self::RenameConflict => write!(f, "rename_conflict"),
            Self::AddAdd => write!(f, "add_add"),
            Self::Submodule => write!(f, "submodule"),
        }
    }
}

/// Resolution strategy applied to a conflict
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ResolutionStrategy {
    /// Accept "ours" (target branch) version
    ChoseOurs,
    /// Accept "theirs" (source branch) version
    ChoseTheirs,
    /// Manual merge of both sides
    ManualMerge,
    /// AI-assisted merge
    AiMerge,
}

impl std::fmt::Display for ResolutionStrategy {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::ChoseOurs => write!(f, "chose_ours"),
            Self::ChoseTheirs => write!(f, "chose_theirs"),
            Self::ManualMerge => write!(f, "manual_merge"),
            Self::AiMerge => write!(f, "ai_merge"),
        }
    }
}

/// A single conflict resolution decision
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConflictDecision {
    /// Unique decision identifier
    pub decision_id: Uuid,
    /// File path of the conflict
    pub file: PathBuf,
    /// Type of conflict
    pub conflict_type: ConflictType,
    /// Resolution strategy used
    pub strategy: ResolutionStrategy,
    /// Reasoning for the decision (human or AI)
    pub reasoning: String,
    /// Confidence in the resolution (0.0 - 1.0)
    pub confidence: f64,
    /// ISO 8601 timestamp
    pub timestamp: String,
    /// Whether this decision can be individually reverted
    pub reversible: bool,
}

/// Complete decision log for a merge session
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DecisionLog {
    /// Session this log belongs to
    pub session_id: Uuid,
    /// All recorded decisions (ordered by timestamp)
    pub decisions: Vec<ConflictDecision>,
    /// Files with pending (unresolved) conflicts
    pub pending_conflicts: Vec<PathBuf>,
}

impl DecisionLog {
    /// Create a new empty decision log
    pub fn new(session_id: Uuid) -> Self {
        Self {
            session_id,
            decisions: Vec::new(),
            pending_conflicts: Vec::new(),
        }
    }

    /// Add a pending conflict file
    pub fn add_pending_conflict(&mut self, file: PathBuf) {
        self.pending_conflicts.push(file);
    }

    /// Record a conflict resolution decision
    pub fn record_decision(&mut self, decision: ConflictDecision) {
        // Remove from pending
        self.pending_conflicts
            .retain(|f| f != &decision.file);
        self.decisions.push(decision);
    }

    /// Get decisions for a specific file
    pub fn decisions_for_file(&self, file: &PathBuf) -> Vec<&ConflictDecision> {
        self.decisions.iter().filter(|d| &d.file == file).collect()
    }

    /// Get the latest decision for a file
    pub fn latest_decision_for_file(&self, file: &PathBuf) -> Option<&ConflictDecision> {
        self.decisions.iter().rev().find(|d| &d.file == file)
    }

    /// Average confidence across all decisions
    pub fn average_confidence(&self) -> f64 {
        if self.decisions.is_empty() {
            return 0.0;
        }
        let sum: f64 = self.decisions.iter().map(|d| d.confidence).sum();
        sum / self.decisions.len() as f64
    }

    /// Count of decisions by strategy
    pub fn strategy_counts(&self) -> std::collections::HashMap<ResolutionStrategy, usize> {
        let mut counts = std::collections::HashMap::new();
        for d in &self.decisions {
            *counts.entry(d.strategy).or_insert(0) += 1;
        }
        counts
    }

    /// Check if all conflicts are resolved
    pub fn all_resolved(&self) -> bool {
        self.pending_conflicts.is_empty()
    }

    /// Format as markdown summary for PanLL Panel-N
    pub fn format_reasoning_summary(&self) -> String {
        let mut lines = Vec::new();
        lines.push(format!(
            "## Merge Resolution Decisions (Session {})\n",
            self.session_id
        ));

        for (i, decision) in self.decisions.iter().enumerate() {
            lines.push(format!(
                "### Decision {} — `{}`",
                i + 1,
                decision.file.display()
            ));
            lines.push(format!("- **Conflict:** {}", decision.conflict_type));
            lines.push(format!("- **Strategy:** {}", decision.strategy));
            lines.push(format!("- **Confidence:** {:.0}%", decision.confidence * 100.0));
            lines.push(format!("- **Reasoning:** {}", decision.reasoning));
            lines.push(String::new());
        }

        if !self.pending_conflicts.is_empty() {
            lines.push("### Pending Conflicts\n".to_string());
            for file in &self.pending_conflicts {
                lines.push(format!("- `{}`", file.display()));
            }
        }

        lines.join("\n")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_decision_log_lifecycle() {
        let session_id = Uuid::new_v4();
        let mut log = DecisionLog::new(session_id);

        // Add pending conflicts
        log.add_pending_conflict(PathBuf::from("src/main.res"));
        log.add_pending_conflict(PathBuf::from("src/utils.res"));
        assert_eq!(log.pending_conflicts.len(), 2);
        assert!(!log.all_resolved());

        // Resolve first conflict
        log.record_decision(ConflictDecision {
            decision_id: Uuid::new_v4(),
            file: PathBuf::from("src/main.res"),
            conflict_type: ConflictType::BothModified,
            strategy: ResolutionStrategy::ChoseOurs,
            reasoning: "Ours uses modern Dict API".to_string(),
            confidence: 0.95,
            timestamp: "2026-03-01T10:00:00Z".to_string(),
            reversible: true,
        });
        assert_eq!(log.pending_conflicts.len(), 1);
        assert_eq!(log.decisions.len(), 1);

        // Resolve second conflict
        log.record_decision(ConflictDecision {
            decision_id: Uuid::new_v4(),
            file: PathBuf::from("src/utils.res"),
            conflict_type: ConflictType::DeleteModify,
            strategy: ResolutionStrategy::ChoseTheirs,
            reasoning: "File was deleted in ours, added back in theirs".to_string(),
            confidence: 0.80,
            timestamp: "2026-03-01T10:01:00Z".to_string(),
            reversible: true,
        });
        assert!(log.all_resolved());
        assert_eq!(log.decisions.len(), 2);
    }

    #[test]
    fn test_average_confidence() {
        let session_id = Uuid::new_v4();
        let mut log = DecisionLog::new(session_id);

        log.record_decision(ConflictDecision {
            decision_id: Uuid::new_v4(),
            file: PathBuf::from("a.res"),
            conflict_type: ConflictType::BothModified,
            strategy: ResolutionStrategy::AiMerge,
            reasoning: "AI merged both sides".to_string(),
            confidence: 0.90,
            timestamp: "2026-03-01T10:00:00Z".to_string(),
            reversible: true,
        });

        log.record_decision(ConflictDecision {
            decision_id: Uuid::new_v4(),
            file: PathBuf::from("b.res"),
            conflict_type: ConflictType::BothModified,
            strategy: ResolutionStrategy::ChoseOurs,
            reasoning: "Ours is correct".to_string(),
            confidence: 0.70,
            timestamp: "2026-03-01T10:01:00Z".to_string(),
            reversible: true,
        });

        let avg = log.average_confidence();
        assert!((avg - 0.80).abs() < f64::EPSILON);
    }

    #[test]
    fn test_strategy_counts() {
        let session_id = Uuid::new_v4();
        let mut log = DecisionLog::new(session_id);

        for _ in 0..3 {
            log.decisions.push(ConflictDecision {
                decision_id: Uuid::new_v4(),
                file: PathBuf::from("test.res"),
                conflict_type: ConflictType::BothModified,
                strategy: ResolutionStrategy::ChoseOurs,
                reasoning: "test".to_string(),
                confidence: 0.9,
                timestamp: "2026-03-01T10:00:00Z".to_string(),
                reversible: true,
            });
        }
        log.decisions.push(ConflictDecision {
            decision_id: Uuid::new_v4(),
            file: PathBuf::from("test2.res"),
            conflict_type: ConflictType::BothModified,
            strategy: ResolutionStrategy::AiMerge,
            reasoning: "test".to_string(),
            confidence: 0.85,
            timestamp: "2026-03-01T10:01:00Z".to_string(),
            reversible: true,
        });

        let counts = log.strategy_counts();
        assert_eq!(counts[&ResolutionStrategy::ChoseOurs], 3);
        assert_eq!(counts[&ResolutionStrategy::AiMerge], 1);
    }

    #[test]
    fn test_format_reasoning_summary() {
        let session_id = Uuid::new_v4();
        let mut log = DecisionLog::new(session_id);
        log.add_pending_conflict(PathBuf::from("unresolved.res"));
        log.record_decision(ConflictDecision {
            decision_id: Uuid::new_v4(),
            file: PathBuf::from("resolved.res"),
            conflict_type: ConflictType::BothModified,
            strategy: ResolutionStrategy::ChoseOurs,
            reasoning: "Ours uses modern Dict API".to_string(),
            confidence: 0.95,
            timestamp: "2026-03-01T10:00:00Z".to_string(),
            reversible: true,
        });

        let summary = log.format_reasoning_summary();
        assert!(summary.contains("Merge Resolution Decisions"));
        assert!(summary.contains("resolved.res"));
        assert!(summary.contains("Ours uses modern Dict API"));
        assert!(summary.contains("unresolved.res"));
    }
}
