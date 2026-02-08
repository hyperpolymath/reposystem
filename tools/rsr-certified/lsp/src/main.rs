//! RSR Language Server Protocol Implementation
//!
//! Provides IDE integration for real-time RSR compliance checking.

use serde::{Deserialize, Serialize};
use serde_json::Value;
use tower_lsp::jsonrpc::Result;
use tower_lsp::lsp_types::*;
use tower_lsp::{Client, LanguageServer, LspService, Server};

#[derive(Debug)]
struct RsrLanguageServer {
    client: Client,
}

#[derive(Debug, Serialize, Deserialize)]
struct RsrComplianceResult {
    tier: String,
    tier_code: String,
    score: f32,
    checks: Vec<RsrCheckResult>,
}

#[derive(Debug, Serialize, Deserialize)]
struct RsrCheckResult {
    id: String,
    name: String,
    passed: bool,
    message: String,
}

#[tower_lsp::async_trait]
impl LanguageServer for RsrLanguageServer {
    async fn initialize(&self, _: InitializeParams) -> Result<InitializeResult> {
        Ok(InitializeResult {
            capabilities: ServerCapabilities {
                text_document_sync: Some(TextDocumentSyncCapability::Kind(
                    TextDocumentSyncKind::INCREMENTAL,
                )),
                diagnostic_provider: Some(DiagnosticServerCapabilities::Options(
                    DiagnosticOptions {
                        identifier: Some("rsr".to_string()),
                        inter_file_dependencies: false,
                        workspace_diagnostics: true,
                        ..Default::default()
                    },
                )),
                execute_command_provider: Some(ExecuteCommandOptions {
                    commands: vec![
                        "rsr.checkCompliance".to_string(),
                        "rsr.generateBadge".to_string(),
                        "rsr.initConfig".to_string(),
                    ],
                    ..Default::default()
                }),
                ..Default::default()
            },
            server_info: Some(ServerInfo {
                name: "RSR Language Server".to_string(),
                version: Some(env!("CARGO_PKG_VERSION").to_string()),
            }),
        })
    }

    async fn initialized(&self, _: InitializedParams) {
        self.client
            .log_message(MessageType::INFO, "RSR Language Server initialized")
            .await;
    }

    async fn shutdown(&self) -> Result<()> {
        Ok(())
    }

    async fn did_open(&self, params: DidOpenTextDocumentParams) {
        // Check if this is an RSR-relevant file
        let uri = params.text_document.uri;
        if is_rsr_relevant(&uri.path()) {
            self.run_compliance_check(&uri).await;
        }
    }

    async fn did_save(&self, params: DidSaveTextDocumentParams) {
        let uri = params.text_document.uri;
        if is_rsr_relevant(&uri.path()) {
            self.run_compliance_check(&uri).await;
        }
    }

    async fn execute_command(&self, params: ExecuteCommandParams) -> Result<Option<Value>> {
        match params.command.as_str() {
            "rsr.checkCompliance" => {
                self.client
                    .log_message(MessageType::INFO, "Running RSR compliance check...")
                    .await;

                // TODO: Run actual compliance check
                let result = RsrComplianceResult {
                    tier: "Silver".to_string(),
                    tier_code: "RSR-Ag".to_string(),
                    score: 0.75,
                    checks: vec![],
                };

                Ok(Some(serde_json::to_value(result).unwrap()))
            }
            "rsr.generateBadge" => {
                self.client
                    .log_message(MessageType::INFO, "Generating RSR badge...")
                    .await;

                // TODO: Generate badge
                Ok(Some(Value::String("Badge generated".to_string())))
            }
            "rsr.initConfig" => {
                self.client
                    .log_message(MessageType::INFO, "Initializing RSR configuration...")
                    .await;

                // TODO: Create .rsr.toml
                Ok(Some(Value::String("Configuration initialized".to_string())))
            }
            _ => Ok(None),
        }
    }
}

impl RsrLanguageServer {
    fn new(client: Client) -> Self {
        Self { client }
    }

    async fn run_compliance_check(&self, uri: &Url) {
        let path = uri.path();

        // Get workspace root
        let workspace_root = std::path::Path::new(path)
            .ancestors()
            .find(|p| p.join(".git").exists())
            .unwrap_or(std::path::Path::new(path).parent().unwrap_or(std::path::Path::new(".")));

        self.client
            .log_message(
                MessageType::INFO,
                format!("Running RSR check on: {}", workspace_root.display()),
            )
            .await;

        // Run compliance check
        let engine = rsr_engine::ComplianceEngine::new();
        match engine.check_local(workspace_root).await {
            Ok(status) => {
                // Convert to diagnostics
                let diagnostics: Vec<Diagnostic> = status
                    .checks
                    .iter()
                    .filter(|c| !c.passed)
                    .map(|check| {
                        Diagnostic {
                            range: Range::default(), // Would need proper location mapping
                            severity: Some(match check.tier {
                                rsr_engine::CertificationTier::Bronze => DiagnosticSeverity::ERROR,
                                rsr_engine::CertificationTier::Silver => DiagnosticSeverity::WARNING,
                                _ => DiagnosticSeverity::INFORMATION,
                            }),
                            code: Some(NumberOrString::String(check.id.clone())),
                            source: Some("rsr".to_string()),
                            message: format!("[{}] {}: {}", check.tier.code(), check.name, check.message),
                            ..Default::default()
                        }
                    })
                    .collect();

                // Publish diagnostics
                self.client
                    .publish_diagnostics(uri.clone(), diagnostics, None)
                    .await;

                // Show summary
                self.client
                    .log_message(
                        MessageType::INFO,
                        format!(
                            "RSR Compliance: {} ({:.0}%)",
                            status.tier.code(),
                            status.score * 100.0
                        ),
                    )
                    .await;
            }
            Err(e) => {
                self.client
                    .log_message(MessageType::ERROR, format!("RSR check failed: {}", e))
                    .await;
            }
        }
    }
}

/// Check if a file is relevant for RSR compliance checking
fn is_rsr_relevant(path: &str) -> bool {
    let relevant_files = [
        "LICENSE",
        "README",
        "CONTRIBUTING",
        "CHANGELOG",
        "SECURITY",
        "CODE_OF_CONDUCT",
        ".rsr.toml",
        ".gitignore",
        "Cargo.toml",
        "package.json",
        "pyproject.toml",
    ];

    let filename = std::path::Path::new(path)
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("");

    relevant_files.iter().any(|f| filename.starts_with(f))
        || path.contains(".github/")
        || path.contains(".gitlab/")
}

#[tokio::main]
async fn main() {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("rsr_lsp=info".parse().unwrap()),
        )
        .with_writer(std::io::stderr)
        .init();

    let stdin = tokio::io::stdin();
    let stdout = tokio::io::stdout();

    let (service, socket) = LspService::new(RsrLanguageServer::new);
    Server::new(stdin, stdout, socket).serve(service).await;
}
