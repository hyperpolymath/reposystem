// SPDX-License-Identifier: PMPL-2.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// git-seo — GitHub repository SEO toolkit.
//
// Automates the discoverability of GitHub repositories:
//   git-seo audit    — check topics, description, homepage, README quality
//   git-seo apply    — set topics/description/homepage from a manifest
//   git-seo batch    — apply SEO to multiple repos from a TOML config
//   git-seo report   — generate a discoverability score report
//
// Uses `gh` CLI under the hood for GitHub API calls.

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use std::fs;
use std::process::Command;

/// git-seo — make your GitHub repos discoverable
#[derive(Parser)]
#[command(name = "git-seo", version, about)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Audit a repo's SEO: topics, description, homepage, README.
    Audit {
        /// GitHub repo (owner/name)
        repo: String,
    },
    /// Apply SEO settings from command-line args.
    Apply {
        /// GitHub repo (owner/name)
        repo: String,
        /// Comma-separated topics
        #[arg(short, long)]
        topics: Option<String>,
        /// Repository description
        #[arg(short, long)]
        description: Option<String>,
        /// Homepage URL
        #[arg(long)]
        homepage: Option<String>,
    },
    /// Apply SEO to multiple repos from a TOML manifest.
    Batch {
        /// Path to git-seo.toml manifest
        #[arg(short, long, default_value = "git-seo.toml")]
        manifest: String,
    },
    /// Generate a discoverability score report for a repo or org.
    Report {
        /// GitHub org or owner
        owner: String,
        /// Output format: text, json, markdown
        #[arg(short, long, default_value = "text")]
        format: String,
    },
}

/// Manifest for batch SEO operations.
#[derive(Debug, Deserialize, Serialize)]
struct SeoManifest {
    /// Default settings applied to all repos.
    #[serde(default)]
    defaults: SeoDefaults,
    /// Per-repo overrides.
    #[serde(default)]
    repos: Vec<RepoSeo>,
}

#[derive(Debug, Deserialize, Serialize, Default)]
struct SeoDefaults {
    /// Topics applied to all repos (in addition to repo-specific).
    #[serde(default)]
    topics: Vec<String>,
    /// Default homepage URL.
    #[serde(default)]
    homepage: Option<String>,
}

#[derive(Debug, Deserialize, Serialize)]
struct RepoSeo {
    /// Repo name (without owner, e.g., "chapeliser").
    name: String,
    /// Description override.
    #[serde(default)]
    description: Option<String>,
    /// Topics (merged with defaults).
    #[serde(default)]
    topics: Vec<String>,
    /// Homepage override.
    #[serde(default)]
    homepage: Option<String>,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Audit { repo } => audit_repo(&repo)?,
        Commands::Apply {
            repo,
            topics,
            description,
            homepage,
        } => apply_seo(&repo, topics.as_deref(), description.as_deref(), homepage.as_deref())?,
        Commands::Batch { manifest } => batch_apply(&manifest)?,
        Commands::Report { owner, format } => generate_report(&owner, &format)?,
    }

    Ok(())
}

/// Audit a single repo's SEO settings.
fn audit_repo(repo: &str) -> Result<()> {
    println!("Auditing SEO for: {repo}");
    println!();

    let output = Command::new("gh")
        .args([
            "repo", "view", repo, "--json",
            "description,repositoryTopics,homepageUrl,hasWikiEnabled,licenseInfo,stargazerCount",
        ])
        .output()
        .context("Failed to run gh CLI — is it installed?")?;

    if !output.status.success() {
        anyhow::bail!("gh repo view failed: {}", String::from_utf8_lossy(&output.stderr));
    }

    let info: serde_json::Value = serde_json::from_slice(&output.stdout)?;

    let mut score = 0u32;
    let max_score = 100u32;

    // Description (20 points)
    let desc = info["description"].as_str().unwrap_or("");
    if desc.is_empty() {
        println!("  [  0/20] Description: MISSING");
    } else if desc.len() < 30 {
        println!("  [ 10/20] Description: too short ({} chars, aim for 50+)", desc.len());
        score += 10;
    } else {
        println!("  [ 20/20] Description: OK ({} chars)", desc.len());
        score += 20;
    }

    // Topics (25 points)
    let topics = info["repositoryTopics"]
        .as_array()
        .map(|a| a.len())
        .unwrap_or(0);
    if topics == 0 {
        println!("  [  0/25] Topics: NONE — add at least 5");
    } else if topics < 3 {
        println!("  [ 10/25] Topics: only {topics} — add more for discoverability");
        score += 10;
    } else if topics < 6 {
        println!("  [ 18/25] Topics: {topics} (good, aim for 6+)");
        score += 18;
    } else {
        println!("  [ 25/25] Topics: {topics} (excellent)");
        score += 25;
    }

    // Homepage (15 points)
    let homepage = info["homepageUrl"].as_str().unwrap_or("");
    if homepage.is_empty() {
        println!("  [  0/15] Homepage: MISSING");
    } else {
        println!("  [ 15/15] Homepage: {homepage}");
        score += 15;
    }

    // License (15 points)
    let license = info["licenseInfo"]["name"].as_str().unwrap_or("none");
    if license == "none" {
        println!("  [  0/15] License: MISSING — repos without licenses get less traffic");
    } else {
        println!("  [ 15/15] License: {license}");
        score += 15;
    }

    // Stars (10 points)
    let stars = info["stargazerCount"].as_u64().unwrap_or(0);
    if stars == 0 {
        println!("  [  0/10] Stars: 0 — star your own repo for a baseline");
    } else if stars < 5 {
        println!("  [  5/10] Stars: {stars}");
        score += 5;
    } else {
        println!("  [ 10/10] Stars: {stars}");
        score += 10;
    }

    // README exists (15 points) — check via API
    let readme_check = Command::new("gh")
        .args(["api", &format!("repos/{repo}/readme"), "--jq", ".size"])
        .output();
    if let Ok(out) = readme_check {
        if out.status.success() {
            let size: usize = String::from_utf8_lossy(&out.stdout)
                .trim()
                .parse()
                .unwrap_or(0);
            if size > 1000 {
                println!("  [ 15/15] README: {size} bytes (good)");
                score += 15;
            } else if size > 0 {
                println!("  [  8/15] README: {size} bytes (too short, aim for 1000+)");
                score += 8;
            } else {
                println!("  [  0/15] README: empty");
            }
        } else {
            println!("  [  0/15] README: MISSING");
        }
    }

    println!();
    println!("  SEO Score: {score}/{max_score}");

    if score >= 80 {
        println!("  Grade: A — excellent discoverability");
    } else if score >= 60 {
        println!("  Grade: B — good, minor improvements needed");
    } else if score >= 40 {
        println!("  Grade: C — fair, several improvements needed");
    } else {
        println!("  Grade: D — poor, significant work needed");
    }

    Ok(())
}

/// Apply SEO settings to a repo.
fn apply_seo(
    repo: &str,
    topics: Option<&str>,
    description: Option<&str>,
    homepage: Option<&str>,
) -> Result<()> {
    if let Some(desc) = description {
        let status = Command::new("gh")
            .args(["repo", "edit", repo, "--description", desc])
            .status()?;
        if status.success() {
            println!("  Set description: {desc}");
        }
    }

    if let Some(url) = homepage {
        let status = Command::new("gh")
            .args(["repo", "edit", repo, "--homepage", url])
            .status()?;
        if status.success() {
            println!("  Set homepage: {url}");
        }
    }

    if let Some(topic_str) = topics {
        let topic_list: Vec<&str> = topic_str.split(',').map(|t| t.trim()).collect();
        let json_arr = format!(
            "{{\"names\": [{}]}}",
            topic_list
                .iter()
                .map(|t| format!("\"{}\"", t))
                .collect::<Vec<_>>()
                .join(",")
        );
        let status = Command::new("gh")
            .args([
                "api",
                &format!("repos/{repo}/topics"),
                "-X",
                "PUT",
                "--input",
                "-",
            ])
            .stdin(std::process::Stdio::piped())
            .spawn()
            .and_then(|mut child| {
                if let Some(stdin) = child.stdin.as_mut() {
                    use std::io::Write;
                    stdin.write_all(json_arr.as_bytes())?;
                }
                child.wait()
            })?;
        if status.success() {
            println!("  Set {} topics", topic_list.len());
        }
    }

    Ok(())
}

/// Apply SEO to multiple repos from a manifest.
fn batch_apply(manifest_path: &str) -> Result<()> {
    let content = fs::read_to_string(manifest_path)
        .with_context(|| format!("Failed to read: {manifest_path}"))?;
    let manifest: SeoManifest = toml::from_str(&content)?;

    println!("Batch SEO: {} repos", manifest.repos.len());
    println!();

    for repo_seo in &manifest.repos {
        let full_name = if repo_seo.name.contains('/') {
            repo_seo.name.clone()
        } else {
            // Assume same owner as first repo or hyperpolymath
            format!("hyperpolymath/{}", repo_seo.name)
        };

        println!("--- {full_name} ---");

        // Merge topics: defaults + repo-specific
        let mut all_topics = manifest.defaults.topics.clone();
        all_topics.extend(repo_seo.topics.iter().cloned());
        all_topics.sort();
        all_topics.dedup();

        let topics_str = if all_topics.is_empty() {
            None
        } else {
            Some(all_topics.join(","))
        };

        let homepage = repo_seo
            .homepage
            .as_deref()
            .or(manifest.defaults.homepage.as_deref());

        apply_seo(
            &full_name,
            topics_str.as_deref(),
            repo_seo.description.as_deref(),
            homepage,
        )?;

        println!();
    }

    Ok(())
}

/// Generate a discoverability report for an entire org.
fn generate_report(owner: &str, format: &str) -> Result<()> {
    let output = Command::new("gh")
        .args([
            "repo",
            "list",
            owner,
            "--limit",
            "500",
            "--json",
            "name,description,repositoryTopics,homepageUrl,stargazerCount,isArchived",
        ])
        .output()
        .context("Failed to list repos")?;

    if !output.status.success() {
        anyhow::bail!("gh repo list failed");
    }

    let repos: Vec<serde_json::Value> = serde_json::from_slice(&output.stdout)?;
    let active: Vec<&serde_json::Value> = repos
        .iter()
        .filter(|r| !r["isArchived"].as_bool().unwrap_or(false))
        .collect();

    let total = active.len();
    let with_desc = active.iter().filter(|r| {
        r["description"].as_str().map(|s| !s.is_empty()).unwrap_or(false)
    }).count();
    let with_topics = active.iter().filter(|r| {
        r["repositoryTopics"].as_array().map(|a| !a.is_empty()).unwrap_or(false)
    }).count();
    let with_homepage = active.iter().filter(|r| {
        r["homepageUrl"].as_str().map(|s| !s.is_empty()).unwrap_or(false)
    }).count();
    let starred = active.iter().filter(|r| {
        r["stargazerCount"].as_u64().unwrap_or(0) > 0
    }).count();

    match format {
        "json" => {
            let report = serde_json::json!({
                "owner": owner,
                "total_repos": total,
                "with_description": with_desc,
                "with_topics": with_topics,
                "with_homepage": with_homepage,
                "starred": starred,
                "score": (with_desc + with_topics + with_homepage + starred) * 100 / (total * 4).max(1),
            });
            println!("{}", serde_json::to_string_pretty(&report)?);
        }
        "markdown" => {
            println!("# SEO Report: {owner}");
            println!();
            println!("| Metric | Count | % |");
            println!("|--------|-------|---|");
            println!("| Total repos | {total} | — |");
            println!("| With description | {with_desc} | {}% |", with_desc * 100 / total.max(1));
            println!("| With topics | {with_topics} | {}% |", with_topics * 100 / total.max(1));
            println!("| With homepage | {with_homepage} | {}% |", with_homepage * 100 / total.max(1));
            println!("| Starred | {starred} | {}% |", starred * 100 / total.max(1));
        }
        _ => {
            println!("SEO Report: {owner}");
            println!("  Total repos:      {total}");
            println!("  With description: {with_desc} ({}%)", with_desc * 100 / total.max(1));
            println!("  With topics:      {with_topics} ({}%)", with_topics * 100 / total.max(1));
            println!("  With homepage:    {with_homepage} ({}%)", with_homepage * 100 / total.max(1));
            println!("  Starred:          {starred} ({}%)", starred * 100 / total.max(1));
            let overall = (with_desc + with_topics + with_homepage + starred) * 100 / (total * 4).max(1);
            println!("  Overall SEO:      {overall}%");
        }
    }

    Ok(())
}
