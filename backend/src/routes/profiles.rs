use axum::{extract::{Path, State}, Json};
use serde::Deserialize;
use serde_json::json;
use uuid::Uuid;
use crate::{utils::{auth::AuthUser, errors::AppResult}, AppState};

#[derive(Deserialize)]
pub struct ProfileRequest { pub name: String, pub description: Option<String> }

pub async fn list(auth: AuthUser, State(s): State<AppState>) -> AppResult<Json<serde_json::Value>> {
    let rows = sqlx::query!("SELECT id, name, description, is_active FROM profiles WHERE user_id = ?", auth.0.sub)
        .fetch_all(&s.db).await?;
    let list: Vec<_> = rows.iter().map(|r| json!({ "id": r.id, "name": r.name, "is_active": r.is_active })).collect();
    Ok(Json(json!({ "profiles": list })))
}

pub async fn create(auth: AuthUser, State(s): State<AppState>, Json(body): Json<ProfileRequest>) -> AppResult<Json<serde_json::Value>> {
    let id = Uuid::new_v4().to_string();
    sqlx::query!("INSERT INTO profiles (id, user_id, name, description) VALUES (?,?,?,?)", id, auth.0.sub, body.name, body.description)
        .execute(&s.db).await?;
    Ok(Json(json!({ "id": id })))
}

pub async fn delete(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>) -> AppResult<Json<serde_json::Value>> {
    sqlx::query!("DELETE FROM profiles WHERE id=? AND user_id=?", id, auth.0.sub).execute(&s.db).await?;
    Ok(Json(json!({ "deleted": true })))
}

pub async fn activate(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>) -> AppResult<Json<serde_json::Value>> {
    sqlx::query!("UPDATE users SET active_profile_id=? WHERE id=?", id, auth.0.sub).execute(&s.db).await?;
    Ok(Json(json!({ "activated": true })))
}
