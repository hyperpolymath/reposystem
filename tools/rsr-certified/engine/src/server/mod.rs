//! HTTP server for receiving webhooks and serving the API

pub mod routes;

use crate::Result;
use axum::{routing::get, Router};
use std::net::SocketAddr;
use tower_http::trace::TraceLayer;

/// Run the RSR webhook server
pub async fn run(host: &str, port: u16, platforms: &[&str]) -> Result<()> {
    let app = create_router(platforms);

    let addr: SocketAddr = format!("{}:{}", host, port).parse().map_err(|e| {
        crate::RsrError::Config(format!("Invalid address: {}", e))
    })?;

    tracing::info!("Starting RSR server on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await.map_err(|e| {
        crate::RsrError::Platform(format!("Server error: {}", e))
    })?;

    Ok(())
}

fn create_router(platforms: &[&str]) -> Router {
    let mut router = Router::new()
        .route("/health", get(routes::health))
        .route("/metrics", get(routes::metrics))
        .route("/api/v1/repo/{owner}/{repo}/status", get(routes::get_repo_status))
        .route("/api/v1/repo/{owner}/{repo}/badge", get(routes::get_badge))
        .route("/api/v1/repo/{owner}/{repo}/report", get(routes::get_report));

    // Add webhook routes for enabled platforms
    for platform in platforms {
        let path = format!("/webhook/{}", platform);
        router = router.route(&path, axum::routing::post(routes::handle_webhook));
    }

    router.layer(TraceLayer::new_for_http())
}
