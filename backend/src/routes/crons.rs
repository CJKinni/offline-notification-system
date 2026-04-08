use axum::{extract::{Path, State}, Json};
use serde::Deserialize;
use serde_json::json;
use uuid::Uuid;
use crate::{utils::{auth::AuthUser, errors::{AppError, AppResult}}, AppState};

#[derive(Deserialize)]
pub struct CronRequest {
    pub name: String,
    pub description: Option<String>,
    pub schedule: String,
    pub flow_id: Option<String>,
    pub agent_id: Option<String>,
    pub prompt: Option<String>,
}

pub async fn list(auth: AuthUser, State(s): State<AppState>) -> AppResult<Json<serde_json::Value>> {
    let rows = sqlx::query!(
        "SELECT id, name, description, schedule, flow_id, agent_id, is_active, last_run_at, run_count
         FROM crons WHERE user_id = ? ORDER BY created_at DESC",
        auth.0.sub
    )
    .fetch_all(&s.db).await?;
    let list: Vec<_> = rows.iter().map(|r| json!({
        "id": r.id, "name": r.name, "description": r.description, "schedule": r.schedule,
        "flow_id": r.flow_id, "agent_id": r.agent_id,
        "is_active": r.is_active, "last_run_at": r.last_run_at, "run_count": r.run_count
    })).collect();
    Ok(Json(json!({ "crons": list })))
}

pub async fn get(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>) -> AppResult<Json<serde_json::Value>> {
    let r = sqlx::query!(
        "SELECT * FROM crons WHERE id = ? AND user_id = ?", id, auth.0.sub
    )
    .fetch_optional(&s.db).await?
    .ok_or_else(|| AppError::NotFound("Cron not found".into()))?;
    Ok(Json(json!({ "id": r.id, "name": r.name, "schedule": r.schedule, "prompt": r.prompt })))
}

pub async fn create(auth: AuthUser, State(s): State<AppState>, Json(body): Json<CronRequest>) -> AppResult<Json<serde_json::Value>> {
    let id = Uuid::new_v4().to_string();
    sqlx::query!(
        "INSERT INTO crons (id, user_id, name, description, schedule, flow_id, agent_id, prompt) VALUES (?,?,?,?,?,?,?,?)",
        id, auth.0.sub, body.name, body.description, body.schedule, body.flow_id, body.agent_id, body.prompt
    )
    .execute(&s.db).await?;
    Ok(Json(json!({ "id": id, "name": body.name })))
}

pub async fn update(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>, Json(body): Json<CronRequest>) -> AppResult<Json<serde_json::Value>> {
    sqlx::query!(
        "UPDATE crons SET name=?,description=?,schedule=?,flow_id=?,agent_id=?,prompt=? WHERE id=? AND user_id=?",
        body.name, body.description, body.schedule, body.flow_id, body.agent_id, body.prompt, id, auth.0.sub
    )
    .execute(&s.db).await?;
    Ok(Json(json!({ "updated": true })))
}

pub async fn delete(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>) -> AppResult<Json<serde_json::Value>> {
    sqlx::query!("DELETE FROM crons WHERE id=? AND user_id=?", id, auth.0.sub)
        .execute(&s.db).await?;
    Ok(Json(json!({ "deleted": true })))
}

pub async fn trigger(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>) -> AppResult<Json<serde_json::Value>> {
    // Manual trigger — just emit the event for now; full execution in scheduler
    s.emitter.emit_cron_fired(&id, "manual");
    Ok(Json(json!({ "triggered": true })))
}
