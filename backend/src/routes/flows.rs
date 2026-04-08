use axum::{extract::{Path, State}, Json};
use serde::Deserialize;
use serde_json::json;
use uuid::Uuid;
use crate::{
    flows::{executor::FlowExecutor, types::{FlowEdge, FlowNode}},
    utils::{auth::AuthUser, errors::{AppError, AppResult}},
    AppState,
};

#[derive(Deserialize)]
pub struct FlowRequest {
    pub name: String,
    pub description: Option<String>,
    pub nodes: serde_json::Value,
    pub edges: serde_json::Value,
}

pub async fn list(auth: AuthUser, State(s): State<AppState>) -> AppResult<Json<serde_json::Value>> {
    let rows = sqlx::query!(
        "SELECT id, name, description, is_active, created_at FROM flows WHERE user_id = ? ORDER BY created_at DESC",
        auth.0.sub
    ).fetch_all(&s.db).await?;
    let list: Vec<_> = rows.iter().map(|r| json!({
        "id": r.id, "name": r.name, "description": r.description,
        "is_active": r.is_active, "created_at": r.created_at
    })).collect();
    Ok(Json(json!({ "flows": list })))
}

pub async fn get(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>) -> AppResult<Json<serde_json::Value>> {
    let r = sqlx::query!(
        "SELECT * FROM flows WHERE id = ? AND user_id = ?", id, auth.0.sub
    ).fetch_optional(&s.db).await?
    .ok_or_else(|| AppError::NotFound("Flow not found".into()))?;
    let nodes: serde_json::Value = serde_json::from_str(&r.nodes_json).unwrap_or(json!([]));
    let edges: serde_json::Value = serde_json::from_str(&r.edges_json).unwrap_or(json!([]));
    Ok(Json(json!({ "id": r.id, "name": r.name, "nodes": nodes, "edges": edges })))
}

pub async fn create(auth: AuthUser, State(s): State<AppState>, Json(body): Json<FlowRequest>) -> AppResult<Json<serde_json::Value>> {
    let id = Uuid::new_v4().to_string();
    let nodes = serde_json::to_string(&body.nodes).unwrap_or_else(|_| "[]".into());
    let edges = serde_json::to_string(&body.edges).unwrap_or_else(|_| "[]".into());
    sqlx::query!(
        "INSERT INTO flows (id, user_id, name, description, nodes_json, edges_json) VALUES (?,?,?,?,?,?)",
        id, auth.0.sub, body.name, body.description, nodes, edges
    ).execute(&s.db).await?;
    Ok(Json(json!({ "id": id })))
}

pub async fn update(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>, Json(body): Json<FlowRequest>) -> AppResult<Json<serde_json::Value>> {
    let nodes = serde_json::to_string(&body.nodes).unwrap_or_else(|_| "[]".into());
    let edges = serde_json::to_string(&body.edges).unwrap_or_else(|_| "[]".into());
    sqlx::query!(
        "UPDATE flows SET name=?,description=?,nodes_json=?,edges_json=?,updated_at=unixepoch() WHERE id=? AND user_id=?",
        body.name, body.description, nodes, edges, id, auth.0.sub
    ).execute(&s.db).await?;
    Ok(Json(json!({ "updated": true })))
}

pub async fn delete(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>) -> AppResult<Json<serde_json::Value>> {
    sqlx::query!("DELETE FROM flows WHERE id=? AND user_id=?", id, auth.0.sub).execute(&s.db).await?;
    Ok(Json(json!({ "deleted": true })))
}

pub async fn run(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>, Json(input): Json<serde_json::Value>) -> AppResult<Json<serde_json::Value>> {
    let flow = sqlx::query!(
        "SELECT nodes_json, edges_json FROM flows WHERE id = ? AND user_id = ?", id, auth.0.sub
    ).fetch_optional(&s.db).await?
    .ok_or_else(|| AppError::NotFound("Flow not found".into()))?;

    let nodes: Vec<FlowNode> = serde_json::from_str(&flow.nodes_json).unwrap_or_default();
    let edges: Vec<FlowEdge> = serde_json::from_str(&flow.edges_json).unwrap_or_default();

    let executor = FlowExecutor { db: s.db.clone(), config: s.config.clone() };
    let result = executor.execute(&id, nodes, edges, input).await?;
    Ok(Json(serde_json::to_value(result).unwrap_or(json!({ "status": "done" }))))
}

pub async fn list_runs(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>) -> AppResult<Json<serde_json::Value>> {
    let runs = sqlx::query!(
        "SELECT id, status, started_at, completed_at, duration_ms, error FROM flow_runs WHERE flow_id = ? ORDER BY started_at DESC LIMIT 20",
        id
    ).fetch_all(&s.db).await?;
    let list: Vec<_> = runs.iter().map(|r| json!({
        "id": r.id, "status": r.status, "duration_ms": r.duration_ms, "error": r.error,
        "started_at": r.started_at, "completed_at": r.completed_at
    })).collect();
    Ok(Json(json!({ "runs": list })))
}
