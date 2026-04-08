mod agents;
mod config;
mod crons;
mod db;
mod flows;
mod integrations;
mod routes;
mod socket;
mod utils;

use axum::{routing::post, Router};
use socketioxide::SocketIo;
use sqlx::SqlitePool;
use std::{net::SocketAddr, sync::Arc};
use tower_http::cors::{Any, CorsLayer};
use tower_http::limit::RequestBodyLimitLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use config::Config;
use socket::EventEmitter;

#[derive(Clone)]
pub struct AppState {
    pub db: SqlitePool,
    pub config: Config,
    pub emitter: Arc<EventEmitter>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| "hermes_server=debug,tower_http=info".into()))
        .with(tracing_subscriber::fmt::layer())
        .init();

    let cfg = Config::from_env();
    let db = db::create_pool(&cfg.database_url).await?;

    let (emitter, rx) = EventEmitter::new();
    let emitter = Arc::new(emitter);

    // Socket.io setup
    let (socket_layer, io) = SocketIo::new_layer();
    socket::setup_socket(&io, rx);

    let state = AppState {
        db: db.clone(),
        config: cfg.clone(),
        emitter: emitter.clone(),
    };

    // Start cron scheduler
    let mut scheduler = crons::scheduler::CronScheduler::new(db.clone(), cfg.clone(), emitter.clone()).await?;
    tokio::spawn(async move {
        if let Err(e) = scheduler.start().await {
            tracing::error!("Cron scheduler error: {}", e);
        }
    });

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .nest("/api/v1", routes::api_router())
        // Inbound webhook endpoint (no auth, HMAC validated externally for now)
        .route("/webhooks/receive/:id", post(webhook_receive))
        .layer(socket_layer)
        .layer(cors)
        .layer(RequestBodyLimitLayer::new(10 * 1024 * 1024)) // 10MB
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], cfg.port));
    tracing::info!("Hermes server listening on {addr}");
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;
    Ok(())
}

async fn webhook_receive(
    axum::extract::Path(id): axum::extract::Path<String>,
    axum::extract::State(state): axum::extract::State<AppState>,
    Json(payload): Json<serde_json::Value>,
) -> axum::Json<serde_json::Value> {
    tracing::info!("Inbound webhook for integration {id}");
    state.emitter.emit_flow_update(&id, "webhook", "triggered");
    axum::Json(serde_json::json!({ "received": true }))
}
