//! RSR CLI and Server
//!
//! Run compliance checks locally or start the webhook server.

use clap::{Parser, Subcommand};
use rsr_engine::{CertificationTier, ComplianceEngine};
use std::path::PathBuf;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[derive(Parser)]
#[command(name = "rsr")]
#[command(author, version, about = "Rhodium Standard Repository Compliance Engine")]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Log level (trace, debug, info, warn, error)
    #[arg(long, default_value = "info", global = true)]
    log_level: String,
}

#[derive(Subcommand)]
enum Commands {
    /// Check compliance of a local repository
    Check {
        /// Path to repository (defaults to current directory)
        #[arg(default_value = ".")]
        path: PathBuf,

        /// Target certification tier
        #[arg(short, long, default_value = "gold")]
        tier: String,

        /// Output format (text, json, badge)
        #[arg(short, long, default_value = "text")]
        format: String,

        /// Strict mode - exit with error if target tier not met
        #[arg(long)]
        strict: bool,
    },

    /// Start the webhook server
    Serve {
        /// Host to bind to
        #[arg(short = 'H', long, default_value = "0.0.0.0")]
        host: String,

        /// Port to listen on
        #[arg(short, long, default_value = "8080")]
        port: u16,

        /// Platforms to enable (comma-separated)
        #[arg(long, default_value = "github,gitlab,bitbucket")]
        platforms: String,
    },

    /// Generate a compliance badge
    Badge {
        /// Certification tier
        tier: String,

        /// Output file (stdout if not specified)
        #[arg(short, long)]
        output: Option<PathBuf>,

        /// Badge style (flat, flat-square, for-the-badge)
        #[arg(short, long, default_value = "flat")]
        style: String,
    },

    /// Initialize RSR configuration in a repository
    Init {
        /// Path to repository (defaults to current directory)
        #[arg(default_value = ".")]
        path: PathBuf,

        /// Target tier for configuration
        #[arg(short, long, default_value = "silver")]
        tier: String,
    },
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    // Initialize logging
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| format!("rsr={}", cli.log_level).into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    match cli.command {
        Commands::Check {
            path,
            tier,
            format,
            strict,
        } => {
            run_check(&path, &tier, &format, strict).await?;
        }
        Commands::Serve {
            host,
            port,
            platforms,
        } => {
            run_server(&host, port, &platforms).await?;
        }
        Commands::Badge {
            tier,
            output,
            style,
        } => {
            generate_badge(&tier, output.as_deref(), &style)?;
        }
        Commands::Init { path, tier } => {
            init_config(&path, &tier)?;
        }
    }

    Ok(())
}

async fn run_check(path: &PathBuf, tier: &str, format: &str, strict: bool) -> anyhow::Result<()> {
    let engine = ComplianceEngine::new();
    let target_tier = parse_tier(tier)?;

    tracing::info!("Checking compliance for: {}", path.display());
    tracing::info!("Target tier: {}", target_tier);

    let status = engine.check_local(path).await?;

    match format {
        "json" => {
            println!("{}", serde_json::to_string_pretty(&status)?);
        }
        "badge" => {
            let badge = generate_badge_svg(&status.tier, "flat");
            println!("{}", badge);
        }
        _ => {
            print_status(&status);
        }
    }

    if strict && status.tier < target_tier {
        tracing::error!(
            "Compliance check failed: achieved {} but target was {}",
            status.tier,
            target_tier
        );
        std::process::exit(1);
    }

    Ok(())
}

async fn run_server(host: &str, port: u16, platforms: &str) -> anyhow::Result<()> {
    let enabled_platforms: Vec<&str> = platforms.split(',').map(|s| s.trim()).collect();

    tracing::info!("Starting RSR server on {}:{}", host, port);
    tracing::info!("Enabled platforms: {:?}", enabled_platforms);

    rsr_engine::server::run(host, port, &enabled_platforms).await?;

    Ok(())
}

fn generate_badge(tier: &str, output: Option<&std::path::Path>, style: &str) -> anyhow::Result<()> {
    let cert_tier = parse_tier(tier)?;
    let svg = generate_badge_svg(&cert_tier, style);

    match output {
        Some(path) => {
            std::fs::write(path, &svg)?;
            tracing::info!("Badge written to: {}", path.display());
        }
        None => {
            println!("{}", svg);
        }
    }

    Ok(())
}

fn init_config(path: &PathBuf, tier: &str) -> anyhow::Result<()> {
    let config_path = path.join(".rsr.toml");

    if config_path.exists() {
        tracing::warn!("Configuration already exists at: {}", config_path.display());
        return Ok(());
    }

    let config = format!(
        r#"# RSR (Rhodium Standard Repository) Configuration
# https://github.com/Hyperpolymath/git-rsr-certified

[compliance]
target_tier = "{tier}"
strict_mode = false

[checks]
# License configuration
license.required = true
license.allowed = ["MIT", "Apache-2.0", "GPL-3.0", "BSD-3-Clause"]

# README requirements
readme.min_length = 100

[ignore]
# Paths to exclude from compliance scanning
paths = [
    "vendor/",
    "third_party/",
    "node_modules/",
    ".git/",
]

[badges]
style = "flat-square"
include_score = true
"#
    );

    std::fs::write(&config_path, config)?;
    tracing::info!("Configuration written to: {}", config_path.display());

    Ok(())
}

fn parse_tier(tier: &str) -> anyhow::Result<CertificationTier> {
    match tier.to_lowercase().as_str() {
        "none" => Ok(CertificationTier::None),
        "bronze" | "cu" => Ok(CertificationTier::Bronze),
        "silver" | "ag" => Ok(CertificationTier::Silver),
        "gold" | "au" => Ok(CertificationTier::Gold),
        "rhodium" | "rh" => Ok(CertificationTier::Rhodium),
        _ => anyhow::bail!("Unknown tier: {}. Use: none, bronze, silver, gold, rhodium", tier),
    }
}

fn print_status(status: &rsr_engine::ComplianceStatus) {
    println!("\n{}", "=".repeat(60));
    println!("RSR Compliance Report");
    println!("{}", "=".repeat(60));
    println!("\nRepository: {}", status.repo);
    println!("Tier: {}", status.tier);
    println!("Score: {:.1}%", status.score * 100.0);
    println!("\nChecks:");
    println!("{}", "-".repeat(60));

    for check in &status.checks {
        let icon = if check.passed { "✓" } else { "✗" };
        let tier_indicator = format!("[{}]", check.tier.code());
        println!(
            "  {} {:12} {} - {}",
            icon, tier_indicator, check.name, check.message
        );
        if let Some(ref details) = check.details {
            for line in details.lines() {
                println!("              {}", line);
            }
        }
    }

    println!("{}", "-".repeat(60));
    println!();
}

fn generate_badge_svg(tier: &CertificationTier, _style: &str) -> String {
    let color = tier.color();
    let label = tier.code();

    format!(
        r##"<svg xmlns="https://www.w3.org/2000/svg" width="120" height="20">
<linearGradient id="b" x2="0" y2="100%">
<stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
<stop offset="1" stop-opacity=".1"/>
</linearGradient>
<clipPath id="a">
<rect width="120" height="20" rx="3" fill="#fff"/>
</clipPath>
<g clip-path="url(#a)">
<path fill="#555" d="M0 0h45v20H0z"/>
<path fill="{}" d="M45 0h75v20H45z"/>
<path fill="url(#b)" d="M0 0h120v20H0z"/>
</g>
<g fill="#fff" text-anchor="middle" font-family="Verdana,sans-serif" font-size="11">
<text x="22.5" y="15" fill="#010101" fill-opacity=".3">RSR</text>
<text x="22.5" y="14">RSR</text>
<text x="82.5" y="15" fill="#010101" fill-opacity=".3">{}</text>
<text x="82.5" y="14">{}</text>
</g>
</svg>"##,
        color, label, label
    )
}
