// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! merge-resolver CLI — Safe, reversible merge conflict resolution
//!
//! Usage:
//!   merge-resolver begin <REPO> <BRANCH>
//!   merge-resolver resolve <REPO> <SESSION> <FILE> --strategy <STRATEGY> --reasoning <TEXT>
//!   merge-resolver rollback <REPO> <SESSION>
//!   merge-resolver accept <REPO> <SESSION> [--message <MSG>]
//!   merge-resolver list <REPO>
//!   merge-resolver show <REPO> <SESSION>

use anyhow::Result;
use clap::{Parser, Subcommand};
use merge_resolver::decision::ResolutionStrategy;
use merge_resolver::MergeResolver;
use std::path::PathBuf;
use uuid::Uuid;

#[derive(Parser)]
#[command(
    name = "merge-resolver",
    version,
    about = "Safe, reversible AI-assisted merge conflict resolution"
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Begin a new merge resolution session
    Begin {
        /// Path to the git repository
        repo: PathBuf,
        /// Branch to merge into current HEAD
        branch: String,
    },

    /// Resolve a single conflict in a session
    Resolve {
        /// Path to the git repository
        repo: PathBuf,
        /// Session ID (UUID)
        session: String,
        /// File to resolve
        file: PathBuf,
        /// Resolution strategy
        #[arg(long, value_parser = parse_strategy)]
        strategy: ResolutionStrategy,
        /// Reasoning for the decision
        #[arg(long)]
        reasoning: String,
        /// Confidence in the resolution (0.0 - 1.0)
        #[arg(long, default_value = "0.9")]
        confidence: f64,
    },

    /// Roll back a merge session to pre-merge state
    Rollback {
        /// Path to the git repository
        repo: PathBuf,
        /// Session ID (UUID)
        session: String,
    },

    /// Accept and finalize a merge session
    Accept {
        /// Path to the git repository
        repo: PathBuf,
        /// Session ID (UUID)
        session: String,
        /// Custom commit message
        #[arg(long)]
        message: Option<String>,
    },

    /// List all merge resolution sessions
    List {
        /// Path to the git repository
        repo: PathBuf,
    },

    /// Show details of a merge resolution session
    Show {
        /// Path to the git repository
        repo: PathBuf,
        /// Session ID (UUID)
        session: String,
        /// Output format
        #[arg(long, default_value = "text")]
        format: OutputFormat,
    },

    /// Verify a migration is complete across ALL git-tracked files
    ///
    /// Scans every git-tracked file (not just src/) for a pattern that
    /// should no longer appear after a migration. Catches files in
    /// non-standard locations (lib/ocaml/, build artifacts, etc.) that
    /// directory-scoped migrations miss.
    Verify {
        /// Path to the git repository
        repo: PathBuf,
        /// String pattern to search for (e.g. "Js.Dict", "Js.")
        #[arg(long)]
        pattern: String,
        /// File glob to filter (e.g. "*.res", "*.ts"). Passed to git ls-files.
        #[arg(long)]
        glob: Option<String>,
        /// Exclude comment-only lines from matching
        #[arg(long, default_value = "false")]
        exclude_comments: bool,
        /// Exit with code 1 if any matches are found
        #[arg(long, default_value = "true")]
        fail_on_match: bool,
        /// Output format
        #[arg(long, default_value = "text")]
        format: OutputFormat,
    },
}

#[derive(Clone, Debug)]
enum OutputFormat {
    Text,
    Json,
    Markdown,
}

impl std::str::FromStr for OutputFormat {
    type Err = String;
    fn from_str(s: &str) -> std::result::Result<Self, Self::Err> {
        match s {
            "text" => Ok(Self::Text),
            "json" => Ok(Self::Json),
            "markdown" | "md" => Ok(Self::Markdown),
            _ => Err(format!("Unknown format: {} (expected text, json, markdown)", s)),
        }
    }
}

fn parse_strategy(s: &str) -> Result<ResolutionStrategy, String> {
    match s {
        "ours" | "chose_ours" => Ok(ResolutionStrategy::ChoseOurs),
        "theirs" | "chose_theirs" => Ok(ResolutionStrategy::ChoseTheirs),
        "manual" | "manual_merge" => Ok(ResolutionStrategy::ManualMerge),
        "ai" | "ai_merge" => Ok(ResolutionStrategy::AiMerge),
        _ => Err(format!(
            "Unknown strategy: {} (expected ours, theirs, manual, ai)",
            s
        )),
    }
}

fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("merge_resolver=info".parse().unwrap()),
        )
        .init();

    let cli = Cli::parse();

    match cli.command {
        Commands::Begin { repo, branch } => {
            let resolver = MergeResolver::new(&repo)?;
            let session = resolver.begin(&branch)?;

            println!("Session: {}", session.session_id);
            println!("Target:  {} -> {}", session.source_branch, session.target_branch);
            println!("Conflicts: {}", session.conflict_count);

            if session.conflict_count > 0 {
                println!("\nConflicting files:");
                for file in &session.decisions.pending_conflicts {
                    println!("  - {}", file.display());
                }
                println!(
                    "\nResolve with: merge-resolver resolve {} {} <FILE> --strategy <ours|theirs|manual|ai> --reasoning \"...\"",
                    repo.display(),
                    session.session_id
                );
            } else {
                println!("\nNo conflicts. Accept with: merge-resolver accept {} {}", repo.display(), session.session_id);
            }
        }

        Commands::Resolve {
            repo,
            session,
            file,
            strategy,
            reasoning,
            confidence,
        } => {
            let resolver = MergeResolver::new(&repo)?;
            let session_id: Uuid = session.parse().map_err(|e| anyhow::anyhow!("Invalid session ID: {}", e))?;
            let mut merge_session = resolver.load_session(&session_id)?;

            resolver.resolve_conflict(&mut merge_session, &file, strategy, &reasoning, confidence)?;

            println!("Resolved: {} (strategy: {}, confidence: {:.0}%)", file.display(), strategy, confidence * 100.0);
            println!(
                "Progress: {}/{} conflicts resolved",
                merge_session.resolved_count, merge_session.conflict_count
            );

            if merge_session.decisions.all_resolved() {
                println!(
                    "\nAll conflicts resolved. Accept with: merge-resolver accept {} {}",
                    repo.display(),
                    session_id
                );
            }
        }

        Commands::Rollback { repo, session } => {
            let resolver = MergeResolver::new(&repo)?;
            let session_id: Uuid = session.parse().map_err(|e| anyhow::anyhow!("Invalid session ID: {}", e))?;
            let mut merge_session = resolver.load_session(&session_id)?;

            resolver.rollback(&mut merge_session)?;

            println!("Rolled back session {}", session_id);
            println!("Repository restored to: {}", merge_session.snapshot.head_ref);
            println!("Decision log preserved at: .merge-resolver/{}-decisions.json", session_id);
        }

        Commands::Accept { repo, session, message } => {
            let resolver = MergeResolver::new(&repo)?;
            let session_id: Uuid = session.parse().map_err(|e| anyhow::anyhow!("Invalid session ID: {}", e))?;
            let mut merge_session = resolver.load_session(&session_id)?;

            resolver.accept(&mut merge_session, message.as_deref())?;

            println!("Merge accepted for session {}", session_id);
            println!(
                "Merged '{}' into '{}'",
                merge_session.source_branch, merge_session.target_branch
            );
            println!(
                "Decisions: {} (avg confidence: {:.0}%)",
                merge_session.decisions.decisions.len(),
                merge_session.decisions.average_confidence() * 100.0
            );
        }

        Commands::List { repo } => {
            let resolver = MergeResolver::new(&repo)?;
            let sessions = resolver.list_sessions()?;

            if sessions.is_empty() {
                println!("No merge resolution sessions found.");
                return Ok(());
            }

            println!("{:<38} {:<12} {:<6} {:<20}", "Session ID", "Status", "Conf.", "Started");
            println!("{}", "-".repeat(80));
            for session in &sessions {
                let status = match session.status {
                    merge_resolver::SessionStatus::InProgress => "in_progress",
                    merge_resolver::SessionStatus::Accepted => "accepted",
                    merge_resolver::SessionStatus::RolledBack => "rolled_back",
                };
                println!(
                    "{:<38} {:<12} {:<6} {:<20}",
                    session.session_id,
                    status,
                    format!("{}/{}", session.resolved_count, session.conflict_count),
                    &session.started_at[..19]
                );
            }
        }

        Commands::Show { repo, session, format } => {
            let resolver = MergeResolver::new(&repo)?;
            let session_id: Uuid = session.parse().map_err(|e| anyhow::anyhow!("Invalid session ID: {}", e))?;
            let merge_session = resolver.load_session(&session_id)?;

            match format {
                OutputFormat::Json => {
                    println!("{}", serde_json::to_string_pretty(&merge_session)?);
                }
                OutputFormat::Markdown => {
                    println!("{}", merge_session.decisions.format_reasoning_summary());
                }
                OutputFormat::Text => {
                    println!("Session:     {}", merge_session.session_id);
                    println!("Status:      {:?}", merge_session.status);
                    println!("Source:      {}", merge_session.source_branch);
                    println!("Target:      {}", merge_session.target_branch);
                    println!("Conflicts:   {}", merge_session.conflict_count);
                    println!("Resolved:    {}", merge_session.resolved_count);
                    println!("Started:     {}", merge_session.started_at);
                    if let Some(ended) = &merge_session.ended_at {
                        println!("Ended:       {}", ended);
                    }
                    println!(
                        "Avg conf.:   {:.0}%",
                        merge_session.decisions.average_confidence() * 100.0
                    );

                    if !merge_session.decisions.decisions.is_empty() {
                        println!("\nDecisions:");
                        for d in &merge_session.decisions.decisions {
                            println!(
                                "  {} — {} ({}, {:.0}%)",
                                d.file.display(),
                                d.strategy,
                                d.conflict_type,
                                d.confidence * 100.0
                            );
                            println!("    Reason: {}", d.reasoning);
                        }
                    }

                    if !merge_session.decisions.pending_conflicts.is_empty() {
                        println!("\nPending:");
                        for f in &merge_session.decisions.pending_conflicts {
                            println!("  - {}", f.display());
                        }
                    }
                }
            }
        }

        Commands::Verify {
            repo,
            pattern,
            glob,
            exclude_comments,
            fail_on_match,
            format,
        } => {
            let result = merge_resolver::verify::verify_migration(
                &repo,
                &pattern,
                glob.as_deref(),
                exclude_comments,
            )?;

            match format {
                OutputFormat::Json => {
                    println!("{}", serde_json::to_string_pretty(&result)?);
                }
                OutputFormat::Text | OutputFormat::Markdown => {
                    print!("{}", result);
                }
            }

            if fail_on_match && !result.passed {
                std::process::exit(1);
            }
        }
    }

    Ok(())
}
