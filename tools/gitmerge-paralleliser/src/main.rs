// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! gitmerge-paralleliser — Split large commits into classified batches and push in parallel
//!
//! Classifies changed files into categories (docs, code, data, assets, config, ci),
//! creates one commit per category, and pushes all commits in parallel using
//! async subprocess spawning (equivalent to pssh-style parallelism).
//!
//! This enables granular GitHub web review: reviewers can approve documentation
//! changes independently of code, or merge config fixes without waiting for
//! large data files to finish uploading.
//!
//! Usage:
//!   gitmerge-paralleliser classify <REPO>           # Preview classification
//!   gitmerge-paralleliser split <REPO> [--prefix]   # Split into per-category commits
//!   gitmerge-paralleliser push <REPO> [--parallel]  # Push all branches in parallel
//!   gitmerge-paralleliser run <REPO>                # classify + split + push (full pipeline)

#![forbid(unsafe_code)]

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use tokio::process::Command;

mod classifier;
mod splitter;

use classifier::{classify_files, FileClass};

/// gitmerge-paralleliser — Classified parallel git push
#[derive(Parser)]
#[command(name = "gitmerge-paralleliser", version, about)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Preview how changed files would be classified
    Classify {
        /// Path to the git repository
        #[arg(default_value = ".")]
        repo: PathBuf,
    },

    /// Split staged/unstaged changes into per-category commits on separate branches
    Split {
        /// Path to the git repository
        #[arg(default_value = ".")]
        repo: PathBuf,

        /// Branch prefix for category branches (e.g. "batch/" → "batch/docs", "batch/code")
        #[arg(long, default_value = "batch/")]
        prefix: String,

        /// Commit message prefix
        #[arg(long, default_value = "chore: batch update")]
        message: String,

        /// Author string (Name <email>)
        #[arg(long)]
        author: Option<String>,
    },

    /// Push all batch/* branches in parallel
    Push {
        /// Path to the git repository
        #[arg(default_value = ".")]
        repo: PathBuf,

        /// Branch prefix to match
        #[arg(long, default_value = "batch/")]
        prefix: String,

        /// Maximum parallel pushes
        #[arg(long, default_value = "8")]
        parallel: usize,

        /// Remote name
        #[arg(long, default_value = "origin")]
        remote: String,

        /// Force push
        #[arg(long)]
        force: bool,

        /// Dry run — show what would be pushed without actually pushing
        #[arg(long)]
        dry_run: bool,
    },

    /// Full pipeline: classify → split → push
    Run {
        /// Path to the git repository
        #[arg(default_value = ".")]
        repo: PathBuf,

        /// Branch prefix
        #[arg(long, default_value = "batch/")]
        prefix: String,

        /// Commit message prefix
        #[arg(long, default_value = "chore: batch update")]
        message: String,

        /// Maximum parallel pushes
        #[arg(long, default_value = "8")]
        parallel: usize,

        /// Remote name
        #[arg(long, default_value = "origin")]
        remote: String,

        /// Author string
        #[arg(long)]
        author: Option<String>,

        /// Force push
        #[arg(long)]
        force: bool,
    },

    /// List repos with uncommitted changes under a parent directory
    Scan {
        /// Parent directory containing multiple repos
        #[arg(default_value = ".")]
        parent: PathBuf,

        /// Only show repos with at least this many changes
        #[arg(long, default_value = "1")]
        min_changes: usize,
    },

    /// Run classify + split + push across multiple repos in parallel
    Multi {
        /// Parent directory containing multiple repos
        parent: PathBuf,

        /// Branch prefix
        #[arg(long, default_value = "batch/")]
        prefix: String,

        /// Commit message prefix
        #[arg(long, default_value = "chore: batch update")]
        message: String,

        /// Maximum parallel repo operations
        #[arg(long, default_value = "4")]
        parallel_repos: usize,

        /// Maximum parallel pushes per repo
        #[arg(long, default_value = "6")]
        parallel_pushes: usize,

        /// Remote name
        #[arg(long, default_value = "origin")]
        remote: String,

        /// Author string
        #[arg(long)]
        author: Option<String>,

        /// Force push
        #[arg(long)]
        force: bool,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();

    let cli = Cli::parse();

    match cli.command {
        Commands::Classify { repo } => {
            let classified = classify_repo(&repo).await?;
            print_classification(&classified);
        }

        Commands::Split {
            repo,
            prefix,
            message,
            author,
        } => {
            let classified = classify_repo(&repo).await?;
            print_classification(&classified);
            let branches =
                splitter::split_into_branches(&repo, &classified, &prefix, &message, author.as_deref())
                    .await?;
            println!("\nCreated {} branches:", branches.len());
            for b in &branches {
                println!("  {b}");
            }
        }

        Commands::Push {
            repo,
            prefix,
            parallel,
            remote,
            force,
            dry_run,
        } => {
            let branches = list_batch_branches(&repo, &prefix).await?;
            if branches.is_empty() {
                println!("No branches matching prefix '{prefix}' found.");
                return Ok(());
            }
            println!("Pushing {} branches (max {} parallel):", branches.len(), parallel);
            if dry_run {
                for b in &branches {
                    println!("  [dry-run] would push {b} → {remote}/{b}");
                }
            } else {
                push_parallel(&repo, &branches, &remote, parallel, force).await?;
            }
        }

        Commands::Run {
            repo,
            prefix,
            message,
            parallel,
            remote,
            author,
            force,
        } => {
            let classified = classify_repo(&repo).await?;
            print_classification(&classified);

            let branches =
                splitter::split_into_branches(&repo, &classified, &prefix, &message, author.as_deref())
                    .await?;
            println!("\nCreated {} branches, pushing in parallel:", branches.len());
            push_parallel(&repo, &branches, &remote, parallel, force).await?;
        }

        Commands::Scan { parent, min_changes } => {
            scan_repos(&parent, min_changes).await?;
        }

        Commands::Multi {
            parent,
            prefix,
            message,
            parallel_repos,
            parallel_pushes,
            remote,
            author,
            force,
        } => {
            multi_repo_run(
                &parent,
                &prefix,
                &message,
                parallel_repos,
                parallel_pushes,
                &remote,
                author.as_deref(),
                force,
            )
            .await?;
        }
    }

    Ok(())
}

/// Classify all changed files in a repo
async fn classify_repo(repo: &Path) -> Result<BTreeMap<FileClass, Vec<String>>> {
    let output = Command::new("git")
        .args(["status", "--porcelain"])
        .current_dir(repo)
        .output()
        .await
        .context("Failed to run git status")?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let files: Vec<String> = stdout
        .lines()
        .filter(|l| !l.is_empty())
        .map(|line| {
            // git status --porcelain format: XY filename
            // Handle renames: "R  old -> new"
            let raw = &line[3..];
            if let Some(arrow) = raw.find(" -> ") {
                raw[arrow + 4..].to_string()
            } else {
                raw.to_string()
            }
        })
        .collect();

    Ok(classify_files(&files))
}

/// Pretty-print the classification
fn print_classification(classified: &BTreeMap<FileClass, Vec<String>>) {
    let total: usize = classified.values().map(|v| v.len()).sum();
    println!("Classified {total} files:\n");
    for (class, files) in classified {
        println!("  {} ({} files):", class.label(), files.len());
        for f in files.iter().take(10) {
            println!("    {f}");
        }
        if files.len() > 10 {
            println!("    ... and {} more", files.len() - 10);
        }
        println!();
    }
}

/// List branches matching a prefix
async fn list_batch_branches(repo: &Path, prefix: &str) -> Result<Vec<String>> {
    let output = Command::new("git")
        .args(["branch", "--list", &format!("{prefix}*")])
        .current_dir(repo)
        .output()
        .await?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    Ok(stdout
        .lines()
        .map(|l| l.trim().trim_start_matches("* ").to_string())
        .filter(|l| !l.is_empty())
        .collect())
}

/// Push multiple branches in parallel with bounded concurrency
async fn push_parallel(
    repo: &Path,
    branches: &[String],
    remote: &str,
    max_parallel: usize,
    force: bool,
) -> Result<()> {
    use tokio::sync::Semaphore;
    let sem = std::sync::Arc::new(Semaphore::new(max_parallel));
    let mut handles = Vec::new();

    for branch in branches {
        let sem = sem.clone();
        let repo = repo.to_path_buf();
        let remote = remote.to_string();
        let branch = branch.clone();
        let force = force;

        handles.push(tokio::spawn(async move {
            let _permit = sem.acquire().await.unwrap();
            let mut args = vec!["push", "-u"];
            if force {
                args.push("--force");
            }
            let refspec = format!("{branch}:{branch}");
            args.push(&remote);
            args.push(&refspec);

            tracing::info!("Pushing {branch} → {remote}/{branch}");
            let output = Command::new("git")
                .args(&args)
                .current_dir(&repo)
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .output()
                .await;

            match output {
                Ok(o) if o.status.success() => {
                    println!("  ✓ {branch}");
                    Ok(())
                }
                Ok(o) => {
                    let stderr = String::from_utf8_lossy(&o.stderr);
                    eprintln!("  ✗ {branch}: {stderr}");
                    Err(anyhow::anyhow!("push failed for {branch}"))
                }
                Err(e) => {
                    eprintln!("  ✗ {branch}: {e}");
                    Err(e.into())
                }
            }
        }));
    }

    let mut failures = 0;
    for h in handles {
        if let Err(_) = h.await? {
            failures += 1;
        }
    }

    if failures > 0 {
        eprintln!("\n{failures}/{} pushes failed", branches.len());
    } else {
        println!("\nAll {} branches pushed successfully", branches.len());
    }

    Ok(())
}

/// Scan a parent directory for repos with uncommitted changes
async fn scan_repos(parent: &Path, min_changes: usize) -> Result<()> {
    let mut entries: Vec<_> = std::fs::read_dir(parent)?
        .filter_map(|e| e.ok())
        .filter(|e| e.path().join(".git").exists())
        .collect();
    entries.sort_by_key(|e| e.file_name());

    println!("Scanning {} for repos with changes...\n", parent.display());

    for entry in entries {
        let repo = entry.path();
        let output = Command::new("git")
            .args(["status", "--porcelain"])
            .current_dir(&repo)
            .output()
            .await?;

        let count = String::from_utf8_lossy(&output.stdout)
            .lines()
            .filter(|l| !l.is_empty())
            .count();

        if count >= min_changes {
            let classified = classify_repo(&repo).await?;
            let classes: Vec<String> = classified
                .iter()
                .map(|(c, f)| format!("{}:{}", c.short(), f.len()))
                .collect();
            println!(
                "  {:40} {:>4} files  [{}]",
                entry.file_name().to_string_lossy(),
                count,
                classes.join(", ")
            );
        }
    }

    Ok(())
}

/// Run the full pipeline across multiple repos in parallel
async fn multi_repo_run(
    parent: &Path,
    prefix: &str,
    message: &str,
    parallel_repos: usize,
    _parallel_pushes: usize,
    remote: &str,
    author: Option<&str>,
    _force: bool,
) -> Result<()> {
    use tokio::sync::Semaphore;

    let mut repos: Vec<PathBuf> = std::fs::read_dir(parent)?
        .filter_map(|e| e.ok())
        .filter(|e| e.path().join(".git").exists())
        .map(|e| e.path())
        .collect();
    repos.sort();

    // Filter to repos with changes
    let mut dirty_repos = Vec::new();
    for repo in &repos {
        let output = Command::new("git")
            .args(["status", "--porcelain"])
            .current_dir(repo)
            .output()
            .await?;
        let count = String::from_utf8_lossy(&output.stdout)
            .lines()
            .filter(|l| !l.is_empty())
            .count();
        if count > 0 {
            dirty_repos.push(repo.clone());
        }
    }

    println!(
        "Processing {} repos with changes (max {} parallel):\n",
        dirty_repos.len(),
        parallel_repos
    );

    let sem = std::sync::Arc::new(Semaphore::new(parallel_repos));
    let mut handles = Vec::new();

    for repo in dirty_repos {
        let sem = sem.clone();
        let prefix = prefix.to_string();
        let message = message.to_string();
        let remote = remote.to_string();
        let author = author.map(|s| s.to_string());

        handles.push(tokio::spawn(async move {
            let _permit = sem.acquire().await.unwrap();
            let name = repo.file_name().unwrap().to_string_lossy().to_string();
            println!("▶ {name}");

            // Classify
            let classified = match classify_repo_inner(&repo).await {
                Ok(c) => c,
                Err(e) => {
                    eprintln!("  ✗ {name}: classify failed: {e}");
                    return;
                }
            };

            // Split
            let branches = match splitter::split_into_branches(
                &repo,
                &classified,
                &prefix,
                &message,
                author.as_deref(),
            )
            .await
            {
                Ok(b) => b,
                Err(e) => {
                    eprintln!("  ✗ {name}: split failed: {e}");
                    return;
                }
            };

            // Push
            if let Err(e) =
                push_parallel_inner(&repo, &branches, &remote, 6, false).await
            {
                eprintln!("  ✗ {name}: push failed: {e}");
                return;
            }

            println!("  ✓ {name}: {} categories pushed", branches.len());
        }));
    }

    for h in handles {
        let _ = h.await;
    }

    println!("\nDone.");
    Ok(())
}

/// Inner classify (for use inside spawned tasks)
async fn classify_repo_inner(repo: &Path) -> Result<BTreeMap<FileClass, Vec<String>>> {
    classify_repo(repo).await
}

/// Inner push (for use inside spawned tasks)
async fn push_parallel_inner(
    repo: &Path,
    branches: &[String],
    remote: &str,
    max_parallel: usize,
    force: bool,
) -> Result<()> {
    push_parallel(repo, branches, remote, max_parallel, force).await
}
