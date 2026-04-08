use axum::{extract::{Path, State}, Json};
use serde::Deserialize;
use serde_json::json;
use uuid::Uuid;
use crate::{utils::{auth::AuthUser, crypto::{encrypt}, errors::{AppError, AppResult}}, AppState};

#[derive(Deserialize)]
pub struct StoreKeyRequest { pub provider: String, pub api_key: String }

pub async fn list(auth: AuthUser, State(s): State<AppState>) -> AppResult<Json<serde_json::Value>> {
    let rows = sqlx::query!("SELECT provider FROM api_keys WHERE user_id = ?", auth.0.sub)
        .fetch_all(&s.db).await?;
    let providers: Vec<_> = rows.iter().map(|r| r.provider.as_str()).collect();
    Ok(Json(json!({ "providers": providers })))
}

pub async fn store(auth: AuthUser, State(s): State<AppState>, Json(body): Json<StoreKeyRequest>) -> AppResult<Json<serde_json::Value>> {
    let enc = encrypt(&body.api_key, &s.config.encryption_key).map_err(|e| AppError::Internal(e))?;
    let id = Uuid::new_v4().to_string();
    sqlx::query!(
        "INSERT INTO api_keys (id, user_id, provider, key_enc) VALUES (?,?,?,?)
         ON CONFLICT(user_id, provider) DO UPDATE SET key_enc=excluded.key_enc",
        id, auth.0.sub, body.provider, enc
    ).execute(&s.db).await?;
    Ok(Json(json!({ "stored": true })))
}

pub async fn delete(auth: AuthUser, State(s): State<AppState>, Path(provider): Path<String>) -> AppResult<Json<serde_json::Value>> {
    sqlx::query!("DELETE FROM api_keys WHERE user_id=? AND provider=?", auth.0.sub, provider)
        .execute(&s.db).await?;
    Ok(Json(json!({ "deleted": true })))
}
