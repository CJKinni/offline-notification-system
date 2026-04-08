pub mod auth;
pub mod agents;
pub mod conversations;
pub mod crons;
pub mod flows;
pub mod integrations;
pub mod keys;
pub mod profiles;
pub mod skills;

use axum::{Router, routing::{get, post, put, delete}};
use crate::AppState;

pub fn api_router() -> Router<AppState> {
    Router::new()
        .nest("/auth", auth_routes())
        .nest("/agents", agent_routes())
        .nest("/conversations", conversation_routes())
        .nest("/flows", flow_routes())
        .nest("/crons", cron_routes())
        .nest("/skills", skill_routes())
        .nest("/integrations", integration_routes())
        .nest("/profiles", profile_routes())
        .nest("/keys", key_routes())
}

fn auth_routes() -> Router<AppState> {
    Router::new()
        .route("/register", post(auth::register))
        .route("/login", post(auth::login))
        .route("/me", get(auth::me))
}

fn agent_routes() -> Router<AppState> {
    Router::new()
        .route("/", get(agents::list).post(agents::create))
        .route("/:id", get(agents::get).put(agents::update).delete(agents::delete))
        .route("/:id/soul", get(agents::get_soul).put(agents::upsert_soul))
        .route("/:id/memory", get(agents::get_memory).put(agents::set_memory))
        .route("/:id/memory/append", post(agents::append_memory))
        .route("/:id/skills", get(agents::list_skills).post(agents::attach_skill))
        .route("/:id/skills/:skill_id", delete(agents::detach_skill))
}

fn conversation_routes() -> Router<AppState> {
    Router::new()
        .route("/", get(conversations::list).post(conversations::create))
        .route("/:id", get(conversations::get).delete(conversations::delete))
        .route("/:id/messages", post(conversations::send_message))
}

fn flow_routes() -> Router<AppState> {
    Router::new()
        .route("/", get(flows::list).post(flows::create))
        .route("/:id", get(flows::get).put(flows::update).delete(flows::delete))
        .route("/:id/run", post(flows::run))
        .route("/:id/runs", get(flows::list_runs))
}

fn cron_routes() -> Router<AppState> {
    Router::new()
        .route("/", get(crons::list).post(crons::create))
        .route("/:id", get(crons::get).put(crons::update).delete(crons::delete))
        .route("/:id/trigger", post(crons::trigger))
}

fn skill_routes() -> Router<AppState> {
    Router::new()
        .route("/", get(skills::list).post(skills::create))
        .route("/library", get(skills::library))
        .route("/:id", get(skills::get).put(skills::update).delete(skills::delete))
}

fn integration_routes() -> Router<AppState> {
    Router::new()
        .route("/", get(integrations::list).post(integrations::create))
        .route("/:id", get(integrations::get).put(integrations::update).delete(integrations::delete))
        .route("/:id/test", post(integrations::test))
        .route("/:id/execute", post(integrations::execute))
}

fn profile_routes() -> Router<AppState> {
    Router::new()
        .route("/", get(profiles::list).post(profiles::create))
        .route("/:id", delete(profiles::delete))
        .route("/:id/activate", post(profiles::activate))
}

fn key_routes() -> Router<AppState> {
    Router::new()
        .route("/", get(keys::list).post(keys::store))
        .route("/:provider", delete(keys::delete))
}
